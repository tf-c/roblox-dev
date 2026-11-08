# Plan 008: Catboys window and side HUD column (UI slice 1)

> **Executor instructions**: Follow this plan step by step. Run every verification command and confirm
> the expected result before moving to the next step. If a STOP condition occurs, stop and report; do
> not improvise. Do NOT edit `plans/README.md` and do not commit; the reviewer does both. Use the
> `ponytail` skill for all coding: smallest change that fully solves each step.
>
> **Drift check (run first)**: `git diff --stat ccc753e..HEAD -- src tests`
> Expected: no output. If anything under `src/` or `tests/` changed, compare the "Current state"
> excerpts with the live code; on a mismatch, STOP.

## Status

- **Priority**: P1 · **Effort**: M · **Risk**: LOW-MED (client UI plus two small server additions)
- **Depends on**: plan 007 (DONE, commit `ccc753e`)
- **Category**: direction (UX layer, slice 1)
- **Planned at**: commit `ccc753e`, 2026-11-08
- **Design contract**: `design/features/catboys-window/design.md` (Status: approved). Read it before
  starting; this plan implements it. Where this plan is more specific, follow this plan.

## Context (why)

The core loop works (throw → catboy lands → collect → it earns on your plot). Players currently can't
see what they own without walking to the plot. The owner approved a design brief for a Catboys window
(cards with a 3D preview, name, rarity and income) opened from a restyled left-side HUD column. The
column holds only buttons that work today: Catboys, Trowel, and Plot. Two server gaps block it: the
client only knows the plot *count*, and the rigs live in server-only storage.

## Current state (verified at `ccc753e`)

Strict-mode Luau, Rojo: `src/shared` → `ReplicatedStorage.Shared`, `src/server` →
`ServerScriptService.Server`, `src/client` → client scripts (`Main.client.luau` is the entry).
Every module starts with `--!strict` and a one-to-three-line header comment. `src/shared/` is pure
Luau, no Roblox APIs (Lune tests it). `Config.luau` has no requires and stores colors as hex strings.
Vocabulary: **Creature** in code, **Catboy** in player text; never "unit", "pet" or "critter" in new
names (old `critter` names stay as they are). **No all-caps player text.**

- `src/client/Hud.luau` (198 lines): `Hud.create()` builds ScreenGui `SeedTossHud` (`IgnoreGuiInset =
  false`) with stats/toast/reveal labels, the timing meter, and two 120 px round buttons at bottom
  center (`BUTTON = 120`, `BOTTOM_GAP = 24`; meter sits at `-(BOTTOM_GAP + BUTTON + 20)` and is 40 px
  tall with a 22 px hint above). Upgrade buttons today, lines 109-125:
  ```lua
  local upgrades: { [string]: TextButton } = {}
  local count = #Config.UpgradeOrder
  for i, id in Config.UpgradeOrder do
  	local button = Instance.new("TextButton")
  	button.Name = "Upgrade_" .. id
  	-- Left middle: clear of the player list (top right) and the mobile thumbstick (bottom left).
  	button.AnchorPoint = Vector2.new(0, 0.5)
  	button.Position = UDim2.new(0, 12, 0.5, (i - (count + 1) / 2) * 64)
  	button.Size = UDim2.fromOffset(190, 56)
  	...
  ```
  Helpers to reuse: `corner(parent, radius)`, `label(name, parent)` (GothamBold, white, TextScaled).
  `bigButton` shows the stroke style (`UIStroke`, Thickness 3, `ApplyStrokeMode.Border`).
- `src/client/Main.client.luau` (70 lines): lines 34-59 `refresh()` sets the stats line, and for each
  upgrade sets `button.Text = "<name>: <text>\n<price> cash"`, `button.Visible = price ~= nil`, color
  `220,150,40` if affordable else `80,80,80`. Lines 61-70 connect `refresh` to Power/Cash
  `.Changed`, the `PlotCount` attribute and each `<id>Level` attribute; each upgrade button's
  `Activated` fires `remote("BuyUpgrade"):FireServer(id)`.
