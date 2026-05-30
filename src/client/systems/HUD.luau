--!strict
-- HUD — T-29 (layout & core), T-30 (mini-map), T-31 (SCAN + cold zone highlights)
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local XPTable = require(ReplicatedStorage.Shared.XPTable)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ImageDefs = require(ReplicatedStorage.Shared.ImageDefs)
local LocalizationBridge = require(script.Parent.LocalizationBridge)
local ZoneDetector = require(script.Parent.ZoneDetector)
local UIManager = require(script.Parent.UIManager)

local LocalPlayer = Players.LocalPlayer

-- ─── Colors & constants ───────────────────────────────────────────────────────

local C_BG = Color3.fromRGB(15, 15, 25)
local C_BAR_BG = Color3.fromRGB(40, 40, 55)
local C_XP = Color3.fromRGB(80, 200, 80)
local C_LANTERN = Color3.fromRGB(255, 200, 50)
local C_BUTTON = Color3.fromRGB(50, 60, 80)
local C_BUTTON_DISABLED = Color3.fromRGB(35, 35, 45)
local C_SCAN_ACTIVE = Color3.fromRGB(40, 100, 180)
local C_TEXT = Color3.fromRGB(230, 230, 230)
local C_TEXT_DIM = Color3.fromRGB(130, 130, 150)
local C_DOT_SELF = Color3.fromRGB(255, 255, 255)
local C_DOT_OTHER = Color3.fromRGB(255, 200, 0)
local C_GHOST_TRACE = Color3.fromRGB(100, 220, 220)

local MAP_WORLD_HALF = 300
local MAP_DOT_SIZE = 8
local MAP_TRACE_SIZE = 14
local SCAN_HIGHLIGHT_TIME = 5
local SCAN_HIGHLIGHT_SIZE = Vector3.new(12, 0.5, 12)
local XP_TWEEN_INFO = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- ─── Module state ─────────────────────────────────────────────────────────────

local HUD = {}

local screenGui: ScreenGui
local zoneLabel: TextLabel
local playerCountLabel: TextLabel
local xpFill: Frame
local xpLabel: TextLabel
local bottleSlots: { [string]: TextLabel } = {}
local miniMapFrame: Frame
local scanButton: TextButton
local scanCooldownLabel: TextLabel
local scanOnCooldown = false
local lanternFill: Frame
local lanternLbl: TextLabel

-- Mini-map state
local playerDots: { [number]: Frame } = {}

type TraceEntry = { frame: Frame, spawnedAt: number }
local ghostTraces: { TraceEntry } = {}

-- ─── Helpers ──────────────────────────────────────────────────────────────────

local function newLabel(parent: Instance, name: string, text: string): TextLabel
	local lbl = Instance.new("TextLabel") :: TextLabel
	lbl.Name = name
	lbl.Text = text
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = C_TEXT
	lbl.Font = Enum.Font.GothamMedium
	lbl.TextScaled = true
	lbl.Parent = parent
	return lbl
end

local function newButton(parent: Instance, name: string, text: string): TextButton
	local btn = Instance.new("TextButton") :: TextButton
	btn.Name = name
	btn.Text = text
	btn.BackgroundColor3 = C_BUTTON
	btn.TextColor3 = C_TEXT
	btn.Font = Enum.Font.GothamMedium
	btn.TextScaled = true
	btn.AutoButtonColor = true
	btn.Parent = parent
	return btn
end

-- Adds an icon ImageLabel inside `parent`. Icon fills the top 55% of parent, centered.
-- Returns the ImageLabel so callers can store the reference if needed.
local function addIcon(parent: Instance, imageId: number): ImageLabel
	local img = Instance.new("ImageLabel") :: ImageLabel
	img.Name = "Icon"
	img.AnchorPoint = Vector2.new(0.5, 0)
	img.Size = UDim2.fromScale(0.55, 0.55)
	img.Position = UDim2.fromScale(0.5, 0.04)
	img.Image = "rbxassetid://" .. tostring(imageId)
	img.BackgroundTransparency = 1
	img.ScaleType = Enum.ScaleType.Fit
	img.ZIndex = 2
	img.Parent = parent
	return img
