# Plan 005: Catboys run in to a yarn ball, with a 6-catboy starter slice

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report, do not improvise. Do NOT edit `plans/README.md`; the reviewer
> maintains the index.
>
> **Drift check (run first)**: `git diff --stat c0bf8b4..HEAD -- src tests`
> Expected: no output. If any file under `src/` or `tests/` changed, compare the
> "Current state" excerpts against the live code; on a mismatch, STOP.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED (changes the throw → arrival → collect path; needs a Studio play test)
- **Depends on**: plans 001-003 (all DONE)
- **Category**: direction (catboy reskin)
- **Planned at**: commit `c0bf8b4`, 2026-11-08

## Context / why this matters

The game is being reskinned from "toss a seed, a critter sprouts" to "throw a yarn ball down the lane, a catboy runs in to it". The question this build answers: **does a catboy running in to the toy feel better than a critter sprouting?** Plans 001-003 built the seam: creatures are Models (`CritterVisual.make`), theme words live in `Config.Text`, and the thrown object lives in `Config.Projectile`. This plan:

1. swaps the 6 placeholder critters for 6 original catboys (data only: ids, names, colors);
2. renames the zones Backyard / Park / Meadow (display names only);
3. replaces the underground "sprout" with an **Arrival**: the catboy runs in from the nearer side edge of the lane, hops at the toy and turns to face the player; its name tag pops after it arrives;
4. makes the toy a yarn ball that rests on a glowing ring after landing;
5. builds a blocky placeholder catboy rig in code (no assets).

The loop, the economy numbers, the weights, rarities and zone thresholds do not change. `tests/Pacing.spec.luau` must keep passing unchanged.

Decided vocabulary (from `GLOSSARY.md`, use these words in comments and player text):
- **Toy**: the object thrown down the Lane; today a yarn ball. Never say "seed".
- **Arrival**: a Creature coming from the edge of a Zone to where the Toy landed. Avoid "sprout".
- **Creature**: the loop concept (code keeps this word). **Catboy**: the current theme's Creature (player-facing text). Never say "critter" in player-facing text.

Rules that must stay true (kid-appropriate, from the research handoff):
- Toys are thrown at the ground; catboys come to them. Nothing is thrown at a catboy.
- Placeholder rigs are fully clothed (torso, arms, legs colored as clothes). No collars, leashes, chains or chokers.

## Current state

Strict-mode Luau Roblox game synced with Rojo (`default.project.json`: `src/shared` → `ReplicatedStorage.Shared`, `src/server` → `ServerScriptService.Server`, `src/client` → `StarterPlayer.StarterPlayerScripts.Client`). Every module starts with `--!strict` and a header comment saying what it does. `src/shared/` is pure Luau (no requires, no Roblox APIs) so Lune can test it; `Config.luau` is pure data with colors as hex strings.

### `src/shared/Config.luau` (relevant excerpts)

