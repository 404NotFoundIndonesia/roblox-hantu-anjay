--!strict
-- MantraTap — T-35
-- Symbol-sequence tap mini-game.
-- Config: { symbols: {string}, timeLimit: number, container: Frame, instanceId: string }
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- ─── State ────────────────────────────────────────────────────────────────────

local MantraTap = {}

local activeConnections: { RBXScriptConnection } = {}
local activeInstances: { Instance } = {}
local running = false

local currentIndex = 1
local symbolCount = 0
local waitingForResponse = false
local onInputFn: (({ [string]: any }) -> any)? = nil

-- UI refs
local timerFill: Frame
local symbolButtons: { TextButton } = {}
local gamepadCursor = 1 -- which button the gamepad cursor is on

-- ─── Colors ───────────────────────────────────────────────────────────────────

local C_BTN_ACTIVE = Color3.fromRGB(60, 140, 220)
local C_BTN_IDLE = Color3.fromRGB(35, 35, 55)
local C_BTN_WRONG = Color3.fromRGB(200, 50, 50)
local C_TEXT = Color3.fromRGB(230, 230, 230)
local C_TEXT_DIM = Color3.fromRGB(90, 90, 110)
local C_TIMER_BG = Color3.fromRGB(30, 30, 45)
local C_TIMER_FILL = Color3.fromRGB(80, 200, 80)
local C_TIMER_LOW = Color3.fromRGB(220, 80, 60)

local FLASH_TWEEN = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- ─── Helpers ──────────────────────────────────────────────────────────────────

local function addCorner(parent: Instance, r: number)
	local c = Instance.new("UICorner") :: UICorner
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function track(inst: Instance)
	table.insert(activeInstances, inst)
end

local function highlightButtons()
	for i, btn in symbolButtons do
		if i == currentIndex then
			btn.BackgroundColor3 = C_BTN_ACTIVE
			btn.TextColor3 = C_TEXT
		else
			btn.BackgroundColor3 = C_BTN_IDLE
			btn.TextColor3 = C_TEXT_DIM
		end
		-- Gamepad cursor outline
		local stroke = btn:FindFirstChildOfClass("UIStroke") :: UIStroke?
		if stroke ~= nil then
			stroke.Enabled = i == gamepadCursor
		end
	end
end

local function flashRed(btn: TextButton)
	TweenService:Create(btn, FLASH_TWEEN, { BackgroundColor3 = C_BTN_WRONG }):Play()
	task.delay(0.3, function()
		if not running then
			return
		end
		local target = if symbolButtons[currentIndex] == btn then C_BTN_ACTIVE else C_BTN_IDLE
		TweenService:Create(btn, FLASH_TWEEN, { BackgroundColor3 = target }):Play()
	end)
end

-- ─── Input handling ───────────────────────────────────────────────────────────

local function handleTap(buttonIndex: number)
	if not running then
		return
	end
	if waitingForResponse then
		return
	end
	if onInputFn == nil then
		return
	end
	local symbols = symbolButtons
	local btn = symbols[buttonIndex]
	if btn == nil then
		return
	end

	local symbol = btn.Text
	waitingForResponse = true

	task.spawn(function()
		local result = onInputFn :: ({ [string]: any }) -> any
		local response = result({ step = currentIndex, symbol = symbol }) :: any
		waitingForResponse = false

		if not running then
			return
		end

		local delta = 0
		if response ~= nil and type(response) == "table" and response.resistanceDelta ~= nil then
			delta = response.resistanceDelta :: number
		end

		if delta > 0 then
			currentIndex += 1
			if currentIndex > symbolCount then
				-- sequence complete; server will send MiniGameEnd
				return
			end
			highlightButtons()
		else
			flashRed(btn)
		end
	end)
end

-- ─── Build UI ─────────────────────────────────────────────────────────────────

