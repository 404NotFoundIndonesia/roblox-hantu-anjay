--!strict
-- AudioDefs.luau
-- Central registry for all audio asset IDs.
-- Every value is 0 (silent placeholder) until you replace it with your real Roblox asset ID.
--
-- To replace a placeholder:
--   1. Upload audio via Creator Hub → Creations → Development Items → Audio.
--   2. Copy the numeric asset ID.
--   3. Set the value here. AudioController, GhostDefs, and ZoneDefs all read from this file.
--
-- Format: "rbxassetid://" is prepended by AudioController — store only the numeric ID here.

local AudioDefs = {

	-- ─── Music ────────────────────────────────────────────────────────────────────
	MUSIC_HUB    = 0, -- Calm ambient track looping in the Hub island (no ghosts)

	-- ─── Tension drone ────────────────────────────────────────────────────────────
	-- Loops continuously; volume scales with distance to the nearest ghost (0 → 0.6).
	TENSION_DRONE = 0,

	-- ─── UI one-shot SFX ──────────────────────────────────────────────────────────
	-- Played via AudioController.playUI(key). Add the key name here to register it.
	UI_SFX = {
		capture_success = 0, -- Victory: ghost sealed in bottle
		capture_fail    = 0, -- Failure: ghost escaped
		level_up        = 0, -- Level-up fanfare
		minigame_hit    = 0, -- Tap/percussion feedback (RhythmChant)
		quest_complete  = 0, -- Quest completion chime
		scan_pulse      = 0, -- SCAN button activation whoosh
		shard_pickup    = 0, -- Spirit Shard collected
		jump_pad        = 0, -- Jump pad launch whoosh
		bottle_throw    = 0, -- Bottle thrown in BottleAim mini-game
	},

	-- ─── Zone ambient loops ───────────────────────────────────────────────────────
	-- Each plays when the player enters that biome zone. Fades in/out on zone change.
	ZONE_AMBIENT = {
		Kuburan      = 0, -- Cemetery — eerie silence, distant wind
		KampungTua   = 0, -- Old village — cicadas, distant gamelan
		HutanBambu   = 0, -- Bamboo forest — rustling leaves, birds
		PantaiSepi   = 0, -- Lonely beach — waves, sea breeze
		KuburanCina  = 0, -- Chinese cemetery — distant chimes, frogs
		SawahHaunted = 0, -- Haunted rice field — crickets, running water
	},

	-- ─── Ghost proximity SFX ─────────────────────────────────────────────────────
	-- Loops spatially on the ghost model while it is in the Triggered state.
	-- Stops automatically when the ghost is captured or escapes.
	GHOST_SFX = {
		-- Common
		Pocong         = 0,
		Kuntilanak     = 0,
		WeweGombel     = 0,
		Banaspati      = 0,
		SundelBolong   = 0,
		Toyol          = 0,
		Tuyul          = 0,
		LeakWeak       = 0,
		GenderuwoJr    = 0,
		Jenglot        = 0,
		-- Rare
		Rangda         = 0,
		OrangBunian    = 0,
		HantuRaya      = 0,
		BabiNgepet     = 0,
		Palasik        = 0,
		Penanggalan    = 0,
		AswangMild     = 0,
		ManananggalHalf = 0,
		KraSue         = 0,
		PhiPop         = 0,
		-- Epic
		NyiBlorong     = 0,
		BataraKala     = 0,
		RangdaTrue     = 0,
		Mahisasura     = 0,
		Leyak          = 0,
		SantetSpecter  = 0,
		HantuKopek     = 0,
		-- Mythic
		NyiRoroKidul      = 0,
		DewiDurga         = 0,
		BataraGuruShadow  = 0,
	},

}

return AudioDefs
