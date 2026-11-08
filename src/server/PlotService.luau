--!strict
-- Each player gets a plot with Config.Plot.slots pedestals. Critters on the plot
-- pay Income.perSecond every second. Also handles the one cash upgrade.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Income = require(ReplicatedStorage.Shared.Income)
local Plot = require(ReplicatedStorage.Shared.Plot)
local CritterVisual = require(script.Parent.CritterVisual)
local MapBuilder = require(script.Parent.MapBuilder)
local PlayerState = require(script.Parent.PlayerState)
local Remotes = require(script.Parent.Remotes)

type PlotVisual = {
	index: number,
	model: Model,
	pedestals: { BasePart },
	critters: { [number]: BasePart },
}

local PlotService = {}

local plots: { [Player]: PlotVisual } = {}
local notify = Remotes.toast

local function freeIndex(): number
	local used: { [number]: boolean } = {}
	for _, plot in plots do
		used[plot.index] = true
	end
	local i = 0
	while used[i] do
		i += 1
	end
	return i
end

local function showCritter(plot: PlotVisual, slot: number, creatureId: string)
	local old = plot.critters[slot]
	if old then
		old:Destroy()
	end
	local part = CritterVisual.make(creatureId)
	local ped = plot.pedestals[slot]
	part.Position = ped.Position + Vector3.new(0, ped.Size.Y / 2 + part.Size.Y / 2, 0)
	part.Parent = plot.model
	plot.critters[slot] = part
end

function PlotService.add(player: Player)
	local index = freeIndex()
	local model, pedestals = MapBuilder.buildPlot(index, player.DisplayName)
	plots[player] = { index = index, model = model, pedestals = pedestals, critters = {} }
end

function PlotService.remove(player: Player)
	local plot = plots[player]
	if plot then
		plot.model:Destroy()
	end
	plots[player] = nil
end

-- Put a critter on the player's plot. If the plot is full, it replaces the
-- lowest-income critter only when it earns more; otherwise it is released.
function PlotService.place(player: Player, creatureId: string)
	local state = PlayerState.get(player)
	local plot = plots[player]
	if not state or not plot then
		return
	end

	local name = Config.Creatures[creatureId].name
	local slot = Plot.choose(state.plot, creatureId, Config.CreatureIncome, Config.Plot.slots)
	if slot == nil then
		notify(player, string.format("Plot full: %s was released", name))
		return
	end

	local replaced = state.plot[slot]
	state.plot[slot] = creatureId
	showCritter(plot, slot, creatureId)
	PlayerState.sync(player)
	if replaced then
		notify(player, string.format("Plot full: %s replaced %s", name, Config.Creatures[replaced].name))
	end
end

-- Where a critter flies to in auto-collect mode.
function PlotService.plotCenter(player: Player): Vector3?
	local plot = plots[player]
	return if plot then plot.model:GetPivot().Position else nil
end

function PlotService.init()
	Remotes.buyUpgrade.OnServerEvent:Connect(function(player: Player)
		local state = PlayerState.get(player)
		if not state or state.upgraded then
			return
		end
		if state.cash < Config.Upgrade.price then
			notify(
				player,
				string.format(
					"Need %d cash for the %s",
					Config.Upgrade.price,
					string.lower(Config.Upgrade.name)
				)
			)
			return
		end
		state.cash -= Config.Upgrade.price
		state.upgraded = true
		PlayerState.sync(player)
		notify(
			player,
			string.format(
				"Bought the %s: %s",
				string.lower(Config.Upgrade.name),
				string.lower(Config.Upgrade.description)
			)
		)
	end)

	-- Income tick.
	task.spawn(function()
		while true do
			task.wait(1)
			for player, state in PlayerState.all() do
				local perSecond = Income.perSecond(state.plot, Config.CreatureIncome)
				if perSecond > 0 then
					state.cash += perSecond
					PlayerState.sync(player)
				end
			end
		end
	end)
end

return PlotService