local function buildUI(config: { [string]: any })
	local container = config.container :: Frame
	local symbols = config.symbols :: { string }
	local timeLimit = config.timeLimit :: number

	symbolCount = #symbols
	currentIndex = 1
	gamepadCursor = currentIndex
	symbolButtons = {}

	-- Root frame centered on screen
	local root = Instance.new("Frame") :: Frame
	root.Name = "MantraTapRoot"
	root.Size = UDim2.fromOffset(math.min(600, symbolCount * 80 + 40), 220)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.BackgroundColor3 = Color3.fromRGB(15, 15, 28)
	root.BackgroundTransparency = 0.1
	root.Parent = container
	addCorner(root, 12)
	track(root)

	-- Timer bar background
	local timerBG = Instance.new("Frame") :: Frame
	timerBG.Name = "TimerBG"
	timerBG.Size = UDim2.new(1, -24, 0, 14)
	timerBG.Position = UDim2.fromOffset(12, 12)
	timerBG.BackgroundColor3 = C_TIMER_BG
	timerBG.Parent = root
	addCorner(timerBG, 4)

	timerFill = Instance.new("Frame") :: Frame
	timerFill.Name = "TimerFill"
	timerFill.Size = UDim2.fromScale(1, 1)
	timerFill.BackgroundColor3 = C_TIMER_FILL
	timerFill.Parent = timerBG
	addCorner(timerFill, 4)

	-- Instruction label
	local hintLabel = Instance.new("TextLabel") :: TextLabel
	hintLabel.Name = "Hint"
	hintLabel.Size = UDim2.new(1, -24, 0, 28)
	hintLabel.Position = UDim2.fromOffset(12, 32)
	hintLabel.BackgroundTransparency = 1
	hintLabel.TextColor3 = C_TEXT_DIM
	hintLabel.Font = Enum.Font.Gotham
	hintLabel.TextScaled = true
	hintLabel.Text = "Ketuk simbol yang menyala"
	hintLabel.Parent = root

	-- Symbol button row
	local btnRow = Instance.new("Frame") :: Frame
	btnRow.Name = "BtnRow"
	btnRow.Size = UDim2.new(1, -24, 0, 100)
	btnRow.Position = UDim2.fromOffset(12, 68)
	btnRow.BackgroundTransparency = 1
	btnRow.Parent = root

	local layout = Instance.new("UIListLayout") :: UIListLayout
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.Parent = btnRow

	for i, sym in symbols do
		local btn = Instance.new("TextButton") :: TextButton
		btn.Name = "Symbol" .. tostring(i)
		btn.Size = UDim2.fromOffset(80, 80)
		btn.BackgroundColor3 = C_BTN_IDLE
		btn.TextColor3 = C_TEXT_DIM
		btn.Font = Enum.Font.GothamBold
		btn.TextScaled = true
		btn.Text = sym
		btn.AutoButtonColor = false
		btn.Parent = btnRow
		addCorner(btn, 10)

		-- Gamepad cursor outline (disabled by default)
		local stroke = Instance.new("UIStroke") :: UIStroke
		stroke.Thickness = 3
		stroke.Color = Color3.fromRGB(255, 220, 80)
		stroke.Enabled = false
		stroke.Parent = btn

		local capturedIndex = i
		btn.Activated:Connect(function()
			handleTap(capturedIndex)
		end)

		symbolButtons[i] = btn
	end

	highlightButtons()

	-- Key hint label
	local keyHint = Instance.new("TextLabel") :: TextLabel
	keyHint.Name = "KeyHint"
	keyHint.Size = UDim2.new(1, -24, 0, 22)
	keyHint.Position = UDim2.new(0, 12, 1, -28)
	keyHint.BackgroundTransparency = 1
	keyHint.TextColor3 = C_TEXT_DIM
	keyHint.Font = Enum.Font.Gotham
	keyHint.TextScaled = true
	keyHint.Text = "[←/→] Pilih  [Space/A] Konfirmasi"
	keyHint.Parent = root

	_ = hintLabel
	_ = keyHint
	_ = layout
	_ = timerBG

	-- Timer countdown loop
	local startClock = os.clock()
	local timerConn: RBXScriptConnection
	timerConn = game:GetService("RunService").Heartbeat:Connect(function()
		if not running then
			timerConn:Disconnect()
			return
		end
		local elapsed = os.clock() - startClock
		local pct = math.clamp(1 - elapsed / timeLimit, 0, 1)
		timerFill.Size = UDim2.fromScale(pct, 1)
		if pct < 0.3 then
			timerFill.BackgroundColor3 = C_TIMER_LOW
		end
		if elapsed >= timeLimit then
			timerConn:Disconnect()
			if running and onInputFn ~= nil then
				task.spawn(function()
					local fn = onInputFn :: ({ [string]: any }) -> any
					fn({ timeout = true })
				end)
			end
		end
	end)
	table.insert(activeConnections, timerConn)
end

-- ─── Keyboard & Gamepad ───────────────────────────────────────────────────────

local function wireKeyboard()
	local conn = UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if not running then
			return
		end

		if input.KeyCode == Enum.KeyCode.Left or input.KeyCode == Enum.KeyCode.DPadLeft then
			gamepadCursor = math.max(1, gamepadCursor - 1)
			highlightButtons()
		elseif input.KeyCode == Enum.KeyCode.Right or input.KeyCode == Enum.KeyCode.DPadRight then
			gamepadCursor = math.min(symbolCount, gamepadCursor + 1)
			highlightButtons()
		elseif input.KeyCode == Enum.KeyCode.Space
			or input.KeyCode == Enum.KeyCode.Return
			or input.KeyCode == Enum.KeyCode.ButtonA
		then
			handleTap(gamepadCursor)
		end
	end)
	table.insert(activeConnections, conn)
end

-- ─── Public interface ─────────────────────────────────────────────────────────

function MantraTap.start(config: { [string]: any }, onInput: ({ [string]: any }) -> any)
	running = true
	waitingForResponse = false
	onInputFn = onInput
	buildUI(config)
	wireKeyboard()
end

function MantraTap.stop()
	running = false
	onInputFn = nil
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
	symbolButtons = {}
end

return MantraTap
