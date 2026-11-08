--!strict
-- Creates every RemoteEvent once, in ReplicatedStorage.Remotes. Services require this directly.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = Instance.new("Folder")
folder.Name = "Remotes"

local function remote(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = folder
	return r
end

local Remotes = {
	train = remote("Train"), -- client -> server
	throw = remote("Throw"), -- client -> server (timing 0..1)
	throwResult = remote("ThrowResult"), -- server -> client (arc + reveal data)
	buyUpgrade = remote("BuyUpgrade"), -- client -> server
	notify = remote("Notify"), -- server -> client (toast text)
}
folder.Parent = ReplicatedStorage

function Remotes.toast(player: Player, text: string)
	Remotes.notify:FireClient(player, text)
end

return Remotes
