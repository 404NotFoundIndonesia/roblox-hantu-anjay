--!strict
-- CaptureSession — T-18 (core flow), T-19 (validators), T-20 (XP), T-21 (milestones)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)
local BottleDefs = require(ReplicatedStorage.Shared.BottleDefs)
local XPTable = require(ReplicatedStorage.Shared.XPTable)
local Types = require(ReplicatedStorage.Shared.Types)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local GhostDefs = require(ReplicatedStorage.Shared.GhostDefs)
local GhostSpawnManager = require(ServerScriptService.Server.systems.GhostSpawnManager)
local GhostAI = require(ServerScriptService.Server.systems.GhostAI)
local PlayerDataManager = require(ServerScriptService.Server.systems.PlayerDataManager)
local QuestManager = require(ServerScriptService.Server.systems.QuestManager)
local TutorialManager = require(ServerScriptService.Server.systems.TutorialManager)

type PlayerProfile = Types.PlayerProfile

-- Mirrors GhostDef from GhostDefs.luau; inline to avoid re-importing the full dict.
type GhostDef = {
	id: string,
	rarity: string,
	behavior: string,
	miniGame: string,
	maxResistance: number,
	speed: number,
	detectionRange: number,
	soundId: number,
	modelName: string,
	nameKey: string,
	loreKey: string,
	affinityZones: { string },
}

-- ─── Types ────────────────────────────────────────────────────────────────────

type MiniGameState = {
	-- MantraTap
	symbols: { string }?,
	currentStep: number,
	-- SignalTriangulate
	targetAngle: number?,
	-- ShadowChase (resistance reset to startResistance on body contact)
	startResistance: number,
	-- TeamSurround
	surroundParts: { BasePart }?,
	surroundFilled: { [number]: boolean }?,
	surroundConnections: { RBXScriptConnection }?,
}

type ActiveSession = {
	instanceId: string,
	ghostId: string,
	player: Player,
	bottleId: string,
	miniGame: string,
	resistance: number,
	maxResistance: number,
	resolved: boolean,
	miniGameState: MiniGameState,
}

-- ─── Module state ─────────────────────────────────────────────────────────────

local activeSessions: { [string]: ActiveSession } = {}
local captureRateLimit: { [number]: number } = {} -- userId → os.clock()
local inputRateLimit: { [string]: number } = {} -- "userId_instanceId" → os.clock()

-- ─── Mini-game constants ──────────────────────────────────────────────────────

local RARITY_RANK: { [string]: number } = { Common = 1, Rare = 2, Epic = 3, Mythic = 4 }
local MANTRATAP_SYMBOLS = { "circle", "star", "moon", "sun", "wave", "spiral" }
local RHYTHM_BPM = 120
local SURROUND_RADIUS = 8
local SURROUND_POSITIONS = 3
local SURROUND_HOLD_TIME = 3 -- seconds all positions must be held simultaneously
local GROUP_CAPTURE_RADIUS = 40 -- studs; other players within this range count for GroupCapture quest

-- ─── Helpers ─────────────────────────────────────────────────────────────────

local function getRankKey(level: number): string
	for _, range in Constants.RANK_RANGES do
		if level >= range.minLevel and level <= range.maxLevel then
			return range.key
		end
	end
	return "RANK_LEGENDA_TITLE"
end

local function getPlayerPosition(player: Player): Vector3?
	local char = player.Character
	if not char then
		return nil
	end
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	return hrp and hrp.Position or nil
end

local function getEntryPosition(entry: { model: Model?, fakePart: BasePart?, [string]: any }): Vector3?
	local model = entry.model :: Model?
	if model and model.Parent ~= nil then
		return model:GetPivot().Position
	end
	local fp = entry.fakePart :: BasePart?
	if fp and fp.Parent ~= nil then
		return fp.Position
	end
	return nil
end

