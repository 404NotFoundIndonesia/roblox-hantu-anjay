--!strict
-- ShopUI — T-33
-- 4-tab shop: Bottles (shards), Cosmetics (Robux), Battle Pass, Boosts.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ImageDefs = require(ReplicatedStorage.Shared.ImageDefs)
local LocalizationBridge = require(script.Parent.LocalizationBridge)
local UIManager = require(script.Parent.UIManager)

local LocalPlayer = Players.LocalPlayer

-- ─── Colors ───────────────────────────────────────────────────────────────────

local C_BG = Color3.fromRGB(12, 12, 22)
local C_PANEL = Color3.fromRGB(20, 20, 35)
local C_TAB_ACTIVE = Color3.fromRGB(50, 80, 140)
local C_TAB_IDLE = Color3.fromRGB(28, 28, 45)
local C_BUTTON = Color3.fromRGB(45, 90, 160)
local C_BUTTON_DISABLED = Color3.fromRGB(35, 35, 50)
local C_FREE = Color3.fromRGB(40, 120, 60)
local C_TEXT = Color3.fromRGB(230, 230, 230)
local C_TEXT_DIM = Color3.fromRGB(130, 130, 150)
local C_SHARD = Color3.fromRGB(100, 200, 255)
local C_ERROR = Color3.fromRGB(200, 60, 60)
local C_CLOSE = Color3.fromRGB(160, 50, 50)

-- ─── Module state ─────────────────────────────────────────────────────────────

local ShopUI = {}

local screenGui: ScreenGui
local tabContents: { [string]: Frame } = {}
local tabButtons: { [string]: TextButton } = {}
local activeTab = "Bottles"
local errorLabel: TextLabel
local shardBalanceLabel: TextLabel
local currentShards = 0

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

local function addIcon(parent: Instance, imageId: number): ImageLabel
	local img = Instance.new("ImageLabel") :: ImageLabel
	img.Name = "Icon"
	img.AnchorPoint = Vector2.new(0, 0.5)
	img.Size = UDim2.fromScale(0.9, 0.7)
	img.Position = UDim2.fromScale(0.05, 0.5)
	img.Image = "rbxassetid://" .. tostring(imageId)
	img.BackgroundTransparency = 1
	img.ScaleType = Enum.ScaleType.Fit
	img.ZIndex = 2
	img.Parent = parent
	return img
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

local function showError(msg: string)
	if errorLabel == nil then
		return
	end
	errorLabel.Text = msg
	errorLabel.Visible = true
	task.delay(3, function()
		if errorLabel ~= nil and errorLabel.Text == msg then
			errorLabel.Visible = false
		end
	end)
end

local function switchTab(name: string)
	activeTab = name
	for tabName, frame in tabContents do
		frame.Visible = tabName == name
	end
	for tabName, btn in tabButtons do
		btn.BackgroundColor3 = if tabName == name then C_TAB_ACTIVE else C_TAB_IDLE
	end
end

-- ─── Card builder (shared layout) ─────────────────────────────────────────────

local function buildItemCard(
	parent: Frame,
	name: string,
	priceText: string,
	priceColor: Color3,
	btnText: string,
	btnColor: Color3,
	onBuy: () -> ()
): Frame
	local card = Instance.new("Frame") :: Frame
	card.Name = name
	card.Size = UDim2.new(1, 0, 0, 90)
	card.BackgroundColor3 = C_PANEL
	card.BackgroundTransparency = 0.2
	card.Parent = parent
	addCorner(card, 8)
	addPadding(card, 10)

	local itemLabel = newLabel(card, "ItemName", name)
	itemLabel.Size = UDim2.fromScale(0.55, 0.5)
	itemLabel.Position = UDim2.fromScale(0, 0)
	itemLabel.TextXAlignment = Enum.TextXAlignment.Left

	local priceLabel = newLabel(card, "Price", priceText)
	priceLabel.Size = UDim2.fromScale(0.55, 0.45)
	priceLabel.Position = UDim2.fromScale(0, 0.52)
	priceLabel.TextColor3 = priceColor
	priceLabel.Font = Enum.Font.GothamBold
	priceLabel.TextXAlignment = Enum.TextXAlignment.Left

	local btn = newButton(card, "BuyBtn", btnText)
	btn.Size = UDim2.fromScale(0.38, 1)
	btn.Position = UDim2.fromScale(0.62, 0)
	btn.BackgroundColor3 = btnColor
	addCorner(btn, 6)
	btn.Activated:Connect(function()
		onBuy()
	end)

	_ = itemLabel
	_ = priceLabel
	_ = btn

	return card
end

