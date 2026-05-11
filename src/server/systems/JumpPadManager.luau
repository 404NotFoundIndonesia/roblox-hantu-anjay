--!strict
-- JumpPadManager — T-53
-- Scans Workspace.World for BaseParts named "JumpPad" after WorldBuilder completes,
-- then wires Touched events to apply an upward impulse to any player who steps on one.
--
-- JumpPad Part setup in Studio (inside a biome model):
--   Name:       JumpPad  (exact)
--   Anchored:   true
--   CanCollide: true  (player must stand on it)
--   Attribute "LaunchVector" (Vector3, optional):
--     If present, this exact velocity vector is applied (allows diagonal launches
--     toward a specific island). If absent, defaults to Vector3.new(0, JUMP_PAD_FORCE, 0).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)
local WorldBuilder = require(ServerScriptService.Server.systems.WorldBuilder)

-- Per-player cooldown: userId → next-allowed-use os.clock()
local padCooldown: { [number]: number } = {}

local JumpPadManager = {}

local function applyLaunch(player: Player, launchVec: Vector3)
	local char = player.Character
	if char == nil then return end
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp == nil then return end
	-- SetLinearVelocity is not available; use AssemblyLinearVelocity directly.
	hrp.AssemblyLinearVelocity = launchVec
end

local function connectPad(part: BasePart)
	local launchAttr = part:GetAttribute("LaunchVector")
	local launchVec: Vector3 = if typeof(launchAttr) == "Vector3"
		then launchAttr :: Vector3
		else Vector3.new(0, Constants.JUMP_PAD_FORCE, 0)

	part.Touched:Connect(function(hit: BasePart)
		local char = hit.Parent :: Model?
		if char == nil then return end
		local player = Players:GetPlayerFromCharacter(char)
		if player == nil then return end

		local now = os.clock()
		local userId = player.UserId
		if now < (padCooldown[userId] or 0) then return end
		padCooldown[userId] = now + Constants.JUMP_PAD_COOLDOWN

		applyLaunch(player, launchVec)
	end)
end

local function scanForPads()
	local worldFolder = Workspace:FindFirstChild("World") :: Folder?
	if worldFolder == nil then
		warn("[JumpPadManager] Workspace.World not found — no JumpPads wired")
		return
	end

	local count = 0
	for _, desc in worldFolder:GetDescendants() do
		if desc:IsA("BasePart") and desc.Name == "JumpPad" then
			connectPad(desc :: BasePart)
			count += 1
		end
	end

	if count > 0 then
		print(string.format("[JumpPadManager] Wired %d JumpPad(s)", count))
	else
		print("[JumpPadManager] No JumpPad Parts found — add Parts named 'JumpPad' to biome models")
	end
end

function JumpPadManager.Init()
	WorldBuilder.Ready:Connect(scanForPads)

	Players.PlayerRemoving:Connect(function(player: Player)
		padCooldown[player.UserId] = nil
	end)
end

return JumpPadManager
