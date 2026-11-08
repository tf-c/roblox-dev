# Plan 007: One Config entry per catboy (name, rarity, zones, look) and a command-bar rig maker

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report, do not improvise. Do NOT edit `plans/README.md`; the reviewer
> maintains the index. Do not commit; the reviewer commits.
>
> **Drift check (run first)**: `git diff --stat b12ec7b..HEAD -- src tests`
> Expected: no output. If any file under `src/` or `tests/` changed, compare the
> "Current state" excerpts against the live code; on a mismatch, STOP.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED (changes how spawn tables are built; `tests/Pacing.spec.luau` guards the odds)
- **Depends on**: plan 006 (DONE)
- **Category**: direction (owner-made catboys)
- **Planned at**: commit `b12ec7b`, 2026-11-08

## Why this matters

The owner wants to make catboys themselves: give each one a name, a rarity, where it can be found, and a look. Today that information is spread over three tables: `Config.Creatures` (name, rarity, income, color), `Config.ZoneTables` (where each creature is found and its odds) and `Config.CreatureBundles` (look). After this plan, **one entry in `Config.Creatures` holds everything**. `Config.ZoneTables` is derived from those entries, and a look can come from a bundle id, an outfit id, or a manual list of asset ids, with optional overrides. A command-bar line builds any catboy's rig in edit mode and saves it to `ServerStorage.CreatureModels`, where the owner can hand-tweak it. A saved model already overrides the Config look (existing behavior).

Decided with the owner (do not add these): no copying a real user's avatar (no `userId` look), no random look generator, no saved looks, no ProximityPrompts/shops/quests, no idle animation. Rarities stay `common | rare | epic`.

## Current state

Strict-mode Luau Roblox game synced with Rojo (`src/shared` → `ReplicatedStorage.Shared`, `src/server` → `ServerScriptService.Server`). Rojo does **not** manage `ServerStorage`, so models saved there live in the place file. Every module starts with `--!strict` and a header comment. `src/shared/` is pure Luau with no Roblox APIs (Lune tests it). `Config.luau` has **no requires** and stores colors as hex strings. Vocabulary (`GLOSSARY.md`): say **Creature** in code, **Catboy** in player-facing text; never "critter", "pet" or "unit" in new names.

### `src/shared/Config.luau` today (relevant parts)

Lines 5-11, policy comment (keep its meaning):
```lua
-- POLICY RULES (from roblox-researcher policy_check.md), keep these true:
--   * Spawns stay free. ZoneTables weights are fixed; nothing bought with Robux,
--     or with cash bought with Robux, may change them.
```
Zone ids (lines 38-42): `lawn` (shown as Backyard), `grove` (Park), `wildwood` (Meadow).

