--!strict
local Assert = require("./assert")
local Income = require("../src/shared/Income")

local creatures = {
	sproutling = 2,
	bloomdrake = 40,
}

return {
	["an empty plot pays nothing"] = function()
		Assert.eq(Income.perSecond({}, creatures), 0)
	end,

	["sums income over filled slots, including gaps"] = function()
		local slots: { [number]: string } = { [1] = "sproutling", [4] = "bloomdrake" }
		Assert.eq(Income.perSecond(slots, creatures), 42)
	end,

	["duplicate critters each pay"] = function()
		Assert.eq(Income.perSecond({ "sproutling", "sproutling", "sproutling" }, creatures), 6)
	end,

	["an unknown critter id is a config error"] = function()
		Assert.throws(function()
			Income.perSecond({ "typo" }, creatures)
		end)
	end,
}
