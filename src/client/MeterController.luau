--!strict
-- Timing meter: the marker ping-pongs across the bar; Throw (button or E) stops it
-- and sends the position (0..1) to the server. The server does everything else.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Hud = require(script.Parent.Hud)

local MeterController = {}

local FREEZE_SECONDS = 0.6

-- 0 -> 1 -> 0 triangle wave.
local function pingPong(t: number): number
	local p = (t % 1) * 2
	return if p > 1 then 2 - p else p
end

function MeterController.init(hud: Hud.Hud, throwRemote: RemoteEvent)
	local player = Players.LocalPlayer :: Player
	local meterCfg = Config.Meter

	hud.sweet.Position = UDim2.fromScale(meterCfg.sweetCenter, 0)
	hud.sweet.Size = UDim2.fromScale(meterCfg.sweetHalfWidth * 2, 1)

	local startClock = os.clock()
	local frozenUntil = 0
	local cooldownUntil = 0
	local position = 0

	local function ready(): boolean
		return not player:GetAttribute("HasPending") and os.clock() >= cooldownUntil
	end

	local function throw()
		if not ready() then
			return
		end
		local now = os.clock()
		frozenUntil = now + FREEZE_SECONDS
		cooldownUntil = now + Config.Throw.cooldownSeconds
		throwRemote:FireServer(position)
	end

	hud.throwButton.Activated:Connect(throw)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not processed and input.KeyCode == Enum.KeyCode.E then
			throw()
		end
	end)

	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local isReady = ready()
		if now >= frozenUntil and isReady then
			position = pingPong((now - startClock) * Config.MeterMotion.cyclesPerSecond)
		end
		hud.marker.Position = UDim2.fromScale(position, 0.5)

		local dim = not isReady and now >= frozenUntil
		hud.meter.BackgroundTransparency = if dim then 0.6 else 0.2
		hud.throwButton.BackgroundTransparency = if isReady then 0 else 0.5
		if player:GetAttribute("HasPending") and now >= frozenUntil then
			hud.meterHint.Text = if Config.CollectMode == "walk" then Config.Text.walkHint else ""
		elseif isReady then
			hud.meterHint.Text = "Stop the marker in the green"
		else
			hud.meterHint.Text = ""
		end
	end)
end

return MeterController
