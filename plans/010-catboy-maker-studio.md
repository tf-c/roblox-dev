# Plan 010: Turn the catboy maker into a full-screen editor with a 3D preview, and let it edit existing catboys

> **Executor instructions**: Follow this plan step by step. Run every verification command and confirm
> the expected result before moving on. If a STOP condition occurs, stop and report; do not improvise.
> Do NOT edit `plans/README.md`, do not commit, and do not touch anything under `.claude/`. Use the
> `ponytail` skill for all coding. Write the Step 1 test BEFORE any code and run it once.
>
> **Drift check (run first)**: `git diff --stat 75d4e4c..HEAD -- src tests`
> Expected: no output. If anything changed, compare the "Current state" notes with the live code; on a
> mismatch, STOP.

## Status

- **Priority**: P2 · **Effort**: M · **Risk**: LOW (dev-only, Studio + owner gated, no gameplay code)
- **Depends on**: plan 009 (DONE, commit `75d4e4c`)
- **Category**: dx (content tool)
- **Planned at**: commit `75d4e4c`, 2026-11-08

## Why this matters

Plan 009 shipped the catboy maker as a 380 px side panel, with the preview rig standing in the world in
front of the player. The owner wants it to feel like an avatar-creator dressing room: a full-screen
editor whose centerpiece is a big live 3D preview you can spin and zoom, and the ability to open any
catboy already in `Config.Creatures`, change it, and print the updated entry. It's a common avatar-editor
layout, not a copy of any specific game.

## Decisions made with the owner (do not revisit)

- **Full-screen editor mode**: M opens/closes it. While open, the game HUD (`PlayerGui.SeedTossHud`)
  is hidden and the character can't walk. Closing restores both.
- **Live 3D preview inside the UI** (a `ViewportFrame`) replaces the rig standing in the world. Drag to
  spin, mouse wheel to zoom, a "Reset view" button.
- **Edit existing catboys**: a row of catboy names (plus "New catboy") loads that entry's look and details
  into the editor. "Make entry" prints the full replacement entry for the owner to paste over the old
  one by hand. The tool still never writes files.
- Still in force: Studio + owner only (server-checked), text output only, no all-caps UI text, "Catboy"
  in UI text and "Creature" in code, Roblox-only search on by default, every look fully clothed.

## Current state (verified at `75d4e4c`)

Strict Luau, Rojo. `src/shared` → `ReplicatedStorage.Shared`, `src/server` →
`ServerScriptService.Server`, `src/client` → `StarterPlayerScripts.Client`.

- `src/server/CatboyMaker.luau` (~105 lines). `init()` creates RemoteEvent
  `ReplicatedStorage.CatboyMakerPreview` only when `RunService:IsStudio()`. `add(player)` sets attribute
  `CatboyMaker = true` when `player.UserId == game.CreatorId`. `onPreview(remote, player, look)`:
  gate check, then a per-player `generation` counter (only the newest build wins), then
  `pcall(CreatureRigs.buildLook, look, RIG_NAME)`. On success it destroys `Workspace.CatboyMakerRig`,
  anchors parts and hides the Humanoid name, then `placement(player)` and `CritterVisual.restingPivot`
  put it 8 studs in front of the player, parented to Workspace. It replies
  `remote:FireClient(player, true, ids)` (accessory asset ids from
  `humanoid:GetAppliedDescription():GetAccessories(true)`), or `(false, reason)` on failure.
- `src/client/CatboyMaker.luau` (~705 lines). `init()` waits for the attribute and the remote, then
  `build(player, remote)`. Inside `build`:
  - Local widget helpers: `corner`, `layout`, `label`, `button`, `textbox`, `row`, `setOn`, `clear`,
    `thumb`, `chip`.
  - State: `look = { bundleId, shirt, pants, skinColor, accessoryIds, removeAccessoryIds, scale }`,
    `rigIds`, `rarity`, `zonesOn`, `weights`. `lookTable()` builds the look to send.
    `changed()` re-renders the chips and, after a 0.3 s debounce, sends `remote:FireServer(lookTable())`.
    It shows "Pick a bundle to start" when `look.bundleId` is nil.
  - One `panel` Frame (380 px wide, top-right) holding a title, an X close button, and one
    `ScrollingFrame` `scroll`. `section(heading)` adds a section to `scroll`. The six sections in order
    are Search, On the rig, Skin, Scale, Details, Config entry.
  - Scale sliders: per field, a local `show(value)` sets `look.scale[field]` and the knob. A reset
    button marked "x".
  - Details: `idBox`, `idNote` ("Replaces the existing <name>"), `nameBox`, rarity buttons
    (`showRarity()`), `incomeBox`, `colorBox` + preview, and one row per `Config.Zones` entry: a toggle
    button (local `box`) and a weight textbox whose FocusLost writes `weights[zone.id]`.
  - Make entry: builds `entry`, runs `CreatureEntry.validate`, then shows
    `CreatureEntry.format(idBox.Text, entry)` in the output TextBox and prints it.
  - The M key (only when `not processed`) toggles `panel.Visible`.
