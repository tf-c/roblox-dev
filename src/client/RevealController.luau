--!strict
-- The reveal moment: the toy arcs down the lane and lands on a glowing ring, distance and zone pop up, then a
-- rarity-colored burst and the creature's name. Epic adds a bigger burst and a camera shake.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Hud = require(script.Parent.Hud)

type ThrowResult = {
	distance: number,
	mult: number,
	zoneId: string,
	creatureId: string,
	origin: Vector3,
	landPos: Vector3,
}

local RevealController = {}

local function zoneName(zoneId: string): string
	local look = Config.ZoneLooks[zoneId]
	return if look then look.name else zoneId
end

local function quality(mult: number): string
	if mult >= Config.Meter.perfectMult then
		return "Perfect!"
	elseif mult >= 1.1 then
		return "Good"
	end
	return "Weak"
end

-- The toy rests on a glowing ring for a moment, then ring and toy fade out.
local function landRing(landPos: Vector3, projectile: BasePart)
	local ring = Instance.new("Part")
	ring.Name = "LandingRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, 6, 6)
	ring.CFrame = CFrame.new(landPos + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = Color3.fromRGB(255, 240, 180)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.3
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Parent = Workspace

	task.delay(Config.Projectile.restSeconds, function()
		local info = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local fade = TweenService:Create(ring, info, { Transparency = 1 })
		TweenService:Create(projectile, info, { Transparency = 1 }):Play()
		fade.Completed:Connect(function()
			ring:Destroy()
			projectile:Destroy()
		end)
		fade:Play()
	end)
end

local function flyProjectile(origin: Vector3, landPos: Vector3)
	local s = Config.Projectile.size
	local projectile = Instance.new("Part")
	projectile.Name = Config.Projectile.name
	projectile.Shape = Enum.PartType.Ball
	projectile.Size = Vector3.new(s, s, s)
	projectile.Color = Color3.fromHex(Config.Projectile.color)
	projectile.Material = Enum.Material.Fabric
	projectile.Anchored = true
	projectile.CanCollide = false
	projectile.CanQuery = false
	projectile.Parent = Workspace

	local trail = Instance.new("Trail")
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.4, 0)
	a0.Parent = projectile
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.4, 0)
	a1.Parent = projectile
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.4
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 240, 180))
	trail.Parent = projectile

	local duration = Config.Throw.arcSeconds
	local height = Config.Throw.arcHeight
	local start = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local t = math.min((os.clock() - start) / duration, 1)
		local flat = origin:Lerp(landPos, t)
		projectile.Position = flat + Vector3.new(0, 4 * height * t * (1 - t), 0)
		if t >= 1 then
			conn:Disconnect()
			projectile.Position = landPos + Vector3.new(0, s / 2, 0)
			landRing(landPos, projectile)
		end
	end)
end

local function burst(position: Vector3, color: Color3, scale: number)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Ball
	ring.Size = Vector3.new(1, 1, 1)
	ring.Position = position
	ring.Color = color
	ring.Material = Enum.Material.Neon
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Transparency = 0.2
	ring.Parent = Workspace
	local size = 10 * scale
	local tween = TweenService:Create(
		ring,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(size, size, size), Transparency = 1 }
	)
	tween.Completed:Connect(function()
		ring:Destroy()
	end)
	tween:Play()
end

local function shakeCamera(seconds: number, strength: number)
	local character = (Players.LocalPlayer :: Player).Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local start = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - start
		if elapsed >= seconds then
			humanoid.CameraOffset = Vector3.zero
			conn:Disconnect()
			return
		end
		local fade = 1 - elapsed / seconds
		humanoid.CameraOffset =
			Vector3.new((math.random() - 0.5) * strength * fade, (math.random() - 0.5) * strength * fade, 0)
	end)
end

local revealToken = 0

function RevealController.init(hud: Hud.Hud, throwResult: RemoteEvent)
	throwResult.OnClientEvent:Connect(function(result: ThrowResult)
		revealToken += 1
		local token = revealToken
		local def = Config.Creatures[result.creatureId]
		local rarityColor = Color3.fromHex(Config.RarityColors[def.rarity])

		flyProjectile(result.origin, result.landPos)
		hud.reveal.TextColor3 = Color3.new(1, 1, 1)
		hud.reveal.Text = string.format("%s  %.1f studs", quality(result.mult), result.distance)
		hud.revealSub.Text = zoneName(result.zoneId)
		hud.revealSub.TextColor3 = Color3.new(1, 1, 1)

		task.delay(Config.Throw.arcSeconds, function()
			if token ~= revealToken then
				return
			end
			local isEpic = def.rarity == "epic"
			burst(
				result.landPos,
				rarityColor,
				if isEpic then 2.5 else (if def.rarity == "rare" then 1.5 else 1)
			)
			if isEpic then
				shakeCamera(0.5, 1.2)
			end
			hud.reveal.Text = def.name .. "!"
			hud.reveal.TextColor3 = rarityColor
			hud.revealSub.Text = string.format("%s · %d cash/s", def.rarity, def.income)
			hud.revealSub.TextColor3 = rarityColor

			task.delay(2.5, function()
				if token == revealToken then
					hud.reveal.Text = ""
					hud.revealSub.Text = ""
				end
			end)
		end)
	end)
end

return RevealController
