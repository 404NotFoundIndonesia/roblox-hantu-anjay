--!strict
-- SignalTriangulate — T-38
-- Rotate a compass ring to align with an unknown target angle, then submit.
-- Config: { targetAngle: number, container: Frame, instanceId: string }
-- (targetAngle is server-only; client never sees it directly)
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- ─── State ────────────────────────────────────────────────────────────────────

local SignalTriangulate = {}

local activeConnections: { RBXScriptConnection } = {}
local activeInstances: { Instance } = {}
local running = false
local onInputFn: (({ [string]: any }) -> any)? = nil

local currentAngle = 0.0 -- degrees [0, 360)
local ROTATION_SPEED = 120.0 -- degrees per second via keyboard/stick
local lastFeedbackAlpha = 0.0 -- 0=no feedback, 1=perfect alignment

-- UI refs
local compassFrame: Frame
local needleFrame: Frame
local glowStroke: UIStroke
local feedbackLabel: TextLabel
local angleLabel: TextLabel

-- Touch drag state
local touchStartX = 0.0
local touchDragging = false
local angleatTouchStart = 0.0

-- ─── Colors ───────────────────────────────────────────────────────────────────

local C_COMPASS_BG = Color3.fromRGB(20, 20, 35)
local C_RING = Color3.fromRGB(140, 140, 180)
local C_NEEDLE = Color3.fromRGB(220, 80, 60)
local C_GLOW_FULL = Color3.fromRGB(80, 220, 255)
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

local function wrapAngle(a: number): number
	a = a % 360
	if a < 0 then
		a += 360
	end
	return a
end

local function updateVisuals()
	if compassFrame == nil then
		return
	end
	compassFrame.Rotation = currentAngle
	angleLabel.Text = tostring(math.floor(currentAngle)) .. "°"

	-- Interpolate glow colour based on last feedback
	local alpha = lastFeedbackAlpha
	glowStroke.Color = C_RING:Lerp(C_GLOW_FULL, alpha)
	glowStroke.Thickness = 3 + alpha * 5
end

-- ─── Build UI ─────────────────────────────────────────────────────────────────

local function buildUI(container: Frame)
	local root = Instance.new("Frame") :: Frame
	root.Name = "SignalTriangulateRoot"
	root.Size = UDim2.fromOffset(320, 380)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.BackgroundColor3 = C_COMPASS_BG
	root.BackgroundTransparency = 0.08
	root.Parent = container
	addCorner(root, 12)
	track(root)

	local title = Instance.new("TextLabel") :: TextLabel
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 36)
	title.Position = UDim2.fromScale(0, 0)
	title.BackgroundTransparency = 1
	title.TextColor3 = C_TEXT
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.Text = "Segitiga Sinyal"
	title.Parent = root

	-- Compass ring (rotates with currentAngle)
	compassFrame = Instance.new("Frame") :: Frame
	compassFrame.Name = "Compass"
	compassFrame.Size = UDim2.fromOffset(200, 200)
	compassFrame.Position = UDim2.fromScale(0.5, 0.5)
	compassFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	compassFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 22)
	compassFrame.BackgroundTransparency = 0.3
	compassFrame.Parent = root
	addCorner(compassFrame, 100)

	glowStroke = Instance.new("UIStroke") :: UIStroke
	glowStroke.Color = C_RING
	glowStroke.Thickness = 3
	glowStroke.Parent = compassFrame

	-- Needle (vertical bar inside compass)
	needleFrame = Instance.new("Frame") :: Frame
	needleFrame.Name = "Needle"
	needleFrame.Size = UDim2.fromOffset(6, 80)
	needleFrame.Position = UDim2.fromScale(0.5, 0.0)
	needleFrame.AnchorPoint = Vector2.new(0.5, 0)
	needleFrame.BackgroundColor3 = C_NEEDLE
	needleFrame.ZIndex = 2
	needleFrame.Parent = compassFrame
	addCorner(needleFrame, 3)

	-- Cardinal tick marks
	local cardinals = { "N", "E", "S", "W" }
	local cardinalAngles = { 0, 90, 180, 270 }
	local COMPASS_R = 80 -- radius for text placement
	for ci, label in cardinals do
		local rad = math.rad(cardinalAngles[ci])
		local lbl = Instance.new("TextLabel") :: TextLabel
		lbl.Name = "Cardinal" .. label
		lbl.Size = UDim2.fromOffset(20, 20)
		lbl.AnchorPoint = Vector2.new(0.5, 0.5)
		lbl.Position = UDim2.fromOffset(
			100 + math.sin(rad) * COMPASS_R,
			100 - math.cos(rad) * COMPASS_R
		)
		lbl.BackgroundTransparency = 1
		lbl.TextColor3 = C_DIM
		lbl.Font = Enum.Font.GothamBold
		lbl.TextScaled = true
		lbl.Text = label
		lbl.ZIndex = 3
		lbl.Parent = compassFrame
	end

	-- Angle readout
	angleLabel = Instance.new("TextLabel") :: TextLabel
	angleLabel.Name = "AngleLabel"
	angleLabel.Size = UDim2.fromOffset(200, 30)
	angleLabel.Position = UDim2.fromScale(0.5, 0.72)
	angleLabel.AnchorPoint = Vector2.new(0.5, 0)
	angleLabel.BackgroundTransparency = 1
	angleLabel.TextColor3 = C_TEXT
	angleLabel.Font = Enum.Font.GothamMedium
	angleLabel.TextScaled = true
	angleLabel.Text = "0°"
	angleLabel.Parent = root

	-- Feedback label
	feedbackLabel = Instance.new("TextLabel") :: TextLabel
	feedbackLabel.Name = "Feedback"
	feedbackLabel.Size = UDim2.fromOffset(280, 28)
	feedbackLabel.Position = UDim2.fromScale(0.5, 0.8)
	feedbackLabel.AnchorPoint = Vector2.new(0.5, 0)
	feedbackLabel.BackgroundTransparency = 1
	feedbackLabel.TextColor3 = C_DIM
	feedbackLabel.Font = Enum.Font.Gotham
	feedbackLabel.TextScaled = true
	feedbackLabel.Text = "Putar kompas, lalu kirim"
	feedbackLabel.Parent = root

	-- Submit button
	local submitBtn = Instance.new("TextButton") :: TextButton
	submitBtn.Name = "SubmitBtn"
	submitBtn.Size = UDim2.fromOffset(160, 48)
	submitBtn.Position = UDim2.fromScale(0.5, 0.9)
	submitBtn.AnchorPoint = Vector2.new(0.5, 0)
	submitBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
	submitBtn.TextColor3 = C_TEXT
	submitBtn.Font = Enum.Font.GothamBold
	submitBtn.TextScaled = true
	submitBtn.Text = "Kirim [Enter/A]"
	submitBtn.AutoButtonColor = true
	submitBtn.Parent = root
	addCorner(submitBtn, 8)
	submitBtn.Activated:Connect(function()
		if not running then
			return
		end
		if onInputFn ~= nil then
			local angle = currentAngle
			local fn = onInputFn :: ({ [string]: any }) -> any
			task.spawn(function()
				local response = fn({ submittedAngle = angle }) :: any
				if response ~= nil and type(response) == "table" then
					local delta = (response.resistanceDelta :: number?) or 0
					-- Map resistanceDelta to feedback alpha (0=no match, >0=closer)
					lastFeedbackAlpha = math.clamp(delta / 10, 0, 1)
					if delta > 0 then
						feedbackLabel.Text = "Sinyal terdeteksi!"
						feedbackLabel.TextColor3 = C_GLOW_FULL
					else
						feedbackLabel.Text = "Tidak ada sinyal..."
						feedbackLabel.TextColor3 = C_DIM
					end
					updateVisuals()
				end
			end)
		end
	end)

	_ = title
	_ = needleFrame
