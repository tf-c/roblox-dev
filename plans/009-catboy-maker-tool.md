# Plan 009: Owner-only catboy maker panel in Studio play tests

> **Executor instructions**: Follow this plan step by step. Run every verification command and confirm
> the expected result before moving to the next step. If a STOP condition occurs, stop and report; do
> not improvise. Do NOT edit `plans/README.md` and do not commit; the reviewer does both. Use the
> `ponytail` skill for all coding: smallest change that fully solves each step. Write each step's tests
> BEFORE its code, and run them once to see them fail.
>
> **Drift check (run first)**: `git diff --stat 49c30a7..HEAD -- src tests README.md`
> Expected: no output. If anything changed, compare the "Current state" excerpts with the live code; on
> a mismatch, STOP.

## Status

- **Priority**: P1 · **Effort**: M-L · **Risk**: LOW (dev-only, gated; one small Config shape addition)
- **Depends on**: plan 007 (DONE), plan 008 (DONE)
- **Category**: dx (content tool)
- **Planned at**: commit `49c30a7`, 2026-11-08

## Why this matters

Making a catboy today means finding catalog ids in a browser, typing a `Config.Creatures` entry by hand,
and restarting a play test to see it. This plan adds an in-game panel, visible only to the place owner
during a Studio play test, that searches the catalog, builds the look on a live rig in front of the
owner, and prints a ready-to-paste Config entry. The owner pastes it into `src/shared/Config.luau`; the
tool never writes files (Rojo syncs files → Studio only, never back).

## Decisions already made with the owner (do not revisit)

- Runs only when `RunService:IsStudio()` is true and `player.UserId == game.CreatorId` (the owner's
  account, UserId 827049048; the place is user-owned). Checked on the **server**. Players never see it.
- Output is text only: shown in a box in the panel and printed to the Output window. No save-to-
  ServerStorage button.
- Look editing: (1) pick a catalog **bundle** → `look.bundleId`; (2) add/remove accessories →
  `accessoryIds` / `removeAccessoryIds`; (3) classic **shirt and pants** → new optional `look.shirt` /
  `look.pants` overrides that work on top of any look source (Step 1); (4) **skin color** (swatches +
  hex box) and **scale** sliders.
- Entry fields: id, name, rarity (`common | rare | epic`), income (owner types it; no suggestion),
  color (hex), zones with weights (`lawn` = Backyard, `grove` = Park, `wildwood` = Meadow).
- Still in force: no copying a real user's avatar, no random look generator, every look fully clothed
  (no collars, leashes, chains or chokers). Roblox-made items preferred: search defaults to
  `CreatorName = "Roblox"`. Say "Catboy" in UI text, "Creature" in code. **No all-caps UI text.**
- No `roblox-game-ux` brief: the Layout section below is the spec.

## Current state (verified at `49c30a7`)

Strict Luau, Rojo (`default.project.json`): `src/shared` → `ReplicatedStorage.Shared`, `src/server` →
`ServerScriptService.Server`, `src/client` → `StarterPlayer.StarterPlayerScripts.Client`. Every module
starts with `--!strict` and a 1–3 line header comment. `src/shared/` is pure Luau with no Roblox APIs
(Lune tests it). `Config.luau` has no requires and stores colors as hex strings.

- `src/shared/Config.luau:66-74`, the look type:
  ```lua
  export type CreatureLook = {
  	bundleId: number?,
  	outfitId: number?,
  	manual: ManualLook?,
  	accessoryIds: { number }?,
  	removeAccessoryIds: { number }?,
  	skinColor: string?,
  	scale: { height: number?, width: number?, head: number?, proportion: number?, bodyType: number? }?,
  }
  ```
  `export type Creature = { name, rarity, income, color, zones: { [string]: number }, look }` (76-83).
  Comment block above `Config.Creatures` (88-98) says "Optional on top of any look: accessoryIds,
  removeAccessoryIds, skinColor ("#rrggbb"), scale." `Config.Zones` (38-42) lists zone ids in order.
- `src/shared/Outfit.luau:22-30`, `Outfit.Look`, same shape as `CreatureLook` with trailing comments.
  `Outfit.source(look)` returns `"bundle" | "outfit" | "manual"` or nil (exactly one source required).
- `src/server/CreatureRigs.luau:113-144`, `applyOverrides(desc, look)` handles removeAccessoryIds,
  accessoryIds, skinColor, scale, in that order. `CreatureRigs.buildLook(look, name): (Model?, string)`
  (147) yields, retries web calls, returns nil + reason on failure. The preview code in `build`
  (213-223) shows how to anchor a rig and hide the Humanoid name: reuse that loop.
