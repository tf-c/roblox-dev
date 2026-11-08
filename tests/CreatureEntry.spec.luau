--!strict
local Assert = require("./assert")
local Config = require("../src/shared/Config")
local CreatureEntry = require("../src/shared/CreatureEntry")
local luau = (require :: any)("@lune/luau") -- cast: luau-lsp cannot resolve Lune built-ins outside run.luau

local zoneIds = { "lawn", "grove", "wildwood" }

local function full(): any
	return {
		name = "Mochi",
		rarity = "rare",
		income = 12,
		color = "#f2a65a",
		zones = { grove = 30, lawn = 10 },
		look = {
			bundleId = 722,
			accessoryIds = { 1374269, 187846604 },
			removeAccessoryIds = { 55 },
			shirt = 123,
			pants = 456,
			skinColor = "#f5cba7",
			scale = { height = 1.02, width = 0.9, head = 1, proportion = 0, bodyType = 0.25 },
		},
	}
end

local function deepEq(a: any, b: any): boolean
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end
	for k, v in a do
		if not deepEq(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local function roundTrip(def: any): any
	local out = CreatureEntry.format("mochi", def)
	local loaded = luau.load("return {" .. out .. "}")() :: any
	return loaded.mochi
end

return {
	["format round-trips a full entry"] = function()
		local def = full()
		Assert.truthy(deepEq(roundTrip(def), def), "round trip")
	end,

	["format escapes quotes and backslashes in the name"] = function()
		local def = full()
		def.name = 'Mo"chi' .. string.char(92)
		Assert.eq(roundTrip(def).name, def.name)
	end,

	["every Config creature round-trips through format"] = function()
		local ids = {}
		for _, zone in Config.Zones do
			table.insert(ids, zone.id)
		end
		for id, def in Config.Creatures do
			local loaded = luau.load("return {" .. CreatureEntry.format(id, def :: any) .. "}")() :: any
			Assert.truthy(deepEq(loaded[id], def), id)
			Assert.eq(#CreatureEntry.validate(id, def :: any, ids), 0)
		end
	end,

	["format is deterministic"] = function()
		Assert.eq(CreatureEntry.format("mochi", full()), CreatureEntry.format("mochi", full()))
	end,

	["validate accepts a full entry"] = function()
		Assert.eq(#CreatureEntry.validate("mochi", full(), zoneIds), 0)
	end,

	["validate rejects bad entries"] = function()
		local function bad(label: string, id: string?, change: ((any) -> ())?)
			local def = full()
			if change then
				change(def)
			end
			Assert.truthy(#CreatureEntry.validate(id or "mochi", def, zoneIds) > 0, label)
		end
		bad("id with space", "Mochi Cat")
		bad("id starting with digit", "1cat")
		bad("empty name", nil, function(d)
			d.name = ""
		end)
		bad("rarity", nil, function(d)
			d.rarity = "legendary"
		end)
		bad("income 0", nil, function(d)
			d.income = 0
		end)
		bad("income 1.5", nil, function(d)
			d.income = 1.5
		end)
		bad("color", nil, function(d)
			d.color = "orange"
		end)
		bad("no zones", nil, function(d)
			d.zones = {}
		end)
		bad("unknown zone", nil, function(d)
			d.zones = { beach = 5 }
		end)
		bad("zero weight", nil, function(d)
			d.zones = { lawn = 0 }
		end)
		bad("two sources", nil, function(d)
			d.look.outfitId = 5
		end)
		bad("no source", nil, function(d)
			d.look.bundleId = nil
		end)
		bad("accessory id 0", nil, function(d)
			d.look.accessoryIds = { 0 }
		end)
		bad("skinColor", nil, function(d)
			d.look.skinColor = "#fff"
		end)
		bad("scale key", nil, function(d)
			d.look.scale = { tall = 1 }
		end)
	end,
}
