# roblox-dev

General Roblox development: experiments, prototypes, and reusable Luau modules.

Working rules for Claude live in [CLAUDE.md](CLAUDE.md).

## Checks

Run all of these before calling a change done:

| Check | Command |
|---|---|
| Tests | `lune run tests/run` |
| Lint | `selene src tests` |
| Format | `stylua --check src tests` |
| Types (game code) | `rojo sourcemap default.project.json -o sourcemap.json` then `luau-lsp analyze --sourcemap=sourcemap.json --definitions=globalTypes.d.luau src` |
| Types (tests) | `luau-lsp analyze --platform=standard --ignore="tests/run.luau" src/shared tests` |

`globalTypes.d.luau` is gitignored; download it from the luau-lsp repo (`scripts/globalTypes.d.luau`) if it's missing. `tests/run.luau` is left out of the type check because it uses Lune's built-in `@lune/*` modules.

## Making a catboy

Add an entry to `Config.Creatures` in `src/shared/Config.luau` (the comment above it explains each field). One entry holds the name, rarity, income, the zones it spawns in, and its look.

Ids come from catalog URLs: the number in `roblox.com/bundles/<id>/...` for bundles, and in `roblox.com/catalog/<id>/...` for accessories and clothing.

To get an editable model, run this in the Studio command bar in edit mode:

```lua
require(game.ServerScriptService.Server.CreatureRigs).saveModel("pillow")
```

It saves the rig to `ServerStorage.CreatureModels.pillow`. A saved model overrides the Config look until you delete it from that folder, and the place needs saving (Ctrl+S) to keep it.

### The maker panel

In a Studio play test, the place owner can press M to open the catboy maker, a full-screen editor (it never exists in a live game or for other players). The catalog is on the left, a 3D preview of the catboy is in the middle (drag to spin, scroll to zoom), and the outfit and details are on the right. While it is open the game HUD is hidden and the character can't walk. Press M again to close it.

- Top row: "New catboy" starts blank, and any catboy name loads that Config entry into the editor. "Make entry" then prints a replacement entry to paste over the old one.
- Search (left): find Roblox-made bundles, accessories, shirts and pants in the catalog; click a result to put it on the rig.
- On the rig: what the rig wears now. Remove an item with its x, and restore removed ones from the Removed row.
- Skin and Scale: skin color swatches (or a hex code) and sliders for height, width, head, proportion and body type.
- Details: id, name, rarity, income, ears and hair color, and the zones with weights.
- Config entry: "Make entry" checks the details and prints a ready-to-paste entry in the panel and the Output window.

The preview updates as you edit. A hand-saved `ServerStorage.CreatureModels.<id>` still overrides the Config look in game, and the editor shows the Config look. The panel never writes files: paste the entry into `Config.Creatures` by hand. Besides `bundleId`, a look can take `shirt` and `pants` (classic clothing catalog ids) on top of any source.