end

local function addPadding(parent: Instance, px: number)
	local pad = Instance.new("UIPadding") :: UIPadding
	pad.PaddingTop = UDim.new(0, px)
	pad.PaddingBottom = UDim.new(0, px)
	pad.PaddingLeft = UDim.new(0, px)
	pad.PaddingRight = UDim.new(0, px)
	pad.Parent = parent
end

local function addCorner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner") :: UICorner
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function worldToMapUV(worldPos: Vector3): (number, number)
	local u = math.clamp((worldPos.X + MAP_WORLD_HALF) / (MAP_WORLD_HALF * 2), 0, 1)
	local v = math.clamp((worldPos.Z + MAP_WORLD_HALF) / (MAP_WORLD_HALF * 2), 0, 1)
	return u, v
end

local function getNextXPThreshold(level: number): number
	local next = XPTable[level + 1]
	return next or XPTable[100] or 999999
end

local function keyHint(parent: Instance, text: string)
	local lbl = newLabel(parent, "KeyHint", text)
	lbl.Size = UDim2.fromScale(1, 0.3)
	lbl.Position = UDim2.fromScale(0, 0.7)
	lbl.TextColor3 = C_TEXT_DIM
	lbl.Font = Enum.Font.Gotham
end

-- ─── T-29 · Top bar ───────────────────────────────────────────────────────────

local function buildTopBar(parent: Frame, isMobile: boolean)
	local topBar = Instance.new("Frame") :: Frame
	topBar.Name = "TopBar"
	topBar.Size = UDim2.new(1, 0, 0, 44)
	topBar.Position = UDim2.fromScale(0, 0)
	topBar.BackgroundColor3 = C_BG
	topBar.BackgroundTransparency = 0.3
	topBar.Parent = parent
	addPadding(topBar, 6)

	-- Lantern bar (left 25%)
	local lanternContainer = Instance.new("Frame") :: Frame
	lanternContainer.Name = "LanternContainer"
	lanternContainer.Size = UDim2.new(0.25, -4, 1, 0)
	lanternContainer.Position = UDim2.fromScale(0, 0)
	lanternContainer.BackgroundColor3 = C_BAR_BG
	lanternContainer.Parent = topBar
	addCorner(lanternContainer, 4)

	lanternFill = Instance.new("Frame") :: Frame
	lanternFill.Name = "LanternFill"
	lanternFill.Size = UDim2.fromScale(1, 1)
	lanternFill.BackgroundColor3 = C_LANTERN
	lanternFill.Parent = lanternContainer
	addCorner(lanternFill, 4)

	-- Lantern icon (left side, sits above fill bar)
	local lanternIcon = Instance.new("ImageLabel") :: ImageLabel
	lanternIcon.Name = "LanternIcon"
	lanternIcon.Size = UDim2.fromScale(0.28, 0.85)
	lanternIcon.AnchorPoint = Vector2.new(0, 0.5)
	lanternIcon.Position = UDim2.fromScale(0.02, 0.5)
	lanternIcon.Image = "rbxassetid://" .. tostring(ImageDefs.ICON_LANTERN)
	lanternIcon.BackgroundTransparency = 1
	lanternIcon.ScaleType = Enum.ScaleType.Fit
	lanternIcon.ZIndex = 3
	lanternIcon.Parent = lanternContainer

	lanternLbl = newLabel(lanternContainer, "LanternLabel", "100%")
	lanternLbl.Size = UDim2.fromScale(0.68, 1)
	lanternLbl.Position = UDim2.fromScale(0.32, 0)
	lanternLbl.TextColor3 = C_BG
	lanternLbl.Font = Enum.Font.GothamBold
	lanternLbl.ZIndex = 2

	_ = lanternIcon

	-- Zone label (center 50%)
	zoneLabel = newLabel(topBar, "ZoneLabel", LocalizationBridge.get("UI_LABEL_ZONE"))
	zoneLabel.Size = UDim2.new(0.5, -8, 1, 0)
	zoneLabel.Position = UDim2.new(0.25, 4, 0, 0)

	-- Player count (right 25%)
	playerCountLabel = newLabel(topBar, "PlayerCount", "")
	playerCountLabel.Size = UDim2.new(0.25, -4, 1, 0)
	playerCountLabel.Position = UDim2.new(0.75, 4, 0, 0)
	playerCountLabel.TextColor3 = C_TEXT_DIM

	local function updatePlayerCount()
		local count = #Players:GetPlayers()
		playerCountLabel.Text = LocalizationBridge.get("UI_PLAYERS_COUNT", { count = count })
	end
	updatePlayerCount()
	Players.PlayerAdded:Connect(function(_: Player)
		updatePlayerCount()
	end)
	Players.PlayerRemoving:Connect(function(_: Player)
		task.defer(updatePlayerCount)
	end)

	_ = isMobile
