# Gameplay and presentation interfaces

This is the current 0.18.6 contract. Simulation owns rules and mutation. UI,
rendering, audio and native probes may read model state and submit explicit
actions; they must not invent prices, damage, availability, debt, random results
or saved-run outcomes.

## Ownership and entry points

| Layer | Canonical entry points | Responsibility |
|---|---|---|
| Main | `scripts/game/main.gd`, `scripts/core/controls.gd` | Input, modal priority, screen lifecycle, suspend envelope and Meta wiring |
| Run | `Sim`, `WaveDirector`, `Expedition`, `WorldArena`, `EnemyBrain` | Encounters, authoritative ticking, missions, interactions, bosses, caps and endings |
| Equipment | `Content`, `WeaponDef`, `Combat`, `SupportSystem` | 35 weapon profiles, hit identity, support bodies and bounded allocation |
| Roles and copies | `CharacterSkills`, `EchoSystem`, `EchoBank`, `EchoArchive` | Role actions, copy wear/retirement, host-preserving merge and cross-run archive |
| Transactions | `Shop`, `ShopState`, `ShopResult`, `Offer`, `AnomalyContract` | Six goods, quotes, order replacement, assembly, refit, branching and atomic undo |
| Persistence | `RunSnapshot`, `SuspendStore`, `Meta`, `StoryLedger` | Snapshot v4, atomic storage, permanent unlock/archive data and route clues |
| Presentation | `Hud`, `ArenaView`, `ExpeditionInk`, `BattleDirector`, `GameAudio` | Read-only, bounded, localized visual/audio feedback |

Main detaches prior session listeners before binding a new or restored session.
Views re-read model objects after undo or restore; they never retain mutable
simulation aliases as authority.

## Campaign, pacing and capacity

- `WaveDirector.FINAL_WAVE == 12`. Normal bosses are mandatory at 4, 8 and 12.
  `Expedition.boss_id` maps them to `foreman`, `collector`, and `paradox`.
- Endless and Boss Rush start from the completed stage-12 state. Boss encounters
  recur at 16, 20, 24, and every fourth stage thereafter.
- Normal duration is `min(60, 24 + 3 * (stage - 1))`. Spawn budget is
  `min(360, 10 + 8 * stage)`. Drop cash is capped by
  `min(300, 24 + 6 * stage)`.
- `Sim.MAX_ENEMIES == 96`; ordinary enemies use at most 94 slots so a mandatory
  boss or split body retains two reserved slots. Pending spawns cap at 24.
  Saturated boss records retry after a real death frees capacity.
- Cohorts occupy 0–24%, 36–60%, and 72–100%. Tail pressure remains active near
  the end but respects the same caps. Each materialized spawn has a real
  0.8-second telegraph.
- `Sim.ARENA == Rect2(40, 80, 2400, 1200)`. The standard 1280×720 canvas uses
  a 1200×600 battle rectangle; `WorldArena.display_viewport` derives the native
  rectangle at other sizes. Model positions and attacks remain world
  coordinates; culling and camera translation are presentation.

## Boss and interaction geometry

`EnemyBrain.attack_profile` exposes the same locked geometry used for damage:

| Boss | Profile | Authoritative behavior |
|---|---|---|
| Foreman | `press` | Warning locks a point; impact tests a radius-112 body area |
| Collector | `dash` | Warning locks direction; active dash sweeps the traveled segment |
| Paradox | `cross` | Warning locks a point; impact tests perpendicular 68-wide, 410-long arms |

Paradox retains the phase-two split. Enemy capacity cannot delete either real
body. Support units use their own radius in the same impact tests.

`Sim.interact()` delegates to `Expedition.interact()`. `Expedition.interaction()`
returns the nearest available item with `name_key`, `description_key`, range,
cost and cooldown. UI does not reproduce this logic. Shipped kinds are press,
conveyor, recycler, mission part, terminal, repair target, rescue target and
boss negotiation.

`Shift / LB` is the `character_skill` action. `E / X` is `interact`. Labels come
from the active `InputMap` through `Controls`; they are not hard-coded in HUD.
Modal screens block both actions and restore focus when closed.

## Work orders, debt and endings

`AnomalyContract.KINDS` contains exactly `salvage`, `audit`, `repair`, `rescue`,
`recruit`, and `credit`. Orders are ordinary `Offer.contract` values. There is
no separate wager panel or parallel accept API.

`Shop._fill` produces six offers: two weapons, two passives, and two distinct
orders. The active order aliases the purchased offer contract. Buying a second
order requires `ShopResult.REPLACE_ORDER`; the previous deposit is credited in
the quoted difference. One `ShopState` undo restores funds, offers, accepted
aliases, mission state, debt and counters atomically.

Credit is explicit: purchasing adds 30 materials and 40 debt. No ordinary failure adds debt and settlement never silently takes an installment. `ShopResult.PAY_DEBT` quotes `min(materials, debt)` with no fee, applies through the same transaction/undo path, and is reachable from the Shop ledger. Outstanding debt blocks another advance and permanent archive writes, independently of exit choice.

