local main_ref, lib_ref, apps_ref, settings_ref
local explorer_ref, properties_ref
 
local plugin_data = {
	name         = "RemoteSpy",
	FriendlyName = "Remote Spy",
}
 
local function initDeps(data)
	main_ref     = data.Main
	lib_ref      = data.Lib
	apps_ref     = data.Apps
	settings_ref = data.Settings
end
 
local function initAfterMain(t)
	explorer_ref   = t.Explorer
	properties_ref = t.Properties
end
 
local function safe_str(v)
	local t = typeof(v)
	if t == "Instance" then
		local parts, cur = {}, v
		while cur and cur ~= game do
			table.insert(parts, 1, cur.Name)
			cur = cur.Parent
		end
		table.insert(parts, 1, "game")
		return table.concat(parts, ".")
	elseif t == "string" then
		local s = #v > 100 and v:sub(1, 100) .. "…" or v
		return '"' .. s:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n') .. '"'
	elseif t == "table" then
		local out, n = {}, 0
		for k, val in pairs(v) do
			n = n + 1
			if n > 6 then out[n] = "…" break end
			out[n] = tostring(k) .. "=" .. safe_str(val)
		end
		return "{" .. table.concat(out, ", ") .. "}"
	else
		return tostring(v)
	end
end
 
local function args_str(args)
	local n = args.n or #args
	if n == 0 then return "()" end
	local out = {}
	for i = 1, n do out[i] = safe_str(args[i]) end
	return table.concat(out, ", ")
end
 
local function inst_path(obj)
	if not obj then return "?" end
	local parts, cur = {}, obj
	while cur and cur ~= game do
		table.insert(parts, 1, cur.Name)
		cur = cur.Parent
	end
	table.insert(parts, 1, "game")
	return table.concat(parts, ".")
end
 
