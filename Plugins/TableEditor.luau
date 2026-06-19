local _main_ref, lib_ref, apps_ref, settings_ref, theme_ref

local plugin_data = {
	name         = "TableEditor",
	FriendlyName = "Table Editor",
}

local function initDeps(data)
	_main_ref    = data.Main
	lib_ref      = data.Lib
	apps_ref     = data.Apps
	settings_ref = data.Settings
end

local function initAfterMain(t)
	theme_ref    = t.Theme
end

local function get_theme()
	return theme_ref or (apps_ref and apps_ref.Theme)
end

-- Fallbacks and executors utilities
local table_clear = table.clear or function(t)
	for k in pairs(t) do t[k] = nil end
end

local table_pack = table.pack or function(...)
	return { n = select("#", ...), ... }
end

local debug_getupvalue = debug["getupvalue"] or getupvalue
local debug_setupvalue = debug["setupvalue"] or setupvalue
local debug_getconstants = debug["getconstants"] or getconstants
local debug_setconstant = debug["setconstant"] or setconstant

local function get_upvalues_list(f)
	local list = {}
	if not debug_getupvalue then return list end
	local index = 1
	while true do
		local name, val = debug_getupvalue(f, index)
		if not name then break end
		table.insert(list, { index = index, name = name, value = val })
		index = index + 1
	end
	return list
end

local function get_constants_list(f)
	if debug_getconstants then
		local ok, list = pcall(debug_getconstants, f)
		if ok and typeof(list) == "table" then
			return list
		end
	end
	return {}
end

local function safe_tostring(val)
	local ok, str = pcall(tostring, val)
	return ok and str or ("[error: " .. typeof(val) .. "]")
end

local function safe_string(val)
	local t = typeof(val)
	if t == "Instance" then
		local ok, path = pcall(function() return val:GetFullName() end)
		return ok and path or safe_tostring(val)
	elseif t == "string" then
		return '"' .. val .. '"'
	elseif t == "table" or t == "function" or t == "userdata" then
		return safe_tostring(val)
	else
		return safe_tostring(val)
	end
end

local function scan_gc_filtered(filter)
	local items = {}
	if not env.getgc then return items end
	
	local ok, gc = pcall(env.getgc, true)
	if not ok or type(gc) ~= "table" then return items end
	
	local count = 0
	local filter_low = filter:lower()
	for _, v in pairs(gc) do
		local t = type(v)
		if t == "table" or t == "function" then
			local matches_filter = false
			if filter == "" then
				matches_filter = true
			else
				if t == "table" then
					pcall(function()
						for k, val in pairs(v) do
							if safe_tostring(k):lower():find(filter_low, 1, true) or safe_tostring(val):lower():find(filter_low, 1, true) then
								matches_filter = true
								break
							end
						end
					end)
				elseif t == "function" then
					local name = debug.info(v, "n") or ""
					local source = debug.info(v, "s") or ""
					if name:lower():find(filter_low, 1, true) or source:lower():find(filter_low, 1, true) then
						matches_filter = true
					end
				end
			end
			
			if matches_filter then
				count = count + 1
				table.insert(items, v)
				if count >= 400 then break end
			end
		end
	end
	return items
end

