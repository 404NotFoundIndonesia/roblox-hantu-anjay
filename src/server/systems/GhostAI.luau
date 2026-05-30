--!strict
-- GhostAI — Wanderer (T-14), Hunter (T-15), Trickster (T-16), Detection (T-17)
local HttpService = game:GetService("HttpService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)
local ZoneDefs = require(ReplicatedStorage.Shared.ZoneDefs)
local Util = require(ReplicatedStorage.Shared.Util)
local Signal = require(ReplicatedStorage.Packages.Signal)

-- Mirrors GhostDef from GhostDefs.luau; defined inline to avoid a circular require.
type GhostDef = {
	id: string,
	nameKey: string,
	loreKey: string,
	rarity: string,
	behavior: string,
	miniGame: string,
	maxResistance: number,
	speed: number,
	detectionRange: number,
	modelName: string,
	affinityZones: { string },
}

export type GhostAICallbacks = {
	onStateChanged: (newState: string, extra: { [string]: any }?) -> (),
	onEscape: () -> (),
}

type Controller = {
	instanceId: string,
	def: GhostDef,
	model: Model?,
	hauntPos: Vector3,
	state: string,
	triggeringPlayer: Player?,
	captureStarted: boolean,
	active: boolean,
	decoys: { Model },
	callbacks: GhostAICallbacks,
}

-- ─── Module state ─────────────────────────────────────────────────────────────

local controllers: { [string]: Controller } = {}
-- decoyInstanceId (model.Name) → real instanceId
local decoyMap: { [string]: string } = {}
-- userId → { pos, since (os.clock()) }
local idleTracker: { [number]: { pos: Vector3, since: number } } = {}
-- "userId_partFullName" → os.clock() expiry for cold zone cooldown
local coldZoneCooldown: { [string]: number } = {}

-- ─── Internal helpers ─────────────────────────────────────────────────────────

local function getHumanoid(model: Model?): Humanoid?
	if model == nil then return nil end
	return model:FindFirstChildOfClass("Humanoid") :: Humanoid?
end

local function getRootPart(model: Model?): BasePart?
	if model == nil then return nil end
	return model:FindFirstChild("HumanoidRootPart") :: BasePart?
		or model:FindFirstChildOfClass("BasePart") :: BasePart?
end

local function getPlayerPos(player: Player): Vector3?
	local char = player.Character
	if not char then return nil end
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	return hrp and hrp.Position or nil
end

-- True only when player is strictly inside one of the 6 biome detection volumes.
-- Players in the Hub or between islands return false (safe, no triggers).
local function playerInBiomeZone(player: Player): boolean
	local char = player.Character
	if not char then return false end
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return false end
	local pos = hrp.Position
	for _, zoneDef in ZoneDefs do
		if Util.isInsideBounds(pos, zoneDef.detectionVolume) then
			return true
		end
	end
	return false
end

local function setState(ctrl: Controller, newState: string, extra: { [string]: any }?)
	ctrl.state = newState
	ctrl.callbacks.onStateChanged(newState, extra)
end

-- Navigate humanoid to targetPos via PathfindingService.
-- Returns true if reached (or close enough), false if stuck/cancelled.
local function navigateTo(ctrl: Controller, humanoid: Humanoid, targetPos: Vector3): boolean
	if not ctrl.active then return false end
	local root = getRootPart(ctrl.model)
	if root == nil then return false end

	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = false,
		AgentCanClimb = false,
		WaypointSpacing = 4,
	})
	local ok = pcall(function()
		path:ComputeAsync(root.Position, targetPos)
	end)
	if not ok or path.Status ~= Enum.PathStatus.Success then
		-- Direct fallback; ghost may clip but won't crash
		humanoid:MoveTo(targetPos)
		task.wait(1.5)
		return ctrl.active
	end

	for _, wp in path:GetWaypoints() do
		if not ctrl.active then return false end
		humanoid:MoveTo(wp.Position)
		local t = 0
		local STEP = 0.1
		local prevPos = root.Position
		while t < 3 do
			task.wait(STEP)
			if not ctrl.active then return false end
			t += STEP
			if (root.Position - wp.Position).Magnitude < 1.5 then break end
			-- Stuck: barely moved in 2s → give up on this target
			if t >= 2 and (root.Position - prevPos).Magnitude < 0.5 then
				return false
			end
		end
	end
	return ctrl.active
