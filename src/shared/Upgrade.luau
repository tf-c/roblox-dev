--!strict
-- Pure: upgrade ladders. A ladder has a base value and fixed-price levels. No requires, no Roblox APIs.

export type Level = { price: number, value: number }
export type Ladder = { name: string, text: string, base: number, levels: { Level } }

local Upgrade = {}

-- The stat a ladder gives at `level` (0 = not bought).
function Upgrade.value(ladder: Ladder, level: number): number
	return if level == 0 then ladder.base else ladder.levels[level].value
end

-- Price of the next level, or nil when maxed.
function Upgrade.nextPrice(ladder: Ladder, level: number): number?
	local nextLevel = ladder.levels[level + 1]
	return if nextLevel then nextLevel.price else nil
end

function Upgrade.maxValue(ladder: Ladder): number
	return ladder.levels[#ladder.levels].value
end

return Upgrade
