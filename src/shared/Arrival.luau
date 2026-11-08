--!strict
-- Pure: where an Arrival starts. A Creature runs in from the lane's side edge nearest the Toy.
-- No requires, no Roblox APIs.

local Arrival = {}

-- X of the lane edge (plus `margin` studs outside it) on the Toy's side. Center counts as the right (+X) side.
function Arrival.startX(landX: number, laneWidth: number, margin: number): number
	local side = if landX < 0 then -1 else 1
	return side * (laneWidth / 2 + margin)
end

return Arrival
