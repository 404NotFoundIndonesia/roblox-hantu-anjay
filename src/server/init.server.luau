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

-- TODO (T-47): initialise remaining systems (GhostSpawnManager, CaptureSession,
-- QuestManager, EconomyManager) after WorldBuilder.Ready fires.
