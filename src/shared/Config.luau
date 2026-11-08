--!strict
-- All balance and tuning numbers live here, so balancing never touches code.
-- Pure data: no requires, no Roblox APIs (colors are hex strings), so Lune can test it.
--
-- POLICY RULES (from roblox-researcher policy_check.md), keep these true:
--   * Spawns stay free. ZoneTables weights are fixed; nothing bought with Robux,
--     or with cash bought with Robux, may change them.
--   * Power changes throw distance, and therefore zone and rarity. So Power must
--     NEVER be sold for Robux (no paid x2 Power, no Power developer products).
--   * Cash is never spent on a random roll. Cash buys fixed items only (see Upgrades).
--   * Players toss seeds at the ground; critters sprout from them. Nothing is thrown at creatures.

local Config = {}

-- Timing meter scoring (read by Distance). Shapes here match the pure modules'
-- types exactly, because Luau's type checker rejects extra fields.
Config.Meter = {
	sweetCenter = 0.5,
	sweetHalfWidth = 0.08,
	perfectMult = 1.5,
	edgeMult = 0.5,
}

-- Meter motion (client only). The marker ping-pongs 0 -> 1 -> 0, one full sweep per cycle.
Config.MeterMotion = {
	cyclesPerSecond = 0.8,
}

-- distance = (baseDistance + powerScale * sqrt(power)) * meterMult, in studs.
Config.Distance = {
	baseDistance = 20,
	powerScale = 1.25,
	meter = Config.Meter,
}

-- Ordered by ascending minDistance (studs from the launch pad).
-- Perfect throw reaches grove at ~256 power and wildwood at ~2304 power.
Config.Zones = {
	{ id = "lawn", minDistance = 0 },
	{ id = "grove", minDistance = 60 },
	{ id = "wildwood", minDistance = 120 },
}

-- Display name and ground color per zone.
Config.ZoneLooks = {
	lawn = { name = "Lawn", color = "#8fd16a" },
	grove = { name = "Grove", color = "#3f9b4b" },
	wildwood = { name = "Wildwood", color = "#24543a" },
}

export type Creature = {
	name: string,
	rarity: string, -- "common" | "rare" | "epic" (Config.spec checks)
	income: number,
	color: string,
}

-- Placeholder critters: 2 per zone. Income is cash per second while on the plot.
Config.Creatures = {
	sproutling = { name = "Sproutling", rarity = "common", income = 1, color = "#b6e388" },
	budbun = { name = "Budbun", rarity = "rare", income = 4, color = "#f2a7c3" },
	mossmole = { name = "Mossmole", rarity = "common", income = 3, color = "#6b8e4e" },
	fernfox = { name = "Fernfox", rarity = "rare", income = 10, color = "#e07a3c" },
	thornowl = { name = "Thornowl", rarity = "rare", income = 25, color = "#7a5a8c" },
	bloomdrake = { name = "Bloomdrake", rarity = "epic", income = 80, color = "#d94fd9" },
} :: { [string]: Creature }

-- Derived lookup for Income.perSecond: critter id -> cash per second.
Config.CreatureIncome = {} :: { [string]: number }
for id, creature in Config.Creatures do
	Config.CreatureIncome[id] = creature.income
end

-- Free, fixed spawn odds per zone. See POLICY RULES above.
Config.ZoneTables = {
	lawn = { { id = "sproutling", weight = 80 }, { id = "budbun", weight = 20 } },
	grove = { { id = "mossmole", weight = 75 }, { id = "fernfox", weight = 25 } },
	wildwood = { { id = "thornowl", weight = 85 }, { id = "bloomdrake", weight = 15 } },
}

Config.RarityColors = {
	common = "#d9d9d9",
	rare = "#4aa3ff",
	epic = "#c45cff",
}

Config.Train = {
	powerPerTrain = 1,
	maxPerSecond = 8,
}

Config.Throw = {
	cooldownSeconds = 1.5,
	arcSeconds = 1.2, -- seed flight time before the sprout pops
	arcHeight = 25,
}

-- "walk": walk to the critter and use its prompt. "auto": it hops to your plot after the reveal.
Config.CollectMode = "auto" :: "walk" | "auto"
Config.AutoCollectDelaySeconds = 1.5
Config.PendingTimeoutSeconds = 45 -- an uncollected critter wilts after this, so throws never lock up

-- Same shape as Upgrade.Ladder (Config stays require-free).
type UpgradeLadder = {
	name: string,
	text: string,
	base: number,
	levels: { { price: number, value: number } },
}

-- Cash upgrade ladders. Fixed prices, fixed effects (see POLICY RULES). Tuned by tests/Pacing.spec.luau:
-- first buy < 1 min, wildwood ~5 min, last buy ~10 min for a good player.
-- `text` formats the value a level gives, for the HUD button.
Config.Upgrades = {
	trowel = {
		name = "Trowel",
		text = "%dx training",
		base = 1,
		levels = { { price = 300, value = 2 }, { price = 3000, value = 3 }, { price = 20000, value = 4 } },
	},
	plotSlots = {
		name = "Plot",
		text = "%d slots",
		base = 3,
		levels = {
			{ price = 150, value = 4 },
			{ price = 600, value = 5 },
			{ price = 2000, value = 6 },
			{ price = 6000, value = 7 },
			{ price = 20000, value = 8 },
			{ price = 60000, value = 9 },
		},
	},
} :: { [string]: UpgradeLadder }

-- HUD button order, top to bottom.
Config.UpgradeOrder = { "trowel", "plotSlots" }

-- Placeholder map layout (studs). The lane runs along +Z from the pad.
Config.Map = {
	padPosition = { x = 0, y = 0, z = 0 },
	laneWidth = 60,
	laneLength = 220,
	plotPosition = { x = -50, y = 0, z = -20 },
}

return Config
