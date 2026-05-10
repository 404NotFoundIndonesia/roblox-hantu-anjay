--!strict
-- CompendiumUI — T-32
-- 30-slot scrolling compendium grid with filter bar, rotating detail card,
-- and other-player read-only view.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GhostDefs = require(ReplicatedStorage.Shared.GhostDefs)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local LocalizationBridge = require(script.Parent.LocalizationBridge)
local UIManager = require(script.Parent.UIManager)

local LocalPlayer = Players.LocalPlayer

-- ─── Types ────────────────────────────────────────────────────────────────────

type CompendiumEntry = {
	captureCount: number,
	firstCapturedAt: number,
}

type CompendiumData = {
	compendium: { [string]: CompendiumEntry },
	isOwn: boolean,
	username: string?,
}

-- ─── Colors & constants ───────────────────────────────────────────────────────

local C_BG = Color3.fromRGB(12, 12, 22)
local C_PANEL = Color3.fromRGB(20, 20, 35)
local C_SLOT_BG = Color3.fromRGB(28, 28, 45)
local C_SLOT_CAPTURED = Color3.fromRGB(38, 38, 58)
local C_TEXT = Color3.fromRGB(230, 230, 230)
local C_TEXT_DIM = Color3.fromRGB(130, 130, 150)
local C_CLOSE = Color3.fromRGB(160, 50, 50)
local C_FILTER_BG = Color3.fromRGB(30, 30, 50)

local RARITY_COLORS: { [string]: Color3 } = {
	Common = Color3.fromRGB(220, 220, 220),
	Rare = Color3.fromRGB(60, 120, 220),
	Epic = Color3.fromRGB(160, 60, 220),
	Mythic = Color3.fromRGB(255, 180, 0),
}

local SLIDE_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- ─── Module state ─────────────────────────────────────────────────────────────

local CompendiumUI = {}

local screenGui: ScreenGui
local gridFrame: ScrollingFrame
local detailPanel: Frame
local detailNameLabel: TextLabel
local detailLoreLabel: TextLabel
local detailRarityLabel: TextLabel
local detailCountLabel: TextLabel
local detailDateLabel: TextLabel
local detailViewport: ViewportFrame
local bannerLabel: TextLabel

local detailVisible = false
local viewportModel: Model?
local rotationConn: RBXScriptConnection?

local activeData: { [string]: CompendiumEntry } = {}
local filterRarity = "All"
local filterStatus = "All"
local filterZone = "All"
local slotFrames: { [string]: TextButton } = {}

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
	btn.BackgroundColor3 = C_FILTER_BG
	btn.TextColor3 = C_TEXT
	btn.Font = Enum.Font.GothamMedium
	btn.TextScaled = true
	btn.AutoButtonColor = true
	btn.Parent = parent
	return btn
end

local function addCorner(parent: Instance, radius: number)
	local c = Instance.new("UICorner") :: UICorner
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function addPadding(parent: Instance, px: number)
	local p = Instance.new("UIPadding") :: UIPadding
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.Parent = parent
end

local function formatDate(ts: number): string
	local t = os.date("*t", ts) :: any
	return string.format("%02d/%02d/%04d", t.day, t.month, t.year)
end

-- ─── Filter logic ─────────────────────────────────────────────────────────────

local function ghostMatchesFilter(ghostId: string): boolean
	local def = GhostDefs[ghostId]
	if def == nil then
		return false
	end
	local entry = activeData[ghostId]
	local captured = entry ~= nil and entry.captureCount > 0

	if filterRarity ~= "All" and def.rarity ~= filterRarity then
		return false
	end
	if filterStatus == "Captured" and not captured then
		return false
	end
	if filterStatus == "Uncaptured" and captured then
		return false
	end
	if filterZone ~= "All" then
		local hasZone = false
		for _, z in def.affinityZones do
			if z == filterZone then
				hasZone = true
				break
			end
		end
		if not hasZone then
			return false
		end
	end
	return true
end

local function applyFilters()
	for ghostId, frame in slotFrames do
		frame.Visible = ghostMatchesFilter(ghostId)
	end
end

-- ─── Slot management ──────────────────────────────────────────────────────────

