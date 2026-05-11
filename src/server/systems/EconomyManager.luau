--!strict
-- EconomyManager — T-22 (shards), T-23 (Robux/gamepasses), T-24 (bottle shop)
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerDataManager = require(ServerScriptService.Server.systems.PlayerDataManager)

-- ─── T-22 · Shard operations ──────────────────────────────────────────────────

local EconomyManager = {}

-- Returns current shard balance without modifying data.
function EconomyManager.GetShards(player: Player): number
	local data = PlayerDataManager.GetData(player)
	if data == nil then
		return 0
	end
	return data.shards
end

-- §22 Rule 5: AddShards/SpendShards are server-only; shard amounts never accepted from client.
-- Adds `amount` shards and fires ShardsUpdated. Server-only — never trust client amount.
function EconomyManager.AddShards(player: Player, amount: number)
	local data = PlayerDataManager.GetData(player)
	if data == nil then
		return
	end
	data.shards += amount
	local shardsRemote = Remotes["ShardsUpdated"] :: RemoteEvent
	shardsRemote:FireClient(player, { shards = data.shards })
end

-- Deducts `amount` shards if balance is sufficient. Returns true on success, false otherwise.
-- Balance is never allowed to go negative.
function EconomyManager.SpendShards(player: Player, amount: number): boolean
	local data = PlayerDataManager.GetData(player)
	if data == nil then
		return false
	end
	if data.shards < amount then
		return false
	end
	data.shards -= amount
	local shardsRemote = Remotes["ShardsUpdated"] :: RemoteEvent
	shardsRemote:FireClient(player, { shards = data.shards })
	return true
end

-- ─── T-23 · Gamepasses & Robux ────────────────────────────────────────────────

-- Sets xpBoostExpiry to now + duration (seconds).
function EconomyManager.ApplyXPBoost(player: Player, duration: number)
	local data = PlayerDataManager.GetData(player)
	if data == nil then
		return
	end
	data.xpBoostExpiry = os.time() + duration
end

-- Checks all three gamepasses and caches results in data.gamepasses.
-- Wrapped in pcall per PRD; partial failures leave prior cached values intact.
local function checkGamepasses(player: Player, data: { gamepasses: { [string]: boolean }, [string]: any })
	local gpIds: { number } = {
		Constants.GAMEPASS_ID_VIP,
		Constants.GAMEPASS_ID_BOTTLE,
		Constants.GAMEPASS_ID_AUTOSHARD,
	}
	for _, id in gpIds do
		local ok, owned = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
		end)
		if ok then
			data.gamepasses[tostring(id)] = owned :: boolean
		end
	end
end

-- Runs a loop that grants AUTO_SHARD_AMOUNT shards every AUTO_SHARD_TICK seconds
-- while the player is in the server and owns the Auto-Shard gamepass.
local function startAutoShard(player: Player)
	task.spawn(function()
		while player:IsDescendantOf(Players) do
			task.wait(Constants.AUTO_SHARD_TICK)
			if not player:IsDescendantOf(Players) then
				break
			end
			local data = PlayerDataManager.GetData(player)
			if data == nil then
				break
			end
			if data.gamepasses[tostring(Constants.GAMEPASS_ID_AUTOSHARD)] then
				EconomyManager.AddShards(player, Constants.AUTO_SHARD_AMOUNT)
			end
		end
	end)
end

-- Maps developer product IDs to shard grant amounts.
local PRODUCT_SHARD_GRANTS: { [number]: number } = {
	[Constants.PRODUCT_ID_SHARDS_100] = 100,
	[Constants.PRODUCT_ID_SHARDS_500] = 500,
	[Constants.PRODUCT_ID_SHARDS_1500] = 1500,
}

-- ─── T-24 · Bottle shop ───────────────────────────────────────────────────────

-- Shard cost per bottle. BotolBiasa (default), BotolKristal (milestone),
-- and BotolRetak (free daily) are intentionally excluded.
local BOTTLE_SHARD_COSTS: { [string]: number } = {
	BotolKacaBiru = 50,
	BotolEmas = 120,
}

-- Per-player rate-limit clock for RequestBuyBottle.
local buyBottleRateLimit: { [number]: number } = {}

