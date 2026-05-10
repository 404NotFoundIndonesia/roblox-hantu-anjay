--!strict
-- QuestManager — T-25 (daily/weekly quests, WIB reset, quest tracking)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Signal = require(ReplicatedStorage.Packages.Signal)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ZoneDefs = require(ReplicatedStorage.Shared.ZoneDefs)
local PlayerDataManager = require(ServerScriptService.Server.systems.PlayerDataManager)
local EconomyManager = require(ServerScriptService.Server.systems.EconomyManager)
local GhostAI = require(ServerScriptService.Server.systems.GhostAI)

local QuestDefs = require(ServerScriptService.Server.data.QuestDefs)
type QuestDef = QuestDefs.QuestDef

-- ─── Public Signals (other systems fire these) ────────────────────────────────
-- Fire QuestManager.Signals.GhostCaptured(player, { rarity, zoneId }) after capture.
-- Fire QuestManager.Signals.GroupCapture(player) when ≥3 others within range.
-- Fire QuestManager.Signals.ZoneVisited(player, { zoneId }) on zone entry.

local QuestManager = {}

QuestManager.Signals = {
	GhostCaptured = Signal.new() :: any,
	ZoneVisited = Signal.new() :: any,
	GroupCapture = Signal.new() :: any,
}

-- ─── WIB time helpers ─────────────────────────────────────────────────────────

-- Returns the Unix timestamp for the most recent WIB midnight (00:00 WIB = UTC-17:00).
local function wibMidnight(): number
	local now = os.time()
	local wibSeconds = now + Constants.UTC_OFFSET_WIB
	local secondsInDay = wibSeconds % 86400
	return now - secondsInDay
end

-- Returns the Unix timestamp for the most recent Monday 00:00 WIB.
local function wibMonday(): number
	local midnight = wibMidnight()
	local wibSeconds = os.time() + Constants.UTC_OFFSET_WIB
	-- Shift to WIB midnight in UTC-equivalent space so os.date gives WIB weekday.
	local wibMidnightLocal = wibSeconds - (wibSeconds % 86400)
	local t = os.date("*t", wibMidnightLocal) :: any
	local wday = t.wday :: number -- 1=Sun, 2=Mon, ..., 7=Sat
	local daysBack = (wday - Constants.WEEKLY_RESET_DAY + 7) % 7
	return midnight - daysBack * 86400
end

-- ─── Quest progress helpers ────────────────────────────────────────────────────

-- Increments all matching quests for `eventName` with `payload`, clamps at target,
-- fires QuestProgress and QuestCompleted remotes, and grants rewards on completion.
local function incrementQuests(player: Player, data: { quests: any, xp: number, [string]: any }, eventName: string, payload: { [string]: any })
	local questData = data.quests :: { daily: { [string]: number }, weekly: { [string]: number } }
	local progressRemote = Remotes["QuestProgress"] :: RemoteEvent
	local completedRemote = Remotes["QuestCompleted"] :: RemoteEvent

	for _, def in QuestDefs do
		if def.trackEvent ~= eventName then
			continue
		end

		-- Apply filter
		local filter = def.trackFilter
		if filter ~= nil then
			if filter.rarity ~= nil and payload.rarity ~= filter.rarity then
				continue
			end
			if filter.zone ~= nil and payload.zoneId ~= filter.zone then
				continue
			end
		end

		local bucket: { [string]: number } = if def.type == "daily" then questData.daily else questData.weekly
		local progress = bucket[def.id] or 0

		if progress >= def.target then
			continue -- already completed this cycle
		end

		bucket[def.id] = math.min(progress + 1, def.target)

		progressRemote:FireClient(player, {
			questId = def.id,
			progress = bucket[def.id],
			target = def.target,
		})

		-- Grant reward exactly once when target is first reached
		if bucket[def.id] >= def.target then
			EconomyManager.AddShards(player, def.rewardShards)
			data.xp += def.rewardXP
			local xpRemote = Remotes["XPUpdated"] :: RemoteEvent
			xpRemote:FireClient(player, { xp = data.xp, level = (data :: any).level, gained = def.rewardXP })
			completedRemote:FireClient(player, {
				questId = def.id,
				rewardShards = def.rewardShards,
				rewardXP = def.rewardXP,
			})
			PlayerDataManager.Save(player)
		end
	end
end

-- ─── Daily/weekly reset ────────────────────────────────────────────────────────

local function resetIfNeeded(player: Player, data: { [string]: any })
	local currentDaily = wibMidnight()
	local currentWeekly = wibMonday()
	local dirty = false

	local questData = data.quests :: { daily: { [string]: number }, weekly: { [string]: number } }

	if (data.lastDailyReset :: number) < currentDaily then
		questData.daily = {}
		data.lastDailyReset = currentDaily
		-- Daily login bonus
		EconomyManager.AddShards(player, Constants.SHARD_DAILY_LOGIN)
		dirty = true
	end

	if (data.lastWeeklyReset :: number) < currentWeekly then
		questData.weekly = {}
		data.lastWeeklyReset = currentWeekly
		dirty = true
	end

	if dirty then
		PlayerDataManager.Save(player)
	end
end

-- ─── Init ─────────────────────────────────────────────────────────────────────

function QuestManager.Init()
	-- GhostCaptured signal from CaptureSession
	QuestManager.Signals.GhostCaptured:Connect(function(player: Player, payload: { [string]: any })
		local data = PlayerDataManager.GetData(player)
		if data == nil then
			return
		end
		incrementQuests(player, data :: any, "GhostCaptured", payload)
	end)

	-- ShardCollected — GhostAI fires this when a shard is picked up in a biome zone
	GhostAI.ShardCollected:Connect(function(player: Player, _: Vector3)
		local data = PlayerDataManager.GetData(player)
		if data == nil then
			return
		end
		incrementQuests(player, data :: any, "ShardCollected", {})
	end)

	-- ZoneVisited signal from ZoneDetector (via ZoneChangedToServer remote)
	QuestManager.Signals.ZoneVisited:Connect(function(player: Player, payload: { [string]: any })
		local data = PlayerDataManager.GetData(player)
		if data == nil then
			return
		end
		incrementQuests(player, data :: any, "ZoneVisited", payload)
	end)

	-- GroupCapture signal from CaptureSession
	QuestManager.Signals.GroupCapture:Connect(function(player: Player)
		local data = PlayerDataManager.GetData(player)
		if data == nil then
			return
		end
		incrementQuests(player, data :: any, "GroupCapture", {})
	end)

	-- ZoneChangedToServer: client fires this when entering a zone; server fires ZoneVisited signal.
	local zoneChangedRemote = Remotes["ZoneChangedToServer"] :: RemoteEvent
	zoneChangedRemote.OnServerEvent:Connect(function(player: Player, zoneId: any)
		if type(zoneId) ~= "string" then
			return
		end
		-- Validate zoneId against known zones to prevent exploits
		if ZoneDefs[zoneId] == nil then
			return
		end
		QuestManager.Signals.ZoneVisited:Fire(player, { zoneId = zoneId })
	end)

	-- Reset check on player load; also grant daily login shards
	PlayerDataManager.OnLoaded(function(player: Player, data)
		resetIfNeeded(player, data :: any)
	end)

	-- Cover players already loaded in studio test runs
	for _, player in Players:GetPlayers() do
		local data = PlayerDataManager.GetData(player)
		if data ~= nil then
			resetIfNeeded(player, data :: any)
		end
	end
end

return QuestManager
