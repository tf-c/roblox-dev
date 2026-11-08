--!strict
-- Pure: which distance zone a throw landed in. No requires, no Roblox APIs.

export type ZoneDef = {
	id: string,
	minDistance: number,
}

local Zone = {}

-- `zones` must be sorted by ascending minDistance (Config.spec checks this).
-- Returns the last zone whose minDistance <= distance; anything below the
-- first zone (including NaN) falls back to the first zone.
function Zone.forDistance(distance: number, zones: { ZoneDef }): string
	assert(#zones > 0, "Zone.forDistance: no zones configured")
	local picked = zones[1].id
	for _, zone in zones do
		if distance >= zone.minDistance then
			picked = zone.id
		end
	end
	return picked
end

return Zone
