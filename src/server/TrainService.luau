--!strict
-- Train: each accepted click raises Power. Rate-limited on the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerState = require(script.Parent.PlayerState)
local RateLimit = require(script.Parent.RateLimit)

local TrainService = {}

local limiter = RateLimit.new(Config.Train.maxPerSecond, Config.Train.maxPerSecond)

function TrainService.init(trainRemote: RemoteEvent)
	trainRemote.OnServerEvent:Connect(function(player: Player)
		local state = PlayerState.get(player)
		if not state or not limiter:allow(player) then
			return
		end
		local mult = if state.upgraded then Config.Upgrade.powerMultiplier else 1
		state.power += Config.Train.powerPerTrain * mult
		PlayerState.sync(player)
	end)
end

function TrainService.forget(player: Player)
	limiter:forget(player)
end

return TrainService
