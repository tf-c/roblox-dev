# Plan 003: Let creatures be multi-part models and move theme text into Config, so the catboy reskin is a data change

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report, do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 9ef9f70..HEAD -- src/server/CritterVisual.luau src/server/PlayerState.luau src/server/PlotService.luau src/server/ThrowService.luau src/client/MeterController.luau src/client/RevealController.luau src/shared/Config.luau tests/Config.spec.luau`
> Plan 002 is expected to have changed `src/server/PlayerState.luau` (requires plus the `levels =` line). Anything else changed in these files is drift. Compare against the excerpts below; on a mismatch, STOP.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED (touches the throw → sprout → collect path; needs a Studio play test)
- **Depends on**: plans/001-typecheck-baseline.md, plans/002-upgrade-levels-from-config.md
- **Category**: tech-debt (direction: catboy reskin)
- **Planned at**: commit `9ef9f70`, 2026-11-08

## Why this matters

The game is changing theme from "toss seeds, critters sprout" to "throw a toy down the lane, a catboy character runs to where it lands". The loop, economy, and zones stay the same. Today every creature is one ball `Part`. The code types it as `BasePart` and moves it by tweening `Position`. A catboy will be a multi-part rig (a `Model`), which has no `Position`, so the reskin would currently mean rewriting the throw, sprout, and plot code. Theme words ("critter", "seed") are also spread across six files. After this plan:

1. Creatures are always `Model`s. Dropping a rig named after a creature id into `ServerStorage.CreatureModels` makes it appear in game with no code change.
2. Theme text and the thrown object's look live in `Config`.

Gameplay, numbers, and the current visuals stay the same. This plan is plumbing only. The actual catboy names, rigs, and toy art come later, from research.

## Current state

Strict-mode Luau Roblox game synced with Rojo (`default.project.json`: `src/shared` → `ReplicatedStorage.Shared`, `src/server` → `ServerScriptService.Server`, `src/client` → `StarterPlayer.StarterPlayerScripts.Client`). `src/shared/Config.luau` is pure data: **no requires, no Roblox APIs, colors as hex strings**, because Lune tests load it (header comment lines 2-3). Keep it that way.

Policy rule to keep true (`src/shared/Config.luau:11`): "Players toss seeds at the ground; critters sprout from them. Nothing is thrown at creatures." The catboy version keeps the same idea: a toy is thrown at the ground and the catboy comes to it. Don't change that comment in this plan.

### Files and the exact code to change

`src/server/CritterVisual.luau` (47 lines): builds the placeholder. Key lines:
```lua
local SIZE_BY_RARITY: { [string]: number } = { common = 3, rare = 4, epic = 5.5 }

function CritterVisual.make(creatureId: string): BasePart
	local def = Config.Creatures[creatureId]
	assert(def, "unknown critter " .. creatureId)
	local size = SIZE_BY_RARITY[def.rarity] or 3

	local part = Instance.new("Part")
	part.Name = def.name
	part.Shape = Enum.PartType.Ball
	...
	part.Anchored = true
	part.CanCollide = false
	part:SetAttribute("CreatureId", creatureId)

	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(160, 44)
	tag.StudsOffset = Vector3.new(0, size * 0.5 + 1.5, 0)
	tag.AlwaysOnTop = true
	tag.MaxDistance = 250
	tag.Parent = part
	... (TextLabel with rarity color, text "%s\n%s · %d/s")
	return part
