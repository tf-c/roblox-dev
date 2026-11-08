--!strict
local Assert = require("./assert")
local Zone = require("../src/shared/Zone")

local zones = {
	{ id = "lawn", minDistance = 0 },
	{ id = "grove", minDistance = 60 },
	{ id = "wildwood", minDistance = 130 },
}

return {
	["picks the zone whose range contains the distance"] = function()
		Assert.eq(Zone.forDistance(10, zones), "lawn")
		Assert.eq(Zone.forDistance(95, zones), "grove")
		Assert.eq(Zone.forDistance(200, zones), "wildwood")
	end,

	["boundaries belong to the farther zone"] = function()
		Assert.eq(Zone.forDistance(0, zones), "lawn")
		Assert.eq(Zone.forDistance(59.999, zones), "lawn")
		Assert.eq(Zone.forDistance(60, zones), "grove")
		Assert.eq(Zone.forDistance(129.999, zones), "grove")
		Assert.eq(Zone.forDistance(130, zones), "wildwood")
	end,

	["below the first zone falls back to the first zone"] = function()
		Assert.eq(Zone.forDistance(-5, zones), "lawn")
		Assert.eq(Zone.forDistance(0 / 0, zones), "lawn")
	end,

	["far beyond the last zone stays in the last zone"] = function()
		Assert.eq(Zone.forDistance(1e9, zones), "wildwood")
	end,

	["no zones is a config error"] = function()
		Assert.throws(function()
			Zone.forDistance(10, {})
		end)
	end,
}
