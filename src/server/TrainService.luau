--!strict
-- Train: each accepted click raises Power. Rate-limited on the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Upgrade = require(ReplicatedStorage.Shared.Upgrade)
local PlayerState = require(script.Parent.PlayerState)
local RateLimit = require(script.Parent.RateLimit)
local Remotes = require(script.Parent.Remotes)

local TrainService = {}

local limiter = RateLimit.new(Config.Train.maxPerSecond, Config.Train.maxPerSecond)

function TrainService.init()
	Remotes.train.OnServerEvent:Connect(function(player: Player)
		local state = PlayerState.get(player)
		if not state or not limiter:allow(player) then
			return
		end
		local mult = Upgrade.value(Config.Upgrades.trowel, state.levels.trowel)
		state.power += Config.Train.powerPerTrain * mult
		PlayerState.sync(player)
	end)
end

function TrainService.forget(player: Player)
	limiter:forget(player)
end

return TrainService