local function main()
	local editor = {}
	editor.PluginData = plugin_data

	-- State management
	local current_target = _G
	local current_target_name = "_G"
	local current_view_type = "table" -- "table", "function_inspect", "upvalues", "constants", "gc_list"
	local history = {} -- Stack of { target, name, view_type }
	local keys_list = {}
	local log_frames = {}
	local row_key_map = {}
	local selected_key = nil
	local selected_val = nil
	local filter_text = ""
	local selected_source = "_G"
	
	-- UI Elements
	local window, list_frame, scroll_v, status_label, empty_label, breadcrumb_scroll, expr_frame, expr_box
	local detail_title, detail_type, detail_box, edit_btn, call_btn, explore_btn, decompile_btn, copy_btn
	local edit_overlay, edit_title, edit_input, edit_check, edit_type_btn, edit_error, edit_cast_type
	local call_overlay, call_func_name, call_input, call_output, call_exec_btn
	local rebuild_list

	local colors = {
		table    = Color3.fromRGB(59, 130, 246),
		["function"] = Color3.fromRGB(139, 92, 246),
		string   = Color3.fromRGB(249, 115, 22),
		number   = Color3.fromRGB(34, 197, 94),
		boolean  = Color3.fromRGB(217, 119, 6),
		Instance = Color3.fromRGB(6, 182, 212),
		OTHER    = Color3.fromRGB(163, 163, 163),
	}

	local function get_color_for_type(t)
		return colors[t] or colors.OTHER
	end

	local function build_keys()
		table.clear(keys_list)
		if current_view_type == "table" then
			if typeof(current_target) == "table" then
				local ok, err = pcall(function()
					for k, v in pairs(current_target) do
						local k_str = safe_tostring(k)
						if filter_text == "" or k_str:lower():find(filter_text:lower(), 1, true) then
							table.insert(keys_list, { key = k, value = v, type = typeof(v) })
						end
					end
				end)
				if not ok then
					table.insert(keys_list, { key = "Error", value = safe_tostring(err), type = "string" })
				end
			end
			table.sort(keys_list, function(a, b)
				return safe_tostring(a.key):lower() < safe_tostring(b.key):lower()
			end)
		elseif current_view_type == "function_inspect" then
			table.insert(keys_list, { key = "Upvalues", value = "Folder containing upvalues", type = "virtual_folder", tag = "upvalues" })
			table.insert(keys_list, { key = "Constants", value = "Folder containing constants", type = "virtual_folder", tag = "constants" })
		elseif current_view_type == "upvalues" then
			local ups = get_upvalues_list(current_target)
			for _, up in ipairs(ups) do
				if filter_text == "" or up.name:lower():find(filter_text:lower(), 1, true) then
					table.insert(keys_list, { key = up.index, name = up.name, value = up.value, type = typeof(up.value), tag = "upvalue" })
				end
			end
		elseif current_view_type == "constants" then
			local consts = get_constants_list(current_target)
			for i, const in ipairs(consts) do
				if filter_text == "" or safe_tostring(const):lower():find(filter_text:lower(), 1, true) then
					table.insert(keys_list, { key = i, value = const, type = typeof(const), tag = "constant" })
				end
			end
		elseif current_view_type == "gc_list" then
			local gc_items = scan_gc_filtered(filter_text)
			for i, v in ipairs(gc_items) do
				local preview = (typeof(v) == "table") and safe_tostring(v) or (debug.info(v, "n") or "anonymous") .. "()"
				table.insert(keys_list, { key = i, value = v, type = typeof(v), preview = preview, tag = "gc_item" })
			end
		end
	end

	local function rebuild_breadcrumbs()
		for _, child in ipairs(breadcrumb_scroll:GetChildren()) do
			if not child:IsA("UIListLayout") then child:Destroy() end
		end
		
		local function add_crumb(name, index)
			local btn = Instance.new("TextButton")
			btn.BackgroundTransparency = 1
			btn.Font = Enum.Font.SourceSans
			btn.TextSize = 13
			btn.TextColor3 = settings_ref.Theme.Text
			btn.Text = name .. "  >"
			btn.Size = UDim2.new(0, 0, 1, 0)
			btn.AutomaticSize = Enum.AutomaticSize.X
			btn.Parent = breadcrumb_scroll
			
			btn.MouseButton1Click:Connect(function()
				-- Pop history back to index
				while #history > index do
					table.remove(history)
				end
				local state = table.remove(history)
				if state then
					current_target = state.target
					current_target_name = state.name
					current_view_type = state.view_type
					selected_key = nil
					selected_val = nil
					rebuild_list()
				end
			end)
		end
		
		for i, state in ipairs(history) do
			add_crumb(state.name, i)
		end
		
		local current_lbl = Instance.new("TextLabel")
		current_lbl.BackgroundTransparency = 1
		current_lbl.Font = Enum.Font.SourceSansBold
		current_lbl.TextSize = 13
		current_lbl.TextColor3 = settings_ref.Theme.PlaceholderText
		current_lbl.Text = current_target_name
		current_lbl.Size = UDim2.new(0, 0, 1, 0)
		current_lbl.AutomaticSize = Enum.AutomaticSize.X
		current_lbl.Parent = breadcrumb_scroll
	end

	local function update_details(key, val, t, tag)
		selected_key = key
		selected_val = val
		
		if key == nil then
			detail_title.Text = "Select an item"
			detail_type.Text = ""
			detail_box.Text = ""
			edit_btn.Active = false
			edit_btn.BackgroundColor3 = settings_ref.Theme.Main1
			call_btn.Active = false
			call_btn.BackgroundColor3 = settings_ref.Theme.Main1
			explore_btn.Active = false
			explore_btn.BackgroundColor3 = settings_ref.Theme.Main1
			decompile_btn.Active = false
			decompile_btn.BackgroundColor3 = settings_ref.Theme.Main1
			copy_btn.Active = false
			copy_btn.BackgroundColor3 = settings_ref.Theme.Main1
			return
		end
		
		detail_title.Text = safe_tostring(key)
		detail_type.Text = "Type: " .. t
		detail_type.TextColor3 = get_color_for_type(t)
		detail_box.Text = safe_string(val)
		
		decompile_btn.Active = (t == "Instance" and val:IsA("LuaSourceContainer"))
		decompile_btn.BackgroundColor3 = decompile_btn.Active and settings_ref.Theme.Button or settings_ref.Theme.Main1
		
		explore_btn.Active = (t == "Instance")
		explore_btn.BackgroundColor3 = explore_btn.Active and settings_ref.Theme.Button or settings_ref.Theme.Main1
		
		call_btn.Active = (t == "function")
		call_btn.BackgroundColor3 = call_btn.Active and settings_ref.Theme.Button or settings_ref.Theme.Main1
		
		edit_btn.Active = (t ~= "virtual_folder" and t ~= "userdata" and t ~= "thread" and tag ~= "gc_item")
		edit_btn.BackgroundColor3 = edit_btn.Active and settings_ref.Theme.Button or settings_ref.Theme.Main1
		
		copy_btn.Active = true
		copy_btn.BackgroundColor3 = settings_ref.Theme.Button
	end

	local function update_scroll()
		if scroll_v then
			scroll_v.TotalSpace = #log_frames
			scroll_v.Index = math.max(0, #log_frames - scroll_v.VisibleSpace)
			scroll_v:Update()
		end
	end

	local function rebuild_list_highlights()
		for _, row in ipairs(log_frames) do
			local k = row_key_map[row]
			if k == selected_key then
				row.BackgroundColor3 = settings_ref.Theme.ListSelection
			else
				row.BackgroundColor3 = settings_ref.Theme.Main1
			end
		end
	end

	local function push_row(item)
		if not list_frame then return end
		if empty_label then empty_label.Visible = false end
		
		local row = Instance.new("Frame")
		row.BackgroundColor3 = settings_ref.Theme.Main1
		row.BorderSizePixel  = 0
		row.Size             = UDim2.new(1, 0, 0, 36)
		row.ClipsDescendants = true
		
		local badge_color = get_color_for_type(item.type)
		local badge = Instance.new("Frame", row)
		badge.BackgroundColor3 = badge_color
		badge.BorderSizePixel  = 0
		badge.Size             = UDim2.new(0, 3, 1, 0)
		
		local expand_lbl = Instance.new("TextLabel", row)
		expand_lbl.BackgroundTransparency = 1
		expand_lbl.Position = UDim2.new(0, 6, 0, 0)
		expand_lbl.Size = UDim2.new(0, 12, 1, 0)
		expand_lbl.Font = Enum.Font.Code
		expand_lbl.TextSize = 11
		expand_lbl.TextColor3 = settings_ref.Theme.PlaceholderText
		expand_lbl.Text = (item.type == "table" or item.type == "function" or item.type == "virtual_folder" or item.tag == "gc_item") and ">" or "-"
		
		local name_lbl = Instance.new("TextLabel", row)
		name_lbl.BackgroundTransparency = 1
		name_lbl.Position  = UDim2.new(0, 20, 0, 2)
		name_lbl.Size      = UDim2.new(1, -26, 0, 16)
		name_lbl.Font      = get_theme() and get_theme().MapFont(Enum.Font.SourceSansBold) or Enum.Font.SourceSansBold
		name_lbl.TextSize  = 13
		name_lbl.TextColor3 = settings_ref.Theme.Text
		name_lbl.TextXAlignment = Enum.TextXAlignment.Left
		name_lbl.TextTruncate = Enum.TextTruncate.AtEnd
		
		if item.name then
			name_lbl.Text = safe_tostring(item.key) .. " (" .. item.name .. ")"
		else
			name_lbl.Text = safe_tostring(item.key)
		end
		
		local val_lbl = Instance.new("TextLabel", row)
		val_lbl.BackgroundTransparency = 1
		val_lbl.Position  = UDim2.new(0, 20, 0, 18)
		val_lbl.Size      = UDim2.new(1, -26, 0, 16)
		val_lbl.Font      = Enum.Font.Code
		val_lbl.TextSize  = 10
		val_lbl.TextColor3 = badge_color
		val_lbl.TextXAlignment = Enum.TextXAlignment.Left
		val_lbl.TextTruncate = Enum.TextTruncate.AtEnd
		
		if item.preview then
			val_lbl.Text = item.preview
		else
			val_lbl.Text = safe_string(item.value)
		end
		
		local separator = Instance.new("Frame", row)
		separator.BackgroundColor3 = settings_ref.Theme.Outline1
		separator.BorderSizePixel = 0
		separator.Size = UDim2.new(1, 0, 0, 1)
		separator.Position = UDim2.new(0, 0, 1, -1)
		
		row.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseMovement then
				row.BackgroundColor3 = selected_key == item.key and settings_ref.Theme.ListSelection or settings_ref.Theme.ButtonHover
			elseif i.UserInputType == Enum.UserInputType.MouseButton1 then
				selected_key = item.key
				update_details(item.key, item.value, item.type, item.tag)
				rebuild_list_highlights()
			end
		end)
		
		-- Double click or click arrow to expand
		row.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 then
				local now = tick()
				if row:GetAttribute("LastClick") and now - row:GetAttribute("LastClick") < 0.35 then
					-- Expand table or function
					if item.type == "table" then
						table.insert(history, { target = current_target, name = current_target_name, view_type = current_view_type })
						current_target = item.value
						current_target_name = safe_tostring(item.key)
						current_view_type = "table"
						selected_key = nil
						selected_val = nil
						rebuild_list()
					elseif item.type == "function" then
						table.insert(history, { target = current_target, name = current_target_name, view_type = current_view_type })
						current_target = item.value
						current_target_name = safe_tostring(item.key) .. "()"
						current_view_type = "function_inspect"
						selected_key = nil
						selected_val = nil
						rebuild_list()
					elseif item.type == "virtual_folder" then
						table.insert(history, { target = current_target, name = current_target_name, view_type = current_view_type })
						-- Target remains function, type changes to upvalues/constants
						current_view_type = item.tag
						current_target_name = item.tag:sub(1,1):upper() .. item.tag:sub(2)
						selected_key = nil
						selected_val = nil
						rebuild_list()
					elseif item.tag == "gc_item" then
						table.insert(history, { target = current_target, name = current_target_name, view_type = current_view_type })
						current_target = item.value
						current_target_name = (typeof(item.value) == "table") and safe_tostring(item.value) or (debug.info(item.value, "n") or "anonymous") .. "()"
						current_view_type = (typeof(item.value) == "table") and "table" or "function_inspect"
						selected_key = nil
						selected_val = nil
						rebuild_list()
					end
				end
				row:SetAttribute("LastClick", now)
			end
		end)

		row.InputEnded:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseMovement then
				row.BackgroundColor3 = selected_key == item.key and settings_ref.Theme.ListSelection or settings_ref.Theme.Main1
			end
		end)
		
		row.LayoutOrder = #log_frames + 1
		row.Parent = list_frame
		table.insert(log_frames, row)
		row_key_map[row] = item.key
	end

	rebuild_list = function()
		for _, f in ipairs(log_frames) do f:Destroy() end
		log_frames = {}
		table_clear(row_key_map)
		
		build_keys()
		rebuild_breadcrumbs()
		
		for _, item in ipairs(keys_list) do
			push_row(item)
		end
		
		if empty_label then
			empty_label.Visible = #keys_list == 0
			if current_view_type == "gc_list" then
				empty_label.Text = "Type in search filter to scan GC..."
			else
				empty_label.Text = "Table is empty or matches no filters"
			end
		end
		
		if status_label then
			status_label.Text = #keys_list .. " keys found"
		end
		
		update_scroll()
		rebuild_list_highlights()
		update_details(selected_key, selected_val, selected_key and typeof(selected_val) or "", selected_key and "details" or nil)
	end

	local function open_edit_overlay()
		if not selected_key then return end
		edit_title.Text = "Edit: " .. safe_tostring(selected_key)
		edit_error.Text = ""
		
		local t = typeof(selected_val)
		if t == "boolean" then
			edit_cast_type = "boolean"
			edit_input.Visible = false
			edit_check.Visible = true
			edit_check.Text = selected_val and "True" or "False"
			edit_check.BackgroundColor3 = selected_val and Color3.fromRGB(34, 197, 94) or Color3.fromRGB(239, 68, 68)
		elseif t == "nil" then
			edit_cast_type = "nil"
			edit_input.Visible = true
			edit_input.Text = "nil"
			edit_check.Visible = false
		elseif t == "number" then
			edit_cast_type = "number"
			edit_input.Visible = true
			edit_input.Text = safe_tostring(selected_val)
			edit_check.Visible = false
		elseif t == "string" then
			edit_cast_type = "string"
			edit_input.Visible = true
			edit_input.Text = selected_val
			edit_check.Visible = false
		else
			-- fallback to json for tables
			edit_cast_type = "JSON"
			edit_input.Visible = true
			edit_input.Text = "{}"
			edit_check.Visible = false
		end
		
		edit_type_btn.Text = "Cast: " .. edit_cast_type:upper()
		edit_overlay.Visible = true
	end

	local function save_edit()
		local raw_input = edit_input.Text
		if edit_cast_type == "boolean" then
			raw_input = (edit_check.Text == "True") and "true" or "false"
		end
		
		local parsed_value
		if edit_cast_type == "nil" then
			parsed_value = nil
		elseif edit_cast_type == "boolean" then
			parsed_value = (raw_input == "true")
		elseif edit_cast_type == "number" then
			parsed_value = tonumber(raw_input)
			if not parsed_value then
				edit_error.Text = "Invalid number format"
				return
			end
		elseif edit_cast_type == "string" then
			parsed_value = tostring(raw_input)
		elseif edit_cast_type == "JSON" then
			local hs = service.HttpService
			local ok, decoded = pcall(function() return hs:JSONDecode(raw_input) end)
			if not ok then
				edit_error.Text = "Invalid JSON structure"
				return
			end
			parsed_value = decoded
		end
		
		local success, err
		if current_view_type == "table" then
			success, err = pcall(function()
				current_target[selected_key] = parsed_value
			end)
		elseif current_view_type == "upvalues" then
			if debug_setupvalue then
				success, err = pcall(debug_setupvalue, current_target, selected_key, parsed_value)
			else
				success, err = false, "debug.setupvalue not supported"
			end
		elseif current_view_type == "constants" then
			if debug_setconstant then
				success, err = pcall(debug_setconstant, current_target, selected_key, parsed_value)
			else
				success, err = false, "debug.setconstant not supported"
			end
		end
		
		if success then
			edit_overlay.Visible = false
			-- Update local value in list
			for _, item in ipairs(keys_list) do
				if item.key == selected_key then
					item.value = parsed_value
					item.type = typeof(parsed_value)
					break
				end
			end
			selected_val = parsed_value
			rebuild_list()
		else
			edit_error.Text = "Write Error:\n" .. safe_tostring(err)
		end
	end

	local function open_call_overlay()
		if typeof(selected_val) ~= "function" then return end
		local name = debug.info(selected_val, "n") or safe_tostring(selected_key)
		call_func_name.Text = "Call: " .. name .. "()"
		call_input.Text = ""
		call_output.Text = "Return results will appear here."
		call_overlay.Visible = true
	end

	local function execute_call()
		local input_args_str = call_input.Text
		local parsed_args = {}
		
		if input_args_str ~= "" then
			local loader = env.loadstring or loadstring
			if not loader then
				call_output.Text = "Error: executor loadstring is missing"
				return
			end
			local ok, func = pcall(loader, "return {" .. input_args_str .. "}")
			if ok and type(func) == "function" then
				local ok2, args = pcall(func)
				if ok2 and typeof(args) == "table" then
					parsed_args = args
				else
					call_output.Text = "Error compiling args: " .. safe_tostring(args)
					return
				end
			else
				call_output.Text = "Error parsing args. Check syntax (e.g. 1, 'text', workspace.Part)"
				return
			end
		end
		
		call_output.Text = "Calling function..."
		task.spawn(function()
			local results = table_pack(pcall(selected_val, table.unpack(parsed_args)))
			if results[1] == true then
				local out = {}
				for i = 2, results.n do
					table.insert(out, "Return " .. (i - 1) .. ": " .. safe_tostring(results[i]))
				end
				call_output.Text = #out == 0 and "Call finished successfully (no returns)" or table.concat(out, "\n")
			else
				call_output.Text = "Call Execution Failed:\n" .. safe_tostring(results[2])
			end
		end)
	end

	local function make_btn(parent, text, x, y, w, h)
		local btn = Instance.new("TextButton")
		btn.BorderSizePixel  = 0
		btn.Font             = Enum.Font.SourceSans
		btn.TextSize         = 13
		btn.Text             = text
		btn.AutoButtonColor  = false
		btn.Size             = UDim2.new(0, w, 0, h)
		btn.Position         = UDim2.new(0, x, 0, y)
		btn.Parent           = parent
		if get_theme() then
			get_theme().StyleButton(btn)
		else
			btn.BackgroundColor3 = settings_ref.Theme.Button
			btn.TextColor3       = settings_ref.Theme.Text
			local c = Instance.new("UICorner", btn)
			c.CornerRadius = UDim.new(0, 3)
		end
		return btn
	end

	editor.LoadTable = function(tbl, name)
		current_target = tbl
		current_target_name = name or "Loaded Table"
		current_view_type = (typeof(tbl) == "table") and "table" or "function_inspect"
		table.clear(history)
		selected_key = nil
		selected_val = nil
		if selected_source ~= "expression" then
			selected_source = "expression"
			if expr_frame then expr_frame.Visible = true end
		end
		if expr_box then expr_box.Text = "(Required Module Return)" end
		rebuild_list()
	end

	editor.Init = function()
		window = lib_ref.Window.new()
		window:SetTitle("Table Editor")
		window:Resize(760, 460)
		editor.Window = window

		local toolbar = Instance.new("Frame")
		toolbar.BackgroundColor3 = settings_ref.Theme.Menu
		toolbar.BorderSizePixel  = 0
		toolbar.Size             = UDim2.new(1, 0, 0, 26)
		toolbar.Parent           = window.GuiElems.Content

		-- Source Selector Dropdown simulation
		local source_btn = make_btn(toolbar, "Source: _G", 4, 4, 110, 18)
		
		local source_menu = Instance.new("Frame", toolbar)
		source_menu.BackgroundColor3 = settings_ref.Theme.Main1
		source_menu.BorderSizePixel = 1
		source_menu.BorderColor3 = settings_ref.Theme.Outline2
		source_menu.Size = UDim2.new(0, 110, 0, 130)
		source_menu.Position = UDim2.new(0, 4, 0, 24)
		source_menu.Visible = false
		source_menu.ZIndex = 50
		
		local menu_layout = Instance.new("UIListLayout", source_menu)
		menu_layout.SortOrder = Enum.SortOrder.LayoutOrder
		
		local function add_source_option(name, target, view_type)
			local opt = Instance.new("TextButton", source_menu)
			opt.Size = UDim2.new(1, 0, 0, 20)
			opt.BorderSizePixel = 0
			opt.Font = Enum.Font.SourceSans
			opt.TextSize = 12
			opt.TextColor3 = settings_ref.Theme.Text
			opt.BackgroundColor3 = settings_ref.Theme.Main2
			opt.Text = name
			opt.ZIndex = 50
			
			opt.MouseEnter:Connect(function() opt.BackgroundColor3 = settings_ref.Theme.ButtonHover end)
			opt.MouseLeave:Connect(function() opt.BackgroundColor3 = settings_ref.Theme.Main2 end)
			opt.MouseButton1Click:Connect(function()
				source_btn.Text = "Source: " .. name
				selected_source = name
				source_menu.Visible = false
				
				current_target = target
				current_target_name = name
				current_view_type = view_type
				table.clear(history)
				selected_key = nil
				selected_val = nil
				
				expr_frame.Visible = (name == "expression")
				rebuild_list()
			end)
		end
		
		add_source_option("_G", _G, "table")
		add_source_option("shared", shared, "table")
		add_source_option("getgenv()", getgenv and getgenv() or {}, "table")
		add_source_option("getreg()", getreg and getreg() or {}, "table")
		add_source_option("getgc()", nil, "gc_list")
		add_source_option("expression", nil, "table")
		
		source_btn.MouseButton1Click:Connect(function()
			source_menu.Visible = not source_menu.Visible
		end)

		status_label = Instance.new("TextLabel")
		status_label.BackgroundTransparency = 1
		status_label.Font       = get_theme() and get_theme().MapFont(Enum.Font.SourceSans) or Enum.Font.SourceSans
		status_label.TextSize   = 12
		status_label.TextColor3 = settings_ref.Theme.PlaceholderText
		status_label.TextXAlignment = Enum.TextXAlignment.Right
		status_label.Size       = UDim2.new(1, -130, 1, 0)
		status_label.Position   = UDim2.new(0, 120, 0, 0)
		status_label.Text       = "0 keys"
		status_label.Parent     = toolbar

		-- Custom Expression frame
		expr_frame = Instance.new("Frame")
		expr_frame.BackgroundColor3 = settings_ref.Theme.Main1
		expr_frame.BorderSizePixel = 0
		expr_frame.Position = UDim2.new(0, 0, 0, 26)
		expr_frame.Size = UDim2.new(1, 0, 0, 26)
		expr_frame.Visible = false
		expr_frame.Parent = window.GuiElems.Content
		
		expr_box = Instance.new("TextBox", expr_frame)
		expr_box.BackgroundTransparency = 1
		expr_box.Position = UDim2.new(0, 8, 0, 0)
		expr_box.Size = UDim2.new(1, -78, 1, 0)
		expr_box.Font = Enum.Font.Code
		expr_box.TextSize = 12
		expr_box.TextColor3 = settings_ref.Theme.Text
		expr_box.PlaceholderText = "Type Luau expression (e.g. game.Workspace)"
		expr_box.PlaceholderColor3 = settings_ref.Theme.PlaceholderText
		expr_box.Text = ""
		expr_box.TextXAlignment = Enum.TextXAlignment.Left
		expr_box.ClearTextOnFocus = false
		
		local load_expr_btn = make_btn(expr_frame, "Load", 692, 4, 60, 18)
		load_expr_btn.MouseButton1Click:Connect(function()
			local loader = env.loadstring or loadstring
			if not loader then return end
			local code = expr_box.Text
			local ok, f = pcall(loader, "return " .. code)
			if ok and type(f) == "function" then
				local ok2, val = pcall(f)
				if ok2 then
					current_target = val
					current_target_name = code
					current_view_type = (typeof(val) == "table") and "table" or "function_inspect"
					table.clear(history)
					selected_key = nil
					selected_val = nil
					rebuild_list()
				end
			end
		end)

		-- Breadcrumbs navigation bar
		local breadcrumb_bar = Instance.new("Frame")
		breadcrumb_bar.BackgroundColor3 = settings_ref.Theme.Main1
		breadcrumb_bar.BorderSizePixel  = 0
		breadcrumb_bar.Size             = UDim2.new(1, 0, 0, 26)
		breadcrumb_bar.Position         = UDim2.new(0, 0, 0, 26)
		breadcrumb_bar.Parent           = window.GuiElems.Content
		
		breadcrumb_scroll = Instance.new("ScrollingFrame", breadcrumb_bar)
		breadcrumb_scroll.BackgroundTransparency = 1
		breadcrumb_scroll.BorderSizePixel = 0
		breadcrumb_scroll.Position = UDim2.new(0, 8, 0, 0)
		breadcrumb_scroll.Size = UDim2.new(1, -16, 1, 0)
		breadcrumb_scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		breadcrumb_scroll.ScrollBarThickness = 0
		breadcrumb_scroll.AutomaticCanvasSize = Enum.AutomaticSize.X
		breadcrumb_scroll.ScrollingDirection = Enum.ScrollingDirection.X
		
		local breadcrumb_layout = Instance.new("UIListLayout", breadcrumb_scroll)
		breadcrumb_layout.FillDirection = Enum.FillDirection.Horizontal
		breadcrumb_layout.SortOrder = Enum.SortOrder.LayoutOrder
		breadcrumb_layout.Padding = UDim.new(0, 6)

		-- Search Bar / Search Box (re-positioned lower)
		local search_bar = Instance.new("Frame")
		search_bar.BackgroundColor3 = settings_ref.Theme.Main2
		search_bar.BorderSizePixel  = 0
		search_bar.Size             = UDim2.new(1, 0, 0, 26)
		search_bar.Position         = UDim2.new(0, 0, 0, 52)
		search_bar.Parent           = window.GuiElems.Content

		local search_box = Instance.new("TextBox", search_bar)
		search_box.BackgroundTransparency = 1
		search_box.PlaceholderText  = "Search keys (or GC items)..."
		search_box.PlaceholderColor3 = settings_ref.Theme.PlaceholderText
		search_box.Text             = ""
		search_box.Font             = Enum.Font.Code
		search_box.TextSize         = 13
		search_box.TextColor3       = settings_ref.Theme.Text
		search_box.TextXAlignment   = Enum.TextXAlignment.Left
		search_box.ClearTextOnFocus = false
		search_box.Size             = UDim2.new(1, -14, 1, 0)
		search_box.Position         = UDim2.new(0, 8, 0, 0)
		search_box:GetPropertyChangedSignal("Text"):Connect(function()
			filter_text = search_box.Text
			rebuild_list()
		end)

		local body = Instance.new("Frame")
		body.BackgroundColor3 = settings_ref.Theme.Main2
		body.BorderSizePixel = 0
		body.Position = UDim2.new(0, 0, 0, 78)
		body.Size = UDim2.new(1, 0, 1, -78)
		body.Parent = window.GuiElems.Content

		local left_panel = Instance.new("Frame")
		left_panel.BackgroundColor3 = settings_ref.Theme.Main1
		left_panel.BorderSizePixel = 0
		left_panel.Size = UDim2.new(0, 400, 1, 0)
		left_panel.Parent = body

		local list_container = Instance.new("Frame")
		list_container.BackgroundColor3 = settings_ref.Theme.Main2
		list_container.BorderSizePixel  = 0
		list_container.Size             = UDim2.new(1, -16, 1, 0)
		list_container.ClipsDescendants = true
		list_container.Parent           = left_panel

		list_frame = Instance.new("Frame")
		list_frame.BackgroundTransparency = 1
		list_frame.Size         = UDim2.new(1, 0, 0, 0)
		list_frame.AutomaticSize = Enum.AutomaticSize.Y
		list_frame.Parent       = list_container

		local layout = Instance.new("UIListLayout", list_frame)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding   = UDim.new(0, 1)

		empty_label = Instance.new("TextLabel", list_container)
		empty_label.BackgroundTransparency = 1
		empty_label.Size = UDim2.new(1, 0, 0, 48)
		empty_label.Position = UDim2.new(0, 0, 0.5, -24)
		empty_label.Font = get_theme() and get_theme().MapFont(Enum.Font.SourceSans) or Enum.Font.SourceSans
		empty_label.TextSize = 14
		empty_label.TextColor3 = settings_ref.Theme.PlaceholderText
		empty_label.Text = "Table is empty or matches no filters"
		empty_label.Visible = true

		scroll_v = lib_ref.ScrollBar.new()
		scroll_v.WheelIncrement  = 3
		scroll_v.Gui.Position    = UDim2.new(1, -16, 0, 0)
		scroll_v.Gui.Size        = UDim2.new(0, 16, 1, 0)
		scroll_v.Gui.Parent      = left_panel
		scroll_v:SetScrollFrame(list_container)
		scroll_v.Scrolled:Connect(function()
			list_frame.Position = UDim2.new(0, 0, 0, -scroll_v.Index * 37)
		end)

		local split_line = Instance.new("Frame", body)
		split_line.BackgroundColor3 = settings_ref.Theme.Outline1
		split_line.BorderSizePixel = 0
		split_line.Position = UDim2.new(0, 400, 0, 0)
		split_line.Size = UDim2.new(0, 1, 1, 0)

		local right_panel = Instance.new("Frame")
		right_panel.BackgroundColor3 = settings_ref.Theme.Main2
		right_panel.BorderSizePixel = 0
		right_panel.Position = UDim2.new(0, 401, 0, 0)
		right_panel.Size = UDim2.new(1, -401, 1, 0)
		right_panel.Parent = body

		detail_title = Instance.new("TextLabel", right_panel)
		detail_title.BackgroundTransparency = 1
		detail_title.Position = UDim2.new(0, 10, 0, 10)
		detail_title.Size = UDim2.new(1, -20, 0, 20)
		detail_title.Font = get_theme() and get_theme().MapFont(Enum.Font.SourceSansBold) or Enum.Font.SourceSansBold
		detail_title.TextSize = 14
		detail_title.TextColor3 = settings_ref.Theme.Text
		detail_title.TextXAlignment = Enum.TextXAlignment.Left
		detail_title.TextTruncate = Enum.TextTruncate.AtEnd
		detail_title.Text = "Select an item"

		detail_type = Instance.new("TextLabel", right_panel)
		detail_type.BackgroundTransparency = 1
		detail_type.Position = UDim2.new(0, 10, 0, 30)
		detail_type.Size = UDim2.new(1, -20, 0, 16)
		detail_type.Font = Enum.Font.SourceSans
		detail_type.TextSize = 12
		detail_type.TextColor3 = settings_ref.Theme.PlaceholderText
		detail_type.TextXAlignment = Enum.TextXAlignment.Left
		detail_type.Text = ""

		detail_box = Instance.new("TextBox", right_panel)
		detail_box.BackgroundColor3 = settings_ref.Theme.Main1
		detail_box.BorderSizePixel = 0
		detail_box.Position = UDim2.new(0, 10, 0, 50)
		detail_box.Size = UDim2.new(1, -20, 0, 120)
		detail_box.Font = Enum.Font.Code
		detail_box.TextSize = 11
		detail_box.TextColor3 = settings_ref.Theme.Text
		detail_box.TextEditable = false
		detail_box.ClearTextOnFocus = false
		detail_box.MultiLine = true
		detail_box.TextWrapped = true
		detail_box.Text = ""
		detail_box.TextXAlignment = Enum.TextXAlignment.Left
		detail_box.TextYAlignment = Enum.TextYAlignment.Top
		local pad_box = Instance.new("UIPadding", detail_box)
		pad_box.PaddingLeft = UDim.new(0, 6)
		pad_box.PaddingRight = UDim.new(0, 6)
		pad_box.PaddingTop = UDim.new(0, 6)
		pad_box.PaddingBottom = UDim.new(0, 6)
		if get_theme() then get_theme().ApplyRounding(detail_box, 4) end

		local function make_detail_btn(text, y, h)
			local btn = Instance.new("TextButton", right_panel)
			btn.BorderSizePixel = 0
			btn.Font = Enum.Font.SourceSans
			btn.TextSize = 13
			btn.Text = text
			btn.AutoButtonColor = false
			btn.Size = UDim2.new(1, -20, 0, h)
			btn.Position = UDim2.new(0, 10, 0, y)
			btn.Active = false
			if get_theme() then
				get_theme().StyleButton(btn)
			else
				btn.BackgroundColor3 = settings_ref.Theme.Main1
				btn.TextColor3 = settings_ref.Theme.Text
			end
			return btn
		end

		edit_btn      = make_detail_btn("Edit Value", 180, 26)
		call_btn      = make_detail_btn("Call Function", 212, 26)
		explore_btn   = make_detail_btn("View in Explorer", 244, 26)
		decompile_btn = make_detail_btn("Decompile Script", 276, 26)
		copy_btn      = make_detail_btn("Copy Value to Clipboard", 308, 26)

		-- Value Editor Overlay
		edit_overlay = Instance.new("Frame", window.GuiElems.Content)
		edit_overlay.BackgroundColor3 = settings_ref.Theme.Main2
		edit_overlay.BorderSizePixel = 1
		edit_overlay.BorderColor3 = settings_ref.Theme.Outline2
		edit_overlay.Size = UDim2.new(0, 300, 0, 200)
		edit_overlay.Position = UDim2.new(0.5, -150, 0.5, -100)
		edit_overlay.Visible = false
		edit_overlay.ZIndex = 100
		if get_theme() then get_theme().ApplyRounding(edit_overlay, 8) end

		edit_title = Instance.new("TextLabel", edit_overlay)
		edit_title.BackgroundTransparency = 1
		edit_title.Position = UDim2.new(0, 15, 0, 10)
		edit_title.Size = UDim2.new(1, -30, 0, 20)
		edit_title.Font = get_theme() and get_theme().MapFont(Enum.Font.SourceSansBold) or Enum.Font.SourceSansBold
		edit_title.TextSize = 14
		edit_title.TextColor3 = settings_ref.Theme.Text
		edit_title.TextXAlignment = Enum.TextXAlignment.Left

		-- Cast type button toggle
		edit_type_btn = make_btn(edit_overlay, "Cast: STRING", 15, 40, 120, 20)
		edit_type_btn.ZIndex = 100
		
		local cast_menu = Instance.new("Frame", edit_overlay)
		cast_menu.BackgroundColor3 = settings_ref.Theme.Main1
		cast_menu.BorderSizePixel = 1
		cast_menu.BorderColor3 = settings_ref.Theme.Outline3
		cast_menu.Size = UDim2.new(0, 120, 0, 100)
		cast_menu.Position = UDim2.new(0, 15, 0, 62)
		cast_menu.Visible = false
		cast_menu.ZIndex = 105
		Instance.new("UIListLayout", cast_menu)
		
		local function add_cast_option(name)
			local opt = Instance.new("TextButton", cast_menu)
			opt.Size = UDim2.new(1, 0, 0, 20)
			opt.BorderSizePixel = 0
			opt.Font = Enum.Font.SourceSans
			opt.TextSize = 12
			opt.TextColor3 = settings_ref.Theme.Text
			opt.BackgroundColor3 = settings_ref.Theme.Main2
			opt.Text = name
			opt.ZIndex = 105
			
			opt.MouseEnter:Connect(function() opt.BackgroundColor3 = settings_ref.Theme.ButtonHover end)
			opt.MouseLeave:Connect(function() opt.BackgroundColor3 = settings_ref.Theme.Main2 end)
			opt.MouseButton1Click:Connect(function()
				edit_cast_type = name
				edit_type_btn.Text = "Cast: " .. name:upper()
				cast_menu.Visible = false
				
				if name == "boolean" then
					edit_input.Visible = false
					edit_check.Visible = true
				else
					edit_input.Visible = true
					edit_check.Visible = false
					if name == "nil" then edit_input.Text = "nil" end
				end
			end)
		end
		
		add_cast_option("string")
		add_cast_option("number")
		add_cast_option("boolean")
		add_cast_option("nil")
		add_cast_option("JSON")
		
		edit_type_btn.MouseButton1Click:Connect(function()
			cast_menu.Visible = not cast_menu.Visible
		end)

		edit_input = Instance.new("TextBox", edit_overlay)
		edit_input.BackgroundColor3 = settings_ref.Theme.Main1
		edit_input.BorderSizePixel = 0
		edit_input.Position = UDim2.new(0, 15, 0, 70)
		edit_input.Size = UDim2.new(1, -30, 0, 48)
		edit_input.Font = Enum.Font.Code
		edit_input.TextSize = 12
		edit_input.TextColor3 = settings_ref.Theme.Text
		edit_input.MultiLine = true
		edit_input.TextWrapped = true
		edit_input.Text = ""
		edit_input.ClearTextOnFocus = false
		edit_input.ZIndex = 100
		local pad_ei = Instance.new("UIPadding", edit_input)
		pad_ei.PaddingLeft = UDim.new(0, 6)
		pad_ei.PaddingTop = UDim.new(0, 4)
		if get_theme() then get_theme().ApplyRounding(edit_input, 4) end

		edit_check = Instance.new("TextButton", edit_overlay)
		edit_check.BorderSizePixel = 0
		edit_check.Font = Enum.Font.SourceSansBold
		edit_check.TextSize = 14
		edit_check.TextColor3 = Color3.new(1, 1, 1)
		edit_check.Position = UDim2.new(0, 15, 0, 70)
		edit_check.Size = UDim2.new(1, -30, 0, 32)
		edit_check.Visible = false
		edit_check.ZIndex = 100
		if get_theme() then get_theme().ApplyRounding(edit_check, 4) end
		
		edit_check.MouseButton1Click:Connect(function()
			if edit_check.Text == "True" then
				edit_check.Text = "False"
				edit_check.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
			else
				edit_check.Text = "True"
				edit_check.BackgroundColor3 = Color3.fromRGB(34, 197, 94)
			end
		end)

		edit_error = Instance.new("TextLabel", edit_overlay)
		edit_error.BackgroundTransparency = 1
		edit_error.Position = UDim2.new(0, 15, 0, 122)
		edit_error.Size = UDim2.new(1, -30, 0, 30)
		edit_error.Font = Enum.Font.SourceSans
		edit_error.TextSize = 11
		edit_error.TextColor3 = Color3.fromRGB(239, 68, 68)
		edit_error.TextWrapped = true
		edit_error.Text = ""
		edit_error.ZIndex = 100

		local save_btn = make_btn(edit_overlay, "Save", 15, 160, 120, 24)
		save_btn.ZIndex = 100
		save_btn.MouseButton1Click:Connect(save_edit)

		local cancel_btn = make_btn(edit_overlay, "Cancel", 165, 160, 120, 24)
		cancel_btn.ZIndex = 100
		cancel_btn.MouseButton1Click:Connect(function()
			edit_overlay.Visible = false
		end)

		-- Call Function Overlay
		call_overlay = Instance.new("Frame", window.GuiElems.Content)
		call_overlay.BackgroundColor3 = settings_ref.Theme.Main2
		call_overlay.BorderSizePixel = 1
		call_overlay.BorderColor3 = settings_ref.Theme.Outline2
		call_overlay.Size = UDim2.new(0, 320, 0, 250)
		call_overlay.Position = UDim2.new(0.5, -160, 0.5, -125)
		call_overlay.Visible = false
		call_overlay.ZIndex = 100
		if get_theme() then get_theme().ApplyRounding(call_overlay, 8) end

		call_func_name = Instance.new("TextLabel", call_overlay)
		call_func_name.BackgroundTransparency = 1
		call_func_name.Position = UDim2.new(0, 15, 0, 10)
		call_func_name.Size = UDim2.new(1, -30, 0, 20)
		call_func_name.Font = get_theme() and get_theme().MapFont(Enum.Font.SourceSansBold) or Enum.Font.SourceSansBold
		call_func_name.TextSize = 14
		call_func_name.TextColor3 = settings_ref.Theme.Text
		call_func_name.TextXAlignment = Enum.TextXAlignment.Left
		call_func_name.ZIndex = 100

		local arg_desc = Instance.new("TextLabel", call_overlay)
		arg_desc.BackgroundTransparency = 1
		arg_desc.Position = UDim2.new(0, 15, 0, 30)
		arg_desc.Size = UDim2.new(1, -30, 0, 16)
		arg_desc.Font = Enum.Font.SourceSans
		arg_desc.TextSize = 12
		arg_desc.TextColor3 = settings_ref.Theme.PlaceholderText
		arg_desc.Text = "Arguments (comma-separated expression: e.g. 1, 'text', workspace):"
		arg_desc.TextXAlignment = Enum.TextXAlignment.Left
		arg_desc.ZIndex = 100

		call_input = Instance.new("TextBox", call_overlay)
		call_input.BackgroundColor3 = settings_ref.Theme.Main1
		call_input.BorderSizePixel = 0
		call_input.Position = UDim2.new(0, 15, 0, 48)
		call_input.Size = UDim2.new(1, -30, 0, 28)
		call_input.Font = Enum.Font.Code
		call_input.TextSize = 11
		call_input.TextColor3 = settings_ref.Theme.Text
		call_input.Text = ""
		call_input.ClearTextOnFocus = false
		call_input.ZIndex = 100
		local pad_ci = Instance.new("UIPadding", call_input)
		pad_ci.PaddingLeft = UDim.new(0, 6)
		if get_theme() then get_theme().ApplyRounding(call_input, 4) end

		call_output = Instance.new("TextBox", call_overlay)
		call_output.BackgroundColor3 = settings_ref.Theme.Main1
		call_output.BorderSizePixel = 0
		call_output.Position = UDim2.new(0, 15, 0, 82)
		call_output.Size = UDim2.new(1, -30, 0, 120)
		call_output.Font = Enum.Font.Code
		call_output.TextSize = 11
		call_output.TextColor3 = settings_ref.Theme.Text
		call_output.TextEditable = false
		call_output.ClearTextOnFocus = false
		call_output.MultiLine = true
		call_output.TextWrapped = true
		call_output.Text = ""
		call_output.TextXAlignment = Enum.TextXAlignment.Left
		call_output.TextYAlignment = Enum.TextYAlignment.Top
		call_output.ZIndex = 100
		local pad_co = Instance.new("UIPadding", call_output)
		pad_co.PaddingLeft = UDim.new(0, 6)
		pad_co.PaddingTop = UDim.new(0, 4)
		if get_theme() then get_theme().ApplyRounding(call_output, 4) end

		call_exec_btn = make_btn(call_overlay, "Execute", 15, 210, 130, 26)
		call_exec_btn.ZIndex = 100
		call_exec_btn.MouseButton1Click:Connect(execute_call)

		local call_close_btn = make_btn(call_overlay, "Close", 175, 210, 130, 26)
		call_close_btn.ZIndex = 100
		call_close_btn.MouseButton1Click:Connect(function()
			call_overlay.Visible = false
		end)

		-- Detail panel button connections
		edit_btn.MouseButton1Click:Connect(open_edit_overlay)
		call_btn.MouseButton1Click:Connect(open_call_overlay)

		explore_btn.MouseButton1Click:Connect(function()
			if not explore_btn.Active or not selected_key or typeof(selected_val) ~= "Instance" then return end
			local exp = apps_ref.Explorer
			if exp and exp.Nodes and exp.Selection then
				local node = exp.Nodes[selected_val]
				if node then
					exp.MakeNodeVisible(node, true)
					exp.Selection:Set(node)
					exp.ViewNode(node)
				end
			end
		end)

		decompile_btn.MouseButton1Click:Connect(function()
			if not decompile_btn.Active or not selected_key or typeof(selected_val) ~= "Instance" or not selected_val:IsA("LuaSourceContainer") then return end
			local sv = apps_ref.Notepad
			if sv and sv.ViewScript then
				task.spawn(function()
					sv.ViewScript(selected_val)
					sv.Window:Show()
				end)
			end
		end)

		copy_btn.MouseButton1Click:Connect(function()
			if not selected_key or not setclipboard then return end
			setclipboard(safe_string(selected_val))
			copy_btn.Text = "Copied!"
			task.delay(1, function() copy_btn.Text = "Copy Value to Clipboard" end)
		end)

		rebuild_list()
		update_details(nil)

		window.OnActivate:Connect(function()
			if scroll_v then
				scroll_v.TotalSpace   = #log_frames
				scroll_v.VisibleSpace = math.floor(list_container.AbsoluteSize.Y / 37)
				scroll_v:Update()
			end
		end)
	end

	return editor
end

return {
	InitDeps      = initDeps,
	InitAfterMain = initAfterMain,
	Main          = main,
	PluginData    = plugin_data,
}
