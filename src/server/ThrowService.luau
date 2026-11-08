--!strict
-- The server decides the throw. The client sends only the meter timing (0..1).
-- Server: distance from Power + timing, zone from distance, free weighted roll,
-- then a critter sprouts where the seed lands.
--
-- A thrown critter is "pending" until it leaves by exactly one path: collected,
-- wandered off (timeout) or owner left. All three go through takePending.
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
local Remotes = require(script.Parent.Remotes)

local ThrowService = {}

local rng = Random.new()
local function nextNumber(): number
	return rng:NextNumber()
end

local nextToken = 0
local fieldFolder = Instance.new("Folder")
fieldFolder.Name = "FieldCritters"

-- The player's pending critter, if it is still the throw identified by `token`.
local function current(player: Player, token: number): PlayerState.Pending?
	local state = PlayerState.get(player)
	local pending = if state then state.pending else nil
	return if pending and pending.token == token then pending else nil
end

-- Removes the pending critter (model included) if it is still `token`. Returns it, or nil if it already left.
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

local function sprout(player: Player, token: number, creatureId: string, landPos: Vector3)
	local pending = current(player, token)
	if not pending then
		return
	end

	local part = CritterVisual.make(creatureId)
	local restY = landPos.Y + part.Size.Y / 2
	part.Position = Vector3.new(landPos.X, restY - part.Size.Y, landPos.Z) -- start underground
	part:SetAttribute("OwnerUserId", player.UserId)
	part.Parent = fieldFolder
	pending.model = part
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
			if target and current(player, token) then
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
		if takePending(player, token) then
			Remotes.toast(player, Config.Creatures[creatureId].name .. " wandered off")
		end
	end)
end

local function onThrow(player: Player, timing: any)
	local state = PlayerState.get(player)
	if not state then
		return
	end
	if state.pending then
		Remotes.toast(player, "Collect your critter first")
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

	task.delay(Config.Throw.arcSeconds, sprout, player, token, creatureId, landPos)
end

function ThrowService.init()
	fieldFolder.Parent = Workspace
	Remotes.throw.OnServerEvent:Connect(onThrow)
end

-- Owner left: drop their pending critter. Call before PlayerState.remove.
function ThrowService.forget(player: Player)
	local state = PlayerState.get(player)
	if state and state.pending then
		takePending(player, state.pending.token)
	end
end

return ThrowService