end
```

`src/server/PlayerState.luau:6-10`:
```lua
export type Pending = {
	token: number,
	creatureId: string,
	model: BasePart?,
}
```

`src/server/PlotService.luau`:
- line 16-21: `type PlotVisual = { index: number, model: Model, pedestals: { BasePart }, critters: { [number]: BasePart } }`
- lines 56-66 `showCritter`:
  ```lua
  	local part = CritterVisual.make(creatureId)
  	local ped = plot.pedestals[slot]
  	part.Position = ped.Position + Vector3.new(0, ped.Size.Y / 2 + part.Size.Y / 2, 0)
  	part.Parent = plot.model
  	plot.critters[slot] = part
  ```
- line 94: `notify(player, string.format("Plot full: %s was released", name))`
- line 104: `notify(player, string.format("Plot full: %s replaced %s", name, Config.Creatures[replaced].name))`

`src/server/ThrowService.luau`:
- lines 71-81 in `sprout`:
  ```lua
  	local part = CritterVisual.make(creatureId)
  	local restY = landPos.Y + part.Size.Y / 2
  	part.Position = Vector3.new(landPos.X, restY - part.Size.Y, landPos.Z) -- start underground
  	part:SetAttribute("OwnerUserId", player.UserId)
  	part.Parent = fieldFolder
  	pending.model = part
  	TweenService:Create(
  		part,
  		TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
  		{ Position = Vector3.new(landPos.X, restY, landPos.Z) }
  	):Play()
  ```
- lines 84-90: ProximityPrompt with `prompt.ActionText = "Collect"`, `prompt.Parent = part`
- lines 97-109: auto collect:
  ```lua
  		task.delay(Config.AutoCollectDelaySeconds, function()
  			local target = PlotService.plotCenter(player)
  			if target and current(player, token) then
  				local tween = TweenService:Create(
  					part,
  					TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
  					{ Position = target + Vector3.new(0, 4, 0) }
  				)
  				tween:Play()
  				tween.Completed:Wait()
  			end
  			collect(player, token)
  		end)
  ```
- line 115: `Remotes.toast(player, Config.Creatures[creatureId].name .. " wandered off")`
- line 126: `Remotes.toast(player, "Collect your critter first")`

`src/client/MeterController.luau:68-70`:
```lua
			hud.meterHint.Text = if Config.CollectMode == "walk"
				then "Walk to your critter to collect it"
				else ""
```

`src/client/RevealController.luau:39-49` `flySeed` creates the thrown object:
```lua
local function flySeed(origin: Vector3, landPos: Vector3)
	local seed = Instance.new("Part")
	seed.Name = "Seed"
	seed.Shape = Enum.PartType.Ball
	seed.Size = Vector3.new(1.2, 1.2, 1.2)
	seed.Color = Color3.fromRGB(150, 100, 50)
	seed.Material = Enum.Material.Neon
```
and is called at line 133: `flySeed(result.origin, result.landPos)`.

`tests/Config.spec.luau`: sanity checks on Config tables, in the same spec style as the other specs (returns `{ [caseName]: () -> () }`, uses `Assert.truthy(value, msg)` / `Assert.eq(a, b, msg)` from `tests/assert.luau`).

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Tests | `lune run tests/run` | `N passed, 0 failed` (47 after plan 002) |
| Lint | `selene src tests` | 0 errors, 0 warnings |
| Format | `stylua --check src tests` (run `stylua src tests` to fix) | exit 0 |
| Sourcemap | `rojo sourcemap default.project.json -o sourcemap.json` | written |
| Types (src) | `luau-lsp analyze --sourcemap=sourcemap.json --definitions=globalTypes.d.luau src` | no `TypeError` |
| Types (tests) | `luau-lsp analyze --platform=standard --ignore="tests/run.luau" src/shared tests` | no `TypeError` |
| Build a place | `rojo build default.project.json -o build.rbxlx` | file written (gitignored) |

## Suggested executor toolkit

- If Roblox Studio MCP tools are available (`mcp__Roblox_Studio__*`), use them for the Studio play test in step 6 (start/stop play, console output, screen capture). Otherwise open `build.rbxlx` in Studio by hand.

## Scope

**In scope**:
- `src/shared/Config.luau` (add `Config.Text` and `Config.Projectile`; nothing else)
- `tests/Config.spec.luau` (add tests)
- `src/server/CritterVisual.luau`
- `src/server/PlayerState.luau` (the `Pending.model` type only)
- `src/server/PlotService.luau`
- `src/server/ThrowService.luau`
- `src/client/MeterController.luau` (the hint string only)
- `src/client/RevealController.luau` (`flySeed` only)

**Out of scope**:
- Creature roster, names, rarities, income, zone names, upgrade names. The catboy content comes later from research. Don't invent catboy names or text.
- Creating or importing any 3D model or asset.
- `Hud.luau` (`SeedTossHud` is an internal name), `default.project.json` (project name). Rename them when the final game name is chosen.
- Policy comment at `Config.luau:5-11`.
- `.claude/`: it has the owner's uncommitted changes.

## Git workflow

- Current branch. Commit after step 3 ("Move theme text and thrown-object look into Config") and after step 5 ("Let creatures be models so rigs can replace the placeholder ball"). Plain imperative messages like the existing `git log`. Don't push.

## Steps

### Step 1: Write failing Config tests

Add to `tests/Config.spec.luau`:

1. `"every theme text is a non-empty string"`: for each key in `{ "collectAction", "pendingBlocked", "wanderedOff", "walkHint", "plotReleased", "plotReplaced" }`, `Config.Text[key]` is a string with length > 0 (message: the key).
2. `"theme text has the right number of %s slots"`: count `%s` with `select(2, string.gsub(text, "%%s", ""))`. Expected counts: `wanderedOff` 1, `plotReleased` 1, `plotReplaced` 2, `collectAction` 0, `pendingBlocked` 0, `walkHint` 0.
3. `"projectile look is valid"`: `Config.Projectile.name` is a non-empty string, `Config.Projectile.size > 0`, and `Config.Projectile.color` matches `^#%x%x%x%x%x%x$`.