- `src/shared/CreatureEntry.luau`: `validate(id, entry, zoneIds)` and `format(id, entry)`. `format`
  errors on `manual` looks. It already prints `outfitId`.
- `tests/CreatureEntry.spec.luau`: round-trip cases use `(require :: any)("@lune/luau").load(...)` and a
  local `deepEq`. Reuse both.
- `src/client/CatboysWindow.luau:60-82` `addViewport(area, source)`: frames a model with FOV 30,
  distance `size.Y / 2 / math.tan(math.rad(15)) * 1.15`, looking at the bounding-box center from the
  front (`part.CFrame.LookVector`). Copy this math; don't import it (it's local there and out of scope).
- Game hotkeys while the editor is open: C (`Main.client.luau:29`), Q (`TrainController.luau:50`),
  E (`MeterController.luau:51`). They still fire, because they only skip when `processed`. That's
  accepted for a dev tool; don't change those files.

## Commands you will need

| Purpose | Command | Expected |
|---|---|---|
| Tests | `lune run tests/run` | all pass |
| Lint | `selene src tests` | 0 errors |
| Format | `stylua --check src tests` | exit 0 (fix with `stylua src tests`) |
| Types (game) | `rojo sourcemap default.project.json -o sourcemap.json` then `luau-lsp analyze --sourcemap=sourcemap.json --definitions=globalTypes.d.luau src` | no errors |
| Types (tests) | `luau-lsp analyze --platform=standard --ignore="tests/run.luau" src/shared tests` | no errors |

Run them with the Bash tool (Git Bash), not PowerShell.

## Scope

**In scope**: `src/client/CatboyMaker.luau`, `src/server/CatboyMaker.luau`,
`tests/CreatureEntry.spec.luau`, `README.md` ("The maker panel" subsection).

**Out of scope**: `Hud.luau`, `CatboysWindow.luau`, `MeterController.luau`, `TrainController.luau`,
`Main.client.luau`, `CreatureRigs.luau`, `CreatureEntry.luau` (no change should be needed; if one is,
STOP), any `Config.Creatures` entry, mobile layout, and writing files from the tool.

## Steps

### Step 1: Test that every existing catboy can be loaded and printed back

In `tests/CreatureEntry.spec.luau`, add the case "every Config creature round-trips through format".
For each `id, def` in `Config.Creatures` (require `../src/shared/Config`), load
`format(id, def)` with the existing load helper and `deepEq` it against `def`. Also assert
`#CreatureEntry.validate(id, def :: any, zoneIds) == 0`, with `zoneIds` taken from `Config.Zones`.
It should pass right away, since all six starters use `bundleId` looks. It guards the editor's "load,
then print" path against future Config entries the tool can't print.

**Verify**: `lune run tests/run` → all pass (86).

### Step 2: Server builds the preview rig into ReplicatedStorage, not the world

In `src/server/CatboyMaker.luau`:
- Remove `placement`, the `CritterVisual` require, `FRONT_STUDS`, and the Workspace parenting.
- On success: destroy any existing `ReplicatedStorage.CatboyMakerRig`. Keep the anchor and
  hide-name loop. `model:PivotTo(CFrame.new())`. Set `model:SetAttribute("Build", mine)`, where
  `mine` is the generation number. Parent it to `ReplicatedStorage`.
- Reply `remote:FireClient(player, true, ids, mine)`. The added 4th argument is the build number.
  Failure replies stay as they are.
- Update the header comment: the rig goes to `ReplicatedStorage.CatboyMakerRig` for the editor's 3D
  preview, and exists only in Studio.

**Verify**: both type checks and selene are clean, and `grep -n "Workspace" src/server/CatboyMaker.luau`
has no matches.

### Step 3: Full-screen layout

Restructure `build` in `src/client/CatboyMaker.luau`. Keep every widget helper and all the state and
section logic. Change only where each piece is parented, plus the additions below.

