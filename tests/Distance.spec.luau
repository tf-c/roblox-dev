--!strict
local Assert = require("./assert")
local Distance = require("../src/shared/Distance")

local cfg = {
	baseDistance = 20,
	powerScale = 6,
	meter = { sweetCenter = 0.5, sweetHalfWidth = 0.08, perfectMult = 1.5, edgeMult = 0.5 },
}

return {
	["perfect timing beats an edge hit"] = function()
		Assert.truthy(Distance.compute(100, 0.5, cfg) > Distance.compute(100, 0, cfg))
		Assert.truthy(Distance.compute(100, 0.5, cfg) > Distance.compute(100, 1, cfg))
	end,

	["whole sweet spot gives the perfect multiplier"] = function()
		local perfect = Distance.compute(0, 0.5, cfg)
		Assert.eq(perfect, 20 * 1.5)
		Assert.eq(Distance.compute(0, 0.42, cfg), perfect)
		Assert.eq(Distance.compute(0, 0.58, cfg), perfect)
	end,

	["also returns the meter multiplier it used"] = function()
		local _, mult = Distance.compute(100, 0.21, cfg)
		Assert.near(mult, 1.0, 1e-9)
		local _, perfect = Distance.compute(100, 0.5, cfg)
		Assert.eq(perfect, 1.5)
	end,

	["edges give the edge multiplier"] = function()
		Assert.eq(Distance.compute(0, 0, cfg), 20 * 0.5)
		Assert.eq(Distance.compute(0, 1, cfg), 20 * 0.5)
	end,

	["multiplier falls off linearly outside the sweet spot"] = function()
		-- Halfway between 0 and the sweet spot start (0.42) is 0.21 -> mult 1.0
		Assert.near(Distance.compute(0, 0.21, cfg), 20, 1e-9)
		-- Halfway between the sweet spot end (0.58) and 1 is 0.79 -> mult 1.0
		Assert.near(Distance.compute(0, 0.79, cfg), 20, 1e-9)
	end,

	["more power throws farther with diminishing returns"] = function()
		local d0 = Distance.compute(0, 0.5, cfg)
		local d100 = Distance.compute(100, 0.5, cfg)
		local d200 = Distance.compute(200, 0.5, cfg)
		Assert.truthy(d100 > d0)
		Assert.truthy(d200 > d100)
		Assert.truthy(d100 - d0 > d200 - d100, "gain should shrink as power grows")
	end,

	["power zero still gives a positive distance"] = function()
		Assert.truthy(Distance.compute(0, 0, cfg) > 0)
	end,

	["timing is clamped to 0..1"] = function()
		Assert.eq(Distance.compute(50, -3, cfg), Distance.compute(50, 0, cfg))
		Assert.eq(Distance.compute(50, 7, cfg), Distance.compute(50, 1, cfg))
	end,

	["bad timing from the client is treated as 0"] = function()
		local edge = Distance.compute(50, 0, cfg)
		Assert.eq(Distance.compute(50, 0 / 0, cfg), edge)
		Assert.eq(Distance.compute(50, "perfect" :: any, cfg), edge)
		Assert.eq(Distance.compute(50, nil :: any, cfg), edge)
	end,

	["negative or NaN power is treated as 0"] = function()
		local base = Distance.compute(0, 0.5, cfg)
		Assert.eq(Distance.compute(-10, 0.5, cfg), base)
		Assert.eq(Distance.compute(0 / 0, 0.5, cfg), base)
	end,
}