end

-- Wander between random points near hauntPos until state changes from "Patrolling".
local function runPatrol(ctrl: Controller, radius: number)
	local humanoid = getHumanoid(ctrl.model)
	if humanoid then
		humanoid.WalkSpeed = ctrl.def.speed
	end

	while ctrl.active and ctrl.state == "Patrolling" do
		local angle = math.random() * math.pi * 2
		local dist = math.random() * radius
		local target = Vector3.new(
			ctrl.hauntPos.X + math.cos(angle) * dist,
			ctrl.hauntPos.Y,
			ctrl.hauntPos.Z + math.sin(angle) * dist
		)
		if humanoid then
			navigateTo(ctrl, humanoid, target)
		else
			if ctrl.model then
				ctrl.model:PivotTo(CFrame.new(target))
			end
			task.wait(2)
		end
		if ctrl.active and ctrl.state == "Patrolling" then
			task.wait(math.random(1, 3))
		end
	end
end

-- ─── T-14 · Wanderer triggered behavior ──────────────────────────────────────

local function runWandererTriggered(ctrl: Controller)
	if not ctrl.active then return end

	-- Stop and face the triggering player
	local humanoid = getHumanoid(ctrl.model)
	if humanoid then
		humanoid.WalkSpeed = 0
		local root = getRootPart(ctrl.model)
		if root then
			humanoid:MoveTo(root.Position)
		end
	end
	if ctrl.triggeringPlayer and ctrl.model then
		local playerPos = getPlayerPos(ctrl.triggeringPlayer)
		if playerPos then
			local root = getRootPart(ctrl.model)
			if root then
				local look = (playerPos - root.Position) * Vector3.new(1, 0, 1)
				if look.Magnitude > 0.1 then
					ctrl.model:PivotTo(CFrame.lookAt(root.Position, root.Position + look))
				end
			end
		end
	end

	-- Wait GHOST_WANDER_FACE_TIME; escape if no capture begins
	local timer = 0
	while timer < Constants.GHOST_WANDER_FACE_TIME do
		if not ctrl.active then return end
		if ctrl.captureStarted then
			-- Hold here until capture session finishes
			while ctrl.captureStarted and ctrl.active do
				task.wait(0.25)
			end
			return -- CaptureSession will call Stop() on success or set Escaped on fail
		end
		task.wait(0.1)
		timer += 0.1
	end

	if ctrl.active and not ctrl.captureStarted then
		setState(ctrl, "Escaped")
		ctrl.callbacks.onEscape()
	end
end

-- ─── T-15 · Hunter chase behavior ────────────────────────────────────────────

local function runHunterChase(ctrl: Controller)
	if not ctrl.active then return end

	local humanoid = getHumanoid(ctrl.model)
	if humanoid then
		humanoid.WalkSpeed = ctrl.def.speed
	end

	local escapeTimer = 0

	while ctrl.active and ctrl.state == "Triggered" do
		if ctrl.captureStarted then
			if humanoid then
				humanoid.WalkSpeed = 0
			end
			while ctrl.captureStarted and ctrl.active do
				task.wait(0.5)
			end
			if not ctrl.active then return end
			if humanoid then
				humanoid.WalkSpeed = ctrl.def.speed
			end
		end

		-- Refresh path every 1s toward locked player
		if ctrl.triggeringPlayer and ctrl.model then
			local targetPos = getPlayerPos(ctrl.triggeringPlayer)
			local root = getRootPart(ctrl.model)
			if targetPos and humanoid and root then
				local path = PathfindingService:CreatePath({
					AgentRadius = 2,
					AgentHeight = 5,
					AgentCanJump = false,
					AgentCanClimb = false,
					WaypointSpacing = 4,
				})
				pcall(function()
					path:ComputeAsync(root.Position, targetPos :: Vector3)
				end)
				if path.Status == Enum.PathStatus.Success then
					local wps = path:GetWaypoints()
					-- Move toward second waypoint (first is current position)
					if #wps >= 2 then
						humanoid:MoveTo(wps[2].Position)
					end
				else
					humanoid:MoveTo(targetPos)
				end
			end
		end

		task.wait(1) -- path refresh interval
		escapeTimer += 1

		if escapeTimer >= Constants.GHOST_ESCAPE_TIME then
			break
		end
	end

	if ctrl.active and ctrl.state == "Triggered" and not ctrl.captureStarted then
		setState(ctrl, "Escaped")
		ctrl.callbacks.onEscape()
	end
