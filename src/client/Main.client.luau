--!strict
-- Client entry: builds the HUD and wires the meter, training, reveal, stats and upgrades.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Upgrade = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Upgrade"))
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

-- Stats line + upgrade buttons, refreshed from leaderstats and attributes.
local leaderstats = player:WaitForChild("leaderstats")
local powerValue = leaderstats:WaitForChild("Power") :: IntValue
local cashValue = leaderstats:WaitForChild("Cash") :: IntValue

local function refresh()
	hud.stats.Text = string.format(
		"Power %d   ·   Cash %d   ·   Plot %d/%d",
		powerValue.Value,
		cashValue.Value,
		(player:GetAttribute("PlotCount") or 0) :: number,
		Upgrade.value(Config.Upgrades.plotSlots, (player:GetAttribute("plotSlotsLevel") or 0) :: number)
	)
	for id, button in hud.upgrades do
		local ladder = Config.Upgrades[id]
		local level = (player:GetAttribute(id .. "Level") or 0) :: number
		local price = Upgrade.nextPrice(ladder, level)
		button.Visible = price ~= nil
		if price ~= nil then
			button.Text = string.format(
				"%s: " .. ladder.text .. "\n%d cash",
				ladder.name,
				Upgrade.value(ladder, level + 1),
				price
			)
			button.BackgroundColor3 = if cashValue.Value >= price
				then Color3.fromRGB(220, 150, 40)
				else Color3.fromRGB(80, 80, 80)
		end
	end
end

powerValue.Changed:Connect(refresh)
cashValue.Changed:Connect(refresh)
player:GetAttributeChangedSignal("PlotCount"):Connect(refresh)
for id, button in hud.upgrades do
	player:GetAttributeChangedSignal(id .. "Level"):Connect(refresh)
	button.Activated:Connect(function()
		remote("BuyUpgrade"):FireServer(id)
	end)
end
refresh()
