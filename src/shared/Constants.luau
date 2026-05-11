--!strict

return {
	-- Server capacity
	MAX_PLAYERS = 50,

	-- World layout
	WORLD_ORIGIN = Vector3.new(0, 0, 0),
	HUB_SPAWN = Vector3.new(0, 50, 0),
	CHUNK_SIZE = 16, -- studs per voxel chunk

	-- SCAN mechanic
	SCAN_RADIUS = 60, -- studs; detection pulse radius
	SCAN_COOLDOWN = 8, -- seconds between SCAN uses per player

	-- Ghost AI timing
	GHOST_ESCAPE_TIME = 15, -- seconds a Hunter chases before giving up
	GHOST_WANDER_FACE_TIME = 3, -- seconds a Wanderer faces player before Escaped
	GHOST_TRICKSTER_TELEPORT_INTERVAL = 4, -- seconds between Trickster teleports
	GHOST_AI_TICK = 0.5, -- seconds between AI state updates
	GHOST_IDLE_TRIGGER_TIME = 8, -- seconds player stands still near haunt to trigger

	-- Capture flow
	CAPTURE_COOLDOWN = 5, -- seconds before a ghost respawns after escape/capture
	CAPTURE_PROXIMITY = 25, -- studs; max distance to initiate capture
	CAPTURE_TIMEOUT = 30, -- seconds before a mini-game auto-fails
	CAPTURE_RATE_LIMIT = 3, -- seconds min between RequestCapture calls per player

	-- Economy defaults
	BOTTLE_DEFAULT = "BotolBiasa",
	BOTTLE_DEFAULT_COUNT = 3,
	BOTTLE_MAX_CAPACITY = 5, -- max non-default bottles; +10 with Extra Bottle Bag
	SHARD_DAILY_LOGIN = 5, -- shards awarded on first login each day

	-- XP
	XP_PER_RARITY = {
		Common = 10,
		Rare = 30,
		Epic = 75,
		Mythic = 200,
	},
	FIRST_CAPTURE_BONUS_MULTIPLIER = 3,
	VIP_XP_MULTIPLIER = 1.1,
	XP_BOOST_MULTIPLIER = 1.5,

	-- Ghost spawn
	MAX_ACTIVE_GHOSTS = 20,
	MAX_GHOSTS_PER_HAUNT = 1,
	RARITY_SPAWN_WEIGHT = {
		Common = 60,
		Rare = 28,
		Epic = 10,
		Mythic = 2,
	},
	AFFINITY_WEIGHT_BONUS = 2, -- multiplier applied to affinity ghost weight

	-- Mythic server-wide event
	MYTHIC_EVENT_MIN_PLAYERS = 4, -- players needed for BataraGuruShadow to spawn
	MYTHIC_EVENT_DESPAWN_TIME = 600, -- seconds (10 min) before mythic auto-despawns
	MYTHIC_MIN_PLAYERS = 2, -- players needed to capture mythic without BotolKristal

	-- Quest reset (WIB = UTC+7)
	UTC_OFFSET_WIB = 7 * 3600,
	WEEKLY_RESET_DAY = 2, -- 2 = Monday in os.date %w (0=Sun, 1=Mon... actually 0=Sun so Monday=2 in some systems)
	-- Note: os.date %w: 0=Sun, 1=Mon, 2=Tue... Use 1 for Monday.

	-- Mini-map
	MINIMAP_UPDATE_RATE = 0.5, -- seconds

	-- Audio
	TENSION_UPDATE_RATE = 0.5, -- seconds
	TENSION_FULL_DISTANCE = 10, -- studs; full tension volume
	TENSION_ZERO_DISTANCE = 50, -- studs; zero tension volume
	TENSION_MAX_VOLUME = 0.6,

	-- Zone detection
	ZONE_DETECT_RATE = 0.25, -- seconds

	-- Auto-shard (AUTO_SHARD gamepass)
	AUTO_SHARD_TICK = 30, -- seconds between auto-shard grants
	AUTO_SHARD_AMOUNT = 1,

	-- Spirit Shard world items (ShardManager)
	SHARD_PICKUP_AMOUNT = 2,        -- shards granted per SpiritShard collected
	SHARD_RESPAWN_TIME = 120,       -- seconds before a collected shard respawns
	SHARDS_PER_HAUNT_POINT = 2,     -- SpiritShard Parts spawned near each haunt point

	-- Lantern (LanternManager)
	LANTERN_DRAIN_PER_TICK = 2,     -- lantern units lost per tick while in a biome zone
	LANTERN_RECHARGE_PER_TICK = 1,  -- lantern units gained per tick at hub
	LANTERN_TICK_INTERVAL = 5,      -- seconds between lantern level updates

	-- Jump pads (JumpPadManager)
	JUMP_PAD_FORCE = 120,           -- studs/s upward impulse applied on touch
	JUMP_PAD_COOLDOWN = 1,          -- seconds before same player can use a JumpPad again

	-- Remote rate limits (seconds)
	RATE_LIMIT_SCAN = 8,
	RATE_LIMIT_CAPTURE = 3,
	RATE_LIMIT_MINIGAME_INPUT = 0.1,
	RATE_LIMIT_BUY_BOTTLE = 2,

	-- Gamepass IDs (fill with real IDs before publishing)
	GAMEPASS_ID_VIP = 0,
	GAMEPASS_ID_BOTTLE = 0,
	GAMEPASS_ID_AUTOSHARD = 0,

	-- Developer Product IDs (fill before publishing)
	PRODUCT_ID_SHARDS_100 = 0,
	PRODUCT_ID_SHARDS_500 = 0,
	PRODUCT_ID_SHARDS_1500 = 0,

	-- Compendium milestones
	MILESTONE_AURA_COUNT = 10,
	MILESTONE_TITLE_COUNT = 20,
	MILESTONE_KRISTAL_COUNT = 30,

	-- Rank level ranges
	RANK_RANGES = {
		{ key = "RANK_PEMULA_TITLE", minLevel = 1, maxLevel = 5 },
		{ key = "RANK_JAGOAN_TITLE", minLevel = 6, maxLevel = 15 },
		{ key = "RANK_PARANORMAL_TITLE", minLevel = 16, maxLevel = 30 },
		{ key = "RANK_DUKUN_TITLE", minLevel = 31, maxLevel = 50 },
		{ key = "RANK_LEGENDA_TITLE", minLevel = 51, maxLevel = math.huge },
	},
}