- `tests/Config.spec.luau:177-236`, "every creature has a valid look": `lookKeys` set (182-190),
  `validId` (178-180), and the scale check `Assert.truthy(scaleKeys[field] and value > 0, ...)` (233).
- `tests/run.luau`, registers each spec in a `specs` list and fails on unregistered spec files.
  Test style: a spec returns `{ ["case name"] = function() ... end }` using `tests/assert.luau`
  (`Assert.eq(a, b, label)`, `Assert.truthy(v, label)`). Model new specs on `tests/Outfit.spec.luau`.
- `src/server/Main.server.luau`, requires services, calls `X.init()`, and `onPlayerAdded` per player.
- `src/client/Main.client.luau`, builds `Hud`, `CatboysWindow`, controllers.
- UI style to match: `src/client/CatboysWindow.luau`, local `corner`, `stroke`, `text` helpers
  (GothamBlack/GothamBold, white text, `Color3.fromRGB(30, 30, 40)` panel, `#1e1e28` stroke,
  12–16 px corners). Copy the helpers locally into the new client module (same as CatboysWindow does).
- Verified in Studio on 2026-11-08: `AvatarEditorService:SearchCatalog(CatalogSearchParams)` works in a
  play-test client with no permission prompt. Each result has `Id`, `Name`, `CreatorName`,
  `ItemType` ("Asset"/"Bundle"), `AssetType`/`BundleType`. `CreatorName = "Roblox"` filters to Roblox
  items. `pages.IsFinished` and `pages:AdvanceToNextPageAsync()` page through results (30 per page).
  Example: Roblox bundles 722 Denny, 605 Dennis; Roblox hat 1374269 Kitty Ears.

## Commands you will need

| Purpose | Command | Expected |
|---|---|---|
| Tests | `lune run tests/run` | all pass |
| Lint | `selene src tests` | 0 errors |
| Format | `stylua --check src tests` | exit 0 (run `stylua src tests` to fix) |
| Types (game) | `rojo sourcemap default.project.json -o sourcemap.json` then `luau-lsp analyze --sourcemap=sourcemap.json --definitions=globalTypes.d.luau src` | no errors |
| Types (tests) | `luau-lsp analyze --platform=standard --ignore="tests/run.luau" src/shared tests` | no errors |

Use Bash (Git Bash) for these, not PowerShell.

## Scope

**In scope**:
- `src/shared/Config.luau` (type + comment only), `src/shared/Outfit.luau` (type only)
- `src/server/CreatureRigs.luau` (`applyOverrides` only)
- `src/shared/CreatureEntry.luau` (create), `tests/CreatureEntry.spec.luau` (create), `tests/run.luau`
- `tests/Config.spec.luau` (look keys, scale check, one new case)
- `src/server/CatboyMaker.luau` (create), `src/server/Main.server.luau`
- `src/client/CatboyMaker.luau` (create), `src/client/Main.client.luau`
- `README.md` ("Making a catboy" section)

**Out of scope**: `Remotes.luau` (the dev remote must not exist in live games, so CatboyMaker makes its
own), `CatboysWindow.luau`, `Hud.luau`, any `Config.Creatures` entry, the starter-catboy test, saving,
an economy/income suggester, a random look generator, loading an existing catboy into the tool.

## Steps

### Step 1: Add `shirt` and `pants` look overrides

Tests first, in `tests/Config.spec.luau`:
- Add `shirt = true, pants = true` to `lookKeys` (182-190), and validate them with `validId` when set
  (next to the bundleId/outfitId checks).
- Change the scale check at 233 to `value >= 0` (proportion and bodyType are valid at 0).

Then:
- `Config.luau` `CreatureLook` and `Outfit.luau` `Look`: add `shirt: number?, pants: number?` (Outfit
  comment: `-- classic clothing asset id, on top of any source`).
- Config comment (93): "Optional on top of any look: accessoryIds, removeAccessoryIds, shirt, pants
  (catalog ids), skinColor ("#rrggbb"), scale."
- `CreatureRigs.applyOverrides`: after the accessory block, `if look.shirt then desc.Shirt = look.shirt end`
  and the same for `pants` / `desc.Pants`.

**Verify**: `lune run tests/run` → all pass; both type checks clean.

### Step 2: Pure `CreatureEntry` module (validate + format)

