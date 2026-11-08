# Plan 004 (spike): Design saving progress and a server-trusted throw meter

> **Executor instructions**: This is a design spike, not a build. You write one
> design document and change no game code. Follow the steps, answer every
> question in the "Questions the design must answer" list, and stop at the
> STOP conditions. When done, update the status row for this plan in
> `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 9ef9f70..HEAD -- src/server/PlayerState.luau src/server/ThrowService.luau src/client/MeterController.luau src/shared/Config.luau`
> Plans 002 and 003 are expected to have changed these files. Read the live versions; the excerpts below are from 9ef9f70.

## Status

- **Priority**: P2
- **Effort**: M for the spike (the later build is M-L)
- **Risk**: LOW (document only)
- **Depends on**: plans/003-reskin-seam.md, and the catboy creature ids being decided (the save stores creature ids)
- **Category**: direction
- **Planned at**: commit `9ef9f70`, 2026-11-08

## Why this matters

Progress is in memory only and disappears when a player leaves. `src/server/PlayerState.luau:2` says: "In-memory player state for the prototype. Saving waits until the loop proves fun." The owner's playtests now say the loop is good enough to build on and the economy "feels right", so the condition is met. Once progress is permanent, a known exploit starts to matter. `src/server/ThrowService.luau:9-10`: "Known prototype gap: a modified client can always send a perfect timing. Harden later (e.g. server-timed meter) before anything of value rides on it." Saving is when something of value rides on it, so both get designed together.

## Current state

- `src/server/PlayerState.luau`: per-player `State` held in a table keyed by `Player`:
  ```lua
  export type State = {
  	power: number,
  	cash: number,
  	plot: { [number]: string },   -- slot index -> creature id
  	pending: Pending?,            -- the in-flight throw; never saved
  	levels: { [string]: number }, -- upgrade id -> level (plan 002 builds the starting levels from Config.UpgradeOrder)
  	lastThrow: number,
  }
  ```
  `PlayerState.add` / `remove` are called from `src/server/Main.server.luau` on `PlayerAdded` / `PlayerRemoving`. `PlayerState.sync(player)` pushes values to leaderstats and attributes.
- `src/server/ThrowService.luau` `onThrow(player, timing)`: the client sends `timing` (0..1, the meter marker position). The server sanitizes it (`Distance.compute` clamps; NaN and non-numbers become 0) and trusts it.
- `src/client/MeterController.luau`: the marker is a ping-pong wave of `os.clock()` on the client at `Config.MeterMotion.cyclesPerSecond = 0.8`. The sweet spot is `Config.Meter.sweetCenter ± sweetHalfWidth` (0.5 ± 0.08). The meter only runs while the player has no pending throw and is off cooldown (`Config.Throw.cooldownSeconds = 1.5`).
- Policy rules in `src/shared/Config.luau:5-11` that the design must keep: spawn odds are fixed and free; Power is never sold for Robux; cash never buys a random roll.
- The repo has no package manager set up (no `wally.toml`); `rokit.toml` pins rojo, lune, selene, stylua, luau-lsp only.
- Repo workflow (`CLAUDE.md`): build core first, then layers. Tests first. Pure logic goes in `src/shared/` so Lune can test it.

## Scope

**In scope**: create `docs/save-design.md`. Nothing else.

**Out of scope**: any `src/` or `tests/` change, adding a package manager or libraries, enabling Studio API access.

## Steps

### Step 1: Research the current official guidance

Read the Roblox Creator Docs pages on data stores (`https://create.roblox.com/docs/cloud-services/data-stores` and its best-practices and error-codes pages) and record the current limits you rely on (request budgets, key/value size). Date-stamp them. If the pages are unreachable, say so in the doc and mark those numbers as unverified.

Also compare one or two session-locking approaches, for example the open-source ProfileStore module versus a hand-rolled `UpdateAsync` lock. Evaluate on: session locking, retries, ease of testing, and the cost of adding a package manager.

### Step 2: Write `docs/save-design.md` answering the questions below

Use short sections, one per question, and a final "Build plan outline" section listing the build steps in tests-first order.

#### Questions the design must answer

1. **What is saved** (field by field, from `State`)? What is never saved (`pending`, `lastThrow`), and why?
2. **Schema and versioning**: a `version` field, and how migrations run. Include the case where the catboy reskin renames creature ids (an old save holds `"sproutling"`). Decide on a migration table in Config vs. dropping unknown ids, and justify the choice.
3. **Load path**: what happens before the load finishes? Can the player throw? Do leaderstats show 0? What happens if the load fails after retries (kick with a message vs. play unsaved)? Make sure a failed load can never overwrite a good save.
4. **Save path**: autosave interval, save on `PlayerRemoving`, `game:BindToClose`, budget checks.
5. **Session locking**: what stops two servers writing the same player (fast rejoin)?
6. **Library choice**: hand-rolled vs. ProfileStore (or another), with the trade-offs from step 1 and a recommendation.
7. **Server-trusted meter**: design a way for the server to decide the timing value instead of trusting the client. Example direction: the server records when the meter started for that player (after cooldown, with no pending throw) and computes the phase from its own clock when the throw arrives, allowing a latency window. Say what latency allowance keeps honest players' perfect throws perfect, and how the client display stays in sync. Name the pure, Lune-testable function(s) this adds to `src/shared/`.
8. **Policy check**: confirm nothing in the design sells Power, changes spawn odds, or adds a paid random roll.
9. **Testing**: what's pure and Lune-testable (migration, serialization, meter phase math), and what needs a Studio test (with "Enable Studio Access to API Services" on a test place).

### Step 3: Open questions for the owner

End the doc with an "Open questions" list for anything you couldn't decide from the repo, each with your recommended answer.

## Done criteria

- [ ] `docs/save-design.md` exists and has a section for each of the 9 questions, a "Build plan outline", and "Open questions"
- [ ] Every Roblox limit or number in it has a source link and a date, or is marked unverified
- [ ] `git status --short` shows only `docs/save-design.md` and `plans/README.md` changed (ignoring `.claude/`)
- [ ] `plans/README.md` status row updated

## STOP conditions

- Catboy creature ids aren't decided yet and question 2 can't be answered. Write the rest, mark question 2 as blocked, and report.
- Any design option would need selling Power or changing spawn odds. Report it instead of including it.

## Maintenance notes

- The build plan that follows this spike should be written with the `improve` skill (`plan <description>`) from `docs/save-design.md`.
- Once saving ships, any change to `State`'s shape needs a schema version bump and a migration test.