**Verify**: `lune run tests/run` → those 3 cases FAIL, all others pass.

### Step 2: Add `Config.Text` and `Config.Projectile`

In `src/shared/Config.luau`, after `Config.RarityColors` (line 85), add the current wording unchanged, so this step changes no behavior:

```lua
-- Player-facing theme words. The reskin changes these, not code. %s = creature name.
Config.Text = {
	collectAction = "Collect",
	pendingBlocked = "Collect your critter first",
	wanderedOff = "%s wandered off",
	walkHint = "Walk to your critter to collect it",
	plotReleased = "Plot full: %s was released",
	plotReplaced = "Plot full: %s replaced %s",
}

-- The thing the player throws down the lane (client visual only).
Config.Projectile = { name = "Seed", color = "#966432", size = 1.2 }
```

(`#966432` is `Color3.fromRGB(150, 100, 50)`.)

**Verify**: `lune run tests/run` → all pass (50).

### Step 3: Use the Config text and projectile everywhere

- `ThrowService.luau`: `prompt.ActionText = Config.Text.collectAction`; line 115 → `Remotes.toast(player, string.format(Config.Text.wanderedOff, Config.Creatures[creatureId].name))`; line 126 → `Remotes.toast(player, Config.Text.pendingBlocked)`.
- `PlotService.luau`: line 94 → `string.format(Config.Text.plotReleased, name)`; line 104 → `string.format(Config.Text.plotReplaced, name, Config.Creatures[replaced].name)`.
- `MeterController.luau:69` → `then Config.Text.walkHint`.
- `RevealController.luau`: rename `flySeed` to `flyProjectile` (and its call at line 133). Rename the local `seed` to `projectile`. Set `Name = Config.Projectile.name`, `Size = Vector3.new(s, s, s)` with `local s = Config.Projectile.size`, `Color = Color3.fromHex(Config.Projectile.color)`. Leave the trail and the attachment offsets as they are.

**Verify**: `grep -rn "critter first\|wandered off\|Walk to your critter\|Plot full\|\"Seed\"\|ActionText = \"" src` → only matches inside `src/shared/Config.luau`.
**Verify**: all checks in the commands table pass. Commit.

### Step 4: Make CritterVisual return a Model, with helpers for moving it

Rewrite `src/server/CritterVisual.luau` so that:

