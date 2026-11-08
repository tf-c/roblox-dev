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
}