Write `tests/CreatureEntry.spec.luau` first and register it in `tests/run.luau` as
`{ name = "CreatureEntry", cases = require("./CreatureEntry.spec") :: any }`. Cases:
1. `format` round-trips: a full entry (bundleId, accessoryIds, removeAccessoryIds, shirt, pants,
   skinColor, all five scale fields, two zones) → `format("mochi", def)` → load with
   `require("@lune/luau").load("return {" .. out .. "}")()` → `.mochi` deep-equals `def`
   (write a small local `deepEq` in the spec).
2. `format` escapes a name containing `"` and `\` (round-trip still equal).
3. `format` is deterministic: zone keys sorted, look keys in a fixed order (call twice, same string).
4. `validate` returns `{}` for the full entry with known zone ids.
5. `validate` returns a non-empty list for each of: bad id key (`"Mochi Cat"`, `"1cat"`), empty name,
   rarity `"legendary"`, income `0` and `1.5`, color `"orange"`, no zones, unknown zone `"beach"`,
   weight `0`, both bundleId and outfitId set, no source, accessory id `0`, skinColor `"#fff"`, scale
   key `"tall"`.

Then create `src/shared/CreatureEntry.luau`. It has **no requires** (no shared module requires a
sibling today, and the same file must load in both Lune and Roblox). Check the look source inline
with the same rule as `Outfit.source` (exactly one of bundleId, outfitId, manual), with a comment
pointing at `Outfit.source`. The spec requires it as `require("../src/shared/CreatureEntry")`; the
client requires it as `ReplicatedStorage.Shared.CreatureEntry`.

```lua
-- Checks and prints a Config.Creatures entry; used by the catboy maker panel.
export type Entry = Config.Creature shape (name, rarity, income, color, zones, look) -- re-declare locally, Config stays require-free
function CreatureEntry.validate(id: string, entry, zoneIds: { string }): { string } -- list of problems, {} if valid
function CreatureEntry.format(id: string, entry): string
```
Rules for `validate` (match `tests/Config.spec.luau` exactly): id matches `^[a-z][a-z0-9]*$`; name
non-empty; rarity in common/rare/epic; income a positive integer; color `^#%x%x%x%x%x%x$`; at least one
zone, each id in `zoneIds`, weight a positive integer; exactly one look source; every id
(bundleId, outfitId, shirt, pants, accessory ids) a positive integer; skinColor hex if set; scale keys
in height/width/head/proportion/bodyType with value >= 0. Messages are plain sentences for the panel,
e.g. `"Pick a rarity: common, rare or epic"`.

`format` output shape (tab-indented to sit inside `Config.Creatures`, trailing comma):
```lua
	mochi = {
		name = "Mochi",
		rarity = "rare",
		income = 12,
		color = "#f2a65a",
		zones = { grove = 30, lawn = 10 },
		look = { bundleId = 722, accessoryIds = { 1374269, 187846604 }, shirt = 123, skinColor = "#f5cba7", scale = { height = 1.02 } },
	},
```
Look key order: bundleId, outfitId, accessoryIds, removeAccessoryIds, shirt, pants, skinColor, scale;
scale key order: height, width, head, proportion, bodyType. Omit unset keys. Names via
`string.format("%q", name)`. Numbers: integers with `%d`, scale values with `%.2f` trimmed of trailing
zeros. `manual` looks are not produced by the tool; `format` may error on them (`error("manual looks
are not supported")`).

Add one case to `tests/Config.spec.luau`: "every creature passes CreatureEntry.validate" (zone ids from
`Config.Zones`). Leave the existing cases as they are.

**Verify**: `lune run tests/run` → all pass including the new spec; type checks clean.

### Step 3: Server side, `src/server/CatboyMaker.luau`

```lua
-- Owner-only catboy maker (Studio play tests only): builds a previewed look on a rig in front of the owner.
function CatboyMaker.init()   -- if not RunService:IsStudio() then return end; create RemoteEvent
                              -- ReplicatedStorage.CatboyMakerPreview; connect OnServerEvent
function CatboyMaker.add(player: Player) -- if IsStudio and player.UserId == game.CreatorId then
                              -- player:SetAttribute("CatboyMaker", true)
```
`OnServerEvent(player, look)`:
1. Ignore unless IsStudio and `player:GetAttribute("CatboyMaker")`. Ignore if `type(look) ~= "table"`.
2. Bump a per-player `generation` counter; call `pcall(CreatureRigs.buildLook, look, "CatboyMakerRig")`.
   If the counter moved on while it yielded, destroy the result and return (only the latest wins).
