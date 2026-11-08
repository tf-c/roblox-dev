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

	["the far zone is reachable with a perfect throw after training"] = function()
		-- Guards against tuning that makes Wildwood impossible.
		local lastZone = Config.Zones[#Config.Zones]
		local d = Config.Distance
		local reach = (d.baseDistance + d.powerScale * math.sqrt(1000)) * Config.Meter.perfectMult
		Assert.truthy(reach >= lastZone.minDistance, "wildwood unreachable at 1000 power")
	end,
}
