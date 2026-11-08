# Plan 002: Build each player's starting upgrade levels from Config instead of hardcoding them

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report, do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 9ef9f70..HEAD -- src/shared/Upgrade.luau src/server/PlayerState.luau tests/Upgrade.spec.luau tests/Pacing.spec.luau`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/001-typecheck-baseline.md (for the type check command)
- **Category**: tech-debt
- **Planned at**: commit `9ef9f70`, 2026-11-08

## Why this matters

The upgrade ladders are defined in `Config.Upgrades` and ordered by `Config.UpgradeOrder`, but the starting levels table `{ trowel = 0, plotSlots = 0 }` is typed out by hand in two other places. The game is about to be reskinned (seeds to a catboy theme), which will likely add or rename ladders. Today a new ladder in Config silently has no starting level in those two places. After this plan, adding a ladder to Config is the only edit needed.

## Current state

Strict-mode Luau Roblox game. `src/shared/` is pure Luau with no requires and no Roblox APIs, so Lune can unit-test it. Each module there starts with `--!strict` and a one-line comment saying what it does.

- `src/shared/Config.luau`, all tuning data. Lines 136-137:
  ```lua
  -- HUD button order, top to bottom.
  Config.UpgradeOrder = { "trowel", "plotSlots" }
  ```
- `src/shared/Upgrade.luau`, pure ladder helpers (24 lines). Exemplar style:
  ```lua
  -- Price of the next level, or nil when maxed.
  function Upgrade.nextPrice(ladder: Ladder, level: number): number?
  	local nextLevel = ladder.levels[level + 1]
  	return if nextLevel then nextLevel.price else nil
  end
  ```
- `src/server/PlayerState.luau:32-40`, the first hardcoded copy. This file has no requires today:
  ```lua
  function PlayerState.add(player: Player)
  	local state: State = {
  		power = 0,
  		cash = 0,
  		plot = {},
  		pending = nil,
  		levels = { trowel = 0, plotSlots = 0 },
  		lastThrow = -math.huge,
  	}
  ```
- `tests/Pacing.spec.luau:31`, the second copy, inside `simulate`:
  ```lua
  	local levels: { [string]: number } = { trowel = 0, plotSlots = 0 }
  ```
- `tests/Upgrade.spec.luau`, existing tests for `Upgrade`. Model new tests on it. Specs return `{ [caseName]: () -> () }` and use `tests/assert.luau` (`Assert.eq(actual, expected, msg?)`, `Assert.truthy(value, msg?)`).
- `src/server/TrainService.luau:22` reads `state.levels.trowel` and `src/server/PlotService.luau:41` reads `state.levels.plotSlots` directly. Those are the ladders' effects, so leave them alone.

How shared modules are required:
- From server code: `require(ReplicatedStorage.Shared.Config)` after `local ReplicatedStorage = game:GetService("ReplicatedStorage")` (see `src/server/PlotService.luau:5-10`).
- From tests: `require("../src/shared/Upgrade")` (see `tests/Pacing.spec.luau:6-12`).

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Tests | `lune run tests/run` | `N passed, 0 failed` (45 before this plan) |
| Lint | `selene src tests` | 0 errors, 0 warnings |
| Format | `stylua --check src tests` | exit 0 |
| Types (src) | `luau-lsp analyze --sourcemap=sourcemap.json --definitions=globalTypes.d.luau src` | no `TypeError` |
| Types (tests) | `luau-lsp analyze --platform=standard --ignore="tests/run.luau" src/shared tests` | no `TypeError` |

If `sourcemap.json` is missing: `rojo sourcemap default.project.json -o sourcemap.json`.

## Scope

**In scope**:
- `src/shared/Upgrade.luau` (add one function)
- `tests/Upgrade.spec.luau` (add tests)
- `src/server/PlayerState.luau` (use the new function)
- `tests/Pacing.spec.luau` (use the new function)

**Out of scope**:
- `src/shared/Config.luau`: no ladder changes.
- `TrainService.luau` / `PlotService.luau` reading specific ladder ids: those are the ladders' effects.
- `.claude/`: it has the owner's uncommitted changes.

## Git workflow

- Current branch. One commit, plain imperative message, e.g. "Build starting upgrade levels from Config.UpgradeOrder". Don't push.

## Steps

### Step 1: Write the failing tests first

Add two cases to the table returned by `tests/Upgrade.spec.luau`:

1. `"startLevels gives every listed ladder level 0"`: `Upgrade.startLevels({ "a", "b" })` deep-equals `{ a = 0, b = 0 }`. Compare keys explicitly, e.g. `Assert.eq(levels.a, 0)`, `Assert.eq(levels.b, 0)`, and count the keys to equal 2.
2. `"startLevels covers Config.UpgradeOrder"`: require `../src/shared/Config`. For every id in `Config.UpgradeOrder`, `Upgrade.startLevels(Config.UpgradeOrder)[id]` equals `0`.

**Verify**: `lune run tests/run` → the two new cases FAIL (`startLevels` doesn't exist yet). Everything else passes.

### Step 2: Add `Upgrade.startLevels`

In `src/shared/Upgrade.luau`, before `return Upgrade`:

```lua
-- Level 0 for every ladder id in `order` (Config.UpgradeOrder): a new player's levels.
function Upgrade.startLevels(order: { string }): { [string]: number }
	local levels: { [string]: number } = {}
	for _, id in order do
		levels[id] = 0
	end
	return levels
