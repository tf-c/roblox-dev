--!strict
-- Creature look: a Model (a rig from ServerStorage.CreatureModels named after the creature id,
-- else a placeholder ball) with a name tag. Used in the field and on plots.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local CritterVisual = {}

local SIZE_BY_RARITY: { [string]: number } = { common = 3, rare = 4, epic = 5.5 }

local warned: { [string]: boolean } = {}

local function placeholder(creatureId: string): Model
	local def = Config.Creatures[creatureId]
	local size = SIZE_BY_RARITY[def.rarity] or 3

	local model = Instance.new("Model")
	model.Name = def.name

	local part = Instance.new("Part")
	part.Name = "Body"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(size, size, size)
	part.Color = Color3.fromHex(def.color)
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = model
	model.PrimaryPart = part
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