Line 11 (policy comment):
```lua
--   * Players toss seeds at the ground; critters sprout from them. Nothing is thrown at creatures.
```
Lines 45-49:
```lua
Config.ZoneLooks = {
	lawn = { name = "Lawn", color = "#8fd16a" },
	grove = { name = "Grove", color = "#3f9b4b" },
	wildwood = { name = "Wildwood", color = "#24543a" },
}
```
Lines 58-66 and 75-79:
```lua
-- Placeholder critters: 2 per zone. Income is cash per second while on the plot.
Config.Creatures = {
	sproutling = { name = "Sproutling", rarity = "common", income = 1, color = "#b6e388" },
	budbun = { name = "Budbun", rarity = "rare", income = 4, color = "#f2a7c3" },
	mossmole = { name = "Mossmole", rarity = "common", income = 3, color = "#6b8e4e" },
	fernfox = { name = "Fernfox", rarity = "rare", income = 10, color = "#e07a3c" },
	thornowl = { name = "Thornowl", rarity = "rare", income = 25, color = "#7a5a8c" },
	bloomdrake = { name = "Bloomdrake", rarity = "epic", income = 80, color = "#d94fd9" },
} :: { [string]: Creature }
...
Config.ZoneTables = {
	lawn = { { id = "sproutling", weight = 80 }, { id = "budbun", weight = 20 } },
	grove = { { id = "mossmole", weight = 75 }, { id = "fernfox", weight = 25 } },
	wildwood = { { id = "thornowl", weight = 85 }, { id = "bloomdrake", weight = 15 } },
}
```
Lines 87-98:
```lua
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
Lines 105-113:
```lua
Config.Throw = {
	cooldownSeconds = 1.5,
	arcSeconds = 1.2, -- seed flight time before the sprout pops
	arcHeight = 25,
}
-- "walk": walk to the critter and use its prompt. "auto": it hops to your plot after the reveal.
Config.CollectMode = "auto" :: "walk" | "auto"
Config.AutoCollectDelaySeconds = 1.5
```
Lines 153-158: `Config.Map = { padPosition = {x=0,y=0,z=0}, laneWidth = 60, laneLength = 220, plotPosition = {...} }`. The lane runs along +Z from the pad and spans x = -30..30.

### `src/server/ThrowService.luau` `sprout` (lines 64-77), to be replaced by an arrival
```lua
local function sprout(player: Player, token: number, creatureId: string, landPos: Vector3)
	local pending = current(player, token)
	if not pending then
		return
	end

	local model = CritterVisual.make(creatureId)
	local rest = CritterVisual.restingPivot(model, landPos)
	local _, size = model:GetBoundingBox()
	model:PivotTo(rest - Vector3.new(0, size.Y, 0)) -- start underground
	model:SetAttribute("OwnerUserId", player.UserId)
	model.Parent = fieldFolder
	pending.model = model
	CritterVisual.tweenTo(model, rest, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
```
Lines 93-104 start auto-collect with `task.delay(Config.AutoCollectDelaySeconds, ...)` measured from the start of `sprout`. Line 151 schedules it: `task.delay(Config.Throw.arcSeconds, sprout, player, token, creatureId, landPos)`. `landPos` comes from `MapBuilder.landPoint` and its x is within about ±9 studs of the lane center.

### `src/server/CritterVisual.luau` (plan 003 output)
- `placeholder(creatureId): Model` builds one ball `Part` named `"Body"` (size from `SIZE_BY_RARITY = { common = 3, rare = 4, epic = 5.5 }`), sets it as `PrimaryPart`.
- `make(creatureId): Model` uses a `ServerStorage.CreatureModels.<id>` template if present, else `placeholder`; anchors all parts, sets `CanCollide = false`, sets attribute `CreatureId`, then attaches a `BillboardGui` (the name tag) to `model.PrimaryPart`, with `StudsOffset` computed from `model:GetBoundingBox()` to sit 1.5 studs above the model's top.
- `restingPivot(model, ground): CFrame` returns a pivot with **identity rotation** that puts the model's lowest point on `ground`.
- `tweenTo(model, target: CFrame, info): Tween` tweens a `CFrameValue` and calls `PivotTo`; it plays the tween and returns it. **All model movement must go through `tweenTo`** (plan 003 rule).

Identity rotation faces -Z (Roblox's default LookVector), i.e. back toward the launch pad and the player. The placeholder rig in this plan is built facing -Z so a resting catboy faces the player.

### `src/client/RevealController.luau` `flyProjectile` (lines 39-78)
Builds a `Neon` ball `Part` from `Config.Projectile`, with a `Trail` (color `Color3.fromRGB(255, 240, 180)`), moves it along an arc on `RenderStepped` for `Config.Throw.arcSeconds`, and at `t >= 1` disconnects and **destroys** it. At `arcSeconds` the reveal shows a rarity `burst(...)` at `landPos` and the creature name in the HUD.

### Tests
- `tests/Config.spec.luau`: sanity checks, returns `{ [caseName]: () -> () }`, uses `Assert.eq(actual, expected, msg?)` / `Assert.truthy(value, msg?)` from `tests/assert.luau`. Existing cases already check every creature has a valid rarity, income and hex color, every zone table entry is a known creature, every theme text is non-empty with the right `%s` count, and the projectile has a name, size > 0 and hex color.
- `tests/Upgrade.spec.luau` is the exemplar for a small pure-module spec (`local Upgrade = require("../src/shared/Upgrade")`).
- `tests/Pacing.spec.luau` simulates a session using zone ids `lawn/grove/wildwood` and `THROW_SECONDS = 4` per throw. It must pass unchanged.
- `tests/Income.spec.luau` and `tests/Plot.spec.luau` use their own literal creature ids (e.g. `sproutling`); they don't read `Config.Creatures`. Leave them alone.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Tests | `lune run tests/run` | last line `N passed, 0 failed` (50 at c0bf8b4) |
| Lint | `selene src tests` | 0 errors, 0 warnings |
| Format | `stylua --check src tests` (fix with `stylua src tests`) | exit 0 |
| Sourcemap | `rojo sourcemap default.project.json -o sourcemap.json` | written |
| Types (src) | `luau-lsp analyze --sourcemap=sourcemap.json --definitions=globalTypes.d.luau src` | no `TypeError` |
| Types (tests) | `luau-lsp analyze --platform=standard --ignore="tests/run.luau" src/shared tests` | no `TypeError` |

Files must keep LF line endings (the repo uses LF; CRLF breaks `stylua --check`).

## Scope

**In scope**:
- `src/shared/Config.luau`
- `src/shared/Arrival.luau` (create)
- `tests/Config.spec.luau`
- `tests/Arrival.spec.luau` (create)
- `src/server/CritterVisual.luau`
- `src/server/ThrowService.luau`
- `src/client/RevealController.luau`

**Out of scope** (do NOT touch):
- Zone ids `lawn` / `grove` / `wildwood`, `Config.Zones`, weights, incomes, rarities, `Config.AutoCollectDelaySeconds`, `Config.Throw`, upgrade numbers. Economy stays fixed.
- Upgrade display names (`"Trowel"`), `Hud.luau` (`SeedTossHud`), `default.project.json`. Renamed later with the game name.
- File/module names `CritterVisual`, `FieldCritters`, and internal identifiers. Code keeps "Creature"; renaming files is a separate cleanup.
- `tests/Pacing.spec.luau`, `tests/Income.spec.luau`, `tests/Plot.spec.luau`.
- Any asset import, mesh, decal or `ServerStorage.CreatureModels` content.
- `plans/`, `GLOSSARY.md`, `CLAUDE.md`, `.claude/`.

## Git workflow

- Current branch `throw-to-collect-core`. Two commits, plain imperative messages like `git log`:
  1. after step 3: "Swap in six starter catboys, zone names and the yarn ball"
  2. after step 6: "Catboys run in to the toy instead of sprouting"
- End each message with the line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Stage only in-scope files. Do NOT push.

## Steps

### Step 1: Write the failing tests

**a. `tests/Config.spec.luau`**: add these cases:

1. `"starter catboys fill the six creature slots"`: assert exactly these zone tables (same weights as before):
   - `lawn`: `pillow` 80, `slipper` 20
   - `grove`: `pickle` 75, `caramel` 25
   - `wildwood`: `satin` 85, `linden` 15

   Compare `entry.id` and `entry.weight` for each index. Also assert rarity and income per id:

   | id | rarity | income |
   |---|---|---|
   | pillow | common | 1 |
   | slipper | rare | 4 |
   | pickle | common | 3 |
   | caramel | rare | 10 |
   | satin | rare | 25 |
   | linden | epic | 80 |

   Also assert that the count of keys in `Config.Creatures` is 6.
2. `"zone names are Backyard, Park, Meadow"`: `Config.ZoneLooks.lawn.name == "Backyard"`, `grove.name == "Park"`, `wildwood.name == "Meadow"`.
3. `"player-facing text never says critter or seed"`: for every value in `Config.Text`, plus `Config.Projectile.name`, plus every `Config.Creatures[id].name`, assert that `string.find(string.lower(text), "critter", 1, true) == nil` and the same for `"seed"` (message: the text).
4. `"the toy is a yarn ball that rests after landing"`: `Config.Projectile.name == "Yarn ball"` and `Config.Projectile.restSeconds > 0`.
5. `"arrival finishes before auto collect starts"`: `Config.Arrival.runSeconds > 0`, `Config.Arrival.hopSeconds > 0`, `Config.Arrival.hopHeight > 0`, `Config.Arrival.edgeMargin >= 0`, and `Config.Arrival.runSeconds + Config.Arrival.hopSeconds < Config.AutoCollectDelaySeconds`.

The existing test `"projectile look is valid"` stays as is.

**b. `tests/Arrival.spec.luau`** (create, modeled on `tests/Upgrade.spec.luau`): `local Arrival = require("../src/shared/Arrival")`. Cases, using `laneWidth = 60` and `margin = 2`:
1. `"a toy right of center comes from the right edge"`: `Arrival.startX(5, 60, 2) == 32`.
2. `"a toy left of center comes from the left edge"`: `Arrival.startX(-0.5, 60, 2) == -32`.
3. `"a toy dead center comes from the right edge"`: `Arrival.startX(0, 60, 2) == 32`.

**Verify**: `lune run tests/run` → the 5 new Config cases and all 3 Arrival cases FAIL. The Arrival cases fail on the require because the module is missing, and the runner may report the whole spec as one failure. All 50 existing cases pass.

### Step 2: Add `src/shared/Arrival.luau`

```lua
--!strict
-- Pure: where an Arrival starts. A Creature runs in from the lane's side edge nearest the Toy.
-- No requires, no Roblox APIs.

local Arrival = {}

-- X of the lane edge (plus `margin` studs outside it) on the Toy's side. Center counts as the right (+X) side.
function Arrival.startX(landX: number, laneWidth: number, margin: number): number
	local side = if landX < 0 then -1 else 1
	return side * (laneWidth / 2 + margin)
end

return Arrival
```

**Verify**: `lune run tests/run` → Arrival cases pass, and the 5 new Config cases still fail.

### Step 3: Change the Config data

In `src/shared/Config.luau`:

1. Policy comment line 11 → `--   * Players throw a toy at the ground; creatures come to it. Nothing is thrown at creatures.`
2. `Config.ZoneLooks` names: `lawn` → `"Backyard"`, `grove` → `"Park"`, `wildwood` → `"Meadow"`. Keep the colors.
3. Replace `Config.Creatures` and its comment:
   ```lua
   -- Starter catboys (original designs, roster ids from roblox-researcher): 2 per zone.
   -- `color` is the ears, tail and hair. Income is cash per second while on the plot.
   Config.Creatures = {
   	pillow = { name = "Pillow", rarity = "common", income = 1, color = "#f2a65a" },
   	slipper = { name = "Slipper", rarity = "rare", income = 4, color = "#f48fb1" },
   	pickle = { name = "Pickle", rarity = "common", income = 3, color = "#2f2f36" },
   	caramel = { name = "Caramel", rarity = "rare", income = 10, color = "#f7c59f" },
   	satin = { name = "Satin", rarity = "rare", income = 25, color = "#5a5d66" },
   	linden = { name = "Linden", rarity = "epic", income = 80, color = "#c8a2e8" },
   } :: { [string]: Creature }
   ```
4. `Config.ZoneTables`: same weights with the new ids: `lawn = pillow 80 / slipper 20`, `grove = pickle 75 / caramel 25`, `wildwood = satin 85 / linden 15`.
5. Change the `Config.CreatureIncome` comment from "critter id" to "creature id".
6. `Config.Text`:
   ```lua
   Config.Text = {
   	collectAction = "Collect",
   	pendingBlocked = "Your catboy is still on the way",
   	wanderedOff = "%s wandered off",
   	walkHint = "Walk to your catboy to collect it",
   	plotReleased = "Plot full: %s was released",
   	plotReplaced = "Plot full: %s replaced %s",
   }
   ```
7. `Config.Projectile`:
   ```lua
   -- The Toy the player throws down the lane (client visual only). It rests on a glowing ring for `restSeconds` after landing.
   Config.Projectile = { name = "Yarn ball", color = "#e2574c", size = 1.6, restSeconds = 2 }
   ```
8. Change the `arcSeconds` comment to `-- toy flight time before the arrival starts`. Change the `CollectMode` comment to `-- "walk": walk to the catboy and use its prompt. "auto": it hops to your plot after it arrives.` Change the `PendingTimeoutSeconds` comment to say "an uncollected creature wanders off after this".
9. After `Config.AutoCollectDelaySeconds`, add:
   ```lua
   -- Arrival: the creature runs in from the lane's side edge to the toy, then hops and turns to face the player.
   -- runSeconds + hopSeconds must stay under AutoCollectDelaySeconds (Config.spec checks), so throw pacing is unchanged.
   Config.Arrival = { runSeconds = 0.6, hopSeconds = 0.25, hopHeight = 1.5, edgeMargin = 2 }
   ```

**Verify**: `lune run tests/run` → `58 passed, 0 failed` (50 + 5 Config + 3 Arrival). Pacing cases pass unchanged.
**Verify**: `grep -rn "sproutling\|budbun\|mossmole\|fernfox\|thornowl\|bloomdrake" src` → no matches.
**Verify**: all checks in the commands table pass. Then make commit 1.

### Step 4: Build a blocky catboy placeholder rig in `CritterVisual.luau`

Replace `placeholder` and `SIZE_BY_RARITY`. Keep `fromTemplate`, `make`, `restingPivot` and `tweenTo` behavior as they are. Templates still win over the placeholder.

```lua
local SCALE_BY_RARITY: { [string]: number } = { common = 1, rare = 1.2, epic = 1.5 }
local SKIN = Color3.fromHex("#f3d2b3")
local PANTS = Color3.fromHex("#4b4f63")
local EYES = Color3.fromHex("#222222")
```

`placeholder(creatureId)` builds a `Model` named `def.name`, facing -Z, from plain anchored `Part`s, using `SmoothPlastic` material. Use a local helper `limb(name, size, offset: CFrame, color, parent)`. Each part's `CFrame` is the offset relative to the body center at the origin. Let `coat = Color3.fromHex(def.color)` and `outfit = coat:Lerp(Color3.new(1, 1, 1), 0.55)`, a pastel version of the coat, used as the sweater/hoodie color.

| Part name | Size (x,y,z) | CFrame offset | Color |
|---|---|---|---|
| `Body` (PrimaryPart) | 2, 2, 1 | `CFrame.new(0, 0, 0)` | outfit |
| `LeftLeg` / `RightLeg` | 0.9, 2, 0.9 | `CFrame.new(∓0.5, -2, 0)` | PANTS |
| `LeftArm` / `RightArm` | 0.8, 1.9, 0.8 | `CFrame.new(∓1.45, 0.05, 0)` | outfit |
| `Head` | 1.8, 1.8, 1.6 | `CFrame.new(0, 1.9, 0)` | SKIN |
| `Hair` | 1.9, 0.5, 1.7 | `CFrame.new(0, 2.75, 0.05)` | coat |
| `LeftEar` / `RightEar` | 0.45, 0.7, 0.35 | `CFrame.new(∓0.6, 3.25, 0) * CFrame.Angles(0, 0, math.rad(±20))` (each ear tilts outward) | coat |
| `LeftEye` / `RightEye` | 0.25, 0.35, 0.1 | `CFrame.new(∓0.4, 2.0, -0.81)` (front face is -Z) | EYES |
| `Tail` | 0.35, 0.35, 2.2 | `CFrame.new(0, -0.6, 1.4) * CFrame.Angles(math.rad(35), 0, 0)` | coat |

After building, set `model.PrimaryPart = body`, then call `model:ScaleTo(SCALE_BY_RARITY[def.rarity] or 1)`. `Model:ScaleTo` works on unparented models.

Update the header comment: "Creature look: a Model (a rig from ServerStorage.CreatureModels named after the creature id, else a blocky placeholder catboy) with a name tag."

Then add two tag helpers. Both find the tag with `(model.PrimaryPart :: BasePart):FindFirstChildOfClass("BillboardGui")` and return early if it is nil:

```lua
-- Hide the name tag until the creature has arrived.
function CritterVisual.hideTag(model: Model)
	-- tag.Enabled = false
end

-- Show the name tag with a quick pop (size 0 -> full).
function CritterVisual.popTag(model: Model)
	-- local full = tag.Size; tag.Size = UDim2.fromOffset(0, 0); tag.Enabled = true
	-- TweenService:Create(tag, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = full }):Play()
