--!strict
-- Minimal assertion helpers for Lune specs. No framework dependency.

local Assert = {}

local function fmt(v: any): string
	if type(v) == "string" then
		return string.format("%q", v)
	end
	return tostring(v)
end

function Assert.eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(
			string.format("%sexpected %s, got %s", msg and (msg .. ": ") or "", fmt(expected), fmt(actual)),
			2
		)
	end
end

function Assert.near(actual: number, expected: number, tolerance: number, msg: string?)
	if math.abs(actual - expected) > tolerance then
		error(
			string.format(
				"%sexpected %s ± %s, got %s",
				msg and (msg .. ": ") or "",
				fmt(expected),
				fmt(tolerance),
				fmt(actual)
			),
			2
		)
	end
end

function Assert.truthy(value: any, msg: string?)
	if not value then
		error(msg or "expected truthy value", 2)
	end
end

function Assert.throws(fn: () -> (), msg: string?)
	local ok = pcall(fn)
	if ok then
		error(msg or "expected function to throw", 2)
	end
end

return Assert