local function refreshSlot(ghostId: string)
	local frame = slotFrames[ghostId]
	if frame == nil then
		return
	end
	local def = GhostDefs[ghostId]
	if def == nil then
		return
	end
	local entry = activeData[ghostId]
	local captured = entry ~= nil and entry.captureCount > 0

	frame.BackgroundColor3 = if captured then C_SLOT_CAPTURED else C_SLOT_BG

	local stroke = frame:FindFirstChildOfClass("UIStroke") :: UIStroke?
	if stroke ~= nil then
		stroke.Color = RARITY_COLORS[def.rarity] or C_TEXT
		stroke.Thickness = if captured then 2 else 1
		stroke.Transparency = if captured then 0 else 0.55
	end

	local silhouette = frame:FindFirstChild("Silhouette") :: Frame?
	if silhouette ~= nil then
		silhouette.Visible = not captured
	end

	local countBadge = frame:FindFirstChild("CountBadge") :: TextLabel?
	if countBadge ~= nil then
		if captured and entry ~= nil then
			countBadge.Text = "\xC3\x97" .. tostring(entry.captureCount)
			countBadge.Visible = true
		else
			countBadge.Visible = false
		end
	end
end

-- ─── Detail card ──────────────────────────────────────────────────────────────

local function stopRotation()
	if rotationConn ~= nil then
		rotationConn:Disconnect()
		rotationConn = nil
	end
	if viewportModel ~= nil then
		viewportModel:Destroy()
		viewportModel = nil
	end
end

local function closeDetailCard()
	if not detailVisible then
		return
	end
	detailVisible = false
	local tween = TweenService:Create(detailPanel, SLIDE_INFO, {
		Position = UDim2.fromScale(1.05, 0.05),
	})
	tween:Play()
	tween.Completed:Connect(function()
		detailPanel.Visible = false
		stopRotation()
	end)
end

local function openDetailCard(ghostId: string)
	local def = GhostDefs[ghostId]
	if def == nil then
		return
	end
	local entry = activeData[ghostId]
	local captured = entry ~= nil and entry.captureCount > 0

	detailNameLabel.Text = LocalizationBridge.get(def.nameKey)
	detailRarityLabel.Text = def.rarity
	detailRarityLabel.TextColor3 = RARITY_COLORS[def.rarity] or C_TEXT

	if captured and entry ~= nil then
		detailLoreLabel.Text = LocalizationBridge.get(def.loreKey)
		detailCountLabel.Text = LocalizationBridge.get("UI_COMPENDIUM_CAPTURES", {
			count = entry.captureCount,
		})
		detailDateLabel.Text = LocalizationBridge.get("UI_COMPENDIUM_FIRST_DATE", {
			date = formatDate(entry.firstCapturedAt),
		})
	else
		detailLoreLabel.Text = "???"
		detailCountLabel.Text = LocalizationBridge.get("UI_COMPENDIUM_CAPTURES", { count = 0 })
		detailDateLabel.Text = "\xe2\x80\x94"
	end

	-- Rotate ghost model in ViewportFrame (captured only)
	stopRotation()
	if captured then
		local assetsFolder = ReplicatedStorage:FindFirstChild("Assets") :: Folder?
		local ghostsFolder = if assetsFolder ~= nil
			then assetsFolder:FindFirstChild("Ghosts") :: Folder?
			else nil
		local ghostAsset = if ghostsFolder ~= nil
			then ghostsFolder:FindFirstChild(def.modelName)
			else nil
		if ghostAsset ~= nil then
			local cloned = (ghostAsset :: Model):Clone()
			cloned.Parent = detailViewport
			viewportModel = cloned

			local vpCam = Instance.new("Camera") :: Camera
			vpCam.Parent = detailViewport
			detailViewport.CurrentCamera = vpCam

			local angle = 0
			rotationConn = RunService.Heartbeat:Connect(function(dt: number)
				if viewportModel == nil then
					return
				end
				angle += dt * 45
				local cf = cloned:GetPivot()
				local center = cf.Position
				vpCam.CFrame = CFrame.new(
					center + Vector3.new(math.sin(math.rad(angle)) * 5, 2, math.cos(math.rad(angle)) * 5),
					center
				)
			end)
		end
	end

	-- Slide in from right
	detailPanel.Visible = true
	detailVisible = true
	TweenService:Create(detailPanel, SLIDE_INFO, { Position = UDim2.fromScale(0.55, 0.05) }):Play()
end

-- ─── Build: Filter bar ────────────────────────────────────────────────────────