- `src/server/PlayerState.luau`: `State.plot: { [number]: string }` (slot → creature id). Slots fill
  first-free (`Plot.choose` in `src/shared/Plot.luau`) and are only ever replaced, never cleared, so
  `state.plot` is always a contiguous array. `PlayerState.sync(player)` (lines 67-89) sets
  leaderstats and attributes `HasPending`, `<id>Level`, and `PlotCount`. It runs after every plot
  change (`PlotService.place`) and every upgrade.
- `src/server/CreatureRigs.luau`: `local function build(creatureId)` calls
  `CreatureRigs.buildLook(def.look, def.name)`; on failure it warns
  `"CreatureRigs: <id>: <reason>; using the placeholder"` and returns; on success `rigs[creatureId]
  = model`. `CreatureRigs.preload()` does `task.spawn(build, creatureId)` per creature.
- `src/server/CritterVisual.luau`: `local function fromTemplate(creatureId)` (lines ~92-106) looks up
  `ServerStorage.CreatureModels.<id>`, returns `template:Clone()` if it is a Model with a
  PrimaryPart, otherwise warns once (`warned` table) and returns nil. `CritterVisual.make` uses
  `fromTemplate(id) or fromBundle(id) or placeholder(id)`. CritterVisual requires CreatureRigs (so
  CreatureRigs must NOT require CritterVisual: cycle).
- `src/shared/Config.luau`: `Config.Creatures[id] = { name, rarity, income, color, zones, look }`,
  `Config.CreatureIncome[id]`, `Config.RarityColors = { common = "#d9d9d9", rare = "#4aa3ff", epic =
  "#c45cff" }`, `Config.Text = { collectAction, pendingBlocked, wanderedOff, walkHint, plotReleased,
  plotReplaced }`, `Config.Upgrades.trowel.name = "Trowel"`, `Config.Upgrades.plotSlots.name =
  "Plot"`, `Config.UpgradeOrder = { "trowel", "plotSlots" }`.
- `src/shared/Upgrade.luau`: `Upgrade.value(ladder, level)`, `Upgrade.nextPrice(ladder, level)`
  (nil when maxed). Slot count = `Upgrade.value(Config.Upgrades.plotSlots, plotSlotsLevel)`.
- Tests: `tests/<Name>.spec.luau` returns `{ [caseName]: () -> () }`, uses `tests/assert.luau`
  (`Assert.eq(actual, expected, msg?)`, `Assert.truthy`). Pattern: `tests/Plot.spec.luau`. New spec
  files must be registered in `tests/run.luau`'s `specs` list.

## Commands

| Purpose | Command | Expected |
|---|---|---|
| Tests | `lune run tests/run` | `N passed, 0 failed` |
| Lint | `selene src tests` | `0 errors`, `0 warnings` |
| Format | `stylua --check src tests` (fix with `stylua src tests`) | no output, exit 0 |
| Types (game) | `rojo sourcemap default.project.json -o sourcemap.json` then `luau-lsp analyze --sourcemap=sourcemap.json --definitions=globalTypes.d.luau src` | only INFO/WARN lines, no errors |
| Types (tests) | `luau-lsp analyze --platform=standard --ignore="tests/run.luau" src/shared tests` | only INFO/WARN lines |

Use Bash for git (PowerShell has crashed on git before).

## Scope

**In scope**: `src/shared/Plot.luau`, `tests/Plot.spec.luau`, `src/shared/Config.luau`,
`src/server/PlayerState.luau`, `src/server/CreatureRigs.luau`, `src/server/CritterVisual.luau`,
`src/client/Hud.luau`, `src/client/Main.client.luau`, `src/client/CatboysWindow.luau` (create).

**Out of scope**: equip/sell/lock/rename/levels/trading/saving; any new remote; ThrowService,
PlotService, TrainService, MeterController, RevealController; the bottom Train/Throw buttons and
meter; `plans/`, `design/`, `.claude/`.

## Steps

### Step 1: Test first: `Plot.parseIds`

The server will send plot contents as a comma-joined string attribute. `string.split("", ",")`
returns `{ "" }`, not `{}`, so parsing needs a helper. Add to `tests/Plot.spec.luau`:
- `""` → `{}` (empty table, `#result == 0`)
- `"pillow"` → `{ "pillow" }`
- `"pillow,slipper"` → `{ "pillow", "slipper" }` (order kept)