end

-- ─── T-16 · Trickster triggered behavior ─────────────────────────────────────

local function spawnDecoys(ctrl: Controller)
	if ctrl.model == nil then return end
	local root = getRootPart(ctrl.model)
	local origin = root and root.Position or ctrl.hauntPos
	local ghostsFolder = Workspace:FindFirstChild("Ghosts") :: Folder?

	local count = math.random(1, 2)
	for _ = 1, count do
		local decoy = ctrl.model:Clone() :: Model
		-- Strip collision and particle effects — decoys must be visually identical
		-- but have no hitbox and no particle emitter
		for _, desc in decoy:GetDescendants() do
			if desc:IsA("BasePart") then
				(desc :: BasePart).CanCollide = false
				(desc :: BasePart).CanTouch = false
			end
			if desc:IsA("ParticleEmitter") then
				desc:Destroy()
			end
		end
		-- Position near the real ghost
		local angle = math.random() * math.pi * 2
		local dist = math.random(5, 15)
		local decoyPos = Vector3.new(
			origin.X + math.cos(angle) * dist,
			origin.Y,
			origin.Z + math.sin(angle) * dist
		)
		decoy:PivotTo(CFrame.new(decoyPos))

		local decoyId = HttpService:GenerateGUID(false)
		decoy.Name = decoyId
		decoy.Parent = ghostsFolder or Workspace
		decoyMap[decoyId] = ctrl.instanceId
		table.insert(ctrl.decoys, decoy)
	end
end

local function addGhostParticle(ctrl: Controller)
	local root = getRootPart(ctrl.model)
	if root == nil then return end
	local pe = Instance.new("ParticleEmitter")
	pe.Brightness = 0.3
	pe.LightEmission = 0.15
	pe.Rate = 5
	pe.Size = NumberSequence.new(0.25)
	pe.Color = ColorSequence.new(Color3.fromRGB(100, 200, 255))
	pe.Lifetime = NumberRange.new(0.5, 1)
	pe.Parent = root
end

local function cleanDecoys(ctrl: Controller)
	for _, decoy in ctrl.decoys do
		decoyMap[decoy.Name] = nil
		if decoy.Parent ~= nil then
			decoy:Destroy()
		end
	end
	table.clear(ctrl.decoys)
end

local function runTricksterTriggered(ctrl: Controller)
	if not ctrl.active then return end

	spawnDecoys(ctrl)
	addGhostParticle(ctrl)

	local teleportTimer = 0

	while ctrl.active and ctrl.state == "Triggered" do
		if ctrl.captureStarted then
			while ctrl.captureStarted and ctrl.active do
				task.wait(0.5)
			end
			if not ctrl.active then
				cleanDecoys(ctrl)
				return
			end
		end

		task.wait(0.1)
		teleportTimer += 0.1

		if teleportTimer >= Constants.GHOST_TRICKSTER_TELEPORT_INTERVAL then
			teleportTimer = 0
			if ctrl.model then
				local root = getRootPart(ctrl.model)
				local origin = root and root.Position or ctrl.hauntPos
				local angle = math.random() * math.pi * 2
				local dist = math.random(5, 30)
				local newPos = Vector3.new(
					origin.X + math.cos(angle) * dist,
					origin.Y,
					origin.Z + math.sin(angle) * dist
				)
				ctrl.model:PivotTo(CFrame.new(newPos))
			end
		end
	end

	cleanDecoys(ctrl)
end

-- ─── T-17 · Detection triggers ────────────────────────────────────────────────

local function triggerGhost(instanceId: string, player: Player)
	local ctrl = controllers[instanceId]
	if ctrl == nil or ctrl.state ~= "Patrolling" then return end
	ctrl.triggeringPlayer = player
	setState(ctrl, "Triggered", { triggeringPlayer = player.UserId })
end