local function buildFilterBar(parent: Frame)
	local bar = Instance.new("Frame") :: Frame
	bar.Name = "FilterBar"
	bar.Size = UDim2.new(1, 0, 0, 40)
	bar.Position = UDim2.fromScale(0, 0)
	bar.BackgroundColor3 = C_PANEL
	bar.BackgroundTransparency = 0.3
	bar.Parent = parent
	addPadding(bar, 5)

	local layout = Instance.new("UIListLayout") :: UIListLayout
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 8)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = bar

	-- Rarity cycle button
	local rarityOptions = { "All", "Common", "Rare", "Epic", "Mythic" }
	local rarityIdx = 1

	local rarityBtn = newButton(bar, "RarityFilter", "Rarity: All")
	rarityBtn.Size = UDim2.fromScale(0.2, 1)
	addCorner(rarityBtn, 4)
	rarityBtn.Activated:Connect(function()
		rarityIdx = (rarityIdx % #rarityOptions) + 1
		filterRarity = rarityOptions[rarityIdx]
		rarityBtn.Text = "Rarity: " .. filterRarity
		applyFilters()
	end)

	-- Status cycle button
	local statusOptions = { "All", "Captured", "Uncaptured" }
	local statusIdx = 1

	local statusBtn = newButton(bar, "StatusFilter", "Status: All")
	statusBtn.Size = UDim2.fromScale(0.2, 1)
	addCorner(statusBtn, 4)
	statusBtn.Activated:Connect(function()
		statusIdx = (statusIdx % #statusOptions) + 1
		filterStatus = statusOptions[statusIdx]
		statusBtn.Text = "Status: " .. filterStatus
		applyFilters()
	end)

	-- Zone cycle button
	local zoneOptions = {
		"All",
		"Kuburan",
		"KampungTua",
		"HutanBambu",
		"PantaiSepi",
		"KuburanCina",
		"SawahHaunted",
	}
	local zoneIdx = 1

	local zoneBtn = newButton(bar, "ZoneFilter", "Zone: All")
	zoneBtn.Size = UDim2.fromScale(0.22, 1)
	addCorner(zoneBtn, 4)
	zoneBtn.Activated:Connect(function()
		zoneIdx = (zoneIdx % #zoneOptions) + 1
		filterZone = zoneOptions[zoneIdx]
		local displayZone: string
		if filterZone == "All" then
			displayZone = "All"
		else
			displayZone = LocalizationBridge.get("ZONE_" .. filterZone .. "_NAME")
		end
		zoneBtn.Text = "Zone: " .. displayZone
		applyFilters()
	end)

	_ = layout
end

-- ─── Build: Ghost grid ────────────────────────────────────────────────────────

local function buildGrid(parent: Frame)
	local grid = Instance.new("ScrollingFrame") :: ScrollingFrame
	grid.Name = "GhostGrid"
	grid.Size = UDim2.new(1, 0, 1, -44)
	grid.Position = UDim2.fromOffset(0, 44)
	grid.BackgroundColor3 = C_BG
	grid.BackgroundTransparency = 0.1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 6
	grid.CanvasSize = UDim2.fromScale(0, 0)
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.Parent = parent
	addPadding(grid, 8)

	local uigrid = Instance.new("UIGridLayout") :: UIGridLayout
	uigrid.CellSize = UDim2.fromOffset(92, 92)
	uigrid.CellPadding = UDim2.fromOffset(6, 6)
	uigrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	uigrid.Parent = grid

	gridFrame = grid

	-- Collect and sort ghost IDs for consistent ordering
	local ghostOrder: { string } = {}
	for ghostId in GhostDefs do
		table.insert(ghostOrder, ghostId)
	end
	table.sort(ghostOrder)

	for _, ghostId in ghostOrder do
		local def = GhostDefs[ghostId]
		if def == nil then
			continue
		end

		local slot = newButton(grid, ghostId, "")
		slot.BackgroundColor3 = C_SLOT_BG
		slot.AutoButtonColor = false
		addCorner(slot, 6)

		-- Rarity border
		local stroke = Instance.new("UIStroke") :: UIStroke
		stroke.Color = RARITY_COLORS[def.rarity] or C_TEXT
		stroke.Thickness = 1
		stroke.Transparency = 0.55
		stroke.Parent = slot

		-- Ghost name label at bottom
		local nameLabel = newLabel(slot, "GhostName", LocalizationBridge.get(def.nameKey))
		nameLabel.Size = UDim2.new(1, 0, 0, 18)
		nameLabel.Position = UDim2.new(0, 0, 1, -20)
		nameLabel.TextColor3 = C_TEXT_DIM
		nameLabel.Font = Enum.Font.Gotham
		nameLabel.ZIndex = 2

		-- Silhouette overlay for uncaptured slots
		local silhouette = Instance.new("Frame") :: Frame
		silhouette.Name = "Silhouette"
		silhouette.Size = UDim2.fromScale(1, 1)
		silhouette.BackgroundColor3 = Color3.fromRGB(8, 8, 15)
		silhouette.BackgroundTransparency = 0.1
		silhouette.ZIndex = 3
		silhouette.Visible = true
		silhouette.Parent = slot
		addCorner(silhouette, 6)

		local questionLbl = newLabel(silhouette, "Question", "?")
		questionLbl.Size = UDim2.fromScale(1, 0.65)
		questionLbl.Position = UDim2.fromScale(0, 0.12)
		questionLbl.TextColor3 = Color3.fromRGB(55, 55, 75)
		questionLbl.Font = Enum.Font.GothamBold
		questionLbl.ZIndex = 4

		-- Capture count badge (top-right corner)
		local countBadge = newLabel(slot, "CountBadge", "")
		countBadge.Size = UDim2.fromOffset(34, 18)
		countBadge.Position = UDim2.new(1, -36, 0, 3)
		countBadge.TextColor3 = Color3.fromRGB(255, 210, 80)
		countBadge.Font = Enum.Font.GothamBold
		countBadge.ZIndex = 5
		countBadge.Visible = false

		slotFrames[ghostId] = slot

		local capturedGhostId = ghostId
		slot.Activated:Connect(function()
			openDetailCard(capturedGhostId)
		end)

		_ = nameLabel
		_ = questionLbl
		_ = countBadge
		_ = stroke
	end

	_ = uigrid
end

-- ─── Build: Detail panel ──────────────────────────────────────────────────────

local function buildDetailPanel(parent: Frame)
	local panel = Instance.new("Frame") :: Frame
	panel.Name = "DetailPanel"
	panel.Size = UDim2.fromScale(0.42, 0.9)
	panel.Position = UDim2.fromScale(1.05, 0.05)
	panel.AnchorPoint = Vector2.new(0, 0)
	panel.BackgroundColor3 = Color3.fromRGB(16, 16, 28)
	panel.ZIndex = 10
	panel.Visible = false
	panel.Parent = parent
	addCorner(panel, 10)
	addPadding(panel, 10)

	-- Close button
	local closeBtn = Instance.new("TextButton") :: TextButton
	closeBtn.Name = "CloseBtn"
	closeBtn.Text = "\xe2\x9c\x95"
	closeBtn.Size = UDim2.fromOffset(30, 30)
	closeBtn.Position = UDim2.new(1, -34, 0, 4)
	closeBtn.BackgroundColor3 = C_CLOSE
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextScaled = true
	closeBtn.AutoButtonColor = true
	closeBtn.ZIndex = 12
	closeBtn.Parent = panel
	addCorner(closeBtn, 6)
	closeBtn.Activated:Connect(function()
		closeDetailCard()
	end)

	-- ViewportFrame for rotating ghost model
	local vp = Instance.new("ViewportFrame") :: ViewportFrame
	vp.Name = "GhostViewport"
	vp.Size = UDim2.new(1, 0, 0, 150)
	vp.Position = UDim2.fromScale(0, 0)
	vp.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
	vp.ZIndex = 11
	vp.Parent = panel
	addCorner(vp, 8)
	detailViewport = vp

	-- Ghost name
	local nameLabel = newLabel(panel, "GhostName", "")
	nameLabel.Size = UDim2.new(1, 0, 0, 28)
	nameLabel.Position = UDim2.fromOffset(0, 158)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.ZIndex = 11
	detailNameLabel = nameLabel

	-- Rarity badge
	local rarityLabel = newLabel(panel, "RarityBadge", "")
	rarityLabel.Size = UDim2.new(1, 0, 0, 20)
	rarityLabel.Position = UDim2.fromOffset(0, 190)
	rarityLabel.Font = Enum.Font.Gotham
	rarityLabel.ZIndex = 11
	detailRarityLabel = rarityLabel

	-- Lore text (multi-line)
	local loreLabel = newLabel(panel, "LoreText", "")
	loreLabel.Size = UDim2.new(1, 0, 0, 90)
	loreLabel.Position = UDim2.fromOffset(0, 214)
	loreLabel.TextColor3 = C_TEXT_DIM
	loreLabel.Font = Enum.Font.Gotham
	loreLabel.TextScaled = false
	loreLabel.TextSize = 13
	loreLabel.TextWrapped = true
	loreLabel.TextXAlignment = Enum.TextXAlignment.Left
	loreLabel.TextYAlignment = Enum.TextYAlignment.Top
	loreLabel.ZIndex = 11
	detailLoreLabel = loreLabel

	-- Capture count
	local countLabel = newLabel(panel, "CaptureCount", "")
	countLabel.Size = UDim2.new(1, 0, 0, 22)
	countLabel.Position = UDim2.fromOffset(0, 310)
	countLabel.TextColor3 = Color3.fromRGB(255, 210, 80)
	countLabel.ZIndex = 11
	detailCountLabel = countLabel

	-- First captured date
	local dateLabel = newLabel(panel, "FirstDate", "")
	dateLabel.Size = UDim2.new(1, 0, 0, 22)
	dateLabel.Position = UDim2.fromOffset(0, 336)
	dateLabel.TextColor3 = C_TEXT_DIM
	dateLabel.Font = Enum.Font.Gotham
	dateLabel.ZIndex = 11
	detailDateLabel = dateLabel

	detailPanel = panel
end

-- ─── Build: Full screen ───────────────────────────────────────────────────────

local function buildScreen()
	screenGui = Instance.new("ScreenGui") :: ScreenGui
	screenGui.Name = "CompendiumUI"
	screenGui.ResetOnSpawn = false
	screenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Enabled = false
	screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

	local root = Instance.new("Frame") :: Frame
	root.Name = "Root"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = C_BG
	root.BackgroundTransparency = 0.05
	root.Parent = screenGui
	addPadding(root, 12)

	-- Top bar
	local topBar = Instance.new("Frame") :: Frame
	topBar.Name = "TopBar"
	topBar.Size = UDim2.new(1, 0, 0, 44)
	topBar.Position = UDim2.fromScale(0, 0)
	topBar.BackgroundColor3 = Color3.fromRGB(15, 15, 28)
	topBar.BackgroundTransparency = 0.15
	topBar.Parent = root

	bannerLabel = newLabel(topBar, "BannerLabel", LocalizationBridge.get("UI_COMPENDIUM_TITLE"))
	bannerLabel.Size = UDim2.fromScale(0.75, 1)
	bannerLabel.Position = UDim2.fromScale(0.1, 0)
	bannerLabel.Font = Enum.Font.GothamBold

	local closeBtn = newButton(topBar, "CloseBtn", LocalizationBridge.get("UI_BUTTON_CLOSE"))
	closeBtn.Size = UDim2.fromOffset(80, 32)
	closeBtn.Position = UDim2.new(1, -84, 0.5, -16)
	closeBtn.BackgroundColor3 = C_CLOSE
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	addCorner(closeBtn, 6)
	closeBtn.Activated:Connect(function()
		UIManager.close("Compendium")
	end)

	-- Content area below top bar
	local content = Instance.new("Frame") :: Frame
	content.Name = "Content"
	content.Size = UDim2.new(1, 0, 1, -48)
	content.Position = UDim2.fromOffset(0, 48)
	content.BackgroundTransparency = 1
	content.Parent = root

	buildFilterBar(content)
	buildGrid(content)
	-- Detail panel overlays root so it appears above everything
	buildDetailPanel(root)

	CompendiumUI.screenGui = screenGui
end

-- ─── Data loading ─────────────────────────────────────────────────────────────

local function loadAndDisplay(targetUserId: number?)
	local ok, result = pcall(function()
		return (Remotes["RequestViewCompendium"] :: RemoteFunction):InvokeServer(targetUserId)
	end)
	if not ok or result == nil then
		return
	end
	local data = result :: CompendiumData

	if data.isOwn then
		bannerLabel.Text = LocalizationBridge.get("UI_COMPENDIUM_TITLE")
	else
		bannerLabel.Text = LocalizationBridge.get("UI_COMPENDIUM_OTHER", {
			name = data.username or "?",
		})
	end

	activeData = data.compendium
	for ghostId in slotFrames do
		refreshSlot(ghostId)
	end
	applyFilters()
end

-- ─── UIModule interface ───────────────────────────────────────────────────────

function CompendiumUI.open()
	if screenGui == nil then
		return
	end
	screenGui.Enabled = true
	closeDetailCard()
	filterRarity = "All"
	filterStatus = "All"
	filterZone = "All"
	task.spawn(function()
		loadAndDisplay(nil)
	end)
end

function CompendiumUI.close()
	if screenGui == nil then
		return
	end
	closeDetailCard()
	screenGui.Enabled = false
end

-- Opens the compendium showing another player's data (read-only view).
function CompendiumUI.openForPlayer(userId: number)
	UIManager.open("Compendium")
	task.spawn(function()
		loadAndDisplay(userId)
	end)
end

CompendiumUI.screenGui = nil :: ScreenGui?

function CompendiumUI.Init()
	buildScreen()
	UIManager.register("Compendium", CompendiumUI)

	-- Real-time slot update when a ghost is captured
	;(Remotes["CompendiumUpdated"] :: RemoteEvent).OnClientEvent:Connect(function(
		ghostId: string,
		entry: CompendiumEntry
	)
		activeData[ghostId] = entry
		refreshSlot(ghostId)
		applyFilters()
	end)

	_ = gridFrame
end

return CompendiumUI