`Expedition.forecast` reports natural faults and endangered workers before a work order is bought. Repair/Rescue orders buy responsibility and rewards; ambient help remains possible. `world_profile` exposes bounded persistent machine, worker, witness and companion-roster records. Rescue creates a safe person, never a decoy. Deployment uses `DEPLOY_COMPANION`; the previous living ally is benched with actual HP/life and can return.

A recruited boss opens a paused `ContextChoiceUi`; `Sim.choose_negotiation` validates identity-specific terms. Cancelling returns to Pause, and Resume reopens pending terms. No hidden decline occurs.

The final fight enters `Sim.Phase.RESOLUTION` (appended numeric value4). `Sim.choose_exit` applies one explicit choice and only then enters WON and emits `run_won`:

- `released`: costs zero with clearance or 12 materials otherwise, repairs copies to100; does not erase debt.
- `collective`: requires actual living workers/crew, releases them alive and restores player health.
- `takeover`: stays in the bureau and assigns the latest retained copy as staff; Solo signs alone.

Two completed audits grant clearance and cancel current debt at audit settlement, never force an exit. At least one free exit is always available. Pending decisions save and resume, and the once-only selected outcome persists into Endless. Exact closed schemas and bounds are defined in [theme-convergence.md](docs/theme-convergence.md).

## Equipment and support contracts

`Content.MAX_WEAPON_SLOTS == 6`. Content contains 18 base weapons, 12 earned
final forms and five support weapons. A base weapon declares two canonical
`evolution_options`; `Shop.evolution_choices` filters them through Content.
`evolve_choice` requires a maxed weapon, three family pieces, an explicit target
and sufficient materials.

Weapon levels are 0–3. From stage 5, the paired weapon offer may match an owned
weapon's exact level. `Shop.combine_weapons(host, donor)` accepts only different
slots with the same canonical ID and grade. It increments the host, consumes the
donor, carries both real investment ledgers plus the assembly fee, and emits
separate host/donor presentation events. `WeaponDef.GRADE_MULTIPLIERS` is exactly
`[1.0, 1.8, 3.2, 5.5]`; assembly therefore retains about 90%, 88.9% and 85.9%
of the two input weapons' immediate DPS while freeing one slot. Offer price uses
`1.65^grade` before the stage factor. Cash refit remains a stable, deliberately
more expensive no-donor alternative, and high-price same-grade assembly may
require saving across encounters. Resale and replacement use only recorded paid
investment.

Evolution replaces the canonical weapon definition but keeps
`WeaponDef.MAX_LEVEL` and the actual paid-investment ledger, adding only the
branch fee. It never resets a final form to grade zero or creates nominal resale
value.

`SupportSystem` stores plain dictionaries with stable UID, kind, position, HP,
lifespan, cooldown, actor token, source identity, weapon, damage, charges, level
and reach. `MAX_UNITS == 12`; at most one live recruited companion is allowed.
The eight canonical kinds are hound, turret, repair station, paper tree, decoy,
and the three recruited bosses.

Support bodies can be damaged by enemy contact, zones, machines and boss
geometry. Hounds retrieve ordinary scrap/supplies without charging role energy;
paper trees have four shield/energy deliveries and no material payout. Repair
stations have six charges. Repeated fire cannot refresh an existing living
unit's HP, charges or lifetime.

## Role ability contract

`CharacterSkills.on_pickup(sim, value)` runs only for manual player collection.
It grants `4 * min(value, 5)` energy, capped at 100. Automatic end payout and
support retrieval add materials but do not invoke it.

`CharacterSkills.activate(sim)` requires wave phase, 100 energy and zero role
cooldown. It dispatches to six distinct mechanics. Energy and the six-second
cooldown are committed only after the mechanic succeeds. Role state is kept in
the bounded `role_effects` dictionary and is part of snapshot/undo validation.
The shared Echo retirement input remains independent.

## Echo merge and archive

`EchoBank.preview_merge(host, donor, trait)` is pure and detached. It never
allocates a UID or mutates input takes. `merge` confirms the preview, removes
both inputs and allocates one new stable identity. The host always keeps its
route and loadout.

| Trait | Donor contribution |
|---|---|
| `skill` | Donor retirement kind; condition becomes the lower input condition |
| `repair` | 50% of donor condition repairs the host, capped at 100 |
| `power` | One strongest eligible host weapon level; lower condition minus 15 |

Echo recordings retain the route, wave-end build, retirement skill and up to six key work events. `EchoRecorder.record_work` records successful player press/conveyor operations and at most two representative attacks, spaced eight seconds apart. Normal automatic fire adapts to current enemies. `EchoWork.step` performs eligible work only forward, consumes unavailable/muted events without backlog, and charges four condition only on success. Looper rewind retains a consumed-event high-water cursor; it cannot duplicate free work. View/audio consume `echo_work_performed` without model mutation.

