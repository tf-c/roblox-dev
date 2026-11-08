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
