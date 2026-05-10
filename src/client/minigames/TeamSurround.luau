--!strict
-- TeamSurround — T-40
-- No overlay UI. BillboardGui markers at world-space positions.
-- Config: { positions: {Vector3}, requiredPlayers: number, container: Frame, instanceId: string }
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

-- ─── State ────────────────────────────────────────────────────────────────────

local TeamSurround = {}

local activeConnections: { RBXScriptConnection } = {}
local activeInstances: { Instance } = {}

local fillState: { [number]: boolean } = {}
local markerLabels: { TextLabel } = {}
local statusLabel: TextLabel? = nil

-- ─── Colors ───────────────────────────────────────────────────────────────────

local C_FILLED = Color3.fromRGB(60, 200, 100)
local C_EMPTY = Color3.fromRGB(140, 140, 160)
local C_TEXT = Color3.fromRGB(240, 240, 240)
local C_HUD_BG = Color3.fromRGB(15, 15, 28)

-- ─── Helpers ──────────────────────────────────────────────────────────────────

local function track(inst: Instance)
	table.insert(activeInstances, inst)
end

local function countFilled(): number
	local n = 0
	for _, v in fillState do
		if v then
			n += 1
		end
	end
	return n
end

local function updateStatus(requiredPlayers: number)
	if statusLabel == nil then
		return
	end
	local filled = countFilled()
	if filled >= requiredPlayers then
		(statusLabel :: TextLabel).Text = "Semua posisi terisi!"
		(statusLabel :: TextLabel).TextColor3 = C_FILLED
	else
		(statusLabel :: TextLabel).Text = "Tunggu pemain lain… (" .. tostring(filled) .. "/" .. tostring(requiredPlayers) .. ")"
		(statusLabel :: TextLabel).TextColor3 = C_TEXT
	end
end

local function updateMarkerColor(index: number)
	local lbl = markerLabels[index]
	if lbl == nil then
		return
	end
	lbl.TextColor3 = if fillState[index] then C_FILLED else C_EMPTY
end

-- ─── Marker creation ──────────────────────────────────────────────────────────

local function createMarker(worldPos: Vector3, index: number)
	local part = Instance.new("Part") :: Part
	part.Name = "SurroundMarker" .. tostring(index)
	part.Size = Vector3.new(2, 0.2, 2)
	part.Position = worldPos
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 0.5
	part.BrickColor = BrickColor.new("Medium stone grey")
	part.CastShadow = false
	part.Parent = workspace
	track(part)

	local billboard = Instance.new("BillboardGui") :: BillboardGui
	billboard.Name = "SurroundBillboard"
	billboard.Size = UDim2.fromOffset(80, 80)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part

	local arrow = Instance.new("TextLabel") :: TextLabel
	arrow.Name = "Arrow"
	arrow.Size = UDim2.fromScale(1, 0.5)
	arrow.Position = UDim2.fromScale(0, 0)
	arrow.BackgroundTransparency = 1
	arrow.TextColor3 = C_EMPTY
	arrow.Font = Enum.Font.GothamBold
	arrow.TextScaled = true
	arrow.Text = "▼"
	arrow.Parent = billboard

	local numLbl = Instance.new("TextLabel") :: TextLabel
	numLbl.Name = "Num"
	numLbl.Size = UDim2.fromScale(1, 0.5)
	numLbl.Position = UDim2.fromScale(0, 0.5)
	numLbl.BackgroundTransparency = 1
	numLbl.TextColor3 = C_EMPTY
	numLbl.Font = Enum.Font.GothamMedium
	numLbl.TextScaled = true
	numLbl.Text = tostring(index)
	numLbl.Parent = billboard

	markerLabels[index] = arrow

	_ = numLbl
end

-- ─── HUD ──────────────────────────────────────────────────────────────────────

local function buildHUD(requiredPlayers: number)
	local localPlayer = Players.LocalPlayer
	local playerGui = localPlayer:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui") :: ScreenGui
	gui.Name = "TeamSurroundHUD"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	track(gui)

	local bg = Instance.new("Frame") :: Frame
	bg.Name = "StatusBG"
	bg.Size = UDim2.fromOffset(280, 40)
	bg.Position = UDim2.fromScale(0.5, 0.08)
	bg.AnchorPoint = Vector2.new(0.5, 0)
	bg.BackgroundColor3 = C_HUD_BG
	bg.BackgroundTransparency = 0.2
	bg.Parent = gui

	local corner = Instance.new("UICorner") :: UICorner
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = bg

	local lbl = Instance.new("TextLabel") :: TextLabel
	lbl.Name = "Status"
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = C_TEXT
	lbl.Font = Enum.Font.GothamMedium
	lbl.TextScaled = true
	lbl.Text = "Tunggu pemain lain… (0/" .. tostring(requiredPlayers) .. ")"
	lbl.Parent = bg
	statusLabel = lbl

	_ = corner
	_ = bg
end

-- ─── Fill state updates from server ──────────────────────────────────────────

local function wireFillUpdates(instanceId: string, requiredPlayers: number)
	local conn = (Remotes["GhostStateChanged"] :: RemoteEvent).OnClientEvent:Connect(function(
		payload: { instanceId: string, fillState: { [number]: boolean }? }
	)
		if payload.instanceId ~= instanceId then
			return
		end
		if payload.fillState == nil then
			return
		end
		local newFill = payload.fillState :: { [number]: boolean }
		for i, v in newFill do
			fillState[i] = v
			updateMarkerColor(i)
		end
		updateStatus(requiredPlayers)
	end)
	table.insert(activeConnections, conn)
end

-- ─── Public interface ─────────────────────────────────────────────────────────

function TeamSurround.start(config: { [string]: any }, onInput: ({ [string]: any }) -> any)
	fillState = {}
	markerLabels = {}
	statusLabel = nil

	local positions = config.positions :: { Vector3 }
	local requiredPlayers = (config.requiredPlayers :: number?) or #positions

	for i, pos in positions do
		fillState[i] = false
		createMarker(pos, i)
	end

	buildHUD(requiredPlayers)
	wireFillUpdates(config.instanceId :: string, requiredPlayers)

	_ = onInput
end

function TeamSurround.stop()
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
	fillState = {}
	markerLabels = {}
	statusLabel = nil
end

return TeamSurround
