--!strict
-- Server entry: builds the map, wires services and player lifecycle.
-- Remotes are created when Remotes.luau is first required (by the services below).

local Players = game:GetService("Players")

local CatboyMaker = require(script.Parent.CatboyMaker)
local CreatureRigs = require(script.Parent.CreatureRigs)
local MapBuilder = require(script.Parent.MapBuilder)
local PlayerState = require(script.Parent.PlayerState)
local PlotService = require(script.Parent.PlotService)
local ThrowService = require(script.Parent.ThrowService)
local TrainService = require(script.Parent.TrainService)

MapBuilder.build()
CreatureRigs.preload()
CatboyMaker.init()
TrainService.init()
PlotService.init()
ThrowService.init()

local function onPlayerAdded(player: Player)
	PlayerState.add(player)
	PlotService.add(player)
	CatboyMaker.add(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

Players.PlayerRemoving:Connect(function(player: Player)
	ThrowService.forget(player) -- before PlayerState.remove: it reads the pending critter
	PlotService.remove(player)
	PlayerState.remove(player)
	TrainService.forget(player)
	CatboyMaker.forget(player)
end)
