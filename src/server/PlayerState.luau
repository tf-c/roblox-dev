--!strict
-- In-memory player state for the prototype. Saving waits until the loop proves fun.
-- leaderstats mirror Power and Cash; attributes on the Player tell the client
-- what it can do (HasPending, Upgraded, PlotCount).

export type Pending = {
	token: number,
	creatureId: string,
	model: BasePart?,
}

export type State = {
	power: number,
	cash: number,
	plot: { [number]: string },
	pending: Pending?,
	upgraded: boolean,
	lastThrow: number,
}

local PlayerState = {}

local states: { [Player]: State } = {}

local function makeStat(parent: Instance, name: string): IntValue
	local value = Instance.new("IntValue")
	value.Name = name
	value.Parent = parent
	return value
end

function PlayerState.add(player: Player)
	local state: State = {
		power = 0,
		cash = 0,
		plot = {},
		pending = nil,
		upgraded = false,
		lastThrow = -math.huge,
	}
	states[player] = state

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	makeStat(leaderstats, "Power")
	makeStat(leaderstats, "Cash")
	leaderstats.Parent = player

	PlayerState.sync(player)
end

function PlayerState.get(player: Player): State?
	return states[player]
end

function PlayerState.remove(player: Player)
	local state = states[player]
	if state and state.pending and state.pending.model then
		state.pending.model:Destroy()
	end
	states[player] = nil
end

function PlayerState.all(): { [Player]: State }
	return states
end

-- Push state to leaderstats and attributes so the client can read it.
function PlayerState.sync(player: Player)
	local state = states[player]
	if not state then
		return
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local power = leaderstats:FindFirstChild("Power") :: IntValue?
		local cash = leaderstats:FindFirstChild("Cash") :: IntValue?
		if power then
			power.Value = math.floor(state.power)
		end
		if cash then
			cash.Value = math.floor(state.cash)
		end
	end
	local count = 0
	for _ in state.plot do
		count += 1
	end
	player:SetAttribute("HasPending", state.pending ~= nil)
	player:SetAttribute("Upgraded", state.upgraded)
	player:SetAttribute("PlotCount", count)
end

return PlayerState
