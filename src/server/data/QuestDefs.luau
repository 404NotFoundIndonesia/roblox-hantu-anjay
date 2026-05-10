--!strict

-- QuestDefs.luau (server-only)
-- Contains all daily and weekly quest templates.
-- trackFilter fields are evaluated by QuestManager when signals fire.

export type TrackFilter = {
	rarity: string?, -- match GhostCaptured by rarity
	zone: string?, -- match GhostCaptured by zoneId
}

export type QuestDef = {
	id: string,
	type: string, -- "daily" | "weekly"
	descKey: string, -- localization key for description
	target: number, -- completion threshold
	rewardShards: number,
	rewardXP: number,
	trackEvent: string, -- internal Signal name QuestManager listens to
	trackFilter: TrackFilter?, -- optional filter; nil = match all events
}

local QuestDefs: { QuestDef } = {

	-- ─────────────────── DAILY (3) ──────────────────────

	{
		id = "daily_capture3common",
		type = "daily",
		descKey = "QUEST_DAILY_CAPTURE3COMMON",
		target = 3,
		rewardShards = 30,
		rewardXP = 50,
		trackEvent = "GhostCaptured",
		trackFilter = { rarity = "Common" },
	},

	{
		id = "daily_find10shards",
		type = "daily",
		descKey = "QUEST_DAILY_FIND10SHARDS",
		target = 10,
		rewardShards = 20,
		rewardXP = 30,
		trackEvent = "ShardCollected",
		trackFilter = nil,
	},

	{
		id = "daily_visit3zones",
		type = "daily",
		descKey = "QUEST_DAILY_VISIT3ZONES",
		target = 3,
		rewardShards = 15,
		rewardXP = 20,
		trackEvent = "ZoneVisited",
		trackFilter = nil,
	},

	-- ─────────────────── WEEKLY (3) ─────────────────────

	{
		id = "weekly_capture1rare",
		type = "weekly",
		descKey = "QUEST_WEEKLY_CAPTURE1RARE",
		target = 1,
		rewardShards = 100,
		rewardXP = 200,
		trackEvent = "GhostCaptured",
		trackFilter = { rarity = "Rare" },
	},

	{
		id = "weekly_groupcapture",
		type = "weekly",
		descKey = "QUEST_WEEKLY_GROUPCAPTURE",
		target = 1,
		rewardShards = 80,
		rewardXP = 150,
		trackEvent = "GroupCapture",
		trackFilter = nil,
	},

	{
		id = "weekly_kuburancina",
		type = "weekly",
		descKey = "QUEST_WEEKLY_KUBURANCINA",
		target = 1,
		rewardShards = 60,
		rewardXP = 100,
		trackEvent = "GhostCaptured",
		trackFilter = { zone = "KuburanCina" },
	},
}

return QuestDefs
