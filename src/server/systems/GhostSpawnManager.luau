--!strict
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)
local GhostDefs = require(ReplicatedStorage.Shared.GhostDefs)
local Util = require(ReplicatedStorage.Shared.Util)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local WorldBuilder = require(ServerScriptService.Server.systems.WorldBuilder)
local GhostAI = require(ServerScriptService.Server.systems.GhostAI)

-- Typed aliases
type GhostDef = typeof(GhostDefs["Pocong"])
type ActiveEntry = {
	def: GhostDef,
	instanceId: string,
	ghostId: string,
	zoneId: string,
	hauntPointIndex: number,
	resistance: number,
	state: string,
	model: Model?,
	isMythicEvent: boolean, -- BataraGuruShadow server-wide event; not counted toward cap
	isTutorial: boolean,    -- scripted tutorial ghost; not counted toward cap, no AI
	fakePart: BasePart?, -- position anchor for mythic event (no real HauntPoint in Hub)
}

-- ─── State ────────────────────────────────────────────────────────────────────

-- instanceId → ActiveEntry; source of truth for all live ghosts
local activeInstances: { [string]: ActiveEntry } = {}

-- Quick lookup: zoneId → set of occupied hauntPointIndex values
local occupiedPoints: { [string]: { [number]: string } } = {} -- zoneId → index → instanceId

-- Ghost asset folder (may not exist before Studio sync)
local ghostAssetsFolder: Folder? = nil

-- Prevents more than one BataraGuruShadow from spawning simultaneously.
-- Declared here (not near startMythicEventLoop) because despawnInstance resets it.
local mythicEventActive = false

-- ─── Helpers ──────────────────────────────────────────────────────────────────

-- Buckets by rarity, built once on init from GhostDefs.
local ghostsByRarity: { [string]: { GhostDef } } = {
	Common = {},
	Rare = {},
	Epic = {},
	Mythic = {},
}

local function buildRarityBuckets()
	for _, def in GhostDefs do
		local bucket = ghostsByRarity[def.rarity]
		if bucket then
			table.insert(bucket, def)
		end
	end
end

local function countActive(): number
	local n = 0
	for _, entry in activeInstances do
		if not entry.isMythicEvent and not entry.isTutorial then
			n += 1
		end
	end
	return n
end

