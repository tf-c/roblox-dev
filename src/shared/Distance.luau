--!strict
-- Pure: throw distance from Power and meter timing. No requires, no Roblox APIs.

export type MeterConfig = {
	sweetCenter: number,
	sweetHalfWidth: number,
	perfectMult: number,
	edgeMult: number,
}

export type DistanceConfig = {
	baseDistance: number,
	powerScale: number,
	meter: MeterConfig,
}

local Distance = {}

-- Treat anything that isn't a finite number (NaN, strings, nil from a client) as `fallback`.
local function sanitize(value: any, fallback: number): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return fallback
	end
	return value
end

-- Multiplier from meter position: flat `perfectMult` across the sweet spot,
-- falling linearly to `edgeMult` at 0 and at 1.
function Distance.meterMultiplier(timing: number, meter: MeterConfig): number
	local t = math.clamp(sanitize(timing, 0), 0, 1)
	local lo = meter.sweetCenter - meter.sweetHalfWidth
	local hi = meter.sweetCenter + meter.sweetHalfWidth
	local span = meter.perfectMult - meter.edgeMult

	if t >= lo and t <= hi then
		return meter.perfectMult
	elseif t < lo then
		return meter.edgeMult + span * (t / lo)
	else
		return meter.edgeMult + span * ((1 - t) / (1 - hi))
	end
end

function Distance.compute(power: number, timing: number, cfg: DistanceConfig): number
	local p = math.max(sanitize(power, 0), 0)
	return (cfg.baseDistance + cfg.powerScale * math.sqrt(p)) * Distance.meterMultiplier(timing, cfg.meter)
end

return Distance