local function setupColdZoneConnection(part: BasePart)
	part.Touched:Connect(function(hit: BasePart)
		local char = hit.Parent :: Model?
		if char == nil then return end
		local player = Players:GetPlayerFromCharacter(char)
		if player == nil then return end
		if not playerInBiomeZone(player) then return end

		local key = tostring(player.UserId) .. "_" .. part:GetFullName()
		if coldZoneCooldown[key] and os.clock() < coldZoneCooldown[key] then return end
		coldZoneCooldown[key] = os.clock() + 30

		-- Trigger nearest Patrolling ghost to this cold zone part
		local nearest: string? = nil
		local nearestDist = math.huge
		for id, ctrl in controllers do
			if ctrl.state ~= "Patrolling" then continue end
			local d = (ctrl.hauntPos - part.Position).Magnitude
			if d < nearestDist then
				nearestDist = d
				nearest = id
			end
		end
		if nearest then
			triggerGhost(nearest, player)
		end
	end)
end

local function startDetectionTick()
	task.spawn(function()
		while true do
			task.wait(Constants.GHOST_AI_TICK)
			local now = os.clock()

			for _, player in Players:GetPlayers() do
				if not playerInBiomeZone(player) then
					idleTracker[player.UserId] = nil
					continue
				end

				local playerPos = getPlayerPos(player)
				if playerPos == nil then continue end

				-- Proximity trigger
				for id, ctrl in controllers do
					if ctrl.state ~= "Patrolling" then continue end
					local dist = (ctrl.hauntPos - playerPos).Magnitude
					if dist <= ctrl.def.detectionRange then
						triggerGhost(id, player)
					end
				end

				-- Idle trigger
				local idle = idleTracker[player.UserId]
				if idle == nil then
					idleTracker[player.UserId] = { pos = playerPos, since = now }
				else
					if (playerPos - idle.pos).Magnitude > 1 then
						-- Moved — reset timer
						idleTracker[player.UserId] = { pos = playerPos, since = now }
					elseif now - idle.since >= Constants.GHOST_IDLE_TRIGGER_TIME then
						-- Standing still ≥8s — find nearest ghost within 40 studs
						local nearest: string? = nil
						local nearestDist = math.huge
						for id, ctrl in controllers do
							if ctrl.state ~= "Patrolling" then continue end
							local d = (ctrl.hauntPos - playerPos).Magnitude
							if d <= 40 and d < nearestDist then
								nearestDist = d
								nearest = id
							end
						end
						if nearest then
							triggerGhost(nearest, player)
							idleTracker[player.UserId] = { pos = playerPos, since = now }
						end
					end
				end
			end

			-- Clean up idle entries for players who left
			local toRemove: { number } = {}
			for userId in idleTracker do
				if Players:GetPlayerByUserId(userId) == nil then
					table.insert(toRemove, userId)
				end
			end
			for _, uid in toRemove do
				idleTracker[uid] = nil
			end

			-- Clean up expired cold zone cooldowns to avoid unbounded growth
			local expiredKeys: { string } = {}
			for k, expiry in coldZoneCooldown do
				if now > expiry then
					table.insert(expiredKeys, k)
				end
			end
			for _, k in expiredKeys do
				coldZoneCooldown[k] = nil
			end
		end
	end)
end

-- ─── Public API ───────────────────────────────────────────────────────────────

local GhostAI = {}

-- Fired by ShardManager when a player collects a SpiritShard.
-- GhostAI listens to this to trigger nearby ghosts.
GhostAI.ShardCollected = Signal.new() :: any

-- Triggers the nearest Patrolling ghost to `pos` on behalf of `player`.
-- Called by LanternManager when lantern drains to 0.
function GhostAI.TriggerNearbyGhost(player: Player, pos: Vector3)
	if not playerInBiomeZone(player) then return end
	local nearest: string? = nil
	local nearestDist = math.huge
	for id, ctrl in controllers do
		if ctrl.state ~= "Patrolling" then continue end
		local d = (ctrl.hauntPos - pos).Magnitude
		if d < nearestDist then
			nearestDist = d
			nearest = id
		end
	end
	if nearest ~= nil then
		triggerGhost(nearest, player)
	end
end

