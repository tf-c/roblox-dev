--!strict
-- Builds the placeholder map at runtime from Config, so moving a zone boundary
-- in Config moves the ground strips and markers too. Lane runs along +Z.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local MapBuilder = {}

local GROUND_TOP = 0
local STRIP_THICKNESS = 0.2
local PLOT_SPACING = 30

local mapFolder: Folder? = nil

local function v3(t: { x: number, y: number, z: number }): Vector3
	return Vector3.new(t.x, t.y, t.z)
end

local function block(name: string, size: Vector3, position: Vector3, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function sign(text: string, position: Vector3, parent: Instance)
	local post = block(
		"Sign",
		Vector3.new(0.6, 6, 0.6),
		position + Vector3.new(0, 3, 0),
		Color3.fromRGB(110, 80, 50),
		parent
	)
	post.CanCollide = false
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 40)
	gui.StudsOffset = Vector3.new(0, 4.5, 0)
	gui.MaxDistance = 400
	gui.Parent = post
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = gui
end

function MapBuilder.build(): Folder
	if mapFolder then
		return mapFolder
	end
	local folder = Instance.new("Folder")
	folder.Name = "Map"

	local pad = v3(Config.Map.padPosition)
	local width = Config.Map.laneWidth
	local length = Config.Map.laneLength

	-- Ground (only if the place has no baseplate, to avoid z-fighting).
	if not Workspace:FindFirstChild("Baseplate") then
		block(
			"Ground",
			Vector3.new(600, 1, 600),
			Vector3.new(0, GROUND_TOP - 0.5, 80),
			Color3.fromRGB(90, 140, 70),
			folder
		)
	end

	-- One colored strip per zone, from its minDistance to the next zone's (or the lane end).
	for i, zone in Config.Zones do
		local look = Config.ZoneLooks[zone.id]
		local startZ = zone.minDistance
		local nextZone = Config.Zones[i + 1]
		local endZ = if nextZone then nextZone.minDistance else length
		local stripLength = endZ - startZ
		block(
			"Zone_" .. zone.id,
			Vector3.new(width, STRIP_THICKNESS, stripLength),
			pad + Vector3.new(0, GROUND_TOP + STRIP_THICKNESS / 2, startZ + stripLength / 2),
			Color3.fromHex(look.color),
			folder
		).CanCollide =
			true
		-- Alternate sides so the signs don't stack in line when seen from the spawn.
		local side = if i % 2 == 0 then -1 else 1
		sign(
			string.format("%s · %d studs", look.name, zone.minDistance),
			pad + Vector3.new(side * (width / 2 + 2), 0, startZ),
			folder
		)
	end

	-- Ours must be the only spawn: a place template's spawn (e.g. Baseplate's, which sits
	-- on the launch pad) can face players away from the lane. Runtime only; the place file is untouched.
	for _, existing in Workspace:GetDescendants() do
		if existing:IsA("SpawnLocation") then
			existing:Destroy()
		end
	end

	-- Launch pad and spawn just behind it, facing down the lane.
	block(
		"LaunchPad",
		Vector3.new(10, 1, 10),
		pad + Vector3.new(0, 0.5, -4),
		Color3.fromRGB(200, 170, 90),
		folder
	)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.lookAt(pad + Vector3.new(0, 0.5, -14), pad + Vector3.new(0, 0.5, 100))
	spawn.Neutral = true
	spawn.Transparency = 0.5
	spawn.Parent = folder

	folder.Parent = Workspace
	mapFolder = folder
	return folder
end

-- Where seeds leave from (above the pad).
function MapBuilder.throwOrigin(): Vector3
	return v3(Config.Map.padPosition) + Vector3.new(0, 4, 0)
end

-- Ground point `distance` studs down the lane, with a sideways offset.
function MapBuilder.landPoint(distance: number, sideways: number): Vector3
	local pad = v3(Config.Map.padPosition)
	local z = math.clamp(distance, 0, Config.Map.laneLength - 2)
	local x = math.clamp(sideways, -Config.Map.laneWidth / 2 + 3, Config.Map.laneWidth / 2 - 3)
	return pad + Vector3.new(x, GROUND_TOP + STRIP_THICKNESS, z)
end

-- Builds plot `index` (0-based) with `slots` pedestals. Returns the pedestal parts in slot order.
function MapBuilder.buildPlot(index: number, ownerName: string): (Model, { BasePart })
	local origin = v3(Config.Map.plotPosition) - Vector3.new(index * PLOT_SPACING, 0, 0)
	local model = Instance.new("Model")
	model.Name = "Plot_" .. ownerName

	block(
		"Floor",
		Vector3.new(24, 0.4, 18),
		origin + Vector3.new(0, 0.2, 0),
		Color3.fromRGB(150, 110, 70),
		model
	)
	sign(ownerName .. "'s plot", origin + Vector3.new(0, 0, -10), model)

	local pedestals: { BasePart } = {}
	local cols = 3
	for slot = 1, Config.Plot.slots do
		local col = (slot - 1) % cols
		local row = (slot - 1) // cols
		local pos = origin + Vector3.new((col - 1) * 7, 1, (row - 0.5) * 8)
		local ped =
			block("Pedestal_" .. slot, Vector3.new(4, 1.2, 4), pos, Color3.fromRGB(220, 210, 190), model)
		table.insert(pedestals, ped)
	end

	model.Parent = assert(mapFolder, "MapBuilder.build() must run before buildPlot")
	return model, pedestals
end

return MapBuilder