3. Failure → `remote:FireClient(player, false, reason)`.
4. Success → destroy the previous `Workspace.CatboyMakerRig`; anchor every BasePart and set Humanoid
   `DisplayDistanceType = None` (same loop as `CreatureRigs` build, 213-223); `PivotTo` 8 studs in front
   of the player's `HumanoidRootPart`, facing the player (`CFrame.lookAt(spot, rootPosition * (1,0,1)
   + spot.Y)`), feet on the ground (offset up by half the bounding box height, like CritterVisual does
   if it has a helper; otherwise `GetBoundingBox`). No character → place at `Config.Map.padPosition`
   + 8 on Z. Parent to Workspace.
5. Reply `remote:FireClient(player, true, ids)` where `ids` is the asset ids from
   `humanoid:GetAppliedDescription():GetAccessories(true)` (so the panel can list the bundle's own
   accessories for removal).

Wire it in `Main.server.luau`: `CatboyMaker.init()` after `CreatureRigs.preload()`, and
`CatboyMaker.add(player)` in `onPlayerAdded`.

**Verify**: type checks and selene clean.

### Step 4: Client panel, `src/client/CatboyMaker.luau`

`CatboyMaker.init()`: return unless `RunService:IsStudio()`; in `task.spawn`, wait for the
`CatboyMaker` attribute (`GetAttributeChangedSignal(...):Wait()` if not already true), then
`ReplicatedStorage:WaitForChild("CatboyMakerPreview")`, build the panel, bind key **M** to toggle it
(skip when `gameProcessed`, so typing "m" in a TextBox doesn't toggle), and `print("Catboy maker: press M")`.
Call it from `Main.client.luau` (one line at the end). The panel starts hidden.

State (one local table): `bundleId`, `accessoryIds`, `removeAccessoryIds`, `shirt`, `pants`,
`skinColor`, `scale` (only touched fields), and the details fields. Any look change → send the look
with `remote:FireServer(look)`, debounced 0.3 s, and set the status line to "Building…". Reply →
status "Ready" or the reason in red; on success refresh the "On the rig" chips from the returned ids.

#### Layout (dev-only, desktop; no mobile pass)

Own ScreenGui `CatboyMakerGui` (`ResetOnSpawn = false`, `DisplayOrder = 10`). One panel anchored
top-right: `Position UDim2.new(1, -8, 0, 8)`, `AnchorPoint (1, 0)`, `Size UDim2.new(0, 380, 1, -16)`,
colors and corners as CatboysWindow. Title "Catboy maker" + 44 px close button (same style as
CatboysWindow's). Below, one vertical `ScrollingFrame` (`AutomaticCanvasSize Y`, `UIListLayout`, 8 px
padding) with these sections in order, each with a small GothamBold heading:

1. **Search**, keyword TextBox; a row of category toggle buttons: Bundles, Hats, Hair, Face, Neck,
   Shoulder, Front, Back, Waist, Shirts, Pants (wrap with `UIGridLayout`); a "Roblox only" toggle (on by
   default → `CreatorName = "Roblox"`); a Search button (Enter in the box also searches). Results: a
   3-column grid of 100 px `ImageButton`s, image `rbxthumb://type=Asset&id=<id>&w=150&h=150` (bundles:
   `rbxthumb://type=BundleThumbnail&id=<id>&w=150&h=150`), name label under each; a "More" button
   (hidden when `pages.IsFinished`). Category → params: Bundles → `BundleTypes = {BodyParts}`; Hats →
   `AssetTypes = {Enum.AvatarAssetType.Hat}`; Hair → `HairAccessory`; Face → `FaceAccessory`; Neck →
   `NeckAccessory`; Shoulder → `ShoulderAccessory`; Front → `FrontAccessory`; Back → `BackAccessory`;
   Waist → `WaistAccessory`; Shirts → `Shirt`; Pants → `Pants`. Wrap `SearchCatalog` and
   `AdvanceToNextPageAsync` in `pcall`; show the error in the status line.
   Click: bundle → set `bundleId`; accessory → add to `accessoryIds` (no duplicates); shirt/pants → set.
2. **On the rig**, status line ("Pick a bundle to start", "Building…", "Ready", or the error).
   Chip row: Bundle chip (thumbnail + id, × clears it), Shirt chip, Pants chip, then one thumbnail chip
   per id the server returned. × on an accessory chip: if it's in `accessoryIds`, remove it there;
   otherwise add it to `removeAccessoryIds`. A "Removed" chip row lists `removeAccessoryIds` with ↺ to
   restore.
3. **Skin**, 10 preset swatches (light to dark skin tones plus a few fun colors) and a hex TextBox;
   a "Bundle skin" button clears `skinColor`.