-- Returns a random unoccupied {zoneId, index, part} or nil if all are full.
-- Pass excludeZoneId + excludeIndex to avoid re-using the exact same haunt point.
local function pickHauntPoint(
	excludeZoneId: string?,
	excludeIndex: number?
): { zoneId: string, index: number, part: BasePart }?
	-- Collect all unoccupied haunt points
	local candidates: { { zoneId: string, index: number, part: BasePart } } = {}
	for zoneId, parts in WorldBuilder.HauntPoints do
		local occupied = occupiedPoints[zoneId] or {}
		for i, part in parts do
			if occupied[i] == nil then
				-- Skip the excluded point to guarantee "different haunt point"
				if zoneId == excludeZoneId and i == excludeIndex then
					continue
				end
				table.insert(candidates, { zoneId = zoneId, index = i, part = part })
			end
		end
	end
	if #candidates == 0 then
		return nil
	end
	return candidates[math.random(1, #candidates)]
end

-- Builds a weight table for ghosts of a given rarity in a given zone.
-- Ghosts in affinityZones for this zone get AFFINITY_WEIGHT_BONUS weight; others get 1.
local function buildGhostWeights(rarity: string, zoneId: string): { [string]: number }
	local weights: { [string]: number } = {}
	local bucket = ghostsByRarity[rarity]
	if not bucket then
		return weights
	end
	for _, def in bucket do
		local w = 1
		for _, az in def.affinityZones do
			if az == zoneId then
				w = Constants.AFFINITY_WEIGHT_BONUS
				break
			end
		end
		weights[def.id] = w
	end
	return weights
end

local function getGhostsFolder(): Folder
	local f = Workspace:FindFirstChild("Ghosts") :: Folder?
	if f then
		return f
	end
	-- Fallback: create it (WorldBuilder should have done this already)
	local folder = Instance.new("Folder")
	folder.Name = "Ghosts"
	folder.Parent = Workspace
	return folder
end

-- Forward declaration so spawnGhostAt closures can reference it before the full
-- definition appears below (mutual recursion: spawnGhostAt ↔ handleCaptureOrEscape).
local handleCaptureOrEscape: (instanceId: string) -> ()

-- Shared state-change helper used by both spawnGhostAt callbacks and SetState.
-- Avoids a forward reference to GhostSpawnManager inside local closures.
local function setInstanceState(instanceId: string, newState: string, extra: { [string]: any }?)
	local entry = activeInstances[instanceId]
	if entry then
		entry.state = newState
	end
	local payload: { [string]: any } = { instanceId = instanceId, state = newState }
	if extra then
		for k, v in extra do
			payload[k] = v
		end
	end
	local stateRemote = Remotes["GhostStateChanged"] :: RemoteEvent
	stateRemote:FireAllClients(payload)
end

local function spawnGhostAt(
	zoneId: string,
	hauntPointIndex: number,
	hauntPart: BasePart,
	isMythicEvent: boolean
): string?
	-- Pick rarity then ghost
	local rarity = Util.weightedRandom(Constants.RARITY_SPAWN_WEIGHT)
	local weights = buildGhostWeights(rarity, zoneId)
	if next(weights) == nil then
		-- No ghosts of this rarity — fallback to Common
		rarity = "Common"
		weights = buildGhostWeights("Common", zoneId)
	end
	local ghostId = Util.weightedRandom(weights)
	local def = GhostDefs[ghostId]
	if def == nil then
		warn("[GhostSpawnManager] Unknown ghostId from weightedRandom:", ghostId)
		return nil
	end

	local instanceId = HttpService:GenerateGUID(false)

	-- Mark haunt point occupied before any yields
	if occupiedPoints[zoneId] == nil then
		occupiedPoints[zoneId] = {}
	end
	occupiedPoints[zoneId][hauntPointIndex] = instanceId

	-- Clone model (may be nil if assets not yet in place)
	local model: Model? = nil
	if ghostAssetsFolder then
		local template = ghostAssetsFolder:FindFirstChild(def.modelName) :: Model?
		if template then
			local clone = template:Clone() :: Model
			clone.Name = instanceId
			clone:PivotTo(CFrame.new(hauntPart.Position))
			clone.Parent = getGhostsFolder()
			model = clone
		end
	end

	local entry: ActiveEntry = {
		def = def,
		instanceId = instanceId,
		ghostId = ghostId,
		zoneId = zoneId,
		hauntPointIndex = hauntPointIndex,
		resistance = def.maxResistance,
		state = "Patrolling",
		model = model,
		isMythicEvent = isMythicEvent,
		isTutorial = false,
		fakePart = nil,
	}
	activeInstances[instanceId] = entry

	-- Start AI loop — captures instanceId for callbacks; no circular require.
	GhostAI.Start(instanceId, def, model, hauntPart.Position, {
		onStateChanged = function(newState: string, extra: { [string]: any }?)
			setInstanceState(instanceId, newState, extra)
		end,
		onEscape = function()
			handleCaptureOrEscape(instanceId)
		end,
	} :: GhostAI.GhostAICallbacks)

	-- §22 Rule 7: position is server-computed from haunt point; client receives it read-only.
	local ghostsRemote = Remotes["GhostSpawned"] :: RemoteEvent
	ghostsRemote:FireAllClients({
		instanceId = instanceId,
		ghostId = ghostId,
		zoneId = zoneId,
		position = hauntPart.Position,
		rarity = def.rarity,
		behavior = def.behavior,
		miniGame = def.miniGame,
	})

	return instanceId
end

local function despawnInstance(instanceId: string, reason: string)
	local entry = activeInstances[instanceId]
	if entry == nil then
		return
	end

	-- Stop AI loop before removing the entry
	GhostAI.Stop(instanceId)

	-- Free the haunt point
	local zoneOccupied = occupiedPoints[entry.zoneId]
	if zoneOccupied then
		zoneOccupied[entry.hauntPointIndex] = nil
	end

	-- Destroy model and mythic event position anchor
	if entry.model and entry.model.Parent ~= nil then
		entry.model:Destroy()
	end
	if entry.fakePart and entry.fakePart.Parent ~= nil then
		entry.fakePart:Destroy()
	end
	if entry.isMythicEvent then
		mythicEventActive = false
	end

	activeInstances[instanceId] = nil

	local despawnRemote = Remotes["GhostDespawned"] :: RemoteEvent
	despawnRemote:FireAllClients({ instanceId = instanceId, reason = reason })
end

-- Assigned here (after despawnInstance and spawnGhostAt are both defined).
-- handleCaptureOrEscape was forward-declared above spawnGhostAt so the
-- onEscape closure could reference it without a circular local-variable issue.
handleCaptureOrEscape = function(instanceId: string)
	local entry = activeInstances[instanceId]
	if entry == nil then
		return
	end
	local prevZoneId = entry.zoneId
	local prevIndex = entry.hauntPointIndex
	local wasMythicEvent = entry.isMythicEvent

	despawnInstance(instanceId, "CaptureOrEscape")

	task.delay(Constants.CAPTURE_COOLDOWN, function()
		if wasMythicEvent then
			return -- mythic event has its own respawn loop
		end
		if countActive() >= Constants.MAX_ACTIVE_GHOSTS then
			return
		end
		local slot = pickHauntPoint(prevZoneId, prevIndex)
		if slot == nil then
			return
		end
		spawnGhostAt(slot.zoneId, slot.index, slot.part, false)
	end)
end

-- ─── Public API ───────────────────────────────────────────────────────────────

local GhostSpawnManager = {}

-- Returns the ActiveEntry for a given instanceId, or nil if not found.
function GhostSpawnManager.GetActiveInstance(instanceId: string): ActiveEntry?
	return activeInstances[instanceId]
end

-- Returns all active instances (read-only intent; do not mutate from outside).
function GhostSpawnManager.GetAllActiveInstances(): { [string]: ActiveEntry }
	return activeInstances
end

-- Updates the state of an instance and fires GhostStateChanged to all clients.
-- Also called by CaptureSession to set "InCapture" / "Captured" states directly.
function GhostSpawnManager.SetState(instanceId: string, newState: string, extra: { [string]: any }?)
	setInstanceState(instanceId, newState, extra)
end

-- Called by CaptureSession after a ghost is captured or escapes.
function GhostSpawnManager.OnCaptureOrEscape(instanceId: string)
	handleCaptureOrEscape(instanceId)
end

-- ─── BataraGuruShadow server-wide event ───────────────────────────────────────

local function startMythicEventLoop()
	task.spawn(function()
		while true do
			task.wait(60)

			if mythicEventActive then
				continue
			end

			local playerCount = #Players:GetPlayers()
			if playerCount < Constants.MYTHIC_EVENT_MIN_PLAYERS then
				continue
			end

			-- Find the Hub haunt point (Hub is at HUB_SPAWN; use its position directly)
			local hubPos = Constants.HUB_SPAWN
			local fakePart = Instance.new("Part") :: BasePart
			fakePart.Position = hubPos
			fakePart.Anchored = true
			fakePart.CanCollide = false
			fakePart.Transparency = 1
			fakePart.Name = "BataraGuruEventPoint"
			fakePart.Parent = Workspace

			-- Use a dedicated zone slot that won't collide with real haunt points.
			-- We reserve zoneId = "HubEvent" and index = 0 for this.
			local eventZone = "HubEvent"
			local eventIndex = 0
			if occupiedPoints[eventZone] == nil then
				occupiedPoints[eventZone] = {}
			end
			if occupiedPoints[eventZone][eventIndex] ~= nil then
				fakePart:Destroy()
				continue -- already spawned (shouldn't happen but guard anyway)
			end

			mythicEventActive = true

			-- Force-spawn BataraGuruShadow
			local def = GhostDefs["BataraGuruShadow"]
			if def == nil then
				mythicEventActive = false
				fakePart:Destroy()
				continue
			end

			local instanceId = HttpService:GenerateGUID(false)
			occupiedPoints[eventZone][eventIndex] = instanceId

			local model: Model? = nil
			if ghostAssetsFolder then
				local template = ghostAssetsFolder:FindFirstChild(def.modelName) :: Model?
				if template then
					local clone = template:Clone() :: Model
					clone.Name = instanceId
					clone:PivotTo(CFrame.new(hubPos))
					clone.Parent = getGhostsFolder()
					model = clone
				end
			end

			local entry: ActiveEntry = {
				def = def,
				instanceId = instanceId,
				ghostId = "BataraGuruShadow",
				zoneId = eventZone,
				hauntPointIndex = eventIndex,
				resistance = def.maxResistance,
				state = "Triggered", -- server-wide event: immediately active
				model = model,
				isMythicEvent = true,
				isTutorial = false,
				fakePart = fakePart,
			}
			activeInstances[instanceId] = entry

			-- Start AI pre-triggered; BataraGuruShadow is Trickster with TeamSurround.
			GhostAI.Start(instanceId, def, model, hubPos, {
				onStateChanged = function(newState: string, extra: { [string]: any }?)
					setInstanceState(instanceId, newState, extra)
				end,
				onEscape = function()
					handleCaptureOrEscape(instanceId)
				end,
			} :: GhostAI.GhostAICallbacks, true)

			local ghostsRemote = Remotes["GhostSpawned"] :: RemoteEvent
			ghostsRemote:FireAllClients({
				instanceId = instanceId,
				ghostId = "BataraGuruShadow",
				zoneId = eventZone,
				position = hubPos,
				rarity = "Mythic",
				behavior = "Trickster",
				miniGame = "TeamSurround",
				isMythicEvent = true,
			})

			-- Auto-despawn after 10 min if not captured.
			-- despawnInstance handles fakePart cleanup and resets mythicEventActive.
			task.delay(Constants.MYTHIC_EVENT_DESPAWN_TIME, function()
				if activeInstances[instanceId] ~= nil then
					despawnInstance(instanceId, "MythicTimeout")
				end
			end)
		end
	end)
end

-- ─── Tutorial spawn ───────────────────────────────────────────────────────────

-- Spawns a scripted tutorial ghost at a fixed world position for a specific player.
-- The ghost has no AI (no patrol, no auto-escape), resistance overridden to 1.
-- Counts as a real ghost for the Compendium but NOT toward the ghost cap.
-- Returns the instanceId, or nil if ghostId is invalid.
function GhostSpawnManager.SpawnTutorial(ghostId: string, worldPos: Vector3, player: Player): string?
	local def = GhostDefs[ghostId]
	if def == nil then
		warn("[GhostSpawnManager] SpawnTutorial: unknown ghostId", ghostId)
		return nil
	end

	local instanceId = HttpService:GenerateGUID(false)

	local model: Model? = nil
	if ghostAssetsFolder then
		local template = ghostAssetsFolder:FindFirstChild(def.modelName) :: Model?
		if template then
			local clone = template:Clone() :: Model
			clone.Name = instanceId
			clone:PivotTo(CFrame.new(worldPos))
			clone.Parent = getGhostsFolder()
			model = clone
		end
	end

	local entry: ActiveEntry = {
		def = def,
		instanceId = instanceId,
		ghostId = ghostId,
		zoneId = "Hub",
		hauntPointIndex = 0,
		resistance = 1, -- always one hit
		state = "Triggered", -- immediately capturable
		model = model,
		isMythicEvent = false,
		isTutorial = true,
		fakePart = nil,
	}
	activeInstances[instanceId] = entry

	-- No GhostAI.Start — tutorial ghost is static; no patrol, no escape timer.

	-- Notify only the specific player (tutorial is player-local).
	local ghostsRemote = Remotes["GhostSpawned"] :: RemoteEvent
	ghostsRemote:FireClient(player, {
		instanceId = instanceId,
		ghostId = ghostId,
		zoneId = "Hub",
		position = worldPos,
		rarity = def.rarity,
		behavior = def.behavior,
		miniGame = def.miniGame,
	})

	return instanceId
end

-- ─── Init ─────────────────────────────────────────────────────────────────────

function GhostSpawnManager.Init()
	buildRarityBuckets()

	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets") :: Folder?
	if assetsFolder then
		ghostAssetsFolder = assetsFolder:FindFirstChild("Ghosts") :: Folder?
	end

	-- Initial population: fill up to MAX_ACTIVE_GHOSTS using all available haunt points
	local allPoints: { { zoneId: string, index: number, part: BasePart } } = {}
	for zoneId, parts in WorldBuilder.HauntPoints do
		for i, part in parts do
			table.insert(allPoints, { zoneId = zoneId, index = i, part = part })
		end
	end

	-- Shuffle so zones get mixed coverage, not just the first zones filled first
	for i = #allPoints, 2, -1 do
		local j = math.random(1, i)
		allPoints[i], allPoints[j] = allPoints[j], allPoints[i]
	end

	local spawned = 0
	for _, slot in allPoints do
		if spawned >= Constants.MAX_ACTIVE_GHOSTS then
			break
		end
		spawnGhostAt(slot.zoneId, slot.index, slot.part, false)
		spawned += 1
	end

	startMythicEventLoop()
end

return GhostSpawnManager
