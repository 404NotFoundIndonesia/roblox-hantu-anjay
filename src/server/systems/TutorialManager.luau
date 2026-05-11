--!strict
-- TutorialManager — T-43
-- Server-side tutorial gate and scripted Pocong spawn.
-- Sequence: step 0 (join) → step 1 (8s) → step 2 (scan) → step 3 (Pocong spawned)
--           → step 4 (capture started) → step 5 (success) → step 6 (complete)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Constants = require(ReplicatedStorage.Shared.Constants)
local PlayerDataManager = require(ServerScriptService.Server.systems.PlayerDataManager)
local GhostSpawnManager = require(ServerScriptService.Server.systems.GhostSpawnManager)

-- ─── Constants ────────────────────────────────────────────────────────────────

-- Tutorial Pocong spawns slightly in front of Hub center, clearly visible.
local TUTORIAL_POCONG_POS = Constants.HUB_SPAWN + Vector3.new(0, 0, -15)
local STEP1_DELAY = 8 -- seconds after step 0 before firing step 1

-- ─── State ────────────────────────────────────────────────────────────────────

local TutorialManager = {}

-- userId → current tutorial step (-1 = not in tutorial)
local playerStep: { [number]: number } = {}

-- userId → tutorial Pocong instanceId
local playerPocong: { [number]: string } = {}

-- instanceId → userId (reverse map for capture hooks)
local tutorialInstances: { [string]: number } = {}

-- ─── Helpers ──────────────────────────────────────────────────────────────────

local function fireTutorialStep(player: Player, step: number, extra: { [string]: any }?)
	local payload: { [string]: any } = { step = step }
	if extra ~= nil then
		for k, v in extra do
			payload[k] = v
		end
	end
	;(Remotes["TutorialStep"] :: RemoteEvent):FireClient(player, payload)
end

local function completeTutorial(player: Player)
	local userId = player.UserId
	playerStep[userId] = -1

	local data = PlayerDataManager.GetData(player)
	if data ~= nil then
		data.tutorialDone = true
		PlayerDataManager.Save(player)
	end

	fireTutorialStep(player, -1) -- signals client to hide all tutorial UI
end

local function spawnTutorialPocong(player: Player)
	local userId = player.UserId
	if playerPocong[userId] ~= nil then
		return -- already spawned
	end

	local instanceId = GhostSpawnManager.SpawnTutorial("Pocong", TUTORIAL_POCONG_POS, player)
	if instanceId == nil then
		return
	end

	playerPocong[userId] = instanceId
	tutorialInstances[instanceId] = userId
end

local function cleanupPlayer(player: Player)
	local userId = player.UserId
	local instanceId = playerPocong[userId]
	if instanceId ~= nil then
		tutorialInstances[instanceId] = nil
		-- Despawn tutorial Pocong if still alive (skip, timeout, or player left)
		if GhostSpawnManager.GetActiveInstance(instanceId) ~= nil then
			GhostSpawnManager.OnCaptureOrEscape(instanceId)
		end
		playerPocong[userId] = nil
	end
	playerStep[userId] = nil
end

-- ─── Public API (called by CaptureSession) ────────────────────────────────────

-- Returns true if instanceId belongs to a tutorial ghost.
function TutorialManager.IsTutorialInstance(instanceId: string): boolean
	return tutorialInstances[instanceId] ~= nil
end

-- Called by CaptureSession when a capture mini-game begins for this instance.
function TutorialManager.OnCaptureStarted(player: Player, instanceId: string)
	if tutorialInstances[instanceId] == nil then
		return
	end
	local userId = player.UserId
	if playerStep[userId] ~= 3 then
		return
	end
	playerStep[userId] = 4
	fireTutorialStep(player, 4)
end

-- Called by CaptureSession after resolveCapture completes for this instance.
function TutorialManager.OnCaptureResult(player: Player, instanceId: string, success: boolean)
	if tutorialInstances[instanceId] == nil then
		return
	end
	tutorialInstances[instanceId] = nil

	local userId = player.UserId
	playerPocong[userId] = nil

	if not success then
		-- Respawn tutorial Pocong so player can try again.
		task.delay(2, function()
			if playerStep[userId] ~= nil and playerStep[userId] >= 3 then
				playerStep[userId] = 3
				spawnTutorialPocong(player)
				fireTutorialStep(player, 3, { instanceId = playerPocong[userId] })
			end
		end)
		return
	end

	playerStep[userId] = 5
	fireTutorialStep(player, 5)

	task.delay(3, function()
		if playerStep[userId] == nil then
			return
		end
		playerStep[userId] = 6
		fireTutorialStep(player, 6)

		task.delay(4, function()
			if playerStep[userId] == nil then
				return
			end
			completeTutorial(player)
		end)
	end)
end

-- ─── Init ─────────────────────────────────────────────────────────────────────

function TutorialManager.Init()
	-- Gate on profile load: fire step 0 for new players.
	PlayerDataManager.OnLoaded(function(player: Player, data)
		if data.tutorialDone then
			return
		end
		local userId = player.UserId
		playerStep[userId] = 0
		fireTutorialStep(player, 0)

		task.delay(STEP1_DELAY, function()
			if playerStep[userId] ~= 0 then
				return
			end
			playerStep[userId] = 1
			fireTutorialStep(player, 1)
		end)
	end)

	-- RequestScan: advance tutorial step 1 → 2 → 3 (spawn Pocong).
	-- Non-tutorial players receive ok=false (RequestScan server logic is T-47).
	;(Remotes["RequestScan"] :: RemoteFunction).OnServerInvoke = function(player: Player): { [string]: any }
		local userId = player.UserId
		local step = playerStep[userId]

		if step == 1 then
			playerStep[userId] = 2
			fireTutorialStep(player, 2)

			-- Spawn tutorial Pocong immediately after scan.
			task.spawn(function()
				spawnTutorialPocong(player)
				playerStep[userId] = 3
				fireTutorialStep(player, 3, { instanceId = playerPocong[userId] })
			end)

			-- Return a fake cold zone near Hub so the client shows a highlight.
			local coldZonePos = TUTORIAL_POCONG_POS
			return { ok = true, coldZones = { coldZonePos } }
		end

		-- Non-tutorial or wrong step: return empty ok (full SCAN logic in T-47).
		return { ok = true, coldZones = {} }
	end

	-- RequestSkipTutorial: set tutorialDone and clean up.
	;(Remotes["RequestSkipTutorial"] :: RemoteFunction).OnServerInvoke = function(player: Player): { [string]: any }
		local userId = player.UserId
		if playerStep[userId] == nil then
			-- Already done or never started.
			return { ok = true }
		end
		cleanupPlayer(player)
		local data = PlayerDataManager.GetData(player)
		if data ~= nil then
			data.tutorialDone = true
			PlayerDataManager.Save(player)
		end
		fireTutorialStep(player, -1)
		return { ok = true }
	end

	-- Clean up state when player leaves.
	Players.PlayerRemoving:Connect(function(player: Player)
		cleanupPlayer(player)
	end)
end

return TutorialManager