local function main()
	local spy = {}
	spy.PluginData = plugin_data
 
	local logs        = {}
	local log_frames  = {}
	local tree_frames = {}
	local remote_stats = {}
	local expanded_paths = { game = true }
	local filter_text = ""
	local selected_path = ""
	local paused      = false
	local log_limit   = 400
	local active      = false
	local last_tree_rebuild = 0
 
	local namecall_orig = nil
	local hook_cons   = {}
	local seen        = {}
	setmetatable(seen, { __mode = "k" })
 
	local colors = {
		out_remote   = Color3.fromRGB(100, 200, 255),
		in_remote    = Color3.fromRGB(120, 255, 120),
		out_bindable = Color3.fromRGB(255, 200, 80),
		in_bindable  = Color3.fromRGB(255, 140, 60),
	}
 
	local remote_classes = {
		RemoteEvent           = true,
		RemoteFunction        = true,
		UnreliableRemoteEvent = true,
		BindableEvent         = true,
		BindableFunction      = true,
	}
 
	local out_methods = {
		FireServer = true, InvokeServer = true,
		fireServer = true, invokeServer = true,
		Fire = true, Invoke = true,
		fire = true, invoke = true,
	}
 
	local in_signals = {
		RemoteEvent           = "OnClientEvent",
		UnreliableRemoteEvent = "OnClientEvent",
		BindableEvent         = "Event",
	}
 
	local window, list_frame, tree_frame, scroll_v, status_label, detail_label, empty_label
	local rebuild_list
 
	local function color_for(dir, class_name)
		local is_bind = class_name == "BindableEvent" or class_name == "BindableFunction"
		if dir == "out" then
			return is_bind and colors.out_bindable or colors.out_remote
		else
			return is_bind and colors.in_bindable or colors.in_remote
		end
	end
 
	local function matches(entry)
		if selected_path ~= "" then
			if entry.path ~= selected_path and entry.path:sub(1, #selected_path + 1) ~= selected_path .. "." then
				return false
			end
		end
		if filter_text == "" then return true end
		local low = filter_text:lower()
		return entry.path:lower():find(low, 1, true)
			or entry.method:lower():find(low, 1, true)
			or entry.args:lower():find(low, 1, true)
	end

	local function is_remote_class(class_name)
		return remote_classes[class_name] == true
	end

	local function note_remote(inst, entry)
		local path = entry and entry.path or inst_path(inst)
		local stat = remote_stats[path]
		local created = false
		if not stat then
			created = true
			stat = {
				path = path,
				name = inst and inst.Name or path:match("[^%.]+$") or path,
				class = entry and entry.class or (inst and inst.ClassName or "Remote"),
				count = 0,
				last = "",
				inst = inst,
			}
			remote_stats[path] = stat
		end
		if entry then
			stat.count = stat.count + 1
			stat.last = entry.time .. " " .. entry.method
			stat.class = entry.class
			stat.inst = inst
		end
		return stat, created
	end

	local function update_detail()
		if not detail_label then return end
		if selected_path == "" then
			detail_label.Text = "All remotes"
		else
			local stat = remote_stats[selected_path]
			if stat then
				detail_label.Text = stat.class .. "  |  " .. stat.count .. " calls  |  " .. selected_path
			else
				detail_label.Text = selected_path
			end
		end
	end

	local function split_path(path)
		local parts = {}
		for part in string.gmatch(path, "[^%.]+") do
			parts[#parts + 1] = part
		end
		return parts
	end

	local function add_tree_path(root, stat)
		local cur = root
		local cur_path = ""
		local parts = split_path(stat.path)
		for i, part in ipairs(parts) do
			cur_path = cur_path == "" and part or (cur_path .. "." .. part)
			local child = cur.children[part]
			if not child then
				child = {
					name = part,
					path = cur_path,
					children = {},
					order = {},
					count = 0,
					remote = nil,
				}
				cur.children[part] = child
				cur.order[#cur.order + 1] = child
			end
			child.count = child.count + stat.count
			cur = child
			if i == #parts then
				cur.remote = stat
			end
		end
	end

	local function rebuild_tree()
		if not tree_frame then return end
		for _, f in ipairs(tree_frames) do f:Destroy() end
		tree_frames = {}

		local root = { children = {}, order = {} }
		for _, stat in pairs(remote_stats) do
			add_tree_path(root, stat)
		end

		local function sort_children(node)
			table.sort(node.order, function(a, b)
				if (a.remote ~= nil) ~= (b.remote ~= nil) then
					return a.remote == nil
				end
				return a.name:lower() < b.name:lower()
			end)
			for _, child in ipairs(node.order) do sort_children(child) end
		end
		sort_children(root)

		local row_count = 0
		local function add_row(node, depth)
			row_count = row_count + 1
			local has_children = #node.order > 0
			local is_selected = selected_path == node.path
			local is_leaf = node.remote ~= nil and not has_children

			local row = Instance.new("TextButton")
			row.AutoButtonColor = false
			row.BackgroundColor3 = is_selected and Color3.fromRGB(42, 78, 124) or Color3.fromRGB(26, 30, 36)
			row.BackgroundTransparency = is_selected and 0 or 1
			row.BorderSizePixel = 0
			row.Size = UDim2.new(1, -4, 0, 24)
			row.Text = ""
			row.LayoutOrder = row_count
			row.Parent = tree_frame

			local mark = Instance.new("TextLabel", row)
			mark.BackgroundTransparency = 1
			mark.Position = UDim2.new(0, 4 + depth * 12, 0, 0)
			mark.Size = UDim2.new(0, 14, 1, 0)
			mark.Font = Enum.Font.Code
			mark.TextSize = 12
			mark.TextColor3 = has_children and Color3.fromRGB(170, 180, 192) or color_for("out", node.remote and node.remote.class or "RemoteEvent")
			mark.Text = has_children and (expanded_paths[node.path] and "v" or ">") or "-"

			local name = Instance.new("TextLabel", row)
			name.BackgroundTransparency = 1
			name.Position = UDim2.new(0, 20 + depth * 12, 0, 0)
			name.Size = UDim2.new(1, -74 - depth * 12, 1, 0)
			name.Font = is_leaf and Enum.Font.SourceSansBold or Enum.Font.SourceSans
			name.TextSize = 13
			name.TextColor3 = node.remote and Color3.fromRGB(232, 236, 242) or Color3.fromRGB(180, 188, 200)
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.TextTruncate = Enum.TextTruncate.AtEnd
			name.Text = node.name

			local count = Instance.new("TextLabel", row)
			count.BackgroundTransparency = 1
			count.Position = UDim2.new(1, -50, 0, 0)
			count.Size = UDim2.new(0, 46, 1, 0)
			count.Font = Enum.Font.Code
			count.TextSize = 11
			count.TextColor3 = Color3.fromRGB(130, 142, 158)
			count.TextXAlignment = Enum.TextXAlignment.Right
			count.Text = node.count > 0 and tostring(node.count) or ""

			row.MouseEnter:Connect(function()
				if selected_path ~= node.path then
					row.BackgroundTransparency = 0
					row.BackgroundColor3 = Color3.fromRGB(38, 44, 52)
				end
			end)
			row.MouseLeave:Connect(function()
				if selected_path ~= node.path then
					row.BackgroundTransparency = 1
				end
			end)
			row.MouseButton1Click:Connect(function()
				if has_children then
					expanded_paths[node.path] = not expanded_paths[node.path]
				end
				selected_path = node.path
				update_detail()
				rebuild_tree()
				rebuild_list()
			end)

			tree_frames[#tree_frames + 1] = row

			if has_children and expanded_paths[node.path] then
				for _, child in ipairs(node.order) do
					add_row(child, depth + 1)
				end
			end
		end

		for _, child in ipairs(root.order) do
			add_row(child, 0)
		end
		tree_frame.Size = UDim2.new(1, -4, 0, math.max(24, row_count * 24))
		if tree_frame.Parent then
			tree_frame.Parent.CanvasSize = UDim2.new(0, 0, 0, math.max(24, row_count * 24))
		end
	end
 
	local function push_row(entry)
		if not list_frame then return end
		if empty_label then empty_label.Visible = false end
		local col = color_for(entry.dir, entry.class)
 
		local row = Instance.new("Frame")
		row.BackgroundColor3 = Color3.fromRGB(38, 38, 38)
		row.BorderSizePixel  = 0
		row.Size             = UDim2.new(1, 0, 0, 36)
		row.ClipsDescendants = true
 
		local badge = Instance.new("Frame", row)
		badge.BackgroundColor3 = col
		badge.BorderSizePixel  = 0
		badge.Size             = UDim2.new(0, 3, 1, 0)
 
		local tl = Instance.new("TextLabel", row)
		tl.BackgroundTransparency = 1
		tl.Position  = UDim2.new(0, 8, 0, 0)
		tl.Size      = UDim2.new(0, 55, 0, 18)
		tl.Font      = Enum.Font.Code
		tl.TextSize  = 11
		tl.TextColor3 = Color3.fromRGB(130, 130, 130)
		tl.TextXAlignment = Enum.TextXAlignment.Left
		tl.Text = entry.time
 
		local dl = Instance.new("TextLabel", row)
		dl.BackgroundTransparency = 1
		dl.Position  = UDim2.new(0, 66, 0, 0)
		dl.Size      = UDim2.new(0, 150, 0, 18)
		dl.Font      = Enum.Font.SourceSansBold
		dl.TextSize  = 13
		dl.TextColor3 = col
		dl.TextXAlignment = Enum.TextXAlignment.Left
		dl.Text = (entry.dir == "out" and "outgoing" or "incoming") .. "  [" .. entry.class .. "]"
 
		local ml = Instance.new("TextLabel", row)
		ml.BackgroundTransparency = 1
		ml.Position  = UDim2.new(0, 220, 0, 0)
		ml.Size      = UDim2.new(0, 120, 0, 18)
		ml.Font      = Enum.Font.Code
		ml.TextSize  = 12
		ml.TextColor3 = Color3.fromRGB(200, 200, 200)
		ml.TextXAlignment = Enum.TextXAlignment.Left
		ml.Text = ":" .. entry.method .. "()"
 
		local pl = Instance.new("TextLabel", row)
		pl.BackgroundTransparency = 1
		pl.Position  = UDim2.new(0, 8, 0, 19)
		pl.Size      = UDim2.new(0.5, -10, 0, 15)
		pl.Font      = Enum.Font.Code
		pl.TextSize  = 11
		pl.TextColor3 = Color3.fromRGB(160, 160, 160)
		pl.TextXAlignment = Enum.TextXAlignment.Left
		pl.TextTruncate = Enum.TextTruncate.AtEnd
		pl.Text = entry.path
 
		local al = Instance.new("TextLabel", row)
		al.BackgroundTransparency = 1
		al.Position  = UDim2.new(0.5, 0, 0, 19)
		al.Size      = UDim2.new(0.5, -6, 0, 15)
		al.Font      = Enum.Font.Code
		al.TextSize  = 11
		al.TextColor3 = Color3.fromRGB(210, 210, 140)
		al.TextXAlignment = Enum.TextXAlignment.Right
		al.TextTruncate = Enum.TextTruncate.AtEnd
		al.Text = entry.args
 
		row.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseMovement then
				row.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
			elseif i.UserInputType == Enum.UserInputType.MouseButton2 and setclipboard then
				setclipboard(entry.path)
			end
		end)
		row.InputEnded:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseMovement then
				row.BackgroundColor3 = Color3.fromRGB(38, 38, 38)
			end
		end)
 
		row.LayoutOrder = #log_frames + 1
		row.Parent = list_frame
		table.insert(log_frames, row)
	end
 
	local function add_log(dir, inst, method, raw_args)
		if not active or paused then return end

		local entry = {
			time   = os.date("%H:%M:%S"),
			dir    = dir,
			path   = inst_path(inst),
			class  = inst.ClassName,
			method = method,
			args   = args_str(raw_args),
		}
		local _, created_remote = note_remote(inst, entry)
 
		logs[#logs + 1] = entry
		if #logs > log_limit then
			table.remove(logs, 1)
		end
 
		if window and not window.Closed and matches(entry) then
			push_row(entry)
			if scroll_v then
				scroll_v.Index = math.max(0, #log_frames - scroll_v.VisibleSpace)
				scroll_v:Update()
			end
		end
 
		if status_label then
			status_label.Text = #logs .. " logs"
		end
		local now = tick()
		if created_remote or now - last_tree_rebuild > 0.25 then
			last_tree_rebuild = now
			rebuild_tree()
		end
		update_detail()
	end
 
	rebuild_list = function()
		for _, f in ipairs(log_frames) do f:Destroy() end
		log_frames = {}
		local visible_count = 0
		for _, e in ipairs(logs) do
			if matches(e) then
				visible_count = visible_count + 1
				push_row(e)
			end
		end
		if empty_label then
			empty_label.Visible = visible_count == 0
			if selected_path ~= "" then
				empty_label.Text = "No calls for selected node"
			elseif filter_text ~= "" then
				empty_label.Text = "No calls match filter"
			else
				empty_label.Text = "Start spy to capture calls"
			end
		end
		if scroll_v then
			scroll_v.TotalSpace = #log_frames
			scroll_v.Index = 0
			scroll_v:Update()
		end
	end
 
	local function hook_instance(inst)
		if seen[inst] then return end
		local sig = in_signals[inst.ClassName]
		if not sig then return end
		seen[inst] = true
		note_remote(inst)
 
		local ok, con = pcall(function()
			return inst[sig]:Connect(function(...)
				add_log("in", inst, sig, table.pack(...))
			end)
		end)
		if ok and con then
			hook_cons[#hook_cons + 1] = con
		end
	end
 
	local function start()
		if active then return end
		active = true
 
		if hookmetamethod and not namecall_orig then
			local ok, orig = pcall(hookmetamethod, game, "__namecall", function(self, ...)
				local method = getnamecallmethod and getnamecallmethod() or ""
				if active
					and typeof(self) == "Instance"
					and remote_classes[self.ClassName]
					and out_methods[method]
				then
					add_log("out", self, method, table.pack(...))
				end
				return namecall_orig(self, ...)
			end)
			if ok then namecall_orig = orig end
		end
 
		local ok, descs = pcall(game.GetDescendants, game)
		if ok then
			for _, inst in ipairs(descs) do
				if typeof(inst) == "Instance" and is_remote_class(inst.ClassName) then
					note_remote(inst)
				end
				hook_instance(inst)
			end
		end
 
		if getnilinstances then
			local ok2, nil_insts = pcall(getnilinstances)
			if ok2 then
				for _, inst in ipairs(nil_insts) do
					if typeof(inst) == "Instance" and is_remote_class(inst.ClassName) then
						note_remote(inst)
					end
					hook_instance(inst)
				end
			end
		end
		rebuild_tree()
		update_detail()
 
		local da_con = game.DescendantAdded:Connect(function(inst)
			if active then
				if typeof(inst) == "Instance" and is_remote_class(inst.ClassName) then
					note_remote(inst)
					rebuild_tree()
				end
				hook_instance(inst)
			end
		end)
		hook_cons[#hook_cons + 1] = da_con
	end
 
	local function stop()
		if not active then return end
		active = false
 
		for _, con in ipairs(hook_cons) do
			pcall(function() con:Disconnect() end)
		end
		hook_cons = {}
 
		seen = {}
		setmetatable(seen, { __mode = "k" })
	end
 
	local function make_btn(parent, text, x, w)
		local btn = Instance.new("TextButton")
		btn.BackgroundColor3 = Color3.fromRGB(43, 49, 58)
		btn.BorderSizePixel  = 0
		btn.Font             = Enum.Font.SourceSans
		btn.TextSize         = 13
		btn.TextColor3       = Color3.fromRGB(238, 242, 247)
		btn.Text             = text
		btn.AutoButtonColor  = false
		btn.Size             = UDim2.new(0, w, 0, 18)
		btn.Position         = UDim2.new(0, x, 0, 2)
		btn.Parent           = parent
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 3)
		btn.MouseEnter:Connect(function() btn.BackgroundColor3 = Color3.fromRGB(55, 63, 75) end)
		btn.MouseLeave:Connect(function() btn.BackgroundColor3 = Color3.fromRGB(43, 49, 58) end)
		return btn
	end
 
	spy.Init = function()
		window = lib_ref.Window.new()
		window:SetTitle("Remote Spy")
		window:Resize(760, 460)
		spy.Window = window
 
		local toolbar = Instance.new("Frame")
		toolbar.BackgroundColor3 = Color3.fromRGB(28, 32, 38)
		toolbar.BorderSizePixel  = 0
		toolbar.Size             = UDim2.new(1, 0, 0, 26)
		toolbar.Parent           = window.GuiElems.Content
 
		local start_btn = make_btn(toolbar, "▶ start",  2,  58)
		local stop_btn  = make_btn(toolbar, "■ stop",   64, 50)
		local clear_btn = make_btn(toolbar, "clear",   118, 42)
		local pause_btn = make_btn(toolbar, "pause",   164, 42)
		local copy_btn  = make_btn(toolbar, "copy all",210, 58)
		start_btn.Text = "Start"
		start_btn.Position = UDim2.new(0, 4, 0, 4)
		stop_btn.Text = "Stop"
		stop_btn.Position = UDim2.new(0, 66, 0, 4)
		clear_btn.Text = "Clear"
		clear_btn.Size = UDim2.new(0, 48, 0, 18)
		clear_btn.Position = UDim2.new(0, 122, 0, 4)
		pause_btn.Text = "Pause"
		pause_btn.Size = UDim2.new(0, 50, 0, 18)
		pause_btn.Position = UDim2.new(0, 174, 0, 4)
		copy_btn.Text = "Copy"
		copy_btn.Size = UDim2.new(0, 48, 0, 18)
		copy_btn.Position = UDim2.new(0, 228, 0, 4)
		local all_btn = make_btn(toolbar, "All", 280, 42)
		all_btn.Position = UDim2.new(0, 280, 0, 4)
 
		status_label = Instance.new("TextLabel")
		status_label.BackgroundTransparency = 1
		status_label.Font       = Enum.Font.SourceSans
		status_label.TextSize   = 12
		status_label.TextColor3 = Color3.fromRGB(142, 151, 164)
		status_label.TextXAlignment = Enum.TextXAlignment.Right
		status_label.Size       = UDim2.new(1, -330, 1, 0)
		status_label.Position   = UDim2.new(0, 326, 0, 0)
		status_label.Text       = "0 logs"
		status_label.Parent     = toolbar
 
		local search_bar = Instance.new("Frame")
		search_bar.BackgroundColor3 = Color3.fromRGB(20, 23, 29)
		search_bar.BorderSizePixel  = 0
		search_bar.Size             = UDim2.new(1, 0, 0, 26)
		search_bar.Position         = UDim2.new(0, 0, 0, 26)
		search_bar.Parent           = window.GuiElems.Content
 
		local search_box = Instance.new("TextBox", search_bar)
		search_box.BackgroundTransparency = 1
		search_box.PlaceholderText  = "filter…"
		search_box.PlaceholderColor3 = Color3.fromRGB(142, 151, 164)
		search_box.Text             = ""
		search_box.Font             = Enum.Font.Code
		search_box.TextSize         = 13
		search_box.TextColor3       = Color3.fromRGB(238, 242, 247)
		search_box.TextXAlignment   = Enum.TextXAlignment.Left
		search_box.ClearTextOnFocus = false
		search_box.Size             = UDim2.new(1, -14, 1, 0)
		search_box.Position         = UDim2.new(0, 8, 0, 0)
		search_box.PlaceholderText  = "filter path, method, or args"
		search_box:GetPropertyChangedSignal("Text"):Connect(function()
			filter_text = search_box.Text
			rebuild_list()
		end)

		local body = Instance.new("Frame")
		body.BackgroundColor3 = Color3.fromRGB(23, 27, 33)
		body.BorderSizePixel = 0
		body.Position = UDim2.new(0, 0, 0, 52)
		body.Size = UDim2.new(1, 0, 1, -52)
		body.Parent = window.GuiElems.Content

		local tree_panel = Instance.new("Frame")
		tree_panel.BackgroundColor3 = Color3.fromRGB(20, 23, 29)
		tree_panel.BorderSizePixel = 0
		tree_panel.Size = UDim2.new(0, 218, 1, 0)
		tree_panel.Parent = body

		local tree_title = Instance.new("TextLabel", tree_panel)
		tree_title.BackgroundTransparency = 1
		tree_title.Position = UDim2.new(0, 8, 0, 0)
		tree_title.Size = UDim2.new(1, -16, 0, 28)
		tree_title.Font = Enum.Font.SourceSansBold
		tree_title.TextSize = 14
		tree_title.TextColor3 = Color3.fromRGB(238, 242, 247)
		tree_title.TextXAlignment = Enum.TextXAlignment.Left
		tree_title.Text = "Remote tree"

		local tree_scroll = Instance.new("ScrollingFrame")
		tree_scroll.Active = true
		tree_scroll.BackgroundTransparency = 1
		tree_scroll.BorderSizePixel = 0
		tree_scroll.Position = UDim2.new(0, 4, 0, 30)
		tree_scroll.Size = UDim2.new(1, -4, 1, -34)
		tree_scroll.ScrollBarImageColor3 = Color3.fromRGB(70, 82, 98)
		tree_scroll.ScrollBarThickness = 4
		tree_scroll.CanvasSize = UDim2.new(0, 0, 0, 24)
		tree_scroll.Parent = tree_panel

		tree_frame = Instance.new("Frame")
		tree_frame.BackgroundTransparency = 1
		tree_frame.Size = UDim2.new(1, -4, 0, 24)
		tree_frame.Parent = tree_scroll

		local tree_layout = Instance.new("UIListLayout", tree_frame)
		tree_layout.SortOrder = Enum.SortOrder.LayoutOrder
		tree_layout.Padding = UDim.new(0, 1)

		local split_line = Instance.new("Frame", body)
		split_line.BackgroundColor3 = Color3.fromRGB(18, 21, 26)
		split_line.BorderSizePixel = 0
		split_line.Position = UDim2.new(0, 218, 0, 0)
		split_line.Size = UDim2.new(0, 1, 1, 0)

		local right_panel = Instance.new("Frame")
		right_panel.BackgroundColor3 = Color3.fromRGB(23, 27, 33)
		right_panel.BorderSizePixel = 0
		right_panel.Position = UDim2.new(0, 219, 0, 0)
		right_panel.Size = UDim2.new(1, -219, 1, 0)
		right_panel.Parent = body

		detail_label = Instance.new("TextLabel", right_panel)
		detail_label.BackgroundColor3 = Color3.fromRGB(28, 32, 38)
		detail_label.BorderSizePixel = 0
		detail_label.Position = UDim2.new(0, 0, 0, 0)
		detail_label.Size = UDim2.new(1, 0, 0, 28)
		detail_label.Font = Enum.Font.Code
		detail_label.TextSize = 12
		detail_label.TextColor3 = Color3.fromRGB(180, 188, 200)
		detail_label.TextXAlignment = Enum.TextXAlignment.Left
		detail_label.TextTruncate = Enum.TextTruncate.AtEnd
		detail_label.Text = "All remotes"
 
		local list_container = Instance.new("Frame")
		list_container.BackgroundColor3 = Color3.fromRGB(23, 27, 33)
		list_container.BorderSizePixel  = 0
		list_container.Size             = UDim2.new(1, -16, 1, -28)
		list_container.Position         = UDim2.new(0, 0, 0, 28)
		list_container.ClipsDescendants = true
		list_container.Parent           = right_panel
 
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
		empty_label.Font = Enum.Font.SourceSans
		empty_label.TextSize = 14
		empty_label.TextColor3 = Color3.fromRGB(142, 151, 164)
		empty_label.Text = "Start spy to capture calls"
		empty_label.Visible = true
 
		scroll_v = lib_ref.ScrollBar.new()
		scroll_v.WheelIncrement  = 3
		scroll_v.Gui.Position    = UDim2.new(1, -16, 0, 28)
		scroll_v.Gui.Size        = UDim2.new(0, 16, 1, -28)
		scroll_v.Gui.Parent      = right_panel
		scroll_v:SetScrollFrame(list_container)
		scroll_v.Scrolled:Connect(function()
			list_frame.Position = UDim2.new(0, 0, 0, -scroll_v.Index * 37)
		end)
 
		start_btn.MouseButton1Click:Connect(function()
			start()
			start_btn.BackgroundColor3 = Color3.fromRGB(28, 95, 48)
			start_btn.Text = "▶ active"
			stop_btn.BackgroundColor3  = Color3.fromRGB(55, 55, 55)
			stop_btn.Text  = "■ stop"
		end)
 
		stop_btn.MouseButton1Click:Connect(function()
			stop()
			start_btn.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
			start_btn.Text = "▶ start"
			stop_btn.BackgroundColor3  = Color3.fromRGB(100, 38, 38)
			stop_btn.Text  = "■ stopped"
		end)
 
		clear_btn.MouseButton1Click:Connect(function()
			logs = {}
			for _, f in ipairs(log_frames) do f:Destroy() end
			log_frames = {}
			status_label.Text = "0 logs"
		end)
 
		pause_btn.MouseButton1Click:Connect(function()
			paused = not paused
			pause_btn.Text = paused and "resume" or "pause"
			pause_btn.BackgroundColor3 = paused
				and Color3.fromRGB(95, 75, 20)
				or  Color3.fromRGB(55, 55, 55)
		end)

		start_btn.MouseButton1Click:Connect(function()
			start_btn.Text = "Active"
			stop_btn.Text = "Stop"
			stop_btn.BackgroundColor3 = Color3.fromRGB(43, 49, 58)
			rebuild_tree()
			rebuild_list()
		end)

		stop_btn.MouseButton1Click:Connect(function()
			start_btn.Text = "Start"
			start_btn.BackgroundColor3 = Color3.fromRGB(43, 49, 58)
			stop_btn.Text = "Stopped"
		end)

		clear_btn.MouseButton1Click:Connect(function()
			for _, stat in pairs(remote_stats) do
				stat.count = 0
				stat.last = ""
			end
			rebuild_tree()
			rebuild_list()
			update_detail()
		end)

		pause_btn.MouseButton1Click:Connect(function()
			pause_btn.Text = paused and "Resume" or "Pause"
			if not paused then
				pause_btn.BackgroundColor3 = Color3.fromRGB(43, 49, 58)
			end
		end)

		all_btn.MouseButton1Click:Connect(function()
			selected_path = ""
			update_detail()
			rebuild_tree()
			rebuild_list()
		end)
 
		copy_btn.MouseButton1Click:Connect(function()
			if not setclipboard then return end
			local lines = {}
			for _, e in ipairs(logs) do
				lines[#lines + 1] = string.format("[%s] %s %s:%s() | %s",
					e.time, e.dir, e.path, e.method, e.args)
			end
			setclipboard(table.concat(lines, "\n"))
		end)

		rebuild_tree()
		update_detail()
		rebuild_list()
 
		window.OnActivate:Connect(function()
			if scroll_v then
				scroll_v.TotalSpace   = #log_frames
				scroll_v.VisibleSpace = math.floor(list_container.AbsoluteSize.Y / 37)
				scroll_v:Update()
			end
		end)
	end
 
	return spy
end
 
return {
	InitDeps      = initDeps,
	InitAfterMain = initAfterMain,
	Main          = main,
	PluginData    = plugin_data,
}
 
