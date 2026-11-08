--!strict
local Assert = require("./assert")
local WeightedRoll = require("../src/shared/WeightedRoll")

local function fixed(value: number): () -> number
	return function()
		return value
	end
end

-- Small deterministic LCG so the distribution test is repeatable.
local function lcg(seed: number): () -> number
	local state = seed
	return function()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
end

local aOneBThree = { { id = "a", weight = 1 }, { id = "b", weight = 3 } }

return {
	["fixed rng values map to the expected entry"] = function()
		Assert.eq(WeightedRoll.pick(aOneBThree, fixed(0)), "a")
		Assert.eq(WeightedRoll.pick(aOneBThree, fixed(0.249)), "a")
		Assert.eq(WeightedRoll.pick(aOneBThree, fixed(0.25)), "b")
		Assert.eq(WeightedRoll.pick(aOneBThree, fixed(0.999)), "b")
	end,

	["zero weight is never picked"] = function()
		local entries = { { id = "never", weight = 0 }, { id = "always", weight = 1 } }
		Assert.eq(WeightedRoll.pick(entries, fixed(0)), "always")
		Assert.eq(WeightedRoll.pick(entries, fixed(0.5)), "always")
	end,

	["an rng value of 1 still returns a valid entry"] = function()
		local entries = { { id = "a", weight = 1 }, { id = "b", weight = 1 }, { id = "zero", weight = 0 } }
		Assert.eq(WeightedRoll.pick(entries, fixed(1)), "b")
	end,

	["empty, all-zero or negative tables are config errors"] = function()
		Assert.throws(function()
			WeightedRoll.pick({}, fixed(0))
		end)
		Assert.throws(function()
			WeightedRoll.pick({ { id = "a", weight = 0 } }, fixed(0))
		end)
		Assert.throws(function()
			WeightedRoll.pick({ { id = "a", weight = -1 }, { id = "b", weight = 2 } }, fixed(0))
		end)
	end,

	["10k seeded rolls match the weights within 2 percent"] = function()
		local entries =
			{ { id = "common", weight = 70 }, { id = "rare", weight = 25 }, { id = "epic", weight = 5 } }
		local counts: { [string]: number } = { common = 0, rare = 0, epic = 0 }
		local rng = lcg(42)
		local n = 10000
		for _ = 1, n do
			local id = WeightedRoll.pick(entries, rng)
			counts[id] += 1
		end
		Assert.near(counts.common / n, 0.70, 0.02, "common")
		Assert.near(counts.rare / n, 0.25, 0.02, "rare")
		Assert.near(counts.epic / n, 0.05, 0.02, "epic")
	end,
}
