--!strict
--[[
	Declarative UI State & Reactivity Module
]]

-- Common Locals
local _Main, _Lib, _Apps, _Settings -- Main Containers
local _API, _RMD, _env, _service, _plr, _create, _createSimple -- Main Locals

-- Default to global environment
local task = ((_G :: any).task or getfenv().task) :: any
local warn = ((_G :: any).warn or getfenv().warn) :: any

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

	-- Support injection for unit testing
	if data.task then
		task = data.task
	end
	if data.warn then
		warn = data.warn
	end
end

local function initAfterMain()
end

export type Connection = {
	Disconnect: (self: Connection) -> ()
}

export type StateCell<T> = {
	_value: T,
	_listeners: { (newValue: T) -> () },
	get: (self: StateCell<T>) -> T,
	set: (self: StateCell<T>, newValue: T) -> (),
	onChange: (self: StateCell<T>, callback: (newValue: T) -> ()) -> Connection,
}

export type ComputedCell<T> = {
	_value: T,
	_callback: () -> T,
	_dependencies: { any },
	_listeners: { (newValue: T) -> () },
	_connections: { Connection },
	get: (self: ComputedCell<T>) -> T,
	onChange: (self: ComputedCell<T>, callback: (newValue: T) -> ()) -> Connection,
}

local function main()
	local State = {}

	local StateCell = {}
	StateCell.__index = StateCell

	function StateCell.new<T>(initialValue: T): StateCell<T>
		local self = setmetatable({
			_value = initialValue,
			_listeners = {}
		}, StateCell)
		return (self :: any) :: StateCell<T>
	end

	function StateCell.get<T>(self: StateCell<T>): T
		return self._value
	end

	function StateCell.set<T>(self: StateCell<T>, newValue: T)
		if self._value == newValue then return end
		self._value = newValue
		for _, listener in ipairs(self._listeners) do
			task.spawn(listener, newValue)
		end
	end

	function StateCell.onChange<T>(self: StateCell<T>, callback: (newValue: T) -> ()): Connection
		table.insert(self._listeners, callback)
		return {
			Disconnect = function()
				local pos = table.find(self._listeners, callback)
				if pos then
					table.remove(self._listeners, pos)
				end
			end
		}
	end

	function StateCell.__call<T>(self: StateCell<T>): T
		return (self :: any):get()
	end

	local ComputedCell = {}
	ComputedCell.__index = ComputedCell

	function ComputedCell.new<T>(dependencies: { any }, callback: () -> T): ComputedCell<T>
		local self = setmetatable({
			_callback = callback,
			_dependencies = dependencies,
			_listeners = {},
			_value = (nil :: any) :: T,
			_connections = {}
		}, ComputedCell)

		local function update()
			local ok, newVal = pcall(self._callback)
			if ok then
				if (self :: any)._value ~= newVal then
					(self :: any)._value = newVal
					for _, listener in ipairs((self :: any)._listeners) do
						task.spawn(listener, newVal)
					end
				end
			else
				warn("Computed value error: " .. tostring(newVal))
			end
		end

		for _, dep in ipairs(dependencies) do
			if type(dep) == "table" and dep.onChange then
				local conn = (dep :: any):onChange(update)
				table.insert((self :: any)._connections, conn)
			end
		end

		(self :: any)._value = callback()
		return (self :: any) :: ComputedCell<T>
	end

	function ComputedCell.get<T>(self: ComputedCell<T>): T
		return self._value
	end

	function ComputedCell.onChange<T>(self: ComputedCell<T>, callback: (newValue: T) -> ()): Connection
		table.insert(self._listeners, callback)
		return {
			Disconnect = function()
				local pos = table.find(self._listeners, callback)
				if pos then
					table.remove(self._listeners, pos)
				end
			end
		}
	end

	function ComputedCell.__call<T>(self: ComputedCell<T>): T
		return (self :: any):get()
	end

	local function Bind(instance: any, properties: { [string]: any }): Connection
		local connections: { Connection } = {}

		for propName, propValue in pairs(properties) do
			if type(propValue) == "table" and propValue.get and propValue.onChange then
				-- It's a state or computed object
				local function update(val: any)
					if instance and instance.Parent then
						local ok, err = pcall(function()
							(instance :: any)[propName] = val
						end)
						if not ok then
							warn("Failed to update bound property " .. propName .. " on " .. tostring(instance) .. ": " .. tostring(err))
						end
					end
				end

				-- Initial update
				update((propValue :: any):get())

				-- Connect listener
				local conn = (propValue :: any):onChange(update)
				table.insert(connections, conn)
			else
				-- Standard value assignment
				(instance :: any)[propName] = propValue
			end
		end

		-- Clean up when the GuiInstance is destroyed
		local destroyConn: any = nil
		local hasDestroying = pcall(function() return instance.Destroying end)
		if hasDestroying then
			destroyConn = instance.Destroying:Connect(function()
				if destroyConn then destroyConn:Disconnect() end
				for _, conn in ipairs(connections) do
					conn:Disconnect()
				end
			end)
		else
			destroyConn = instance.AncestryChanged:Connect(function(_: any, parent: any)
				if parent == nil then
					if destroyConn then destroyConn:Disconnect() end
					for _, conn in ipairs(connections) do
						conn:Disconnect()
					end
				end
			end)
		end

		return {
			Disconnect = function()
				if destroyConn then destroyConn:Disconnect() end
				for _, conn in ipairs(connections) do
					conn:Disconnect()
				end
			end
		}
	end

	State.new = StateCell.new
	State.Computed = ComputedCell.new
	State.Bind = Bind

	return State
end

local getgenv = (_G :: any).getgenv or getfenv().getgenv
if getgenv and (getgenv :: any)().gethsfuncs then
	((getgenv :: any)()._G :: any).moduleData = {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
else
	return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
end