end
```

**Verify**: `lune run tests/run` → `47 passed, 0 failed`.

### Step 3: Use it in PlayerState and Pacing.spec

- `src/server/PlayerState.luau`: add the requires at the top, after the header comment and before `export type Pending`:
  ```lua
  local ReplicatedStorage = game:GetService("ReplicatedStorage")

  local Config = require(ReplicatedStorage.Shared.Config)
  local Upgrade = require(ReplicatedStorage.Shared.Upgrade)
  ```
  and replace `levels = { trowel = 0, plotSlots = 0 },` with `levels = Upgrade.startLevels(Config.UpgradeOrder),`.
- `tests/Pacing.spec.luau:31`: replace the literal with `local levels: { [string]: number } = Upgrade.startLevels(Config.UpgradeOrder)`. `Upgrade` and `Config` are already required there.

**Verify**: `grep -rn "trowel = 0" src tests` → no matches.
**Verify**: all five commands in the table pass, and tests show `47 passed, 0 failed`.

## Test plan

- Two new cases in `tests/Upgrade.spec.luau` (step 1).
- `tests/Pacing.spec.luau` still passes unchanged, which shows the simulated economy is the same.
- PlayerState can't be tested under Lune (it uses Roblox APIs). The type check covers it. If you can reach Roblox Studio, play once and confirm both upgrade buttons still show and buying one works. Otherwise say it wasn't checked in Studio.

## Done criteria

- [ ] `lune run tests/run` → `47 passed, 0 failed`
- [ ] `grep -rn "trowel = 0" src tests` → no matches
- [ ] Both luau-lsp commands print no `TypeError`; selene clean; stylua check exits 0
- [ ] Only the four in-scope files (plus `plans/README.md`) changed
- [ ] `plans/README.md` status row updated

## STOP conditions

- `PlayerState.luau` already requires something, or its `State.levels` type isn't `{ [string]: number }` (drift).
- The Pacing tests fail after step 3. That means the starting levels differ from before. Report it; don't retune Config.

## Maintenance notes

- Adding a ladder is now: add it to `Config.Upgrades` and `Config.UpgradeOrder`, then read its value where its effect applies.
- Saving (plan 004) will load saved levels over `Upgrade.startLevels(...)`, so a ladder added later still starts at 0 for old saves.
