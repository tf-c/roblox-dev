--!strict
-- Pure: pick one id from a weighted table. The random source is injected so
-- tests can seed it. No requires, no Roblox APIs.

export type Entry = {
	id: string,
	weight: number,
}

local WeightedRoll = {}

-- `rng` returns a number in [0, 1). A value of exactly 1 is tolerated and
-- returns the last entry with positive weight.
function WeightedRoll.pick(entries: { Entry }, rng: () -> number): string
	local total = 0
	local last: string? = nil
	for _, entry in entries do
		assert(entry.weight >= 0, "WeightedRoll.pick: negative weight on " .. entry.id)
		total += entry.weight
		if entry.weight > 0 then
			last = entry.id
		end
	end
	assert(total > 0 and last ~= nil, "WeightedRoll.pick: table has no positive weights")

	local target = rng() * total
	local cumulative = 0
	for _, entry in entries do
		cumulative += entry.weight
		if entry.weight > 0 and target < cumulative then
			return entry.id
		end
	end
	return last :: string
end

return WeightedRoll
