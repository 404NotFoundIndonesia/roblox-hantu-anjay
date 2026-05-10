--!strict
-- ShadowChase — T-39
-- 2D top-down arena: chase / avoid ghost shadow.
-- Config: { duration: number, container: Frame, instanceId: string }
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

-- ─── State ────────────────────────────────────────────────────────────────────

local ShadowChase = {}

local activeConnections: { RBXScriptConnection } = {}
local activeInstances: { Instance } = {}
local running = false
local onInputFn: (({ [string]: any }) -> any)? = nil

-- Arena logical size (units match pixel coords 1:1)
local ARENA_SIZE = 200
local AVATAR_R = 12.0 -- player avatar radius in arena units
local SHADOW_R = 14.0 -- ghost shadow radius
local BODY_R = 16.0 -- ghost body radius
local MOVE_SPEED = 90.0 -- arena units per second

-- Avatar & ghost positions (arena-local, origin = top-left = 0,0)
local avatarPos = Vector2.new(ARENA_SIZE / 2, ARENA_SIZE / 2)
local shadowPos = Vector2.new(ARENA_SIZE / 4, ARENA_SIZE / 4)
local bodyPos = Vector2.new(3 * ARENA_SIZE / 4, 3 * ARENA_SIZE / 4)

-- Touch drag state
local touchDragging = false
local touchStartPos = Vector2.zero
local avatarAtTouchStart = Vector2.zero

-- Contact tick
local contactAccum = 0.0
local CONTACT_TICK = 0.5

-- UI refs
local arenaFrame: Frame
local avatarCircle: Frame
local shadowCircle: Frame
local bodyCircle: Frame
local timerLabel: TextLabel

-- ─── Colors ───────────────────────────────────────────────────────────────────

local C_BG = Color3.fromRGB(15, 15, 28)
local C_ARENA = Color3.fromRGB(22, 22, 38)
local C_AVATAR = Color3.fromRGB(240, 240, 240)
local C_SHADOW = Color3.fromRGB(140, 140, 160)
local C_BODY = Color3.fromRGB(200, 60, 60)
local C_BODY_HIT = Color3.fromRGB(255, 100, 100)
local C_TEXT = Color3.fromRGB(230, 230, 230)
local C_DIM = Color3.fromRGB(110, 110, 140)

-- ─── Helpers ──────────────────────────────────────────────────────────────────

local function addCorner(parent: Instance, r: number)
	local c = Instance.new("UICorner") :: UICorner
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function track(inst: Instance)
	table.insert(activeInstances, inst)
end

local function clampArena(pos: Vector2, r: number): Vector2
	return Vector2.new(
		math.clamp(pos.X, r, ARENA_SIZE - r),
		math.clamp(pos.Y, r, ARENA_SIZE - r)
	)
end

local function circlesOverlap(a: Vector2, ra: number, b: Vector2, rb: number): boolean
	return (a - b).Magnitude < (ra + rb)
end

local function posToOffset(pos: Vector2, r: number): UDim2
	return UDim2.fromOffset(pos.X - r, pos.Y - r)
end

local function updateCirclePositions()
	if arenaFrame == nil then
		return
	end
	avatarCircle.Position = posToOffset(avatarPos, AVATAR_R)
	shadowCircle.Position = posToOffset(shadowPos, SHADOW_R)
	bodyCircle.Position = posToOffset(bodyPos, BODY_R)
end

-- ─── Build UI ─────────────────────────────────────────────────────────────────

