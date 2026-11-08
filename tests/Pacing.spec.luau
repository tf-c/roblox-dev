--!strict
-- Simulates a good player's session from Config and checks the milestone times.
-- Model: a perfect throw every cycle, buying greedily. If this fails after a tuning change,
-- the 10-minute pacing target moved.
local Assert = require("./assert")
local Config = require("../src/shared/Config")
local Distance = require("../src/shared/Distance")
local Income = require("../src/shared/Income")
local Plot = require("../src/shared/Plot")
local Upgrade = require("../src/shared/Upgrade")
local WeightedRoll = require("../src/shared/WeightedRoll")
local Zone = require("../src/shared/Zone")

local THROW_SECONDS = 4 -- meter wait plus arc plus auto collect
local TRAIN_SECONDS = 4 -- training between throws
local SEEDS = 50
local MAX_SECONDS = 1200

type Result = { firstBuy: number, firstWildwood: number, lastBuy: number, boughtAll: boolean }

local function simulate(seed: number): Result
	local state = seed
	local function rng(): number
		-- Park-Miller: the product stays below 2^53, so it's exact in Luau numbers.
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end

	local t, power, cash = 0, 0, 0
	local plot: { [number]: string } = {}
	local levels: { [string]: number } = { trowel = 0, plotSlots = 0 }
	local firstBuy, firstWildwood, lastBuy = math.huge, math.huge, math.huge

	local function allBought(): boolean
		for _, id in Config.UpgradeOrder do
			if Upgrade.nextPrice(Config.Upgrades[id], levels[id]) ~= nil then
				return false
			end
		end
		return true
	end

	while t < MAX_SECONDS do
		-- Throw perfectly.
		local distance = Distance.compute(power, Config.Meter.sweetCenter, Config.Distance)
		local zoneId = Zone.forDistance(distance, Config.Zones)
		if zoneId == "wildwood" and firstWildwood == math.huge then
			firstWildwood = t
		end
		local id = WeightedRoll.pick(Config.ZoneTables[zoneId], rng)

		-- Place it.
		local slot = Plot.choose(
			plot,
			id,
			Config.CreatureIncome,
			Upgrade.value(Config.Upgrades.plotSlots, levels.plotSlots)
		)
		if slot ~= nil then
			plot[slot] = id
		end

		-- Train, then earn.
		power += TRAIN_SECONDS * Config.Train.maxPerSecond * Config.Train.powerPerTrain * Upgrade.value(
			Config.Upgrades.trowel,
			levels.trowel
		)
		cash += Income.perSecond(plot, Config.CreatureIncome) * (THROW_SECONDS + TRAIN_SECONDS)
		t += THROW_SECONDS + TRAIN_SECONDS

		-- Buy greedily, cheapest next price first.
		while true do
			local bestId, bestPrice = nil, math.huge
			for _, upgradeId in Config.UpgradeOrder do
				local price = Upgrade.nextPrice(Config.Upgrades[upgradeId], levels[upgradeId])
				if price ~= nil and price < bestPrice then
					bestId, bestPrice = upgradeId, price
				end
			end
			if bestId == nil or cash < bestPrice then
				break
			end
			cash -= bestPrice
			levels[bestId] += 1
			if firstBuy == math.huge then
				firstBuy = t
			end
			lastBuy = t
		end
	end

	return { firstBuy = firstBuy, firstWildwood = firstWildwood, lastBuy = lastBuy, boughtAll = allBought() }
end

local function median(values: { number }): number
	table.sort(values)
	return values[SEEDS // 2 + 1]
end

local results: { Result } = {}
local firstBuys, wildwoods, lastBuys = {}, {}, {}
for seed = 1, SEEDS do
	local r = simulate(seed)
	table.insert(results, r)
	table.insert(firstBuys, r.firstBuy)
	table.insert(wildwoods, r.firstWildwood)
	table.insert(lastBuys, r.lastBuy)
end
local firstBuyMedian, wildwoodMedian, lastBuyMedian = median(firstBuys), median(wildwoods), median(lastBuys)

return {
	["a good player makes a first purchase within a minute"] = function()
		Assert.truthy(firstBuyMedian <= 60, "first buy median " .. firstBuyMedian .. "s")
	end,

	["a good player first reaches wildwood around minute five"] = function()
		Assert.truthy(
			wildwoodMedian >= 240 and wildwoodMedian <= 360,
			"wildwood median " .. wildwoodMedian .. "s"
		)
	end,

	["a good player finishes buying around minute ten"] = function()
		Assert.truthy(
			lastBuyMedian >= 540 and lastBuyMedian <= 720,
			"last buy median " .. lastBuyMedian .. "s"
		)
	end,

	["every simulated session can buy everything"] = function()
		for seed, r in results do
			Assert.truthy(r.boughtAll, "seed " .. seed .. " did not buy everything")
		end
	end,
}
