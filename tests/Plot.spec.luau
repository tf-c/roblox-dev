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

	["parseIds: empty string is an empty list"] = function()
		Assert.eq(#Plot.parseIds(""), 0)
	end,

	["parseIds: one id"] = function()
		local ids = Plot.parseIds("pillow")
		Assert.eq(#ids, 1)
		Assert.eq(ids[1], "pillow")
	end,

	["parseIds: keeps slot order"] = function()
		local ids = Plot.parseIds("pillow,slipper")
		Assert.eq(#ids, 2)
		Assert.eq(ids[1], "pillow")
		Assert.eq(ids[2], "slipper")
	end,
}