local function buildUI(container: Frame, duration: number)
	local root = Instance.new("Frame") :: Frame
	root.Name = "ShadowChaseRoot"
	root.Size = UDim2.fromOffset(260, 310)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.BackgroundColor3 = C_BG
	root.BackgroundTransparency = 0.08
	root.Parent = container
	addCorner(root, 12)
	track(root)

	local title = Instance.new("TextLabel") :: TextLabel
	title.Name = "Title"
	title.Size = UDim2.fromOffset(260, 34)
	title.Position = UDim2.fromOffset(0, 0)
	title.BackgroundTransparency = 1
	title.TextColor3 = C_TEXT
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.Text = "Kejar Bayangan"
	title.Parent = root

	arenaFrame = Instance.new("Frame") :: Frame
	arenaFrame.Name = "Arena"
	arenaFrame.Size = UDim2.fromOffset(ARENA_SIZE, ARENA_SIZE)
	arenaFrame.Position = UDim2.fromOffset(30, 40)
	arenaFrame.BackgroundColor3 = C_ARENA
	arenaFrame.ClipsDescendants = true
	arenaFrame.Parent = root
	addCorner(arenaFrame, 6)

	-- Ghost body circle (drawn first = lower Z)
	bodyCircle = Instance.new("Frame") :: Frame
	bodyCircle.Name = "Body"
	bodyCircle.Size = UDim2.fromOffset(BODY_R * 2, BODY_R * 2)
	bodyCircle.BackgroundColor3 = C_BODY
	bodyCircle.ZIndex = 2
	bodyCircle.Parent = arenaFrame
	addCorner(bodyCircle, BODY_R)

	-- Ghost shadow circle
	shadowCircle = Instance.new("Frame") :: Frame
	shadowCircle.Name = "Shadow"
	shadowCircle.Size = UDim2.fromOffset(SHADOW_R * 2, SHADOW_R * 2)
	shadowCircle.BackgroundColor3 = C_SHADOW
	shadowCircle.ZIndex = 3
	shadowCircle.Parent = arenaFrame
	addCorner(shadowCircle, SHADOW_R)

	-- Player avatar circle (drawn on top)
	avatarCircle = Instance.new("Frame") :: Frame
	avatarCircle.Name = "Avatar"
	avatarCircle.Size = UDim2.fromOffset(AVATAR_R * 2, AVATAR_R * 2)
	avatarCircle.BackgroundColor3 = C_AVATAR
	avatarCircle.ZIndex = 4
	avatarCircle.Parent = arenaFrame
	addCorner(avatarCircle, AVATAR_R)

	updateCirclePositions()

	-- Legend row
	local legendFrame = Instance.new("Frame") :: Frame
	legendFrame.Name = "Legend"
	legendFrame.Size = UDim2.fromOffset(220, 24)
	legendFrame.Position = UDim2.fromOffset(20, 248)
	legendFrame.BackgroundTransparency = 1
	legendFrame.Parent = root

	local legendLayout = Instance.new("UIListLayout") :: UIListLayout
	legendLayout.FillDirection = Enum.FillDirection.Horizontal
	legendLayout.Padding = UDim.new(0, 8)
	legendLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	legendLayout.Parent = legendFrame

	local function makeDot(color: Color3, label: string): Frame
		local wrapper = Instance.new("Frame") :: Frame
		wrapper.Name = "LegendItem"
		wrapper.Size = UDim2.fromOffset(60, 20)
		wrapper.BackgroundTransparency = 1
		wrapper.Parent = legendFrame

		local dot = Instance.new("Frame") :: Frame
		dot.Size = UDim2.fromOffset(10, 10)
		dot.Position = UDim2.fromOffset(0, 5)
		dot.BackgroundColor3 = color
		dot.Parent = wrapper
		addCorner(dot, 5)

		local lbl = Instance.new("TextLabel") :: TextLabel
		lbl.Size = UDim2.fromOffset(46, 20)
		lbl.Position = UDim2.fromOffset(14, 0)
		lbl.BackgroundTransparency = 1
		lbl.TextColor3 = C_DIM
		lbl.Font = Enum.Font.Gotham
		lbl.TextScaled = true
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Text = label
		lbl.Parent = wrapper

		_ = dot
		_ = lbl
		return wrapper
	end

	_ = makeDot(C_AVATAR, "Kamu")
	_ = makeDot(C_SHADOW, "Bayangan")
	_ = makeDot(C_BODY, "Tubuh")

	-- Timer label
	timerLabel = Instance.new("TextLabel") :: TextLabel
	timerLabel.Name = "Timer"
	timerLabel.Size = UDim2.fromOffset(260, 28)
	timerLabel.Position = UDim2.fromOffset(0, 276)
	timerLabel.BackgroundTransparency = 1
	timerLabel.TextColor3 = C_TEXT
	timerLabel.Font = Enum.Font.GothamMedium
	timerLabel.TextScaled = true
	timerLabel.Text = tostring(math.floor(duration)) .. "s"
	timerLabel.Parent = root

	-- Instruction hint
	local hint = Instance.new("TextLabel") :: TextLabel
	hint.Name = "Hint"
	hint.Size = UDim2.fromOffset(220, 20)
	hint.Position = UDim2.fromOffset(20, 268)
	hint.BackgroundTransparency = 1
	hint.TextColor3 = C_DIM
	hint.Font = Enum.Font.Gotham
	hint.TextScaled = true
	hint.Text = "WASD / Drag arena"
	hint.Parent = root

	_ = title
	_ = hint
	_ = legendFrame
	_ = legendLayout
end

-- ─── Ghost position updates ───────────────────────────────────────────────────

local function worldToArena(worldPos: Vector3, instanceId: string): Vector2
	_ = instanceId
	-- Map world XZ to arena 2D. Scale factor: 1 world unit ≈ 2 arena units.
	-- Centered in arena.
	local scale = 2.0
	return Vector2.new(
		math.clamp(ARENA_SIZE / 2 + worldPos.X * scale, 0, ARENA_SIZE),
		math.clamp(ARENA_SIZE / 2 + worldPos.Z * scale, 0, ARENA_SIZE)
	)
end