4. **Scale**, five sliders (a bar Frame with a draggable knob; one local `slider()` helper) with a
   value label and a reset (↺) button that removes the field. Ranges: height 0.9–1.05, width 0.7–1,
   head 0.95–1, proportion 0–1, bodyType 0–1; step 0.01. Labels: Height, Width, Head, Proportion,
   Body type.
5. **Details**, Id TextBox (placeholder "lowercase, e.g. mochi"; note "Replaces the existing
   <name>" if the id is already in `Config.Creatures`); Name; Rarity (three toggle buttons: Common,
   Rare, Epic, using `Config.RarityColors`); Income (number TextBox, placeholder lists existing incomes
   for the chosen rarity, e.g. "rare now: 4, 10, 25"); Color (hex TextBox + swatch preview, label
   "Ears and hair color"); Zones: one row per `Config.Zones` entry showing `Config.ZoneLooks[id].name`,
   a checkbox and a weight TextBox.
6. **Config entry**, "Make entry" button: builds the entry, runs `CreatureEntry.validate`; problems
   → list them in red; valid → put `CreatureEntry.format(id, entry)` in a multi-line TextBox
   (`ClearTextOnFocus = false`, `TextEditable = true`, `MultiLine = true`) and `print` it to Output
   with the line "Paste into Config.Creatures in src/shared/Config.luau:".

Keep all UI text sentence case. The file will be long (~400 lines); that is fine for a dev tool, but
keep one helper per repeated widget (button, chip, slider, textbox) instead of copy-paste.

**Verify**: type checks, selene and stylua clean.

### Step 5: README

Add to "Making a catboy": the maker panel (Studio play test, owner only, press M), what each section
does, and that the result is pasted into Config by hand. Mention `shirt` / `pants` as look overrides.

## Test plan

- Lune: `tests/CreatureEntry.spec.luau` (Step 2 cases) and the Config.spec changes (Steps 1–2).
- Studio (reviewer, via Studio MCP): start a play test; press M (`user_keyboard_input`); search
  Bundles "" with Roblox only → results with thumbnails; click Denny → rig appears in front of the
  player within a few seconds; add Kitty Ears (Hats "kitty") → rig updates; remove one bundle
  accessory → it goes; pick a shirt → rig wears it; set skin and move the height slider → rig updates;
  fill details, Make entry → valid entry text in the box and Output. Screenshot each stage. Paste that
  text into a scratch Lune script (not Config) and run it through `CreatureEntry.validate` → `{}`.
  Bundle `999999999999` → status shows the failure reason, no crash.

## Done criteria

- [ ] `lune run tests/run` → all pass, CreatureEntry spec registered
- [ ] `selene src tests` → 0 errors; `stylua --check src tests` → exit 0
- [ ] Both luau-lsp type checks → no errors
- [ ] `git status` shows only in-scope files changed; `Config.Creatures` entries unchanged
- [ ] `grep -n "CatboyMakerPreview" src/server/Remotes.luau` → no match
- [ ] Studio checks in the Test plan done with screenshots (reviewer)

## STOP conditions

- `SearchCatalog` errors or asks for permission in the play-test client.
- `Players:CreateHumanoidModelFromDescription` rejects `desc.Shirt`/`desc.Pants` overrides on a bundle
  look (the shirt never shows on the rig).
- Lune has no `@lune/luau` `load` (round-trip test can't run), report, don't switch to string compares.
- Any change seems to need `Remotes.luau`, `Hud.luau` or `CatboysWindow.luau`.

## Maintenance notes

- The owner gate uses `game.CreatorId`; if the place moves to a group, `CreatorId` becomes the group id
  and the gate needs an explicit UserId list. "Play Here" local-server tests use negative UserIds, so
  the panel only appears in normal Play / Play Here solo tests.
- `CreatureEntry.validate` and `Config.spec`'s look checks overlap on purpose (the spec stays an
  independent guard). If the look shape grows, update `lookKeys`, `validate`, and `format`'s key order
  together.
- Scale slider ranges are the avatar-editor limits; NPC rigs accept others, but staying inside keeps
  rigs looking normal.
- Commits (reviewer): (1) shirt/pants overrides, (2) CreatureEntry + tests, (3) the panel + README.

## Verification (this session, after the executor)

Review the diff with `/ponytail-review`, rerun all Commands above, then run the Studio Test plan
through the Studio MCP with screenshots, and report anything not verified (the live-game "not Studio"
path can't be exercised in Studio; it's checked by reading the code).
