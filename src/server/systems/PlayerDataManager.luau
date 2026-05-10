--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileService = require(ServerScriptService.ServerPackages.ProfileService)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Types = require(ReplicatedStorage.Shared.Types)

type PlayerProfile = Types.PlayerProfile
type Profile = { Data: PlayerProfile, IsActive: (self: any) -> boolean, Reconcile: (self: any) -> (), ListenToRelease: (self: any, cb: () -> ()) -> (), Release: (self: any) -> (), Save: (self: any) -> () }

local PROFILE_STORE_NAME = "PlayerData_v1"

-- Template must list every key so :Reconcile() fills gaps for returning players.
-- `companion` intentionally omitted — nil default is correct and ProfileService
-- would store a nil key which causes reconcile to skip it anyway.
local PROFILE_TEMPLATE: { [string]: any } = {
	level = 1,
	xp = 0,
	compendium = {},
	shards = 50,
	bottles = { BotolBiasa = Constants.BOTTLE_DEFAULT_COUNT },
	quests = { daily = {}, weekly = {} },
	lastDailyReset = 0,
	lastWeeklyReset = 0,
	gamepasses = {},
	cosmetics = {},
	tutorialDone = false,
	milestones = {},
	xpBoostExpiry = 0,
	purchaseHistory = {},
}

local profileStore = ProfileService.GetProfileStore(PROFILE_STORE_NAME, PROFILE_TEMPLATE)

local activeProfiles: { [number]: Profile } = {}
local loadedCallbacks: { (player: Player, data: PlayerProfile) -> () } = {}

local PlayerDataManager = {}

-- Register a callback fired once per player when their profile is ready.
-- Systems that need player data on join must use this rather than polling GetData.
function PlayerDataManager.OnLoaded(callback: (player: Player, data: PlayerProfile) -> ())
	table.insert(loadedCallbacks, callback)
end

-- Returns the raw ProfileService Profile object; server-internal use only.
function PlayerDataManager.GetProfile(player: Player): Profile?
	return activeProfiles[player.UserId]
end

-- Returns the mutable PlayerProfile data table, or nil if not yet loaded.
-- Never write to the returned table from outside a single atomic operation;
-- all writes must happen before the next task.wait() to stay consistent.
function PlayerDataManager.GetData(player: Player): PlayerProfile?
	local profile = activeProfiles[player.UserId]
	if profile == nil then
		return nil
	end
	return profile.Data
end

-- Explicit save. ProfileService auto-saves on interval; call after high-value
-- mutations (capture rewards, purchases) so data isn't lost on crash.
function PlayerDataManager.Save(player: Player)
	local profile = activeProfiles[player.UserId]
	if profile and profile:IsActive() then
		profile:Save()
	end
end

local function fireLoadedCallbacks(player: Player, data: PlayerProfile)
	for _, cb in loadedCallbacks do
		task.spawn(cb, player, data)
	end
end

local function onPlayerAdded(player: Player)
	local ok, profile = pcall(function()
		return profileStore:LoadProfileAsync("Player_" .. player.UserId)
	end)

	if not ok then
		warn("[PlayerDataManager] LoadProfileAsync error for", player.Name, ":", profile)
		player:Kick("Data failed to load. Please rejoin.")
		return
	end

	if profile == nil then
		-- Session lock held by another server — safe to kick so they can rejoin.
		warn("[PlayerDataManager] Profile nil (session locked) for", player.Name)
		player:Kick("Your data is loaded on another server. Please rejoin in a moment.")
		return
	end

	-- Fill in any keys added to the template after this player's last session.
	profile:Reconcile()

	-- ProfileService signals this when another server takes ownership.
	profile:ListenToRelease(function()
		activeProfiles[player.UserId] = nil
		player:Kick("Your session was claimed by another server. Please rejoin.")
	end)

	if not player:IsDescendantOf(Players) then
		-- Player left during the async load — release immediately.
		profile:Release()
		return
	end

	activeProfiles[player.UserId] = profile
	fireLoadedCallbacks(player, profile.Data)
end

local function onPlayerRemoving(player: Player)
	local profile = activeProfiles[player.UserId]
	if profile then
		profile:Release()
		activeProfiles[player.UserId] = nil
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Cover players who joined before this module was required (studio test runs).
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

return PlayerDataManager
