--!strict
local Arrival = require("../src/shared/Arrival")
local Assert = require("./assert")

return {
	["a toy right of center comes from the right edge"] = function()
		Assert.eq(Arrival.startX(5, 60, 2), 32)
	end,

	["a toy left of center comes from the left edge"] = function()
		Assert.eq(Arrival.startX(-0.5, 60, 2), -32)
	end,

	["a toy dead center comes from the right edge"] = function()
		Assert.eq(Arrival.startX(0, 60, 2), 32)
	end,
}