end

-- ─── T-29 · XP bar ────────────────────────────────────────────────────────────

local function buildXPBar(parent: Frame)
	local xpContainer = Instance.new("Frame") :: Frame
	xpContainer.Name = "XPBarContainer"
	xpContainer.Size = UDim2.new(1, 0, 0, 20)
	xpContainer.Position = UDim2.new(0, 0, 1, -116)
	xpContainer.BackgroundTransparency = 1
	xpContainer.Parent = parent

	local xpBG = Instance.new("Frame") :: Frame
	xpBG.Name = "XPBarBG"
	xpBG.Size = UDim2.fromScale(0.7, 1)
	xpBG.Position = UDim2.fromScale(0.15, 0)
	xpBG.BackgroundColor3 = C_BAR_BG
	xpBG.Parent = xpContainer
	addCorner(xpBG, 4)

	xpFill = Instance.new("Frame") :: Frame
	xpFill.Name = "XPFill"
	xpFill.Size = UDim2.fromScale(0, 1) -- starts empty
	xpFill.BackgroundColor3 = C_XP
	xpFill.Parent = xpBG
	addCorner(xpFill, 4)

	xpLabel = newLabel(xpContainer, "XPLabel", "Level 1")
	xpLabel.Size = UDim2.new(0.15, -4, 1, 0)
	xpLabel.Position = UDim2.fromScale(0, 0)
	xpLabel.TextColor3 = C_TEXT_DIM
	xpLabel.TextXAlignment = Enum.TextXAlignment.Right
end

-- ─── T-29 · Bottle display ────────────────────────────────────────────────────

local BOTTLE_ORDER = { "BotolBiasa", "BotolKacaBiru", "BotolEmas", "BotolKristal", "BotolRetak" }
local BOTTLE_LABELS: { [string]: string } = {
	BotolBiasa = "Biasa",
	BotolKacaBiru = "Kaca",
	BotolEmas = "Emas",
	BotolKristal = "Kristal",
	BotolRetak = "Retak",
}

local BOTTLE_ICONS: { [string]: number } = {
	BotolBiasa    = ImageDefs.ICON_BOTTLE_BIASA,
	BotolKacaBiru = ImageDefs.ICON_BOTTLE_KACABIRU,
	BotolEmas     = ImageDefs.ICON_BOTTLE_EMAS,
	BotolKristal  = ImageDefs.ICON_BOTTLE_KRISTAL,
	BotolRetak    = ImageDefs.ICON_BOTTLE_RETAK,
}

