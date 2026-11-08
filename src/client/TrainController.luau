--!strict
-- Hold Train (button or Q) to raise Power. Fires at the server's allowed rate;
-- the server rate-limits again and owns the Power value.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Hud = require(script.Parent.Hud)

local TrainController = {}

function TrainController.init(hud: Hud.Hud, trainRemote: RemoteEvent)
	local holds: { [InputObject]: boolean } = {}
	local looping = false

	local function holding(): boolean
		return next(holds) ~= nil
	end

	local function startLoop()
		if looping then
			return
		end
		looping = true
		task.spawn(function()
			local interval = 1 / Config.Train.maxPerSecond
			while holding() do
				trainRemote:FireServer()
				hud.trainButton.Rotation = if hud.trainButton.Rotation == 0 then 4 else 0
				task.wait(interval)
			end
			hud.trainButton.Rotation = 0
			looping = false
		end)
	end

	local function track(input: InputObject)
		holds[input] = true
		startLoop()
	end

	hud.trainButton.InputBegan:Connect(function(input: InputObject)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			track(input)
		end
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not processed and input.KeyCode == Enum.KeyCode.Q then
			track(input)
		end
	end)
	-- Release anywhere on screen ends the hold (a finger can slide off the button).
	UserInputService.InputEnded:Connect(function(input: InputObject)
		holds[input] = nil
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			for held in holds do
				if held.UserInputType == Enum.UserInputType.MouseButton1 then
					holds[held] = nil
				end
			end
		end
	end)
end

return TrainController
