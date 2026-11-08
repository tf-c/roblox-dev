--!strict
-- Pure: cash per second for a plot. No requires, no Roblox APIs.

local Income = {}

-- `slots` maps slot index -> critter id and may have gaps.
-- `incomeById` maps critter id -> cash per second (Config.CreatureIncome).
function Income.perSecond(slots: { [number]: string }, incomeById: { [string]: number }): number
	local total = 0
	for _, id in slots do
		local income = incomeById[id]
		assert(income ~= nil, "Income.perSecond: unknown critter " .. tostring(id))
		total += income
	end
	return total
end

return Income