end

-- ─── Input handling ───────────────────────────────────────────────────────────

local function wireInput()
	-- Keyboard A/D + left/right arrows
	local conn = RunService.Heartbeat:Connect(function(dt: number)
		if not running then
			return
		end
		local delta = 0.0
		if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
			delta -= ROTATION_SPEED * dt
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
			delta += ROTATION_SPEED * dt
		end
		-- Gamepad left stick X
		local leftStick = UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)
		for _, axisInput in leftStick do
			if axisInput.KeyCode == Enum.KeyCode.Thumbstick1 then
				delta += axisInput.Position.X * ROTATION_SPEED * dt
				break
			end
		end

		if delta ~= 0 then
			currentAngle = wrapAngle(currentAngle + delta)
			updateVisuals()
		end
	end)
	table.insert(activeConnections, conn)

	-- Enter / gamepad A to submit
	local submitConn = UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if not running then
			return
		end
		if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.ButtonA then
			if onInputFn ~= nil then
				local angle = currentAngle
				local fn = onInputFn :: ({ [string]: any }) -> any
				task.spawn(function()
					local response = fn({ submittedAngle = angle }) :: any
					if response ~= nil and type(response) == "table" then
						local delta2 = (response.resistanceDelta :: number?) or 0
						lastFeedbackAlpha = math.clamp(delta2 / 10, 0, 1)
						updateVisuals()
					end
				end)
			end
		end
	end)
	table.insert(activeConnections, submitConn)

	-- Touch drag to rotate
	local touchBeginConn = UserInputService.TouchStarted:Connect(function(input: InputObject, _: boolean)
		touchDragging = true
		touchStartX = input.Position.X
		angleatTouchStart = currentAngle
	end)
	table.insert(activeConnections, touchBeginConn)

	local touchMoveConn = UserInputService.TouchMoved:Connect(function(input: InputObject, _: boolean)
		if not touchDragging then
			return
		end
		local dx = input.Position.X - touchStartX
		currentAngle = wrapAngle(angleatTouchStart + dx * 0.5)
		updateVisuals()
	end)
	table.insert(activeConnections, touchMoveConn)

	local touchEndConn = UserInputService.TouchEnded:Connect(function(_: InputObject, _: boolean)
		touchDragging = false
	end)
	table.insert(activeConnections, touchEndConn)
end

-- ─── Public interface ─────────────────────────────────────────────────────────

function SignalTriangulate.start(config: { [string]: any }, onInput: ({ [string]: any }) -> any)
	running = true
	onInputFn = onInput
	currentAngle = 0
	lastFeedbackAlpha = 0
	touchDragging = false
	buildUI(config.container :: Frame)
	wireInput()
	updateVisuals()
end

function SignalTriangulate.stop()
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

return SignalTriangulate