end
```

Implement them as described in the comments. (`UDim2` tweens are supported by TweenService.)

**Verify**: both luau-lsp commands → no `TypeError`. `selene src tests` → clean.

### Step 5: Replace the sprout with an Arrival in `ThrowService.luau`

1. Add `local Arrival = require(ReplicatedStorage.Shared.Arrival)` with the other shared requires (alphabetical: after `Config`).
2. Rename the local function `sprout` to `arrive` (and its `task.delay` call at the end of `onThrow`). Replace its first block (everything from `local model = CritterVisual.make(creatureId)` through the `CritterVisual.tweenTo(... 0.35 ...)` line) with:
   ```lua
   	local model = CritterVisual.make(creatureId)
   	CritterVisual.hideTag(model)
   	local rest = CritterVisual.restingPivot(model, landPos) -- identity rotation: faces the player
   	local startX = Arrival.startX(landPos.X, Config.Map.laneWidth, Config.Arrival.edgeMargin)
   	local startPos = Vector3.new(startX, rest.Position.Y, rest.Position.Z)
   	-- Face the toy while running.
   	local runFacing = CFrame.lookAt(startPos, rest.Position) - startPos
   	model:PivotTo(runFacing + startPos)
   	model:SetAttribute("OwnerUserId", player.UserId)
   	model.Parent = fieldFolder
   	pending.model = model

   	task.spawn(function()
   		local a = Config.Arrival
   		local half = a.hopSeconds / 2
   		CritterVisual.tweenTo(model, runFacing + rest.Position, TweenInfo.new(a.runSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)).Completed:Wait()
   		if not current(player, token) then return end
   		CritterVisual.tweenTo(model, rest + Vector3.new(0, a.hopHeight, 0), TweenInfo.new(half, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)).Completed:Wait()
   		if not current(player, token) then return end
   		CritterVisual.tweenTo(model, rest, TweenInfo.new(half, Enum.EasingStyle.Quad, Enum.EasingDirection.In)).Completed:Wait()
   		if current(player, token) then
   			CritterVisual.popTag(model)
   		end
   	end)
   ```
   Format the long lines with `stylua`. The hop's turn from run-facing to identity happens during the hop, because `tweenTo` interpolates the full CFrame.
3. Leave the walk-mode prompt, the auto-collect `task.delay(Config.AutoCollectDelaySeconds, ...)` and the timeout block exactly as they are. Auto collect still counts from the start of `arrive`. Config.spec guarantees the arrival (0.85 s) ends before it (1.5 s), so throw pacing is unchanged.
4. Update comments in this file: header line 4 → `-- then a creature runs in to where the toy lands.`; line 6 "A thrown critter" → "A thrown creature"; the `current`/`takePending` comments "pending critter" → "pending creature"; line 107 "ignored critter" → "ignored creature"; the `forget` comment likewise. Don't rename `fieldFolder.Name = "FieldCritters"`.

**Verify**: `grep -n "sprout\|critter\|seed" src/server/ThrowService.luau` → only the `"FieldCritters"` line.
**Verify**: both luau-lsp commands → no `TypeError`; `selene` clean; `stylua --check` exit 0; tests `58 passed, 0 failed`.

### Step 6: Yarn ball rests on a glowing ring (`RevealController.luau`)

In `flyProjectile`:
1. Change `projectile.Material = Enum.Material.Neon` to `Enum.Material.Fabric`.
2. Replace the landing branch (`if t >= 1 then conn:Disconnect() projectile:Destroy() end`) with: disconnect, set `projectile.Position = landPos + Vector3.new(0, s / 2, 0)`, then call a new local function `landRing(landPos, projectile)`.
3. Add `landRing(landPos: Vector3, projectile: BasePart)` above `flyProjectile`. It creates the ring as a `Part`:
   - `Name = "LandingRing"`, `Shape = Enum.PartType.Cylinder`, `Size = Vector3.new(0.2, 6, 6)`
   - `CFrame = CFrame.new(landPos + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))` (a flat disc)
   - `Color = Color3.fromRGB(255, 240, 180)`, `Material = Enum.Material.Neon`, `Transparency = 0.3`
   - `Anchored = true`, `CanCollide = false`, `CanQuery = false`, `Parent = Workspace`

   Then `task.delay(Config.Projectile.restSeconds, ...)` tweens both the ring and the projectile to `Transparency = 1` over 0.4 s (TweenService, Quad Out) and destroys both when the tween completes.
4. Header comment: `-- The reveal moment: the toy arcs down the lane and lands on a glowing ring, distance and zone pop up, then a` / `-- rarity-colored burst and the creature's name. Epic adds a bigger burst and a camera shake.`

