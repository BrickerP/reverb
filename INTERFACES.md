# Mechanism / Presentation Interfaces

Status: **M2 events emitted; current Shop UI still uses legacy methods.**  
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

M1 adds a unified shop bridge. The mechanism API is now:

- `Shop.quote(action, sim, offer = null, index = -1)` → `ShopResult`
- `Shop.apply(action, sim, offer = null, index = -1)` → `ShopResult`
- `Shop.undo(sim)` → `ShopResult`
- `Shop.can_undo()` / `Shop.clear_history()`

Signals on `Sim.shop`:

- `shop_action_resolved(result)`
- `shop_history_changed(can_undo)`

The old direct methods remain for compatibility:

- `Shop.buy(sim, offer)`
- `Shop.replace_weapon(sim, offer, index)`
- `Shop.upgrade_weapon(sim, index)`
- `Shop.evolve_weapon(sim, index)`
- `Shop.reroll(sim)`

New UI must use `quote/apply` for equipment actions so history is recorded. Direct methods are migration-only.

Replacement quotes include the base resale plus 50% of the material spent on the old weapon's
upgrades. `Shop.resale_total(w, level)` is the display/quote source; `Shop.resale_value(w)` is
only the base value.

## 4. Presentation event types

These types are now emitted:

- `ShotInfo` via `shot_fired_info(info)`, once per weapon volley; old `shot_fired(source)` remains.
- `DamageInfo` via `damage_event(info)` for direct hits and explosions; old `enemy_hit(...)` remains. `reduced` marks a shield-reduced hit.
- `ExplosionInfo` via `explosion_info(info)` for weapon and bomber explosions; old `explosion(...)` remains.
- `WeaponChangeInfo` via `weapon_changed(info)` for applied equipment actions and undo; one event per changed slot. Removed slots report `after_id = ""`.
- `PlayerHurtInfo` via `player_hurt_info(info)` for enemy contact and bomber explosions; old `player_hurt(amount)` remains. It carries source, amount, position, direction, effect and lethal.

Compatibility rule: old signals remain valid. New presentation should prefer the rich
events; current view/audio can migrate independently.

## 5. Undo semantics (implemented)

- Undo scope: **equipment operations only** for the first slice.
- Buy, replace, upgrade, and evolve performed through `apply` push exact `ShopState` snapshots.
- `undo` restores the full state from the snapshot, not a recomputed refund.
- Failed operations do not lock history.
- A successful reroll clears prior history; the new offers start a new history.
- A successfully started wave clears history.
- Undo never rerolls or advances RNG.
- `ShopState.restore` rebuilds `Offer` objects; UI must discard old offer references and re-read the restored list after undo.
- Echo discard/merge undo is **out of scope** until explicitly specified.

## 6. Current known gaps

- Shop operations still mutate directly when UI uses the legacy methods; only `apply` records undo history and emits `weapon_changed`.
- Undo transaction/history is implemented in mechanism API, but the current Shop UI still calls legacy methods and has no undo control.
- Combat rich events are emitted, but current view/audio still subscribe to the old signals.
- Drag/drop is presentation-owned and is not part of the mechanism API yet.
- UI currently recalculates display strings but reads costs/validation from Shop functions.

## 7. Shared-file rule

If a mechanism task needs `loc`, `main.gd`, `project.godot`, export config, or version changes,
list them in the delivery note before editing. Codex integrates both branches from a fixed
commit; mechanism commits do not create tags or releases.

## 8. Codex integration checklist

Integration source: `mechanics/conductor` at `5a1e8c1`. Codex's current workspace base is
`0276f67` / v0.1.35. The mechanism branch contains the Conductor commit plus M0–M4 and should be
merged or cherry-picked as commits, not copied as uncommitted files.

### Shop UI migration

1. Replace direct `buy` / `replace_weapon` / `upgrade_weapon` / `evolve_weapon` calls with
   `Shop.quote(...)` for preview and `Shop.apply(...)` for commitment.
2. Drag/drop may only call `apply` after the mechanism has validated the target; UI must not
   calculate cost, family effects, or refunds.
3. Add an Undo control bound to `Shop.can_undo()` / `Shop.undo(sim)`. After undo, discard all old
   `Offer` references and rebuild/refresh offer cards before animating.
4. Subscribe to `Sim.shop.shop_action_resolved` and `shop_history_changed`; disable Undo when the
   history is empty or the shop is locked.
5. A successful reroll or start-wave clears history; failed actions do not.
6. Build replacement/upgrade/evolution displays must use `Shop.resale_total`,
   `Shop.upgrade_cost`, and `Shop.evolution_cost`, not local formulas.

### Presentation event migration

Prefer the rich events for new animation/audio; keep the old signals as fallback during migration:

- `shot_fired_info`: weapon-specific fire sound, muzzle origin, direction/target, volley count.
- `damage_event`: impact position, crit, shield-reduced hit, weapon identity.
- `explosion_info`: distinguish weapon explosion from bomber explosion.
- `weapon_changed`: animate card/slot in, replace, upgrade, evolution, and undo; removed slots have
  `after_id = ""`.
- `player_hurt_info`: hit direction, enemy source, lethal feedback.

### Shared files and integration risks

- `scripts/core/loc*.gd`: both branches add text; reconcile keys rather than overwrite tables.
- `scripts/ui/character_select.gd` and `scripts/ui/build_panel.gd`: presentation-owned, but the
  mechanism branch contains a 4-card layout change and one resale-total line; merge them explicitly.
- `project.godot`, `export_presets.cfg`, `tests/test_run_log.gd`: version metadata must be aligned
  with the final integrated release commit.
- `scripts/game/main.gd`: shared boundary; no mechanism changes were made for M1/M2, but event
  subscriptions and undo wiring belong on the presentation side.

### Acceptance before release

- Multi-step buy/replace/upgrade/evolve then Undo restores materials, stats, HP, weapons, levels,
  sold offers and rerolls exactly.
- Undo after a successful reroll is unavailable; failed reroll does not clear history.
- Starting a wave clears history.
- Drag/drop and click paths produce identical `ShopResult` and state.
- Rich events and old signals agree on a seeded smoke run.
- Mechanism tests + smoke stay green; Codex adds UI tests for Undo, drag/drop, and event wiring.

