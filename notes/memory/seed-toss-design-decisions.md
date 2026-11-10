---
name: seed-toss-design-decisions
description: "Settled design decisions for the throw-to-collect prototype (seed theme, Power never sold, collect modes, toolchain)"
metadata:
  node_type: memory
  type: project
  originSessionId: 85eda95f-561b-4ec4-8ee0-44391891ec8a
  modified: 2026-11-08T19:28:34.462Z
---

Throw-to-collect prototype ("seed toss") decisions, settled 2026-11-08:
- Theme: throw magic seeds into a meadow; a plant-critter sprouts where it lands. Zones: Lawn, Grove, Wildwood.
- Power changes throw distance, and so zone and rarity. So **Power must never be sold for Robux** (no paid x2 Power). Monetize later with cosmetics, plot slots or income boosts instead.
- Collect mode: the 2026-11-08 playtest picked **auto** (walk felt tedious). Walk code stays behind `Config.CollectMode` in case a transport upgrade makes walking worth it later.
- Session target: 10 minutes for now. Retention hooks wait for the economy layer.
- Toolchain: Rokit + Rojo + Lune (tests) + Selene + StyLua + luau-lsp, code in git.

- Later the same day (theme is now catboys): the owner's spec "units" = Creatures, collected by throwing; no egg summons. Catboy looks use Roblox-made catalog items (no UGC lookalikes, no copying a real user's avatar). Random looks, saved looks, shop/quest NPCs and idle animations wait for later layers.

**Why:** Roblox policy (from roblox-researcher policy_check.md) bans paid influence on random spawn odds; Power feeds the odds via distance.
**How to apply:** Reject any monetization proposal that sells Power or changes ZoneTables weights. Related: [[throw-to-collect-playtest]].
