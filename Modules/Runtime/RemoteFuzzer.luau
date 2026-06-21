--!nocheck
--[[
	Remote Fuzzer Generator Module
	Generates custom payload/fuzz testing scripts for RemoteEvents and RemoteFunctions.
]]
local Main, Lib, Apps, Settings
local Notepad

local function initDeps(data)
	Main = data.Main
	Lib = data.Lib
	Apps = data.Apps
	Settings = data.Settings
end

local function initAfterMain(apps)
	Notepad = apps.Notepad
end

local function main()
	local RemoteFuzzer = {}

	local function getPath(obj)
        if Main and Main.SafeGetInstancePath then return Main.SafeGetInstancePath(obj) end
		local ok, path = pcall(function()
			if Apps.Explorer and Apps.Explorer.GetInstancePath then
				return Apps.Explorer.GetInstancePath(obj)
			end
			return obj:GetFullName()
		end)
		return ok and tostring(path) or tostring(obj)
	end

	RemoteFuzzer.Generate = function(remote: Instance)
		if not remote then return end
		local path = getPath(remote)
		local isFunction = remote:IsA("RemoteFunction") or remote:IsA("BindableFunction")
		local isBindable = remote:IsA("BindableEvent") or remote:IsA("BindableFunction")

		local fireMethod = "FireServer"
		if isBindable then
			fireMethod = isFunction and "Invoke" or "Fire"
		else
			fireMethod = isFunction and "InvokeServer" or "FireServer"
		end

		-- Query RemoteSpy for logged signatures
		local spy = Apps.RemoteSpy
		local callHistory = nil
		if spy and spy.GetRemoteStats then
			local stat = spy.GetRemoteStats(path)
			if stat then
				callHistory = stat.callHistory
			end
		end

		local signature = nil
		if callHistory and #callHistory > 0 then
			signature = callHistory[#callHistory] -- Take the most recent call's parameter types
		end

		local code = {}
		table.insert(code, "-- Auto-generated Remote Fuzzer Payload")
		table.insert(code, "-- Target: " .. path)
		table.insert(code, "-- Class: " .. remote.ClassName)
		if signature then
			table.insert(code, "-- Smart Mode: Fuzzing detected parameter types: (" .. table.concat(signature, ", ") .. ")")
		else
			table.insert(code, "-- Standalone Mode: No call history in RemoteSpy, using generic static fuzzing.")
		end
		table.insert(code, "\nlocal target = " .. path)
		table.insert(code, "if not target then")
		table.insert(code, "    warn(\"Fuzzer target not found!\")")
		table.insert(code, "    return")
		table.insert(code, "end\n")

		if signature then
			local sigStr = "{"
			for _, t in ipairs(signature) do
				sigStr = sigStr .. "\"" .. t .. "\", "
			end
			sigStr = sigStr .. "}"

			table.insert(code, "local signature = " .. sigStr)
			table.insert(code, [[
local typeFuzzers = {
    ["number"] = {0, 1, -1, 999999, -999999, 1.00001, 0/0, math.huge, -math.huge},
    ["string"] = {"", string.rep("A", 10000), "%s%s%s%s%d%x", "\\0\\n\\r\\t!@#$%^&*()"},
    ["boolean"] = {true, false},
    ["Vector3"] = {Vector3.new(0,0,0), Vector3.new(1e9,1e9,1e9), Vector3.new(-1e9,-1e9,-1e9), Vector3.new(0/0,0/0,0/0)},
    ["CFrame"] = {CFrame.new(0,0,0), CFrame.new(1e9,1e9,1e9)},
    ["Color3"] = {Color3.new(0,0,0), Color3.new(1,1,1)},
    ["table"] = {{}, {1, 2, 3}, {key = "value"}},
    ["Instance"] = {workspace, nil},
}

local genericFuzzers = {0, "", {}, true, nil, Vector3.new(0,0,0)}

local defaultNormals = {
    ["number"] = 1,
    ["string"] = "test",
    ["boolean"] = true,
    ["Vector3"] = Vector3.new(0, 0, 0),
    ["CFrame"] = CFrame.new(0, 0, 0),
    ["Color3"] = Color3.new(1, 0, 0),
    ["table"] = {},
    ["Instance"] = workspace,
}

local baseArgs = {}
for i, t in ipairs(signature) do
    baseArgs[i] = defaultNormals[t]
    if baseArgs[i] == nil then
        baseArgs[i] = "placeholder"
    end
end

local function cloneTable(t)
    local nt = {}
    for k, v in pairs(t) do nt[k] = v end
    return nt
end

print("=== Starting Smart Remote Fuzzer on: " .. target:GetFullName() .. " ===")
print("Pattern: (" .. table.concat(signature, ", ") .. ")")

for paramIdx = 1, #signature do
    local paramType = signature[paramIdx]
    local fuzzers = typeFuzzers[paramType] or genericFuzzers
    
    print("\nFuzzing Parameter " .. paramIdx .. " [" .. paramType .. "]...")
    
    for _, fuzzVal in ipairs(fuzzers) do
        local testArgs = cloneTable(baseArgs)
        testArgs[paramIdx] = fuzzVal
        
        local displayVal = tostring(fuzzVal)
        if typeof(fuzzVal) == "string" then
            displayVal = "\"" .. displayVal:sub(1, 30) .. "\""
        end
        print("  Testing param " .. paramIdx .. " with: " .. displayVal .. " (" .. typeof(fuzzVal) .. ")")
        
        task.spawn(function()
            local ok, result = pcall(function()]])
			if isFunction then
				table.insert(code, "                return target:" .. fireMethod .. "(unpack(testArgs))")
			else
				table.insert(code, "                target:" .. fireMethod .. "(unpack(testArgs))")
			end
			table.insert(code, [[            end)
            if not ok then
                warn("    Error: " .. tostring(result))]])
			if isFunction then
				table.insert(code, [[            else
                print("    Success. Return: " .. tostring(result))]])
			end
			table.insert(code, [[            end
        end)
        task.wait(0.08)
    end
end
print("\n=== Smart Remote Fuzzing Finished ===")]])
		else
			-- Fallback to static list fuzzer
			table.insert(code, [[-- Define a diverse list of fuzz payloads (boundary values, incorrect types, etc.)
local payloads = {
    {name = "Zero", val = 0},
    {name = "Positive Int", val = 1},
    {name = "Negative Int", val = -1},
    {name = "Large Int", val = 999999},
    {name = "Float", val = 1.00001},
    {name = "NaN", val = 0/0},
    {name = "Infinity", val = math.huge},
    {name = "Negative Infinity", val = -math.huge},
    {name = "Empty String", val = ""},
    {name = "Long String (10k)", val = string.rep("A", 10000)},
    {name = "Format Injection", val = "%s%s%s%s%d%x"},
    {name = "Special Chars", val = "\\0\\n\\r\\t!@#$%^&*()"},
    {name = "Empty Table", val = {}},
    {name = "Simple Array", val = {1, 2, 3}},
    {name = "Simple Dict", val = {key = "value"}},
    {name = "Nested Table", val = {a = {b = {c = 1}}}},
    {name = "Nil", val = nil},
    {name = "True", val = true},
    {name = "False", val = false},
    {name = "Vector3", val = Vector3.new(100, 200, 300)},
    {name = "CFrame", val = CFrame.new(0, 50, 0)},
    {name = "Color3", val = Color3.fromRGB(255, 0, 0)},
}

print("=== Starting Remote Fuzzer on: " .. target:GetFullName() .. " ===")
for _, payload in ipairs(payloads) do
    print("Testing: " .. payload.name .. " (" .. typeof(payload.val) .. ")")
    task.spawn(function()
        local ok, result = pcall(function()]])
			if isFunction then
				table.insert(code, "            return target:" .. fireMethod .. "(payload.val)")
			else
				table.insert(code, "            target:" .. fireMethod .. "(payload.val)")
			end
			table.insert(code, [[        end)
        if not ok then
            warn("  Error: " .. tostring(result))]])
			if isFunction then
				table.insert(code, [[        else
            print("  Success. Return value: " .. tostring(result))]])
			end
			table.insert(code, [[        end
    end)
    task.wait(0.1)
end
print("=== Remote Fuzzing Finished ===")]])
		end

		local finalCode = table.concat(code, "\n")
		if Notepad and Notepad.ViewRawCode then
			Notepad.ViewRawCode(finalCode, remote.Name .. " Fuzzer")
		else
			warn("Notepad not available or missing ViewRawCode!")
		end
	end

	return RemoteFuzzer
end

if gethsfuncs then
	_G.moduleData = {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
else
	return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
end
