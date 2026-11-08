--!strict
-- Catboys window: one card per plot slot with a 3D preview, name, rarity and income.
-- Opened from the side column; never blocks throwing.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Plot = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Plot"))
local Upgrade = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Upgrade"))

export type Window = { frame: Frame, closeButton: TextButton, refresh: () -> () }

local CatboysWindow = {}

local DARK = Color3.fromHex("#1e1e28")
local TITLE_HEIGHT = 44
local EMPTY_HEIGHT = 24

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function stroke(parent: Instance, thickness: number, color: Color3)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Color = color
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

local function text(
	name: string,
	parent: Instance,
	value: string,
	color: Color3,
	position: UDim2,
	size: UDim2
): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBlack
	l.TextColor3 = color
	l.TextScaled = true
	l.Text = value
	l.Position = position
	l.Size = size
	l.Parent = parent
	return l
end

-- Static 3D preview of a published model, framed front-on from slightly above.
local function addViewport(area: Frame, source: Model)
	local model = source:Clone()
	local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not part then
		model:Destroy()
		return
	end
	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.fromScale(1, 1)
	model.Parent = viewport
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.Parent = viewport
	viewport.CurrentCamera = cam
	local cf, size = model:GetBoundingBox()
	local dist = size.Y / 2 / math.tan(math.rad(15)) * 1.15
	cam.CFrame = CFrame.lookAt(
		cf.Position + part.CFrame.LookVector * dist + Vector3.new(0, size.Y * 0.1, 0),
		cf.Position
	)
	viewport.Parent = area
end

local function filledCard(id: string, slot: number, previews: Instance?): Frame
	local def = Config.Creatures[id]
	local card = Instance.new("Frame")
	card.Name = "Card" .. slot
	card.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
	card.Selectable = true
	card.LayoutOrder = slot
	corner(card, 12)

	local area = Instance.new("Frame")
	area.Name = "Preview"
	area.BackgroundColor3 = Color3.fromHex(def.color)
	area.Position = UDim2.fromScale(0.05, 0.03)
	area.Size = UDim2.fromScale(0.9, 0.67)
	corner(area, 10)
	area.Parent = card
	local model = previews and previews:FindFirstChild(id)
	if model and model:IsA("Model") then
		addViewport(area, model)
	end

	text("Name", card, def.name, Color3.new(1, 1, 1), UDim2.fromScale(0.05, 0.71), UDim2.fromScale(0.9, 0.1))

	local pill = Instance.new("Frame")
	pill.Name = "Rarity"
	pill.BackgroundColor3 = Color3.fromHex(Config.RarityColors[def.rarity])
	pill.Position = UDim2.fromScale(0.05, 0.82)
	pill.Size = UDim2.fromScale(0.42, 0.14)
	corner(pill, 8)
	pill.Parent = card
	text(
		"Label",
		pill,
		def.rarity:sub(1, 1):upper() .. def.rarity:sub(2),
		DARK,
		UDim2.fromScale(0, 0.1),
		UDim2.fromScale(1, 0.8)
	)

	text(
		"Income",
		card,
		string.format(Config.Text.incomePerSecond, def.income),
		Color3.fromRGB(120, 230, 120),
		UDim2.fromScale(0.5, 0.82),
		UDim2.fromScale(0.45, 0.14)
	)
	return card
end

local function emptyCard(slot: number): Frame
	local card = Instance.new("Frame")
	card.Name = "Card" .. slot
	card.BackgroundTransparency = 1
	card.LayoutOrder = slot
	corner(card, 12)
	stroke(card, 2, Color3.fromHex("#8a8a99"))
	text(
		"Label",
		card,
		Config.Text.emptySlot,
		Color3.fromHex("#8a8a99"),
		UDim2.fromScale(0.1, 0.4),
		UDim2.fromScale(0.8, 0.2)
	)
	return card
end

