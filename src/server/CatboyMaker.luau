--!strict
-- Owner-only catboy maker (Studio play tests only): builds a previewed look on a rig in ReplicatedStorage.CatboyMakerRig,
-- which the owner's editor clones into its 3D preview. It exists only in Studio.
-- The remote is created here, not in Remotes.luau, so it never exists in a live game.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CreatureRigs = require(script.Parent.CreatureRigs)

local CatboyMaker = {}

local RIG_NAME = "CatboyMakerRig"

local generation: { [Player]: number } = {}

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

	local previous = ReplicatedStorage:FindFirstChild(RIG_NAME)
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
	model:PivotTo(CFrame.new())
	model:SetAttribute("Build", mine)
	model.Parent = ReplicatedStorage

	local ids = {}
	local humanoid = model:FindFirstChildWhichIsA("Humanoid")
	if humanoid then
		for _, accessory in humanoid:GetAppliedDescription():GetAccessories(true) do
			table.insert(ids, accessory.AssetId)
		end
	end
	remote:FireClient(player, true, ids, mine)
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
