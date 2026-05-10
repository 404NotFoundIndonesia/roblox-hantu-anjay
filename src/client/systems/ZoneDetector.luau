--!strict
-- ZoneDetector — T-28
-- Detects which biome zone the local player is in, throttled to 0.25s intervals.
-- Fires ZoneChanged signal and notifies the server (for quest tracking) on zone entry.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)
local Util = require(ReplicatedStorage.Shared.Util)
local ZoneDefs = require(ReplicatedStorage.Shared.ZoneDefs)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local LocalPlayer = Players.LocalPlayer

local ZoneDetector = {}

-- Fires on zone change: Signal<newZone: string?, prevZone: string?>
-- newZone is nil when the player is in the Hub or between islands.
ZoneDetector.ZoneChanged = Signal.new() :: any

local currentZone: string? = nil

-- Returns the zoneId whose AABB contains `pos`, or nil if none match.
local function detectZone(pos: Vector3): string?
	for zoneId, def in ZoneDefs do
		if Util.isInsideBounds(pos, def.detectionVolume) then
			return zoneId
		end
	end
	return nil
end

-- Returns the zone the player is currently in (nil = Hub or between islands).
function ZoneDetector.GetCurrentZone(): string?
	return currentZone
end

function ZoneDetector.Init()
	local zoneChangedRemote = Remotes["ZoneChangedToServer"] :: RemoteEvent
	local lastTick = 0
	local TICK_RATE = 0.25

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastTick < TICK_RATE then
			return
		end
		lastTick = now

		local char = LocalPlayer.Character
		if char == nil then
			return
		end
		local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp == nil then
			return
		end

		local newZone = detectZone(hrp.Position)
		if newZone == currentZone then
			return -- no change; no signal, no server notify
		end

		local prevZone = currentZone
		currentZone = newZone

		ZoneDetector.ZoneChanged:Fire(newZone, prevZone)

		-- Only notify server when entering a zone (not on null transitions).
		if newZone ~= nil then
			zoneChangedRemote:FireServer(newZone)
		end
	end)
end

return ZoneDetector
