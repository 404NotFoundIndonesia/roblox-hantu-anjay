--!strict
-- UIManager — T-27
-- Centralised UI routing. Enforces single-modal constraint and platform detection.
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)

-- ─── Types ────────────────────────────────────────────────────────────────────

-- All registered UI modules must implement this interface.
export type UIModule = {
	open: () -> (),
	close: () -> (),
	screenGui: ScreenGui?, -- optional; UIManager applies DeviceSafeInsets if present
}

-- ─── State ────────────────────────────────────────────────────────────────────

local registry: { [string]: UIModule } = {}
local openFlags: { [string]: boolean } = {}

-- HUD is always visible and exempt from the single-modal close sweep.
local HUD_NAME = "HUD"

-- ─── Public API ───────────────────────────────────────────────────────────────

local UIManager = {}

-- Current platform string; set during Init().
UIManager.platform = "PC" :: string

-- Fires once during Init() with the platform string ("Mobile" | "PC" | "Console").
UIManager.PlatformDetected = Signal.new() :: any

-- Detects the device platform based on UserInputService capabilities.
local function detectPlatform(): string
	if UserInputService.TouchEnabled then
		return "Mobile"
	elseif UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		return "Console"
	end
	return "PC"
end

-- Applies DeviceSafeInsets to a ScreenGui so content avoids notches and home bars.
local function applySafeInsets(gui: ScreenGui)
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
end

-- Registers a UI module under `name`. If the module exposes a `screenGui`,
-- DeviceSafeInsets is applied immediately.
function UIManager.register(name: string, module: UIModule)
	registry[name] = module
	openFlags[name] = false
	if module.screenGui ~= nil then
		applySafeInsets(module.screenGui :: ScreenGui)
	end
end

-- Opens a UI module by name. For non-HUD modals, closes any other open modal first
-- (single-modal constraint). HUD is always exempt.
function UIManager.open(name: string)
	local module = registry[name]
	if module == nil then
		warn("[UIManager] open: '" .. name .. "' is not registered")
		return
	end

	-- Single-modal sweep: close all other open non-HUD modals.
	if name ~= HUD_NAME then
		for otherName, isOpen in openFlags do
			if isOpen and otherName ~= HUD_NAME and otherName ~= name then
				UIManager.close(otherName)
			end
		end
	end

	openFlags[name] = true
	module.open()
end

-- Closes a UI module by name. No-op if not registered or already closed.
function UIManager.close(name: string)
	local module = registry[name]
	if module == nil then
		return
	end
	openFlags[name] = false
	module.close()
end

-- Returns true if the named module is currently open.
function UIManager.isOpen(name: string): boolean
	return openFlags[name] == true
end

-- Detects platform, fires PlatformDetected signal, and applies safe insets to any
-- ScreenGuis already registered (in case modules registered before Init was called).
function UIManager.Init()
	UIManager.platform = detectPlatform()

	-- Apply safe insets to any modules registered before Init().
	for _, module in registry do
		if module.screenGui ~= nil then
			applySafeInsets(module.screenGui :: ScreenGui)
		end
	end

	UIManager.PlatformDetected:Fire(UIManager.platform)
end

return UIManager
