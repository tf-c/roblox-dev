--!strict
-- Server entry: builds the map, creates remotes, wires services and player lifecycle.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapBuilder = require(script.Parent.MapBuilder)
local PlayerState = require(script.Parent.PlayerState)
local PlotService = require(script.Parent.PlotService)
local ThrowService = require(script.Parent.ThrowService)
local TrainService = require(script.Parent.TrainService)

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"

local function remote(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end

local trainRemote = remote("Train") -- client -> server
local throwRemote = remote("Throw") -- client -> server (timing 0..1)
local throwResult = remote("ThrowResult") -- server -> client (arc + reveal data)
local buyUpgrade = remote("BuyUpgrade") -- client -> server
local notifyRemote = remote("Notify") -- server -> client (toast text)
remotes.Parent = ReplicatedStorage

MapBuilder.build()
TrainService.init(trainRemote)
PlotService.init(buyUpgrade, notifyRemote)
ThrowService.init(throwRemote, throwResult, notifyRemote)

local function onPlayerAdded(player: Player)
	PlayerState.add(player)
	PlotService.add(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

Players.PlayerRemoving:Connect(function(player: Player)
	PlotService.remove(player)
	PlayerState.remove(player)
	TrainService.forget(player)
	ThrowService.forget(player)
end)
