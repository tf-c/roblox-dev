--!strict
-- Checks and prints a Config.Creatures entry; used by the catboy maker panel.
-- No requires on purpose: the same file loads in Lune and in Roblox, and Config stays require-free.
local CreatureEntry = {}

export type Entry = {
	name: string,
	rarity: string,
	income: number,
	color: string,
	zones: { [string]: number },
	look: {
		bundleId: number?,
		outfitId: number?,
		manual: any?,
		accessoryIds: { number }?,
		removeAccessoryIds: { number }?,
		shirt: number?,
		pants: number?,
		skinColor: string?,
		scale: { height: number?, width: number?, head: number?, proportion: number?, bodyType: number? }?,
	},
}

local RARITIES = { common = true, rare = true, epic = true }
local SCALE_KEYS = { "height", "width", "head", "proportion", "bodyType" }
local SCALE_SET = { height = true, width = true, head = true, proportion = true, bodyType = true }

local function isId(value: any): boolean
	return type(value) == "number" and value > 0 and value % 1 == 0
end

local function isHex(value: any): boolean
	return type(value) == "string" and string.match(value, "^#%x%x%x%x%x%x$") ~= nil
end

function CreatureEntry.validate(id: string, entry: Entry, zoneIds: { string }): { string }
	local problems: { string } = {}
	local function add(message: string)
		table.insert(problems, message)
	end

	if string.match(id, "^[a-z][a-z0-9]*$") == nil then
		add("The id must be lowercase letters and digits, starting with a letter")
	end
	if entry.name == "" then
		add("Give the catboy a name")
	end
	if not RARITIES[entry.rarity] then
		add("Pick a rarity: common, rare or epic")
	end
	if not isId(entry.income) then
		add("Income must be a whole number above 0")
	end
	if not isHex(entry.color) then
		add("Color must look like #f2a65a")
	end

	local known: { [string]: boolean } = {}
	for _, zoneId in zoneIds do
		known[zoneId] = true
	end
	local zoneCount = 0
	for zoneId, weight in entry.zones do
		zoneCount += 1
		if not known[zoneId] then
			add("Unknown zone: " .. zoneId)
		end
		if not isId(weight) then
			add("The weight for " .. zoneId .. " must be a whole number above 0")
		end
	end
	if zoneCount == 0 then
		add("Pick at least one zone")
	end

	local look = entry.look
	-- Same rule as Outfit.source: exactly one of bundleId, outfitId, manual.
	local sources = (if look.bundleId then 1 else 0)
		+ (if look.outfitId then 1 else 0)
		+ (if look.manual then 1 else 0)
	if sources ~= 1 then
		add("Pick exactly one look source: a bundle or an outfit")
	end
	local single: { [string]: number? } =
		{ bundleId = look.bundleId, outfitId = look.outfitId, shirt = look.shirt, pants = look.pants }
	for field, value in single do
		if not isId(value) then
			add("The " .. field .. " must be a catalog id")
		end
	end
	local lists: { { number } } = { look.accessoryIds or {}, look.removeAccessoryIds or {} }
	for _, ids in lists do
		for _, assetId in ids do
			if not isId(assetId) then
				add("Accessory ids must be catalog ids")
				break
			end
		end
	end
	if look.skinColor ~= nil and not isHex(look.skinColor) then
		add("Skin color must look like #f5cba7")
	end
	for field, value in (look.scale or {}) :: { [string]: number } do
		if not SCALE_SET[field] or type(value) ~= "number" or value < 0 then
			add("Bad scale value: " .. field)
		end
	end
	return problems
end

local function number(value: number): string
	if value % 1 == 0 then
		return string.format("%d", value)
	end
	local text = string.format("%.2f", value)
	return (string.gsub(string.gsub(text, "0+$", ""), "%.$", ""))
end

local function list(values: { number }): string
	local parts = {}
	for _, value in values do
		table.insert(parts, number(value))
	end
	return "{ " .. table.concat(parts, ", ") .. " }"
end

function CreatureEntry.format(id: string, entry: Entry): string
	local look = entry.look
	if look.manual then
		error("manual looks are not supported")
	end

	local zoneIds = {}
	for zoneId in entry.zones do
		table.insert(zoneIds, zoneId)
	end
	table.sort(zoneIds)
	local zones = {}
	for _, zoneId in zoneIds do
		table.insert(zones, zoneId .. " = " .. number(entry.zones[zoneId]))
	end

	local parts = {}
	if look.bundleId then
		table.insert(parts, "bundleId = " .. number(look.bundleId))
	end
	if look.outfitId then
		table.insert(parts, "outfitId = " .. number(look.outfitId))
	end
	if look.accessoryIds then
		table.insert(parts, "accessoryIds = " .. list(look.accessoryIds))
	end
	if look.removeAccessoryIds then
		table.insert(parts, "removeAccessoryIds = " .. list(look.removeAccessoryIds))
	end
	if look.shirt then
		table.insert(parts, "shirt = " .. number(look.shirt))
	end
	if look.pants then
		table.insert(parts, "pants = " .. number(look.pants))
	end
	if look.skinColor then
		table.insert(parts, string.format("skinColor = %q", look.skinColor))
	end
	if look.scale then
		local scale = {}
		for _, key in SCALE_KEYS do
			local value = (look.scale :: { [string]: number? })[key]
			if value then
				table.insert(scale, key .. " = " .. number(value))
			end
		end
		table.insert(parts, "scale = { " .. table.concat(scale, ", ") .. " }")
	end

	return table.concat({
		"\t" .. id .. " = {",
		"\t\tname = " .. string.format("%q", entry.name) .. ",",
		"\t\trarity = " .. string.format("%q", entry.rarity) .. ",",
		"\t\tincome = " .. number(entry.income) .. ",",
		"\t\tcolor = " .. string.format("%q", entry.color) .. ",",
		"\t\tzones = { " .. table.concat(zones, ", ") .. " },",
		"\t\tlook = { " .. table.concat(parts, ", ") .. " },",
		"\t},",
	}, "\n")
end

return CreatureEntry
