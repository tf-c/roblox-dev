--!strict
-- Sanity checks on the balance tables so a typo fails here, not mid-playtest.
local Assert = require("./assert")
local Config = require("../src/shared/Config")
local Outfit = require("../src/shared/Outfit")

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

	["every creature has a valid look"] = function()
		local function validId(value: any, label: string)
			Assert.truthy(type(value) == "number" and value > 0 and value % 1 == 0, label)
		end
		-- Typos in these keys pass the type checker (casts allow extra keys), so catch them here.
		local lookKeys = {
			bundleId = true,
			outfitId = true,
			manual = true,
			accessoryIds = true,
			removeAccessoryIds = true,
			skinColor = true,
			shirt = true,
			pants = true,
			scale = true,
		}
		local scaleKeys = { height = true, width = true, head = true, proportion = true, bodyType = true }
		for id, def in Config.Creatures do
			local look = def.look
			for field in look :: { [string]: any } do
				Assert.truthy(lookKeys[field], "unknown look field " .. field .. " on " .. id)
			end
			if look.manual then
				local given, mapped = 0, 0
				for _ in look.manual :: { [string]: any } do
					given += 1
				end
				for _ in Outfit.manualProperties(look.manual) do
					mapped += 1
				end
				Assert.eq(mapped, given, "unknown manual field on " .. id)
			end
			Assert.truthy(Outfit.source(look) ~= nil, "look source on " .. id)
			if look.bundleId then
				validId(look.bundleId, "bundleId on " .. id)
			end
			if look.outfitId then
				validId(look.outfitId, "outfitId on " .. id)
			end
			local lists: { { number } } = { look.accessoryIds or {}, look.removeAccessoryIds or {} }
			if look.shirt then
				validId(look.shirt, "shirt on " .. id)
			end
			if look.pants then
				validId(look.pants, "pants on " .. id)
			end
			for _, list in lists do
				for _, assetId in list do
					validId(assetId, "accessory id on " .. id)
				end
			end
			for field, value in (look.manual or {}) :: { [string]: any } do
				if type(value) == "table" then
					for _, assetId in value do
						validId(assetId, field .. " on " .. id)
					end
				else
					validId(value, field .. " on " .. id)
				end
			end
			if look.skinColor then
				Assert.truthy(string.match(look.skinColor, "^#%x%x%x%x%x%x$") ~= nil, "skinColor on " .. id)
			end
			for field, value in (look.scale or {}) :: { [string]: number } do
				Assert.truthy(scaleKeys[field] and value >= 0, "scale " .. field .. " on " .. id)
			end
		end
	end,

	["every creature is found in at least one known zone"] = function()
		local zoneIds: { [string]: boolean } = {}
		for _, zone in Config.Zones do
			zoneIds[zone.id] = true
		end
		for id, def in Config.Creatures do
			local count = 0
			for zoneId, weight in def.zones do
				count += 1
				Assert.truthy(zoneIds[zoneId], "unknown zone " .. zoneId .. " on " .. id)
				Assert.truthy(weight > 0, "weight in " .. zoneId .. " on " .. id)
			end
			Assert.truthy(count > 0, "no zones on " .. id)
		end
	end,
}
