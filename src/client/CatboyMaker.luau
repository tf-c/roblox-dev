--!strict
-- Catboy maker panel (Studio play tests, place owner only; press M). Searches the catalog, previews the
-- look on a server-built rig and prints a Config.Creatures entry to paste by hand. Never writes files.

local AvatarEditorService = game:GetService("AvatarEditorService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local CreatureEntry = require(Shared:WaitForChild("CreatureEntry"))

local CatboyMaker = {}

local PANEL = Color3.fromRGB(30, 30, 40)
local FIELD = Color3.fromRGB(45, 45, 60)
local BUTTON = Color3.fromRGB(70, 70, 95)
local ON = Color3.fromRGB(80, 140, 220)
local RED = Color3.fromRGB(255, 110, 110)
local GREY = Color3.fromRGB(200, 200, 210)
local TITLE_HEIGHT = 44
local SKIN_SWATCHES = {
	"#ffe0c8",
	"#f5cba7",
	"#e0ac84",
	"#c68642",
	"#a1665e",
	"#8d5524",
	"#5c3a21",
	"#a8d8ff",
	"#b6e3a1",
	"#d8b4f8",
}

-- Search categories: label, and a bundle or an asset type to search.
local CATEGORIES: { { any } } = {
	{ "Bundles", "bundle" },
	{ "Hats", Enum.AvatarAssetType.Hat },
	{ "Hair", Enum.AvatarAssetType.HairAccessory },
	{ "Face", Enum.AvatarAssetType.FaceAccessory },
	{ "Neck", Enum.AvatarAssetType.NeckAccessory },
	{ "Shoulder", Enum.AvatarAssetType.ShoulderAccessory },
	{ "Front", Enum.AvatarAssetType.FrontAccessory },
	{ "Back", Enum.AvatarAssetType.BackAccessory },
	{ "Waist", Enum.AvatarAssetType.WaistAccessory },
	{ "Shirts", Enum.AvatarAssetType.Shirt },
	{ "Pants", Enum.AvatarAssetType.Pants },
}
local SLIDERS: { { any } } = {
	{ "height", "Height", 0.9, 1.05 },
	{ "width", "Width", 0.7, 1 },
	{ "head", "Head", 0.95, 1 },
	{ "proportion", "Proportion", 0, 1 },
	{ "bodyType", "Body type", 0, 1 },
}
local RARITIES = { "common", "rare", "epic" }

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function layout(parent: Instance, horizontal: boolean?, padding: number?)
	local l = Instance.new("UIListLayout")
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding = UDim.new(0, padding or 6)
	if horizontal then
		l.FillDirection = Enum.FillDirection.Horizontal
		l.Wraps = true
	end
	l.Parent = parent
end

local function label(
	parent: Instance,
	value: string,
	height: number?,
	color: Color3?,
	bold: boolean?
): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, 0, height or 20)
	l.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
	l.TextSize = 14
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.Text = value
	l.Parent = parent
	return l
end

