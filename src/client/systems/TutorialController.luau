--!strict
-- TutorialController — T-44
-- Client-side tutorial UI: NPC chat bubble, step highlights, skip button.
-- Listens to TutorialStep RemoteEvent (step field; step=-1 ends tutorial).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local LocalizationBridge = require(script.Parent.LocalizationBridge)
local UIManager = require(script.Parent.UIManager)
local HUD = require(script.Parent.HUD)

local LocalPlayer = Players.LocalPlayer

-- ─── Module ───────────────────────────────────────────────────────────────────

local TutorialController = {}

-- ─── Colors & tweens ──────────────────────────────────────────────────────────

local C_BUBBLE_BG = Color3.fromRGB(20, 20, 35)
local C_TEXT = Color3.fromRGB(230, 230, 230)
local C_DIM = Color3.fromRGB(130, 130, 150)
local C_SKIP_BG = Color3.fromRGB(60, 60, 80)
local C_HIGHLIGHT = Color3.fromRGB(80, 200, 255)
local C_ARROW = Color3.fromRGB(240, 200, 60)

local PULSE_IN = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

-- ─── State ────────────────────────────────────────────────────────────────────

local tutorialActive = false
local currentStep = -1

-- Active UI instances created by this controller
local screenGui: ScreenGui
local bubbleGui: BillboardGui? = nil
local bubbleLabel: TextLabel? = nil
local skipButton: TextButton? = nil
local arrowFrame: Frame? = nil

-- Highlight/pulse connections
local activeConnections: { RBXScriptConnection } = {}
local activeTweens: { Tween } = {}
local scanPulseStroke: UIStroke? = nil
local ghostHighlight: Highlight? = nil

-- ─── Helpers ──────────────────────────────────────────────────────────────────

local function addCorner(parent: Instance, r: number)
	local c = Instance.new("UICorner") :: UICorner
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function clearPulse()
	for _, t in activeTweens do
		t:Cancel()
	end
	activeTweens = {}
	if scanPulseStroke ~= nil then
		scanPulseStroke:Destroy()
		scanPulseStroke = nil
	end
	if ghostHighlight ~= nil then
		ghostHighlight:Destroy()
		ghostHighlight = nil
	end
	if arrowFrame ~= nil then
		arrowFrame:Destroy()
		arrowFrame = nil
	end
end

local function clearConnections()
	for _, c in activeConnections do
		c:Disconnect()
	end
	activeConnections = {}
end

-- ─── NPC bubble ───────────────────────────────────────────────────────────────

-- Shows bubble text above the TutorialNPC model if it exists in workspace,
-- otherwise falls back to a screen-space label at the top of the screen.
local function showBubble(text: string)
	if bubbleLabel ~= nil then
		bubbleLabel.Text = text
		return
	end

	-- Try to find NPC model in workspace
	local npcModel = workspace:FindFirstChild("TutorialNPC", true) :: Model?

	if npcModel ~= nil then
		local billboard = Instance.new("BillboardGui") :: BillboardGui
		billboard.Name = "TutorialBubble"
		billboard.Size = UDim2.fromOffset(260, 70)
		billboard.StudsOffset = Vector3.new(0, 4, 0)
		billboard.AlwaysOnTop = true
		billboard.Adornee = npcModel.PrimaryPart or npcModel:FindFirstChildWhichIsA("BasePart")
		billboard.Parent = npcModel
		bubbleGui = billboard

		local bg = Instance.new("Frame") :: Frame
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = C_BUBBLE_BG
		bg.BackgroundTransparency = 0.1
		bg.Parent = billboard
		addCorner(bg, 10)

		local lbl = Instance.new("TextLabel") :: TextLabel
		lbl.Size = UDim2.new(1, -16, 1, 0)
		lbl.Position = UDim2.fromOffset(8, 0)
		lbl.BackgroundTransparency = 1
		lbl.TextColor3 = C_TEXT
		lbl.Font = Enum.Font.GothamMedium
		lbl.TextScaled = true
		lbl.TextWrapped = true
		lbl.Text = text
		lbl.Parent = bg
		bubbleLabel = lbl

		_ = bg
	else
		-- Screen-space fallback: label at top of screen
		local lbl = Instance.new("TextLabel") :: TextLabel
		lbl.Name = "TutorialBubble"
		lbl.Size = UDim2.fromOffset(360, 60)
		lbl.Position = UDim2.fromScale(0.5, 0.06)
		lbl.AnchorPoint = Vector2.new(0.5, 0)
		lbl.BackgroundColor3 = C_BUBBLE_BG
		lbl.BackgroundTransparency = 0.1
		lbl.TextColor3 = C_TEXT
		lbl.Font = Enum.Font.GothamMedium
		lbl.TextScaled = true
		lbl.TextWrapped = true
		lbl.Text = text
		lbl.Parent = screenGui
		addCorner(lbl, 10)
		bubbleLabel = lbl
	end
