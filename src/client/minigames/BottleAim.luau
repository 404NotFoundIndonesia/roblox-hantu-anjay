--!strict
-- BottleAim — T-36
-- Hold reticle on ghost's screen position to drain resistance.
-- Config: { holdDuration: number, ghostWorldPos: Vector3, container: Frame, instanceId: string }
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

-- ─── State ────────────────────────────────────────────────────────────────────

local BottleAim = {}

local activeConnections: { RBXScriptConnection } = {}
local activeInstances: { Instance } = {}
local running = false

local ghostWorldPos: Vector3 = Vector3.new(0, 0, 0)
local holdAccum = 0.0
local isHolding = false
local inputAccum = 0.0
local onInputFn: (({ [string]: any }) -> any)? = nil

-- UI refs
local reticleFrame: Frame
local fillBar: Frame
local progressLabel: TextLabel
local offScreenLabel: TextLabel

-- ─── Constants ────────────────────────────────────────────────────────────────

local RETICLE_SIZE = 80
local INPUT_TICK = 0.5
local C_RETICLE = Color3.fromRGB(80, 180, 255)
local C_FILL = Color3.fromRGB(40, 220, 120)
local C_TEXT = Color3.fromRGB(230, 230, 230)
local C_DIM = Color3.fromRGB(120, 120, 140)

-- ─── Helpers ──────────────────────────────────────────────────────────────────

local function addCorner(parent: Instance, r: number)
	local c = Instance.new("UICorner") :: UICorner
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function track(inst: Instance)
	table.insert(activeInstances, inst)
end

local function worldToScreen(worldPos: Vector3): (Vector2, boolean)
	local camera = workspace.CurrentCamera
	if camera == nil then
		return Vector2.new(0, 0), false
	end
	local screenVec, onScreen = camera:WorldToScreenPoint(worldPos)
	return Vector2.new(screenVec.X, screenVec.Y), onScreen
end

-- ─── Reticle update ───────────────────────────────────────────────────────────

local function updateReticlePosition()
	local screenPos, onScreen = worldToScreen(ghostWorldPos)
	if onScreen then
		reticleFrame.Visible = true
		offScreenLabel.Visible = false
		reticleFrame.Position = UDim2.fromOffset(
			screenPos.X - RETICLE_SIZE / 2,
			screenPos.Y - RETICLE_SIZE / 2
		)
	else
		reticleFrame.Visible = false
		offScreenLabel.Visible = true
	end
end

local function updateFill(pct: number)
	fillBar.Size = UDim2.fromScale(pct, 1)
	progressLabel.Text = tostring(math.floor(pct * 100)) .. "%"
end

-- ─── Hold state ───────────────────────────────────────────────────────────────

local function isPointerOnReticle(inputPos: Vector2): boolean
	if not reticleFrame.Visible then
		return false
	end
	local absPos = reticleFrame.AbsolutePosition
	local absSize = reticleFrame.AbsoluteSize
	return inputPos.X >= absPos.X
		and inputPos.X <= absPos.X + absSize.X
		and inputPos.Y >= absPos.Y
		and inputPos.Y <= absPos.Y + absSize.Y
end

local function startHold()
	isHolding = true
end

local function stopHold()
	isHolding = false
	holdAccum = 0
	inputAccum = 0
	updateFill(0)
end

-- ─── GhostStateChanged: track ghost movement ──────────────────────────────────

local function wireGhostUpdates(instanceId: string)
	local conn = (Remotes["GhostStateChanged"] :: RemoteEvent).OnClientEvent:Connect(function(
		payload: { instanceId: string, shadowPos: Vector3? }
	)
		if payload.instanceId ~= instanceId then
			return
		end
		if payload.shadowPos ~= nil then
			ghostWorldPos = payload.shadowPos :: Vector3
		end
	end)
	table.insert(activeConnections, conn)
end

-- ─── Build UI ─────────────────────────────────────────────────────────────────