-- ─── Tab: Bottles ─────────────────────────────────────────────────────────────

local BOTTLE_DEFS: { { id: string, cost: number, qty: number } } = {
	{ id = "BotolKacaBiru", cost = 50, qty = 1 },
	{ id = "BotolKacaBiru", cost = 240, qty = 5 },
	{ id = "BotolEmas", cost = 120, qty = 1 },
	{ id = "BotolEmas", cost = 575, qty = 5 },
}

local function requestBuyBottle(bottleId: string, qty: number)
	local ok, result = pcall(function()
		return (Remotes["RequestBuyBottle"] :: RemoteFunction):InvokeServer({
			bottleId = bottleId,
			quantity = qty,
		})
	end)
	if not ok then
		showError(LocalizationBridge.get("UI_SHOP_ERROR_GENERIC"))
		return
	end
	local data = result :: { ok: boolean, error: string? }
	if data == nil or not data.ok then
		local errKey = data and data.error or "GENERIC"
		if errKey == "INSUFFICIENT_SHARDS" then
			showError(LocalizationBridge.get("UI_SHOP_ERROR_SHARDS"))
		elseif errKey == "FULL" then
			showError(LocalizationBridge.get("UI_SHOP_ERROR_FULL"))
		else
			showError(LocalizationBridge.get("UI_SHOP_ERROR_GENERIC"))
		end
	end
end

