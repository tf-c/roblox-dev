--!strict
-- The server decides the throw. The client sends only the meter timing (0..1).
-- Server: distance from Power + timing, zone from distance, free weighted roll,
-- then a creature runs in to where the toy lands.
--
-- A thrown creature is "pending" until it leaves by exactly one path: collected,
-- wandered off (timeout) or owner left. All three go through takePending.
--
-- Known prototype gap: a modified client can always send a perfect timing.
-- Harden later (e.g. server-timed meter) before anything of value rides on it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Arrival = require(ReplicatedStorage.Shared.Arrival)
local Config = require(ReplicatedStorage.Shared.Config)
local Distance = require(ReplicatedStorage.Shared.Distance)
local WeightedRoll = require(ReplicatedStorage.Shared.WeightedRoll)
local Zone = require(ReplicatedStorage.Shared.Zone)
local CritterVisual = require(script.Parent.CritterVisual)
local MapBuilder = require(script.Parent.MapBuilder)
local PlayerState = require(script.Parent.PlayerState)
local PlotService = require(script.Parent.PlotService)
local Remotes = require(script.Parent.Remotes)

local ThrowService = {}

local rng = Random.new()
local function nextNumber(): number
	return rng:NextNumber()
end

local nextToken = 0
local fieldFolder = Instance.new("Folder")
fieldFolder.Name = "FieldCritters"

-- The player's pending creature, if it is still the throw identified by `token`.
local function current(player: Player, token: number): PlayerState.Pending?
	local state = PlayerState.get(player)
	local pending = if state then state.pending else nil
	return if pending and pending.token == token then pending else nil
end

-- Removes the pending creature (model included) if it is still `token`. Returns it, or nil if it already left.
local function takePending(player: Player, token: number): PlayerState.Pending?
	local pending = current(player, token)
	if not pending then
		return nil
	end
	(PlayerState.get(player) :: PlayerState.State).pending = nil
	if pending.model then
		pending.model:Destroy()
	end
	PlayerState.sync(player)
	return pending
end

local function collect(player: Player, token: number)
	local pending = takePending(player, token)
	if pending then
		PlotService.place(player, pending.creatureId)
	end
end

local function arrive(player: Player, token: number, creatureId: string, landPos: Vector3)
	local pending = current(player, token)
	if not pending then
		return
	end

	local model = CritterVisual.make(creatureId)
	CritterVisual.hideTag(model)
	local rest = CritterVisual.restingPivot(model, landPos) -- identity rotation: faces the player
	local startX = Arrival.startX(landPos.X, Config.Map.laneWidth, Config.Arrival.edgeMargin)
	local startPos = Vector3.new(startX, rest.Position.Y, rest.Position.Z)
	-- Face the toy while running.
	local runFacing = CFrame.lookAt(startPos, rest.Position) - startPos
	model:PivotTo(runFacing + startPos)
	model:SetAttribute("OwnerUserId", player.UserId)
	model.Parent = fieldFolder
	pending.model = model

	task.spawn(function()
		local a = Config.Arrival
		local half = a.hopSeconds / 2
		CritterVisual.tweenTo(
			model,
			runFacing + rest.Position,
			TweenInfo.new(a.runSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		).Completed
			:Wait()
		if not current(player, token) then
			return
		end
		CritterVisual.tweenTo(
			model,
			rest + Vector3.new(0, a.hopHeight, 0),
			TweenInfo.new(half, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		).Completed
			:Wait()
		if not current(player, token) then
			return
		end
		CritterVisual.tweenTo(
			model,
			rest,
			TweenInfo.new(half, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		).Completed
			:Wait()
		if current(player, token) then
			CritterVisual.popTag(model)
		end
	end)

	if Config.CollectMode == "walk" then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = Config.Text.collectAction
		prompt.ObjectText = Config.Creatures[creatureId].name
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = model.PrimaryPart
		prompt.Triggered:Connect(function(who: Player)
			if who == player then
				collect(player, token)
			end
		end)
	else
		task.delay(Config.AutoCollectDelaySeconds, function()
			local target = PlotService.plotCenter(player)
			if target and current(player, token) then
				local tween = CritterVisual.tweenTo(
					model,
					CFrame.new(target + Vector3.new(0, 4, 0)),
					TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				)
				tween.Completed:Wait()
			end
			collect(player, token)
		end)
	end

	-- Never let an ignored creature block throwing forever.
	task.delay(Config.PendingTimeoutSeconds, function()
		if takePending(player, token) then
			Remotes.toast(player, string.format(Config.Text.wanderedOff, Config.Creatures[creatureId].name))
		end
	end)
end

local function onThrow(player: Player, timing: any)
	local state = PlayerState.get(player)
	if not state then
		return
	end
	if state.pending then
		Remotes.toast(player, Config.Text.pendingBlocked)
		return
	end
	local now = os.clock()
	if now - state.lastThrow < Config.Throw.cooldownSeconds then
		return
	end
	state.lastThrow = now

	-- Distance.compute sanitizes timing (non-numbers and NaN become 0, then clamps).
	local distance, mult = Distance.compute(state.power, timing, Config.Distance)
	local zoneId = Zone.forDistance(distance, Config.Zones)
	local creatureId = WeightedRoll.pick(Config.ZoneTables[zoneId], nextNumber)
	local sideways = rng:NextNumber(-1, 1) * Config.Map.laneWidth * 0.3
	local landPos = MapBuilder.landPoint(distance, sideways)

	nextToken += 1
	local token = nextToken
	state.pending = { token = token, creatureId = creatureId, model = nil }
	PlayerState.sync(player)

	Remotes.throwResult:FireClient(player, {
		distance = distance,
		mult = mult,
		zoneId = zoneId,
		creatureId = creatureId,
		origin = MapBuilder.throwOrigin(),
		landPos = landPos,
	})

	task.delay(Config.Throw.arcSeconds, arrive, player, token, creatureId, landPos)
end

function ThrowService.init()
	fieldFolder.Parent = Workspace
	Remotes.throw.OnServerEvent:Connect(onThrow)
end

-- Owner left: drop their pending creature. Call before PlayerState.remove.
function ThrowService.forget(player: Player)
	local state = PlayerState.get(player)
	if state and state.pending then
		takePending(player, state.pending.token)
	end
end

return ThrowService
