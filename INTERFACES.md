# Mechanism / Presentation Interfaces

Status: **M0 contract frozen; not wired to gameplay yet.**  
Baseline: `v0.1.36` / `d3d62b3`  
Owner: mechanism side (`scripts/sim/**`, `scripts/data/**`, `scripts/echo/**`)

This file defines the contract Codex can design against. It does not claim that undo or the
new events are implemented. M1 adds the shop transaction/undo behavior; M2 emits the combat
events. Existing signals remain available during migration.

## 1. Ownership

| Area | Owner |
|---|---|
| `scripts/sim/**`, `scripts/data/**`, `scripts/echo/**`, rule tests | mechanism |
| `scripts/view/**`, `scripts/ui/**`, `scripts/game/audio.gd`, visual/audio assets | presentation |
| `scripts/game/main.gd`, `loc`, `project.godot`, export config, version | shared; announce before editing |

UI must call mechanism methods and read results. It must not reimplement costs, damage,
family bonuses, or undo state. Presentation reacts to events after the state is committed.

## 2. ShopState

`ShopState` is the exact equipment/shop snapshot for one undo step:

- `materials`, `hp`, `stats`
- weapon ids, levels, cooldowns
- item counts
- offer kind/id/price/sold
- shop reroll count
- phase and wave

`ShopState.capture(sim)` and `restore(sim)` are implemented and round-trip tested.

It intentionally does **not** capture the RNG stream. Equipment actions must not consume
randomness, and undo must never reroll. Reroll is a lock boundary, not an undoable equipment
action.

## 3. ShopResult

`ShopResult` is the result of one requested shop operation:

- `action`: `buy`, `replace`, `upgrade`, `evolve`, `reroll`, `undo`
- `ok`, `reason`
- `cost`, `index`, `offer_id`
- optional `before_state`, `after_state` (`ShopState`)

M1 will add a unified `quote/apply` bridge. Until then, the existing methods remain:

- `Shop.buy(sim, offer)`
- `Shop.replace_weapon(sim, offer, index)`
- `Shop.upgrade_weapon(sim, index)`
- `Shop.evolve_weapon(sim, index)`
- `Shop.reroll(sim)`

Existing quote/validation functions (`block_reason`, `upgrade_cost`,
`upgrade_block_reason`, `evolution_cost`, `evolution_block_reason`) stay the source of truth.
UI reads them; it does not duplicate the formulas.

## 4. Presentation event types

These types are defined but not emitted yet:

- `ShotInfo`: source, weapon_id, origin, direction, count, level, sequence
- `DamageInfo`: source, weapon_id, target_uid, pos, amount, crit, reduced, hit_dir, effect
- `ExplosionInfo`: kind (`weapon` / `bomber`), source, weapon_id, pos, radius, color, effect
- `WeaponChangeInfo`: index, before/after id and level, reason, ok

Compatibility rule: add new signals and keep old signals until presentation has migrated.
Planned additions:

- `shot_fired_info(info)` alongside `shot_fired(source)`
- `damage_event(info)` alongside `enemy_hit(...)`
- `explosion_info(info)` alongside `explosion(...)`
- `weapon_changed(info)` from shop actions
- `shop_action_resolved(result)` and `shop_history_changed(can_undo)`

The old signals remain valid for current view/audio. New presentation should prefer the rich
events once emitted.

## 5. Undo semantics (M1 target)

- Undo scope: **equipment operations only** for the first slice.
- Buying, replacing, upgrading, and evolving push exact `ShopState` snapshots.
- Undo restores the full state, not a recomputed refund.
- Failed operations do not lock history.
- A successful reroll locks/clears prior history; the new offers start a new history.
- A successfully started wave clears history.
- Undo never rerolls or advances RNG.
- Echo discard/merge undo is **out of scope** until explicitly specified.

## 6. Current known gaps

- Shop operations still mutate directly and emit only `purchased` with no payload.
- Undo transaction/history is not implemented.
- Combat events do not carry weapon/origin/direction/source-kind information.
- Drag/drop is presentation-owned and is not part of the mechanism API yet.
- UI currently recalculates display strings but reads costs/validation from Shop functions.

## 7. Shared-file rule

If a mechanism task needs `loc`, `main.gd`, `project.godot`, export config, or version changes,
list them in the delivery note before editing. Codex integrates both branches from a fixed
commit; mechanism commits do not create tags or releases.
