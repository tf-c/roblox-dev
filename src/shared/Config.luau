--!strict
-- All balance and tuning numbers live here, so balancing never touches code.
-- Pure data: no requires, no Roblox APIs (colors are hex strings), so Lune can test it.
--
-- POLICY RULES (from roblox-researcher policy_check.md), keep these true:
--   * Spawns stay free. Zone weights (`zones` on each creature, which build
--     ZoneTables) are fixed; nothing bought with Robux, or with cash bought with Robux, may change them.
--   * Power changes throw distance, and therefore zone and rarity. So Power must
--     NEVER be sold for Robux (no paid x2 Power, no Power developer products).
--   * Cash is never spent on a random roll. Cash buys fixed items only (see Upgrades).
--   * Players throw a toy at the ground; creatures come to it. Nothing is thrown at creatures.

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
	lawn = { name = "Backyard", color = "#8fd16a" },
	grove = { name = "Park", color = "#3f9b4b" },
	wildwood = { name = "Meadow", color = "#24543a" },
}

-- Same shape as Outfit.ManualLook / Outfit.Look (Config stays require-free).
type ManualLook = {
	hats: { number }?,
	hair: { number }?,
	face: { number }?,
	neck: { number }?,
	shoulder: { number }?,
	front: { number }?,
	back: { number }?,
	waist: { number }?,
	shirt: number?,
	pants: number?,
	graphicTShirt: number?,
	faceId: number?,
}
export type CreatureLook = {
	bundleId: number?,
	outfitId: number?,
	manual: ManualLook?,
	accessoryIds: { number }?,
	removeAccessoryIds: { number }?,
	skinColor: string?,
	scale: { height: number?, width: number?, head: number?, proportion: number?, bodyType: number? }?,
}

export type Creature = {
	name: string,
	rarity: string, -- "common" | "rare" | "epic" (Config.spec checks)
	income: number,
	color: string,
	zones: { [string]: number }, -- zone id -> spawn weight in that zone
	look: CreatureLook,
}

-- Starter catboys (original designs, roster ids from roblox-researcher): 2 per zone.
-- `color` is the ears, tail and hair. Income is cash per second while on the plot.
--
-- To add a catboy: copy an entry, give it a new id key, then set:
--   name, rarity ("common", "rare" or "epic"), income (cash per second),
--   zones: zone id -> spawn weight (lawn = Backyard, grove = Park, wildwood = Meadow),
--   look: exactly one of bundleId (the number in the catalog bundle URL), outfitId, or
--     manual = { hats = { ... }, hair = { ... }, shirt = ..., pants = ... }.
--   Optional on top of any look: accessoryIds, removeAccessoryIds, skinColor ("#rrggbb"), scale.
-- The server builds an R15 rig from `look` at start. A look that fails to load keeps the placeholder rig.
-- Keep every look fully clothed: no collars, leashes, chains or chokers.
-- All items below are Roblox-made (free bodies; Kitty Ears 1374269, Fuchsia Kitty Ears 22070807,
-- Purple Cat Ears Headphones 244159564; Orange 187846604, Grey 170892848, Rainbow 212358027 cat tails).
-- Avoid Oakley/John/Casey: their left leg detaches when the rig is anchored.
Config.Creatures = {
	pillow = {
		name = "Pillow",
		rarity = "common",
		income = 1,
		color = "#f2a65a",
		zones = { lawn = 80 },
		look = { bundleId = 722, accessoryIds = { 1374269, 187846604 } }, -- Denny, Kitty Ears, orange tail
	},
	slipper = {
		name = "Slipper",
		rarity = "rare",
		income = 4,
		color = "#f48fb1",
		zones = { lawn = 20 },
		look = { bundleId = 605, accessoryIds = { 22070807, 170892848 } }, -- Dennis, Fuchsia Kitty Ears, grey tail
	},
	pickle = {
		name = "Pickle",
		rarity = "common",
		income = 3,
		color = "#2f2f36",
		zones = { grove = 75 },
		look = { bundleId = 608, accessoryIds = { 1374269, 170892848 } }, -- Kenneth, Kitty Ears, grey tail
	},
	caramel = {
		name = "Caramel",
		rarity = "rare",
		income = 10,
		color = "#f7c59f",
		zones = { grove = 25 },
		look = { bundleId = 109, accessoryIds = { 1374269, 187846604 } }, -- ROBLOX Boy, Kitty Ears, orange tail
	},
	satin = {
		name = "Satin",
		rarity = "rare",
		income = 25,
		color = "#5a5d66",
		zones = { wildwood = 85 },
		look = { bundleId = 573, accessoryIds = { 1374269, 170892848 } }, -- Oliver, Kitty Ears, grey tail
	},
	linden = {
		name = "Linden",
		rarity = "epic",
		income = 80,
		color = "#c8a2e8",
		zones = { wildwood = 15 },
		look = { bundleId = 572, accessoryIds = { 244159564, 212358027 } }, -- Summer, Cat Ears Headphones, rainbow tail
	},
} :: { [string]: Creature }

-- Derived lookup for Income.perSecond: creature id -> cash per second.
Config.CreatureIncome = {} :: { [string]: number }
for id, creature in Config.Creatures do
	Config.CreatureIncome[id] = creature.income
end

-- Free, fixed spawn odds per zone, built from each creature's `zones`. See POLICY RULES above.
-- Heaviest weight first, ties by id, so the order is stable for the seeded tests.
Config.ZoneTables = {} :: { [string]: { { id: string, weight: number } } }
for _, zone in Config.Zones do
	local entries: { { id: string, weight: number } } = {}
	for id, creature in Config.Creatures do
		local weight = creature.zones[zone.id]
		if weight then
			table.insert(entries, { id = id, weight = weight })
		end
	end
	table.sort(entries, function(a, b)
		if a.weight ~= b.weight then
			return a.weight > b.weight
		end
		return a.id < b.id
	end)
	Config.ZoneTables[zone.id] = entries
end

Config.RarityColors = {
	common = "#d9d9d9",
	rare = "#4aa3ff",
	epic = "#c45cff",
}

-- Player-facing theme words. The reskin changes these, not code. %s = creature name.
Config.Text = {
	collectAction = "Collect",
	pendingBlocked = "Your catboy is still on the way",
	wanderedOff = "%s wandered off",
	walkHint = "Walk to your catboy to collect it",
	plotReleased = "Plot full: %s was released",
	plotReplaced = "Plot full: %s replaced %s",
}

-- The Toy the player throws down the lane (client visual only). It rests on a glowing ring for `restSeconds` after landing.
Config.Projectile = { name = "Yarn ball", color = "#e2574c", size = 1.6, restSeconds = 2 }

Config.Train = {
	powerPerTrain = 1,
	maxPerSecond = 8,
}

Config.Throw = {
	cooldownSeconds = 1.5,
	arcSeconds = 1.2, -- toy flight time before the arrival starts
	arcHeight = 25,
}

-- "walk": walk to the catboy and use its prompt. "auto": it hops to your plot after it arrives.
Config.CollectMode = "auto" :: "walk" | "auto"
Config.AutoCollectDelaySeconds = 1.5
-- Arrival: the creature runs in from the lane's side edge to the toy, then hops and turns to face the player.
-- runSeconds + hopSeconds must stay under AutoCollectDelaySeconds (Config.spec checks), so throw pacing is unchanged.
Config.Arrival = { runSeconds = 0.6, hopSeconds = 0.25, hopHeight = 1.5, edgeMargin = 2 }
Config.PendingTimeoutSeconds = 45 -- an uncollected creature wanders off after this, so throws never lock up

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