local function angleDiff(a: number, b: number): number
	local d = math.abs(a - b) % 360
	return if d > 180 then 360 - d else d
end

-- ─── Mini-game config generators ─────────────────────────────────────────────

local function makeMantraTapConfig(resistance: number): ({ string }, { [string]: any })
	local len = math.max(3, math.ceil(resistance / 2))
	local symbols: { string } = {}
	for _ = 1, len do
		table.insert(symbols, MANTRATAP_SYMBOLS[math.random(1, #MANTRATAP_SYMBOLS)])
	end
	return symbols, { symbols = symbols, timeLimit = Constants.CAPTURE_TIMEOUT }
end

local function makeRhythmConfig(resistance: number): { [string]: any }
	local noteCount = math.max(3, math.ceil(resistance / 2))
	local interval = 60 / RHYTHM_BPM
	local notes: { { lane: number, timing: number } } = {}
	for i = 1, noteCount do
		table.insert(notes, { lane = math.random(1, 3), timing = i * interval })
	end
	return { notes = notes, bpm = RHYTHM_BPM }
end

local function makeSurroundPositions(origin: Vector3): ({ Vector3 }, { [string]: any })
	local positions: { Vector3 } = {}
	for i = 1, SURROUND_POSITIONS do
		local angle = (i - 1) * (2 * math.pi / SURROUND_POSITIONS)
		table.insert(positions, Vector3.new(
			origin.X + math.cos(angle) * SURROUND_RADIUS,
			origin.Y,
			origin.Z + math.sin(angle) * SURROUND_RADIUS
		))
	end
	return positions, { positions = positions, requiredPlayers = Constants.MYTHIC_MIN_PLAYERS }
end

-- ─── T-19 · Mini-game validators ─────────────────────────────────────────────

-- MantraTap: validate { step, symbol } in strict order. delta=2 correct, 0 wrong.
-- Tutorial instances accept any tap as correct (forgiving mode, resistance=1 so one hit captures).
local function validateMantraTap(session: ActiveSession, input: { [string]: any }): number
	local state = session.miniGameState
	if TutorialManager.IsTutorialInstance(session.instanceId) then
		state.currentStep += 1
		return 2
	end
	if state.symbols == nil then
		return 0
	end
	local step = input.step
	local symbol = input.symbol
	if type(step) ~= "number" or type(symbol) ~= "string" then
		return 0
	end
	if step ~= state.currentStep then
		return 0 -- sequence skip attempt rejected
	end
	local expected = (state.symbols :: { string })[step]
	if expected ~= symbol then
		return 0
	end
	state.currentStep += 1
	return 2
end

-- BottleAim: { heldSeconds } increments; delta = 3 * seconds, clamped to [0,1] per call.
local function validateBottleAim(session: ActiveSession, input: { [string]: any }): number
	local held = input.heldSeconds
	if type(held) ~= "number" then
		return 0
	end
	held = math.clamp(held, 0, 1)
	local delta = math.floor(3 * held)
	return math.min(delta, session.resistance)
end

-- RhythmChant: { lane, hitDelta }. delta=2 if |hitDelta| ≤ 0.15s, else 0.
local function validateRhythmChant(input: { [string]: any }): number
	local hitDelta = input.hitDelta
	if type(hitDelta) ~= "number" then
		return 0
	end
	return if math.abs(hitDelta) <= 0.15 then 2 else 0
end

-- SignalTriangulate: { submittedAngle }. Full clear ≤15°, partial ≤45°, zero beyond.
local function validateSignalTriangulate(session: ActiveSession, input: { [string]: any }): number
	local state = session.miniGameState
	if state.targetAngle == nil then
		return 0
	end
	local submitted = input.submittedAngle
	if type(submitted) ~= "number" then
		return 0
	end
	submitted = submitted % 360
	local diff = angleDiff(submitted, state.targetAngle :: number)
	if diff <= 15 then
		return session.resistance -- full clear
	elseif diff <= 45 then
		local t = (diff - 15) / 30
		return math.max(1, math.floor(session.resistance * (1 - t)))
	end
	return 0
end

-- ShadowChase: { contact }. "shadow"=1 delta; "body"=resistance reset to max, 0 delta.
local function validateShadowChase(session: ActiveSession, input: { [string]: any }): number
	local contact = input.contact
	if type(contact) ~= "string" then
		return 0
	end
	if contact == "shadow" then
		return 1
	elseif contact == "body" then
		session.resistance = session.maxResistance
		return 0
	end
	return 0
end

-- ─── TeamSurround server monitoring ──────────────────────────────────────────

local resolveCapture: (instanceId: string, reason: string) -> () -- forward declaration; body assigned below

local function setupTeamSurround(session: ActiveSession, positions: { Vector3 })
	local parts: { BasePart } = {}
	local filled: { [number]: boolean } = {}
	local connections: { RBXScriptConnection } = {}

	for i, pos in positions do
		filled[i] = false

		local part = Instance.new("Part")
		part.Size = Vector3.new(4, 4, 4)
		part.Position = pos
		part.Anchored = true
		part.CanCollide = false
		part.Transparency = 0.75
		part.BrickColor = BrickColor.new("Bright red")
		part.Name = "SurroundPos_" .. i
		part.Parent = Workspace

		table.insert(parts, part)

		local idx = i
		local touchConn = part.Touched:Connect(function(hit: BasePart)
			local char = hit.Parent :: Model?
			if char == nil then
				return
			end
			if Players:GetPlayerFromCharacter(char) ~= nil then
				filled[idx] = true
			end
		end)
		local endConn = part.TouchEnded:Connect(function(hit: BasePart)
			local char = hit.Parent :: Model?
			if char == nil then
				return
			end
			if Players:GetPlayerFromCharacter(char) ~= nil then
				filled[idx] = false
			end
		end)
		table.insert(connections, touchConn)
		table.insert(connections, endConn)
	end

	session.miniGameState.surroundParts = parts
	session.miniGameState.surroundFilled = filled
	session.miniGameState.surroundConnections = connections

	-- Server-side monitoring loop — no client input needed
	task.spawn(function()
		local allFilledSince: number? = nil
		while activeSessions[session.instanceId] ~= nil do
			task.wait(0.1)
			local allFilled = true
			for i = 1, SURROUND_POSITIONS do
				if not filled[i] then
					allFilled = false
					break
				end
			end
			if allFilled then
				if allFilledSince == nil then
					allFilledSince = os.clock()
				elseif os.clock() - allFilledSince >= SURROUND_HOLD_TIME then
					-- All positions held for required time — resolve
					session.resistance = 0
					resolveCapture(session.instanceId, "TeamSurround")
					break
				end
			else
				allFilledSince = nil
			end
		end
	end)
end

local function cleanupTeamSurround(session: ActiveSession)
	local state = session.miniGameState
	if state.surroundConnections then
		for _, conn in state.surroundConnections :: { RBXScriptConnection } do
			conn:Disconnect()
		end
	end
	if state.surroundParts then
		for _, part in state.surroundParts :: { BasePart } do
			if part.Parent ~= nil then
				part:Destroy()
			end
		end
	end
	state.surroundParts = nil
	state.surroundConnections = nil
	state.surroundFilled = nil
end

-- ─── T-20 · XP & leveling ────────────────────────────────────────────────────

local function awardXP(player: Player, data: PlayerProfile, def: GhostDef, isFirstCapture: boolean)
	local baseXP: number = (Constants.XP_PER_RARITY :: { [string]: number })[def.rarity] or 10
	local mult = 1.0

	if isFirstCapture then
		mult *= Constants.FIRST_CAPTURE_BONUS_MULTIPLIER
	end
	if data.gamepasses[tostring(Constants.GAMEPASS_ID_VIP)] then
		mult *= Constants.VIP_XP_MULTIPLIER
	end
	if os.time() < data.xpBoostExpiry then
		mult *= Constants.XP_BOOST_MULTIPLIER
	end

	local gained = math.floor(baseXP * mult)
	data.xp += gained

	local xpRemote = Remotes["XPUpdated"] :: RemoteEvent
	xpRemote:FireClient(player, { xp = data.xp, level = data.level, gained = gained })

	-- Multi-level-up support
	local prevLevel = data.level
	while data.level < 100 do
		local threshold = XPTable[data.level + 1]
		if threshold == nil or data.xp < threshold then
			break
		end
		data.level += 1
	end

	if data.level > prevLevel then
		local levelUpRemote = Remotes["LevelUp"] :: RemoteEvent
		levelUpRemote:FireClient(player, {
			newLevel = data.level,
			rank = getRankKey(data.level),
		})
	end
end

-- ─── T-21 · Milestone checks ─────────────────────────────────────────────────

local function checkMilestones(player: Player, data: PlayerProfile)
	-- Count distinct ghost types with at least one capture
	local total = 0
	for _, entry in data.compendium do
		if entry.captureCount > 0 then
			total += 1
		end
	end

	local notifRemote = Remotes["QuestCompleted"] :: RemoteEvent

	if total >= Constants.MILESTONE_AURA_COUNT and not data.milestones["aura_mistis"] then
		data.milestones["aura_mistis"] = true
		notifRemote:FireClient(player, { type = "milestone", key = "aura_mistis" })
	end

	if total >= Constants.MILESTONE_TITLE_COUNT and not data.milestones["title_kolektor"] then
		data.milestones["title_kolektor"] = true
		notifRemote:FireClient(player, { type = "milestone", key = "title_kolektor" })
	end

	if total >= Constants.MILESTONE_KRISTAL_COUNT and not data.milestones["botol_kristal"] then
		data.milestones["botol_kristal"] = true
		data.bottles["BotolKristal"] = (data.bottles["BotolKristal"] or 0) + 1
		notifRemote:FireClient(player, { type = "milestone", key = "botol_kristal" })
		local bottlesRemote = Remotes["BottlesUpdated"] :: RemoteEvent
		bottlesRemote:FireClient(player, { bottles = data.bottles })
	end
end

-- ─── T-18 · Core capture resolution ──────────────────────────────────────────

-- Assign the real body now that all helpers are defined.
resolveCapture = function(instanceId: string, reason: string)
	local session = activeSessions[instanceId]
	if session == nil then
		return
	end
	if session.resolved then
		return
	end
	session.resolved = true
	activeSessions[instanceId] = nil

	cleanupTeamSurround(session)
	GhostAI.NotifyCaptureEnd(instanceId)

	local player = session.player
	local data = PlayerDataManager.GetData(player)
	local bottleDef = BottleDefs[session.bottleId]
	local ghostEntry = GhostSpawnManager.GetActiveInstance(instanceId)

	if data == nil then
		-- ProfileService failure — fire fail and clean up
		local miniEndRemote = Remotes["MiniGameEnd"] :: RemoteEvent
		miniEndRemote:FireClient(player, { instanceId = instanceId, result = "Fail" })
		GhostSpawnManager.OnCaptureOrEscape(instanceId)
		return
	end

	-- Decrement bottle on any use (success or fail), unless unlimited
	if bottleDef and not bottleDef.unlimited then
		local count = data.bottles[session.bottleId] or 0
		data.bottles[session.bottleId] = math.max(0, count - 1)
		local bottlesRemote = Remotes["BottlesUpdated"] :: RemoteEvent
		bottlesRemote:FireClient(player, { bottles = data.bottles })
	end

	-- Catch rate check (server-authoritative; client never provides this value).
	-- Tutorial instances always succeed when resistance reaches 0 (catchRate = 1.0 override).
	local isTutorial = TutorialManager.IsTutorialInstance(instanceId)
	local success = session.resistance <= 0
		and bottleDef ~= nil
		and (isTutorial or math.random() <= bottleDef.catchRate)

	if success and ghostEntry ~= nil then
		local ghostId = session.ghostId
		local isFirstCapture = data.compendium[ghostId] == nil

		if isFirstCapture then
			data.compendium[ghostId] = { captureCount = 1, firstCapturedAt = os.time() }
		else
			data.compendium[ghostId].captureCount += 1
		end

		awardXP(player, data, ghostEntry.def :: GhostDef, isFirstCapture)

		local compRemote = Remotes["CompendiumUpdated"] :: RemoteEvent
		compRemote:FireClient(player, { ghostId = ghostId, entry = data.compendium[ghostId] })

		checkMilestones(player, data)

		-- Update companion ghost to rarest captured (T-45).
		local bestId: string? = nil
		local bestRank = 0
		for gId, entry in data.compendium do
			if entry.captureCount > 0 then
				local gDef = GhostDefs[gId]
				if gDef ~= nil then
					local rank = RARITY_RANK[gDef.rarity] or 0
					if rank > bestRank then
						bestRank = rank
						bestId = gId
					end
				end
			end
		end
		if bestId ~= nil and bestId ~= data.companion then
			data.companion = bestId
			;(Remotes["CompanionSet"] :: RemoteEvent):FireClient(player, { ghostId = bestId })
		end

		-- Quest tracking: GhostCaptured + GroupCapture
		local capturePos = getEntryPosition(ghostEntry :: any)
		QuestManager.Signals.GhostCaptured:Fire(player, { rarity = ghostEntry.def.rarity, zoneId = ghostEntry.zoneId })
		if capturePos ~= nil then
			local nearbyCount = 0
			for _, otherPlayer in Players:GetPlayers() do
				if otherPlayer == player then
					continue
				end
				local otherPos = getPlayerPosition(otherPlayer)
				if otherPos ~= nil and (otherPos - capturePos).Magnitude <= GROUP_CAPTURE_RADIUS then
					nearbyCount += 1
				end
			end
			if nearbyCount >= 3 then
				QuestManager.Signals.GroupCapture:Fire(player)
			end
		end

		GhostSpawnManager.SetState(instanceId, "Captured")
	else
		GhostSpawnManager.SetState(instanceId, "Escaped")
	end

	local miniEndRemote = Remotes["MiniGameEnd"] :: RemoteEvent
	miniEndRemote:FireClient(player, {
		instanceId = instanceId,
		result = if success then "Success" else "Fail",
		reason = reason,
	})

	PlayerDataManager.Save(player)
	GhostSpawnManager.OnCaptureOrEscape(instanceId)

	-- Notify TutorialManager so it can advance to step 5/6 on success.
	TutorialManager.OnCaptureResult(player, instanceId, success)
end

-- ─── RequestCapture handler ───────────────────────────────────────────────────

local function handleRequestCapture(player: Player, args: { [string]: any }): { [string]: any }
	local userId = player.UserId
	local now = os.clock()

	if now - (captureRateLimit[userId] or 0) < Constants.RATE_LIMIT_CAPTURE then
		return { ok = false, error = "RATE_LIMITED" }
	end
	captureRateLimit[userId] = now

	local instanceId = args.instanceId
	local bottleId = args.bottleId
	if type(instanceId) ~= "string" or type(bottleId) ~= "string" then
		return { ok = false, error = "INVALID_ARGS" }
	end

	-- Decoy check
	if GhostAI.IsDecoy(instanceId) then
		return { ok = false, error = "DECOY" }
	end

	local ghostEntry = GhostSpawnManager.GetActiveInstance(instanceId)
	if ghostEntry == nil then
		return { ok = false, error = "NOT_FOUND" }
	end
	if ghostEntry.state ~= "Triggered" then
		return { ok = false, error = "NOT_TRIGGERED" }
	end
	if activeSessions[instanceId] ~= nil then
		return { ok = false, error = "BUSY" }
	end

	local data = PlayerDataManager.GetData(player)
	if data == nil then
		return { ok = false, error = "NO_DATA" }
	end

	local bottleDef = BottleDefs[bottleId]
	if bottleDef == nil then
		return { ok = false, error = "NO_BOTTLE" }
	end
	local bottleCount = data.bottles[bottleId] or 0
	if not bottleDef.unlimited and bottleCount <= 0 then
		return { ok = false, error = "NO_BOTTLE" }
	end

	-- Proximity check (skipped if ghost has no model yet)
	local entryPos = getEntryPosition(ghostEntry :: any)
	local playerPos = getPlayerPosition(player)
	if entryPos ~= nil and playerPos ~= nil then
		if (playerPos - entryPos).Magnitude > Constants.CAPTURE_PROXIMITY then
			return { ok = false, error = "TOO_FAR" }
		end
	end

	-- All validations passed — open capture session
	local def = ghostEntry.def :: GhostDef
	local miniGame = def.miniGame
	local maxResistance = def.maxResistance

	-- Build mini-game state and config
	local miniGameState: MiniGameState = {
		symbols = nil,
		currentStep = 1,
		targetAngle = nil,
		startResistance = maxResistance,
		surroundParts = nil,
		surroundFilled = nil,
		surroundConnections = nil,
	}

	local config: { [string]: any } = {}

	if miniGame == "MantraTap" then
		local syms, cfg = makeMantraTapConfig(maxResistance)
		miniGameState.symbols = syms
		config = cfg
		if TutorialManager.IsTutorialInstance(instanceId) then
			config.timeLimit = (cfg.timeLimit :: number) * 2
		end
	elseif miniGame == "BottleAim" then
		local origin = entryPos or Vector3.zero
		config = { holdDuration = 2, ghostWorldPos = { X = origin.X, Y = origin.Y, Z = origin.Z } }
	elseif miniGame == "RhythmChant" then
		config = makeRhythmConfig(maxResistance)
	elseif miniGame == "SignalTriangulate" then
		miniGameState.targetAngle = math.random(0, 359)
		config = {} -- client does not receive target angle
	elseif miniGame == "ShadowChase" then
		config = { duration = Constants.CAPTURE_TIMEOUT }
	elseif miniGame == "TeamSurround" then
		local origin = entryPos or Vector3.zero
		local positions, cfg = makeSurroundPositions(origin)
		config = cfg
		-- TeamSurround setup deferred to after session creation (needs session ref)
		miniGameState.surroundParts = nil -- filled in setupTeamSurround
		-- Store positions in config; setupTeamSurround called below
		config._positions = positions
	end

	local session: ActiveSession = {
		instanceId = instanceId,
		ghostId = ghostEntry.ghostId,
		player = player,
		bottleId = bottleId,
		miniGame = miniGame,
		resistance = maxResistance,
		maxResistance = maxResistance,
		resolved = false,
		miniGameState = miniGameState,
	}
	activeSessions[instanceId] = session

	-- TeamSurround: set up position parts now that session exists
	if miniGame == "TeamSurround" then
		local positions = config._positions :: { Vector3 }
		config._positions = nil
		setupTeamSurround(session, positions)
	end

	-- Transition ghost to InCapture and notify AI
	GhostSpawnManager.SetState(instanceId, "InCapture")
	GhostAI.NotifyCaptureStart(instanceId)

	-- Notify TutorialManager that capture has begun (advances to step 4).
	TutorialManager.OnCaptureStarted(player, instanceId)

	-- Fire MiniGameStart to this player with full config.
	-- Field is `miniGameType` (matches MiniGameController payload type).
	local miniStartRemote = Remotes["MiniGameStart"] :: RemoteEvent
	miniStartRemote:FireClient(player, { instanceId = instanceId, miniGameType = miniGame, config = config })

	-- 30s server-side timeout — auto-fails if session is still active
	local captureTimeout = if TutorialManager.IsTutorialInstance(instanceId)
		then Constants.CAPTURE_TIMEOUT * 2
		else Constants.CAPTURE_TIMEOUT
	task.delay(captureTimeout, function()
		if activeSessions[instanceId] ~= nil then
			resolveCapture(instanceId, "Timeout")
		end
	end)

	return { ok = true }
end

-- ─── RequestMiniGameInput handler ─────────────────────────────────────────────

local function handleRequestMiniGameInput(player: Player, args: { [string]: any }): { [string]: any }
	local userId = player.UserId
	local instanceId = args.instanceId
	if type(instanceId) ~= "string" then
		return { ok = false, error = "INVALID_ARGS" }
	end

	local rateLimitKey = tostring(userId) .. "_" .. instanceId
	local now = os.clock()
	if now - (inputRateLimit[rateLimitKey] or 0) < Constants.RATE_LIMIT_MINIGAME_INPUT then
		return { ok = false, error = "RATE_LIMITED" }
	end
	inputRateLimit[rateLimitKey] = now

	local session = activeSessions[instanceId]
	if session == nil then
		return { ok = false, error = "NO_SESSION" }
	end
	if session.player ~= player then
		return { ok = false, error = "NOT_YOUR_SESSION" }
	end

	local inputData = args.inputData
	if type(inputData) ~= "table" then
		return { ok = false, error = "INVALID_INPUT" }
	end

	-- TeamSurround has no client input — server-driven only
	if session.miniGame == "TeamSurround" then
		return { ok = false, error = "NO_INPUT_NEEDED" }
	end

	-- Route to validator (all compute delta server-side)
	local delta = 0
	if session.miniGame == "MantraTap" then
		delta = validateMantraTap(session, inputData)
	elseif session.miniGame == "BottleAim" then
		delta = validateBottleAim(session, inputData)
	elseif session.miniGame == "RhythmChant" then
		delta = validateRhythmChant(inputData)
	elseif session.miniGame == "SignalTriangulate" then
		delta = validateSignalTriangulate(session, inputData)
	elseif session.miniGame == "ShadowChase" then
		delta = validateShadowChase(session, inputData)
	end

	-- ShadowChase body contact may have reset resistance directly;
	-- only reduce if delta > 0
	if delta > 0 then
		session.resistance = math.max(0, session.resistance - delta)
	end

	if session.resistance <= 0 then
		resolveCapture(instanceId, "ResistanceDepleted")
	end

	return { ok = true, resistanceDelta = delta }
end

-- ─── Public API ───────────────────────────────────────────────────────────────

local CaptureSession = {}

function CaptureSession.GetSession(instanceId: string): ActiveSession?
	return activeSessions[instanceId]
end

function CaptureSession.Init()
	local requestCapture = Remotes["RequestCapture"] :: RemoteFunction
	requestCapture.OnServerInvoke = function(player: Player, args: any): any
		return handleRequestCapture(player, args :: { [string]: any })
	end

	local requestInput = Remotes["RequestMiniGameInput"] :: RemoteFunction
	requestInput.OnServerInvoke = function(player: Player, args: any): any
		return handleRequestMiniGameInput(player, args :: { [string]: any })
	end

	-- Clean up rate limit tables when players leave (prevent unbounded growth)
	Players.PlayerRemoving:Connect(function(player: Player)
		captureRateLimit[player.UserId] = nil
		local prefix = tostring(player.UserId) .. "_"
		local toRemove: { string } = {}
		for key in inputRateLimit do
			if key:sub(1, #prefix) == prefix then
				table.insert(toRemove, key)
			end
		end
		for _, k in toRemove do
			inputRateLimit[k] = nil
		end
	end)
end

return CaptureSession