local function buildBottleDisplay(parent: Frame)
	local container = Instance.new("Frame") :: Frame
	container.Name = "BottleDisplay"
	container.Size = UDim2.new(0.45, -4, 1, 0)
	container.Position = UDim2.fromScale(0, 0)
	container.BackgroundTransparency = 1
	container.Parent = parent

	local layout = Instance.new("UIListLayout") :: UIListLayout
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 4)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = container

	for _, bottleId in BOTTLE_ORDER do
		local slot = Instance.new("Frame") :: Frame
		slot.Name = bottleId
		slot.Size = UDim2.fromOffset(50, 50)
		slot.BackgroundColor3 = C_BAR_BG
		slot.Visible = false
		slot.Parent = container
		addCorner(slot, 6)

		-- Bottle icon (top 50%)
		local bottleIcon = addIcon(slot, BOTTLE_ICONS[bottleId])
		bottleIcon.Size = UDim2.fromScale(0.6, 0.5)
		bottleIcon.Position = UDim2.fromScale(0.5, 0.02)

		-- Count label (middle 35%)
		local countLbl = newLabel(slot, "Count", "0x")
		countLbl.Size = UDim2.fromScale(1, 0.35)
		countLbl.Position = UDim2.fromScale(0, 0.52)
		countLbl.Font = Enum.Font.GothamBold
		countLbl.ZIndex = 2

		-- Name label (bottom 18%)
		local nameLbl = newLabel(slot, "Name", BOTTLE_LABELS[bottleId])
		nameLbl.Size = UDim2.fromScale(1, 0.18)
		nameLbl.Position = UDim2.fromScale(0, 0.82)
		nameLbl.TextColor3 = C_TEXT_DIM
		nameLbl.Font = Enum.Font.Gotham
		nameLbl.ZIndex = 2

		bottleSlots[bottleId] = countLbl
		_ = nameLbl
	end

	_ = layout
end

-- ─── T-29 · Bottom bar ────────────────────────────────────────────────────────

local function buildBottomBar(parent: Frame, isMobile: boolean)
	local btnSize = if isMobile then 72 else 60

	local bottomBar = Instance.new("Frame") :: Frame
	bottomBar.Name = "BottomBar"
	bottomBar.Size = UDim2.new(1, 0, 0, 96)
	bottomBar.Position = UDim2.new(0, 0, 1, -96)
	bottomBar.BackgroundColor3 = C_BG
	bottomBar.BackgroundTransparency = 0.3
	bottomBar.Parent = parent
	addPadding(bottomBar, 12)

	buildBottleDisplay(bottomBar)

	local btnRow = Instance.new("Frame") :: Frame
	btnRow.Name = "ButtonRow"
	btnRow.Size = UDim2.new(0.55, -4, 1, 0)
	btnRow.Position = UDim2.new(0.45, 4, 0, 0)
	btnRow.BackgroundTransparency = 1
	btnRow.Parent = bottomBar

	local rowLayout = Instance.new("UIListLayout") :: UIListLayout
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	rowLayout.Padding = UDim.new(0, 8)
	rowLayout.Parent = btnRow

	-- SCAN button
	scanButton = newButton(btnRow, "ScanButton", "")
	scanButton.Size = UDim2.fromOffset(btnSize, btnSize)
	scanButton.BackgroundColor3 = C_SCAN_ACTIVE
	scanButton.TextYAlignment = Enum.TextYAlignment.Bottom
	addCorner(scanButton, 8)
	addIcon(scanButton, ImageDefs.ICON_SCAN)
	local scanLbl = newLabel(scanButton, "Label", LocalizationBridge.get("UI_BUTTON_SCAN"))
	scanLbl.Size = UDim2.fromScale(1, 0.32)
	scanLbl.Position = UDim2.fromScale(0, 0.68)
	scanLbl.Font = Enum.Font.Gotham
	scanLbl.ZIndex = 2
	if not isMobile then
		keyHint(scanButton, "[E]")
	end

	-- Cooldown overlay (hidden initially)
	scanCooldownLabel = newLabel(scanButton, "Cooldown", "")
	scanCooldownLabel.Size = UDim2.fromScale(1, 1)
	scanCooldownLabel.BackgroundColor3 = C_BUTTON_DISABLED
	scanCooldownLabel.BackgroundTransparency = 0.3
	scanCooldownLabel.Font = Enum.Font.GothamBold
	scanCooldownLabel.ZIndex = 3
	scanCooldownLabel.Visible = false
	addCorner(scanCooldownLabel, 8)

	-- Compendium button
	local compBtn = newButton(btnRow, "CompendiumButton", "")
	compBtn.Size = UDim2.fromOffset(btnSize, btnSize)
	addCorner(compBtn, 8)
	addIcon(compBtn, ImageDefs.ICON_COMPENDIUM)
	local compLbl = newLabel(compBtn, "Label", LocalizationBridge.get("UI_BUTTON_COMPENDIUM"))
	compLbl.Size = UDim2.fromScale(1, 0.32)
	compLbl.Position = UDim2.fromScale(0, 0.68)
	compLbl.Font = Enum.Font.Gotham
	compLbl.ZIndex = 2
	if not isMobile then
		keyHint(compBtn, "[F]")
	end
	compBtn.Activated:Connect(function()
		UIManager.open("Compendium")
	end)

	-- Shop button
	local shopBtn = newButton(btnRow, "ShopButton", "")
	shopBtn.Size = UDim2.fromOffset(btnSize, btnSize)
	addCorner(shopBtn, 8)
	addIcon(shopBtn, ImageDefs.ICON_SHOP)
	local shopLbl = newLabel(shopBtn, "Label", LocalizationBridge.get("UI_BUTTON_SHOP"))
	shopLbl.Size = UDim2.fromScale(1, 0.32)
	shopLbl.Position = UDim2.fromScale(0, 0.68)
	shopLbl.Font = Enum.Font.Gotham
	shopLbl.ZIndex = 2
	if not isMobile then
		keyHint(shopBtn, "[G]")
	end
	shopBtn.Activated:Connect(function()
		UIManager.open("Shop")
	end)

	_ = scanLbl
	_ = compLbl
	_ = shopLbl

	_ = rowLayout