local function buildUI(container: Frame)
	local overlay = Instance.new("Frame") :: Frame
	overlay.Name = "BottleAimOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundTransparency = 1
	overlay.Parent = container
	track(overlay)

	offScreenLabel = Instance.new("TextLabel") :: TextLabel
	offScreenLabel.Name = "OffScreen"
	offScreenLabel.Size = UDim2.fromOffset(300, 40)
	offScreenLabel.Position = UDim2.fromScale(0.5, 0.08)
	offScreenLabel.AnchorPoint = Vector2.new(0.5, 0)
	offScreenLabel.BackgroundTransparency = 1
	offScreenLabel.TextColor3 = C_DIM
	offScreenLabel.Font = Enum.Font.GothamMedium
	offScreenLabel.TextScaled = true
	offScreenLabel.Text = "Hantu di luar layar..."
	offScreenLabel.Visible = false
	offScreenLabel.Parent = overlay

	reticleFrame = Instance.new("Frame") :: Frame
	reticleFrame.Name = "Reticle"
	reticleFrame.Size = UDim2.fromOffset(RETICLE_SIZE, RETICLE_SIZE)
	reticleFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 28)
	reticleFrame.BackgroundTransparency = 0.3
	reticleFrame.ZIndex = 2
	reticleFrame.Parent = overlay
	addCorner(reticleFrame, RETICLE_SIZE)

	local ring = Instance.new("UIStroke") :: UIStroke
	ring.Color = C_RETICLE
	ring.Thickness = 3
	ring.Parent = reticleFrame

	local fillBG = Instance.new("Frame") :: Frame
	fillBG.Name = "FillBG"
	fillBG.Size = UDim2.new(1, 0, 0, 14)
	fillBG.Position = UDim2.new(0, 0, 1, -18)
	fillBG.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
	fillBG.ZIndex = 3
	fillBG.Parent = reticleFrame
	addCorner(fillBG, 4)

	fillBar = Instance.new("Frame") :: Frame
	fillBar.Name = "Fill"
	fillBar.Size = UDim2.fromScale(0, 1)
	fillBar.BackgroundColor3 = C_FILL
	fillBar.ZIndex = 4
	fillBar.Parent = fillBG
	addCorner(fillBar, 4)

	progressLabel = Instance.new("TextLabel") :: TextLabel
	progressLabel.Name = "Pct"
	progressLabel.Size = UDim2.fromScale(1, 1)
	progressLabel.BackgroundTransparency = 1
	progressLabel.TextColor3 = C_TEXT
	progressLabel.Font = Enum.Font.GothamBold
	progressLabel.TextScaled = true
	progressLabel.Text = "0%"
	progressLabel.ZIndex = 4
	progressLabel.Parent = reticleFrame

	local hintLbl = Instance.new("TextLabel") :: TextLabel
	hintLbl.Name = "Hint"
	hintLbl.Size = UDim2.fromOffset(260, 32)
	hintLbl.Position = UDim2.fromScale(0.5, 0.88)
	hintLbl.AnchorPoint = Vector2.new(0.5, 0)
	hintLbl.BackgroundTransparency = 1
	hintLbl.TextColor3 = C_DIM
	hintLbl.Font = Enum.Font.Gotham
	hintLbl.TextScaled = true
	hintLbl.Text = "Tahan pada lingkaran hantu"
	hintLbl.Parent = overlay

	_ = ring
	_ = fillBG
	_ = hintLbl
end

-- ─── Input wiring ─────────────────────────────────────────────────────────────

local function wireInput()
	local beginConn = UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if not running then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			local pos = Vector2.new(input.Position.X, input.Position.Y)
			if isPointerOnReticle(pos) then
				startHold()
			end
		elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
			startHold()
		end
	end)
	table.insert(activeConnections, beginConn)

	local endConn = UserInputService.InputEnded:Connect(function(input: InputObject, _: boolean)
		if not running then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.ButtonR2
		then
			stopHold()
		end
	end)
	table.insert(activeConnections, endConn)
end

-- ─── Update loop ──────────────────────────────────────────────────────────────

local function startUpdateLoop(holdDuration: number)
	local loopConn = RunService.Heartbeat:Connect(function(dt: number)
		if not running then
			return
		end
		updateReticlePosition()

		if not isHolding then
			return
		end
		holdAccum += dt
		inputAccum += dt
		updateFill(math.clamp(holdAccum / holdDuration, 0, 1))

		if inputAccum >= INPUT_TICK then
			inputAccum -= INPUT_TICK
			local accum = holdAccum
			if onInputFn ~= nil then
				local fn = onInputFn :: ({ [string]: any }) -> any
				task.spawn(function()
					fn({ heldSeconds = accum })
				end)
			end
		end
	end)
	table.insert(activeConnections, loopConn)
end

-- ─── Public interface ─────────────────────────────────────────────────────────

function BottleAim.start(config: { [string]: any }, onInput: ({ [string]: any }) -> any)
	running = true
	holdAccum = 0
	inputAccum = 0
	isHolding = false
	onInputFn = onInput
	ghostWorldPos = (config.ghostWorldPos :: Vector3?) or Vector3.new(0, 0, 0)

	local holdDuration = (config.holdDuration :: number?) or 2
	buildUI(config.container :: Frame)
	wireInput()
	wireGhostUpdates(config.instanceId :: string)
	startUpdateLoop(holdDuration)
end

function BottleAim.stop()
	running = false
	onInputFn = nil
	isHolding = false
	holdAccum = 0
	inputAccum = 0
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

return BottleAim
