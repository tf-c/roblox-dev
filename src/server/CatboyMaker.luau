--!strict
-- Owner-only catboy maker (Studio play tests only): builds a previewed look on a rig in front of the owner.
-- The remote is created here, not in Remotes.luau, so it never exists in a live game.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local CreatureRigs = require(script.Parent.CreatureRigs)
local CritterVisual = require(script.Parent.CritterVisual)

local CatboyMaker = {}

local RIG_NAME = "CatboyMakerRig"
local FRONT_STUDS = 8

local generation: { [Player]: number } = {}

-- Spot in front of the player (feet on the ground) and the point the rig should face.
local function placement(player: Player): (Vector3, Vector3)
	local pad = Config.Map.padPosition
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		local spot = Vector3.new(pad.x, pad.y, pad.z + FRONT_STUDS)
		return spot, Vector3.new(pad.x, pad.y, pad.z + FRONT_STUDS * 2)
	end
	local humanoid = player.Character and player.Character:FindFirstChildWhichIsA("Humanoid")
	local feet = root.Position.Y - root.Size.Y / 2 - (if humanoid then humanoid.HipHeight else 0)
	local spot = root.Position + root.CFrame.LookVector * FRONT_STUDS
	return Vector3.new(spot.X, feet, spot.Z), Vector3.new(root.Position.X, feet, root.Position.Z)
end

local function onPreview(remote: RemoteEvent, player: Player, look: any)
	if not RunService:IsStudio() or not player:GetAttribute("CatboyMaker") or type(look) ~= "table" then
		return
	end
	local mine = (generation[player] or 0) + 1
	generation[player] = mine
	local ok, model, reason = pcall(CreatureRigs.buildLook, look, RIG_NAME)
	if generation[player] ~= mine then -- a newer request took over while this one yielded
		if ok and model then
			model:Destroy()
		end
		return
	end
	if not ok or not model then
		remote:FireClient(player, false, if ok then reason else tostring(model))
		return
	end

	local previous = Workspace:FindFirstChild(RIG_NAME)
	if previous then
		previous:Destroy()
	end
	for _, inst in model:GetDescendants() do
		if inst:IsA("BasePart") then
			inst.Anchored = true
		elseif inst:IsA("Humanoid") then
			inst.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
	end
	local spot, faceAt = placement(player)
	model:PivotTo(CFrame.lookAt(spot, faceAt))
	local lift = CritterVisual.restingPivot(model, spot).Y - model:GetPivot().Y
	model:PivotTo(model:GetPivot() + Vector3.new(0, lift, 0))
	model.Parent = Workspace

	local ids = {}
	local humanoid = model:FindFirstChildWhichIsA("Humanoid")
	if humanoid then
		for _, accessory in humanoid:GetAppliedDescription():GetAccessories(true) do
			table.insert(ids, accessory.AssetId)
		end
	end
	remote:FireClient(player, true, ids)
end

function CatboyMaker.init()
	if not RunService:IsStudio() then
		return
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = "CatboyMakerPreview"
	remote.Parent = ReplicatedStorage
	remote.OnServerEvent:Connect(function(player: Player, look: any)
		onPreview(remote, player, look)
	end)
end

function CatboyMaker.add(player: Player)
	if RunService:IsStudio() and player.UserId == game.CreatorId then
		player:SetAttribute("CatboyMaker", true)
	end
end

function CatboyMaker.forget(player: Player)
	generation[player] = nil
end

return CatboyMaker