function CatboysWindow.create(parent: ScreenGui): Window
	local player = Players.LocalPlayer :: Player

	local frame = Instance.new("Frame")
	frame.Name = "CatboysWindow"
	frame.Visible = false
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	frame.AnchorPoint = Vector2.new(0.5, 0)
	-- 40/104 clear the side column; 238 keeps the bottom edge above the meter and Train/Throw.
	frame.Position = UDim2.new(0.5, 40, 0, 8)
	frame.Size = UDim2.new(1, -104, 1, -238)
	corner(frame, 16)
	stroke(frame, 3, DARK)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(560, 440)
	limit.Parent = frame
	local openScale = Instance.new("UIScale")
	openScale.Parent = frame

	text(
		"Title",
		frame,
		Config.Text.catboysTitle,
		Color3.new(1, 1, 1),
		UDim2.fromOffset(12, 4),
		UDim2.new(0.3, 0, 0, TITLE_HEIGHT - 8)
	).TextXAlignment =
		Enum.TextXAlignment.Left
	local slotsLabel = text(
		"Slots",
		frame,
		"",
		Color3.fromRGB(200, 200, 210),
		UDim2.fromScale(0.35, 0),
		UDim2.new(0.3, 0, 0, TITLE_HEIGHT)
	)
	slotsLabel.Font = Enum.Font.GothamBold

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "Close"
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -4, 0, 0)
	closeButton.Size = UDim2.fromOffset(44, 44)
	closeButton.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
	closeButton.Font = Enum.Font.GothamBlack
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.TextSize = 24
	closeButton.Text = "X"
	corner(closeButton, 10)
	closeButton.Parent = frame

	local empty = text(
		"Empty",
		frame,
		Config.Text.catboysEmpty,
		Color3.fromRGB(200, 200, 210),
		UDim2.fromOffset(12, TITLE_HEIGHT),
		UDim2.new(1, -24, 0, EMPTY_HEIGHT)
	)
	empty.Font = Enum.Font.GothamBold

	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 6
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.Parent = frame
	local layout = Instance.new("UIGridLayout")
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	local padding = Instance.new("UIPadding")
	for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		(padding :: any)[side] = UDim.new(0, 8)
	end
	padding.Parent = grid

	local previews: Instance? = nil

	local function size()
		local w = grid.AbsoluteSize.X
		local cols = if w < 300 then 2 elseif w < 460 then 3 else 4
		local cellW = (w - 16 - 8 * (cols - 1)) / cols
		layout.CellSize = UDim2.fromOffset(cellW, cellW * 1.25)
	end
	grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(size)
	size()

	local function refresh()
		local ids = Plot.parseIds((player:GetAttribute("PlotCreatures") or "") :: string)
		local slots =
			Upgrade.value(Config.Upgrades.plotSlots, (player:GetAttribute("plotSlotsLevel") or 0) :: number)
		for _, child in grid:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for slot = 1, slots do
			local id = ids[slot]
			local card = if id then filledCard(id, slot, previews) else emptyCard(slot)
			card.Parent = grid
		end
		slotsLabel.Text = string.format(Config.Text.catboysSlots, #ids, slots)
		empty.Visible = #ids == 0
		local top = TITLE_HEIGHT + if #ids == 0 then EMPTY_HEIGHT else 0
		grid.Position = UDim2.fromOffset(0, top)
		grid.Size = UDim2.new(1, 0, 1, -top)
	end

	player:GetAttributeChangedSignal("PlotCreatures"):Connect(refresh)
	player:GetAttributeChangedSignal("plotSlotsLevel"):Connect(refresh)
	task.spawn(function()
		local folder = ReplicatedStorage:WaitForChild("CreaturePreviews")
		previews = folder
		folder.ChildAdded:Connect(refresh)
		refresh()
	end)

	frame.Parent = parent
	refresh()
	local window: Window = { frame = frame, closeButton = closeButton, refresh = refresh }
	closeButton.Activated:Connect(function()
		CatboysWindow.toggle(window)
	end)
	return window
end

function CatboysWindow.toggle(window: Window)
	local frame = window.frame
	frame.Visible = not frame.Visible
	if frame.Visible then
		local scale = frame:FindFirstChildOfClass("UIScale") :: UIScale
		scale.Scale = 0.9
		TweenService
			:Create(
				scale,
				TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Scale = 1 }
			)
			:Play()
		if UserInputService.GamepadEnabled then
			GuiService.SelectedObject = window.closeButton
		end
		ContextActionService:BindAction("CloseCatboys", function(_, state)
			if state == Enum.UserInputState.Begin then
				CatboysWindow.toggle(window)
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.KeyCode.ButtonB)
	else
		ContextActionService:UnbindAction("CloseCatboys")
		local selected = GuiService.SelectedObject
		if selected and selected:IsDescendantOf(frame) then
			GuiService.SelectedObject = nil
		end
	end
end

return CatboysWindow
