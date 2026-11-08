--!strict
-- Pure helpers for turning a catalog bundle into a Creature outfit (used by server/CreatureRigs).

local Outfit = {}

export type BundleItem = { Id: number, Name: string, Type: string }

export type ManualLook = {
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
export type Look = {
	bundleId: number?,
	outfitId: number?,
	manual: ManualLook?,
	accessoryIds: { number }?, -- add on top
	removeAccessoryIds: { number }?, -- take off the source outfit
	skinColor: string?, -- "#rrggbb", all body parts
	scale: { height: number?, width: number?, head: number?, proportion: number?, bodyType: number? }?,
}

local LIST_PROPERTIES: { [string]: string } = {
	hats = "HatAccessory",
	hair = "HairAccessory",
	face = "FaceAccessory",
	neck = "NeckAccessory",
	shoulder = "ShouldersAccessory",
	front = "FrontAccessory",
	back = "BackAccessory",
	waist = "WaistAccessory",
}
local ID_PROPERTIES: { [string]: string } = {
	shirt = "Shirt",
	pants = "Pants",
	graphicTShirt = "GraphicTShirt",
	faceId = "Face",
}

-- Where a look comes from. Exactly one of bundleId, outfitId, manual must be set.
function Outfit.source(look: Look): ("bundle" | "outfit" | "manual")?
	local count = (if look.bundleId then 1 else 0)
		+ (if look.outfitId then 1 else 0)
		+ (if look.manual then 1 else 0)
	if count ~= 1 then
		return nil
	elseif look.bundleId then
		return "bundle"
	elseif look.outfitId then
		return "outfit"
	end
	return "manual"
end

-- Maps the owner-friendly manual table to HumanoidDescription property names.
function Outfit.manualProperties(manual: ManualLook): { [string]: string | number }
	local result: { [string]: string | number } = {}
	local fields = manual :: { [string]: any }
	for field, property in LIST_PROPERTIES do
		local ids = fields[field]
		if ids then
			local parts = {}
			for _, id in ids do
				table.insert(parts, tostring(id))
			end
			result[property] = table.concat(parts, ",")
		end
	end
	for field, property in ID_PROPERTIES do
		if fields[field] then
			result[property] = fields[field]
		end
	end
	return result
end

-- The bundle's outfit id: the first UserOutfit item that isn't a head-only outfit.
function Outfit.pickOutfitId(items: { BundleItem }): number?
	for _, item in items do
		if item.Type == "UserOutfit" and not string.find(item.Name, "Head", 1, true) then
			return item.Id
		end
	end
	return nil
end

-- Appends asset ids to a HumanoidDescription comma-separated accessory string.
function Outfit.withAccessories(existing: string, extra: { number }): string
	local parts = if existing == "" then {} else { existing }
	for _, id in extra do
		table.insert(parts, tostring(id))
	end
	return table.concat(parts, ",")
end

return Outfit
