--!strict
-- Client entry: builds the HUD and wires the meter, training, reveal, stats and upgrade.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Hud = require(script.Parent.Hud)
local MeterController = require(script.Parent.MeterController)
local RevealController = require(script.Parent.RevealController)
local TrainController = require(script.Parent.TrainController)

local player = Players.LocalPlayer :: Player
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local function remote(name: string): RemoteEvent
	return remotes:WaitForChild(name) :: RemoteEvent
end

local hud = Hud.create()
MeterController.init(hud, remote("Throw"))
TrainController.init(hud, remote("Train"))
RevealController.init(hud, remote("ThrowResult"))

remote("Notify").OnClientEvent:Connect(function(text: string)
	Hud.toast(hud, text)
end)

-- Stats line + upgrade button, refreshed from leaderstats and attributes.
local leaderstats = player:WaitForChild("leaderstats")
local powerValue = leaderstats:WaitForChild("Power") :: IntValue
local cashValue = leaderstats:WaitForChild("Cash") :: IntValue

local function refresh()
	hud.stats.Text = string.format(
		"Power %d   ·   Cash %d   ·   Plot %d/%d",
		powerValue.Value,
		cashValue.Value,
		(player:GetAttribute("PlotCount") or 0) :: number,
		Config.Plot.slots
	)
	local upgraded = player:GetAttribute("Upgraded") == true
	hud.upgrade.Visible = not upgraded
	local affordable = cashValue.Value >= Config.Upgrade.price
	hud.upgrade.Text = string.format(
		"%s\n%d cash · %s",
		Config.Upgrade.name,
		Config.Upgrade.price,
		Config.Upgrade.description
	)
	hud.upgrade.BackgroundColor3 = if affordable
		then Color3.fromRGB(220, 150, 40)
		else Color3.fromRGB(80, 80, 80)
end

powerValue.Changed:Connect(refresh)
cashValue.Changed:Connect(refresh)
player:GetAttributeChangedSignal("PlotCount"):Connect(refresh)
player:GetAttributeChangedSignal("Upgraded"):Connect(refresh)
refresh()

hud.upgrade.Activated:Connect(function()
	remote("BuyUpgrade"):FireServer()
end)
