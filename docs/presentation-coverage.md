# Take Stack presentation coverage

Snapshot: presentation `4b481d3`, fixed mechanics cursor `c2e184e`. G002 production
commit: `2a44c2d`. Source of
content truth: `scripts/data/content.gd`; `scripts/data/character_def.gd` applies
the configured starting weapon. A family/body fallback is marked **prototype
reuse**, never complete art coverage.

Evidence is deliberately split. Source inspection proves that a path exists;
runtime evidence proves only the states visible in the checked screenshots/movie.
The authoritative machine-readable ledger is `docs/presentation-coverage.json`.

## Coverage at this snapshot

| Content | Total | Independent art | Prototype reuse / missing |
| --- | ---: | ---: | ---: |
| Weapons | 12 | 3 | 9 |
| Items | 11 | 0 | 11 |
| Enemies | 7 | 2 | 5 |
| Characters | 4 | 0 character-specific | 4 share the operator |

Independent art currently covers pistol, shotgun, orb, grunt and runner. SMG,
rifle, flechette, longbow and hex bolt reuse family art. All four evolutions also
reuse family art, so their transformation is not visually complete. Every item is
still a color block/text identity; magnet additionally has a pickup-range ring.
Brute, silencer, bomber, warden and Paradox reuse the grunt body, although their
existing scale/tint, explosion radius, shield, silence and boss tells remain.

All characters share the operator sprite. Their selection color, echo rules,
statistics and starting weapons distinguish them: Looper and Conductor start with
pistol, Solo with hex bolt, and Mirror with longbow. There is still no
character-specific battle silhouette, so this remains prototype art coverage.

## UI and event state

Actual-window evidence exists for the four-character selection, combat HUD,
echoes, the shop in English and Chinese, full six-weapon scrolling, replacement
and purchase. Pause, settings, history, codex, merge and end-state flows have source
and automated tests but no accepted current-window matrix yet.

The approved transaction experience is implemented through mechanics-owned
`quote/apply/undo`. Native EN/ZH interaction probes cover weapon drop into an empty
slot (BUY), weapon drop onto an occupied slot before the loadout is full (REPLACE),
item BUY, cancelled drag with no change, exact cost/refund hints, focused partial
replacement, upgrade, four consecutive undos, and reroll/start-wave history locks.
Undo is equipment-only; echo discard/merge remains excluded. Exact stale Offer
objects are rejected after undo/rebuild. The focused transaction suite passes 76
assertions. The integrated G002 tree subsequently passed 2660 assertions with zero
failures; smoke completed 5246 frames through wave 4 with three purchases.

Rich `ShotInfo`, `DamageInfo`, `ExplosionInfo` and `WeaponChangeInfo` events exist
at the mechanics cursor. View/audio still consume compatible legacy signals, so
weapon-specific recoil, muzzle position, impact direction, explosion cause and
equipment/undo feedback are not implemented.

Audio exposes 14 events. Five have new documented presentation cues (click, buy,
hit, echo, wave end); nine use the pre-existing fallback files. The 12-second movie
proves a mixed audio track exists, not that every cue has passed a listening matrix.

## Evidence

Runtime evidence:

- `/Users/yupeng/Documents/Codex/2026-10-23/qu/outputs/take-stack-presentation-preview.mp4`
- `/Users/yupeng/Documents/Codex/2026-10-23/qu/outputs/take-stack-presentation-*.png`
- `/Users/yupeng/Documents/Codex/2026-10-23/qu/outputs/take-stack-*-en.png`
- `/Users/yupeng/Documents/Codex/2026-10-23/qu/outputs/take-stack-*-zh.png`
- `/Users/yupeng/Documents/Codex/2026-10-23/qu/outputs/take-stack-verification/`
- `/Users/yupeng/Documents/Codex/2026-10-23/qu/work/presentation-verification/g002-unit.log`
- `/Users/yupeng/Documents/Codex/2026-10-23/qu/work/presentation-verification/g002-drag-en.log`
- `/Users/yupeng/Documents/Codex/2026-10-23/qu/work/presentation-verification/g002-drag-zh.log`
- `/Users/yupeng/Documents/Codex/2026-10-23/qu/work/presentation-verification/tests.log`
- `/Users/yupeng/Documents/Codex/2026-10-23/qu/work/presentation-verification/smoke.log`
- `shots/shop_drag_full.png`, `shop_drag_highlight.png`,
  `shop_drag_committed.png`, `shop_drag_undone.png`

Source evidence and ownership are listed explicitly in the JSON ledger. DeepSeek
owns simulation/data/echo rules and balancing. Codex owns presentation assets,
view, UI, audio and presentation tools. Main, localization, project/export and
version files are shared and require an announced integration boundary.

## Work order

1. P0: bind rich combat/equipment events to precise view and audio feedback.
2. P0: give the four evolved weapons and five special enemies/boss distinct identity.
3. P1: complete base-weapon variants, 11 item icons and four character identities.
4. P1: add a complete content-ID gallery and coverage assertions.
5. P2: capture the remaining UI state/accessibility matrix and finish mix QA.

G005 polish note: the drag preview's intended offset still appears close to its
target in the actual gallery. Recheck its wrapper/theme sizing and target occlusion;
this does not block the functional G002 transaction milestone.

G003 preparation note: 32 generated source images are present and independently
visually checked, but they are not mapped into the presentation catalog/runtime.
Their affected rows therefore remain prototype reuse or missing art until the
integration and content-ID runtime gallery pass.

Completion requires updating both this document and the JSON ledger with a fixed
mechanics cursor and concrete runtime evidence. New content IDs must appear as
explicit incomplete rows until presentation coverage and verification land.