Lines 51-67:
```lua
export type Creature = {
	name: string,
	rarity: string, -- "common" | "rare" | "epic" (Config.spec checks)
	income: number,
	color: string,
}

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
Then a comment block plus:
```lua
export type CreatureBundle = { bundleId: number, accessoryIds: { number }? }
-- (comments listing the Roblox-made item ids and "Avoid Oakley/John/Casey ...")
Config.CreatureBundles = {
	pillow = { bundleId = 722, accessoryIds = { 1374269, 187846604 } }, -- Denny
	slipper = { bundleId = 605, accessoryIds = { 22070807, 170892848 } }, -- Dennis
	pickle = { bundleId = 608, accessoryIds = { 1374269, 170892848 } }, -- Kenneth
	caramel = { bundleId = 109, accessoryIds = { 1374269, 187846604 } }, -- ROBLOX Boy
	satin = { bundleId = 573, accessoryIds = { 1374269, 170892848 } }, -- Oliver
	linden = { bundleId = 572, accessoryIds = { 244159564, 212358027 } }, -- Summer
} :: { [string]: CreatureBundle }
```
Then the `Config.CreatureIncome` derivation loop (the pattern for deriving a table inside Config), and:
```lua
Config.ZoneTables = {
	lawn = { { id = "pillow", weight = 80 }, { id = "slipper", weight = 20 } },
	grove = { { id = "pickle", weight = 75 }, { id = "caramel", weight = 25 } },
	wildwood = { { id = "satin", weight = 85 }, { id = "linden", weight = 15 } },
}
```
`Config.ZoneTables` is read by `src/server/ThrowService.luau:169` (`WeightedRoll.pick(Config.ZoneTables[zoneId], nextNumber)`) and `tests/Pacing.spec.luau:50` with a seeded RNG, so **entry order inside each zone matters**: the derived tables must come out exactly as above (heaviest weight first, ties by id ascending).

### `src/shared/Outfit.luau` (from plan 006)
Pure helpers: `Outfit.pickOutfitId(items: { BundleItem }): number?` (first `UserOutfit` whose name lacks "Head") and `Outfit.withAccessories(existing: string, extra: { number }): string` (comma join). Tests in `tests/Outfit.spec.luau` (9 cases, keep them).

### `src/server/CreatureRigs.luau` (from plan 006)
Builds each rig once at server start and caches it. Key pieces to keep: `retry(fn)` (3 attempts, `task.wait(2)` between, returns `ok, result`), `descriptions` cache keyed by bundle id, `build(creatureId, look)` with a `fail(reason)` warn of the form `CreatureRigs: <id> (bundle <n>): <reason>; using the placeholder`, `CreatureRigs.preload()` (one `task.spawn(build, ...)` per entry in `Config.CreatureBundles`) and `CreatureRigs.get(creatureId): Model?` (never yields). Accessories are added through `desc.HatAccessory = Outfit.withAccessories(desc.HatAccessory, ids)`. This works for any rigid accessory type, including waist tails (verified in Studio).

### `src/server/CritterVisual.luau`
Lookup order in `make`: `fromTemplate(creatureId)` (a Model named after the id in `ServerStorage.CreatureModels`, must have a PrimaryPart) → `fromBundle(creatureId)` (clone of `CreatureRigs.get`, scaled by rarity) → `placeholder(creatureId)`. **Do not change this file** except the one comment noted in Step 5.

### Exemplar test style: `tests/Arrival.spec.luau` / `tests/Config.spec.luau`
Each spec returns `{ ["case name"] = function() ... end }` and uses `Assert.eq / Assert.truthy` from `tests/assert.luau`. `tests/run.luau` lists every spec; it's already registered for Outfit and Config.

## Commands you will need

Run from `C:\Users\pi\roblox-dev`. Use the **Bash** tool (PowerShell has crashed in this environment).

| Purpose | Command | Expected on success |
|---|---|---|
| Tests | `lune run tests/run` | last line `N passed, 0 failed` (68 before this plan) |
| Lint | `selene src tests` | `0 errors`, `0 warnings` |
| Format | `stylua --check src tests` | exit 0 (fix with `stylua src tests`) |
| Types (game) | `rojo sourcemap default.project.json -o sourcemap.json && luau-lsp analyze --sourcemap=sourcemap.json --definitions=globalTypes.d.luau src` | exit 0, no errors |
| Types (tests) | `luau-lsp analyze --platform=standard --ignore="tests/run.luau" src/shared tests` | exit 0, no errors |

## Scope

**In scope:**
- `src/shared/Config.luau`
- `src/shared/Outfit.luau`
- `src/server/CreatureRigs.luau`
- `src/server/CritterVisual.luau` (header comment only)
- `tests/Config.spec.luau`
- `tests/Outfit.spec.luau`
- `README.md` (add a short "Making a catboy" section)

**Out of scope (do NOT touch):** `ThrowService.luau`, `PlotService.luau`, `Main.server.luau`, `tests/Pacing.spec.luau` (must pass unchanged), `WeightedRoll.luau`, anything client-side, `default.project.json`, `.claude/`, `plans/README.md`.

## Steps

### Step 1: Tests first: new Outfit helpers

Add to `tests/Outfit.spec.luau` (keep the existing 9 cases):

`Outfit.source(look): "bundle" | "outfit" | "manual" | nil`, which says where a look comes from. Exactly one of `bundleId`, `outfitId`, `manual` must be set:
- `{ bundleId = 722 }` → `"bundle"`
- `{ outfitId = 5 }` → `"outfit"`
- `{ manual = {} }` → `"manual"`
- `{}` → `nil`
- `{ bundleId = 1, outfitId = 2 }` → `nil` (two sources is an error)

`Outfit.manualProperties(manual): { [string]: string | number }` maps the owner-friendly manual table to `HumanoidDescription` property names:
- accessory lists → comma strings: `hats`→`HatAccessory`, `hair`→`HairAccessory`, `face`→`FaceAccessory`, `neck`→`NeckAccessory`, `shoulder`→`ShouldersAccessory`, `front`→`FrontAccessory`, `back`→`BackAccessory`, `waist`→`WaistAccessory`. Example: `{ hats = { 1, 2 } }` → `HatAccessory = "1,2"`.
- single ids → numbers: `shirt`→`Shirt`, `pants`→`Pants`, `graphicTShirt`→`GraphicTShirt`, `faceId`→`Face`.
- fields that are absent produce no key (`manualProperties({})` has no keys; check with a `next(result) == nil` assert).
- Test cases: `hats` + `waist` + `shirt` together map to exactly those three keys and values; empty table gives no keys.

**Verify**: `lune run tests/run` → the new cases FAIL (functions missing). Expected.

### Step 2: Implement the helpers in `src/shared/Outfit.luau`

Add the types and two functions; keep the file pure. Types (export them; Config can't require Outfit, so Config declares its own matching types in Step 3, the way it already does for `UpgradeLadder`):
```lua
export type ManualLook = {
	hats: { number }?, hair: { number }?, face: { number }?, neck: { number }?,
	shoulder: { number }?, front: { number }?, back: { number }?, waist: { number }?,
	shirt: number?, pants: number?, graphicTShirt: number?, faceId: number?,
}
export type Look = {
	bundleId: number?, outfitId: number?, manual: ManualLook?,
	accessoryIds: { number }?,       -- add on top
	removeAccessoryIds: { number }?, -- take off the source outfit
	skinColor: string?,              -- "#rrggbb", all body parts
	scale: { height: number?, width: number?, head: number?, proportion: number?, bodyType: number? }?,
}
```
`source`: count which of the three is non-nil; return the name only when exactly one is set. `manualProperties`: two small lookup tables (list fields → property name, single fields → property name), loop and fill; join lists with `table.concat` over `tostring`.

**Verify**: `lune run tests/run` → `0 failed`.

### Step 3: Tests first: one entry per creature in Config

Edit `tests/Config.spec.luau`:
- **Replace** the case `"creature bundles name known creatures and valid ids"` with `"every creature has a valid look"`. For each creature: `Outfit.source(def.look) ~= nil` (require `../src/shared/Outfit`); every id in `bundleId`, `outfitId`, `accessoryIds`, `removeAccessoryIds` and in `manual` lists/single ids is an integer > 0; `skinColor`, if set, matches `^#%x%x%x%x%x%x$`; every `scale` value, if set, is > 0.
- **Add** `"every creature is found in at least one known zone"`: `def.zones` has at least one key, every key is a zone id in `Config.Zones`, and every weight is > 0.
- **Keep** the existing cases unchanged, especially `"every zone has a spawn table of known critters"` and `"starter catboys fill the six creature slots"`. Those two prove the derived `ZoneTables` are identical to today's.