**Verify**: `lune run tests/run` → the 3 new cases FAIL (function missing), all others pass.

### Step 2: Implement `Plot.parseIds(csv: string): { string }` in `src/shared/Plot.luau`

```lua
-- Creature ids from the PlotCreatures attribute ("pillow,slipper"), in slot order.
function Plot.parseIds(csv: string): { string }
	return if csv == "" then {} else string.split(csv, ",")
end
```
**Verify**: `lune run tests/run` → all pass (76 + 3 = 79).

### Step 3: Config additions (`src/shared/Config.luau`)

Add to `Config.Text` (sentence case, keep existing keys):
```lua
catboysTitle = "Catboys",
catboysSlots = "%d/%d slots",
catboysEmpty = "No catboys yet. Throw the yarn ball to find one.",
emptySlot = "Empty slot",
incomePerSecond = "+%d/s",
upgradeMax = "Max",
upgradePrice = "%d cash",
```
Add after `Config.UpgradeOrder`:
```lua
-- Side HUD icons (rbxassetid://...), keyed by "catboys" and upgrade id. Empty = text-only button.
Config.Icons = { catboys = "", trowel = "", plotSlots = "" }
```
Rarity names are shown by capitalizing the rarity id's first letter in the client
(`"common"` → `"Common"`); do not add a table for it.

**Verify**: tests and both type checks pass.

### Step 4: Send plot contents (`src/server/PlayerState.luau`)

In `PlayerState.sync`, next to `PlotCount`:
```lua
-- state.plot is contiguous (slots fill first-free and are only replaced), so concat keeps slot order.
player:SetAttribute("PlotCreatures", table.concat(state.plot :: { string }, ","))
```
Update the header comment's attribute list to include `PlotCreatures`.

**Verify**: game type check passes.

### Step 5: Publish previews to ReplicatedStorage (`CreatureRigs` + `CritterVisual`)

Goal: `ReplicatedStorage.CreaturePreviews.<creatureId>` holds a Model for each creature that has a
real look: the saved `ServerStorage.CreatureModels.<id>` if valid, else the built rig. Creatures with
neither get nothing (the client shows its color block).

1. Move the saved-model lookup from `CritterVisual.fromTemplate` into CreatureRigs as
   `CreatureRigs.saved(creatureId: string): Model?`. It returns the template itself (not a clone), and
   it keeps the validity check (a Model with a PrimaryPart) and the warn-once message exactly. Move the
   `warned` table with it. In CritterVisual, replace `fromTemplate` with:
   ```lua
   local function fromTemplate(creatureId: string): Model?
   	local template = CreatureRigs.saved(creatureId)
   	return if template then template:Clone() else nil
   end
   ```
   Remove `ServerStorage` from CritterVisual if it is no longer used (selene will flag it).
2. In CreatureRigs, create the folder synchronously at the start of `preload()` (before spawning):
   `Folder` named `CreaturePreviews`, parented to `ReplicatedStorage` (reuse it if it already exists).
3. Change `build(creatureId)` so it always ends by publishing:
   ```lua
   local function build(creatureId: string)
   	local def = Config.Creatures[creatureId]
   	local model, reason = CreatureRigs.buildLook(def.look, def.name)
   	if model then
   		rigs[creatureId] = model
   	else
   		warn("CreatureRigs: " .. creatureId .. ": " .. reason .. "; using the placeholder")
   	end
   	local source = CreatureRigs.saved(creatureId) or model
   	if source then
   		local preview = source:Clone()
   		preview.Name = creatureId
   		for _, inst in preview:GetDescendants() do
   			if inst:IsA("BasePart") then
   				inst.Anchored = true
   			elseif inst:IsA("Humanoid") then
   				inst.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
   			elseif inst:IsA("Script") or inst:IsA("LocalScript") then
   				inst:Destroy()
   			end
   		end
   		preview.Parent = previewFolder
   	end
   end
   ```
   (`previewFolder` is the module-level local set in `preload`.) Update the module header comment
   with one line: "Also publishes a preview copy to ReplicatedStorage.CreaturePreviews for the
   Catboys window."