1. `CritterVisual.make(creatureId: string): Model`:
   - If `ServerStorage:FindFirstChild("CreatureModels")` has a child `Model` named exactly `creatureId` with a `PrimaryPart`, clone it. If the template exists but isn't a Model or has no `PrimaryPart`, `warn` once with the id and fall back to the placeholder.
   - Otherwise build the placeholder: a `Model` named `def.name` holding today's ball `Part` (same shape, size from `SIZE_BY_RARITY`, color, material) named `"Body"` and set as `model.PrimaryPart`.
   - For every `BasePart` descendant (template or placeholder): `Anchored = true`, `CanCollide = false`. For every `Humanoid` descendant: `DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None`, so Roblox's own name tag doesn't double the BillboardGui.
   - `model:SetAttribute("CreatureId", creatureId)`.
   - Attach the existing BillboardGui and label (same properties and text as today) to `model.PrimaryPart`. Set `StudsOffset` so the tag sits 1.5 studs above the top of the model: `local box, size = model:GetBoundingBox()` and `local top = box.Position.Y + size.Y / 2`, then `StudsOffset = Vector3.new(0, top - model.PrimaryPart.Position.Y + 1.5, 0)`. For the placeholder ball this gives the same `size * 0.5 + 1.5` as today.
2. `CritterVisual.restingPivot(model: Model, ground: Vector3): CFrame` returns the pivot CFrame that puts the model's lowest point on `ground`:
   ```lua
   local box, size = model:GetBoundingBox()
   local bottomToPivot = model:GetPivot().Position.Y - (box.Position.Y - size.Y / 2)
   return CFrame.new(ground + Vector3.new(0, bottomToPivot, 0))
   ```
3. `CritterVisual.tweenTo(model: Model, target: CFrame, info: TweenInfo): Tween` tweens a model's pivot (models can't be tweened directly). It tweens a `CFrameValue` and calls `PivotTo` on change:
   ```lua
   local value = Instance.new("CFrameValue")
   value.Value = model:GetPivot()
   value.Changed:Connect(function(cf: CFrame)
   	model:PivotTo(cf)
   end)
   local tween = TweenService:Create(value, info, { Value = target })
   tween.Completed:Connect(function()
   	value:Destroy()
   end)
   tween:Play()
   return tween
   ```
   Add `local ServerStorage = game:GetService("ServerStorage")` and `local TweenService = game:GetService("TweenService")` at the top, matching the existing `GetService` line style.

**Verify**: `luau-lsp analyze --sourcemap=sourcemap.json --definitions=globalTypes.d.luau src` → the only `TypeError`s are in `PlayerState.luau`, `PlotService.luau`, `ThrowService.luau` (callers still expect `BasePart`). Step 5 fixes those. If errors show in `CritterVisual.luau` itself, fix them before moving on.

### Step 5: Switch the callers to the Model API

- `PlayerState.luau`: `model: BasePart?` → `model: Model?`.
- `PlotService.luau`: `critters: { [number]: BasePart }` → `{ [number]: Model }`. In `showCritter`:
  ```lua
  	local model = CritterVisual.make(creatureId)
  	local ped = plot.pedestals[slot]
  	model:PivotTo(CritterVisual.restingPivot(model, ped.Position + Vector3.new(0, ped.Size.Y / 2, 0)))
  	model.Parent = plot.model
  	plot.critters[slot] = model
  ```
- `ThrowService.luau` `sprout`:
  ```lua
  	local model = CritterVisual.make(creatureId)
  	local rest = CritterVisual.restingPivot(model, landPos)
  	local _, size = model:GetBoundingBox()
  	model:PivotTo(rest - Vector3.new(0, size.Y, 0)) -- start underground
  	model:SetAttribute("OwnerUserId", player.UserId)
  	model.Parent = fieldFolder
  	pending.model = model
  	CritterVisual.tweenTo(model, rest, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
  ```
  ProximityPrompt: `prompt.Parent = model.PrimaryPart`. Auto collect: replace the `TweenService:Create(part, ...)` block with
  ```lua
  				local tween = CritterVisual.tweenTo(
  					model,
  					CFrame.new(target + Vector3.new(0, 4, 0)),
  					TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
  				)
  				tween.Completed:Wait()
  ```
  If `TweenService` is no longer used in `ThrowService.luau`, remove its `GetService` line (selene flags unused variables).