**Verify**: `lune run tests/run` → the new/changed cases fail (no `look`/`zones` fields yet). Expected.

### Step 4: Restructure `src/shared/Config.luau`

1. Declare `ManualLook` and `CreatureLook` types in Config with the same shape as Outfit's `ManualLook`/`Look` (Config stays require-free; add a comment "Same shape as Outfit.Look"). Extend `Creature`:
   ```lua
   export type Creature = {
   	name: string,
   	rarity: string, -- "common" | "rare" | "epic" (Config.spec checks)
   	income: number,
   	color: string,
   	zones: { [string]: number }, -- zone id -> spawn weight in that zone
   	look: CreatureLook,
   }
   ```
2. Move each creature's bundle look and its zone weight into its entry, using today's values exactly. Format each entry over multiple lines so it is easy to copy, e.g.
   ```lua
   pillow = {
   	name = "Pillow",
   	rarity = "common",
   	income = 1,
   	color = "#f2a65a",
   	zones = { lawn = 80 },
   	look = { bundleId = 722, accessoryIds = { 1374269, 187846604 } }, -- Denny, Kitty Ears, orange tail
   },
   ```
   Weights: pillow lawn 80, slipper lawn 20, pickle grove 75, caramel grove 25, satin wildwood 85, linden wildwood 15.
