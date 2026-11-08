--!strict
-- Pure helpers for turning a catalog bundle into a Creature outfit (used by server/CreatureRigs).

local Outfit = {}

export type BundleItem = { Id: number, Name: string, Type: string }

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