end

-- ─── T-30 · Mini-map ──────────────────────────────────────────────────────────

local function buildMiniMap(parent: Frame, isMobile: boolean)
	local mapSize = if isMobile then 120 else 160

	local container = Instance.new("Frame") :: Frame
	container.Name = "MiniMap"
	container.Size = UDim2.fromOffset(mapSize, mapSize)
	container.Position = UDim2.new(1, -(mapSize + 8), 0, 52)
	container.BackgroundColor3 = C_BG
	container.BackgroundTransparency = 0.2
	container.ClipsDescendants = true
	container.Parent = parent
	addCorner(container, 6)

	local mapBG = Instance.new("ImageLabel") :: ImageLabel
	mapBG.Name = "MapBG"
	mapBG.Size = UDim2.fromScale(1, 1)
	mapBG.Image = "rbxassetid://" .. tostring(ImageDefs.ICON_MINIMAP_BG)
	mapBG.BackgroundColor3 = Color3.fromRGB(25, 30, 20)
	mapBG.ImageTransparency = 0.3
	mapBG.Parent = container

	local mapLbl = newLabel(container, "MapLabel", LocalizationBridge.get("UI_MINIMAP_LABEL"))
	mapLbl.Size = UDim2.new(1, 0, 0, 14)
	mapLbl.Position = UDim2.fromScale(0, 0)
	mapLbl.TextColor3 = C_TEXT_DIM
	mapLbl.Font = Enum.Font.Gotham
	mapLbl.ZIndex = 3

	miniMapFrame = container

	-- Self dot
	local selfDot = Instance.new("Frame") :: Frame
	selfDot.Name = "SelfDot"
	selfDot.Size = UDim2.fromOffset(MAP_DOT_SIZE, MAP_DOT_SIZE)
	selfDot.AnchorPoint = Vector2.new(0.5, 0.5)
	selfDot.BackgroundColor3 = C_DOT_SELF
	selfDot.ZIndex = 4
	selfDot.Parent = container
	addCorner(selfDot, MAP_DOT_SIZE)
	playerDots[LocalPlayer.UserId] = selfDot

	_ = mapBG
	_ = mapLbl
end

-- ─── T-30 · Mini-map update loop ─────────────────────────────────────────────

