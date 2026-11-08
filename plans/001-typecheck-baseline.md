# Plan 001: Make the type check pass on src and tests with one documented command

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report, do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 9ef9f70..HEAD -- tests/Distance.spec.luau README.md`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: dx
- **Planned at**: commit `9ef9f70`, 2026-11-08

## Why this matters

The repo's CLAUDE.md requires "Run the type checker and linter, and fix all errors" before any task is done, but no command for the type checker is written down anywhere, and the obvious way to check the tests fails with 5 errors. Two of those are real type errors in a test file. Every later plan uses this type check as a verification gate, so it has to pass cleanly first.

## Current state

This is a Roblox game in strict Luau (`.luaurc` sets `"languageMode": "strict"`). Tools are pinned in `rokit.toml`: rojo 7.7.1, lune 0.11.1, selene 0.32.0, stylua 2.6.0, luau-lsp 1.70.1.

- `src/`, game code. `src/shared/` is pure Luau (no Roblox APIs) so Lune can test it; `src/server/` and `src/client/` use Roblox APIs.
- `tests/*.spec.luau`, Lune unit tests for `src/shared/`. `tests/run.luau` is the runner (`lune run tests/run`); it requires `@lune/fs` and `@lune/process`, which only resolve inside Lune.
- `globalTypes.d.luau` and `sourcemap.json` exist at the repo root and are gitignored (`.gitignore` lines "sourcemap.json" and "globalTypes.d.luau").

Type checking `src` against Roblox types already passes (verified at 9ef9f70):

```
luau-lsp analyze --sourcemap=sourcemap.json --definitions=globalTypes.d.luau src
```

Type checking the tests fails. Output at 9ef9f70 of
`luau-lsp analyze --platform=standard src/shared tests`:

```
tests/Distance.spec.luau(57,44): TypeError: Expected this to be 'string?', but got 'number'
tests/Distance.spec.luau(58,43): TypeError: Expected this to be 'string?', but got 'number'
tests/run.luau(5,12): TypeError: Unknown require: ...\tests\@lune\fs.lua
tests/run.luau(6,17): TypeError: Unknown require: ...\tests\@lune\process.lua
tests/run.luau(41,3): TypeError: Function only returns 1 value, but 2 are required here
```

The cause of the two real errors, `tests/Distance.spec.luau:56-59`:

```lua
	["timing is clamped to 0..1"] = function()
		Assert.eq(Distance.compute(50, -3, cfg), Distance.compute(50, 0, cfg))
		Assert.eq(Distance.compute(50, 7, cfg), Distance.compute(50, 1, cfg))
	end,
```

`Distance.compute` returns two values `(distance, mult)` (`src/shared/Distance.luau:45`). As the last argument, the second call expands to both values, so `mult` lands in `Assert.eq`'s third parameter `msg: string?` (`tests/assert.luau:13`). The test still passes at runtime, but it is a type error. Wrapping a call in parentheses keeps only its first value.

The three `tests/run.luau` errors happen because the type checker doesn't know Lune's built-in modules. The runner works under `lune run`, so leave it out of the static check instead of changing it.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Tests | `lune run tests/run` | last line `N passed, 0 failed`, exit 0 (45 passed at 9ef9f70) |
| Lint | `selene src tests` | `0 errors`, `0 warnings` |
| Format check | `stylua --check src tests` | exit 0, no output |
| Sourcemap (if missing) | `rojo sourcemap default.project.json -o sourcemap.json` | file written |
| Type check src | `luau-lsp analyze --sourcemap=sourcemap.json --definitions=globalTypes.d.luau src` | no `TypeError` lines |
| Type check tests | `luau-lsp analyze --platform=standard --ignore="tests/run.luau" src/shared tests` | no `TypeError` lines |

If `globalTypes.d.luau` is missing, download it from `https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau` into the repo root. It's gitignored, so never commit it.

## Scope

**In scope** (the only files you should modify):
- `tests/Distance.spec.luau` (lines 57–58 only)
- `README.md` (add a "Checks" section)

**Out of scope** (do NOT touch):
- `tests/run.luau`: it works under Lune. Exclude it from the static check, don't edit it.
- `CLAUDE.md`: the owner's working rules. Don't edit it.
- `.claude/`: it has the owner's uncommitted changes.
- Any `src/` file.

## Git workflow

- Work on the current branch unless told otherwise. Commit message style matches `git log`: a plain imperative sentence, for example "Fix test type errors and document the check commands".
- Do NOT push.

## Steps

### Step 1: Fix the two multi-return type errors

In `tests/Distance.spec.luau`, wrap each `Distance.compute(...)` call on lines 57 and 58 in parentheses so only the distance is compared:

```lua
		Assert.eq((Distance.compute(50, -3, cfg)), (Distance.compute(50, 0, cfg)))
		Assert.eq((Distance.compute(50, 7, cfg)), (Distance.compute(50, 1, cfg)))
```

**Verify**: `luau-lsp analyze --platform=standard --ignore="tests/run.luau" src/shared tests` → no lines containing `TypeError`.
**Verify**: `lune run tests/run` → `45 passed, 0 failed`.

### Step 2: Confirm the src type check still passes

**Verify**: `luau-lsp analyze --sourcemap=sourcemap.json --definitions=globalTypes.d.luau src` → no lines containing `TypeError`.

### Step 3: Document the checks in README.md

Append this section to `README.md`:

```markdown
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
```

**Verify**: `grep -c "luau-lsp analyze" README.md` → `2`.

## Test plan

No new tests: this plan fixes existing tests and documents commands. The verification is the full check list above, all clean.

## Done criteria

- [ ] `luau-lsp analyze --platform=standard --ignore="tests/run.luau" src/shared tests` prints no `TypeError`
- [ ] `luau-lsp analyze --sourcemap=sourcemap.json --definitions=globalTypes.d.luau src` prints no `TypeError`
- [ ] `lune run tests/run` ends with `45 passed, 0 failed`
- [ ] `selene src tests` reports 0 errors, 0 warnings; `stylua --check src tests` exits 0
- [ ] `git status --short` shows only `tests/Distance.spec.luau`, `README.md`, and `plans/` changed (ignore the owner's pre-existing `.claude/` changes)
- [ ] `plans/README.md` status row updated

## STOP conditions

- The test type check still shows a `TypeError` in a file other than `tests/run.luau` after step 1. Report the error; don't fix files outside scope.
- `--ignore` isn't accepted by the installed luau-lsp (an error about an unknown option). Report it rather than finding another way to exclude the file.
- The test count isn't 45 before your change (the code has drifted).

## Maintenance notes

- New spec files are type checked automatically by the "Types (tests)" command. New test helpers that need Lune modules go next to `run.luau` and should be added to `--ignore`.
- A cleaner long-term option is Lune's type definitions (`lune setup`), but that writes machine-specific paths. It was deferred for that reason.
