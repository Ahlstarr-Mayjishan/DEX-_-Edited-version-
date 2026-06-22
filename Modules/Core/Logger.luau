--!strict
--[[
	Centralized Logger Module for DarkDEX++
]]

-- Common Locals
local _Main: any, _Lib: any, _Apps: any, _Settings: any
local _API: any, _RMD: any, _env: any, _service: any, _plr: any, _create: any, _createSimple: any

local function initDeps(data: any)
	_Main = data.Main
	_Lib = data.Lib
	_Apps = data.Apps
	_Settings = data.Settings

	_API = data.API
	_RMD = data.RMD
	_env = data.env
	_service = data.service
	_plr = data.plr
	_create = data.create
	_createSimple = data.createSimple
end

local function initAfterMain()
end

export type LogLevel = number

export type Logger = {
	Levels: {
		DEBUG: LogLevel,
		INFO: LogLevel,
		WARN: LogLevel,
		ERROR: LogLevel,
	},
	setLogLevel: (level: LogLevel) -> (),
	addCustomOutput: (callback: (level: LogLevel, message: string) -> ()) -> (),
	debug: (...any) -> (),
	info: (...any) -> (),
	warn: (...any) -> (),
	error: (...any) -> (),
}

local function main(): Logger
	local Logger = {}
	
	local Levels = {
		DEBUG = 0,
		INFO = 1,
		WARN = 2,
		ERROR = 3
	}
	Logger.Levels = Levels
	
	local currentLevel = Levels.INFO
	local customOutputs: { (level: LogLevel, message: string) -> () } = {}
	
	function Logger.setLogLevel(level: LogLevel)
		currentLevel = level
	end
	
	function Logger.addCustomOutput(callback: (level: LogLevel, message: string) -> ())
		table.insert(customOutputs, callback)
	end
	
	local function formatMessage(...)
		local parts = {}
		for i = 1, select("#", ...) do
			table.insert(parts, tostring(select(i, ...)))
		end
		return table.concat(parts, " ")
	end
	
	local function log(level: LogLevel, prefix: string, ...)
		if level < currentLevel then return end
		local msg = "[" .. prefix .. "] " .. formatMessage(...)
		
		-- Default standard outputs
		if level == Levels.ERROR or level == Levels.WARN then
			local warnFunc = (_G :: any).warn or getfenv().warn or print
			warnFunc(msg)
		else
			local printFunc = (_G :: any).print or getfenv().print or print
			printFunc(msg)
		end
		
		-- Custom outputs
		for _, output in ipairs(customOutputs) do
			pcall(output, level, msg)
		end
	end
	
	function Logger.debug(...)
		log(Levels.DEBUG, "DEBUG", ...)
	end
	
	function Logger.info(...)
		log(Levels.INFO, "INFO", ...)
	end
	
	function Logger.warn(...)
		log(Levels.WARN, "WARN", ...)
	end
	
	function Logger.error(...)
		log(Levels.ERROR, "ERROR", ...)
	end
	
	return Logger :: Logger
end

local getgenv = (_G :: any).getgenv or getfenv().getgenv
if getgenv and (getgenv :: any)().gethsfuncs then
	((getgenv :: any)()._G :: any).moduleData = {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
else
	return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
end
