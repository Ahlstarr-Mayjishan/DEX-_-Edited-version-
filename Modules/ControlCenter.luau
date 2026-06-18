--!nocheck
--[[
	Control Center App Module

	Tracks heavy DEX++ tools and provides quick safety controls.
]]

local Main, Lib, Apps, Settings
local env, service, createSimple

local function initDeps(data)
	Main = data.Main
	Lib = data.Lib
	Apps = data.Apps
	Settings = data.Settings
	env = data.env
	service = data.service
	createSimple = data.createSimple
end

local function initAfterMain()
end

local function main()
	local ControlCenter = {}
	local window, statusLabel, overviewFrame, modulesFrame, timelineFrame, rulesFrame
	local rows = {}
	local timeline = {}
	local activeTab = "Overview"
	local currentFps = 0
	local heartbeatCon
	local lastHelperCheck = 0
	local helperStatus = {Status = "unknown", Indexed = 0, File = ""}

	local function nowText()
		return os.date("%H:%M:%S")
	end

	local function addTimeline(text)
		table.insert(timeline, 1, "[" .. nowText() .. "] " .. tostring(text))
		while #timeline > 80 do table.remove(timeline) end
	end

	local function setStatus(text)
		if statusLabel then
			statusLabel.Text = tostring(text)
		end
		addTimeline(text)
	end

	local function clear(frame)
		if not frame then return end
		for _, child in ipairs(frame:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	local function button(parent, text, x, y, w, h, callback)
		local b = createSimple("TextButton", {
			AutoButtonColor = false,
			BackgroundColor3 = Settings.Theme.Button,
			BorderColor3 = Settings.Theme.Outline2,
			Font = Enum.Font.SourceSansBold,
			Position = UDim2.new(0, x, 0, y),
			Size = UDim2.new(0, w, 0, h),
			Text = text,
			TextColor3 = Settings.Theme.Text,
			TextSize = 13,
			Parent = parent
		})
		Lib.ButtonAnim(b, {
			Mode = 2,
			StartColor = Settings.Theme.Button,
			HoverColor = Settings.Theme.ButtonHover,
			PressColor = Settings.Theme.ButtonPress,
			OutlineColor = Settings.Theme.Outline2
		})
		b.MouseButton1Click:Connect(callback)
		return b
	end

	local function label(parent, text, x, y, w, h, color, bold)
		return createSimple("TextLabel", {
			BackgroundTransparency = 1,
			Font = bold and Enum.Font.SourceSansBold or Enum.Font.SourceSans,
			Position = UDim2.new(0, x, 0, y),
			Size = UDim2.new(0, w, 0, h),
			Text = text,
			TextColor3 = color or Settings.Theme.Text,
			TextSize = 13,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = parent
		})
	end

	local function card(parent, x, y, w, h, title, value, detail, color)
		local frame = createSimple("Frame", {
			BackgroundColor3 = Settings.Theme.Main1,
			BorderColor3 = Settings.Theme.Outline1,
			Position = UDim2.new(0, x, 0, y),
			Size = UDim2.new(0, w, 0, h),
			Parent = parent
		})
		label(frame, title, 8, 4, w - 16, 18, Settings.Theme.PlaceholderText, false)
		label(frame, value, 8, 23, w - 16, 24, color or Settings.Theme.Text, true).TextSize = 18
		label(frame, detail or "", 8, 50, w - 16, 18, Settings.Theme.PlaceholderText, false).TextSize = 12
		return frame
	end

	local function decodeJson(body)
		local http = service and service.HttpService
		if not http then
			local ok, resolved = pcall(game.GetService, game, "HttpService")
			if ok then
				http = resolved
			end
		end
		if not http then return nil end
		local ok, decoded = pcall(function()
			return http:JSONDecode(body)
		end)
		return ok and decoded or nil
	end

	local function refreshHelperStatus(force)
		if not env.HelperServer or not env.HelperServer.IndexStatus then
			helperStatus = {Status = "unavailable", Indexed = 0, File = ""}
			return helperStatus
		end
		if not force and os.clock() - lastHelperCheck < 2 then
			return helperStatus
		end
		lastHelperCheck = os.clock()
		local active = true
		if env.HelperServer.IsActive then
			active = env.HelperServer.IsActive(false)
		end
		if not active then
			helperStatus = {Status = "offline", Indexed = 0, File = ""}
			return helperStatus
		end
		local ok, body = pcall(env.HelperServer.IndexStatus)
		local decoded = ok and decodeJson(body) or nil
		if decoded and decoded.ok then
			helperStatus = {
				Status = "active",
				Indexed = tonumber(decoded.scripts or decoded.indexed or 0) or 0,
				File = tostring(decoded.file or "")
			}
		else
			helperStatus = {Status = "active", Indexed = 0, File = ""}
		end
		return helperStatus
	end

	local function openTool(name)
		local control = Main.MenuApps and Main.MenuApps[name]
		if control and control.Enable then
			control.Enable()
			return true
		end
		local app = Apps[name:gsub("%s+", "")] or Apps[name]
		if app and app.Window then
			app.Window:Show()
			return true
		end
		return false
	end

	local function panicStop()
		if Apps.CodeSearch and Apps.CodeSearch.Stop then
			pcall(Apps.CodeSearch.Stop)
		end
		if Apps.ThreadManager and Apps.ThreadManager.StopAll then
			pcall(Apps.ThreadManager.StopAll)
		end
		Settings.Decompiler.CodeSearchLowImpact = true
		Settings.Decompiler.HelperLogChanges = false
		Settings.Decompiler.HelperLogRateLimit = math.min(tonumber(Settings.Decompiler.HelperLogRateLimit or 5) or 5, 5)
		setStatus("Panic stop: stopped known heavy jobs, enabled Low Impact, disabled helper property logging.")
	end

	local function applyPreset(name)
		if name == "Play" then
			Settings.Decompiler.CodeSearchLowImpact = true
			Settings.Decompiler.HelperLogChanges = false
			Settings.Decompiler.HelperLogRateLimit = 0
			setStatus("Preset applied: Play Mode.")
		elseif name == "Research" then
			Settings.Decompiler.CodeSearchLowImpact = true
			Settings.Decompiler.HelperLogChanges = false
			Settings.Decompiler.HelperLogRateLimit = 5
			setStatus("Preset applied: Research Mode.")
		elseif name == "Heavy" then
			Settings.Decompiler.CodeSearchLowImpact = false
			Settings.Decompiler.HelperLogChanges = false
			Settings.Decompiler.HelperLogRateLimit = 5
			setStatus("Preset applied: Heavy Analysis. Full index can lag the client.")
		end
		ControlCenter.Refresh()
	end

	local function renderOverview()
		clear(overviewFrame)
		local helper = refreshHelperStatus(false)
		local lowImpact = Settings.Decompiler.CodeSearchLowImpact ~= false
		local helperLog = Settings.Decompiler.HelperLogChanges == true
		local fpsColor = currentFps >= 50 and Color3.fromRGB(34, 197, 94) or (currentFps >= 30 and Color3.fromRGB(234, 179, 8) or Settings.Theme.Important)
		card(overviewFrame, 8, 8, 170, 76, "FPS", tostring(math.floor(currentFps + 0.5)), "live heartbeat estimate", fpsColor)
		card(overviewFrame, 186, 8, 170, 76, "Helper", helper.Status, tostring(helper.Indexed) .. " indexed", helper.Status == "active" and Color3.fromRGB(34, 197, 94) or Settings.Theme.Important)
		card(overviewFrame, 364, 8, 170, 76, "Code Search", lowImpact and "Low Impact" or "Full Index", lowImpact and "cache/helper only" or "may decompile", lowImpact and Color3.fromRGB(34, 197, 94) or Color3.fromRGB(234, 179, 8))
		card(overviewFrame, 542, 8, 170, 76, "Helper Logging", helperLog and "ON" or "OFF", tostring(Settings.Decompiler.HelperLogRateLimit or 5) .. " logs/s cap", helperLog and Color3.fromRGB(234, 179, 8) or Color3.fromRGB(34, 197, 94))
		button(overviewFrame, "Panic Stop", 8, 102, 110, 26, panicStop)
		button(overviewFrame, "Force Low Impact", 126, 102, 130, 26, function()
			Settings.Decompiler.CodeSearchLowImpact = true
			setStatus("Low Impact lock applied.")
			ControlCenter.Refresh()
		end)
		button(overviewFrame, "Disable Helper Log", 264, 102, 138, 26, function()
			Settings.Decompiler.HelperLogChanges = false
			setStatus("Helper property logging disabled.")
			ControlCenter.Refresh()
		end)
		button(overviewFrame, "Refresh", 410, 102, 86, 26, function()
			refreshHelperStatus(true)
			ControlCenter.Refresh()
		end)
		label(overviewFrame, "Presets", 8, 145, 110, 20, Settings.Theme.Text, true)
		button(overviewFrame, "Play Mode", 8, 170, 110, 24, function() applyPreset("Play") end)
		button(overviewFrame, "Research", 126, 170, 110, 24, function() applyPreset("Research") end)
		button(overviewFrame, "Heavy Analysis", 244, 170, 126, 24, function() applyPreset("Heavy") end)
		local warnings = {}
		if not lowImpact then warnings[#warnings + 1] = "Full Code Search index is enabled." end
		if helperLog then warnings[#warnings + 1] = "Property helper logging is enabled." end
		if currentFps > 0 and currentFps < 30 then warnings[#warnings + 1] = "FPS is low; avoid full index/deep scans." end
		if #warnings == 0 then warnings[#warnings + 1] = "No active safety warnings." end
		label(overviewFrame, "Warnings", 8, 214, 120, 20, Settings.Theme.Text, true)
		for i, warning in ipairs(warnings) do
			label(overviewFrame, "- " .. warning, 12, 236 + (i - 1) * 18, 690, 18, i == 1 and (#warnings == 1 and Settings.Theme.PlaceholderText or Settings.Theme.Important) or Settings.Theme.Important, false)
		end
	end

	local function addModuleRow(parent, y, name, state, load, detail, openName)
		local row = createSimple("Frame", {
			BackgroundColor3 = Settings.Theme.Main1,
			BorderColor3 = Settings.Theme.Outline1,
			Position = UDim2.new(0, 8, 0, y),
			Size = UDim2.new(1, -16, 0, 34),
			Parent = parent
		})
		label(row, name, 8, 0, 150, 34, Settings.Theme.Text, true)
		label(row, state, 170, 0, 90, 34, state == "active" and Color3.fromRGB(34, 197, 94) or Settings.Theme.PlaceholderText, false)
		label(row, load, 270, 0, 86, 34, load == "high" and Settings.Theme.Important or Settings.Theme.PlaceholderText, false)
		label(row, detail, 364, 0, 230, 34, Settings.Theme.PlaceholderText, false)
		local openButton = button(row, "Open", 0, 6, 58, 22, function()
			openTool(openName or name)
		end)
		openButton.Position = UDim2.new(1, -70, 0, 6)
		return row
	end

	local function renderModules()
		clear(modulesFrame)
		local helper = refreshHelperStatus(false)
		addModuleRow(modulesFrame, 8, "Code Search", Settings.Decompiler.CodeSearchLowImpact ~= false and "guarded" or "full", Settings.Decompiler.CodeSearchLowImpact ~= false and "low" or "high", "Index mode controls decompile pressure.", "Code Search")
		addModuleRow(modulesFrame, 48, "Property Tracker", Settings.Decompiler.HelperLogChanges == true and "logging" or "local", Settings.Decompiler.HelperLogChanges == true and "medium" or "low", "Helper log cap: " .. tostring(Settings.Decompiler.HelperLogRateLimit or 5) .. "/s", "Property Tracker")
		addModuleRow(modulesFrame, 88, "Helper Server", helper.Status, helper.Status == "active" and "low" or "off", tostring(helper.Indexed) .. " indexed | " .. helper.File, "Task Router")
		addModuleRow(modulesFrame, 128, "Thread Manager", Apps.ThreadManager and "available" or "missing", "low", "Open for coroutine/thread inspection.", "Thread Manager")
		addModuleRow(modulesFrame, 168, "Remote Spy", Apps.RemoteSpy and "available" or "plugin", "variable", "Use Stop/Pause inside the spy while playing.", "Remote Spy")
		addModuleRow(modulesFrame, 208, "Runtime Inspector", Apps.RuntimeInspector and "available" or "missing", "variable", "Prefer snapshots over continuous deep scans.", "Runtime Inspector")
	end

	local function renderRules()
		clear(rulesFrame)
		label(rulesFrame, "Safety Rules", 8, 8, 250, 22, Settings.Theme.Text, true).TextSize = 16
		local rules = {
			"Code Search Low Impact ON skips uncached decompile during index.",
			"Panic Stop disables helper property logging and stops known heavy jobs.",
			"Property helper logging is rate-limited by Helper Property Log Limit/s.",
			"Use Play Mode during combat or heavy map streaming.",
			"Use Heavy Analysis only in lobby/safe areas.",
			"Helper search is preferred after cache/index has been pushed outside Roblox.",
		}
		for i, rule in ipairs(rules) do
			label(rulesFrame, tostring(i) .. ". " .. rule, 12, 42 + (i - 1) * 24, 690, 22, Settings.Theme.PlaceholderText, false)
		end
	end

	local function renderTimeline()
		clear(timelineFrame)
		label(timelineFrame, "Activity Timeline", 8, 8, 250, 22, Settings.Theme.Text, true).TextSize = 16
		for i, entry in ipairs(timeline) do
			if i > 18 then break end
			label(timelineFrame, entry, 12, 38 + (i - 1) * 19, 690, 18, Settings.Theme.PlaceholderText, false)
		end
	end

	local function showTab(name)
		activeTab = name
		overviewFrame.Visible = name == "Overview"
		modulesFrame.Visible = name == "Modules"
		rulesFrame.Visible = name == "Rules"
		timelineFrame.Visible = name == "Timeline"
		ControlCenter.Refresh()
	end

	ControlCenter.Refresh = function()
		if not window then return end
		if activeTab == "Overview" then
			renderOverview()
		elseif activeTab == "Modules" then
			renderModules()
		elseif activeTab == "Rules" then
			renderRules()
		elseif activeTab == "Timeline" then
			renderTimeline()
		end
	end

	ControlCenter.PanicStop = panicStop

	ControlCenter.Init = function()
		window = Lib.Window.new()
		window:SetTitle("Control Center")
		window:Resize(760, 460)
		ControlCenter.Window = window

		local content = window.GuiElems.Content
		local toolbar = createSimple("Frame", {
			BackgroundColor3 = Settings.Theme.Main2,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 58),
			Parent = content
		})
		statusLabel = label(toolbar, "Control Center ready.", 8, 31, 720, 20, Settings.Theme.PlaceholderText, false)
		button(toolbar, "Overview", 6, 5, 82, 22, function() showTab("Overview") end)
		button(toolbar, "Modules", 94, 5, 76, 22, function() showTab("Modules") end)
		button(toolbar, "Rules", 176, 5, 62, 22, function() showTab("Rules") end)
		button(toolbar, "Timeline", 244, 5, 78, 22, function() showTab("Timeline") end)
		button(toolbar, "Panic", 640, 5, 76, 22, panicStop)

		overviewFrame = createSimple("Frame", {BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 58), Size = UDim2.new(1, 0, 1, -58), Parent = content})
		modulesFrame = createSimple("Frame", {BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 58), Size = UDim2.new(1, 0, 1, -58), Parent = content, Visible = false})
		rulesFrame = createSimple("Frame", {BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 58), Size = UDim2.new(1, 0, 1, -58), Parent = content, Visible = false})
		timelineFrame = createSimple("Frame", {BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 58), Size = UDim2.new(1, 0, 1, -58), Parent = content, Visible = false})

		local lastFrame = os.clock()
		if service and service.RunService then
			heartbeatCon = service.RunService.Heartbeat:Connect(function()
				local now = os.clock()
				local dt = now - lastFrame
				lastFrame = now
				if dt > 0 then
					currentFps = (currentFps == 0) and (1 / dt) or (currentFps * 0.9 + (1 / dt) * 0.1)
				end
			end)
		end

		task.spawn(function()
			while window and not window.Closed do
				task.wait(1)
				ControlCenter.Refresh()
			end
		end)

		addTimeline("Control Center initialized.")
		showTab("Overview")
	end

	return ControlCenter
end

return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
