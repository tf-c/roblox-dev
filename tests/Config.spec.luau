--!strict
-- Sanity checks on the balance tables so a typo fails here, not mid-playtest.
local Assert = require("./assert")
local Config = require("../src/shared/Config")

local RARITIES = { common = true, rare = true, epic = true }

return {
	["zones are in ascending distance order and start at 0"] = function()
		Assert.eq(Config.Zones[1].minDistance, 0)
		for i = 2, #Config.Zones do
			Assert.truthy(Config.Zones[i].minDistance > Config.Zones[i - 1].minDistance, Config.Zones[i].id)
		end
	end,

	["every zone has a spawn table of known critters"] = function()
		for _, zone in Config.Zones do
			local entries = Config.ZoneTables[zone.id]
			Assert.truthy(entries and #entries > 0, "missing table for " .. zone.id)
			for _, entry in entries do
				Assert.truthy(Config.Creatures[entry.id] ~= nil, "unknown critter " .. entry.id)
				Assert.truthy(entry.weight > 0, "non-positive weight for " .. entry.id)
			end
		end
	end,

	["every zone has a name and hex color"] = function()
		for _, zone in Config.Zones do
			local look = Config.ZoneLooks[zone.id]
			Assert.truthy(look ~= nil, "missing look for " .. zone.id)
			Assert.truthy(string.match(look.color, "^#%x%x%x%x%x%x$") ~= nil, "color on " .. zone.id)
		end
	end,

	["every critter has a rarity, positive income and a hex color"] = function()
		for id, creature in Config.Creatures do
			Assert.truthy(RARITIES[creature.rarity], "bad rarity on " .. id)
			Assert.truthy(creature.income > 0, "income on " .. id)
			Assert.truthy(string.match(creature.color, "^#%x%x%x%x%x%x$") ~= nil, "color on " .. id)
		end
	end,

	["collect mode is walk or auto"] = function()
		Assert.truthy(Config.CollectMode == "walk" or Config.CollectMode == "auto")
	end,

	["upgrade order lists every upgrade exactly once"] = function()
		local seen = 0
		for _, id in Config.UpgradeOrder do
			Assert.truthy(Config.Upgrades[id] ~= nil, "unknown upgrade " .. id)
			seen += 1
		end
		local total = 0
		for _ in Config.Upgrades do
			total += 1
		end
		Assert.eq(seen, total)
	end,

	["upgrade ladders rise in price and value"] = function()
		for id, ladder in Config.Upgrades do
			Assert.truthy(ladder.levels[1].value > ladder.base, "first level value on " .. id)
			local lastPrice, lastValue = 0, ladder.base
			for _, level in ladder.levels do
				Assert.truthy(level.price > lastPrice, "price order on " .. id)
				Assert.truthy(level.value > lastValue, "value order on " .. id)
				lastPrice, lastValue = level.price, level.value
			end
		end
	end,

	["every theme text is a non-empty string"] = function()
		for _, key in
			{ "collectAction", "pendingBlocked", "wanderedOff", "walkHint", "plotReleased", "plotReplaced" }
		do
			local text = Config.Text[key]
			Assert.truthy(type(text) == "string" and #text > 0, key)
		end
	end,

	["theme text has the right number of %s slots"] = function()
		local expected: { [string]: number } = {
			wanderedOff = 1,
			plotReleased = 1,
			plotReplaced = 2,
			collectAction = 0,
			pendingBlocked = 0,
			walkHint = 0,
		}
		for key, count in expected do
			Assert.eq(
				select(2, string.gsub((Config.Text :: { [string]: string })[key], "%%s", "")),
				count,
				key
			)
		end
	end,

	["projectile look is valid"] = function()
		local p = Config.Projectile
		Assert.truthy(type(p.name) == "string" and #p.name > 0, "name")
		Assert.truthy(p.size > 0, "size")
		Assert.truthy(string.match(p.color, "^#%x%x%x%x%x%x$") ~= nil, "color")
	end,

	["starter catboys fill the six creature slots"] = function()
		local tables: { [string]: { { string | number } } } = {
			lawn = { { "pillow", 80 }, { "slipper", 20 } },
			grove = { { "pickle", 75 }, { "caramel", 25 } },
			wildwood = { { "satin", 85 }, { "linden", 15 } },
		}
		for zone, expected in tables do
			for i, want in expected do
				local entry = Config.ZoneTables[zone][i]
				Assert.eq(entry.id, want[1], zone)
				Assert.eq(entry.weight, want[2], zone)
			end
		end
		local stats: { [string]: { string | number } } = {
			pillow = { "common", 1 },
			slipper = { "rare", 4 },
			pickle = { "common", 3 },
			caramel = { "rare", 10 },
			satin = { "rare", 25 },
			linden = { "epic", 80 },
		}
		for id, want in stats do
			local def = Config.Creatures[id]
			Assert.truthy(def ~= nil, id)
			Assert.eq(def.rarity, want[1], id)
			Assert.eq(def.income, want[2], id)
		end
		local count = 0
		for _ in Config.Creatures do
			count += 1
		end
		Assert.eq(count, 6)
	end,

	["zone names are Backyard, Park, Meadow"] = function()
		Assert.eq(Config.ZoneLooks.lawn.name, "Backyard")
		Assert.eq(Config.ZoneLooks.grove.name, "Park")
		Assert.eq(Config.ZoneLooks.wildwood.name, "Meadow")
	end,

	["player-facing text never says critter or seed"] = function()
		local texts: { string } = {}
		for _, text in Config.Text :: { [string]: string } do
			table.insert(texts, text)
		end
		table.insert(texts, Config.Projectile.name)
		for _, def in Config.Creatures do
			table.insert(texts, def.name)
		end
		for _, text in texts do
			local lower = string.lower(text)
			Assert.eq(string.find(lower, "critter", 1, true), nil, text)
			Assert.eq(string.find(lower, "seed", 1, true), nil, text)
		end
	end,

	["the toy is a yarn ball that rests after landing"] = function()
		Assert.eq(Config.Projectile.name, "Yarn ball")
		Assert.truthy(Config.Projectile.restSeconds > 0, "restSeconds")
	end,

	["arrival finishes before auto collect starts"] = function()
		local a = Config.Arrival
		Assert.truthy(a.runSeconds > 0, "runSeconds")
		Assert.truthy(a.hopSeconds > 0, "hopSeconds")
		Assert.truthy(a.hopHeight > 0, "hopHeight")
		Assert.truthy(a.edgeMargin >= 0, "edgeMargin")
		Assert.truthy(a.runSeconds + a.hopSeconds < Config.AutoCollectDelaySeconds, "timing budget")
	end,

	["creature bundles name known creatures and valid ids"] = function()
		for id, look in Config.CreatureBundles do
			Assert.truthy(Config.Creatures[id] ~= nil, "unknown creature " .. id)
			Assert.truthy(look.bundleId > 0 and look.bundleId % 1 == 0, "bundleId on " .. id)
			local accessoryIds: { number } = look.accessoryIds or {}
			for _, accessoryId in accessoryIds do
				Assert.truthy(accessoryId > 0 and accessoryId % 1 == 0, "accessoryId on " .. id)
			end
		end
	end,
}
