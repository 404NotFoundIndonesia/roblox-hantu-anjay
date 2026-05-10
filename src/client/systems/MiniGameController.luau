--!strict
-- MiniGameController — T-34
-- Dispatches MiniGameStart to the correct mini-game module.
-- Wires the onInput callback and shows the result overlay on MiniGameEnd.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local LocalizationBridge = require(script.Parent.LocalizationBridge)
local UIManager = require(script.Parent.UIManager)

local LocalPlayer = Players.LocalPlayer

-- ─── Mini-game module type ────────────────────────────────────────────────────

export type MiniGameModule = {
	start: ({ [string]: any }, ({ [string]: any }) -> any) -> (),
	stop: () -> (),
}

-- Require all modules up-front so requires don't block mid-game.
local miniGameModules: { [string]: MiniGameModule } = {
	MantraTap = require(script.Parent.Parent.minigames.MantraTap) :: MiniGameModule,
	BottleAim = require(script.Parent.Parent.minigames.BottleAim) :: MiniGameModule,
	RhythmChant = require(script.Parent.Parent.minigames.RhythmChant) :: MiniGameModule,
	SignalTriangulate = require(script.Parent.Parent.minigames.SignalTriangulate) :: MiniGameModule,
	ShadowChase = require(script.Parent.Parent.minigames.ShadowChase) :: MiniGameModule,
	TeamSurround = require(script.Parent.Parent.minigames.TeamSurround) :: MiniGameModule,
}

-- ─── Module state ─────────────────────────────────────────────────────────────

local MiniGameController = {}

local screenGui: ScreenGui
local containerFrame: Frame
local resultOverlay: Frame
local resultLabel: TextLabel

local activeModule: MiniGameModule? = nil

-- ─── Helpers ──────────────────────────────────────────────────────────────────

local AudioController = require(script.Parent.AudioController) :: any

local function playSound(key: string)
	pcall(function()
		if type(AudioController.playUI) == "function" then
			(AudioController.playUI :: (string) -> ())(key)
		end
	end)
end

local function clearContainer()
	for _, child in containerFrame:GetChildren() do
		child:Destroy()
	end
end

-- ─── Result overlay ───────────────────────────────────────────────────────────

local OVERLAY_TWEEN = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SUCCESS_COLOR = Color3.fromRGB(40, 160, 80)
local FAIL_COLOR = Color3.fromRGB(180, 50, 50)

local function showResult(success: boolean)
	if success then
		resultLabel.Text = LocalizationBridge.get("UI_CAPTURE_SUCCESS")
		resultOverlay.BackgroundColor3 = SUCCESS_COLOR
	else
		resultLabel.Text = LocalizationBridge.get("UI_CAPTURE_FAIL")
		resultOverlay.BackgroundColor3 = FAIL_COLOR
	end
	resultOverlay.Visible = true
	TweenService:Create(resultOverlay, OVERLAY_TWEEN, { BackgroundTransparency = 0.1 }):Play()

	task.delay(2.5, function()
		local tween = TweenService:Create(resultOverlay, OVERLAY_TWEEN, { BackgroundTransparency = 1 })
		tween:Play()
		tween.Completed:Connect(function()
			resultOverlay.Visible = false
		end)
	end)
end

-- ─── onInput factory ──────────────────────────────────────────────────────────

local function makeOnInput(instanceId: string): ({ [string]: any }) -> any
	return function(inputData: { [string]: any }): any
		local ok, result = pcall(function()
			return (Remotes["RequestMiniGameInput"] :: RemoteFunction):InvokeServer(instanceId, inputData)
		end)
		if ok then
			return result
		end
		return nil
	end
end

-- ─── Screen building ──────────────────────────────────────────────────────────

local function buildScreen()
	screenGui = Instance.new("ScreenGui") :: ScreenGui
	screenGui.Name = "MiniGameUI"
	screenGui.ResetOnSpawn = false
	screenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Enabled = false
	screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

	containerFrame = Instance.new("Frame") :: Frame
	containerFrame.Name = "Container"
	containerFrame.Size = UDim2.fromScale(1, 1)
	containerFrame.BackgroundTransparency = 1
	containerFrame.Parent = screenGui

	-- Result overlay (hidden until mini-game ends)
	resultOverlay = Instance.new("Frame") :: Frame
	resultOverlay.Name = "ResultOverlay"
	resultOverlay.Size = UDim2.fromScale(1, 0.15)
	resultOverlay.Position = UDim2.fromScale(0, 0.425)
	resultOverlay.AnchorPoint = Vector2.new(0, 0)
	resultOverlay.BackgroundColor3 = SUCCESS_COLOR
	resultOverlay.BackgroundTransparency = 1
	resultOverlay.ZIndex = 20
	resultOverlay.Visible = false
	resultOverlay.Parent = screenGui

	local corner = Instance.new("UICorner") :: UICorner
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = resultOverlay

	resultLabel = Instance.new("TextLabel") :: TextLabel
	resultLabel.Name = "ResultLabel"
	resultLabel.Size = UDim2.fromScale(1, 1)
	resultLabel.BackgroundTransparency = 1
	resultLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	resultLabel.Font = Enum.Font.GothamBold
	resultLabel.TextScaled = true
	resultLabel.ZIndex = 21
	resultLabel.Parent = resultOverlay

	MiniGameController.screenGui = screenGui
end

-- ─── UIModule interface ───────────────────────────────────────────────────────

function MiniGameController.open()
	if screenGui ~= nil then
		screenGui.Enabled = true
	end
end

function MiniGameController.close()
	if screenGui ~= nil then
		screenGui.Enabled = false
	end
end

MiniGameController.screenGui = nil :: ScreenGui?

-- ─── Init ─────────────────────────────────────────────────────────────────────

function MiniGameController.Init()
	buildScreen()
	UIManager.register("MiniGame", MiniGameController)

	-- MiniGameStart: route to correct module
	;(Remotes["MiniGameStart"] :: RemoteEvent).OnClientEvent:Connect(function(
		payload: { instanceId: string, miniGameType: string, config: { [string]: any } }
	)
		local instanceId = payload.instanceId
		local miniGameType = payload.miniGameType
		local config = payload.config

		local module = miniGameModules[miniGameType]
		if module == nil then
			warn("[MiniGameController] Unknown miniGameType: " .. tostring(miniGameType))
			return
		end

		-- If already running, stop previous
		if activeModule ~= nil then
			activeModule.stop()
			activeModule = nil
		end

		activeModule = module

		-- Inject shared fields into config
		config.container = containerFrame
		config.instanceId = instanceId

		clearContainer()
		UIManager.open("MiniGame")

		module.start(config, makeOnInput(instanceId))
	end)

	-- MiniGameEnd: stop active module, show result
	;(Remotes["MiniGameEnd"] :: RemoteEvent).OnClientEvent:Connect(function(
		payload: { result: string, xpGained: number, shardGained: number }
	)
		if activeModule ~= nil then
			activeModule.stop()
			activeModule = nil
		end

		local success = payload.result == "Success"
		if success then
			playSound("capture_success")
		else
			playSound("capture_fail")
		end

		showResult(success)

		task.delay(3, function()
			UIManager.close("MiniGame")
		end)
	end)
end

return MiniGameController
