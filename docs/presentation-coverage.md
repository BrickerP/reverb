# Take Stack presentation coverage

Final runtime/export snapshot: presentation `d4a0e73` (G003 source `a5d7cea`, G004
`9e808ff`, G005 `24f4fd4`) with runtime mechanics `5a1e8c1`. Latest contract/test
integration is `dee0fd7` at mechanics cutoff `075a2bd`. Source of
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

G005 completes the UI-state matrix: character selection, combat HUD,
shop/build/echo merge, pause, settings, history, codex and loss/win results. All
modal focus cycles, active accessible names, persisted reduced effects, active-run
language guard, merge cancellation, draggable preview wrapper and three surface
skins are present. Strict English and Chinese native geometry passes across all ten
states after the final Codex spacing, merged-badge HFlow and dense-panel paint-crop
fixes. The 960×540 English scaled and 1280×800 Chinese letterbox probes also pass.

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
- `/Users/yupeng/Documents/Codex/2026-10-23/qu/outputs/take-stack-ui-verification/`
- `/Users/yupeng/Documents/Codex/2026-10-23/qu/outputs/take-stack-final-verification/`
- `/Users/yupeng/Documents/Codex/2026-10-23/qu/outputs/take-stack-export-verification/`
- `/Users/yupeng/Documents/Codex/2026-10-23/qu/outputs/TakeStack-macOS-d4a0e73.zip`
- `/Users/yupeng/Documents/Codex/2026-10-23/qu/outputs/TakeStack-Windows-d4a0e73.zip`
- `/Users/yupeng/Documents/Codex/2026-10-23/qu/outputs/TakeStack-Linux-d4a0e73.zip`
- `/Users/yupeng/Documents/Codex/2026-10-23/qu/outputs/Take Stack Preview.app`
- `/Users/yupeng/Documents/Codex/2026-10-23/qu/outputs/试玩表现版.command`
- `shots/feedback_summary.json` and seven `shots/feedback_*.png` captures
- `shots/shop_drag_full.png`, `shop_drag_highlight.png`,
  `shop_drag_committed.png`, `shop_drag_undone.png`

Source evidence and ownership are listed explicitly in the JSON ledger. DeepSeek
owns simulation/data/echo rules and balancing. Codex owns presentation assets,
view, UI, audio and presentation tools. Main, localization, project/export and
version files are shared and require an announced integration boundary.

## Work order

1. Run human play sessions and feed balance findings to DeepSeek.
2. Launch the Windows and Linux builds natively on their target platforms.
3. Iterate feel only from observed player feedback and new committed mechanics.

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

The arena floor, panel skin and recording cartridge are integrated. A fourth new
original provides the application icon, bringing the original PNG total to 42.
Final bilingual geometry, scaled and letterbox probes pass. G006 is now exercising
the narrow Silencer and light Longbow silhouette in dense combat and at arena
boundaries; these remain verification targets, not known failures.

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

G005 is fixed at `24f4fd4`: 3927 assertions and smoke pass, strict native EN/ZH
ten-state geometry passes, and the 960×540 EN scaled and 1280×800 ZH letterbox
probes pass. The final dense-shop paint crop removes a duplicated inner panel body
without changing layout or source PNGs; refreshed EN/ZH captures pass. The stable
output folder contains 20 PNGs plus JSON and logs. Code review is APPROVE,
architecture review CLEAR and visual review PASS.

G006 cleanup removes the unused `player` alias and duplicate metadata, leaving 38
canonical catalog keys while retaining the same 42 PNGs. This does not rewrite the
historical G003 evidence that originally verified 39 keys with one documented alias.
After cleanup, 3915 assertions, smoke and EN/ZH UI pass at fixed HEAD `d4a0e73`
at 2026-10-23 21:34 +08:00.
The fixed 300-enemy stress fixture contains all seven enemy types, six player
weapons and four echoes. Standard 300-enemy frame production is 6.761 ms average,
10.813 ms p99 and 13.640 ms max; reduced effects is 6.916/12.516/14.490 ms.
Four dense/edge captures pass visual review, with bounded 12 audio voices and 260
sparks.
These are Apple M3, Godot 4.7.2 OpenGL Compatibility measurements with fixed 60
FPS and vsync disabled: frame-production headroom on that machine, not a universal
or cross-hardware FPS guarantee. Reduced effects exists for readability and lower
motion; the timing comparison does not claim that mode is inherently faster.

All three delivered PCKs share SHA-256
`cfc5ba3466ea34478494d636e2ee20dfa2da9a8bda15490113edec74835dcbf2`.
Each mounts and loads 79 runtime resources plus 18 provenance files with zero
forbidden hits. macOS runs 30 isolated headless frames and leaves normal user data
unchanged. The exported app also passes a live Chinese flow: start, movement,
pause, active-run language guard, reduced-effects persistence, resume, return to
character select and clean exit. Windows/Linux packages were audited on macOS but
not launched natively on those operating systems.

Final source is `09375a4`; version is 0.2.0. Cleanup is recorded, independent code review is APPROVE with zero findings, and the independent architect verdict is CLEAR across seven invariants. This source is packaged as the v0.2.0 release.

After that immutable export, DeepSeek delivered `075a2bd` plus `6325bcb`: interface
documentation, README text and 13 additional assertions in two test files. They are
integrated at `dee0fd728569db0f28d5396f638e4586f8e2f869`; no runtime/export input
changed. The latest integrated verification is therefore the headline result:
3928 assertions, smoke, import and English/Chinese UI all pass at 2026-10-23
21:45:35 +08:00. The audited packages and performance evidence remain tied to the
byte-identical runtime source `d4a0e73`.

Completion requires updating both this document and the JSON ledger with a fixed
mechanics cursor and concrete runtime evidence. New content IDs must appear as
explicit incomplete rows until presentation coverage and verification land.
