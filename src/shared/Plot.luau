--!strict
-- Pure: which plot slot a newly collected critter goes into. No requires, no Roblox APIs.

local Plot = {}

-- Returns the first free slot. If the plot is full, returns the first
-- lowest-earning slot when `newId` earns more than it; otherwise nil (release).
function Plot.choose(
	slots: { [number]: string },
	newId: string,
	incomeById: { [string]: number },
	slotCount: number
): number?
	local newIncome = incomeById[newId]
	assert(newIncome ~= nil, "Plot.choose: unknown critter " .. newId)

	local worstSlot, worstIncome = nil, math.huge
	for slot = 1, slotCount do
		local id = slots[slot]
		if id == nil then
			return slot
		end
		local income = incomeById[id]
		if income < worstIncome then
			worstSlot, worstIncome = slot, income
		end
	end
	return if newIncome > worstIncome then worstSlot else nil
end

return Plot
