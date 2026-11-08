# Plan 006: Catboys wear R15 rigs built from catalog bundles, with the placeholder as fallback

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report, do not improvise. Do NOT edit `plans/README.md`; the reviewer
> maintains the index.
>
> **Drift check (run first)**: `git diff --stat e437e21..HEAD -- src tests`
> Expected: no output. If any file under `src/` or `tests/` changed, compare the
> "Current state" excerpts against the live code; on a mismatch, STOP.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED (web calls at server start; changes what every Creature model looks like; needs a Studio play test)
- **Depends on**: plans 003 and 005 (both DONE)
- **Category**: direction (real catboy rigs)
- **Planned at**: commit `e437e21`, 2026-11-08

## Why this matters

Creatures are blocky placeholder catboys built from Parts in code. The owner wants real R15 avatars dressed in Roblox catalog bundles. A bundle's outfit becomes a `HumanoidDescription`, and that becomes a rig. These calls are web requests that can fail or be slow. So this plan builds every rig **once at server start**, caches it, and has `CritterVisual.make` clone from the cache. `make` must never wait on the web, because it runs inside the throw → arrival path. If a bundle is missing, fails to load or has no outfit, the creature keeps today's placeholder. The game must never break because of the catalog.

## Current state

Strict-mode Luau Roblox game synced with Rojo (`default.project.json`: `src/shared` → `ReplicatedStorage.Shared`, `src/server` → `ServerScriptService.Server`, `src/client` → `StarterPlayer.StarterPlayerScripts.Client`). Every module starts with `--!strict` and a one-line-or-so header comment saying what it does. `src/shared/` is **pure Luau**: no Roblox APIs (Config has no requires at all), so Lune can test it. Tests are Lune specs under `tests/`, each returning `{ [caseName]: () -> () }`, registered in `tests/run.luau` (the runner fails if a spec file isn't registered).

Vocabulary (from `GLOSSARY.md`): **Creature** is the code concept; **Catboy** is the current theme's name for it in player-facing text. Never write "critter", "pet" or "unit" in new names or comments (the existing `CritterVisual` file name is a known leftover; do not rename it in this plan). Kid-appropriate rule from the research brief: catboys are fully clothed, with no collars, leashes, chains or chokers.

### `src/server/CritterVisual.luau` (the only builder of Creature models)

Lines 91-111, the lookup order today is "hand-made template in `ServerStorage.CreatureModels`, else placeholder":
```lua
local function fromTemplate(creatureId: string): Model?
	local folder = ServerStorage:FindFirstChild("CreatureModels")
	local template = folder and folder:FindFirstChild(creatureId)
	if not template then
		return nil
	end
	if template:IsA("Model") and template.PrimaryPart then
		return template:Clone()
	end
	...
end

function CritterVisual.make(creatureId: string): Model
	local def = Config.Creatures[creatureId]
	assert(def, "unknown critter " .. creatureId)

	local model = fromTemplate(creatureId) or placeholder(creatureId)
	local primary = model.PrimaryPart :: BasePart
	for _, inst in model:GetDescendants() do
		if inst:IsA("BasePart") then
			inst.Anchored = true
			inst.CanCollide = false
		elseif inst:IsA("Humanoid") then
			inst.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
	end
```
Line 13: `local SCALE_BY_RARITY: { [string]: number } = { common = 1, rare = 1.2, epic = 1.5 }`. The placeholder applies it with `model:ScaleTo(SCALE_BY_RARITY[def.rarity] or 1)` (line 87). The rest of `make` (name tag sized from `GetBoundingBox`), `restingPivot` and `tweenTo` work on any Model with a PrimaryPart. They already handle a Humanoid rig, so leave them alone. Models face -Z (toward the player); a fresh R15 rig also faces -Z.

Callers: `src/server/ThrowService.luau:71` and `src/server/PlotService.luau:61` call `CritterVisual.make(creatureId)` synchronously. Do not change them.

### `src/server/Main.server.luau` lines 13-16
```lua
MapBuilder.build()
TrainService.init()
PlotService.init()
ThrowService.init()
```

### `src/shared/Config.luau`
Creature ids (lines 60-67): `pillow, slipper, pickle, caramel, satin, linden`. Config is pure data with a comment above each table saying what it is (see `Config.Arrival`, lines 115-117, for the style).

### Exemplar test: `tests/Arrival.spec.luau`
```lua
--!strict
local Arrival = require("../src/shared/Arrival")
local Assert = require("./assert")

return {
	["a toy right of center comes from the right edge"] = function()
		Assert.eq(Arrival.startX(5, 60, 2), 32)
	end,
}
```
`tests/assert.luau` provides `Assert.eq(actual, expected, msg?)`, `Assert.truthy(value, msg?)`, `Assert.near`, `Assert.throws`.

### The Roblox calls (server only; all yield, all can throw)
1. `AssetService:GetBundleDetailsAsync(bundleId)` → table with `Items: { { Id: number, Name: string, Type: string } }`.
2. Pick the item with `Type == "UserOutfit"` whose `Name` does not contain `"Head"`; its `Id` is the outfit id.
3. `Players:GetHumanoidDescriptionFromOutfitId(outfitId)` → `HumanoidDescription`.
4. Optional extra accessories: `HumanoidDescription.HatAccessory` is a comma-separated string of asset ids (it may be `""`).
5. `Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)` → `Model` (PrimaryPart is normally `HumanoidRootPart`).

## Commands you will need

Run from the repo root (`C:\Users\pi\roblox-dev`).

| Purpose | Command | Expected on success |
|---|---|---|
| Tests | `lune run tests/run` | last line `N passed, 0 failed` (58 before this plan) |
| Lint | `selene src tests` | `0 errors, 0 warnings` (or no problems reported) |
| Format | `stylua --check src tests` | exit 0, no output |
| Types (game) | `rojo sourcemap default.project.json -o sourcemap.json` then `luau-lsp analyze --sourcemap=sourcemap.json --definitions=globalTypes.d.luau src` | exit 0, no errors |
| Types (tests) | `luau-lsp analyze --platform=standard --ignore="tests/run.luau" src/shared tests` | exit 0, no errors |

If you need to fix formatting, run `stylua src tests`.

## Suggested executor toolkit

- `ponytail` skill for every code step: smallest change that fully solves it.
- Roblox Studio MCP tools (`start_stop_play`, `get_console_output`, `screen_capture`, `execute_luau`) for Step 6.

## Scope

**In scope** (the only files you should modify or create):
- `src/shared/Outfit.luau` (create): pure helpers
- `tests/Outfit.spec.luau` (create)
- `tests/run.luau`: register the new spec
- `src/shared/Config.luau`: add `Config.CreatureBundles`
- `tests/Config.spec.luau`: one new check
- `src/server/CreatureRigs.luau` (create): fetch, build and cache rigs
- `src/server/CritterVisual.luau`: add the bundle rig to the lookup order
- `src/server/Main.server.luau`: start the preload

**Out of scope** (do NOT touch):
- `ThrowService.luau`, `PlotService.luau`: callers stay synchronous and unchanged.
- Shopkeeper/quest NPCs, ProximityPrompts, idle animations, ViewportFrame previews, any UI, music, economy, saving (plan 004). Those come in later plans.
- Renaming `CritterVisual` or the `FieldCritters` folder (separate cleanup).
- `Config.Creatures` and its `Creature` type: leave them as they are, and put bundle data in its own table.

## Git workflow

- Work on the current branch `throw-to-collect-core` (the repo's convention so far), or `advisor/006-bundle-rigs` if the operator says so.
- Commit message style matches `git log`: a plain sentence, for example `Build catboy rigs from catalog bundles at server start`. End with the attribution line the operator gives you.
- Do NOT push or open a PR.

## Steps

### Step 1: Write the failing tests for the pure helpers

Create `tests/Outfit.spec.luau` modeled on `tests/Arrival.spec.luau`, requiring `../src/shared/Outfit`. Cases:

`Outfit.pickOutfitId(items)`:
- returns the `Id` of the only `UserOutfit` item, e.g. items `{ {Id=1, Name="Cat Boy", Type="Asset"}, {Id=2, Name="Cat Boy", Type="UserOutfit"} }` → `2`.
- skips a `UserOutfit` whose name contains `Head`: `{ {Id=3, Name="Cat Head", Type="UserOutfit"}, {Id=4, Name="Cat Boy", Type="UserOutfit"} }` → `4`.
- returns `nil` when there is no usable outfit: `{ {Id=5, Name="Cat Head", Type="UserOutfit"} }` → `nil`, and `{}` → `nil`.
- when two usable outfits exist, returns the first one.

`Outfit.withAccessories(existing: string, extra: { number }): string`:
- `("", {101, 102})` → `"101,102"`
- `("55", {101})` → `"55,101"`
- `("55", {})` → `"55"`
- `("", {})` → `""`

Register it in `tests/run.luau`: add `{ name = "Outfit", cases = require("./Outfit.spec") :: any },` to the `specs` list.

**Verify**: `lune run tests/run` → fails (the module doesn't exist yet). This is expected.

### Step 2: Implement `src/shared/Outfit.luau`

Pure Luau, no Roblox APIs, `--!strict`, header comment. Shape:
```lua
--!strict
-- Pure helpers for turning a catalog bundle into a Creature outfit (used by server/CreatureRigs).

local Outfit = {}

export type BundleItem = { Id: number, Name: string, Type: string }

-- The bundle's outfit id: the first UserOutfit item that isn't a head-only outfit.
function Outfit.pickOutfitId(items: { BundleItem }): number?
	for _, item in items do
		if item.Type == "UserOutfit" and not string.find(item.Name, "Head", 1, true) then
			return item.Id
		end
	end
	return nil
end

-- Appends asset ids to a HumanoidDescription comma-separated accessory string.
function Outfit.withAccessories(existing: string, extra: { number }): string
	local parts = if existing == "" then {} else { existing }
	for _, id in extra do
		table.insert(parts, tostring(id))
	end
	return table.concat(parts, ",")
end

return Outfit
```

**Verify**: `lune run tests/run` → `0 failed`, with the new Outfit cases listed as `pass`.

### Step 3: Add the bundle table to Config, with a check

Test first: in `tests/Config.spec.luau` add the case `["creature bundles name known creatures and valid ids"]`. For each `id, look` in `Config.CreatureBundles`: `Config.Creatures[id] ~= nil`; `look.bundleId` is an integer > 0 (`look.bundleId > 0 and look.bundleId % 1 == 0`); every entry of `look.accessoryIds` (if present) is an integer > 0. Run tests and confirm the new case fails because `Config.CreatureBundles` is nil.

Then in `src/shared/Config.luau`, right after the `Config.Creatures` table (after line 67), add:
```lua
-- Catalog bundle each catboy wears (server builds an R15 rig from it at start).
-- A creature with no entry, or whose bundle fails to load, keeps the placeholder rig.
-- accessoryIds: extra catalog accessories (e.g. cat ears) added on top of the bundle's outfit.
-- Keep every look fully clothed: no collars, leashes, chains or chokers.
export type CreatureBundle = { bundleId: number, accessoryIds: { number }? }
Config.CreatureBundles = {} :: { [string]: CreatureBundle }
```
If the operator has given you bundle/accessory ids, fill them in here (keyed by creature id). Otherwise leave the table empty: the owner fills it in later.

**Verify**: `lune run tests/run` → `0 failed`.

### Step 4: Create `src/server/CreatureRigs.luau`

Server module, `--!strict`, header comment. Responsibilities: build each bundle rig once, cache it, and hand out the cached template. Required behavior:

- `CreatureRigs.preload()`: for each `creatureId, look` in `Config.CreatureBundles`, start a `task.spawn` that builds the rig, so one slow bundle never blocks the others or server start. Returns immediately.
- Cache the `HumanoidDescription` per `bundleId` (two creatures may share a bundle). Use a `descriptions: { [number]: HumanoidDescription }` table. Clone the description before adding a creature's accessories, so the cached one stays clean. If two creatures share a bundle, it's fine if both fetch at the same time; don't add locking.
- Each web call (`GetBundleDetailsAsync`, `GetHumanoidDescriptionFromOutfitId`, `CreateHumanoidModelFromDescription`) goes through `pcall`. Use one local helper that tries up to 3 times with `task.wait(2)` between attempts and returns `(ok, result)`.
- Missing outfit id (`Outfit.pickOutfitId` returns nil) or any call failing after its retries: `warn("CreatureRigs: " .. creatureId .. " (bundle " .. bundleId .. "): <reason>; using the placeholder")` once, and store nothing.
- On success: `accessoryIds` (if any) go in via `description.HatAccessory = Outfit.withAccessories(description.HatAccessory, look.accessoryIds)`. Build the R15 model and name it `Config.Creatures[creatureId].name`. If `model.PrimaryPart` is nil, set it to `model:FindFirstChild("HumanoidRootPart")`. If that is also missing, warn and store nothing. Store it in `rigs: { [string]: Model }`. Do not parent it anywhere.
- `CreatureRigs.get(creatureId): Model?`: returns the cached template or nil. It never yields.
- Pass `bundle.Items` to `Outfit.pickOutfitId` with a cast (`bundle.Items :: any`), because the API's return type is loose.

Require `Outfit` and `Config` from `ReplicatedStorage.Shared`, like `CritterVisual.luau` lines 5-9 do.

**Verify**: both type checks and `selene src tests` pass with no errors.

### Step 5: Use the rig in `CritterVisual`, and start the preload

In `src/server/CritterVisual.luau`:
- require `script.Parent.CreatureRigs`;
- add, next to `fromTemplate`:
  ```lua
  -- A catalog-bundle rig built at server start (see CreatureRigs), scaled by rarity.
  local function fromBundle(creatureId: string): Model?
  	local template = CreatureRigs.get(creatureId)
  	if not template then
  		return nil
  	end
  	local model = template:Clone()
  	model:ScaleTo(SCALE_BY_RARITY[Config.Creatures[creatureId].rarity] or 1)
  	return model
  end
  ```
- change line 111 to `local model = fromTemplate(creatureId) or fromBundle(creatureId) or placeholder(creatureId)`. A hand-made template still wins.
- update the header comment (lines 2-3) to name the three sources in order.

In `src/server/Main.server.luau`: require `script.Parent.CreatureRigs` and call `CreatureRigs.preload()` right after `MapBuilder.build()`. Throws made in the first seconds, before rigs finish loading, use the placeholder. That is expected.

**Verify**: all five commands in "Commands you will need" pass. Tests: `0 failed`.

### Step 6: Studio play test

Prerequisites: Studio is open with this place, `rojo serve` is running and connected. If you can't reach Studio, STOP and report that the code is done but unverified in Studio.

1. **Fallback path** (always): with `Config.CreatureBundles` empty, start play (`start_stop_play`), throw a few times (or call the throw path via `execute_luau`), and read `get_console_output`. Expected: no errors, no `CreatureRigs` warnings, and catboys look exactly like before (placeholder).
2. **Bundle path** (only if at least one real bundle id is in `Config.CreatureBundles`): play, wait about 5 seconds, then throw until that creature arrives. Expected: an R15 avatar in the bundle's outfit runs in, hops, its name tag sits above its head, and it moves to the plot. Take a `screen_capture` of it on the lane and on the plot.
3. **Failure path**: temporarily set one entry's `bundleId` to `1` (not a real bundle) in a play session via a local edit, then play. Expected: one `CreatureRigs: ...; using the placeholder` warning, that creature shows the placeholder, and nothing else breaks. **Revert the temporary edit before committing.**
4. Stop play.

**Verify**: `git diff --stat` shows only in-scope files; `Config.CreatureBundles` holds only the operator's real ids (no `1`).

## Test plan

- `tests/Outfit.spec.luau` (new, 9 cases): outfit pick (single, skip head, none, empty list, first of two) and accessory join (4 cases). Pattern: `tests/Arrival.spec.luau`.
- `tests/Config.spec.luau` (+1 case): bundle entries reference known creatures and hold positive integer ids.
- `CreatureRigs` and the `CritterVisual` change use Roblox web APIs, so Lune can't test them. They are covered by the Studio play test in Step 6 (fallback, bundle and failure paths).
- `lune run tests/run` → `68 passed, 0 failed` (58 + 10), give or take if the count drifted. What matters is `0 failed`.

## Done criteria

- [ ] `lune run tests/run` ends with `0 failed` and lists the Outfit cases and the new Config case as `pass`
- [ ] `selene src tests` reports no errors or warnings
- [ ] `stylua --check src tests` exits 0
- [ ] both `luau-lsp analyze` commands exit 0
- [ ] `git grep -n "CreatureRigs.preload" src/server/Main.server.luau` returns one match
- [ ] `git grep -n "fromBundle(creatureId)" src/server/CritterVisual.luau` returns one match on the `local model =` line
- [ ] `git status` shows changes only to in-scope files
- [ ] Step 6 results reported: which paths (fallback / bundle / failure) were checked, with console output and screenshots

## STOP conditions

Stop and report (do not improvise) if:

- The drift check shows changes and the excerpts above no longer match.
- `CreateHumanoidModelFromDescription` or `GetHumanoidDescriptionFromOutfitId` errors in Studio with a permission or "server only" message, even though it runs in a server Script.
- The R15 rig's name tag ends up far from the head, or the rig sinks into or floats above the ground. Report it with a screenshot; don't adjust the `restingPivot` or tag math yourself.
- A bundle's look breaks the kid-appropriate rule (collar, leash, chain, choker, or not fully clothed). Report the bundle id; don't swap in a different bundle yourself.
- Making it work seems to require changing `ThrowService.luau`, `PlotService.luau`, or making `CritterVisual.make` yield.

## Maintenance notes

- The lookup order is now: hand-made template (`ServerStorage.CreatureModels`) → bundle rig → placeholder. Adding a hand-made model for a creature silently overrides its bundle.
- Rigs are built once per server. A bundle that fails at start stays a placeholder until the server restarts. That's fine for a prototype; revisit if failures show up in live logs.
- Rigs are anchored and moved by `PivotTo` tweens, so they don't animate. A walk or idle animation (a known leftover) needs `AnimationController`/`Animator` work and is a separate plan.
- The same `CreatureRigs.get` template can later feed a ViewportFrame preview (the spec's units window) by cloning it on the server and replicating it, or by sending the description to the client. Decide that when the UI layer starts.
- Reviewer focus: no web call reachable from `make`; `pcall` around all three calls; cached description is cloned before accessories are added; temporary `bundleId = 1` was reverted.