end

local function hideBubble()
	if bubbleGui ~= nil then
		bubbleGui:Destroy()
		bubbleGui = nil
	end
	if bubbleLabel ~= nil then
		if bubbleLabel.Parent ~= nil then
			bubbleLabel:Destroy()
		end
		bubbleLabel = nil
	end
end

-- ─── Skip button ──────────────────────────────────────────────────────────────

local function showSkipButton()
	if skipButton ~= nil then
		return
	end
	local btn = Instance.new("TextButton") :: TextButton
	btn.Name = "TutorialSkip"
	btn.Size = UDim2.fromOffset(100, 36)
	btn.Position = UDim2.new(1, -12, 0, 12)
	btn.AnchorPoint = Vector2.new(1, 0)
	btn.BackgroundColor3 = C_SKIP_BG
	btn.BackgroundTransparency = 0.3
	btn.TextColor3 = C_DIM
	btn.Font = Enum.Font.Gotham
	btn.TextScaled = true
	btn.Text = "Lewati"
	btn.AutoButtonColor = true
	btn.Parent = screenGui
	addCorner(btn, 6)

	btn.Activated:Connect(function()
		pcall(function()
			(Remotes["RequestSkipTutorial"] :: RemoteFunction):InvokeServer()
		end)
	end)

	skipButton = btn
end

local function hideSkipButton()
	if skipButton ~= nil then
		skipButton:Destroy()
		skipButton = nil
	end
end

-- ─── Walk arrow ───────────────────────────────────────────────────────────────

local function showWalkArrow()
	if arrowFrame ~= nil then
		return
	end
	local frame = Instance.new("Frame") :: Frame
	frame.Name = "TutorialArrow"
	frame.Size = UDim2.fromOffset(60, 60)
	frame.Position = UDim2.fromScale(0.5, 0.35)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundTransparency = 1
	frame.Parent = screenGui

	local lbl = Instance.new("TextLabel") :: TextLabel
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = C_ARROW
	lbl.Font = Enum.Font.GothamBold
	lbl.TextScaled = true
	lbl.Text = "▼"
	lbl.Parent = frame

	-- Bounce tween
	local t = TweenService:Create(frame, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Position = UDim2.fromScale(0.5, 0.38),
	})
	t:Play()
	table.insert(activeTweens, t)

	arrowFrame = frame
	_ = lbl
end

-- ─── SCAN button pulse (step 1) ───────────────────────────────────────────────

local function pulseScanButton()
	if HUD.screenGui == nil then
		return
	end
	local hudGui = HUD.screenGui :: ScreenGui
	local scanBtn = hudGui:FindFirstChild("ScanButton", true) :: TextButton?
	if scanBtn == nil then
		return
	end
	local stroke = Instance.new("UIStroke") :: UIStroke
	stroke.Color = C_HIGHLIGHT
	stroke.Thickness = 4
	stroke.Parent = scanBtn
	scanPulseStroke = stroke

	local t = TweenService:Create(stroke, PULSE_IN, { Thickness = 10 })
	t:Play()
	table.insert(activeTweens, t)
end

-- ─── Ghost highlight (step 3) ─────────────────────────────────────────────────

local function highlightGhost(instanceId: string)
	local ghostsFolder = workspace:FindFirstChild("Ghosts") :: Folder?
	if ghostsFolder == nil then
		return
	end
	local model = ghostsFolder:FindFirstChild(instanceId) :: Model?
	if model == nil then
		-- Model might arrive slightly after the TutorialStep event; retry once.
		task.delay(1, function()
			local gf = workspace:FindFirstChild("Ghosts") :: Folder?
			if gf == nil then return end
			local m = gf:FindFirstChild(instanceId) :: Model?
			if m == nil then return end
			local h = Instance.new("Highlight") :: Highlight
			h.FillTransparency = 0.6
			h.OutlineColor = C_HIGHLIGHT
			h.FillColor = C_HIGHLIGHT
			h.Parent = m
			ghostHighlight = h
		end)
		return
	end
	local h = Instance.new("Highlight") :: Highlight
	h.FillTransparency = 0.6
	h.OutlineColor = C_HIGHLIGHT
	h.FillColor = C_HIGHLIGHT
	h.Parent = model
	ghostHighlight = h
