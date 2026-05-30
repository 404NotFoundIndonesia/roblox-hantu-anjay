--!strict
-- ImageDefs.luau
-- Central registry for all UI image/decal asset IDs.
-- Every value is 0 (blank placeholder) until you replace it with your real Roblox asset ID.
--
-- To replace a placeholder:
--   1. Upload your image via Creator Hub → Creations → Development Items → Decals (or Images).
--   2. Copy the numeric asset ID from the URL.
--   3. Set the value here: e.g.  ICON_SCAN = 1234567890
--
-- Format: "rbxassetid://" is prepended by the UI code — store only the numeric ID here.

local ImageDefs = {

	-- ─── HUD buttons (bottom bar) ────────────────────────────────────────────────
	ICON_SCAN        = 119036386606378, -- SCAN pulse button icon
	ICON_COMPENDIUM  = 122949449016781, -- Compendium book icon
	ICON_SHOP        = 127983952451303, -- Shop bag/cart icon

	-- ─── Economy ─────────────────────────────────────────────────────────────────
	ICON_SHARD       = 0, -- Spirit Shard gem/crystal icon (used in shard balance labels)
	ICON_LANTERN     = 0, -- Lantern icon (top bar lantern level display)

	-- ─── Mini-map ─────────────────────────────────────────────────────────────────
	ICON_MINIMAP_BG  = 0, -- Overhead world map decal shown as mini-map background

	-- ─── Bottle icons (HUD bottom bar slots + shop cards) ────────────────────────
	ICON_BOTTLE_BIASA    = 0, -- Botol Biasa
	ICON_BOTTLE_KACABIRU = 0, -- Botol Kaca Biru
	ICON_BOTTLE_EMAS     = 0, -- Botol Emas
	ICON_BOTTLE_KRISTAL  = 0, -- Botol Kristal
	ICON_BOTTLE_RETAK    = 0, -- Botol Retak

	-- ─── Shop tab icons ───────────────────────────────────────────────────────────
	ICON_TAB_BOTTLES    = 0, -- Bottles tab icon
	ICON_TAB_COSMETICS  = 0, -- Cosmetics tab icon
	ICON_TAB_BATTLEPASS = 0, -- Battle Pass tab icon
	ICON_TAB_BOOSTS     = 0, -- Boosts tab icon

	-- ─── Rarity badges (compendium slots + detail card) ──────────────────────────
	ICON_RARITY_COMMON  = 0, -- Common star/badge
	ICON_RARITY_RARE    = 0, -- Rare star/badge
	ICON_RARITY_EPIC    = 0, -- Epic gem/badge
	ICON_RARITY_MYTHIC  = 0, -- Mythic crown/badge

	-- ─── Compendium ───────────────────────────────────────────────────────────────
	ICON_GHOST_SILHOUETTE = 0, -- Dimmed ghost silhouette shown on uncaptured slots

	-- ─── Decorative / backgrounds ────────────────────────────────────────────────
	DECAL_PANEL_BG   = 0, -- Repeating panel/parchment texture used behind menus
	DECAL_MENU_LOGO  = 0, -- Game logo image shown at top of shop / compendium header

}

return ImageDefs