- ScreenGui `CatboyMakerGui`: `IgnoreGuiInset = true`, `DisplayOrder = 10`, `ResetOnSpawn = false`.
- `root` Frame: full screen, `BackgroundColor3 = Color3.fromRGB(27, 27, 38)`, `Visible = false`,
  `Active = true` (so clicks don't reach the world).
- **Top bar** (height 52, `FIELD`-colored strip):
  - "Catboy maker" title on the left (GothamBlack 22).
  - Then a horizontal `ScrollingFrame` (`ScrollingDirection = X`, `AutomaticCanvasSize = X`), the
    **catboy row**: a "New catboy" button, then one button per `Config.Creatures` id sorted by
    display name, each labeled with the name. The loaded one is highlighted with `setOn`.
  - The 44 px red X close button on the right.
- **Left column** (`Position (0, 12, 0, 64)`, `Size (0, 360, 1, -76)`, `PANEL` color, 16 px corner): a
  `ScrollingFrame` with the **Search** section only.
- **Right column** (anchored right, same size and style): a `ScrollingFrame` with the **On the rig**,
  **Skin**, **Scale**, **Details** and **Config entry** sections, in that order.
- **Center**: a `ViewportFrame` filling the space between the columns
  (`Position (0, 384, 0, 64)`, `Size (1, -768, 1, -76)`), 16 px corner, a vertical `UIGradient` from
  `#3a3a55` (top) to `#1e1e2c` (bottom), `Ambient = Color3.fromRGB(200, 200, 210)`,
  `LightDirection = Vector3.new(-1, -1, -1)`. Overlays on the viewport:
  - The status label at the top center, moved here from "On the rig". Same texts: "Pick a bundle to
    start", "Building...", "Ready", or the error in red.
  - A hint "Drag to spin, scroll to zoom" at the bottom center.
  - A "Reset view" button at the bottom right.
- `section(heading)` becomes `section(scrollParent, heading)`.

Opening and closing are one `setOpen(open: boolean)` function:
- `root.Visible = open`.
- The HUD: `local hud = playerGui:FindFirstChild("SeedTossHud")`, and if it's a ScreenGui,
  `hud.Enabled = not open`.
- Controls: `require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()`,
  fetched once, then `:Disable()` when opening and `:Enable()` when closing. Wrap the require in
  `pcall`; if it fails, skip the freeze and carry on.
- M toggles `setOpen(not root.Visible)`, still only when `not processed`. The X button calls
  `setOpen(false)`.

**Verify**: type checks, selene and stylua are clean.

### Step 4: Live 3D preview

In the client, after an `ok` reply `(true, ids, buildNumber)`:
1. `local rig = ReplicatedStorage:WaitForChild("CatboyMakerRig", 5)`. If it's nil, or
   `rig:GetAttribute("Build") ~= buildNumber`, return (a newer build is on the way).
2. Destroy the previous preview clone in the viewport. Clone `rig` into the viewport.
3. Frame it with the `addViewport` math from `CatboysWindow.luau:75-80`. Keep
   `center = boundingBox.Position` and `baseDistance` (the formula from Current state), plus orbit
   state `yaw` (radians) and `zoom` (multiplier). Keep both across rebuilds, so editing doesn't reset
   the view. The camera (`FieldOfView = 30`, made once and set as `viewport.CurrentCamera`) goes at
   `CFrame.lookAt(center + Vector3.new(math.sin(yaw), 0.15, math.cos(yaw)).Unit * baseDistance * zoom, center)`.
   The rig faces -Z after `PivotTo(CFrame.new())`; if the first screenshot shows its back at
   `yaw = 0`, use `yaw = math.pi` as the default instead. That's a one-constant fix, not a STOP.
4. Spin: on `viewport.InputBegan` with MouseButton1 or Touch, set `dragging = true`. On
   `UserInputService.InputChanged` with MouseMovement while dragging,
   `yaw -= input.Delta.X * 0.01`. On InputEnded, set `dragging = false`. Reuse `isPress`.
5. Zoom: on `viewport.InputChanged` with `UserInputType.MouseWheel`,
   `zoom = math.clamp(zoom - input.Position.Z * 0.1, 0.5, 2)`.
6. "Reset view" sets `yaw` to the default and `zoom = 1`.
7. Re-place the camera after each change (one local `placeCamera()`).

**Verify**: type checks, selene and stylua are clean.

### Step 5: Load existing catboys

- Extend the state with `outfitId = nil :: number?`. `lookTable()` includes it. Picking a bundle sets
  `look.outfitId = nil`. `changed()` treats "has a source" as `look.bundleId or look.outfitId`. Add an
  "outfit <id>" chip with x when `outfitId` is set; there is no outfit thumbnail, so use `thumb("Asset", id)`
  or an empty image.
- Keep handles to the widgets that loading must set: the slider `show` functions keyed by field
  (`sliderShow[field] = show`), and each zone's toggle button and weight textbox keyed by zone id.
- `load(id: string?)`:
  - `nil` → **New catboy**: clear the look (empty lists, empty scale, all ids nil), reset every
    slider with `show(nil)`, clear the id/name/income/color boxes, set rarity to "common", and turn
    off every zone and clear its weight.
  - An id → `local def = Config.Creatures[id]`. If `def.look.manual`, set the status (red)
    "<name> uses a manual look. Edit it in Config by hand." and stop. Otherwise **copy, never alias**
    (`table.clone` on `accessoryIds`, `removeAccessoryIds` and `scale`, or `{}` when missing), so edits
    never change the live `Config.Creatures` table. Copy `bundleId`, `outfitId`, `shirt`, `pants` and
    `skinColor`. Call `sliderShow[field](def.look.scale and def.look.scale[field])` for each field.
    Then set `idBox.Text = id`, the name, `rarity = def.rarity` plus `showRarity()`, the income, and
    the color. For each zone, turn it on with the weight text from `def.zones[zone.id]`, or off with a
    cleared weight. Update the toggle button text and color the same way its click handler does.
  - Both cases: highlight the matching button in the catboy row, clear the problems label, hide the
    output box, and call `changed()`.
- Wire the "New catboy" button and the per-catboy buttons to `load`.

**Verify**: type checks, selene and stylua are clean, and `lune run tests/run` passes.

### Step 6: README

Update "The maker panel" subsection:
- M opens a full-screen editor: catalog on the left, 3D preview in the middle (drag to spin, scroll to
  zoom), outfit and details on the right.
- The top row loads any existing catboy; "Make entry" then prints a replacement entry to paste over
  the old one.
- A hand-saved `ServerStorage.CreatureModels.<id>` still overrides the Config look in game, and the
  editor shows the Config look.

## Test plan

- Lune: the Step 1 case.
- Studio (the reviewer does this through the Studio MCP and takes screenshots). Start a play test and
  press M:
  - The editor fills the screen, the game HUD is gone, and WASD doesn't move the character.
  - Click "Pillow": the preview shows Pillow's look (Denny with Kitty Ears and an orange tail), and the
    Details show its name, rarity, income, color and zones.
  - Drag on the preview: the rig spins. Scroll: it zooms. Reset view: it goes back.
  - Add a hat from search: the preview updates and the view stays where it was.
  - Make entry: the text shows `pillow = {` with the hat added. Compare `Config.Creatures.pillow`
    before and after: it is unchanged (no aliasing).
  - Click "New catboy": everything clears.
  - Press M: the HUD returns and the character can walk again.
  - `workspace:FindFirstChild("CatboyMakerRig")` is nil.

## Done criteria

- [ ] `lune run tests/run` → all pass (86)
- [ ] `selene src tests` → 0 errors; `stylua --check src tests` → exit 0
- [ ] Both luau-lsp type checks → no errors
- [ ] `git status` shows only the four in-scope files changed (plus the plan files the reviewer adds)
- [ ] The Studio checks in the Test plan pass, with screenshots (reviewer)

## STOP conditions

- The rig doesn't replicate to the client in ReplicatedStorage within 5 s, or the clone renders
  without accessories in the ViewportFrame.
- `PlayerModule` isn't found and movement can't be frozen any other way inside the in-scope files.
- Step 1 fails for an existing catboy, meaning a Config entry the tool can't print.
- Any step seems to need an out-of-scope file.

## Maintenance notes

- `ReplicatedStorage.CatboyMakerRig` replicates to every client, which is fine because it exists only in
  Studio play tests. Don't reuse this pattern for live-game content.
- Loading a catboy copies its Config tables. Any new look list field must be cloned in `load` too, or
  edits will change the live Config table for the rest of the play test.
- The C/Q/E game hotkeys still work while the editor is open; that's accepted for a dev tool.
- Desktop only. The two 360 px columns need a window at least ~1100 px wide for the preview to stay
  useful.
- Commit as one behavior change: "Make the catboy maker a full-screen editor that can load existing
  catboys".

## Review notes (2026-11-08)

- Freeze: `ControlModule:Disable()` did not stop movement in the play test, so `setOpen` saves the
  Humanoid's `WalkSpeed` and `JumpHeight`, sets them to 0 while open, and restores them on close.
- Spin uses the change in mouse position, not `input.Delta` (Delta was 0 for the test tool's mouse).
- Preview framing uses 1.4x the fit distance (not 1.15x) so the status and hint text clear the model.
