# Working Rules

## Planning
- For any large or multi-file task, start in plan mode: explore the relevant code, write a full plan, and wait for my approval before changing anything.
- Skip planning for small tasks (typos, renames, minor design tweaks). Just do them.
- When asked, use the `improve` skill to audit the codebase and write plans detailed enough for a cheaper, faster model (e.g. Sonnet) to implement.

## Skills
Use these when relevant, or when I name them:
- `grill-with-docs`: question me to refine requirements before building.
- `improve-codebase-architecture`: structural improvements.
- `thermonuclear-code-quality-review`: simplify generated code and remove slop. Pair it with improve-codebase-architecture.
- `improve`: codebase audit and plan writing.
- `ponytail`

## Verification (required before saying a task is done)
- Write tests first, then implement. Never write tests after the fact just to pass your own code.
- Test only what matters. Don't add tests for every line.
- Run the type checker and linter, and fix all errors.
- For frontend changes, open the app in the browser, click through the change, and take screenshots to confirm it looks and works right.
- If you can't verify something, tell me so. Don't claim it works.

## Context & Token Efficiency
- Stay focused: only read files and sources the task needs. No exploratory tangents.
- If my prompt is vague, ask a short clarifying question instead of reading the whole codebase to guess.
- Use the files and sources I point you to first.
- Treat each session as one task. If I start a new, unrelated task, suggest a fresh session.
- If context passes about 150k tokens, tell me and suggest starting a new session. If we must compact, ask what I want kept first.
- Use subagents sparingly, only when the quality gain is worth the token cost.

## Tools
- Use MCPs only to interact with things outside the codebase (database, GitHub, browser, deployments). Don't use them for best practices or patterns.

## Code Style
- No all-caps text in user-facing UI.
- Write PR descriptions in plain, concise language: what changed, why, and how it was tested.

## Teaching
- After each change, briefly explain what you did and why, so I understand my own codebase.