end

-- ─── Mini-map highlight (step 6) ─────────────────────────────────────────────

local function highlightMiniMap()
	if HUD.screenGui == nil then
		return
	end
	local hudGui = HUD.screenGui :: ScreenGui
	local mapFrame = hudGui:FindFirstChild("MiniMap", true) :: Frame?
	if mapFrame == nil then
		return
	end
	local stroke = Instance.new("UIStroke") :: UIStroke
	stroke.Color = C_HIGHLIGHT
	stroke.Thickness = 4
	stroke.Parent = mapFrame
	local t = TweenService:Create(stroke, PULSE_IN, { Thickness = 8 })
	t:Play()
	table.insert(activeTweens, t)
	-- Remove after 5 seconds
	task.delay(5, function()
		if stroke.Parent ~= nil then
			stroke:Destroy()
		end
	end)
end

-- ─── End tutorial ─────────────────────────────────────────────────────────────

local function endTutorial()
	tutorialActive = false
	currentStep = -1
	clearPulse()
	clearConnections()
	hideBubble()
	hideSkipButton()
	UIManager.close("Tutorial")
end

-- ─── Step dispatcher ──────────────────────────────────────────────────────────

local function applyStep(step: number, payload: { [string]: any })
	currentStep = step

	clearPulse()

	if step == -1 then
		endTutorial()
		return
	end

	if step == 0 then
		showBubble(LocalizationBridge.get("TUT_STEP0"))
		showWalkArrow()
		return
	end

	if step == 1 then
		showBubble(LocalizationBridge.get("TUT_STEP1"))
		pulseScanButton()
		if arrowFrame ~= nil then
			arrowFrame:Destroy()
			arrowFrame = nil
		end
		return
	end

	if step == 2 then
		showBubble(LocalizationBridge.get("TUT_STEP2"))
		return
	end

	if step == 3 then
		showBubble(LocalizationBridge.get("TUT_STEP3"))
		local instanceId = payload.instanceId
		if type(instanceId) == "string" then
			highlightGhost(instanceId)
		end
		return
	end

	-- step 4: MantraTap opens (server already doubled timeLimit); no extra UI needed.
	if step == 4 then
		return
	end

	if step == 5 then
		showBubble(LocalizationBridge.get("TUT_STEP4"))
		-- Auto-open Compendium with a brief delay so MiniGameEnd overlay clears first.
		task.delay(1, function()
			if currentStep == 5 then
				UIManager.open("Compendium")
			end
		end)
		return
	end

	if step == 6 then
		showBubble(LocalizationBridge.get("TUT_STEP5"))
		highlightMiniMap()
		-- Tutorial auto-completes server-side after step 6; client just waits for step=-1.
		return
	end
end

-- ─── UIModule interface ───────────────────────────────────────────────────────

function TutorialController.open()
	if screenGui ~= nil then
		screenGui.Enabled = true
	end
end

function TutorialController.close()
	-- Tutorial UI stays visible until explicitly ended — do not hide on close sweep.
end

TutorialController.screenGui = nil :: ScreenGui?

-- ─── Init ─────────────────────────────────────────────────────────────────────

function TutorialController.Init()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")

	screenGui = Instance.new("ScreenGui") :: ScreenGui
	screenGui.Name = "TutorialUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	screenGui.Enabled = false
	screenGui.Parent = playerGui

	TutorialController.screenGui = screenGui

	UIManager.register("Tutorial", TutorialController)

	;(Remotes["TutorialStep"] :: RemoteEvent).OnClientEvent:Connect(function(
		payload: { step: number, [string]: any }
	)
		local step = payload.step
		if type(step) ~= "number" then
			return
		end

		if step == -1 then
			endTutorial()
			return
		end

		if not tutorialActive then
			tutorialActive = true
			screenGui.Enabled = true
			showSkipButton()
		end

		applyStep(step, payload)
	end)
end

return TutorialController
