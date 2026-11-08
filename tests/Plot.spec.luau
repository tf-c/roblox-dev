--!strict
local Assert = require("./assert")
local Plot = require("../src/shared/Plot")

local income = { low = 1, mid = 5, high = 20 }

local function full(): { [number]: string }
	return { "mid", "low", "high", "low" }
end

return {
	["an empty plot takes slot 1"] = function()
		Assert.eq(Plot.choose({}, "low", income, 4), 1)
	end,

	["fills the first gap"] = function()
		Assert.eq(Plot.choose({ [1] = "mid", [3] = "high" }, "low", income, 4), 2)
	end,

	["full plot: a better critter replaces the first lowest earner"] = function()
		Assert.eq(Plot.choose(full(), "mid", income, 4), 2)
	end,

	["full plot: an equal or worse critter is released"] = function()
		Assert.eq(Plot.choose(full(), "low", income, 4), nil)
	end,

	["an unknown critter id is a config error"] = function()
		Assert.throws(function()
			Plot.choose(full(), "typo", income, 4)
		end)
	end,
}
