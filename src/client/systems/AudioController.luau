--!strict
-- AudioController — T-41 + T-42
-- Layers: Ambient (zone crossfade), Tension (ghost proximity drone),
-- Ghost SFX (spatial on Triggered), UI SFX (one-shot lookup).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ZoneDefs = require(ReplicatedStorage.Shared.ZoneDefs)
local GhostDefs = require(ReplicatedStorage.Shared.GhostDefs)
local ZoneDetector = require(script.Parent.ZoneDetector)

local LocalPlayer = Players.LocalPlayer

-- ─── Module ───────────────────────────────────────────────────────────────────

local AudioController = {}

-- ─── Constants ────────────────────────────────────────────────────────────────

-- Exact tension formula from PRD §17.2:
--   t = 1 - clamp((nearest - 10) / 40, 0, 1)
--   Volume = t * 0.6
-- Full tension at 10 studs, silent beyond 50 studs.
local TENSION_NEAR_DIST = 10
local TENSION_RANGE = 40
local TENSION_MAX_VOL = 0.6
local TENSION_TICK = 0.5 -- seconds between tension recalculations

local AMBIENT_FADE = TweenInfo.new(1, Enum.EasingStyle.Linear)
local AMBIENT_MAX_VOL = 0.4

-- Placeholder IDs — replace with real Roblox asset IDs before ship.
local TENSION_SOUND_ID: number = 0

-- ─── UI SFX lookup (PRD §17.4) ────────────────────────────────────────────────

local UI_SOUND_IDS: { [string]: number } = {
	capture_success = 0, -- Gamelan note
	capture_fail    = 0, -- Glass shatter
	level_up        = 0, -- Gamelan fanfare
	minigame_hit    = 0, -- Percussion tap
	quest_complete  = 0, -- Short chime
}

-- ─── State ────────────────────────────────────────────────────────────────────

-- Ambient
local ambientContainer: Folder
local ambientSounds: { [string]: Sound } = {} -- zoneId → looped Sound
local currentZoneId: string? = nil

-- Tension
local tensionSound: Sound
local tensionAccum = 0.0

-- Ghost SFX
local ghostSounds: { [string]: Sound } = {}       -- instanceId → spatial Sound
local instanceGhostId: { [string]: string } = {}  -- instanceId → ghostId

-- ─── Ambient helpers ──────────────────────────────────────────────────────────

local function getOrCreateAmbient(zoneId: string): Sound?
	local existing = ambientSounds[zoneId]
	if existing ~= nil then
		return existing
	end
	local def = ZoneDefs[zoneId]
	if def == nil then
		return nil
	end
	local s = Instance.new("Sound") :: Sound
	s.Name = "Ambient_" .. zoneId
	s.SoundId = if def.ambientSoundId > 0
		then "rbxassetid://" .. tostring(def.ambientSoundId)
		else ""
	s.Looped = true
	s.Volume = 0
	s.Parent = ambientContainer
	ambientSounds[zoneId] = s
	return s
end

local function crossfadeAmbient(newZoneId: string?)
	-- Fade out previous zone.
	if currentZoneId ~= nil then
		local prev = ambientSounds[currentZoneId]
		if prev ~= nil then
			local p = prev
			TweenService:Create(p, AMBIENT_FADE, { Volume = 0 }):Play()
			task.delay(1, function()
				p:Stop()
			end)
		end
	end

	currentZoneId = newZoneId

	-- Fade in new zone (nil = Hub → silence).
	if newZoneId ~= nil then
		local next = getOrCreateAmbient(newZoneId)
		if next ~= nil then
			next.Volume = 0
			next:Play()
			TweenService:Create(next, AMBIENT_FADE, { Volume = AMBIENT_MAX_VOL }):Play()
		end
	end
end

-- ─── Tension helpers ──────────────────────────────────────────────────────────

local function recalcTension()
	local char = LocalPlayer.Character
	if char == nil then
		tensionSound.Volume = 0
		return
	end
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp == nil then
		tensionSound.Volume = 0
		return
	end
	local rootPos = hrp.Position

	local ghostsFolder = workspace:FindFirstChild("Ghosts") :: Folder?
	if ghostsFolder == nil then
		tensionSound.Volume = 0
		return
	end

	-- PRD §17.2: find nearest ghost model in Workspace/Ghosts/
	local nearest = math.huge
	for _, child in ghostsFolder:GetChildren() do
		local model = child :: Model
		local pp = model.PrimaryPart
		if pp == nil then
			continue
		end
		local dist = (rootPos - pp.Position).Magnitude
		if dist < nearest then
			nearest = dist
		end
	end

	local t = 1 - math.clamp((nearest - TENSION_NEAR_DIST) / TENSION_RANGE, 0, 1)
	tensionSound.Volume = t * TENSION_MAX_VOL
