--!strict

-- init.client.luau — T-48
-- Client bootstrap entry point. Systems initialised in dependency order.
-- Each Init() call is pcall-wrapped; failures are logged but do not crash the client.

local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local function safeInit(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if not ok then
		warn("[Client Bootstrap] " .. name .. " failed to init: " .. tostring(err))
	end
end

-- 1. LocalizationBridge — yields until translator ready (≤3 s) before any UI text is set.
local LocalizationBridge = require(script.systems.LocalizationBridge)
safeInit("LocalizationBridge", LocalizationBridge.Init)

-- 2. UIManager — detect platform before any UI layout is applied.
local UIManager = require(script.systems.UIManager)
safeInit("UIManager", UIManager.Init)

-- 3. Wait for character — ZoneDetector and HUD depend on the character existing.
if LocalPlayer.Character == nil then
	LocalPlayer.CharacterAdded:Wait()
end

-- 4. ZoneDetector — requires LocalPlayer.Character to determine starting zone.
local ZoneDetector = require(script.systems.ZoneDetector)
safeInit("ZoneDetector", ZoneDetector.Init)

-- 5. AudioController — ambient and tension layers; starts after zone is known.
local AudioController = require(script.systems.AudioController)
safeInit("AudioController", AudioController.Init)

-- 6. HUD — registers with UIManager; must be ready before tutorial highlights its buttons.
local HUD = require(script.systems.HUD)
safeInit("HUD", HUD.Init)

-- 7. CompendiumUI — registers with UIManager; wires ProximityPrompts on other players.
local CompendiumUI = require(script.systems.CompendiumUI)
safeInit("CompendiumUI", CompendiumUI.Init)

-- 8. ShopUI — registers with UIManager.
local ShopUI = require(script.systems.ShopUI)
safeInit("ShopUI", ShopUI.Init)

-- 9. MiniGameController — registers with UIManager; handles MiniGameStart events.
local MiniGameController = require(script.systems.MiniGameController)
safeInit("MiniGameController", MiniGameController.Init)

-- 10. TutorialController — registers with UIManager; highlights HUD elements (ScanButton,
--     MiniMap). Must run after HUD so those targets exist in the hierarchy.
local TutorialController = require(script.systems.TutorialController)
safeInit("TutorialController", TutorialController.Init)

-- 11. CompanionController — listens to CompanionSet; spawns companion model.
local CompanionController = require(script.systems.CompanionController)
safeInit("CompanionController", CompanionController.Init)

-- Suppress unused-local hints for systems whose only role is Init() side-effects.
_ = LocalizationBridge
_ = UIManager
_ = ZoneDetector
_ = AudioController
_ = HUD
_ = CompendiumUI
_ = ShopUI
_ = MiniGameController
_ = TutorialController
_ = CompanionController
