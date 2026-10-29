# Gameplay and presentation interfaces

This is the current 0.15 contract. Simulation owns rules and mutation. UI,
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
| Persistence | `RunSnapshot`, `SuspendStore`, `Meta`, `StoryLedger` | Snapshot v2, atomic storage, permanent unlock/archive data and route clues |
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

Credit is explicit: purchasing it adds 30 materials and 40 debt. No ordinary
failure path adds debt. Outstanding debt blocks another credit offer and Echo
archive writes. Wave settlement may pay existing debt from current materials;
tests distinguish repayment from newly created debt.

`Expedition.apply_ending_outcome` is once-only and bounded:

- `released`: selected first after two completed audits; repairs current copies
  to 100 and writes off remaining credit debt.
- `collective`: fills player health, then restores an existing recruited
  companion or spawns one when capacity permits; otherwise the bounded pending
  result is retained until capacity exists.
- `indebted`: adds exactly 24 materials and keeps the debt ledger.

The recorded outcome survives Endless and cannot be applied again.

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

Archive records are Meta data, not suspended-run data. `EchoArchive` stores one
bounded record per eligible character and protects a stronger prior record.
Solo, Daily, outstanding debt, invalid canonical gear/routes/stats, and missing
capacity are rejected. Loading occupies a real Echo slot, uses current player
stats as the baseline, caps condition at 60, and caps opening target power at
the smaller of archived power and `current player DPS * 0.75` at stage 1. The
title archive screen previews records and atomically toggles inheritance.

## Snapshot v2 and atomic storage

`RunSnapshot.VERSION == 2`. The graph includes expedition, debt/outcome,
interactables, character energy/cooldown/effects, support units and next UID,
graded offers, paid investment, assembly annotations, order aliases, Echo merge
metadata, archive-loaded flags and boss negotiation. It preserves exact RNG and
shared references while accepting only known classes, canonical content and
finite bounded values.

The old 0.14 suspended-run schema is intentionally incompatible. There is no
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

The final native evidence is EN 1280×720 (46 PNGs, 440 checks) and ZH Reduced
960×540 (47 PNGs, 449 checks), both with empty failure lists. Each profile
strictly restores the authoritative Snapshot around 43 Sim screenshots. These
are clinical fixtures, not a human playthrough. Three-platform export remains a
separate pending gate tracked in [docs/closeout-acceptance.md](docs/closeout-acceptance.md).
Scripted evidence does not establish human balance, addictiveness,
physical-controller behavior, Windows GUI behavior, notarization or universal
frame-rate acceptance.