**Verify**: `grep -n "seed\|critter" src/client/RevealController.luau` → no matches.
**Verify**: all commands in the table pass (tests `58 passed, 0 failed`). Make commit 2.

### Step 7: Studio play test (reviewer runs this, executor skips it)

Rojo is syncing into the open Studio place "Throw Game". Play solo:
1. Throw 20 times (E key, about 4.5 s apart). Each time: the yarn ball arcs and rests on a glowing ring, and a blocky catboy (ears, tail, clothes) runs in from the lane's nearer side edge, hops and ends facing the player, standing on the ground. Then its tag pops above it and it flies to the plot, where it sits on a pedestal. Check positions with `execute_luau`: the field model's bottom equals the ground (0.20) and its starting x is ±32.
2. Zone signs read "Backyard · 0 studs", "Park · 60 studs", "Meadow · 120 studs".
3. The Output shows no script errors (ignore the Baseplate asset warning `rbxassetid://203785492`).
4. Take screenshots of a catboy arriving and of the plot, for the phone readability note.

## Test plan

- 5 new `tests/Config.spec.luau` cases pin the starter roster mapping, zone names, retired words, the yarn ball and the arrival timing budget.
- 3 new `tests/Arrival.spec.luau` cases cover the only new pure logic: which edge a creature comes from.
- Rig building, tweening and the ring are Roblox APIs. The type check and the Step 7 play test cover them. Don't build Roblox mocks.
- `tests/Pacing.spec.luau` passing unchanged shows the economy didn't move.

