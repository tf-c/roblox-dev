--!strict
-- Placeholder critter look: a colored ball with a name tag. Used in the field and on plots.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local CritterVisual = {}

local SIZE_BY_RARITY: { [string]: number } = { common = 3, rare = 4, epic = 5.5 }

function CritterVisual.make(creatureId: string): BasePart
	local def = Config.Creatures[creatureId]
	assert(def, "unknown critter " .. creatureId)
	local size = SIZE_BY_RARITY[def.rarity] or 3

	local part = Instance.new("Part")
	part.Name = def.name
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(size, size, size)
	part.Color = Color3.fromHex(def.color)
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part:SetAttribute("CreatureId", creatureId)

	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(160, 44)
	tag.StudsOffset = Vector3.new(0, size * 0.5 + 1.5, 0)
	tag.AlwaysOnTop = true
	tag.MaxDistance = 250
	tag.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromHex(Config.RarityColors[def.rarity])
	label.TextStrokeTransparency = 0.3
	label.Text = string.format("%s\n%s · %d/s", def.name, def.rarity, def.income)
	label.Parent = tag

	return part
end

return CritterVisual
