--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")
local Workspace = game:GetService("Workspace")

local Signal = require(ReplicatedStorage.Packages.Signal)
local Constants = require(ReplicatedStorage.Shared.Constants)
local ZoneDefs = require(ReplicatedStorage.Shared.ZoneDefs)

-- Ensure "Safe" collision group exists. Hub parts carry this group so ghost
-- detection triggers inside the Hub can be excluded server-side.
pcall(function()
	PhysicsService:RegisterCollisionGroup("Safe")
end)

local WorldBuilder = {}

-- Fires once when all islands are placed. Connect before calling Build().
WorldBuilder.Ready = Signal.new() :: any

-- ZoneId → ordered array of HauntPoint BaseParts placed in the world.
-- GhostSpawnManager reads this after Ready fires.
WorldBuilder.HauntPoints = {} :: { [string]: { BasePart } }

local function buildWorld()
	local t0 = os.clock()

	-- Workspace containers created once; other systems reference these by name.
	local worldFolder = Instance.new("Folder")
	worldFolder.Name = "World"
	worldFolder.Parent = Workspace

	local ghostsFolder = Instance.new("Folder")
	ghostsFolder.Name = "Ghosts"
	ghostsFolder.Parent = Workspace

	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets") :: Folder?
	local biomesFolder = assetsFolder and assetsFolder:FindFirstChild("Biomes") :: Folder?

	if biomesFolder == nil then
		warn("[WorldBuilder] ReplicatedStorage.Assets.Biomes not found — no biomes placed")
	else
		for zoneId, zoneDef in ZoneDefs do
			local template = biomesFolder:FindFirstChild(zoneDef.modelName) :: Model?

			if template == nil then
				warn("[WorldBuilder] Missing biome model:", zoneDef.modelName)
				WorldBuilder.HauntPoints[zoneId] = {}
				continue
			end

			local island = template:Clone() :: Model
			island.Name = zoneId
			island:PivotTo(CFrame.new(zoneDef.worldOffset))
			island.Parent = worldFolder

			-- Collect HauntPoint Parts for this zone.
			local hauntPoints: { BasePart } = {}
			for _, desc in island:GetDescendants() do
				if desc:IsA("BasePart") and desc.Name == "HauntPoint" then
					table.insert(hauntPoints, desc :: BasePart)
				end
			end
			WorldBuilder.HauntPoints[zoneId] = hauntPoints

			if #hauntPoints ~= zoneDef.hauntPointCount then
				warn(
					string.format(
						"[WorldBuilder] %s: expected %d HauntPoints, got %d",
						zoneId,
						zoneDef.hauntPointCount,
						#hauntPoints
					)
				)
			end
		end
	end

	-- Hub island: always present; all its parts are tagged Safe so ghost
	-- proximity checks ignore players standing on the Hub.
	local hubTemplate = assetsFolder and assetsFolder:FindFirstChild("Hub") :: Model?
	if hubTemplate then
		local hub = hubTemplate:Clone() :: Model
		hub.Name = "Hub"
		hub:PivotTo(CFrame.new(Constants.HUB_SPAWN))
		hub.Parent = worldFolder

		for _, desc in hub:GetDescendants() do
			if desc:IsA("BasePart") then
				(desc :: BasePart).CollisionGroup = "Safe"
			end
		end
	else
		warn("[WorldBuilder] Hub model not found in ReplicatedStorage.Assets — Hub island missing")
	end

	local elapsed = os.clock() - t0
	if elapsed > 5 then
		warn(string.format("[WorldBuilder] Build took %.2fs — exceeds 5s budget", elapsed))
	else
		print(string.format("[WorldBuilder] Build complete in %.3fs", elapsed))
	end

	WorldBuilder.Ready:Fire()
end

-- Builds the world synchronously on the calling thread.
-- Must be called from init.server.luau before Players.PlayerAdded is connected
-- so the world exists when the first player joins.
function WorldBuilder.Build()
	buildWorld()
end

return WorldBuilder