## Done criteria

- [ ] `lune run tests/run` → `58 passed, 0 failed`
- [ ] Both luau-lsp commands print no `TypeError`; `selene src tests` clean; `stylua --check src tests` exits 0
- [ ] `grep -rn "sproutling\|budbun\|mossmole\|fernfox\|thornowl\|bloomdrake" src` → no matches
- [ ] `grep -rni "critter\|seed" src/shared/Config.luau` → no matches
- [ ] `git status --short` shows only in-scope files changed (ignore `.claude/`)
- [ ] Two commits made, not pushed
- [ ] Step 7 passes in Studio (reviewer)

## STOP conditions

- Drift: anything under `src/` or `tests/` changed since `c0bf8b4`, or an excerpt above doesn't match.
- `tests/Pacing.spec.luau` fails after step 3. The roster swap must not change the economy; report it, and don't retune.
- `Model:ScaleTo` errors on an unparented model, or the type checker rejects it. Report it; don't swap in hand-scaled sizes without the reviewer.
- The arrival seems to need a change to `Config.AutoCollectDelaySeconds`, `Config.Throw` or the auto-collect block. Stop; those are out of scope.
- Any step's verification fails twice after a reasonable fix attempt.

## Maintenance notes

- Real rigs: drop a Model named exactly the creature id (e.g. `pillow`) with a `PrimaryPart` into `ServerStorage.CreatureModels`. It replaces the placeholder with no code change. It must face -Z so it ends up facing the player.
- `SCALE_BY_RARITY` (1 / 1.2 / 1.5) is chosen for phone readability. The roster's own `size` field (1.0 / 1.1 / 1.2) is more subtle; revisit after the phone playtest.
- Deferred: accessories from the roster (fang, glasses, paw mittens, ear bow), sparkles and aura effects, a walk animation, the "Trowel" upgrade name, renaming `CritterVisual` / `FieldCritters`, and toy choice.
- Reviewer: check that all model movement still goes through `CritterVisual.tweenTo`, that every arrival stage re-checks `current(player, token)`, and that no player-facing string says "critter" or "seed".