local function button(parent: Instance, value: string, width: number, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(width, 28)
	b.BackgroundColor3 = BUTTON
	b.Font = Enum.Font.GothamBold
	b.TextSize = 14
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = value
	corner(b, 8)
	b.Activated:Connect(onClick)
	b.Parent = parent
	return b
end

local function textbox(
	parent: Instance,
	placeholder: string,
	width: number,
	onDone: ((string) -> ())?
): TextBox
	local t = Instance.new("TextBox")
	t.Size = UDim2.fromOffset(width, 28)
	t.BackgroundColor3 = FIELD
	t.Font = Enum.Font.Gotham
	t.TextSize = 14
	t.TextColor3 = Color3.new(1, 1, 1)
	t.PlaceholderText = placeholder
	t.PlaceholderColor3 = Color3.fromRGB(140, 140, 150)
	t.Text = ""
	t.ClearTextOnFocus = false
	corner(t, 8)
	if onDone then
		t.FocusLost:Connect(function()
			onDone(t.Text)
		end)
	end
	t.Parent = parent
	return t
end

-- A wrapping horizontal strip.
local function row(parent: Instance): Frame
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromScale(1, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	layout(f, true, 4)
	f.Parent = parent
	return f
end

local function setOn(b: TextButton, on: boolean)
	b.BackgroundColor3 = if on then ON else BUTTON
end

local function clear(parent: Instance)
	for _, child in parent:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIGridLayout") then
			child:Destroy()
		end
	end
end

local function thumb(kind: string, id: number): string
	return string.format("rbxthumb://type=%s&id=%d&w=150&h=150", kind, id)
end

-- A thumbnail with a caption and a small corner button (x to remove, + to restore).
local function chip(parent: Instance, image: string, caption: string, symbol: string, onClick: () -> ())
	local f = Instance.new("Frame")
	f.Size = UDim2.fromOffset(64, 82)
	f.BackgroundTransparency = 1
	local img = Instance.new("ImageLabel")
	img.Size = UDim2.fromOffset(64, 64)
	img.BackgroundColor3 = FIELD
	img.Image = image
	corner(img, 8)
	img.Parent = f
	local cap = label(f, caption, 16, GREY)
	cap.Position = UDim2.fromOffset(0, 66)
	cap.TextSize = 11
	local x = button(f, symbol, 22, onClick)
	x.Position = UDim2.fromOffset(42, 0)
	x.Size = UDim2.fromOffset(22, 22)
	x.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
	f.Parent = parent
end

local function build(player: Player, remote: RemoteEvent)
	-- State: the look being edited and the entry details.
	local look = {
		bundleId = nil :: number?,
		shirt = nil :: number?,
		pants = nil :: number?,
		skinColor = nil :: string?,
		accessoryIds = {} :: { number },
		removeAccessoryIds = {} :: { number },
		scale = {} :: { [string]: number? },
	}
	local rigIds: { number } = {}
	local rarity = "common"
	local zonesOn: { [string]: boolean } = {}
	local weights: { [string]: string } = {}

	local function lookTable(): { [string]: any }
		local out: { [string]: any } = {
			bundleId = look.bundleId,
			shirt = look.shirt,
			pants = look.pants,
			skinColor = look.skinColor,
		}
		if #look.accessoryIds > 0 then
			out.accessoryIds = look.accessoryIds
		end
		if #look.removeAccessoryIds > 0 then
			out.removeAccessoryIds = look.removeAccessoryIds
		end
		if next(look.scale) then
			out.scale = look.scale
		end
		return out
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "CatboyMakerGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10

	local panel = Instance.new("Frame")
	panel.Visible = false
	panel.BackgroundColor3 = PANEL
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -8, 0, 8)
	panel.Size = UDim2.new(0, 380, 1, -16)
	corner(panel, 16)
	local panelStroke = Instance.new("UIStroke")
	panelStroke.Thickness = 3
	panelStroke.Color = Color3.fromHex("#1e1e28")
	panelStroke.Parent = panel
	panel.Parent = gui

	local title = label(panel, "Catboy maker", TITLE_HEIGHT)
	title.Position = UDim2.fromOffset(12, 0)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 22
	local close = button(panel, "X", 44, function()
		panel.Visible = false
	end)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -4, 0, 0)
	close.Size = UDim2.fromOffset(44, 44)
	close.BackgroundColor3 = Color3.fromRGB(220, 60, 60)

	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(8, TITLE_HEIGHT + 4)
	scroll.Size = UDim2.new(1, -16, 1, -TITLE_HEIGHT - 12)
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 6
	layout(scroll, false, 14)
	scroll.Parent = panel

	local order = 0
	local function section(heading: string): Frame
		order += 1
		local s = Instance.new("Frame")
		s.BackgroundTransparency = 1
		s.Size = UDim2.new(1, -8, 0, 0)
		s.AutomaticSize = Enum.AutomaticSize.Y
		s.LayoutOrder = order
		layout(s, false, 6)
		label(s, heading, 20, nil, true).TextSize = 16
		s.Parent = scroll
		return s
	end

	local status: TextLabel
	local function setStatus(value: string, isError: boolean?)
		status.Text = value
		status.TextColor3 = if isError then RED else GREY
	end

	-- Any look change redraws the chips and, after a short pause, asks the server to rebuild the rig.
	local renderChips: () -> ()
	local token = 0
	local function changed()
		renderChips()
		if not look.bundleId then
			setStatus("Pick a bundle to start")
			return
		end
		setStatus("Building...")
		token += 1
		local mine = token
		task.delay(0.3, function()
			if mine == token then
				remote:FireServer(lookTable())
			end
		end)
	end

	-- 1. Search
	local search = section("Search")
	local keyword = textbox(search, "Search the catalog", 340)
	local categoryRow = row(search)
	local category = 1
	local categoryButtons: { TextButton } = {}
	for index, entry in CATEGORIES do
		categoryButtons[index] = button(categoryRow, entry[1] :: string, 76, function()
			category = index
			for i, b in categoryButtons do
				setOn(b, i == index)
			end
		end)
	end
	setOn(categoryButtons[1], true)
	local robloxOnly = true
	local robloxButton: TextButton
	robloxButton = button(search, "Roblox only", 120, function()
		robloxOnly = not robloxOnly
		setOn(robloxButton, robloxOnly)
	end)
	setOn(robloxButton, true)

	local results = Instance.new("Frame")
	results.BackgroundTransparency = 1
	results.Size = UDim2.fromScale(1, 0)
	results.AutomaticSize = Enum.AutomaticSize.Y
	results.LayoutOrder = 100
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(100, 124)
	grid.CellPadding = UDim2.fromOffset(8, 4)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = results
	local pages: any
	local resultKind = "bundle"
	local moreButton: TextButton

	local function pick(kind: string, id: number)
		if kind == "bundle" then
			look.bundleId = id
		elseif kind == "shirt" then
			look.shirt = id
		elseif kind == "pants" then
			look.pants = id
		elseif not table.find(look.accessoryIds, id) then
			table.insert(look.accessoryIds, id)
		end
		changed()
	end

	local function showPage()
		for _, item in pages:GetCurrentPage() do
			local cell = Instance.new("Frame")
			cell.BackgroundTransparency = 1
			local img = Instance.new("ImageButton")
			img.Size = UDim2.fromOffset(100, 100)
			img.BackgroundColor3 = FIELD
			img.Image = thumb(if item.ItemType == "Bundle" then "BundleThumbnail" else "Asset", item.Id)
			corner(img, 8)
			local kind = resultKind
			img.Activated:Connect(function()
				pick(kind, item.Id)
			end)
			img.Parent = cell
			local name = label(cell, item.Name, 20, GREY)
			name.Position = UDim2.fromOffset(0, 102)
			name.TextSize = 11
			name.TextTruncate = Enum.TextTruncate.AtEnd
			cell.Parent = results
		end
		moreButton.Visible = not pages.IsFinished
	end

	local function runSearch()
		clear(results)
		moreButton.Visible = false
		local params = CatalogSearchParams.new()
		params.SearchKeyword = keyword.Text
		if robloxOnly then
			params.CreatorName = "Roblox"
		end
		local assetType = CATEGORIES[category][2]
		if assetType == "bundle" then
			params.BundleTypes = { Enum.BundleType.BodyParts }
			resultKind = "bundle"
		else
			params.AssetTypes = { assetType :: Enum.AvatarAssetType }
			resultKind = if assetType == Enum.AvatarAssetType.Shirt
				then "shirt"
				elseif assetType == Enum.AvatarAssetType.Pants then "pants"
				else "accessory"
		end
		local ok, found = pcall(function()
			return AvatarEditorService:SearchCatalog(params)
		end)
		if not ok then
			setStatus("Search failed: " .. tostring(found), true)
			return
		end
		pages = found
		showPage()
	end
	button(search, "Search", 100, runSearch)
	keyword.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			runSearch()
		end
	end)
	results.Parent = search
	moreButton = button(search, "More", 100, function()
		local ok, err = pcall(function()
			pages:AdvanceToNextPageAsync()
		end)
		if ok then
			showPage()
		else
			setStatus("Search failed: " .. tostring(err), true)
		end
	end)
	moreButton.Visible = false
	moreButton.LayoutOrder = 101

	-- 2. On the rig
	local rig = section("On the rig")
	status = label(rig, "Pick a bundle to start", 20, GREY)
	local chips = row(rig)
	label(rig, "Removed", 18, GREY, true)
	local removed = row(rig)

	function renderChips()
		clear(chips)
		clear(removed)
		if look.bundleId then
			chip(chips, thumb("BundleThumbnail", look.bundleId), "bundle " .. look.bundleId, "x", function()
				look.bundleId = nil
				changed()
			end)
		end
		if look.shirt then
			chip(chips, thumb("Asset", look.shirt), "shirt " .. look.shirt, "x", function()
				look.shirt = nil
				changed()
			end)
		end
		if look.pants then
			chip(chips, thumb("Asset", look.pants), "pants " .. look.pants, "x", function()
				look.pants = nil
				changed()
			end)
		end
		for _, id in rigIds do
			chip(chips, thumb("Asset", id), tostring(id), "x", function()
				local at = table.find(look.accessoryIds, id)
				if at then
					table.remove(look.accessoryIds, at)
				else
					table.insert(look.removeAccessoryIds, id)
				end
				changed()
			end)
		end
		for index, id in look.removeAccessoryIds do
			chip(removed, thumb("Asset", id), tostring(id), "+", function()
				table.remove(look.removeAccessoryIds, index)
				changed()
			end)
		end
	end

	remote.OnClientEvent:Connect(function(ok: boolean, data: any)
		if ok then
			rigIds = data
			renderChips()
			setStatus("Ready")
		else
			setStatus(tostring(data), true)
		end
	end)

	-- 3. Skin
	local skin = section("Skin")
	local swatches = row(skin)
	for _, hex in SKIN_SWATCHES do
		local s = button(swatches, "", 28, function()
			look.skinColor = hex
			changed()
		end)
		s.BackgroundColor3 = Color3.fromHex(hex)
	end
	local skinRow = row(skin)
	textbox(skinRow, "#rrggbb", 100, function(value)
		if string.match(value, "^#%x%x%x%x%x%x$") then
			look.skinColor = value
			changed()
		end
	end)
	button(skinRow, "Bundle skin", 110, function()
		look.skinColor = nil
		changed()
	end)

	-- 4. Scale
	local scaleSection = section("Scale")
	for _, def in SLIDERS do
		local field, name, lo, hi = def[1] :: string, def[2] :: string, def[3] :: number, def[4] :: number
		local line = Instance.new("Frame")
		line.BackgroundTransparency = 1
		line.Size = UDim2.new(1, 0, 0, 28)
		line.Parent = scaleSection
		local caption = label(line, name, 28)
		caption.Size = UDim2.fromOffset(80, 28)
		local bar = Instance.new("Frame")
		bar.Position = UDim2.fromOffset(84, 10)
		bar.Size = UDim2.fromOffset(150, 8)
		bar.BackgroundColor3 = FIELD
		corner(bar, 4)
		bar.Parent = line
		local knob = Instance.new("Frame")
		knob.AnchorPoint = Vector2.new(0.5, 0.5)
		knob.Size = UDim2.fromOffset(16, 16)
		corner(knob, 8)
		knob.Parent = bar
		local readout = label(line, "", 28, GREY)
		readout.Position = UDim2.fromOffset(242, 0)
		readout.Size = UDim2.fromOffset(60, 28)
		local function show(value: number?)
			look.scale[field] = value
			knob.Position = UDim2.fromScale(if value then (value - lo) / (hi - lo) else 0, 0.5)
			knob.BackgroundColor3 = if value then ON else BUTTON
			readout.Text = if value then string.format("%.2f", value) else "default"
		end
		show(nil)
		local dragging = false
		local function drag(x: number)
			local frac = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
			show(math.floor((lo + frac * (hi - lo)) * 100 + 0.5) / 100)
		end
		bar.InputBegan:Connect(function(input)
			if isPress(input) then
				dragging = true
				drag(input.Position.X)
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if
				dragging
				and (
					input.UserInputType == Enum.UserInputType.MouseMovement
					or input.UserInputType == Enum.UserInputType.Touch
				)
			then
				drag(input.Position.X)
			end
		end)
		UserInputService.InputEnded:Connect(function(input)
			if dragging and isPress(input) then
				dragging = false
				changed()
			end
		end)
		local reset = button(line, "x", 28, function()
			show(nil)
			changed()
		end)
		reset.Position = UDim2.fromOffset(306, 0)
	end

	-- 5. Details
	local details = section("Details")
	local idBox = textbox(details, "lowercase, e.g. mochi", 340)
	local idNote = label(details, "", 18, GREY)
	idBox:GetPropertyChangedSignal("Text"):Connect(function()
		local existing = Config.Creatures[idBox.Text]
		idNote.Text = if existing then "Replaces the existing " .. existing.name else ""
	end)
	local nameBox = textbox(details, "Name", 340)
	local rarityRow = row(details)
	local rarityButtons: { [string]: TextButton } = {}
	local incomeBox = textbox(details, "Income", 340)
	local function showRarity()
		local incomes = {}
		for _, def in Config.Creatures do
			if def.rarity == rarity then
				table.insert(incomes, def.income)
			end
		end
		table.sort(incomes)
		for name, b in rarityButtons do
			b.BackgroundColor3 = if name == rarity then Color3.fromHex(Config.RarityColors[name]) else BUTTON
			b.TextColor3 = if name == rarity then PANEL else Color3.new(1, 1, 1)
		end
		incomeBox.PlaceholderText = string.format("%s now: %s", rarity, table.concat(incomes, ", "))
	end
	for _, name in RARITIES do
		rarityButtons[name] = button(rarityRow, name:sub(1, 1):upper() .. name:sub(2), 80, function()
			rarity = name
			showRarity()
		end)
	end
	showRarity()
	local colorRow = row(details)
	local colorBox = textbox(colorRow, "Ears and hair color, #rrggbb", 280)
	local colorPreview = Instance.new("Frame")
	colorPreview.Size = UDim2.fromOffset(28, 28)
	colorPreview.BackgroundColor3 = BUTTON
	corner(colorPreview, 8)
	colorPreview.Parent = colorRow
	colorBox:GetPropertyChangedSignal("Text"):Connect(function()
		if string.match(colorBox.Text, "^#%x%x%x%x%x%x$") then
			colorPreview.BackgroundColor3 = Color3.fromHex(colorBox.Text)
		end
	end)
	for _, zone in Config.Zones do
		local line = row(details)
		local box: TextButton
		box = button(line, "", 28, function()
			zonesOn[zone.id] = not zonesOn[zone.id]
			box.Text = if zonesOn[zone.id] then "✓" else ""
			setOn(box, zonesOn[zone.id])
		end)
		local zoneName = label(line, Config.ZoneLooks[zone.id].name, 28)
		zoneName.Size = UDim2.fromOffset(120, 28)
		textbox(line, "weight", 80, function(value)
			weights[zone.id] = value
		end)
	end

	-- 6. Config entry
	local entrySection = section("Config entry")
	local output = Instance.new("TextBox")
	output.Size = UDim2.new(1, 0, 0, 180)
	output.BackgroundColor3 = FIELD
	output.Font = Enum.Font.Code
	output.TextSize = 13
	output.TextColor3 = Color3.new(1, 1, 1)
	output.TextXAlignment = Enum.TextXAlignment.Left
	output.TextYAlignment = Enum.TextYAlignment.Top
	output.MultiLine = true
	output.TextWrapped = true
	output.ClearTextOnFocus = false
	output.TextEditable = true
	output.Text = ""
	output.Visible = false
	output.LayoutOrder = 2
	corner(output, 8)
	local problems = label(entrySection, "", 20, RED)
	problems.AutomaticSize = Enum.AutomaticSize.Y
	problems.LayoutOrder = 1
	local make = button(entrySection, "Make entry", 140, function()
		local zones: { [string]: number } = {}
		local zoneIds = {}
		for _, zone in Config.Zones do
			table.insert(zoneIds, zone.id)
			if zonesOn[zone.id] then
				zones[zone.id] = tonumber(weights[zone.id]) or 0
			end
		end
		local entry: any = {
			name = nameBox.Text,
			rarity = rarity,
			income = tonumber(incomeBox.Text) or 0,
			color = colorBox.Text,
			zones = zones,
			look = lookTable(),
		}
		local found = CreatureEntry.validate(idBox.Text, entry, zoneIds)
		problems.Text = table.concat(found, "\n")
		output.Visible = #found == 0
		if #found == 0 then
			output.Text = CreatureEntry.format(idBox.Text, entry)
			print("Paste into Config.Creatures in src/shared/Config.luau:\n" .. output.Text)
		end
	end)
	make.LayoutOrder = 0
	output.Parent = entrySection

	renderChips()
	gui.Parent = player:WaitForChild("PlayerGui")
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.M then
			panel.Visible = not panel.Visible
		end
	end)
	print("Catboy maker: press M")
end

function CatboyMaker.init()
	if not RunService:IsStudio() then
		return
	end
	task.spawn(function()
		local player = Players.LocalPlayer :: Player
		if not player:GetAttribute("CatboyMaker") then
			player:GetAttributeChangedSignal("CatboyMaker"):Wait()
		end
		build(player, ReplicatedStorage:WaitForChild("CatboyMakerPreview") :: RemoteEvent)
	end)
end

return CatboyMaker