3. Delete `Config.CreatureBundles` and its type. Keep the comment lines about the Roblox-made item ids and "Avoid Oakley/John/Casey…", moved above `Config.Creatures`.
4. Write a "how to add a catboy" comment above `Config.Creatures` (plain, short): copy an entry, give it a new id key, name, rarity (`common`/`rare`/`epic`), income, `zones` (zone ids: lawn = Backyard, grove = Park, wildwood = Meadow, with a weight per zone), and a `look` with exactly one of `bundleId` (number in the catalog bundle URL), `outfitId`, or `manual = { hats = {...}, hair = {...}, shirt = ..., pants = ... }`; optional `accessoryIds`, `removeAccessoryIds`, `skinColor`, `scale`. Keep looks fully clothed: no collars, leashes, chains or chokers.
5. Replace the literal `Config.ZoneTables` with a derivation placed after `Config.Creatures` (mirror the `CreatureIncome` loop style):
   - for each zone in `Config.Zones`, collect `{ id = creatureId, weight = w }` from every creature whose `zones[zone.id]` is set;
   - `table.sort` each list by weight descending, then id ascending;
   - type it `{ [string]: { { id: string, weight: number } } }`.
6. Update the policy comment: "Spawns stay free. Zone weights (`zones` on each creature, which build ZoneTables) are fixed; …".

**Verify**: `lune run tests/run` → `0 failed`, including `Pacing` (unchanged) and `"starter catboys fill the six creature slots"`.

### Step 5: Generalize `src/server/CreatureRigs.luau`

Keep the module's shape and the retry/cache/warn behavior. Changes:
1. **`describe(look): (HumanoidDescription?, string)`**, the source description by `Outfit.source(look)`:
   - `"bundle"`: today's bundle path (cache by bundle id; "bundle has no outfit" → fail message `Bundle <id> has no UserOutfit`).
   - `"outfit"`: `Players:GetHumanoidDescriptionFromOutfitId(outfitId)` via `retry`, cached in a second table keyed by outfit id.
   - `"manual"`: `Instance.new("HumanoidDescription")`, then set each pair from `Outfit.manualProperties(look.manual)` (`(desc :: any)[prop] = value`).
   - `nil`: return `nil, "look needs exactly one of bundleId, outfitId, manual"`.
   Always return a **clone** of a cached description, so overrides never touch the cache.
2. **Overrides** (in this order, in a local `applyOverrides(desc, look)`):
   - `removeAccessoryIds`: `local list = desc:GetAccessories(true)`, keep entries whose `AssetId` isn't in the remove set, `desc:SetAccessories(kept, true)`.
   - `accessoryIds`: today's `HatAccessory` append.
   - `skinColor`: `Color3.fromHex`, set to `HeadColor, TorsoColor, LeftArmColor, RightArmColor, LeftLegColor, RightLegColor`.
   - `scale`: `HeightScale, WidthScale, HeadScale, ProportionScale, BodyTypeScale` for the fields given.