local function wireGhostUpdates(instanceId: string)
	local conn = (Remotes["GhostStateChanged"] :: RemoteEvent).OnClientEvent:Connect(function(
		payload: { instanceId: string, shadowPos: Vector3?, worldPos: Vector3? }
	)
		if payload.instanceId ~= instanceId then
			return
		end
		if payload.shadowPos ~= nil then
			shadowPos = worldToArena(payload.shadowPos :: Vector3, instanceId)
		end
		if payload.worldPos ~= nil then
			bodyPos = worldToArena(payload.worldPos :: Vector3, instanceId)
		end
	end)
	table.insert(activeConnections, conn)
end

-- ─── Input wiring ─────────────────────────────────────────────────────────────

local function wireInput()
	-- Touch drag on arena
	local touchBegin = UserInputService.TouchStarted:Connect(function(input: InputObject, _: boolean)
		if not running then
			return
		end
		touchDragging = true
		touchStartPos = Vector2.new(input.Position.X, input.Position.Y)
		avatarAtTouchStart = avatarPos
	end)
	table.insert(activeConnections, touchBegin)

	local touchMove = UserInputService.TouchMoved:Connect(function(input: InputObject, _: boolean)
		if not touchDragging or not running then
			return
		end
		local delta = Vector2.new(input.Position.X, input.Position.Y) - touchStartPos
		avatarPos = clampArena(avatarAtTouchStart + delta, AVATAR_R)
	end)
	table.insert(activeConnections, touchMove)

	local touchEnd = UserInputService.TouchEnded:Connect(function(_: InputObject, _: boolean)
		touchDragging = false
	end)
	table.insert(activeConnections, touchEnd)
end

-- ─── Main update loop ─────────────────────────────────────────────────────────

local function startUpdateLoop(duration: number)
	local startClock = os.clock()

	local loopConn = RunService.Heartbeat:Connect(function(dt: number)
		if not running then
			return
		end

		local elapsed = os.clock() - startClock
		local remaining = math.max(0, duration - elapsed)
		timerLabel.Text = tostring(math.floor(remaining + 0.999)) .. "s"

		-- WASD / arrow keys movement
		local moveDir = Vector2.zero
		if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
			moveDir = moveDir + Vector2.new(0, -1)
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
			moveDir = moveDir + Vector2.new(0, 1)
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
			moveDir = moveDir + Vector2.new(-1, 0)
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
			moveDir = moveDir + Vector2.new(1, 0)
		end

		-- Gamepad left stick
		local sticks = UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)
		for _, axisInput in sticks do
			if axisInput.KeyCode == Enum.KeyCode.Thumbstick1 then
				moveDir = moveDir + Vector2.new(axisInput.Position.X, -axisInput.Position.Y)
				break
			end
		end

		if moveDir.Magnitude > 0 then
			moveDir = moveDir.Unit
			avatarPos = clampArena(avatarPos + moveDir * MOVE_SPEED * dt, AVATAR_R)
		end

		updateCirclePositions()

		-- Contact detection every CONTACT_TICK
		contactAccum += dt
		if contactAccum >= CONTACT_TICK then
			contactAccum -= CONTACT_TICK
			if onInputFn ~= nil then
				local fn = onInputFn :: ({ [string]: any }) -> any
				if circlesOverlap(avatarPos, AVATAR_R, bodyPos, BODY_R) then
					bodyCircle.BackgroundColor3 = C_BODY_HIT
					task.spawn(function()
						fn({ contact = "body" })
					end)
					task.delay(0.3, function()
						if running then
							bodyCircle.BackgroundColor3 = C_BODY
						end
					end)
				elseif circlesOverlap(avatarPos, AVATAR_R, shadowPos, SHADOW_R) then
					task.spawn(function()
						fn({ contact = "shadow" })
					end)
				end
			end
		end
	end)
	table.insert(activeConnections, loopConn)
end

-- ─── Public interface ─────────────────────────────────────────────────────────

function ShadowChase.start(config: { [string]: any }, onInput: ({ [string]: any }) -> any)
	running = true
	onInputFn = onInput
	contactAccum = 0
	touchDragging = false
	avatarPos = Vector2.new(ARENA_SIZE / 2, ARENA_SIZE / 2)
	shadowPos = Vector2.new(ARENA_SIZE / 4, ARENA_SIZE / 4)
	bodyPos = Vector2.new(3 * ARENA_SIZE / 4, 3 * ARENA_SIZE / 4)

	local duration = (config.duration :: number?) or 30
	buildUI(config.container :: Frame, duration)
	wireInput()
	wireGhostUpdates(config.instanceId :: string)
	startUpdateLoop(duration)
end

function ShadowChase.stop()
	running = false
	onInputFn = nil
	touchDragging = false
	for _, conn in activeConnections do
		conn:Disconnect()
	end
	activeConnections = {}
	for _, inst in activeInstances do
		if inst.Parent ~= nil then
			inst:Destroy()
		end
	end
	activeInstances = {}
end

return ShadowChase