local function handleRequestBuyBottle(player: Player, args: { [string]: any }): { [string]: any }
	local userId = player.UserId
	local now = os.clock()

	-- §22 Rule 8: minimum 2s gap between RequestBuyBottle calls per player.
	if now - (buyBottleRateLimit[userId] or 0) < Constants.RATE_LIMIT_BUY_BOTTLE then
		return { ok = false, error = "RATE_LIMITED" }
	end
	buyBottleRateLimit[userId] = now

	local bottleId = args.bottleId
	local qty = args.quantity
	if type(bottleId) ~= "string" or type(qty) ~= "number" then
		return { ok = false, error = "INVALID_ARGS" }
	end
	qty = math.floor(qty)
	if qty ~= 1 and qty ~= 5 then
		return { ok = false, error = "INVALID_ARGS" }
	end

	local costPer = BOTTLE_SHARD_COSTS[bottleId]
	if costPer == nil then
		return { ok = false, error = "NOT_PURCHASABLE" }
	end

	local data = PlayerDataManager.GetData(player)
	if data == nil then
		return { ok = false, error = "NO_DATA" }
	end

	-- Capacity check: max BOTTLE_MAX_CAPACITY per non-default type; +10 with Extra Bottle Bag.
	local maxCap = Constants.BOTTLE_MAX_CAPACITY
	if data.gamepasses[tostring(Constants.GAMEPASS_ID_BOTTLE)] then
		maxCap += 10
	end
	local current = data.bottles[bottleId] or 0
	if current + qty > maxCap then
		return { ok = false, error = "FULL" }
	end

	-- Deduct shards atomically before updating inventory.
	local totalCost = costPer * qty
	local spent = EconomyManager.SpendShards(player, totalCost)
	if not spent then
		return { ok = false, error = "INSUFFICIENT_SHARDS" }
	end

	data.bottles[bottleId] = current + qty

	local bottlesRemote = Remotes["BottlesUpdated"] :: RemoteEvent
	bottlesRemote:FireClient(player, { bottles = data.bottles })

	PlayerDataManager.Save(player)

	return { ok = true }
end

-- ─── Init ─────────────────────────────────────────────────────────────────────

function EconomyManager.Init()
	-- T-24: wire RequestBuyBottle RemoteFunction
	local buyBottleRf = Remotes["RequestBuyBottle"] :: RemoteFunction
	buyBottleRf.OnServerInvoke = handleRequestBuyBottle

	-- T-23: on each player load, cache gamepasses and start Auto-Shard if owned
	PlayerDataManager.OnLoaded(function(player: Player, data)
		checkGamepasses(player, data :: any)
		if (data :: any).gamepasses[tostring(Constants.GAMEPASS_ID_AUTOSHARD)] then
			startAutoShard(player)
		end
	end)

	-- Cover players already loaded (studio test runs where PlayerAdded fires early)
	for _, player in Players:GetPlayers() do
		local data = PlayerDataManager.GetData(player)
		if data ~= nil then
			checkGamepasses(player, data :: any)
			if data.gamepasses[tostring(Constants.GAMEPASS_ID_AUTOSHARD)] then
				startAutoShard(player)
			end
		end
	end

	-- Clean up rate-limit table on player leave
	Players.PlayerRemoving:Connect(function(player: Player)
		buyBottleRateLimit[player.UserId] = nil
	end)

	-- T-23: ProcessReceipt — idempotent via purchaseHistory in player profile
	MarketplaceService.ProcessReceipt = function(info: { PlayerId: number, ProductId: number, PurchaseId: number })
		local player = Players:GetPlayerByUserId(info.PlayerId)
		if player == nil then
			-- Player left mid-purchase; retry on next join
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local data = PlayerDataManager.GetData(player)
		if data == nil then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local receiptKey = tostring(info.PurchaseId)
		local history = (data :: any).purchaseHistory :: { [string]: boolean }

		-- §22 Rule 9: idempotency — duplicate receipt returns PurchaseGranted without re-granting.
		if history[receiptKey] then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		local grant = PRODUCT_SHARD_GRANTS[info.ProductId]
		if grant == nil then
			-- Unknown product; do not acknowledge (will retry)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		EconomyManager.AddShards(player, grant)
		history[receiptKey] = true
		PlayerDataManager.Save(player)

		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
end

return EconomyManager
