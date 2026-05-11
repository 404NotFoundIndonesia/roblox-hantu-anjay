--!strict
-- LanternManager — T-52
-- Tracks each player's lantern level (0–100). Level drains while the player is
-- in a biome zone and recharges while at the hub. When the level reaches 0,
-- the nearest Patrolling ghost is triggered (lantern-failure ghost trigger per GDD §4.2).
-- Fires LanternUpdated RemoteEvent to the client on every level change.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local ZoneDefs = require(ReplicatedStorage.Shared.ZoneDefs)
local Util = require(ReplicatedStorage.Shared.Util)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local GhostAI = require(ServerScriptService.Server.systems.GhostAI)

-- lanternLevel[userId] is the current lantern charge (0–100).
local lanternLevel: { [number]: number } = {}

-- Tracks whether a player's lantern just hit 0 this tick (prevents repeated triggers).
local lanternDrained: { [number]: boolean } = {}

local LanternManager = {}

local lanternRemote: RemoteEvent

-- Returns true when the player is inside any biome zone detection volume.
local function isInBiomeZone(player: Player): boolean
	local char = player.Character
	if char == nil then return false end
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp == nil then return false end
	local pos = hrp.Position
	for _, def in ZoneDefs do
		if Util.isInsideBounds(pos, def.detectionVolume) then
			return true
		end
	end
	return false
end

local function getPlayerPos(player: Player): Vector3?
	local char = player.Character
	if char == nil then return nil end
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp == nil then return nil end
	return hrp.Position
end

local function startPlayerLoop(player: Player)
	local userId = player.UserId
	lanternLevel[userId] = 100
	lanternDrained[userId] = false

	task.spawn(function()
		while player:IsDescendantOf(Players) do
			task.wait(Constants.LANTERN_TICK_INTERVAL)

			if not player:IsDescendantOf(Players) then break end

			local prev = lanternLevel[userId]
			if prev == nil then break end

			local inZone = isInBiomeZone(player)
			local delta = if inZone
				then -Constants.LANTERN_DRAIN_PER_TICK
				else Constants.LANTERN_RECHARGE_PER_TICK

			local newLevel = math.clamp(prev + delta, 0, 100)
			lanternLevel[userId] = newLevel

			-- Only fire update when level actually changed
			if newLevel ~= prev then
				lanternRemote:FireClient(player, { level = newLevel })
			end

			-- Lantern-failure ghost trigger: fires once per drain-to-zero event.
			-- Resets when lantern recharges above 0 so it can trigger again next time.
			if newLevel == 0 and not lanternDrained[userId] then
				lanternDrained[userId] = true
				local pos = getPlayerPos(player)
				if pos ~= nil then
					GhostAI.TriggerNearbyGhost(player, pos)
				end
			elseif newLevel > 0 then
				lanternDrained[userId] = false
			end
		end

		-- Cleanup on exit
		lanternLevel[userId] = nil
		lanternDrained[userId] = nil
	end)
end

function LanternManager.Init()
	lanternRemote = Remotes["LanternUpdated"] :: RemoteEvent

	Players.PlayerAdded:Connect(startPlayerLoop)
	Players.PlayerRemoving:Connect(function(player: Player)
		lanternLevel[player.UserId] = nil
		lanternDrained[player.UserId] = nil
	end)

	-- Cover players already in server (studio play solo)
	for _, player in Players:GetPlayers() do
		startPlayerLoop(player)
	end
end

return LanternManager
