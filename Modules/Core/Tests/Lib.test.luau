--!strict
local TestRunner = require("./TestRunner")

local LibModule = require("../Lib")

-- Mocks
local task = {}
task.spawn = function(f: any, ...: any)
	f(...)
end

local warn = function(...)
	print("MOCK_WARN:", ...)
end

local mockData = {
	Main = {},
	Lib = {},
	Apps = {
		IconData = {
			Old = {
				MapId = "rbxassetid://5034768003",
				Icons = {},
				IconSize = 16
			}
		}
	},
	Settings = {
		Window = {},
		Explorer = {}
	},
	API = {},
	RMD = {},
	env = {},
	service = {
		RunService = {
			RenderStepped = {
				wait = function() end
			}
		},
		Players = {
			LocalPlayer = {
				GetMouse = function()
					return {
						X = 0,
						Y = 0,
						ViewSizeX = 1920,
						ViewSizeY = 1080
					}
				end
			}
		}
	},
	plr = {
		GetMouse = function()
			return {
				X = 0,
				Y = 0
			}
		end
	},
	create = function() end,
	createSimple = function() end,
	task = task,
	warn = warn
}
LibModule.InitDeps(mockData)
LibModule.InitAfterMain()
local Lib = LibModule.Main()

local suite = {}

function suite.testFormatLuaString()
	local formatted = Lib.FormatLuaString("hello \"world\" \\")
	TestRunner.assertEquals(formatted, "hello \\\"world\\\" \\\\", "Should correctly escape quotes and backslashes")

	local formattedControl = Lib.FormatLuaString("\n\t\r")
	TestRunner.assertEquals(formattedControl, "\\010\\009\\013", "Should correctly escape control characters")
end

function suite.testColorToBytes()
	local col = { r = 1, g = 0.5, b = 0.25 }
	local bytes = Lib.ColorToBytes(col)
	TestRunner.assertEquals(bytes, "255, 128, 64", "Should format color correctly")
end

function suite.testFindAndRemove()
	local t = { "a", "b", "c", "d" }
	Lib.FindAndRemove(t, "c")
	TestRunner.assertEquals(#t, 3, "Table size should decrease")
	TestRunner.assertEquals(t[3], "d", "Subsequent items should shift left")
	
	Lib.FindAndRemove(t, "z") -- non-existent item should do nothing
	TestRunner.assertEquals(#t, 3)
end

function suite.testGetSafePath()
	-- Test nil object
	TestRunner.assertEquals(Lib.getSafePath(nil), "?")
	
	-- Test nil parented object
	local mockObj = { Parent = nil }
	TestRunner.assertEquals(Lib.getSafePath(mockObj), "Nil parented")
	
	-- Test custom full path retrieval via full name fallback
	local mockObj2 = {
		Parent = {},
		GetFullName = function() return "game.Workspace.BasePart" end
	}
	TestRunner.assertEquals(Lib.getSafePath(mockObj2), "game.Workspace.BasePart")
end

TestRunner.runSuite("Lib Utility Tests", suite)