3. **`CreatureRigs.buildLook(look, name): (Model?, string)`**: describe → overrides → `CreateHumanoidModelFromDescription(desc, R15)` via `retry` → name it → ensure `PrimaryPart` (fallback `HumanoidRootPart`). Yields. Returns `nil, reason` on failure. Used by both paths below.
4. `build(creatureId)` / `preload()`: iterate `Config.Creatures` and use `def.look`; warn format stays `CreatureRigs: <id>: <reason>; using the placeholder`.
5. **`CreatureRigs.saveModel(creatureId)`**, the command-bar tool (works in edit mode, yields): build with `buildLook`; on failure `warn` the reason and return. On success, get or create the `Folder` `ServerStorage.CreatureModels`, destroy any existing child named `creatureId` (print that it was replaced), set the model's name to `creatureId` (the folder lookup uses the id), parent it there and `print("Saved ServerStorage.CreatureModels." .. creatureId .. ". It now overrides the Config look. Save the place (Ctrl+S) to keep it.")`. Also add `CreatureRigs.saveAll()` that calls `saveModel` for every creature id in order.
6. Header comment: mention the command-bar line: `require(game.ServerScriptService.Server.CreatureRigs).saveModel("pillow")`.

In `src/server/CritterVisual.luau`, only update the header comment so it says the rig in `CreatureModels` can be made with `CreatureRigs.saveModel`.

**Verify**: all five commands pass.

### Step 6: README section

Add `## Making a catboy` to `README.md` (after "Checks"), 6-10 lines: add an entry to `Config.Creatures` (see the comment there), where to find ids (the number in a catalog URL: `roblox.com/bundles/<id>/…` for bundles, `roblox.com/catalog/<id>/…` for accessories and clothing), and the command-bar line to save an editable model (and that a saved model overrides the Config look until deleted from `ServerStorage.CreatureModels`). No all-caps.

**Verify**: `git diff --stat` lists only in-scope files.

## Test plan

- `tests/Outfit.spec.luau`: +7 cases (5 `source`, 2 `manualProperties`).
- `tests/Config.spec.luau`: one case replaced, one added.
- Unchanged and must pass: `Pacing`, `"starter catboys fill the six creature slots"`, `"every zone has a spawn table of known critters"`. Together they prove the derived spawn tables match today's exactly.
- Expected total: `76 passed, 0 failed` (68 + 7 + 1). If the count differs, what matters is `0 failed` with the named cases present.
- Roblox API paths (outfit, manual, overrides, saveModel) are checked by the reviewer in Studio; not part of your work.

## Done criteria

- [ ] `lune run tests/run` ends `0 failed`; new Outfit cases and the two Config cases pass
- [ ] selene, stylua --check, both luau-lsp commands clean
- [ ] `git grep -n "CreatureBundles" src tests` → no matches
- [ ] `git grep -n "Config.ZoneTables = {$" src/shared/Config.luau` → no matches (no literal table left)
- [ ] `git grep -n "saveModel" src/server/CreatureRigs.luau` → at least 2 matches
- [ ] `git status` shows only in-scope files changed

## STOP conditions

- Drift check fails, or the excerpts don't match the live files.
- `Pacing` or `"starter catboys fill the six creature slots"` fails after Step 4 and the cause isn't entry order. Do not edit those tests.
- The type checker rejects the `Creature` type with optional nested tables in a way that would need `any` on `Config.Creatures` as a whole. Report it instead of loosening types broadly (a cast on a single field is fine).
- Anything seems to require changing `ThrowService`, `PlotService`, `Main.server.luau` or client code.

## Maintenance notes

- Adding a catboy is now one Config entry. Adding a rarity beyond `common/rare/epic` also needs `Config.RarityColors`, `SCALE_BY_RARITY` in `CritterVisual`, and the `RARITIES` set in `Config.spec`. That belongs to the economy layer.
- A saved `CreatureModels.<id>` model always wins over the Config look. If a Config look change "does nothing", check that folder.
- Manual looks start from a blank description (default grey body). Owners will usually want `skinColor` with them.
- Reviewer focus: derived ZoneTables order; cached descriptions cloned before overrides; `saveModel` names the model by id; no `userId` path added.