local function startMiniMapLoop()
	task.spawn(function()
		while screenGui and screenGui.Parent ~= nil do
			task.wait(Constants.MINIMAP_UPDATE_RATE)

			-- Update / create player dots
			for _, player in Players:GetPlayers() do
				local char = player.Character
				if char == nil then continue end
				local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
				if hrp == nil then continue end
				local u, v = worldToMapUV(hrp.Position)

				local dot = playerDots[player.UserId]
				if dot == nil then
					dot = Instance.new("Frame") :: Frame
					dot.Size = UDim2.fromOffset(MAP_DOT_SIZE, MAP_DOT_SIZE)
					dot.AnchorPoint = Vector2.new(0.5, 0.5)
					dot.BackgroundColor3 = if player == LocalPlayer then C_DOT_SELF else C_DOT_OTHER
					dot.ZIndex = 4
					addCorner(dot, MAP_DOT_SIZE)
					dot.Parent = miniMapFrame
					playerDots[player.UserId] = dot
				end
				dot.Position = UDim2.fromScale(u, v)
			end

			-- Remove dots for departed players
			for userId, dot in playerDots do
				if Players:GetPlayerByUserId(userId) == nil then
					dot:Destroy()
					playerDots[userId] = nil
				end
			end

			-- Fade out ghost traces
			local now = os.clock()
			local remaining: { TraceEntry } = {}
			for _, trace in ghostTraces do
				local age = now - trace.spawnedAt
				if age >= SCAN_HIGHLIGHT_TIME then
					trace.frame:Destroy()
				else
					trace.frame.BackgroundTransparency = age / SCAN_HIGHLIGHT_TIME
					table.insert(remaining, trace)
				end
			end
			ghostTraces = remaining
		end
	end)
end

-- ─── T-31 · SCAN button ───────────────────────────────────────────────────────

local function startScanCooldown()
	scanOnCooldown = true
	scanButton.BackgroundColor3 = C_BUTTON_DISABLED
	scanCooldownLabel.Visible = true
	scanButton.Active = false

	local remaining = Constants.SCAN_COOLDOWN
	while remaining > 0 do
		scanCooldownLabel.Text = tostring(remaining)
		task.wait(1)
		remaining -= 1
	end

	scanOnCooldown = false
	scanButton.BackgroundColor3 = C_SCAN_ACTIVE
	scanCooldownLabel.Visible = false
	scanButton.Active = true
	scanCooldownLabel.Text = ""
end

local function spawnColdZoneHighlight(worldPos: Vector3)
	local part = Instance.new("Part") :: Part
	part.Name = "ColdZoneHighlight"
	part.Size = SCAN_HIGHLIGHT_SIZE
	part.Position = worldPos
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.Neon
	part.BrickColor = BrickColor.new("Bright blue")
	part.Transparency = 0.55
	part.CastShadow = false
	part.Parent = game:GetService("Workspace")

	-- Mini-map trace
	local u, v = worldToMapUV(worldPos)
	local traceFrame = Instance.new("Frame") :: Frame
	traceFrame.Name = "GhostTrace"
	traceFrame.Size = UDim2.fromOffset(MAP_TRACE_SIZE, MAP_TRACE_SIZE)
	traceFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	traceFrame.Position = UDim2.fromScale(u, v)
	traceFrame.BackgroundColor3 = C_GHOST_TRACE
	traceFrame.ZIndex = 5
	addCorner(traceFrame, MAP_TRACE_SIZE)
	traceFrame.Parent = miniMapFrame

	local traceLbl = newLabel(traceFrame, "Mark", "?")
	traceLbl.Size = UDim2.fromScale(1, 1)
	traceLbl.TextColor3 = Color3.fromRGB(20, 20, 30)
	traceLbl.Font = Enum.Font.GothamBold
	traceLbl.ZIndex = 6

	table.insert(ghostTraces, { frame = traceFrame, spawnedAt = os.clock() })

	task.delay(SCAN_HIGHLIGHT_TIME, function()
		if part and part.Parent ~= nil then
			part:Destroy()
		end
	end)
end

local function wireScanButton()
	scanButton.Activated:Connect(function()
		if scanOnCooldown then
			return
		end
		task.spawn(function()
			task.spawn(startScanCooldown)
			local ok, result = pcall(function()
				return (Remotes["RequestScan"] :: RemoteFunction):InvokeServer()
			end)
			if not ok or result == nil then return end
			local data = result :: { ok: boolean, coldZones: { Vector3 }? }
			if not data.ok or data.coldZones == nil then return end
			for _, pos in data.coldZones do
				spawnColdZoneHighlight(pos)
			end
		end)
	end)