Archive records are permanent Meta data. EndUi selects any retained candidate; raw DPS never decides replacement. An existing file requires an explicit comparison and confirmation, including lower-output and utility-only choices. Solo, Daily, debt, invalid gear/routes/stats and missing capacity are rejected. `EchoArchive.normalize` is the shared pure load/preview path: a real slot, at most60 condition, grade0 at opening, combat budget no more than0.75 of starter DPS and matching normalized utility stats. The stored original keeps its identity/grade. Conductor opening copy synergy and Mirror starter gear are included in actual-entry previews. Old permanent records may omit `work_actions`, decoded as an empty list in the same closed decoder.

## Snapshot v4 and atomic storage

`RunSnapshot.VERSION == 4`. The graph includes expedition, debt/outcome,
interactables, character energy/cooldown/effects, support units and next UID,
graded offers, paid investment, assembly annotations, order aliases, Echo merge
metadata, key-work cursors and rewind high-water state, archive-loaded flags, persistent world/roster/witness references, pending boss terms and final resolution. It preserves exact RNG and
shared references while accepting only known classes, canonical content and
finite bounded values.

The old 0.16 and earlier suspended-run schemas are intentionally incompatible. There is no
legacy fallback or migration branch. Permanent Meta unlocks, clues, archives
and settings remain separate.

`SuspendStore` validates capture before writing a same-directory temporary file,
flushes it, and atomically renames it. A failed write keeps both the live run and
the previous usable file. Source archive writes use the same rollback principle:
failed Meta persistence restores the prior record and toggle.

## Presentation and verification

HUD uses compact top and bottom islands. Pure `WorldArena.display_viewport`
derives a real battle rectangle from the native canvas, and Main resize applies
it to the clip and camera. At 960×540 the camera FOV adapts while actor pixels retain their
size; there is no global scale-down. Character Select pages three roles at 960
and shows all six at 1280. End, Archive, HUD and four exercised UI surfaces keep
enabled targets on-screen.

Physics spawn planning continues to use the constant 1200×600 simulation field,
so resize and presentation cannot consume or redirect gameplay RNG.
`ExpeditionInk`, boss warnings, support health, skill emblems and end fold/loot
reactions read model snapshots and have explicit caps.

Current evidence entry points are:

- `make test`, `make smoke`, and Python tooling tests;
- `tools/expedition_art_probe.gd` for current art/presentation fixtures;
- `tools/expedition_gameplay_probe.gd` for the completed integrated bilingual
  and reduced closeout flow;
- `make export` plus release auditing for actual platform artifacts.

Native probes use original1280×720 and960×540 canvases, including EN/ZH and Reduced Effects. Clinical fixtures disclose setup, use real Main/UI inputs and validate snapshots around rendering; they are not human playthroughs. `tests/probe_native_theme_ui.gd` checks bounded full rosters and decision sheets, while `tools/theme_performance_probe.gd` supplies deterministic CPU comparisons. Build and release receipts accompany the exact immutable exported commit.

Scripted evidence does not establish human balance, addictiveness, physical-controller behavior, Windows GUI behavior, notarization or universal frame-rate acceptance.

## Bureau rituals

`BureauEvents` owns the closed expedition.bureau delivery, confession, retired and work state; `BureauConfession` owns its bounded act choices. All new world targets use existing E/X interaction and the canonical model. Campaign2/6/10 announces an optional document delivery. A radius86 stamp warns1.1s in a4s cycle; the safety lever grants4s, including from actual recorded Echo work. Successful inbox delivery pays8 materials once. Failure has no surprise fee and every role can time the crossing alone.

`ShopResult.CONFESS` signs once per upcoming act. Truth automatically repairs the most-worn eligible copy (lowestUID tie) by at most12 condition, or heals up to6HP when none needs repair. Polish grants12 cash and declares the next encounter's inspection terminal/hazard. Story commits only at departure. Pending/registered/unverified outcomes remain visible across acts. A pending signature holds reroll until undone; purchase, refit and departure remain available. The existing32-state history protects the pre-signature anchor and rejects an action rather than silently evicting it.

`Meta.stage_bureau_report(sim,run_id)` upserts at most12 actual shifts, each with at most6 retired identities. Original recording stage is independent of current-run retirement stage. A retained body cannot simultaneously be a retired record. Transient switch, carry and impact signals never consume the48-entry causal world history. Event target_id distinguishes lever feedback from physical press impact.

Family-wall selection and actual entry preview share existing archive rules. The inherited-copy print is passive0.7s, validates actual bank identity and never creates an extra body. Merge/Undo ceremonies consume actual ShopResult snapshots; skill transfer, repair patch and power clamp have distinct read-only geometry. Reduced Effects/skip/pause alter presentation only. TooltipPanel/TooltipLabel use an opaque paper surface and readable ink.


The 0.18.1 event/presentation contract is documented in [paper-action-feedback.md](docs/paper-action-feedback.md). ShotInfo captures the actual weapon slot, PlayerHurtInfo separates absorbed impact and HP loss, and DamageInfo captures the target radius. These are event values rather than saved-run fields; Snapshot v4 remains unchanged.
