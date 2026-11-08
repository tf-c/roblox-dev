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
