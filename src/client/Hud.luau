--!strict
-- Placeholder HUD for the core-loop prototype (not the UX layer).
-- Bottom-center controls so they clear the mobile thumbstick (left) and jump button (right).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

export type Hud = {
	gui: ScreenGui,
	stats: TextLabel,
	toast: TextLabel,
	reveal: TextLabel,
	revealSub: TextLabel,
	upgrades: { [string]: TextButton },
	meter: Frame,
	sweet: Frame,
	marker: Frame,
	meterHint: TextLabel,
	trainButton: TextButton,
	throwButton: TextButton,
}

local Hud = {}

local BUTTON = 120
local BOTTOM_GAP = 24

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function label(name: string, parent: Instance): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.4
	l.TextScaled = true
	l.Parent = parent
	return l
end

local function bigButton(
	name: string,
	text: string,
	color: Color3,
	xOffset: number,
	parent: Instance
): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.AnchorPoint = Vector2.new(0.5, 1)
	b.Position = UDim2.new(0.5, xOffset, 1, -BOTTOM_GAP)
	b.Size = UDim2.fromOffset(BUTTON, BUTTON)
	b.BackgroundColor3 = color
	b.Font = Enum.Font.GothamBlack
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextSize = 28
	b.Text = text
	b.AutoButtonColor = true
	corner(b, BUTTON // 2)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.new(1, 1, 1)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = b
	b.Parent = parent
	return b
end

function Hud.create(): Hud
	local gui = Instance.new("ScreenGui")
	gui.Name = "SeedTossHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false

	local stats = label("Stats", gui)
	stats.AnchorPoint = Vector2.new(0.5, 0)
	stats.Position = UDim2.new(0.5, 0, 0, 8)
	stats.Size = UDim2.new(0.8, 0, 0, 30)

	local toast = label("Toast", gui)
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, 44)
	toast.Size = UDim2.new(0.8, 0, 0, 26)
	toast.TextColor3 = Color3.fromRGB(255, 230, 140)
	toast.Text = ""

	local reveal = label("Reveal", gui)
	reveal.AnchorPoint = Vector2.new(0.5, 0.5)
	reveal.Position = UDim2.fromScale(0.5, 0.28)
	reveal.Size = UDim2.new(0.8, 0, 0, 56)
	reveal.TextStrokeTransparency = 0 -- full outline so light rarity colors read against the sky
	reveal.Text = ""

	local revealSub = label("RevealSub", gui)
	revealSub.AnchorPoint = Vector2.new(0.5, 0.5)
	revealSub.Position = UDim2.new(0.5, 0, 0.28, 46)
	revealSub.Size = UDim2.new(0.8, 0, 0, 32)
	revealSub.TextStrokeTransparency = 0
	revealSub.Text = ""

	local upgrades: { [string]: TextButton } = {}
	local count = #Config.UpgradeOrder
	for i, id in Config.UpgradeOrder do
		local button = Instance.new("TextButton")
		button.Name = "Upgrade_" .. id
		-- Left middle: clear of the player list (top right) and the mobile thumbstick (bottom left).
		button.AnchorPoint = Vector2.new(0, 0.5)
		button.Position = UDim2.new(0, 12, 0.5, (i - (count + 1) / 2) * 64)
		button.Size = UDim2.fromOffset(190, 56)
		button.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
		button.Font = Enum.Font.GothamBold
		button.TextColor3 = Color3.new(1, 1, 1)
		button.TextScaled = true
		corner(button, 10)
		button.Parent = gui
		upgrades[id] = button
	end

	-- Timing meter: wide bar above the two buttons, sweet spot in the middle.
	local meter = Instance.new("Frame")
	meter.Name = "Meter"
	meter.AnchorPoint = Vector2.new(0.5, 1)
	meter.Position = UDim2.new(0.5, 0, 1, -(BOTTOM_GAP + BUTTON + 20))
	meter.Size = UDim2.new(0.7, 0, 0, 40)
	meter.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	meter.BackgroundTransparency = 0.2
	corner(meter, 10)
	local maxWidth = Instance.new("UISizeConstraint")
	maxWidth.MaxSize = Vector2.new(560, 40)
	maxWidth.Parent = meter
	meter.Parent = gui

	local sweet = Instance.new("Frame")
	sweet.Name = "Sweet"
	sweet.AnchorPoint = Vector2.new(0.5, 0)
	sweet.BackgroundColor3 = Color3.fromRGB(110, 220, 90)
	sweet.BorderSizePixel = 0
	sweet.Parent = meter

	local marker = Instance.new("Frame")
	marker.Name = "Marker"
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.Position = UDim2.fromScale(0, 0.5)
	marker.Size = UDim2.new(0, 8, 1, 14)
	marker.BackgroundColor3 = Color3.new(1, 1, 1)
	marker.BorderSizePixel = 0
	corner(marker, 4)
	marker.Parent = meter

	local meterHint = label("Hint", meter)
	meterHint.AnchorPoint = Vector2.new(0.5, 1)
	meterHint.Position = UDim2.new(0.5, 0, 0, -4)
	meterHint.Size = UDim2.new(1, 0, 0, 22)
	meterHint.Text = ""

	local trainButton = bigButton("Train", "Train", Color3.fromRGB(70, 130, 220), -(BUTTON // 2 + 12), gui)
	local throwButton = bigButton("Throw", "Throw", Color3.fromRGB(70, 170, 70), BUTTON // 2 + 12, gui)

	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")

	return {
		gui = gui,
		stats = stats,
		toast = toast,
		reveal = reveal,
		revealSub = revealSub,
		upgrades = upgrades,
		meter = meter,
		sweet = sweet,
		marker = marker,
		meterHint = meterHint,
		trainButton = trainButton,
		throwButton = throwButton,
	}
end

local toastToken = 0
function Hud.toast(hud: Hud, text: string)
	toastToken += 1
	local token = toastToken
	hud.toast.Text = text
	hud.toast.TextTransparency = 0
	task.delay(2.5, function()
		if token == toastToken then
			TweenService:Create(hud.toast, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		end
	end)
end

return Hud
