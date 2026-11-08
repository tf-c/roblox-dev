# Catboys window and side HUD (UI slice 1)

Status: approved

## User goal

"Which catboys do I have, how rare are they, and what do they earn?" Today the only answer is walking to the plot. This slice adds a Catboys window opened from a side HUD column. It is optional: it never blocks throwing.

Decided with the owner:
- The side HUD shows **only buttons that work today**: Catboys, plus the existing Trowel and Plot upgrade buttons, restyled into one column. More buttons (inventory, rebirth, codes...) are added when their systems exist. No dead buttons.
- Previews are 3D: the server copies each built rig to `ReplicatedStorage.CreaturePreviews.<id>`, and the window clones it into a ViewportFrame.

Out of scope: equip, sell, lock, rename, levels, trading, saving. Each needs plan 004 (saving) or the economy layer first.

## Surfaces

### 1. Side HUD column (left edge, vertically centered)

Where the upgrade buttons already are (`Hud.luau`, x = 12 px, 64 px spacing). The order, top to bottom:

1. **Catboys**: icon, label "Catboys", and a small badge with the count (`2`).
2. **Trowel**: existing upgrade button, same behavior and text.
3. **Plot**: existing upgrade button, same behavior and text.

Style ("bold simulator"):
- Buttons are 56 x 56 px squares with rounded corners (12 px), a 3 px dark outline (`UIStroke`) and a bright fill. Their labels sit under the icon in a heavy font (`FredokaOne` or `GothamBlack`), 14 px, with a dark text stroke.
- On press, the button shrinks to 92% for 0.08 s, then springs back.
- Icons come from your Free Icon Pack and live in `Config.Icons` (`catboys`, `trowel`, `plot`). Until you give the ids, each button shows its label only, centered. Nothing breaks without them.
- Upgrade buttons keep the label they have today (price or "Max") under the icon.

### 2. Catboys window

A centered panel with a title bar and a scrolling grid of cards.

- **Title bar:** "Catboys" on the left, "2/3 slots" in the middle (plot count / slot count) and a close button (X, 44 x 44 px touch target) on the right.
- **Card** (one per plot slot, in slot order):
  - The 3D preview, about 70% of the card's height. The camera faces the catboy from the front, slightly above, framed to the model's bounding box. The model is static, with no rotation (it stays cheap on phones).
  - The name in bold ("Pillow").
  - A rarity pill colored from `Config.RarityColors`, in sentence case: "Common", "Rare", "Epic".
  - The income: "+1/s" (cash per second, from `Config.CreatureIncome`).
- Grid: `ScrollingFrame` + `UIGridLayout`, with 8 px padding between cards.

## Layout by screen size

| | Phone (portrait or landscape) | Tablet | Desktop |
|---|---|---|---|
| Panel | 92% width, max 75% height | 70% width, max 70% height | 560 x 440 px |
| Cards per row | 2 (portrait), 3 (landscape) | 3 | 4 |
| Card size | Square, fills the column | Square | 120 x 150 px |

- Use `UIAspectRatioConstraint` on the cards, and `UISizeConstraint` (max 560 x 440) on the panel.
- The panel stays inside `GuiService:GetGuiInset()` and the safe area: no content under the notch or the top bar.
- The side column never overlaps the bottom Train and Throw buttons. On short screens (height < 400 px), it shrinks to 48 px buttons.
- While the window is open, it covers the reveal text but **not the Train and Throw buttons**. The panel's bottom edge sits above them, so throwing still works with the window open.

## States

| State | When | What shows |
|---|---|---|
| Default | Plot has catboys | One card per catboy, then empty slots |
| Empty | Plot has 0 catboys | One line in the panel: "No catboys yet. Throw the yarn ball to find one." plus all empty-slot cards |
| Empty slot | Slot count > plot count | A dashed-outline card that reads "Empty slot" |
| Loading | The rig hasn't reached `ReplicatedStorage.CreaturePreviews` yet (first seconds after the server starts) | The card shows the creature's `color` as a soft rounded block in the preview area. The rig swaps in when it arrives, without reopening the window |
| Error | The rig failed to build (the server warned and is using the placeholder) | The same color block, permanently. No error text: the player doesn't need to know |
| Locked | Not used in this slice | No locked cards. Plot upgrades already show their price on the Plot button |

The window updates live. When a catboy lands on the plot, or replaces another one when the plot is full, the cards refresh while the window is open, and the Catboys badge count updates whether it is open or not.

## Interactions

- Tapping Catboys opens the window, and tapping it again closes it. The X button closes it too, and so does the gamepad B button. On desktop, the `C` key toggles it.
- Opening it plays a 0.15 s scale-up from 90%; closing has no animation.
- Cards do nothing when tapped in this slice; there's no hover effect, so nothing suggests they're tappable.
- Gamepad: when the window opens, focus moves to the close button; selection moves between cards.

## Copy rules

- No all-caps anywhere: "Catboys", "Common", "Empty slot", never "CATBOYS" or "EPIC".
- Player-facing text says **Catboy**, never unit, pet or critter. Code says Creature.
- All new strings go in `Config.Text` (`catboysTitle`, `catboysSlots = "%d/%d slots"`, `catboysEmpty`, `emptySlot`, `incomePerSecond = "+%d/s"`).

## Data the client needs (for the build plan)

- **Plot contents:** today the client only gets `PlotCount`. `PlayerState.sync` should also set a `PlotCreatures` attribute holding the ids in slot order, comma-joined (`"pillow,slipper"`). The slot count comes from the existing `plotSlotsLevel` attribute and `Config.Upgrades.plotSlots`.
- **Previews:** after `CreatureRigs` builds a rig (or finds a saved model in `ServerStorage.CreatureModels`), the server parents an anchored clone to `ReplicatedStorage.CreaturePreviews`, named after the creature id. If the build fails, nothing goes there, and the card stays in its error state.

## Verify (after build)

- `roblox-mobile-playtest`: phone portrait and landscape and tablet in the device emulator. Check that the window fits, nothing sits under the notch, and Throw can be tapped with the window open.
- Play: throw until the plot is full, then once more. The cards and the badge should update live, and the replace toast still shows.
- Screenshots of default, empty and loading (open the window within 2 s of the server starting).
