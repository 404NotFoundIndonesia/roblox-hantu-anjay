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

-- TODO (T-47): initialise remaining systems (CaptureSession, QuestManager,
-- EconomyManager) in dependency order.
