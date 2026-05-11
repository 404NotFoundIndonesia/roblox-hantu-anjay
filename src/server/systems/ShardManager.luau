--!strict
-- ShardManager — T-51
-- Spawns SpiritShard collectible Parts near haunt points in each biome zone.
-- Collection grants shards via EconomyManager, fires GhostAI.ShardCollected
-- (which triggers the nearest ghost and increments ShardCollected quest progress),
-- then hides the Part and respawns it after SHARD_RESPAWN_TIME seconds.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)
local WorldBuilder = require(ServerScriptService.Server.systems.WorldBuilder)
local GhostAI = require(ServerScriptService.Server.systems.GhostAI)
local EconomyManager = require(ServerScriptService.Server.systems.EconomyManager)
local PlayerDataManager = require(ServerScriptService.Server.systems.PlayerDataManager)

-- §22 Rule 8: per-player rate-limit prevents double-touch grants.
local collectRateLimit: { [number]: number } = {}

local ShardManager = {}

local function spawnShardAt(position: Vector3, parent: Instance): Part
	local part = Instance.new("Part") :: Part
	part.Name = "SpiritShard"
	part.Size = Vector3.new(1.5, 1.5, 1.5)
	part.Shape = Enum.PartType.Ball
	part.Position = position + Vector3.new(0, 2, 0) -- float above surface
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.BrickColor = BrickColor.new("Cyan")
	part.Parent = parent
	return part
end

local function connectShard(part: Part)
	part.Touched:Connect(function(hit: BasePart)
		-- Only collectible when visible
		if not part.CanTouch then return end

		local char = hit.Parent :: Model?
		if char == nil then return end
		local player = Players:GetPlayerFromCharacter(char)
		if player == nil then return end

		-- §22 Rule 8: enforce 0.5s minimum between collections per player
		local now = os.clock()
		local userId = player.UserId
		if now - (collectRateLimit[userId] or 0) < 0.5 then return end
		collectRateLimit[userId] = now

		-- Disable immediately to prevent concurrent collection by another player
		part.CanTouch = false

		local data = PlayerDataManager.GetData(player)
		if data == nil then
			-- Profile not loaded yet — restore part and skip
			part.CanTouch = true
			return
		end

		-- Grant shards; ShardsUpdated fires inside AddShards
		EconomyManager.AddShards(player, Constants.SHARD_PICKUP_AMOUNT)
		PlayerDataManager.Save(player)

		-- Fire ShardCollected: triggers nearest ghost + increments shard quest
		local shardPos = part.Position
		GhostAI.ShardCollected:Fire(player, shardPos)

		-- Hide Part and schedule respawn
		part.Transparency = 1

		task.delay(Constants.SHARD_RESPAWN_TIME, function()
			if part.Parent == nil then return end
			part.Transparency = 0
			part.CanTouch = true
		end)
	end)
end

function ShardManager.Init()
	WorldBuilder.Ready:Connect(function()
		local worldFolder = Workspace:FindFirstChild("World") :: Folder?
		local shardParent: Instance = worldFolder or Workspace

		for zoneId, hauntPoints in WorldBuilder.HauntPoints do
			for _, hauntPoint in hauntPoints do
				for i = 1, Constants.SHARDS_PER_HAUNT_POINT do
					-- Distribute shards in a ring around the haunt point
					local angle = (i - 1) / Constants.SHARDS_PER_HAUNT_POINT * math.pi * 2
					local radius = 5 + (i % 2) * 3 -- alternates 5 and 8 studs out
					local offset = Vector3.new(
						math.cos(angle) * radius,
						0,
						math.sin(angle) * radius
					)
					local part = spawnShardAt(hauntPoint.Position + offset, shardParent)
					connectShard(part)
				end
			end
			_ = zoneId
		end

		local zoneCount = 0
		for _ in WorldBuilder.HauntPoints do
			zoneCount += 1
		end
		print(string.format("[ShardManager] Shards placed across %d zones", zoneCount))
	end)

	-- Clean up rate-limit entry when player leaves (no memory leak)
	Players.PlayerRemoving:Connect(function(player: Player)
		collectRateLimit[player.UserId] = nil
	end)
end

return ShardManager
