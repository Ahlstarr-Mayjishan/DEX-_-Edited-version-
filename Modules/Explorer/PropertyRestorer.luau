--[[
	Property Restorer Core Module
	Manages backup and restoration of instance properties modified during copy/paste operations.
]]

-- Common Locals
local Main, Lib, Apps, Settings
local API, RMD, env, service, plr, create, createSimple

local function initDeps(data)
	Main = data.Main
	Lib = data.Lib
	Apps = data.Apps
	Settings = data.Settings

	API = data.API
	RMD = data.RMD
	env = data.env
	service = data.service
	plr = data.plr
	create = data.create
	createSimple = data.createSimple
end

local function initAfterMain()
end

local function main()
	local PropertyRestorer = {}
	local originalPropertiesCache = setmetatable({}, {__mode = "k"})

	PropertyRestorer.Backup = function(targetInstance)
		if not targetInstance then return end
		if originalPropertiesCache[targetInstance] then return end

		local backup = {
			Properties = {}
		}
		
		local function addBackupProp(name)
			pcall(function()
				backup.Properties[name] = targetInstance[name]
			end)
		end
		
		if targetInstance:IsA("BasePart") then
			addBackupProp("Material")
			addBackupProp("MaterialVariant")
			addBackupProp("Color")
			addBackupProp("Transparency")
			addBackupProp("Reflectance")
			addBackupProp("Size")
			addBackupProp("CanCollide")
			addBackupProp("Anchored")
			addBackupProp("CastShadow")
		end
		
		if targetInstance:IsA("MeshPart") then
			addBackupProp("MeshId")
			addBackupProp("TextureID")
		end
		
		local specialMesh = targetInstance:FindFirstChildOfClass("SpecialMesh")
		if specialMesh then
			backup.SpecialMesh = {
				MeshId = specialMesh.MeshId,
				TextureId = specialMesh.TextureId,
				Scale = specialMesh.Scale,
				Offset = specialMesh.Offset,
				MeshType = specialMesh.MeshType
			}
		else
			backup.HadNoSpecialMesh = true
		end
		
		originalPropertiesCache[targetInstance] = backup
	end

	PropertyRestorer.Restore = function(targetInstance)
		if not targetInstance then return end
		local backup = originalPropertiesCache[targetInstance]
		if not backup then return end
		
		-- Restore base properties
		for k, v in pairs(backup.Properties) do
			pcall(function()
				targetInstance[k] = v
			end)
		end
		
		-- Restore SpecialMesh
		if backup.HadNoSpecialMesh then
			local specialMesh = targetInstance:FindFirstChildOfClass("SpecialMesh")
			if specialMesh then
				specialMesh:Destroy()
			end
		elseif backup.SpecialMesh then
			local specialMesh = targetInstance:FindFirstChildOfClass("SpecialMesh")
			if not specialMesh then
				specialMesh = Instance.new("SpecialMesh")
				specialMesh.Parent = targetInstance
			end
			for k, v in pairs(backup.SpecialMesh) do
				pcall(function()
					specialMesh[k] = v
				end)
			end
		end
	end

	PropertyRestorer.HasBackup = function(targetInstance)
		return originalPropertiesCache[targetInstance] ~= nil
	end

	return PropertyRestorer
end

return {
	InitDeps = initDeps,
	InitAfterMain = initAfterMain,
	Main = main
}