-- Returns haunt positions of all ghost controllers within `radius` studs of `playerPos`.
-- Used by TutorialManager to implement the SCAN pulse for non-tutorial players.
function GhostAI.GetNearbyGhostPositions(playerPos: Vector3, radius: number): { Vector3 }
	local result: { Vector3 } = {}
	for _, ctrl in controllers do
		if (ctrl.hauntPos - playerPos).Magnitude <= radius then
			table.insert(result, ctrl.hauntPos)
		end
	end
	return result
end

function GhostAI.Start(
	instanceId: string,
	def: GhostDef,
	model: Model?,
	hauntPos: Vector3,
	callbacks: GhostAICallbacks,
	startTriggered: boolean?
)
	local ctrl: Controller = {
		instanceId = instanceId,
		def = def,
		model = model,
		hauntPos = hauntPos,
		state = "Patrolling",
		triggeringPlayer = nil,
		captureStarted = false,
		active = true,
		decoys = {},
		callbacks = callbacks,
	}
	controllers[instanceId] = ctrl

	-- For the mythic server-wide event, the ghost spawns pre-triggered
	if startTriggered then
		ctrl.state = "Triggered"
	end

	task.spawn(function()
		if def.behavior == "Wanderer" then
			runPatrol(ctrl, 20)
			runWandererTriggered(ctrl)
		elseif def.behavior == "Hunter" then
			runPatrol(ctrl, 15)
			runHunterChase(ctrl)
		elseif def.behavior == "Trickster" then
			runPatrol(ctrl, 15)
			runTricksterTriggered(ctrl)
		end
	end)
end

-- Stop and clean up the AI for a despawned ghost. Called by GhostSpawnManager.
function GhostAI.Stop(instanceId: string)
	local ctrl = controllers[instanceId]
	if ctrl == nil then return end
	ctrl.active = false
	cleanDecoys(ctrl)
	controllers[instanceId] = nil
end

-- External trigger (e.g. CaptureSession or server events).
function GhostAI.Trigger(instanceId: string, player: Player)
	triggerGhost(instanceId, player)
end

-- CaptureSession calls this when a capture mini-game begins.
-- Suspends the auto-escape countdown for all archetypes.
function GhostAI.NotifyCaptureStart(instanceId: string)
	local ctrl = controllers[instanceId]
	if ctrl then
		ctrl.captureStarted = true
	end
end

-- CaptureSession calls this when the mini-game ends (success OR fail).
function GhostAI.NotifyCaptureEnd(instanceId: string)
	local ctrl = controllers[instanceId]
	if ctrl then
		ctrl.captureStarted = false
	end
end

-- Returns true if instanceId belongs to a Trickster decoy.
-- CaptureSession uses this to return { ok=false, error="DECOY" }.
function GhostAI.IsDecoy(instanceId: string): boolean
	return decoyMap[instanceId] ~= nil
end

-- Returns the real ghost instanceId that owns a decoy, or nil.
function GhostAI.GetRealForDecoy(instanceId: string): string?
	return decoyMap[instanceId]
end

-- Wire detection triggers. Must be called from init.server.luau
-- AFTER WorldBuilder.Build() so Workspace/World/ exists.
function GhostAI.InitDetection()
	-- Connect cold zone .Touched events on all ColdZone Parts in the world
	local worldFolder = Workspace:FindFirstChild("World") :: Folder?
	if worldFolder then
		for _, island in worldFolder:GetChildren() do
			for _, desc in island:GetDescendants() do
				if desc:IsA("BasePart") and desc.Name == "ColdZone" then
					setupColdZoneConnection(desc :: BasePart)
				end
			end
		end
	end

	-- Shard pickup trigger: ShardSystem fires this with (player, shardWorldPos)
	GhostAI.ShardCollected:Connect(function(player: Player, shardPos: Vector3)
		if not playerInBiomeZone(player) then return end
		local nearest: string? = nil
		local nearestDist = math.huge
		for id, ctrl in controllers do
			if ctrl.state ~= "Patrolling" then continue end
			local d = (ctrl.hauntPos - shardPos).Magnitude
			if d < nearestDist then
				nearestDist = d
				nearest = id
			end
		end
		if nearest then
			triggerGhost(nearest, player)
		end
	end)

	startDetectionTick()
end

return GhostAI
