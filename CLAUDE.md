# Working Rules

## Planning
- For any large or multi-file task, start in plan mode: explore the relevant code, write a full plan, and wait for my approval before changing anything.
- Skip planning for small tasks (typos, renames, minor design tweaks). Just do them.
- In plan mode, always use the `improve` skill to write the plan, detailed enough for a cheaper, faster model to implement without rereading the codebase.
- After I approve a plan, hand the implementation to a Sonnet subagent (Agent tool with `model: "sonnet"`) with the plan as its brief, to save tokens. Then review its result yourself and run the Verification steps before saying it's done. This is the exception to "use subagents sparingly".

## Development Pipeline
We are not building the game in one pass. Build from the ground up:
1. Core mechanics first: get the main loop working and fun.
2. Then layer on UI, music/audio, maps, economy, and the rest.

Don't start a later layer until the core it depends on works. If a request jumps ahead (for example, shop UI before the loop exists), point that out before building.

## Skills
Roblox skills in `.claude/skills/` (from AshExplained/roblox-skills):
- `roblox-world-level-design`: maps, zones, player flow.
- `roblox-game-ux`: design and approve a UI brief before building it.
- `roblox-ui-implementation`: build approved UI in Studio.
- `roblox-mobile-playtest`: phone/tablet checks.
- `roblox-asset-pipeline`: finding, generating, and importing assets.
- `roblox-economy-balancing`: currencies, sinks, reward curves.
- `roblox-admin-tools-observability`: admin commands, audit logs, diagnostics.
- `roblox-code-maintenance-refactor`: Roblox-specific cleanup checklist. Use it when I name it; for reviews and cleanup, the pair below leads.
- `handoff`: writes a handoff note to `.scratch/handoffs/` so a fresh session can continue.

These skills sometimes point to other roblox-skills that aren't installed here. If one is needed, tell me rather than improvising it.

Coding and review defaults:
- `ponytail`: use for all coding. The smallest change that fully solves the task.
- `improve-codebase-architecture` + `thermonuclear-code-quality-review`: the default pair for code reviews and cleanup, run together. Never mix behavior changes with cleanup; commit them separately.

Other skills. Use these when relevant, or when I name them:
- `grill-with-docs`: question me to refine requirements before building.
- `improve`: codebase audit and plan writing.

## Verification (required before saying a task is done)
- Write tests first, then implement. Never write tests after the fact just to pass your own code.
- Test only what matters. Don't add tests for every line.
- Run the type checker and linter, and fix all errors.
- For frontend changes, open the app in the browser, click through the change, and take screenshots to confirm it looks and works right.
- If you can't verify something, tell me so. Don't claim it works.

## Persistent Context (Obsidian vault)
Project context and memory live only in the vault at `C:\Users\pi\Documents\General Roblox Development`, not in this repo. Follow the vault's `CLAUDE.md`.
- Start every session from the vault, not from exploring the code: read `VAULT-INDEX.md`, `memory/MEMORY.md` and `projects/roblox-dev/CONTEXT.md` there, then open only the notes, plans and files the task needs.
- Prefer the `obsidian` CLI for vault search, backlinks and tags when it's on PATH (it's allowed in `.claude/settings.local.json`). Otherwise use the normal file tools.
- At the end of a task, update the "Now" section of the vault's `projects/roblox-dev/CONTEXT.md` (a few lines, not a log).
- Auto memory is stored in the vault's `memory/` folder (the `~/.claude` memory path is a junction to it). Save lasting decisions there, one per note, linked with `[[name]]`.
- Don't add notes, `.obsidian/` or memory files to this repo.

## Context & Token Efficiency
- Stay focused: only read files and sources the task needs. No exploratory tangents.
- If my prompt is vague, ask a short clarifying question instead of reading the whole codebase to guess.
- Use the files and sources I point you to first.
- Treat each session as one task. If I start a new, unrelated task, suggest a fresh session.
- When context reaches about 200k tokens or about 50% of the window (whichever comes first), alert me and offer to write a `handoff` so a fresh session can continue. If we must compact, ask what I want kept first.
- Use subagents sparingly, only when the quality gain is worth the token cost.

## Tools
- Use MCPs only to interact with things outside the codebase (database, GitHub, browser, deployments). Don't use them for best practices or patterns.

## Code Style
- No all-caps text in user-facing UI.
- Write PR descriptions in plain, concise language: what changed, why, and how it was tested.

## Teaching
- After each change, briefly explain what you did and why, so I understand my own codebase.
