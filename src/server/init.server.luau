--!strict

-- init.server.luau
-- Server bootstrap entry point.
-- Systems initialised in strict dependency order; see T-47 for full sequence.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- 1. Remotes first — every system needs them, and clients WaitForChild them.
require(ReplicatedStorage.Shared.Remotes)

-- 2. PlayerDataManager — loads profiles; other systems gate on OnLoaded.
-- Requiring it is enough: module-level PlayerAdded wiring runs on require.
require(ServerScriptService.Server.systems.PlayerDataManager)

-- 3. WorldBuilder — synchronous; world must exist before players can join.
local WorldBuilder = require(ServerScriptService.Server.systems.WorldBuilder)
WorldBuilder.Build()

-- 4. GhostSpawnManager — populates haunt points; must run after Build().
local GhostSpawnManager = require(ServerScriptService.Server.systems.GhostSpawnManager)
GhostSpawnManager.Init()

-- 5. GhostAI detection triggers — cold zones, proximity tick, shard pickup.
--    Must run after Build() so Workspace/World/ parts exist for ColdZone scan.
local GhostAI = require(ServerScriptService.Server.systems.GhostAI)
GhostAI.InitDetection()

-- 6. EconomyManager — ProcessReceipt + gamepass checks + bottle shop.
--    Must run before QuestManager (AddShards used by quest rewards).
local EconomyManager = require(ServerScriptService.Server.systems.EconomyManager)
EconomyManager.Init()

-- 7. QuestManager — signal connections + WIB reset + OnLoaded reset hook.
--    Must run before CaptureSession.Init() so Signals exist before any capture fires.
local QuestManager = require(ServerScriptService.Server.systems.QuestManager)
QuestManager.Init()

-- 8. CaptureSession — registers RemoteFunction handlers; must run after
--    PlayerDataManager, GhostSpawnManager, GhostAI, and QuestManager are initialised.
local CaptureSession = require(ServerScriptService.Server.systems.CaptureSession)
CaptureSession.Init()

-- 9. TutorialManager — must run after PlayerDataManager and CaptureSession so
--    OnLoaded callbacks fire after all handlers are registered and RequestScan /
--    RequestSkipTutorial OnServerInvoke are bound exactly once.
local TutorialManager = require(ServerScriptService.Server.systems.TutorialManager)
TutorialManager.Init()