**Verify**: lint and game type check pass. `grep -n "CreatureModels" src/server/CritterVisual.luau`
→ only in comments.

### Step 6: Side HUD column (`src/client/Hud.luau`)

Replace the upgrade-button loop (lines 109-125) with one left column. Remove nothing else.

- `local column = Instance.new("Frame")`, Name `SideColumn`, transparent, `AnchorPoint (0, 0.5)`,
  `Position UDim2.new(0, 12, 0.5, 0)`, `Size UDim2.fromOffset(56, 0)`, `AutomaticSize = Enum.AutomaticSize.Y`.
  A `UIListLayout` (vertical, `Padding = UDim.new(0, 8)`, `SortOrder = LayoutOrder`), and a
  `UIScale` named `Scale`.
- A local `sideButton(name, text, icon, order)` that builds a 56 x 76 transparent `Frame` holding:
  - a `TextButton` named `Button`, 56 x 56 at the top: `corner(_, 12)`, a `UIStroke` with Thickness 3
    and color `#1e1e28`, `BackgroundColor3` `80,80,80`, `Font GothamBlack`, white text with
    `TextStrokeTransparency 0`, `TextScaled`, and a `UIPadding` of 6. If `icon ~= ""`: the button text
    is `""` and it gets a child `ImageLabel` (transparent, Size 0.8 scale, centered, `Image = icon`).
    Otherwise the button text is `text`.
  - a `TextLabel` named `Caption`, built with `label()`, at y = 58, 56 x 16, `TextStrokeTransparency 0`.
  - A press squish: give the button a `UIScale`. On `Activated`, tween its Scale to 0.92 over 0.08 s,
    then back to 1 over 0.08 s.
  - It returns `(button, caption)`.
- Order: Catboys first (`LayoutOrder 1`, text `Config.Text.catboysTitle`, icon `Config.Icons.catboys`,
  bright fill `255,140,60`), then each `Config.UpgradeOrder` id (`LayoutOrder 1 + i`, text
  `Config.Upgrades[id].name`, icon `Config.Icons[id]`).
- The Catboys button gets a badge: a `TextLabel` named `Badge`, 22 x 22, `AnchorPoint (0.5, 0.5)` at
  the top-right corner (`Position UDim2.fromScale(1, 0)`), red fill `220,60,60`, round
  (`corner(_, 11)`), white GothamBlack text. It shows the plot count. Its caption is
  `Config.Text.catboysTitle`.
- Short screens: a function sets `column.Scale.Scale = if viewport.Y < 400 then 48 / 56 else 1`. Call
  it once, and on `workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize")`.
- Hud type changes: `upgrades: { [string]: { button: TextButton, caption: TextLabel } }`, and new
  fields `catboysButton: TextButton`, `catboysBadge: TextLabel`. Update the returned table. Change the
  module header's first line to "Core-loop HUD: stats, meter, Train/Throw, and the left side column."

**Verify**: lint, format, and game type check pass. Main.client.luau type errors on `hud.upgrades`
are expected until Step 8.

### Step 7: Catboys window (`src/client/CatboysWindow.luau`, new)

Header: `--!strict` plus "Catboys window: one card per plot slot with a 3D preview, name, rarity and
income. Opened from the side column; never blocks throwing."

API:
```lua
export type Window = { frame: Frame, closeButton: TextButton, refresh: () -> () }
function CatboysWindow.create(parent: ScreenGui): Window
function CatboysWindow.toggle(window: Window)
```
Build (all names as given so the reviewer can find them):
- `frame` named `CatboysWindow`, `Visible = false`, fill `30,30,40`, `corner 16`, a 3 px `UIStroke` in
  `#1e1e28`, `AnchorPoint (0.5, 0)`, `Position UDim2.new(0.5, 40, 0, 8)`, `Size UDim2.new(1, -104, 1,
  -238)`, and a `UISizeConstraint` with `MaxSize (560, 440)`. The 40/104 keep it clear of the side
  column (x 12-68). The -238 keeps the bottom edge above the meter, the hint and the Train/Throw
  buttons (24 + 120 + 20 + 40 + 26 + 8). Give it a `UIScale` for the open animation.
