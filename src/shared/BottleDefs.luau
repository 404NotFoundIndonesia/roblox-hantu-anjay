--!strict

export type BottleDef = {
	catchRate: number, -- 0.0–1.0 probability of successful capture
	maxDurability: number?, -- nil = unlimited
	unlimited: boolean,
}

local BottleDefs: { [string]: BottleDef } = {
	BotolBiasa = {
		catchRate = 0.40,
		maxDurability = 3,
		unlimited = false,
	},
	BotolKacaBiru = {
		catchRate = 0.60,
		maxDurability = 5,
		unlimited = false,
	},
	BotolEmas = {
		catchRate = 0.80,
		maxDurability = 8,
		unlimited = false,
	},
	BotolKristal = {
		catchRate = 0.95,
		maxDurability = nil,
		unlimited = true,
	},
	BotolRetak = {
		catchRate = 0.20,
		maxDurability = 1,
		unlimited = false,
	},
}

return BottleDefs
