--!strict
-- LocalizationBridge — T-26
-- Fetches the player's LocalizationTranslator once; exposes LocalizationBridge.get().
-- Falls back to the raw key if the translator is not yet ready or the key is missing.
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local LocalizationBridge = {}

-- Populated asynchronously; nil until GetTranslatorForPlayerAsync completes.
local translator: any = nil

-- Fetch translator in a background task so module load is non-blocking.
-- Other systems receive raw keys as fallback until the translator is ready
-- (typically < 1 second; DoD requires < 3 seconds).
task.spawn(function()
	local ok, result = pcall(function()
		return LocalizationService:GetTranslatorForPlayerAsync(LocalPlayer)
	end)
	if ok and result ~= nil then
		translator = result
	end
end)

-- Returns a localized string for `key` with optional format parameters.
-- `params` maps placeholder names to values, e.g. { count = 5, date = "01/01/2025" }.
-- Falls back to the raw key on missing key, translator not ready, or pcall failure.
function LocalizationBridge.get(key: string, params: { [string]: any }?): string
	local t = translator
	if t == nil then
		return key
	end
	local ok, result = pcall(function()
		return (t :: any):FormatByKey(key, params)
	end)
	if ok and type(result) == "string" and #result > 0 then
		return result
	end
	return key
end

return LocalizationBridge
