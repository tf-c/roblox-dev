--!strict
-- Lune test runner: `lune run tests/run` from the repo root.
-- Each spec returns { [caseName]: () -> () }. Any error is a failure.

local fs = require("@lune/fs")
local process = require("@lune/process")

type Spec = { [string]: () -> () }

local specs: { { name: string, cases: Spec } } = {
	{ name = "Distance", cases = require("./Distance.spec") :: any },
	{ name = "Zone", cases = require("./Zone.spec") :: any },
	{ name = "WeightedRoll", cases = require("./WeightedRoll.spec") :: any },
	{ name = "Income", cases = require("./Income.spec") :: any },
	{ name = "Config", cases = require("./Config.spec") :: any },
}

-- Guard against a new spec file that was never registered above.
local registered: { [string]: boolean } = {}
for _, spec in specs do
	registered[spec.name .. ".spec.luau"] = true
end
for _, file in fs.readDir("tests") do
	if string.match(file, "%.spec%.luau$") and not registered[file] then
		print("unregistered spec file: " .. file)
		process.exit(1)
	end
end

local passed, failed = 0, 0
for _, spec in specs do
	local names = {}
	for caseName in spec.cases do
		table.insert(names, caseName)
	end
	table.sort(names)
	for _, caseName in names do
		local ok, err = pcall(spec.cases[caseName])
		if ok then
			passed += 1
			print("  pass  " .. spec.name .. " > " .. caseName)
		else
			failed += 1
			print("  FAIL  " .. spec.name .. " > " .. caseName .. "\n        " .. tostring(err))
		end
	end
end

print(string.format("\n%d passed, %d failed", passed, failed))
process.exit(if failed > 0 then 1 else 0)
