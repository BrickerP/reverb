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

## Post-G006 playtest feedback phase

Fixed source `a4704647bf45df3faf71825309df9f23c7abeb2f` adds local,
attributable post-run feedback without changing simulation. Run-log schema 2 assigns
a Crypto run ID, UTC timestamps, source and immutable build stamp. Feedback-log
schema 1 accepts one validated category/feeling/note record per run ID. The result
screen form supports save, cancel, duplicate/read-only reopen and opening the local
folder. No record is uploaded or sent automatically.

`runs_report.py` joins run and feedback ledgers only when ID and provenance agree,
groups by source/build, and reports malformed, orphan, duplicate and mismatched
records. Sources are `manual`, `fixture`, `bot` and `unknown`; fixture, bot, unknown
and legacy rows are never silently described as human evidence. At this checkpoint
the number of verified human feedback records is **zero**.

Verification passes: 4158 Godot assertions, smoke, English/Chinese UI, 10 Python
report tests and native EN/ZH feedback probes including Unicode note input, Tab
navigation, duplicate/read-only reopen, reset and fixture provenance. Exact-head CI
[39998713766](https://github.com/BrickerP/reverb/actions/runs/39998713766) passes all
five jobs, including native Ubuntu and Windows exported-build launches for 60
headless frames. Baseline CI
[39967093104](https://github.com/BrickerP/reverb/actions/runs/39967093104) also passes.

Three immutable playtest packages share PCK SHA-256
`f6376bba8b0ec856bb1f8966230f606f6889764abb62a8adc0753f200d32e028`;
each loads 79 runtime resources plus 18 provenance files with zero forbidden hits.
The macOS isolated startup passes with build stamp `a470464` and leaves normal user
data unchanged. The previous `Take Stack Preview.app` and its archives remain
untouched. This phase creates no tag, Release or main-branch move.

The normal exported macOS Playtest app was also driven through CUA without an
injected script. It completed a real run and saved a schema-2 run plus matching
schema-1 feedback with the same run ID and build stamp `a470464`. That evidence is
explicitly `fixture`, its note says it is automated, and it makes no human-feedback
claim.

Metadata commit `4594fce` is integrated for v0.2.0. The latest observed DeepSeek
main `cba4dc9` is runtime-equivalent to that metadata checkpoint; no release action
is attributed to the presentation lane. The next evidence required is actual human
play: current local ledgers may be read by authorized follow-up checks, while other
players may voluntarily provide theirs.

Completion requires updating both this document and the JSON ledger with a fixed
mechanics cursor and concrete runtime evidence. New content IDs must appear as
explicit incomplete rows until presentation coverage and verification land.

## Playtest follow-up: lethal-hit health text

The exported macOS playtest exposed a negative health label after lethal damage.
The HUD now floors only the displayed number at zero. Simulation health and
positive fractional-health rounding remain unchanged. A native EN/ZH probe
observes the actual health draw call for raw HP -1.4, 0, 0.2, 34.2 and 35; all ten
cases pass, with simulation HP unchanged and screenshots checked. The full suite
passes 4158 assertions with zero failures. Evidence is in
`outputs/take-stack-hud-fix-verification/` in the parent task directory.

The mechanics cursor remains `4594fce`; the newly checked DeepSeek `cba4dc9`
has no tree difference from it. No default manual run or feedback ledger exists
in the previous playtest's isolated user directory, so this fix derives from
automated runtime observation and makes no claim about human player feedback.

## Pending mechanics: Paradox twin timelines

Candidate `bb09c95735e6270e095c5e344abecc299e527900` (observed merge `f3c4e91`)
is held before integration. Its upstream CI passes and its existing boss suite
passes 40 assertions in an isolated archive. A separate contract probe fails:
nonlethal damage leaving 0.25 HP creates two bodies with total HP 1.0, contrary to
the documented remaining-health preservation rule. The 10 HP control is preserved.
This is a controlled boundary fixture, not observed human gameplay or a balance
conclusion. Mechanism ownership remains with DeepSeek; no candidate code is merged.

The accepted mechanics cursor remains `4594fce` and the playable build remains
`42b0c6e`. The candidate reuses existing Paradox art, but its combined health/pips,
phase/shard/enrage events, surviving-body effect origins, reduced-effects lifecycle
and audio coverage are pending acceptance. Evidence and reproduction are in
`outputs/take-stack-boss-phase2-review/` in the parent task directory.

## Selective family mastery integration

The independent family patch from `78145876` is applied on base `4594fce` without
the held Boss ancestry. The private preview retains version 0.2.0; its immutable
build commit identifies the composition rather than claiming the upstream release.
No new content ID, bitmap or sound is required for these four family rules.

The build panel explains the four distinct masteries, reads effective arcane echo
power from Sim, and updates after purchase/undo. HUD readiness now includes the
actual family and synergy cooldown multipliers. A native screenshot exposed long
English descriptions widening the entire shop; wrapped summary rows fix this,
and the probe now checks the whole shop, columns, header and actions, as well as
all wrapped text lines.

Full tests pass 4208 assertions with zero failures. Smoke reaches wave 4 with
three purchases across 5246 frames. EN/ZH and normal/reduced modes each pass all
four families through three-to-four-piece purchase and undo, including arcane
40% → 48% → 40%. All 32 captures and geometry receipts are under
`outputs/take-stack-family-verification/`. These are automated fixtures; they do
not establish human satisfaction or balance. The Boss phase-2 hold remains active.

## Selective elite integration

Fixed elite source `1b45f321` is applied on presentation `39bc2c0`, without the held
Boss ancestry or later shop features. The six regular enemy IDs each support all
three modifiers (18 combinations), explicitly reusing the existing enemy art.
Pending telegraphs and auras share identity colors and scaled radius; shield and
death-warning geometry reads instance overrides. Reduced effects retain stable
identity/rule cues and remove the extra rotating aura and pulse. Ordinary enemies
do not allocate the new elite profile each frame.

One presentation-interface correction is recorded: volatile non-bombers previously
reported `bomber` as the death cause. The two attribution fields now use the actual
enemy ID, while damage, radius, iframes and BOMBER effect/audio routing are unchanged.
The 33 attribution assertions include both volatile non-bombers and normal bombers.

Full tests pass 5102 assertions with zero failures. Native normal/reduced probes
each cover 18 combinations with nine screenshots, reduced/front versus back hits,
one corresponding audio cue per hit, one radius-64 volatile explosion and its
existing audio route, plus pause/rebind/reset. Evidence is under
`outputs/take-stack-elite-verification/`; these are isolated fixtures, not human play.

Final stress exits cleanly with p99 frame-production samples 13.169/13.631/13.724 ms
for 100 standard / 300 standard / 300 reduced enemies. The first run reported
shutdown resources still in use; a verbose rerun was already clean. The probe now
explicitly returns to character select, asserts Sim ownership is released, and
frees Main before quitting. The final ordinary rerun is clean. The original warning
and both reruns are retained; its intermittent root cause is not claimed resolved.

## Selective weapon-sale integration

Fixed sale source `ea00b0a` is applied on presentation `047a717`; later shop features,
held Boss ancestry and upstream version metadata remain excluded. Sell, eligibility,
refund and quote methods match the fixed source. One event-interface repair preserves
the actual operation index in undo history and emits explicit removal/insertion
payloads. This prevents shifted and same-ID weapons being reported as replacements;
the history annotation never becomes restored or serialized gameplay state.

Quote-driven sell controls explain the last-weapon guard. Removal/refund and undo
reinsertion use the authoritative event/result, play existing audio once, preserve
family wrapping, and fall back to Undo focus if the neighboring upgrade is disabled.
All 5235 assertions and smoke pass. EN/ZH x normal/reduced native runs cover exact
two-sale/two-undo restoration, last-weapon protection and refresh/start history locks,
with 16 screenshots. The initial ZH reduced fixed-fps run timed out before capture;
the same checks with real-time max-fps 60 and added wait-position diagnostics passed.
Its original timeout is retained and not described as a diagnosed game defect.
Evidence: `outputs/take-stack-sell-verification/` in the parent task directory.

## Selective offer-lock integration

Fixed lock source `699ee83` is applied on presentation `ba92fb2`, preserving the
sale-event index annotation and excluding Boss/later-system ancestry and release
metadata. The held offer now stays at its original clamped slot after reroll and
the next shop, with the same object and price. Generation, duplicate prevention,
RNG consumption and refresh cost remain unchanged; this repairs six failing
nonzero-position checks from the fixed candidate.

Independent Lock/Unlock controls suppress purchase and equipment drag, retain
keyboard focus after refresh, and show a compact full-slot reason with detailed
accessible text. The free hold produces no material or purchase feedback. The hint
explains that equipment undo restores the hold snapshot at that transaction.

All 5358 assertions, resource import and smoke pass. Native EN/ZH x normal/reduced
runs pass physical click, drag-away and keyboard guards, stable object/index/price,
sold/stale and full/poor/maxed states, sale/undo interoperability, history boundaries
and cleanup, with 16 screenshots. Independent review is APPROVE with zero issues.
Evidence is in `outputs/take-stack-lock-verification/`; fixtures do not establish
human satisfaction or balance. No new image or audio resource is needed.

## Contract accounting hold and Boss health repair

An isolated archive of contract candidate `1d0eeda` passes its 77 existing assertions
but fails the equipment-before-contract ordering probe: both buy → accept → undo
and sell → accept → undo restore 100 materials instead of 94 while the 6-deposit
contract remains accepted and active. Accept → buy → undo correctly returns 94.
Independent review marks this a high-severity economy/state issue. No contract code
or accounting/history rule is changed in this presentation branch. An additional
acceptance-time history barrier would require explicit design alignment with the
currently agreed reroll/start boundaries; it is not silently adopted.

Upstream repair `73717b1` resolves the previously held Boss fractional-health issue.
The isolated composition `bb09c95` + `73717b1` passes 46 Boss assertions and the exact
original 10/0.25 HP boundary probe. Independent review approves the source fix.
The next presentation batch is therefore the repaired twin-timeline Boss, including
combined HUD health, split/survivor/last-body events, audio, reduced effects and lifecycle.
Source repair is not yet a playable presentation integration. Current playable code
remains `8403188`. Evidence: `outputs/take-stack-contract-review/` and
`outputs/take-stack-boss-fix-verification/` in the parent task directory.

## Repaired twin-timeline Boss presentation

The repaired `bb09c95` + `73717b1` mechanics are now selectively composed with the
accepted `8403188` runtime. Family echo power, elite instance overrides/death attribution,
sale events and held-offer behavior remain intact. Contract/rift/collapse/endless ancestry
and release metadata are excluded. Both bodies use the existing explicit Paradox art.

The combined health bar and body-identity pips remain correct when the original body
dies first. Silence follows the living body; the final beat follows the last defeated
body. Existing audio assets provide one spawn/phase/enrage cue with pitch variation,
the existing silence cue and one run-won victory cue. Reduced effects keep a stable
link and survivor/silence tells while suppressing new decorative motion and sparks.
Bind/unbind clears death/victory origins; the English phase-2 title uses 22px within
the 400px HUD region.

All 5444 assertions, smoke and import pass. EN/ZH x normal/reduced native runs provide
24 screenshots and exact spawn/split/death/enrage/silence/win receipts, including the
direct-lethal skip path and lifecycle checks. Independent review is APPROVE. Stress
completed within feedback/audio bounds with clean exit. Its first sample included
243.716/123.481ms frame outliers; an unchanged-code follow-up did not reproduce those
outliers (p99 13.173/14.556/14.829ms). Both samples are retained; they do not establish
universal frame pacing. Evidence: `outputs/take-stack-boss-verification/`.
