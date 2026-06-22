--!strict
local TestRunner = require("./TestRunner")
local StateModule = require("../State")

-- 1. Setup mocks
local task = {}
task.spawn = function(f: any, ...: any)
	f(...)
end

local warn = function(...)
	print("MOCK_WARN:", ...)
end

-- 2. Mock the environment data
local mockData = {
	Main = {},
	Lib = {},
	Apps = {},
	Settings = {},
	API = {},
	RMD = {},
	env = {},
	service = {
		RunService = {
			RenderStepped = {
				wait = function() end
			}
		}
	},
	plr = {},
	create = function() end,
	createSimple = function() end,
	task = task,
	warn = warn
}

StateModule.InitDeps(mockData)
StateModule.InitAfterMain()
local State = StateModule.Main()

local suite = {}

function suite.testStateCellNew()
	local cell = State.new(42)
	TestRunner.assertEquals(cell:get(), 42, "Initial value should be 42")
	TestRunner.assertEquals((cell :: any)(), 42, "Calling cell as function should return value")
end

function suite.testStateCellSet()
	local cell = State.new(42)
	cell:set(100)
	TestRunner.assertEquals(cell:get(), 100, "Value should update to 100")
end

function suite.testStateCellOnChange()
	local cell = State.new(1)
	local called = 0
	local valReceived = nil

	local conn = cell:onChange(function(val)
		called += 1
		valReceived = val
	end)

	cell:set(2)
	TestRunner.assertEquals(called, 1, "OnChange callback should run once")
	TestRunner.assertEquals(valReceived, 2, "Callback should receive new value")

	-- Setting same value shouldn't trigger onChange
	cell:set(2)
	TestRunner.assertEquals(called, 1, "OnChange callback should not run if value is the same")

	-- Disconnect
	conn:Disconnect()
	cell:set(3)
	TestRunner.assertEquals(called, 1, "Callback should not run after disconnect")
end

function suite.testStateComputed()
	local a = State.new(10)
	local b = State.new(20)

	local sum = State.Computed({a, b}, function()
		return a:get() + b:get()
	end)

	TestRunner.assertEquals(sum:get(), 30, "Initial computed value should be 30")

	local called = 0
	local valReceived = nil
	sum:onChange(function(val)
		called += 1
		valReceived = val
	end)

	a:set(15)
	TestRunner.assertEquals(sum:get(), 35, "Computed value should update to 35 when dependency updates")
	TestRunner.assertEquals(called, 1, "Computed onChange should trigger")
	TestRunner.assertEquals(valReceived, 35, "Computed onChange should receive new computed value")

	b:set(25)
	TestRunner.assertEquals(sum:get(), 40, "Computed value should update to 40 when second dependency updates")
	TestRunner.assertEquals(called, 2, "Computed onChange should trigger again")
	TestRunner.assertEquals(valReceived, 40)
end

TestRunner.runSuite("State Management Tests", suite)
