--!strict

-- init.server.luau — T-47
-- Server bootstrap entry point. Systems initialised in strict dependency order.
-- Each Init() call is pcall-wrapped; failures are logged but do not crash the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local function safeInit(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if not ok then
		warn("[Server Bootstrap] " .. name .. " failed to init: " .. tostring(err))
	end
end

-- 1. Remotes — must exist before any client connects or other system runs.
local Remotes = require(ReplicatedStorage.Shared.Remotes)

-- 2. PlayerDataManager — module-level PlayerAdded wiring runs on require.
local PlayerDataManager = require(ServerScriptService.Server.systems.PlayerDataManager)

-- 3. WorldBuilder — synchronous; fires Ready at end of Build().
--    World must exist before ghost systems run and before PlayerAdded fires.
local WorldBuilder = require(ServerScriptService.Server.systems.WorldBuilder)
safeInit("WorldBuilder", WorldBuilder.Build)

-- 4. GhostSpawnManager — populates haunt points; requires WorldBuilder.HauntPoints.
local GhostSpawnManager = require(ServerScriptService.Server.systems.GhostSpawnManager)
safeInit("GhostSpawnManager", GhostSpawnManager.Init)

-- 5. GhostAI — cold zones, proximity tick, shard pickup.
--    Must run after Build() so Workspace/World/ parts exist for ColdZone scan.
local GhostAI = require(ServerScriptService.Server.systems.GhostAI)
safeInit("GhostAI", GhostAI.InitDetection)

-- 6. EconomyManager — ProcessReceipt + gamepass checks + bottle shop.
--    Must run before QuestManager (AddShards used by quest rewards).
local EconomyManager = require(ServerScriptService.Server.systems.EconomyManager)
safeInit("EconomyManager", EconomyManager.Init)

-- 7. QuestManager — signal connections + WIB reset + OnLoaded reset hook.
--    Must run before CaptureSession so Signals exist before any capture fires.
local QuestManager = require(ServerScriptService.Server.systems.QuestManager)
safeInit("QuestManager", QuestManager.Init)

-- 8. CaptureSession — registers RemoteFunction handlers; depends on all above.
local CaptureSession = require(ServerScriptService.Server.systems.CaptureSession)
safeInit("CaptureSession", CaptureSession.Init)

-- 9. TutorialManager — depends on PlayerDataManager and CaptureSession.
--    RequestScan / RequestSkipTutorial OnServerInvoke bound exactly once here.
local TutorialManager = require(ServerScriptService.Server.systems.TutorialManager)
safeInit("TutorialManager", TutorialManager.Init)

-- 10. RequestViewCompendium — T-46. Pure data query; depends only on PlayerDataManager.
safeInit("RequestViewCompendium", function()
	local rf = Remotes["RequestViewCompendium"] :: RemoteFunction
	rf.OnServerInvoke = function(
		player: Player,
		targetUserId: any
	): { [string]: any }
		if targetUserId == nil then
			local data = PlayerDataManager.GetData(player)
			return {
				compendium = if data ~= nil then data.compendium else {},
				isOwn = true,
				username = nil,
			}
		end
		if type(targetUserId) ~= "number" then
			return { compendium = {}, isOwn = false, username = "?" }
		end
		local targetPlayer = Players:GetPlayerByUserId(targetUserId)
		if targetPlayer == nil then
			return { compendium = {}, isOwn = false, username = "?" }
		end
		local data = PlayerDataManager.GetData(targetPlayer)
		return {
			compendium = if data ~= nil then data.compendium else {},
			isOwn = (targetUserId == player.UserId),
			username = targetPlayer.Name,
		}
	end
end)

-- Suppress unused-local hints for systems whose only side-effect is Init().
_ = GhostSpawnManager
_ = GhostAI
_ = EconomyManager
_ = QuestManager
_ = CaptureSession
_ = TutorialManager
