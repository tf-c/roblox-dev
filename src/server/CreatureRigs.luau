--!strict
-- Builds an R15 rig per Config.Creatures look once at server start and caches it.
-- CritterVisual clones from the cache, so making a Creature never waits on the web.
-- Also publishes a preview copy to ReplicatedStorage.CreaturePreviews for the Catboys window.
-- To make an editable copy, run in the command bar (edit mode):
--   require(game.ServerScriptService.Server.CreatureRigs).saveModel("pillow")

local AssetService = game:GetService("AssetService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Outfit = require(ReplicatedStorage.Shared.Outfit)

local CreatureRigs = {}

local ATTEMPTS = 3
local RETRY_SECONDS = 2

local bundleDescriptions: { [number]: HumanoidDescription } = {}
local outfitDescriptions: { [number]: HumanoidDescription } = {}
local rigs: { [string]: Model } = {}
local warned: { [string]: boolean } = {}
local previewFolder: Folder

-- Web calls can fail or time out: try a few times before giving up.
local function retry(fn: () -> any): (boolean, any)
	local ok, result = false, nil
	for attempt = 1, ATTEMPTS do
		ok, result = pcall(fn)
		if ok then
			break
		end
		if attempt < ATTEMPTS then
			task.wait(RETRY_SECONDS)
		end
	end
	return ok, result
end

local function outfitDescription(outfitId: number): (HumanoidDescription?, string)
	local cached = outfitDescriptions[outfitId]
	if cached then
		return cached, ""
	end
	local ok, desc = retry(function()
		return Players:GetHumanoidDescriptionFromOutfitId(outfitId)
	end)
	if not ok then
		return nil, "outfit failed: " .. tostring(desc)
	end
	outfitDescriptions[outfitId] = desc
	return desc, ""
end

local function bundleDescription(bundleId: number): (HumanoidDescription?, string)
	local cached = bundleDescriptions[bundleId]
	if cached then
		return cached, ""
	end
	local okBundle, bundle = retry(function()
		return AssetService:GetBundleDetailsAsync(bundleId)
	end)
	if not okBundle then
		return nil, "bundle details failed: " .. tostring(bundle)
	end
	local outfitId = Outfit.pickOutfitId(bundle.Items :: any)
	if not outfitId then
		return nil, "Bundle " .. bundleId .. " has no UserOutfit"
	end
	local desc, reason = outfitDescription(outfitId)
	if not desc then
		return nil, reason
	end
	bundleDescriptions[bundleId] = desc
	return desc, ""
end

-- A fresh description for the look's source; cached ones are cloned so overrides never touch them.
local function describe(look: Config.CreatureLook): (HumanoidDescription?, string)
	local source = Outfit.source(look :: Outfit.Look)
	local base, reason
	if source == "bundle" then
		base, reason = bundleDescription(look.bundleId :: number)
	elseif source == "outfit" then
		base, reason = outfitDescription(look.outfitId :: number)
	elseif source == "manual" then
		local desc = Instance.new("HumanoidDescription")
		for property, value in Outfit.manualProperties(look.manual :: Outfit.ManualLook) do
			(desc :: any)[property] = value
		end
		return desc, ""
	else
		return nil, "look needs exactly one of bundleId, outfitId, manual"
	end
	if not base then
		return nil, reason
	end
	return base:Clone(), ""
end

local SKIN_PARTS =
	{ "HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor" }
local SCALE_PROPERTIES: { [string]: string } = {
	height = "HeightScale",
	width = "WidthScale",
	head = "HeadScale",
	proportion = "ProportionScale",
	bodyType = "BodyTypeScale",
}

local function applyOverrides(desc: HumanoidDescription, look: Config.CreatureLook)
	if look.removeAccessoryIds then
		local remove: { [number]: boolean } = {}
		for _, id in look.removeAccessoryIds do
			remove[id] = true
		end
		local kept = {}
		for _, accessory in desc:GetAccessories(true) do
			if not remove[accessory.AssetId] then
				table.insert(kept, accessory)
			end
		end
		desc:SetAccessories(kept, true)
	end
	if look.accessoryIds then
		desc.HatAccessory = Outfit.withAccessories(desc.HatAccessory, look.accessoryIds)
	end
	if look.shirt then
		desc.Shirt = look.shirt
	end
	if look.pants then
		desc.Pants = look.pants
	end
	if look.skinColor then
		local color = Color3.fromHex(look.skinColor)
		for _, part in SKIN_PARTS do
			(desc :: any)[part] = color
		end
	end
	if look.scale then
		for field, property in SCALE_PROPERTIES do
			local value = (look.scale :: { [string]: number? })[field]
			if value then
				(desc :: any)[property] = value
			end
		end
	end
end

-- Builds a rig from a look. Yields. Returns nil and a reason on failure.
function CreatureRigs.buildLook(look: Config.CreatureLook, name: string): (Model?, string)
	local desc, reason = describe(look)
	if not desc then
		return nil, reason
	end
	applyOverrides(desc, look)
	local okModel, model = retry(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not okModel then
		return nil, "rig failed: " .. tostring(model)
	end
	model.Name = name
	if not model.PrimaryPart then
		model.PrimaryPart = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	end
	if not model.PrimaryPart then
		model:Destroy()
		return nil, "rig has no root part"
	end
	-- An unparented rig's accessories can sit where their welds haven't pulled them yet
	-- (seen with manual looks). CritterVisual anchors before parenting, so snap each handle's
	-- attachment onto the body attachment of the same name now.
	for _, accessory in model:GetChildren() do
		local handle = accessory:IsA("Accessory") and accessory:FindFirstChild("Handle")
		local attachment = handle and handle:FindFirstChildWhichIsA("Attachment")
		if handle and handle:IsA("BasePart") and attachment then
			for _, part in model:GetChildren() do
				local target = part:IsA("BasePart") and part:FindFirstChild(attachment.Name)
				if target and target:IsA("Attachment") then
					handle.CFrame = target.WorldCFrame * attachment.CFrame:Inverse()
					break
				end
			end
		end
	end
	return model, ""
end

-- The hand-saved ServerStorage.CreatureModels.<id> (the template itself, not a clone), or nil.
function CreatureRigs.saved(creatureId: string): Model?
	local folder = ServerStorage:FindFirstChild("CreatureModels")
	local template = folder and folder:FindFirstChild(creatureId)
	if not template then
		return nil
	end
	if template:IsA("Model") and template.PrimaryPart then
		return template
	end
	if not warned[creatureId] then
		warned[creatureId] = true
		warn("CreatureModels." .. creatureId .. " must be a Model with a PrimaryPart; using the placeholder")
	end
	return nil
end

local function build(creatureId: string)
	local def = Config.Creatures[creatureId]
	local model, reason = CreatureRigs.buildLook(def.look, def.name)
	if model then
		rigs[creatureId] = model
	else
		warn("CreatureRigs: " .. creatureId .. ": " .. reason .. "; using the placeholder")
	end
	local source = CreatureRigs.saved(creatureId) or model
	if source then
		local preview = source:Clone()
		preview.Name = creatureId
		for _, inst in preview:GetDescendants() do
			if inst:IsA("BasePart") then
				inst.Anchored = true
			elseif inst:IsA("Humanoid") then
				inst.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			elseif inst:IsA("Script") or inst:IsA("LocalScript") then
				inst:Destroy()
			end
		end
		preview.Parent = previewFolder
	end
end

-- Starts one build per creature; returns immediately.
function CreatureRigs.preload()
	local existing = ReplicatedStorage:FindFirstChild("CreaturePreviews")
	if existing then
		previewFolder = existing :: Folder
	else
		previewFolder = Instance.new("Folder")
		previewFolder.Name = "CreaturePreviews"
		previewFolder.Parent = ReplicatedStorage
	end
	for creatureId in Config.Creatures do
		task.spawn(build, creatureId)
	end
end

-- The cached rig template for a creature, or nil (never yields).
function CreatureRigs.get(creatureId: string): Model?
	return rigs[creatureId]
end

-- Command-bar tool (edit mode, yields): builds the Config look and saves it to
-- ServerStorage.CreatureModels.<creatureId>, where it can be hand-tweaked.
function CreatureRigs.saveModel(creatureId: string)
	local def = Config.Creatures[creatureId]
	if not def then
		warn("CreatureRigs: unknown creature " .. creatureId)
		return
	end
	local model, reason = CreatureRigs.buildLook(def.look, creatureId)
	if not model then
		warn("CreatureRigs: " .. creatureId .. ": " .. reason)
		return
	end
	local folder = ServerStorage:FindFirstChild("CreatureModels")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "CreatureModels"
		folder.Parent = ServerStorage
	end
	local old = folder:FindFirstChild(creatureId)
	if old then
		old:Destroy()
		print("CreatureRigs: replaced the existing " .. creatureId .. " model")
	end
	model.Name = creatureId
	model.Parent = folder
	print(
		"Saved ServerStorage.CreatureModels."
			.. creatureId
			.. ". It now overrides the Config look. Save the place (Ctrl+S) to keep it."
	)
end

-- Saves a model for every creature, in id order.
function CreatureRigs.saveAll()
	local ids = {}
	for creatureId in Config.Creatures do
		table.insert(ids, creatureId)
	end
	table.sort(ids)
	for _, creatureId in ids do
		CreatureRigs.saveModel(creatureId)
	end
end

return CreatureRigs