- Title bar, 44 px tall:
  - `Title`: `Config.Text.catboysTitle`, left side, GothamBlack.
  - `Slots`: `string.format(Config.Text.catboysSlots, count, slots)`, centered.
  - `Close`: a `TextButton` showing "X", 44 x 44, on the right, red fill `220,60,60`, corner 10.
- `Empty` label under the title bar, 24 px tall, showing `Config.Text.catboysEmpty`. Visible only when
  the plot has 0 catboys.
- `Grid`: a `ScrollingFrame` filling the rest of the frame (below the title bar, and below the empty
  label when it shows). Set `AutomaticCanvasSize = Y`, `CanvasSize = 0`, scrollbar 6, transparent.
  Inside it: a `UIGridLayout` (`CellPadding 8, 8`, `SortOrder = LayoutOrder`) and a `UIPadding` of 8.
- Columns: on the grid's `AbsoluteSize` change (and once at create), `cols = if w < 300 then 2 elseif w
  < 460 then 3 else 4`. Then cell width = `(w - 16 - 8 * (cols - 1)) / cols` and `CellSize =
  UDim2.fromOffset(cellW, cellW * 1.25)`.
- `refresh()`: read `Plot.parseIds(player:GetAttribute("PlotCreatures") or "")` and `slots =
  Upgrade.value(Config.Upgrades.plotSlots, player:GetAttribute("plotSlotsLevel") or 0)`. Destroy the
  old cards. For each slot `1..slots`:
  - **Filled slot** (an id at that index): a `Frame` card, fill `45,45,60`, corner 12, `Selectable =
    true`, `LayoutOrder = slot`, holding:
    - **Preview area** (top 70%): a rounded Frame filled with `Color3.fromHex(def.color)`, which is the
      loading/error color block. If `previews:FindFirstChild(id)` exists, add a transparent
      `ViewportFrame` on top. Clone the model into it, add a `Camera` (`FieldOfView = 30`) and set it
      as `CurrentCamera`. Frame it:
      `local cf, size = model:GetBoundingBox(); local front = (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")).CFrame.LookVector; local dist = size.Y / 2 / math.tan(math.rad(15)) * 1.15; cam.CFrame = CFrame.lookAt(cf.Position + front * dist + Vector3.new(0, size.Y * 0.1, 0), cf.Position)`.
      If the model has neither a PrimaryPart nor a BasePart, leave only the color block.
    - **Name**: `def.name`, GothamBlack.
    - **Rarity pill**: a rounded Frame filled with `Color3.fromHex(Config.RarityColors[def.rarity])`.
      Its text is the rarity with the first letter capitalized
      (`def.rarity:sub(1, 1):upper() .. def.rarity:sub(2)`), in dark text.
    - **Income**: `string.format(Config.Text.incomePerSecond, def.income)`.
  - **Empty slot**: a `Frame` card, transparent fill, 2 px `UIStroke` in `#8a8a99`, corner 12, and a
    centered label showing `Config.Text.emptySlot`. (Roblox has no dashed stroke; a thin grey outline
    stands in for the brief's "dashed".)
  - Update `Slots` and the visibility of `Empty`.
- Live updates inside `create`: run `refresh` on `player:GetAttributeChangedSignal("PlotCreatures")`,
  on `("plotSlotsLevel")`, and on `previews.ChildAdded`. Get `previews` with
  `ReplicatedStorage:WaitForChild("CreaturePreviews")` inside a `task.spawn`, so `create` never
  yields. Until it arrives, refresh treats every preview as missing.
- `toggle(window)`: flip `frame.Visible`. When opening:
  - set `UIScale.Scale = 0.9` and tween it to 1 over 0.15 s (Quad Out);
  - if `UserInputService.GamepadEnabled`, set `GuiService.SelectedObject = closeButton`;
  - bind ContextActionService action `"CloseCatboys"` to `Enum.KeyCode.ButtonB`, which closes the
    window.

  When closing, unbind that action and clear `SelectedObject` if it is inside the frame. The Close
  button calls `toggle`.

**Verify**: lint, format, and game type check pass (Main errors may remain until Step 8).

### Step 8: Wire it in (`src/client/Main.client.luau`)

- Require `CatboysWindow`. After `Hud.create()`: `local catboys = CatboysWindow.create(hud.gui)`.
  `hud.catboysButton.Activated:Connect(function() CatboysWindow.toggle(catboys) end)`.
- `C` key: `UserInputService.InputBegan:Connect(function(input, processed) if not processed and
  input.KeyCode == Enum.KeyCode.C then CatboysWindow.toggle(catboys) end end)`.
- In `refresh()`:
  - Set `hud.catboysBadge.Text = tostring(PlotCount)`.
  - Replace the upgrade-button block. For each `id, entry in hud.upgrades`: the button stays visible.
    If `price ~= nil`: `entry.caption.Text = string.format(Config.Text.upgradePrice, price)`, and
    `entry.button.BackgroundColor3` is orange `220,150,40` when affordable, else grey `80,80,80`
    (same as today). If maxed: caption is `Config.Text.upgradeMax`, the button is grey, and
    `entry.button.Active = false`.
  - Keep the stats line as is.
- `Activated` wiring uses `entry.button`. Update the header comment to mention the Catboys window.

**Verify**: all five checks pass, and `lune run tests/run` → 79 passed.

### Step 9: Final checks

Run all five commands from the table. `git status --short` should show only in-scope files (plus the
reviewer's untouched `.claude/`, `plans/` and `design/` changes). Report the output of each command.

## Test plan

- Automated: `Plot.parseIds` (3 cases, Step 1). Everything else is Roblox UI and is verified in
  Studio by the reviewer (below). Do not add tests for layout code.
- Reviewer's Studio checks (not the executor's):
  1. Play solo. Within 2 s of start, open the window: the cards show color blocks, which swap to rigs
     without reopening.
  2. Throw until the plot is full, then once more. Cards and the badge update live, and the replace
     toast still shows.
  3. The empty state on a fresh join shows the empty line and 3 empty-slot cards.
  4. Device emulator (phone portrait and landscape, tablet) via `roblox-mobile-playtest`: the window
     doesn't overlap the side column, the notch, or Train/Throw. Throw stays tappable with the window
     open.
  5. Buy a Plot upgrade with the window open: the slots count and the empty cards update. A maxed
     upgrade shows "Max".
  6. Screenshot default, empty and loading.

## Done criteria

- `lune run tests/run` → `79 passed, 0 failed`.
- selene shows 0 errors and 0 warnings; `stylua --check` is clean; both luau-lsp runs show no errors.
- `grep -rn "Upgrade_\|190, 56" src/client` → no matches (the old upgrade buttons are gone).
- `grep -rnE '"[A-Z ]{4,}"' src/client src/shared/Config.luau` → no all-caps player strings.

## STOP conditions

- The drift check shows changes to an in-scope file whose excerpt no longer matches.
- Removing `fromTemplate`'s lookup from CritterVisual would need CreatureRigs to require CritterVisual
  (a require cycle).
- `state.plot` turns out to have gaps (some code sets a slot to nil): the concat in Step 4 would then
  be wrong.
- Any step seems to need a new RemoteEvent, or a change to ThrowService or PlotService.

## Maintenance notes

- New side buttons (inventory, rebirth...) go through `sideButton` with the next `LayoutOrder` and a
  `Config.Icons` key, only once their system exists.
- When saving (plan 004) lands, `PlotCreatures` stays the client's source of truth for the window. If
  the plot ever allows clearing a slot, switch the attribute to a format that keeps gaps, and update
  `Plot.parseIds` and its tests.
- Saved models in `ServerStorage.CreatureModels` publish as previews only after the rig build attempt
  finishes (a few seconds after start). That's acceptable: the card shows its color block until then.

## Reviewer follow-up (me, after the executor)

Copy this plan to `plans/008-catboys-window.md` and add row 008 to `plans/README.md`. Review the diff
with `/ponytail-review`. Run the Studio checks above, then commit with a message like "Add the
Catboys window and side HUD column".
