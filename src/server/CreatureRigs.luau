--!strict
-- Builds an R15 rig per catalog bundle once at server start and caches it.
-- CritterVisual clones from the cache, so making a Creature never waits on the web.

local AssetService = game:GetService("AssetService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Outfit = require(ReplicatedStorage.Shared.Outfit)

local CreatureRigs = {}

local ATTEMPTS = 3
local RETRY_SECONDS = 2

local descriptions: { [number]: HumanoidDescription } = {}
local rigs: { [string]: Model } = {}

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

local function description(bundleId: number): (HumanoidDescription?, string)
	local cached = descriptions[bundleId]
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
		return nil, "bundle has no outfit"
	end
	local okDesc, desc = retry(function()
		return Players:GetHumanoidDescriptionFromOutfitId(outfitId)
	end)
	if not okDesc then
		return nil, "outfit failed: " .. tostring(desc)
	end
	descriptions[bundleId] = desc
	return desc, ""
end

local function build(creatureId: string, look: Config.CreatureBundle)
	local function fail(reason: string)
		warn(
			"CreatureRigs: "
				.. creatureId
				.. " (bundle "
				.. look.bundleId
				.. "): "
				.. reason
				.. "; using the placeholder"
		)
	end

	local base, reason = description(look.bundleId)
	if not base then
		return fail(reason)
	end
	local desc = base:Clone()
	if look.accessoryIds then
		desc.HatAccessory = Outfit.withAccessories(desc.HatAccessory, look.accessoryIds)
	end
	local okModel, model = retry(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not okModel then
		return fail("rig failed: " .. tostring(model))
	end
	model.Name = Config.Creatures[creatureId].name
	if not model.PrimaryPart then
		model.PrimaryPart = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	end
	if not model.PrimaryPart then
		return fail("rig has no root part")
	end
	rigs[creatureId] = model
end

-- Starts one build per bundled creature; returns immediately.
function CreatureRigs.preload()
	for creatureId, look in Config.CreatureBundles do
		task.spawn(build, creatureId, look)
	end
end

-- The cached rig template for a creature, or nil (never yields).
function CreatureRigs.get(creatureId: string): Model?
	return rigs[creatureId]
end

return CreatureRigs
