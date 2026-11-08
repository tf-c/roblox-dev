--!strict
local Assert = require("./assert")
local Config = require("../src/shared/Config")
local Upgrade = require("../src/shared/Upgrade")

local ladder: Upgrade.Ladder = {
	name = "Test",
	text = "%d",
	base = 1,
	levels = { { price = 10, value = 2 }, { price = 50, value = 5 } },
}

return {
	["level 0 gives the base value"] = function()
		Assert.eq(Upgrade.value(ladder, 0), 1)
	end,

	["each level gives its own value"] = function()
		Assert.eq(Upgrade.value(ladder, 1), 2)
		Assert.eq(Upgrade.value(ladder, 2), 5)
	end,

	["next price is the next level's price"] = function()
		Assert.eq(Upgrade.nextPrice(ladder, 0), 10)
		Assert.eq(Upgrade.nextPrice(ladder, 1), 50)
	end,

	["a maxed ladder has no next price"] = function()
		Assert.eq(Upgrade.nextPrice(ladder, 2), nil)
	end,

	["max value is the last level's value"] = function()
		Assert.eq(Upgrade.maxValue(ladder), 5)
	end,

	["startLevels gives every listed ladder level 0"] = function()
		local levels = Upgrade.startLevels({ "a", "b" })
		Assert.eq(levels.a, 0)
		Assert.eq(levels.b, 0)
		local count = 0
		for _ in levels do
			count += 1
		end
		Assert.eq(count, 2)
	end,

	["startLevels covers Config.UpgradeOrder"] = function()
		local levels = Upgrade.startLevels(Config.UpgradeOrder)
		for _, id in Config.UpgradeOrder do
			Assert.eq(levels[id], 0)
		end
	end,
}
