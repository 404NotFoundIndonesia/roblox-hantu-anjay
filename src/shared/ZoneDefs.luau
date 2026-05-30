--!strict

export type DetectionVolume = {
	min: Vector3,
	max: Vector3,
}

export type ZoneDef = {
	id: string, -- ZoneId
	modelName: string, -- asset name in ReplicatedStorage/Assets/Biomes/
	worldOffset: Vector3, -- suggested island center; designer places model in Studio at this position
	hauntPointCount: number, -- how many HauntPoint Parts expected in the model
	ambientSoundId: number, -- Roblox audio asset ID (0 = placeholder)
	affinityGhosts: { string }, -- GhostIds with boosted spawn weight in this zone
	detectionVolume: DetectionVolume, -- AABB used by ZoneDetector (exclusive bounds)
}

-- Islands are placed in Studio by the designer (see STUDIO_SETUP.md §5–6).
-- Detection volumes must cover the actual in-world position of each island.
-- If you reposition an island, update detectionVolume here to match.

local ZoneDefs: { [string]: ZoneDef } = {

	Kuburan = {
		id = "Kuburan",
		modelName = "Kuburan",
		worldOffset = Vector3.new(-280, 30, 0),
		hauntPointCount = 4,
		ambientSoundId = 0,
		affinityGhosts = {
			"Pocong",
			"Jenglot",
			"Rangda",
			"BataraKala",
			"Mahisasura",
			"SantetSpecter",
			"DewiDurga",
			"Leyak",
		},
		-- Island spans roughly (-325, 20, -45) → (-235, 90, 45)
		detectionVolume = {
			min = Vector3.new(-325, 20, -45),
			max = Vector3.new(-235, 90, 45),
		},
	},

	KampungTua = {
		id = "KampungTua",
		modelName = "KampungTua",
		worldOffset = Vector3.new(0, 60, 270),
		hauntPointCount = 5,
		ambientSoundId = 0,
		affinityGhosts = {
			"Kuntilanak",
			"WeweGombel",
			"GenderuwoJr",
			"HantuRaya",
			"HantuKopek",
			"SantetSpecter",
		},
		-- Island spans roughly (-50, 50, 225) → (50, 130, 315)
		detectionVolume = {
			min = Vector3.new(-50, 50, 225),
			max = Vector3.new(50, 130, 315),
		},
	},

	HutanBambu = {
		id = "HutanBambu",
		modelName = "HutanBambu",
		worldOffset = Vector3.new(220, 75, 150),
		hauntPointCount = 3,
		ambientSoundId = 0,
		affinityGhosts = {
			"SundelBolong",
			"OrangBunian",
			"AswangMild",
			"ManananggalHalf",
		},
		-- Island spans roughly (175, 65, 105) → (265, 145, 195)
		detectionVolume = {
			min = Vector3.new(175, 65, 105),
			max = Vector3.new(265, 145, 195),
		},
	},

	PantaiSepi = {
		id = "PantaiSepi",
		modelName = "PantaiSepi",
		worldOffset = Vector3.new(250, 15, -220),
		hauntPointCount = 3,
		ambientSoundId = 0,
		affinityGhosts = {
			"Penanggalan",
			"ManananggalHalf",
			"KraSue",
			"NyiBlorong",
			"NyiRoroKidul",
		},
		-- Island spans roughly (205, 5, -265) → (295, 60, -175)
		detectionVolume = {
			min = Vector3.new(205, 5, -265),
			max = Vector3.new(295, 60, -175),
		},
	},

	KuburanCina = {
		id = "KuburanCina",
		modelName = "KuburanCina",
		worldOffset = Vector3.new(-200, 40, -240),
		hauntPointCount = 4,
		ambientSoundId = 0,
		affinityGhosts = {
			"Toyol",
			"Tuyul",
			"PhiPop",
			"RangdaTrue",
			"Leyak",
		},
		-- Island spans roughly (-245, 30, -285) → (-155, 100, -195)
		detectionVolume = {
			min = Vector3.new(-245, 30, -285),
			max = Vector3.new(-155, 100, -195),
		},
	},

	SawahHaunted = {
		id = "SawahHaunted",
		modelName = "SawahHaunted",
		worldOffset = Vector3.new(60, 55, -300),
		hauntPointCount = 4,
		ambientSoundId = 0,
		affinityGhosts = {
			"Banaspati",
			"LeakWeak",
			"BabiNgepet",
			"Palasik",
			"KraSue",
		},
		-- Island spans roughly (15, 45, -345) → (105, 115, -255)
		detectionVolume = {
			min = Vector3.new(15, 45, -345),
			max = Vector3.new(105, 115, -255),
		},
	},
}

return ZoneDefs