end

-- ─── T-29 · Event handlers ────────────────────────────────────────────────────

local function handleZoneChanged(newZone: string?)
	if newZone == nil then
		zoneLabel.Text = LocalizationBridge.get("UI_LABEL_ZONE")
	else
		zoneLabel.Text = LocalizationBridge.get("ZONE_" .. newZone .. "_NAME")
	end
end

local function handleBottlesUpdated(data: { bottles: { [string]: number } })
	for bottleId, countLbl in bottleSlots do
		local count = data.bottles[bottleId] or 0
		countLbl.Text = tostring(count) .. "x"
		;(countLbl.Parent :: Frame).Visible = count > 0
	end
end

local function handleXPUpdated(data: { xp: number, level: number, gained: number })
	local pct = math.clamp(data.xp / getNextXPThreshold(data.level), 0, 1)
	TweenService:Create(xpFill, XP_TWEEN_INFO, { Size = UDim2.fromScale(pct, 1) }):Play()
	xpLabel.Text = "Lv " .. tostring(data.level)
	_ = data.gained
end

-- ─── Init + UIModule interface ────────────────────────────────────────────────

local function handleLanternUpdated(level: number)
	local pct = math.clamp(level / 100, 0, 1)
	lanternFill.Size = UDim2.fromScale(pct, 1)
	lanternFill.BackgroundColor3 = if pct > 0.3
		then C_LANTERN
		else Color3.fromRGB(200, 80, 50) -- red tint when low
	lanternLbl.Text = tostring(math.floor(level)) .. "%"
end

function HUD.open()
	if screenGui then
		screenGui.Enabled = true
	end
end

function HUD.close()
	-- HUD is always visible; UIManager never closes it (HUD_NAME exempt).
end

HUD.screenGui = nil :: ScreenGui?

function HUD.Init()
	local isMobile = UIManager.platform == "Mobile"

	screenGui = Instance.new("ScreenGui") :: ScreenGui
	screenGui.Name = "HUD"
	screenGui.ResetOnSpawn = false
	screenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

	local root = Instance.new("Frame") :: Frame
	root.Name = "Root"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Parent = screenGui
	addPadding(root, 12)

	buildTopBar(root, isMobile)
	buildXPBar(root)
	buildBottomBar(root, isMobile)
	buildMiniMap(root, isMobile)
	wireScanButton()
	startMiniMapLoop()

	-- Zone label: from ZoneDetector (local, immediate)
	ZoneDetector.ZoneChanged:Connect(function(newZone: string?, _: string?)
		handleZoneChanged(newZone)
	end)

	-- Zone label: from server ZoneChanged remote (server-initiated updates)
	;(Remotes["ZoneChanged"] :: RemoteEvent).OnClientEvent:Connect(function(newZone: string?)
		handleZoneChanged(newZone)
	end)

	-- Bottle inventory updates
	;(Remotes["BottlesUpdated"] :: RemoteEvent).OnClientEvent:Connect(function(data: { bottles: { [string]: number } })
		handleBottlesUpdated(data)
	end)

	-- XP updates
	;(Remotes["XPUpdated"] :: RemoteEvent).OnClientEvent:Connect(function(data: { xp: number, level: number, gained: number })
		handleXPUpdated(data)
	end)

	-- ScanPulseResult: server may push cold zone positions proactively
	;(Remotes["ScanPulseResult"] :: RemoteEvent).OnClientEvent:Connect(function(data: { ok: boolean, coldZones: { Vector3 }? })
		if not data.ok or data.coldZones == nil then return end
		for _, pos in data.coldZones do
			spawnColdZoneHighlight(pos)
		end
	end)

	-- Lantern level updates from LanternManager
	;(Remotes["LanternUpdated"] :: RemoteEvent).OnClientEvent:Connect(function(data: { level: number })
		handleLanternUpdated(data.level)
	end)

	HUD.screenGui = screenGui
	UIManager.register("HUD", HUD)
	UIManager.open("HUD")
end

return HUD
