--!strict
-- The server decides the throw. The client sends only the meter timing (0..1).
-- Server: distance from Power + timing, zone from distance, free weighted roll,
-- then a critter sprouts where the seed lands.
--
-- Known prototype gap: a modified client can always send a perfect timing.
-- Harden later (e.g. server-timed meter) before anything of value rides on it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Distance = require(ReplicatedStorage.Shared.Distance)
local WeightedRoll = require(ReplicatedStorage.Shared.WeightedRoll)
local Zone = require(ReplicatedStorage.Shared.Zone)
local CritterVisual = require(script.Parent.CritterVisual)
local MapBuilder = require(script.Parent.MapBuilder)
local PlayerState = require(script.Parent.PlayerState)
local PlotService = require(script.Parent.PlotService)
local RateLimit = require(script.Parent.RateLimit)

local ThrowService = {}

local rng = Random.new()
local function nextNumber(): number
	return rng:NextNumber()
end

-- Backstop against remote spam; the real pacing is the cooldown below.
local limiter = RateLimit.new(2, 3)
local nextToken = 0
local notifyRemote: RemoteEvent? = nil
local fieldFolder: Folder? = nil

local function notify(player: Player, text: string)
	if notifyRemote then
		notifyRemote:FireClient(player, text)
	end
end

local function clearPending(player: Player, token: number): boolean
	local state = PlayerState.get(player)
	if not state or not state.pending or state.pending.token ~= token then
		return false
	end
	local model = state.pending.model
	state.pending = nil
	if model then
		model:Destroy()
	end
	PlayerState.sync(player)
	return true
end

local function collect(player: Player, token: number)
	local state = PlayerState.get(player)
	if not state or not state.pending or state.pending.token ~= token then
		return
	end
	local creatureId = state.pending.creatureId
	clearPending(player, token)
	PlotService.place(player, creatureId)
end

local function sprout(player: Player, token: number, creatureId: string, landPos: Vector3)
	local state = PlayerState.get(player)
	if not state or not state.pending or state.pending.token ~= token then
		return
	end

	local part = CritterVisual.make(creatureId)
	local restY = landPos.Y + part.Size.Y / 2
	part.Position = Vector3.new(landPos.X, restY - part.Size.Y, landPos.Z) -- start underground
	part:SetAttribute("OwnerUserId", player.UserId)
	part.Parent = fieldFolder
	state.pending.model = part
	TweenService:Create(
		part,
		TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = Vector3.new(landPos.X, restY, landPos.Z) }
	):Play()

	if Config.CollectMode == "walk" then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Collect"
		prompt.ObjectText = Config.Creatures[creatureId].name
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = part
		prompt.Triggered:Connect(function(who: Player)
			if who == player then
				collect(player, token)
			end
		end)
	else
		task.delay(Config.AutoCollectDelaySeconds, function()
			local target = PlotService.plotCenter(player)
			if target and part.Parent then
				local tween = TweenService:Create(
					part,
					TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{ Position = target + Vector3.new(0, 4, 0) }
				)
				tween:Play()
				tween.Completed:Wait()
			end
			collect(player, token)
		end)
	end

	-- Never let an ignored critter block throwing forever.
	task.delay(Config.PendingTimeoutSeconds, function()
		if clearPending(player, token) then
			notify(player, Config.Creatures[creatureId].name .. " wandered off")
		end
	end)
end

local function onThrow(throwResult: RemoteEvent, player: Player, timing: any)
	local state = PlayerState.get(player)
	if not state or not limiter:allow(player) then
		return
	end
	if state.pending then
		notify(player, "Collect your critter first")
		return
	end
	local now = os.clock()
	if now - state.lastThrow < Config.Throw.cooldownSeconds then
		return
	end
	state.lastThrow = now

	-- Distance.compute sanitizes timing (non-numbers and NaN become 0, then clamps).
	local distance = Distance.compute(state.power, timing, Config.Distance)
	local mult = Distance.meterMultiplier(timing, Config.Meter)
	local zoneId = Zone.forDistance(distance, Config.Zones)
	local creatureId = WeightedRoll.pick(Config.ZoneTables[zoneId], nextNumber)
	local sideways = rng:NextNumber(-1, 1) * Config.Map.laneWidth * 0.3
	local landPos = MapBuilder.landPoint(distance, sideways)

	nextToken += 1
	local token = nextToken
	state.pending = { token = token, creatureId = creatureId, model = nil }
	PlayerState.sync(player)

	throwResult:FireClient(player, {
		distance = distance,
		mult = mult,
		zoneId = zoneId,
		creatureId = creatureId,
		origin = MapBuilder.throwOrigin(),
		landPos = landPos,
	})

	task.delay(Config.Throw.arcSeconds, sprout, player, token, creatureId, landPos)
end

function ThrowService.init(throwRemote: RemoteEvent, throwResult: RemoteEvent, notify_: RemoteEvent)
	notifyRemote = notify_
	local folder = Instance.new("Folder")
	folder.Name = "FieldCritters"
	folder.Parent = Workspace
	fieldFolder = folder

	throwRemote.OnServerEvent:Connect(function(player: Player, timing: any)
		onThrow(throwResult, player, timing)
	end)
end

function ThrowService.forget(player: Player)
	limiter:forget(player)
end

return ThrowService
