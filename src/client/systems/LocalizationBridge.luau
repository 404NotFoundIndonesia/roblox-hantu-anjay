--!strict
-- LocalizationBridge — T-26
-- Primary source: StringDefs.luau (Indonesian strings, always available).
-- Secondary source: Roblox LocalizationService translator (for future multi-language support).
-- Falls back to StringDefs, then to the raw key if both fail.
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StringDefs = require(ReplicatedStorage.Shared.StringDefs)
local LocalPlayer = Players.LocalPlayer

local LocalizationBridge = {}

local translator: any = nil

-- Try to load the Roblox translator in the background (used only when a
-- LocalizationTable is placed inside LocalizationService for multi-language builds).
task.spawn(function()
	local ok, result = pcall(function()
		return LocalizationService:GetTranslatorForPlayerAsync(LocalPlayer)
	end)
	if ok and result ~= nil then
		translator = result
	end
end)

-- Replaces {paramName} placeholders in a string with values from params.
local function applyParams(s: string, params: { [string]: any }?): string
	if params == nil then
		return s
	end
	return (s:gsub("{([%w_]+)}", function(key: string): string
		local v = params[key]
		return if v ~= nil then tostring(v) else "{" .. key .. "}"
	end))
end

-- No init delay needed — StringDefs is always available synchronously.
function LocalizationBridge.Init()
	-- Nothing to wait for; translator is optional.
end

-- Returns a localized string for `key` with optional format parameters.
-- Resolution order:
--   1. Roblox translator (if loaded and key exists there)
--   2. StringDefs table
--   3. Raw key (last-resort fallback)
function LocalizationBridge.get(key: string, params: { [string]: any }?): string
	-- Try Roblox translator first (multi-language builds)
	local t = translator
	if t ~= nil then
		local ok, result = pcall(function()
			return (t :: any):FormatByKey(key, params)
		end)
		if ok and type(result) == "string" and result ~= key and #result > 0 then
			return result
		end
	end

	-- Fall back to StringDefs
	local s = StringDefs[key]
	if s ~= nil then
		return applyParams(s, params)
	end

	return key
end

return LocalizationBridge