**Verify**: all checks in the commands table pass (tests: 50 passed). `grep -n "BasePart" src/server/ThrowService.luau src/server/PlayerState.luau` → no matches.

### Step 6: Studio play test (the change is in Roblox-only code)

Build with `rojo build default.project.json -o build.rbxlx` (or sync with `rojo serve` if a Studio session is already connected). Play solo and check each item, recording pass/fail:

1. Press E (throw) 10 times over about a minute. Each time the projectile flies, the colored ball pops up from under the ground, the name/rarity tag shows above it, then the ball flies to the plot and sits on a pedestal (not floating, not sunk).
2. Toasts still read "Plot full: X replaced Y" / "Plot full: X was released" once the plot fills (3 slots at start).
3. The Output window shows no script errors (ignore the Baseplate template asset warning).
4. Template seam: in Studio, create `ServerStorage > CreatureModels > sproutling` as a Model with two Parts (for example a 2×4×1 body and a 2×2×2 head on top), set its PrimaryPart, play, and throw until a Sproutling lands in the Lawn. It appears as that model, standing on the ground, tag above it, then moves to a pedestal. Delete the test model afterwards. It's a Studio-only object and must not be saved anywhere in the repo.

If Studio isn't reachable, say so in your report and mark this plan "IN PROGRESS, needs Studio check" rather than DONE.

## Test plan

- 3 new cases in `tests/Config.spec.luau` (step 1) cover the Config contract the reskin will edit.
- Model positioning and tweening are Roblox APIs, so Lune can't run them. They're covered by the type check and the step 6 play test. Don't build Roblox API mocks to unit-test them.

## Done criteria

- [ ] `lune run tests/run` → `50 passed, 0 failed`
- [ ] Both luau-lsp commands print no `TypeError`; `selene src tests` clean; `stylua --check src tests` exits 0
- [ ] `grep -rn "BasePart?" src/server/PlayerState.luau` → no matches
- [ ] The step 3 grep only matches `src/shared/Config.luau`
- [ ] Step 6 items 1-4 all pass in Studio (or the plan is marked as needing a Studio check)
- [ ] Only in-scope files changed (`git status --short`, ignoring `.claude/` and `plans/`)
- [ ] `plans/README.md` status row updated

## STOP conditions

- `Config.luau` already has `Text` or `Projectile` keys (drift, or another plan got there first).
- `GetBoundingBox` gives zero size for an unparented model in Studio (the creature appears at the wrong height in step 6 item 1). Report it. The likely fix is parenting before measuring, but confirm with the reviewer first.
- Anything in step 6 fails twice after a reasonable fix attempt.
- The change seems to need a Config field on `Creature` (like a model id). Don't add one; template lookup by creature id in `ServerStorage.CreatureModels` is the chosen seam.

## Maintenance notes

- Rigs must be Models with a `PrimaryPart`, named exactly the creature id (`sproutling`, not `Sproutling`). Rigs from the Roblox avatar pipeline usually have `HumanoidRootPart`. Set it as PrimaryPart.
- `restingPivot` uses identity rotation, so templates face their built-in front. If catboys should face the player or the lane, add a rotation there, not in callers.
- The catboy content pass (next) edits `Config.Creatures`, `Config.ZoneTables`, `Config.ZoneLooks`, `Config.Text`, `Config.Projectile`, and the upgrade `name`/`text` fields. Changing creature ids also means updating `Config.ZoneTables`, and later the save migration (plan 004).
- Reviewer: check that `tweenTo` is the only way models get moved, and that no caller reaches into `PrimaryPart.Position`.