local function buildBottlesTab(parent: Frame)
	local scroll = Instance.new("ScrollingFrame") :: ScrollingFrame
	scroll.Name = "BottlesScroll"
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.fromScale(0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = parent
	addPadding(scroll, 8)

	local layout = Instance.new("UIListLayout") :: UIListLayout
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	-- Purchasable bottles
	for i, def in BOTTLE_DEFS do
		local label = LocalizationBridge.get("BOTTLE_" .. def.id .. "_NAME")
		local qtyStr = if def.qty > 1 then " ×" .. tostring(def.qty) else ""
		local priceStr = tostring(def.cost) .. " " .. LocalizationBridge.get("UI_SHARDS_LABEL")
		local card = buildItemCard(
			scroll,
			label .. qtyStr,
			priceStr,
			C_SHARD,
			LocalizationBridge.get("UI_BUTTON_BUY"),
			C_BUTTON,
			function()
				requestBuyBottle(def.id, def.qty)
			end
		)
		card.LayoutOrder = i
	end

	-- BotolRetak — free daily login bottle (no buy button)
	local freeLabel = LocalizationBridge.get("BOTTLE_BotolRetak_NAME")
	local freeCard = Instance.new("Frame") :: Frame
	freeCard.Name = freeLabel
	freeCard.Size = UDim2.new(1, 0, 0, 90)
	freeCard.BackgroundColor3 = C_PANEL
	freeCard.BackgroundTransparency = 0.2
	freeCard.LayoutOrder = #BOTTLE_DEFS + 1
	freeCard.Parent = scroll
	addCorner(freeCard, 8)
	addPadding(freeCard, 10)

	local freeName = newLabel(freeCard, "ItemName", freeLabel)
	freeName.Size = UDim2.fromScale(0.55, 0.5)
	freeName.Position = UDim2.fromScale(0, 0)
	freeName.TextXAlignment = Enum.TextXAlignment.Left

	local freePriceLbl = newLabel(freeCard, "Price", LocalizationBridge.get("UI_SHOP_FREE_DAILY"))
	freePriceLbl.Size = UDim2.fromScale(0.55, 0.45)
	freePriceLbl.Position = UDim2.fromScale(0, 0.52)
	freePriceLbl.TextColor3 = C_FREE
	freePriceLbl.Font = Enum.Font.GothamBold
	freePriceLbl.TextXAlignment = Enum.TextXAlignment.Left

	local freeTag = newButton(freeCard, "FreeTag", LocalizationBridge.get("UI_SHOP_FREE_DAILY"))
	freeTag.Size = UDim2.fromScale(0.38, 1)
	freeTag.Position = UDim2.fromScale(0.62, 0)
	freeTag.BackgroundColor3 = C_BUTTON_DISABLED
	freeTag.AutoButtonColor = false
	addCorner(freeTag, 6)

	_ = layout
	_ = freeName
	_ = freePriceLbl
	_ = freeTag
end

-- ─── Tab: Cosmetics ───────────────────────────────────────────────────────────

local COSMETIC_DEFS: { { nameKey: string, gamepassId: number } } = {
	{ nameKey = "SHOP_GAMEPASS_VIP", gamepassId = Constants.GAMEPASS_ID_VIP },
	{ nameKey = "SHOP_GAMEPASS_BOTTLE", gamepassId = Constants.GAMEPASS_ID_BOTTLE },
	{ nameKey = "SHOP_GAMEPASS_AUTOSHARD", gamepassId = Constants.GAMEPASS_ID_AUTOSHARD },
}

local function buildCosmeticsTab(parent: Frame)
	local scroll = Instance.new("ScrollingFrame") :: ScrollingFrame
	scroll.Name = "CosmeticsScroll"
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.fromScale(0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = parent
	addPadding(scroll, 8)

	local layout = Instance.new("UIListLayout") :: UIListLayout
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	for i, def in COSMETIC_DEFS do
		local gpId = def.gamepassId
		local card = buildItemCard(
			scroll,
			LocalizationBridge.get(def.nameKey),
			LocalizationBridge.get("UI_SHOP_ROBUX_PRICE"),
			Color3.fromRGB(0, 176, 111),
			LocalizationBridge.get("UI_BUTTON_BUY"),
			Color3.fromRGB(0, 140, 90),
			function()
				MarketplaceService:PromptGamePassPurchase(LocalPlayer, gpId)
			end
		)
		card.LayoutOrder = i
	end

	_ = layout
end

-- ─── Tab: Battle Pass ─────────────────────────────────────────────────────────

local function buildBattlePassTab(parent: Frame)
	local scroll = Instance.new("ScrollingFrame") :: ScrollingFrame
	scroll.Name = "BPScroll"
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.fromScale(0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = parent
	addPadding(scroll, 12)

	local titleLbl = newLabel(scroll, "Title", LocalizationBridge.get("UI_SHOP_BP_TITLE"))
	titleLbl.Size = UDim2.new(1, 0, 0, 36)
	titleLbl.Font = Enum.Font.GothamBold

	local layout = Instance.new("UIListLayout") :: UIListLayout
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	-- 30 tier progress rows (v1 hardcoded placeholders)
	for tier = 1, 30 do
		local row = Instance.new("Frame") :: Frame
		row.Name = "Tier" .. tostring(tier)
		row.Size = UDim2.new(1, 0, 0, 44)
		row.BackgroundColor3 = C_PANEL
		row.BackgroundTransparency = 0.3
		row.LayoutOrder = tier
		row.Parent = scroll
		addCorner(row, 6)
		addPadding(row, 6)

		local tierLbl = newLabel(row, "TierLabel", LocalizationBridge.get("UI_SHOP_BP_TIER", { tier = tier }))
		tierLbl.Size = UDim2.fromScale(0.15, 1)
		tierLbl.Position = UDim2.fromScale(0, 0)
		tierLbl.TextColor3 = C_TEXT_DIM

		local rewardLbl = newLabel(row, "Reward", LocalizationBridge.get("UI_SHOP_BP_REWARD_PLACEHOLDER"))
		rewardLbl.Size = UDim2.fromScale(0.8, 1)
		rewardLbl.Position = UDim2.fromScale(0.18, 0)
		rewardLbl.TextXAlignment = Enum.TextXAlignment.Left
		rewardLbl.TextColor3 = C_TEXT_DIM
		rewardLbl.Font = Enum.Font.Gotham

		_ = tierLbl
		_ = rewardLbl
	end

	_ = titleLbl
	_ = layout
end

-- ─── Tab: Boosts ──────────────────────────────────────────────────────────────

local BOOST_PRODUCT_ID = Constants.PRODUCT_ID_SHARDS_100

local function buildBoostsTab(parent: Frame)
	local scroll = Instance.new("ScrollingFrame") :: ScrollingFrame
	scroll.Name = "BoostsScroll"
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.fromScale(0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = parent
	addPadding(scroll, 8)

	local layout = Instance.new("UIListLayout") :: UIListLayout
	layout.Padding = UDim.new(0, 8)
	layout.Parent = scroll

	-- XP Boost (Robux via Developer Product)
	local xpCard = buildItemCard(
		scroll,
		LocalizationBridge.get("SHOP_BOOST_XP_NAME"),
		LocalizationBridge.get("UI_SHOP_ROBUX_PRICE"),
		Color3.fromRGB(0, 176, 111),
		LocalizationBridge.get("UI_BUTTON_BUY"),
		Color3.fromRGB(0, 140, 90),
		function()
			MarketplaceService:PromptProductPurchase(LocalPlayer, BOOST_PRODUCT_ID)
		end
	)
	xpCard.LayoutOrder = 1

	-- Shard packs
	local shardPacks: { { label: string, productId: number } } = {
		{
			label = LocalizationBridge.get("SHOP_SHARDS_100"),
			productId = Constants.PRODUCT_ID_SHARDS_100,
		},
		{
			label = LocalizationBridge.get("SHOP_SHARDS_500"),
			productId = Constants.PRODUCT_ID_SHARDS_500,
		},
		{
			label = LocalizationBridge.get("SHOP_SHARDS_1500"),
			productId = Constants.PRODUCT_ID_SHARDS_1500,
		},
	}

	for i, pack in shardPacks do
		local packId = pack.productId
		local card = buildItemCard(
			scroll,
			pack.label,
			LocalizationBridge.get("UI_SHOP_ROBUX_PRICE"),
			Color3.fromRGB(0, 176, 111),
			LocalizationBridge.get("UI_BUTTON_BUY"),
			Color3.fromRGB(0, 140, 90),
			function()
				MarketplaceService:PromptProductPurchase(LocalPlayer, packId)
			end
		)
		card.LayoutOrder = i + 1
	end

	_ = layout
end

-- ─── Screen building ──────────────────────────────────────────────────────────

local function buildScreen()
	screenGui = Instance.new("ScreenGui") :: ScreenGui
	screenGui.Name = "ShopUI"
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

	-- Optional panel background decal (set ImageDefs.DECAL_PANEL_BG to show a texture)
	local panelBG = Instance.new("ImageLabel") :: ImageLabel
	panelBG.Name = "PanelBG"
	panelBG.Size = UDim2.fromScale(1, 1)
	panelBG.Image = "rbxassetid://" .. tostring(ImageDefs.DECAL_PANEL_BG)
	panelBG.BackgroundTransparency = 1
	panelBG.ImageTransparency = 0.85
	panelBG.ScaleType = Enum.ScaleType.Tile
	panelBG.TileSize = UDim2.fromOffset(128, 128)
	panelBG.ZIndex = 0
	panelBG.Parent = root
	_ = panelBG

	-- Top bar
	local topBar = Instance.new("Frame") :: Frame
	topBar.Name = "TopBar"
	topBar.Size = UDim2.new(1, 0, 0, 44)
	topBar.Position = UDim2.fromScale(0, 0)
	topBar.BackgroundColor3 = Color3.fromRGB(15, 15, 28)
	topBar.BackgroundTransparency = 0.15
	topBar.Parent = root

	local titleLbl = newLabel(topBar, "Title", LocalizationBridge.get("UI_SHOP_TITLE"))
	titleLbl.Size = UDim2.fromScale(0.5, 1)
	titleLbl.Position = UDim2.fromScale(0.05, 0)
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left

	-- Shard balance display (icon + label)
	local shardIcon = Instance.new("ImageLabel") :: ImageLabel
	shardIcon.Name = "ShardIcon"
	shardIcon.Size = UDim2.new(0, 20, 1, -8)
	shardIcon.AnchorPoint = Vector2.new(0, 0.5)
	shardIcon.Position = UDim2.new(0.55, 2, 0.5, 0)
	shardIcon.Image = "rbxassetid://" .. tostring(ImageDefs.ICON_SHARD)
	shardIcon.BackgroundTransparency = 1
	shardIcon.ScaleType = Enum.ScaleType.Fit
	shardIcon.ZIndex = 2
	shardIcon.Parent = topBar

	shardBalanceLabel = newLabel(topBar, "ShardBalance", "0 " .. LocalizationBridge.get("UI_SHARDS_LABEL"))
	shardBalanceLabel.Size = UDim2.fromScale(0.22, 1)
	shardBalanceLabel.Position = UDim2.new(0.57, 22, 0, 0)
	shardBalanceLabel.TextColor3 = C_SHARD
	shardBalanceLabel.Font = Enum.Font.GothamBold
	shardBalanceLabel.TextXAlignment = Enum.TextXAlignment.Left
	_ = shardIcon

	local closeBtn = newButton(topBar, "CloseBtn", LocalizationBridge.get("UI_BUTTON_CLOSE"))
	closeBtn.Size = UDim2.fromOffset(80, 32)
	closeBtn.Position = UDim2.new(1, -84, 0.5, -16)
	closeBtn.BackgroundColor3 = C_CLOSE
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	addCorner(closeBtn, 6)
	closeBtn.Activated:Connect(function()
		UIManager.close("Shop")
	end)

	-- Tab bar
	local tabBar = Instance.new("Frame") :: Frame
	tabBar.Name = "TabBar"
	tabBar.Size = UDim2.new(1, 0, 0, 40)
	tabBar.Position = UDim2.fromOffset(0, 48)
	tabBar.BackgroundColor3 = C_PANEL
	tabBar.BackgroundTransparency = 0.2
	tabBar.Parent = root

	local tabLayout = Instance.new("UIListLayout") :: UIListLayout
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabBar

	local TAB_NAMES = { "Bottles", "Cosmetics", "BattlePass", "Boosts" }
	local TAB_KEYS = {
		Bottles = "UI_SHOP_TAB_BOTTLES",
		Cosmetics = "UI_SHOP_TAB_COSMETICS",
		BattlePass = "UI_SHOP_TAB_BATTLEPASS",
		Boosts = "UI_SHOP_TAB_BOOSTS",
	}
	local TAB_ICONS = {
		Bottles    = ImageDefs.ICON_TAB_BOTTLES,
		Cosmetics  = ImageDefs.ICON_TAB_COSMETICS,
		BattlePass = ImageDefs.ICON_TAB_BATTLEPASS,
		Boosts     = ImageDefs.ICON_TAB_BOOSTS,
	}

	for i, tabName in TAB_NAMES do
		local capturedTab = tabName
		local btn = newButton(tabBar, tabName .. "Tab", "")
		btn.Size = UDim2.fromScale(0.25, 1)
		btn.BackgroundColor3 = if tabName == activeTab then C_TAB_ACTIVE else C_TAB_IDLE
		btn.AutoButtonColor = false
		btn.LayoutOrder = i
		addCorner(btn, 0)

		local tabIcon = addIcon(btn, TAB_ICONS[tabName])
		tabIcon.Size = UDim2.fromScale(0.35, 0.75)
		tabIcon.AnchorPoint = Vector2.new(0, 0.5)
		tabIcon.Position = UDim2.fromScale(0.04, 0.5)

		local tabLbl = newLabel(btn, "TabLabel", LocalizationBridge.get(TAB_KEYS[tabName]))
		tabLbl.Size = UDim2.fromScale(0.6, 1)
		tabLbl.Position = UDim2.fromScale(0.38, 0)
		tabLbl.TextXAlignment = Enum.TextXAlignment.Left
		tabLbl.ZIndex = 2

		btn.Activated:Connect(function()
			switchTab(capturedTab)
		end)
		tabButtons[tabName] = btn
		_ = tabIcon
		_ = tabLbl
	end

	-- Content area
	local content = Instance.new("Frame") :: Frame
	content.Name = "Content"
	content.Size = UDim2.new(1, 0, 1, -92)
	content.Position = UDim2.fromOffset(0, 92)
	content.BackgroundTransparency = 1
	content.Parent = root

	-- Build all 4 tab frames
	local TAB_BUILDERS: { [string]: (Frame) -> () } = {
		Bottles = buildBottlesTab,
		Cosmetics = buildCosmeticsTab,
		BattlePass = buildBattlePassTab,
		Boosts = buildBoostsTab,
	}

	for _, tabName in TAB_NAMES do
		local tabFrame = Instance.new("Frame") :: Frame
		tabFrame.Name = tabName .. "Content"
		tabFrame.Size = UDim2.fromScale(1, 1)
		tabFrame.BackgroundTransparency = 1
		tabFrame.Visible = tabName == activeTab
		tabFrame.Parent = content
		tabContents[tabName] = tabFrame
		TAB_BUILDERS[tabName](tabFrame)
	end

	-- Error label (bottom overlay)
	errorLabel = newLabel(root, "ErrorLabel", "")
	errorLabel.Size = UDim2.new(1, 0, 0, 30)
	errorLabel.Position = UDim2.new(0, 0, 1, -44)
	errorLabel.TextColor3 = C_ERROR
	errorLabel.Font = Enum.Font.GothamBold
	errorLabel.ZIndex = 5
	errorLabel.Visible = false

	_ = titleLbl
	_ = tabLayout
	_ = TAB_KEYS

	ShopUI.screenGui = screenGui
end

-- ─── UIModule interface ───────────────────────────────────────────────────────

function ShopUI.open()
	if screenGui == nil then
		return
	end
	screenGui.Enabled = true
	switchTab("Bottles")
end

function ShopUI.close()
	if screenGui == nil then
		return
	end
	screenGui.Enabled = false
end

ShopUI.screenGui = nil :: ScreenGui?

function ShopUI.Init()
	buildScreen()
	UIManager.register("Shop", ShopUI)

	-- Keep shard balance label up to date
	;(Remotes["ShardsUpdated"] :: RemoteEvent).OnClientEvent:Connect(function(data: { shards: number })
		currentShards = data.shards
		shardBalanceLabel.Text = tostring(currentShards) .. " " .. LocalizationBridge.get("UI_SHARDS_LABEL")
	end)
end

return ShopUI