end

-- ─── Ghost SFX helpers ────────────────────────────────────────────────────────

local function playGhostSFX(instanceId: string)
	if ghostSounds[instanceId] ~= nil then
		return -- already playing
	end
	local ghostId = instanceGhostId[instanceId]
	if ghostId == nil then
		return
	end
	local def = GhostDefs[ghostId]
	if def == nil or def.soundId == 0 then
		return -- no sound configured
	end

	local ghostsFolder = workspace:FindFirstChild("Ghosts") :: Folder?
	if ghostsFolder == nil then
		return
	end
	local model = ghostsFolder:FindFirstChild(instanceId) :: Model?
	if model == nil then
		return
	end
	local root = model.PrimaryPart
	if root == nil then
		return
	end

	local s = Instance.new("Sound") :: Sound
	s.Name = "GhostSFX"
	s.SoundId = "rbxassetid://" .. tostring(def.soundId)
	s.Looped = true
	s.RollOffMaxDistance = 60
	s.RollOffMinDistance = 8
	s.Volume = 0.8
	s.Parent = root
	s:Play()
	ghostSounds[instanceId] = s
end

local function stopGhostSFX(instanceId: string)
	local s = ghostSounds[instanceId]
	if s ~= nil then
		s:Stop()
		if s.Parent ~= nil then
			s:Destroy()
		end
		ghostSounds[instanceId] = nil
	end
	instanceGhostId[instanceId] = nil
end

-- ─── Public ───────────────────────────────────────────────────────────────────

-- playUI plays a one-shot UI sound by key. Silent fail on unknown keys.
function AudioController.playUI(key: string)
	local soundId = UI_SOUND_IDS[key]
	if soundId == nil then
		warn("[AudioController] Unknown UI sound key:", key)
		return
	end
	if soundId == 0 then
		return -- placeholder, not yet assigned
	end
	local s = Instance.new("Sound") :: Sound
	s.SoundId = "rbxassetid://" .. tostring(soundId)
	s.Volume = 0.8
	s.Parent = SoundService
	s:Play()
	local ref = s
	task.delay(5, function()
		if ref.Parent ~= nil then
			ref:Destroy()
		end
	end)
end

-- ─── Init ─────────────────────────────────────────────────────────────────────

function AudioController.Init()
	-- Folder to hold per-zone ambient Sounds.
	ambientContainer = Instance.new("Folder") :: Folder
	ambientContainer.Name = "AmbientSounds"
	ambientContainer.Parent = SoundService

	-- Tension drone (always running, volume driven by proximity).
	tensionSound = Instance.new("Sound") :: Sound
	tensionSound.Name = "TensionDrone"
	tensionSound.SoundId = if TENSION_SOUND_ID > 0
		then "rbxassetid://" .. tostring(TENSION_SOUND_ID)
		else ""
	tensionSound.Looped = true
	tensionSound.Volume = 0
	tensionSound.Parent = SoundService
	if TENSION_SOUND_ID > 0 then
		tensionSound:Play()
	end

	-- Zone changes → crossfade ambient.
	ZoneDetector.ZoneChanged:Connect(function(newZone: string?)
		crossfadeAmbient(newZone)
	end)

	-- Throttled tension update.
	RunService.Heartbeat:Connect(function(dt: number)
		tensionAccum += dt
		if tensionAccum >= TENSION_TICK then
			tensionAccum -= TENSION_TICK
			recalcTension()
		end
	end)

	-- Track instanceId → ghostId from GhostSpawned.
	;(Remotes["GhostSpawned"] :: RemoteEvent).OnClientEvent:Connect(function(
		payload: { instanceId: string, ghostId: string, [string]: any }
	)
		instanceGhostId[payload.instanceId] = payload.ghostId
	end)

	-- Play ghost signature sound on Triggered.
	;(Remotes["GhostStateChanged"] :: RemoteEvent).OnClientEvent:Connect(function(
		payload: { instanceId: string, state: string, [string]: any }
	)
		if payload.state == "Triggered" then
			playGhostSFX(payload.instanceId)
		end
	end)

	-- Clean up ghost sound on despawn.
	;(Remotes["GhostDespawned"] :: RemoteEvent).OnClientEvent:Connect(function(
		payload: { instanceId: string, [string]: any }
	)
		stopGhostSFX(payload.instanceId)
	end)
end

return AudioController
