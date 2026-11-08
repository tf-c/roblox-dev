--!strict
-- Creature look: a Model (a rig from ServerStorage.CreatureModels named after the creature id,
-- else a blocky placeholder catboy) with a name tag. Used in the field and on plots.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local CritterVisual = {}

local SCALE_BY_RARITY: { [string]: number } = { common = 1, rare = 1.2, epic = 1.5 }
local SKIN = Color3.fromHex("#f3d2b3")
local PANTS = Color3.fromHex("#4b4f63")
local EYES = Color3.fromHex("#222222")

local warned: { [string]: boolean } = {}

-- `shape` lets a limb be another part type (the ears are wedges); default is a block.
local function limb(
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	parent: Model,
	shape: BasePart?
): BasePart
	local part: BasePart = shape or Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = offset
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.Parent = parent
	return part
end

-- A blocky, fully clothed catboy facing -Z (toward the player). Centered on the torso.
local function placeholder(creatureId: string): Model
	local def = Config.Creatures[creatureId]
	local coat = Color3.fromHex(def.color)
	local outfit = coat:Lerp(Color3.new(1, 1, 1), 0.3)

	local model = Instance.new("Model")
	model.Name = def.name

	local body = limb("Body", Vector3.new(2, 2, 1), CFrame.new(0, 0, 0), outfit, model)
	limb("LeftLeg", Vector3.new(0.9, 2, 0.9), CFrame.new(-0.5, -2, 0), PANTS, model)
	limb("RightLeg", Vector3.new(0.9, 2, 0.9), CFrame.new(0.5, -2, 0), PANTS, model)
	limb("LeftArm", Vector3.new(0.8, 1.9, 0.8), CFrame.new(-1.45, 0.05, 0), outfit, model)
	limb("RightArm", Vector3.new(0.8, 1.9, 0.8), CFrame.new(1.45, 0.05, 0), outfit, model)
	limb("Head", Vector3.new(1.8, 1.8, 1.6), CFrame.new(0, 1.9, 0), SKIN, model)
	limb("Hair", Vector3.new(1.9, 0.5, 1.7), CFrame.new(0, 2.75, 0.05), coat, model)
	-- Triangle ears: a wedge turned sideways shows its triangle to the front, straight edge outward.
	local earSize = Vector3.new(0.3, 0.6, 0.6)
	local ear = CFrame.new(0, 3.25, 0)
	limb(
		"LeftEar",
		earSize,
		ear * CFrame.new(-0.6, 0, 0) * CFrame.Angles(0, math.rad(-90), 0),
		coat,
		model,
		Instance.new("WedgePart")
	)
	limb(
		"RightEar",
		earSize,
		ear * CFrame.new(0.6, 0, 0) * CFrame.Angles(0, math.rad(90), 0),
		coat,
		model,
		Instance.new("WedgePart")
	)
	local eyeSize = Vector3.new(0.25, 0.35, 0.1)
	limb("LeftEye", eyeSize, CFrame.new(-0.4, 2.0, -0.81), EYES, model)
	limb("RightEye", eyeSize, CFrame.new(0.4, 2.0, -0.81), EYES, model)
	limb(
		"Tail",
		Vector3.new(0.35, 0.35, 2.2),
		CFrame.new(0, -0.6, 1.4) * CFrame.Angles(math.rad(35), 0, 0),
		coat,
		model
	)

	model.PrimaryPart = body
	model:ScaleTo(SCALE_BY_RARITY[def.rarity] or 1)
	return model
end

local function fromTemplate(creatureId: string): Model?
	local folder = ServerStorage:FindFirstChild("CreatureModels")
	local template = folder and folder:FindFirstChild(creatureId)
	if not template then
		return nil
	end
	if template:IsA("Model") and template.PrimaryPart then
		return template:Clone()
	end
	if not warned[creatureId] then
		warned[creatureId] = true
		warn("CreatureModels." .. creatureId .. " must be a Model with a PrimaryPart; using the placeholder")
	end
	return nil
end

function CritterVisual.make(creatureId: string): Model
	local def = Config.Creatures[creatureId]
	assert(def, "unknown critter " .. creatureId)

	local model = fromTemplate(creatureId) or placeholder(creatureId)
	local primary = model.PrimaryPart :: BasePart
	for _, inst in model:GetDescendants() do
		if inst:IsA("BasePart") then
			inst.Anchored = true
			inst.CanCollide = false
		elseif inst:IsA("Humanoid") then
			inst.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
	end
	model:SetAttribute("CreatureId", creatureId)

	local box, size = model:GetBoundingBox()
	local top = box.Position.Y + size.Y / 2

	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(160, 44)
	tag.StudsOffset = Vector3.new(0, top - primary.Position.Y + 1.5, 0)
	tag.AlwaysOnTop = true
	tag.MaxDistance = 250
	tag.Parent = primary

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromHex(Config.RarityColors[def.rarity])
	label.TextStrokeTransparency = 0.3
	label.Text = string.format("%s\n%s · %d/s", def.name, def.rarity, def.income)
	label.Parent = tag

	return model
end

-- Hide the name tag until the creature has arrived.
function CritterVisual.hideTag(model: Model)
	local tag = (model.PrimaryPart :: BasePart):FindFirstChildOfClass("BillboardGui")
	if not tag then
		return
	end
	tag.Enabled = false
end

-- Show the name tag with a quick pop (size 0 -> full).
function CritterVisual.popTag(model: Model)
	local tag = (model.PrimaryPart :: BasePart):FindFirstChildOfClass("BillboardGui")
	if not tag then
		return
	end
	local full = tag.Size
	tag.Size = UDim2.fromOffset(0, 0)
	tag.Enabled = true
	TweenService
		:Create(tag, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = full })
		:Play()
end

-- Pivot that puts the model's lowest point on `ground`.
function CritterVisual.restingPivot(model: Model, ground: Vector3): CFrame
	local box, size = model:GetBoundingBox()
	local bottomToPivot = model:GetPivot().Position.Y - (box.Position.Y - size.Y / 2)
	return CFrame.new(ground + Vector3.new(0, bottomToPivot, 0))
end

-- Models can't be tweened directly, so tween a CFrameValue and pivot on change.
function CritterVisual.tweenTo(model: Model, target: CFrame, info: TweenInfo): Tween
	local value = Instance.new("CFrameValue")
	value.Value = model:GetPivot()
	value.Changed:Connect(function(cf: CFrame)
		model:PivotTo(cf)
	end)
	local tween = TweenService:Create(value, info, { Value = target })
	tween.Completed:Connect(function()
		value:Destroy()
	end)
	tween:Play()
	return tween
end

return CritterVisual
