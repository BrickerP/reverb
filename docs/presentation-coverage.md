# Take Stack presentation coverage

Snapshot: presentation `2fa3735` (G003 source `a5d7cea`), fixed mechanics cursor
`5a1e8c1`. G002 production commit: `2a44c2d`. Source of
content truth: `scripts/data/content.gd`; `scripts/data/character_def.gd` applies
the configured starting weapon. A family/body fallback is marked **prototype
reuse**, never complete art coverage.

Evidence is deliberately split. Source inspection proves that a path exists;
runtime evidence proves only the states visible in the checked screenshots/movie.
The authoritative machine-readable ledger is `docs/presentation-coverage.json`.

## Coverage at this snapshot

| Content | Total | Independent art | Prototype reuse / missing |
| --- | ---: | ---: | ---: |
| Weapons | 12 | 12 | 0 |
| Items | 11 | 11 | 0 |
| Enemies | 7 | 7 | 0 |
| Characters | 4 | 4 front/back sets | 0 |

All 12 weapons, 11 items and 7 enemies now resolve to explicit, unique content-ID
art. The four characters each have authored front/back assets; horizontal mirroring
provides left/right, giving 16 verified character-direction cases across the roster.
The legacy `player` catalog key is the single documented alias of Looper front, so
39 catalog keys resolve to 38 runtime PNGs (32 new plus 6 retained originals).

This completes static identity and front/back-derived direction coverage. It does
not claim full walk/attack frame animation. Existing gameplay tells remain layered
over the new enemy art. Warden received a pivot/authored-axis correction so its
shield and visual front follow gameplay facing.

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

G004 consumes `ShotInfo`, `DamageInfo`, `ExplosionInfo`, `WeaponChangeInfo` and
`PlayerHurtInfo`. It adds per-weapon recoil/muzzle/tracer response, directional
normal/critical/shield-block hits, cause-specific explosions and player hurt, and
post-rebuild equipment apply/undo feedback. Feedback queues are bounded, expire,
pause independently from simulation, support reduced effects and clear on lifecycle
transitions.

Audio now routes 35 cue names, including 12 explicit weapon profiles and 21 new
CC0 WAVs. Seven common and five protected voices prevent routine combat density
from stealing high-priority hurt, boss, result or transaction cues. Rich signals
replace duplicate legacy binding; equipment apply plays once, with separate undo
and reroll cues. Combat/ambient audio pauses while allowed UI transaction cues
remain responsive.

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
- `/Users/yupeng/Documents/Codex/2026-10-23/qu/outputs/take-stack-gallery-weapons.png`
- `/Users/yupeng/Documents/Codex/2026-10-23/qu/outputs/take-stack-gallery-items.png`
- `/Users/yupeng/Documents/Codex/2026-10-23/qu/outputs/take-stack-gallery-enemies.png`
- `/Users/yupeng/Documents/Codex/2026-10-23/qu/outputs/take-stack-gallery-characters.png`
- `/Users/yupeng/Documents/Codex/2026-10-23/qu/outputs/take-stack-content-select-en.png`
- `/Users/yupeng/Documents/Codex/2026-10-23/qu/outputs/take-stack-content-select-zh.png`
- `/Users/yupeng/Documents/Codex/2026-10-23/qu/outputs/take-stack-content-verification/`
- `/Users/yupeng/Documents/Codex/2026-10-23/qu/work/presentation-verification/summary.json`
- `/Users/yupeng/Documents/Codex/2026-10-23/qu/work/presentation-verification/g004-audio-tests.log`
- `/Users/yupeng/Documents/Codex/2026-10-23/qu/work/presentation-verification/g004-combat-tests.log`
- `/Users/yupeng/Documents/Codex/2026-10-23/qu/work/presentation-verification/g004-equipment-tests.log`
- `/Users/yupeng/Documents/Codex/2026-10-23/qu/work/presentation-verification/g004-lifecycle-tests.log`
- `/Users/yupeng/Documents/Codex/2026-10-23/qu/work/presentation-verification/g004-feedback.log`
- `/Users/yupeng/Documents/Codex/2026-10-23/qu/outputs/take-stack-feedback.mp4`
- `/Users/yupeng/Documents/Codex/2026-10-23/qu/outputs/take-stack-feedback-verification/`
- `shots/feedback_summary.json` and seven `shots/feedback_*.png` captures
- `shots/shop_drag_full.png`, `shop_drag_highlight.png`,
  `shop_drag_committed.png`, `shop_drag_undone.png`

Source evidence and ownership are listed explicitly in the JSON ledger. DeepSeek
owns simulation/data/echo rules and balancing. Codex owns presentation assets,
view, UI, audio and presentation tools. Main, localization, project/export and
version files are shared and require an announced integration boundary.

## Work order

1. P2: capture the remaining UI state/accessibility matrix and finish mix QA.
2. G006: verify dense-combat and arena-boundary readability before final delivery.

G005 polish note: the drag preview's intended offset still appears close to its
target in the actual gallery. Recheck its wrapper/theme sizing and target occlusion;
this does not block the functional G002 transaction milestone.

G003 is complete for static/front-back-derived art coverage. Four production
gallery pages and their summary pass with stable Content IDs and linear mipmaps;
the actual weapon/icon/world sizes and all gallery pages passed independent visual
review. Strict English/Chinese four-card geometry and the native G002 nine-counter
probe also pass. On final HEAD `2fa3735` with fixed mechanics `5a1e8c1`, resource
import, English/Chinese UI, 3470 assertions and smoke (5246 frames, wave 4, three
purchases) passed at 2026-10-23 19:15:17 +08:00.

Three surface PNGs are prepared for G005 but lack runtime acceptance. G006 should
exercise the narrow Silencer and light Longbow silhouette in dense combat and at
arena boundaries; these are verification targets, not known failures.

G004 production regression passes: resource import, English/Chinese UI, 3796
assertions and smoke (5246 frames, wave 4, three purchases). The real-paced native
probe observes 15 shots, 4 damage events, 2 explosions, 3 player hurts and 2 weapon
changes. All seven 1280×720 captures are nonblank and actual-view checked. Audio
position stays fixed after pause settles and advances after resume; cleanup clears
old references, feedback queues and motion. Code review is APPROVE and architecture
review CLEAR after the final null-guard confirmation. The shareable audio movie
capture also passes at production commit `9e808ff`. The exported
`take-stack-feedback.mp4` is 7.45 seconds, 1280×720 at 60 FPS with H.264 video and
AAC audio; the verification directory contains seven PNGs, summary and logs.

Completion requires updating both this document and the JSON ledger with a fixed
mechanics cursor and concrete runtime evidence. New content IDs must appear as
explicit incomplete rows until presentation coverage and verification land.
