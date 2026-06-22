--!strict
local TestRunner = require("./TestRunner")
local LoggerModule = require("../Logger")

-- Mock the environment data
local mockData = {
	Main = {},
	Lib = {},
	Apps = {},
	Settings = {},
	API = {},
	RMD = {},
	env = {},
	service = {},
	plr = {},
	create = function() end,
	createSimple = function() end,
}

LoggerModule.InitDeps(mockData)
LoggerModule.InitAfterMain()
local Logger = LoggerModule.Main()

local suite = {}

function suite.testDefaultLevel()
	local logged = {}
	Logger.addCustomOutput(function(level, msg)
		table.insert(logged, {level = level, msg = msg})
	end)
	
	Logger.debug("this should not log")
	Logger.info("this should log")
	Logger.warn("this is a warning")
	
	TestRunner.assertEquals(#logged, 2, "Should have logged two messages")
	TestRunner.assertEquals(logged[1].level, Logger.Levels.INFO, "First logged level should be INFO")
	TestRunner.assertEquals(logged[2].level, Logger.Levels.WARN, "Second logged level should be WARN")
end

function suite.testSetLogLevel()
	local logged = {}
	Logger.addCustomOutput(function(level, msg)
		table.insert(logged, {level = level, msg = msg})
	end)
	
	Logger.setLogLevel(Logger.Levels.WARN)
	Logger.info("info log")
	Logger.warn("warn log")
	Logger.error("error log")
	
	TestRunner.assertEquals(#logged, 2, "Should only log WARN and ERROR")
	TestRunner.assertEquals(logged[1].level, Logger.Levels.WARN)
	TestRunner.assertEquals(logged[2].level, Logger.Levels.ERROR)
end

TestRunner.runSuite("Logger Module Tests", suite)
