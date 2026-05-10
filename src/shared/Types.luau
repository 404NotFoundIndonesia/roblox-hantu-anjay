--!strict

-- Rarity tier for spirits
export type Rarity = "Common" | "Rare" | "Epic" | "Mythic"

-- Ghost movement/behaviour archetype
export type GhostBehavior = "Wanderer" | "Hunter" | "Trickster"

-- Which mini-game is used to weaken a ghost
export type MiniGameType =
	"MantraTap"
	| "BottleAim"
	| "RhythmChant"
	| "SignalTriangulate"
	| "ShadowChase"
	| "TeamSurround"

-- Bottle identifiers
export type BottleId =
	"BotolBiasa"
	| "BotolKacaBiru"
	| "BotolEmas"
	| "BotolKristal"
	| "BotolRetak"

-- Biome zone identifiers
export type ZoneId =
	"Kuburan"
	| "KampungTua"
	| "HutanBambu"
	| "PantaiSepi"
	| "KuburanCina"
	| "SawahHaunted"

-- Ghost definition identifier (matches keys in GhostDefs)
export type GhostId = string

-- Lifecycle states a spawned ghost can be in
export type GhostState =
	"Patrolling"
	| "Triggered"
	| "InCapture"
	| "Escaped"
	| "Captured"

-- Runtime ghost instance (server-side data, NOT replicated raw)
export type GhostInstance = {
	ghostId: GhostId,
	instanceId: string, -- unique GUID per spawned instance
	zoneId: ZoneId,
	hauntPointIndex: number,
	state: GhostState,
	resistance: number, -- current resistance; starts at GhostDef.maxResistance
}

-- Outcome of a completed capture attempt
export type CaptureResult = "Success" | "Fail" | "Escaped"

-- Per-ghost record stored in the player compendium
export type CompendiumEntry = {
	captureCount: number,
	firstCapturedAt: number, -- os.time() timestamp
}

-- Quest progress counters (questId → current count)
export type QuestProgress = {
	daily: { [string]: number },
	weekly: { [string]: number },
}

-- Full player profile stored via ProfileService
export type PlayerProfile = {
	level: number,
	xp: number,
	compendium: { [string]: CompendiumEntry }, -- GhostId → CompendiumEntry
	shards: number,
	bottles: { [string]: number }, -- BottleId → count
	quests: QuestProgress,
	lastDailyReset: number, -- os.time() of last daily reset
	lastWeeklyReset: number, -- os.time() of last weekly reset
	gamepasses: { [string]: boolean }, -- gamepass id string → owned
	cosmetics: { [string]: boolean }, -- cosmetic key → owned
	companion: string?, -- GhostId of companion ghost (rarest captured)
	tutorialDone: boolean,
	milestones: { [string]: boolean }, -- milestone key → unlocked
	xpBoostExpiry: number, -- os.time() when XP boost expires (0 = none)
	purchaseHistory: { [string]: boolean }, -- receiptId string → processed
}

return {}
