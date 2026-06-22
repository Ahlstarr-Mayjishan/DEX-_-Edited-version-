--!strict
--[[
	Theme Module
	
	Centralizes UI aesthetics, fonts, custom colors, and transition helpers.
]]

-- Common Locals
local _Main, _Lib, _Apps, Settings -- Main Containers
local _Explorer, _Properties, _Notepad -- Major Apps
local _API, _RMD, _env, service, _plr, _create, _createSimple -- Main Locals

-- Silence standard Luau CLI environment issues
local Enum = ((_G :: any).Enum or getfenv().Enum) :: any
local Instance = ((_G :: any).Instance or getfenv().Instance) :: any
local UDim = ((_G :: any).UDim or getfenv().UDim) :: any
local TweenInfo = ((_G :: any).TweenInfo or getfenv().TweenInfo) :: any

local function initDeps(data: any)
	_Main = data.Main
	_Lib = data.Lib
	_Apps = data.Apps
	Settings = data.Settings

	_API = data.API
	_RMD = data.RMD
	_env = data.env
	service = data.service
	_plr = data.plr
	_create = data.create
	_createSimple = data.createSimple
end

local function initAfterMain(t: any)
	_Explorer = t.Explorer
	_Properties = t.Properties
	_Notepad = t.Notepad
end

local function main()
	local Theme = {}

	-- Font Mapping: Upgrades basic SourceSans font to modern Gotham family
	function Theme.MapFont(font: any): any
		if font == Enum.Font.SourceSans then
			return Enum.Font.Gotham
		elseif font == Enum.Font.SourceSansBold then
			return Enum.Font.GothamBold
		elseif font == Enum.Font.Code then
			return Enum.Font.RobotoMono
		end
		return font
	end

	-- Rounded Corners Helper
	function Theme.ApplyRounding(guiInstance: any, radius: number?): any
		local corner = guiInstance:FindFirstChildOfClass("UICorner")
		if not corner then
			corner = Instance.new("UICorner")
			corner.Parent = guiInstance
		end
		corner.CornerRadius = UDim.new(0, radius or 4)
		return corner
	end

	-- Outline Stroke Helper (Replaces ugly BordersizePixel)
	function Theme.ApplyStroke(guiInstance: any, color: any, thickness: number?, transparency: number?): any
		guiInstance.BorderSizePixel = 0
		local stroke = guiInstance:FindFirstChildOfClass("UIStroke")
		if not stroke then
			stroke = Instance.new("UIStroke")
			stroke.Parent = guiInstance
		end
		local activeTheme = Settings and (Settings :: any).Theme
		stroke.Color = color or (activeTheme and activeTheme.Outline1)
		stroke.Thickness = thickness or 1
		stroke.Transparency = transparency or 0
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		return stroke
	end

	-- Standardized Button Styling with Smooth Tweens
	function Theme.StyleButton(button: any, isAccent: boolean?)
		Theme.ApplyRounding(button, 6)
		button.Font = Theme.MapFont(button.Font)
		button.BorderSizePixel = 0

		local theme = Settings and (Settings :: any).Theme
		local startCol = isAccent and (theme and theme.ListSelection) or (theme and theme.Button)
		local hoverCol = theme and theme.ButtonHover
		local pressCol = theme and theme.ButtonPress

		button.BackgroundColor3 = startCol
		button.TextColor3 = theme and theme.Text
		Theme.ApplyStroke(button, isAccent and (theme and theme.Highlight) or (theme and theme.Outline2), 1, isAccent and 0.25 or 0.45)

		button.MouseEnter:Connect(function()
			(service :: any).TweenService:Create(button, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundColor3 = hoverCol
			}):Play()
		end)
		button.MouseLeave:Connect(function()
			(service :: any).TweenService:Create(button, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundColor3 = startCol
			}):Play()
		end)
		button.MouseButton1Down:Connect(function()
			(service :: any).TweenService:Create(button, TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundColor3 = pressCol
			}):Play()
		end)
		button.MouseButton1Up:Connect(function()
			(service :: any).TweenService:Create(button, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundColor3 = hoverCol
			}):Play()
		end)
	end

	-- Standardized TextBox Styling
	function Theme.StyleTextBox(textBox: any)
		Theme.ApplyRounding(textBox, 6)
		local theme = Settings and (Settings :: any).Theme
		Theme.ApplyStroke(textBox, theme and theme.Outline3, 1, 0.25)
		textBox.Font = Theme.MapFont(textBox.Font)
		textBox.BackgroundColor3 = theme and theme.TextBox
		textBox.TextColor3 = theme and theme.Text
		textBox.PlaceholderColor3 = theme and theme.PlaceholderText
		textBox.BorderSizePixel = 0
	end

	-- Standardized Frame Styling
	function Theme.StyleFrame(frame: any, mainType: number?)
		Theme.ApplyRounding(frame, 8)
		local theme = Settings and (Settings :: any).Theme
		local bgCol = (mainType == 1) and (theme and theme.Main1) or ((mainType == 2) and (theme and theme.Main2) or (theme and theme.Menu))
		frame.BackgroundColor3 = bgCol
		frame.BorderSizePixel = 0
		Theme.ApplyStroke(frame, theme and theme.Outline1, 1, 0.4)
	end

	-- Standardized Window Styling
	function Theme.StyleWindow(window: any)
		if not window or not window.GuiElems then return end
		local theme = Settings and (Settings :: any).Theme
		local main = (window.GuiElems :: any).Main
		local topBar = (window.GuiElems :: any).TopBar
		local content = (window.GuiElems :: any).Content
		local line = (window.GuiElems :: any).Line
		if main then
			main.BackgroundTransparency = 0
			Theme.ApplyRounding(main, 8)
			Theme.ApplyStroke(main, theme and theme.Outline1, 1, 0.2)
		end
		if topBar then
			topBar.BackgroundColor3 = theme and theme.Menu
			topBar.BorderSizePixel = 0
		end
		if content then
			content.BackgroundColor3 = theme and theme.Main2
			content.BorderSizePixel = 0
		end
		if line then
			line.BackgroundColor3 = theme and theme.Outline1
		end
	end

	return Theme
end

return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
