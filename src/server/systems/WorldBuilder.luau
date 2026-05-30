--!strict
-- WorldBuilder — reads pre-placed Workspace models rather than cloning from ReplicatedStorage.
-- Designer places Hub and all biome islands directly in Workspace (or Workspace.World).
-- WorldBuilder collects HauntPoints, applies Safe collision group to Hub, then fires Ready.
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Signal = require(ReplicatedStorage.Packages.Signal)
local ZoneDefs = require(ReplicatedStorage.Shared.ZoneDefs)

-- "Safe" group excludes Hub parts from ghost proximity checks.
pcall(function()
	PhysicsService:RegisterCollisionGroup("Safe")
end)

local WorldBuilder = {}

-- Fires once when all islands are registered. Connect before calling Build().
WorldBuilder.Ready = Signal.new() :: any

-- ZoneId → ordered array of HauntPoint BaseParts placed in the world.
-- GhostSpawnManager reads this after Ready fires.
WorldBuilder.HauntPoints = {} :: { [string]: { BasePart } }

-- Returns a named Model from Workspace.World first, then bare Workspace.
-- If found outside Workspace.World, moves it in.
local function findModel(worldFolder: Folder, name: string): Model?
	local m = worldFolder:FindFirstChild(name)
	if m and m:IsA("Model") then
		return m :: Model
	end
	local fallback = Workspace:FindFirstChild(name)
	if fallback and fallback:IsA("Model") then
		local model = fallback :: Model
		model.Parent = worldFolder
		return model
	end
	return nil
end

local function buildWorld()
	-- Ensure World folder exists (designer may have pre-created it).
	local worldFolder = Workspace:FindFirstChild("World") :: Folder?
	if worldFolder == nil then
		worldFolder = Instance.new("Folder")
		worldFolder.Name = "World"
		worldFolder.Parent = Workspace
	end

	-- Ghosts folder created at runtime; never pre-create in Studio.
	if Workspace:FindFirstChild("Ghosts") == nil then
		local gf = Instance.new("Folder")
		gf.Name = "Ghosts"
		gf.Parent = Workspace
	end

	-- Collect biome islands placed by the designer in Studio.
	for zoneId, zoneDef in ZoneDefs do
		local island = findModel(worldFolder, zoneDef.modelName)

		if island == nil then
			warn("[WorldBuilder] Biome model not found in Workspace: " .. zoneDef.modelName)
			WorldBuilder.HauntPoints[zoneId] = {}
			continue
		end

		local hauntPoints: { BasePart } = {}
		for _, desc in island:GetDescendants() do
			if desc:IsA("BasePart") and desc.Name == "HauntPoint" then
				table.insert(hauntPoints, desc :: BasePart)
			end
		end
		WorldBuilder.HauntPoints[zoneId] = hauntPoints

		if #hauntPoints ~= zoneDef.hauntPointCount then
			warn(string.format(
				"[WorldBuilder] %s: expected %d HauntPoints, got %d",
				zoneId,
				zoneDef.hauntPointCount,
				#hauntPoints
			))
		end
	end

	-- Hub: apply Safe collision group so ghost detection ignores Hub players.
	local hub = findModel(worldFolder, "Hub")
	if hub ~= nil then
		for _, desc in hub:GetDescendants() do
			if desc:IsA("BasePart") then
				(desc :: BasePart).CollisionGroup = "Safe"
			end
		end
	else
		warn("[WorldBuilder] Hub model not found in Workspace — Hub island missing")
	end

	print("[WorldBuilder] Build complete")
	WorldBuilder.Ready:Fire()
end

-- Builds the world synchronously on the calling thread.
-- Must be called from init.server.luau before Players.PlayerAdded is connected.
function WorldBuilder.Build()
	buildWorld()
end

return WorldBuilder
