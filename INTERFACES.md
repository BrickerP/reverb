# Mechanism / Presentation Interfaces

Status: **M2 rich events, M5 Paradox phase 2, M6 family mastery, M7 echo-touched elites, M8 weapon selling, M9 offer locking, M10 anomaly contracts, M11 temporal rifts, M12 echo collapse, M13 endless mode, M14 endless escalation, M15 item sets, M16 ascension, M17 endless boss, M18 ascension identities, M19 survival shield, M20 daily anomaly, M21 endless boons, M22 echo organization undo, M23 echo refresh, and quote/apply shop UI are implemented.**

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
- `ShopState` now also captures the complete `EchoBank` (samples, weapons, levels, stats, wave,
  age, tint, merged, tint counter). Undo rebuilds equivalent `EchoTake` objects; discard UI
  references must be refreshed.
- Echo discard/merge are now undoable through the same history (`Shop.discard_echo`,
  `Shop.merge_echoes`, actions `echo_discard`/`echo_merge`).

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

Historical presentation starting baseline: `0276f67` / v0.1.35. The latest fixed
mechanics cutoff integrated here is `075a2bd`; the current runtime/export source and
integration split are tracked in `docs/presentation-coverage.md`. Mechanism changes
must be merged or cherry-picked as commits, not copied as uncommitted files.

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

## 9. Paradox phase 2: twin timelines

At 50% health the final boss splits into two bodies. The remaining health is divided
between them, not added: the split is a target-priority change, not a second health bar.

Mechanism API:

- `boss_phase: int` — `1` before the split, `2` after it.
- `boss_shards: Array[EnemyState]` — one body in phase 1, two in phase 2; dead bodies stay
  in the array until the next wave, so use `boss_alive_count()` rather than `size()`.
- `boss_original_max_hp: float` — the pre-split maximum used by the combined HUD bar.
- `boss_health_ratio() -> float` — total living health divided by the original maximum.
- `boss_alive_count() -> int`, `boss_total_count() -> int`.
- `boss_origin() -> Vector2` — first living body position; use this for silence/victory
  effects instead of assuming `boss.pos`.
- `boss` remains the first body for compatibility. After the split its `max_hp` is the
  local phase-2 body scale; do **not** draw an overall bar from `boss.hp / boss.max_hp`.

Signals:

- `boss_phase_changed(phase)` — once per split; phase 2 only.
- `boss_shard_spawned(enemy)` — the second body has been added and is active.
- `boss_shard_defeated(enemy, remaining)` — every boss body death, including a phase-1
  direct kill; `remaining` is the number of living bodies after the death.
- `boss_enraged(enemy)` — exactly once, when the first of two bodies dies.
- `boss_defeated` — only after all bodies are dead. A dead `boss` alone is no longer enough.
- `echoes_silenced(duration)` — the split also emits a shorter transition silence; audio/view
  may reuse the existing silence treatment.

Presentation requirements:

- HUD must use `boss_health_ratio()`, `boss_phase`, and the body counters. The phase-2 title
  is `hud.boss_phase2`; the bar shows the combined total, with one pip per living body.
- View/audio must use `boss_origin()` for effects while one body may be dead, and must not
  end the run on `boss.dead`; wait for `boss_defeated`/phase `WON`.
- The two bodies use the existing Paradox art. Do not add new enemy IDs or art for this slice.
- Silence and summons share one cadence; the split must not double either cadence.

Validation contract:

- A hit that crosses 50% splits exactly once and preserves the health after that hit.
- Splitting does not reroll or advance randomized wave planning.
- One death emits `boss_shard_defeated` and `boss_enraged`; the survivor has the documented
  speed/damage multiplier.
- Both deaths emit `boss_defeated`; a lethal hit above 50% may skip phase 2 intentionally.

## 10. Family mastery

Four pieces of one family replace the old generic +3% attack speed with a family rule:

| Family | Mastery | Mechanism |
|---|---|---|
| sidearm | Gunslinger | `Combat.family_cooldown_mult` returns `0.94` at 4+ pieces (6% shorter firing interval) |
| scatter | Point blank | `Combat.family_mastery_damage` returns `1.15` when the target is within 160 |
| marksman | Overpenetration | `Combat.family_mastery_pierce` returns `+1` projectile pierce |
| arcane | Resonance | `Sim.echo_power()` adds `0.08` while 4+ arcane weapons are equipped |

Rules:

- The 2-piece `+3% damage` and 6-piece `+3% damage` effects are unchanged.
- Four pieces no longer grant a generic attack-speed bonus to scatter/marksman/arcane.
- Sidearm haste is included in `OfferCard.weapon_dps`; scatter range, marksman pierce and
  arcane echo power are situational or echo-side, so the UI must explain them in the family
  summary instead of promising them as flat DPS.
- `Sim.echo_power()` is the display source for the arcane bonus; do not recompute it in UI.
- No new weapon IDs, art, drops or RNG streams were added for this slice.

Presentation requirements:

- `BuildPanel` family summary must show the active 4-piece mastery text for each family.
- `hud`/shop core echo power should use `sim.echo_power()`, not the raw stat, so the arcane
  mastery is visible.
- Weapon detail may show base DPS; do not imply scatter/marksman/arcane mastery is already
  included in single-target DPS.

## 11. Echo-touched elites

From wave 10 to 19, `WaveDirector.plan` upgrades exactly one existing spawn into an elite.
It does not add spawn cost, a new enemy ID or new art; it is a deterministic modifier on an
existing body.

Data flow:

- `SpawnEvent.elite_kind` → `PendingSpawn.elite_kind` → `EnemyState.elite/elite_kind`.
- `Sim` applies the elite stat package and modifier in `_apply_elite`.
- `EnemyState` exposes `shield_arc_value()`, `shield_reduction_value()`,
  `death_radius_value()` and `death_damage_value()`. These fall back to `def` and allow
  runtime elite overrides without mutating shared `EnemyDef` resources.
- `drop_mult` multiplies the pickup value; elites use ×2.

Rules:

- Base elite: HP ×1.7, speed ×1.08, damage ×1.15, radius ×1.12, drop ×2.
- `overclocked`: additional speed ×1.3 and damage ×1.1.
- `bulwark`: shield arc 120°, reduction 0.25.
- `volatile`: death radius 64, death damage 6.
- `splitter`: on death spawn two non-elite copies of the same enemy at 22% of the elite
  max HP, 55% damage and 90% speed. Children keep the host `def.id`, use normal radius and
  cannot split again.
- The final wave has no regular elite; the boss is never marked elite.
- Elite selection is deterministic for a seed/wave; it does not add a new reward roll.

Presentation requirements:

- Draw an elite aura in the family-independent color map: overclocked cyan, bulwark blue,
  volatile orange, splitter green. Pending spawn telegraphs must use the same color.
- Use `EnemyState.death_*_value()` and `shield_*_value()` in the arena painter; do not read
  `def.death_radius`/`def.shield_arc` directly for elites.
- The volatile death uses the existing bomber explosion event/audio path; no new event type.
- No HUD label is required; color, double ring, shield fan and death circle carry the rule.

Presentation integration correction: death explosions keep `ExplosionInfo.BOMBER` and
`bomber_explosion` for existing effects/audio, while `last_damage_source` and
`PlayerHurtInfo.source` identify the actual `EnemyDef.id`. This corrects result/log
attribution for volatile non-bombers without changing damage or gameplay rules.

## 12. Weapon selling

`ShopResult.SELL` is an equipment action that liquidates one equipped weapon without an
offer. It is available only in the shop and only when at least two weapons are equipped.

Mechanism API:

- `Shop.quote(ShopResult.SELL, sim, null, index)` → a result whose `cost` is the negative
  refund, or a failure with reason `invalid`/`last`.
- `Shop.apply(ShopResult.SELL, sim, null, index)` → removes the weapon and adds
  `Shop.resale_total(w, level)` materials.
- `Shop.sell_weapon(sim, index)` remains the direct compatibility method.
- `ShopState` already captures materials, weapons, levels, cooldowns, items, offers and
  rerolls; undo restores a sale exactly.
- A sale emits one `weapon_changed` event for the removed slot with `after_id = ""` and
  `reason = SELL`; undo emits the inverse event at the same insertion index. The
  size-change helper avoids false events for shifted later slots.
- Selling the last weapon is blocked with reason `last`; buy a replacement first if the
  player wants to pivot away from their only weapon.
- Selling uses the same refund formula as replacement; it does not create a new price or
  RNG path.

Presentation requirements:

- BuildPanel shows a sell button per equipped weapon with the exact refund; the last
  weapon's button is disabled and reads `shop.sell_last`.
- The button must call `Shop.apply(ShopResult.SELL, ...)`, not mutate arrays locally.
- After a successful sale, refresh the build panel and keep focus valid; the freed slot
  shows the normal empty/drop target.
- Undo must restore the weapon, its level, cooldown and materials, and rebuild all cards.

Presentation integration correction: removal/insertion events retain the acted-on slot
through `ShopState.weapon_change_index`, which is event metadata only and is neither
restored nor serialized as simulation state. Size changes emit an explicit empty
side, so middle-slot and duplicate-ID sales never masquerade as shifted replacements.
Refunds, sale eligibility, state restoration and history limits remain unchanged.

## 13. Offer locking

One offer can be held across rerolls and the next shop. Locking is a shop decision, not an
equipment transaction, and does not consume materials or push undo history.

Mechanism API:

- `Offer.locked: bool` is the per-offer flag.
- `Shop.locked_offer()` returns the unsold locked offer, or `null`.
- `Shop.toggle_lock(sim, offer) -> bool` locks/unlocks; locking a second offer moves the
  hold, so at most one offer is held. Sold offers cannot be locked.
- `Shop.reroll(sim)` keeps the locked offer and fills the remaining `OFFER_COUNT` slots;
  `Shop.roll(sim)` also keeps it when the next shop opens.
- Locked prices do not change while held.
- `ShopState` captures/restores `Offer.locked`, so an equipment undo after a purchase
  preserves the hold at the time of that transaction. Lock toggles themselves are not undo
  steps.
- If the held offer is bought, it is sold and stops being held; the next roll fills a fresh
  slot. Unlock explicitly releases it.

Presentation requirements:

- Each unsold offer card exposes a `Lock`/`Unlock` action; do not bake lock state into the
  purchase button.
- Locking a second offer must visibly move the hold; only one card may show the locked state.
- After a reroll, the held offer remains and should keep its card position/visibility.
- The full-slot reason on a card is the short `shop.full_short`; the detailed
  `shop.full` remains available in the footer/tooltip so the lock button does not squeeze
  the price.
- Locking is free and must not show a material transaction animation.

Presentation-order correction: `_fill` retains the held offer during generation for
duplicate prevention, then restores its previous clamped slot. The held object,
price, generated offer set, RNG consumption and refresh cost are unchanged.
The local sale-event index annotation remains separate from lock snapshot state.

## 14. Anomaly contracts

From wave 3 to 19, each shop may offer one optional contract. It is a risk/reward shop
decision, not an equipment transaction.

Mechanism API:

- `AnomalyContract` kind: `clean` (no damage next wave), `clear` (kill `target` enemies),
  or `hunt` (kill the wave elite). `hunt` is only generated from wave 10 onward.
- `Shop.contract` is the current shop contract; `Contract.accepted` is its local spent flag.
- `Shop.accept_contract(sim) -> bool` requires shop phase, an unaccepted contract,
  no existing `sim.active_contract`, and enough materials. It deducts `deposit` once and
  assigns `sim.active_contract`.
- Contract goals read `Sim.wave_damage_taken`, `Sim.wave_kills`, and
  `Sim.wave_elite_kills`; those counters reset in `Sim.start_wave`.
- `Sim._end_wave` evaluates the active contract before computing `last_wave_earned`;
  success adds `reward` before interest, failure adds nothing. The deposit is never
  refunded on failure.
- `Sim.contract_resolved(contract, success, reward)` fires once per evaluated contract.
- `Sim.last_contract_done/success/reward` stay available for the following shop; they reset
  on the next `start_wave`.
- `Shop.roll` generates a fresh contract; `Shop.reroll` keeps the current one. Contract
  state is not part of `ShopState` undo history.

Presentation requirements:

- Keep the contract strip between offers and the reroll/start row; show goal, deposit,
  reward, and Accept in one line.
- After accepting, show ACTIVE and disable Accept; do not charge again.
- Show the previous contract result in the shop warning line; combine it with the
  overcapacity warning when both are present.
- Do not imply a contract is free: the deposit is material cost and a failure loses it.
- Contract text must include "next wave" so the goal is not mistaken for the current shop.

## 15. Temporal rifts

Waves 12–19 add avoidable arena hazards. Rifts are floor effects, not enemies: they do not
enter `EnemyState`, do not provide drops, and are not drawn with enemy art.

Mechanism API:

- `TemporalRift` fields: `pos`, `radius`, `telegraph`, `active`, `tick`; constants
  `TELEGRAPH_TIME=1.5`, `ACTIVE_TIME=3.0`, `RADIUS=80`, `TICK_TIME=0.75`.
- `Sim.rifts: Array[TemporalRift]` is the live hazard list. It is cleared at wave end
  and in `start_wave`.
- Waves 12–19 start with `RIFT_FIRST_DELAY=8s`, then spawn every `RIFT_INTERVAL=16s`.
  Rifts spawn 0–70px from the player using the dedicated `hazard_rng`, so combat crit/spread
  RNG is untouched.
- The warning is 1.5s; activation emits `rift_activated`. Active ticks deal
  `3 + 0.15 × wave` damage only when the player center is inside `radius + PlayerState.RADIUS`.
- Rift damage sets `last_damage_source = &"rift"` and emits `player_hurt` /
  `player_hurt_info`; it deliberately does **not** set `player.iframes`, so it cannot
  shield the player from enemy contact.
- Signals: `rift_spawned(rift)`, `rift_activated(rift)`, `rift_ended(rift)`.
- The boss wave never spawns rifts. Expired rifts are compacted after the active timer.

Presentation requirements:

- Draw rifts below pickups/enemies: warning is an empty ring with spokes and a tightening
  inner ring; active is a translucent fill with rotating arcs. Use purple, distinct from
  echo tints, elite aura colors and enemy colors.
- Do not add an enemy ID, HUD text or new health bar for rifts.
- If the player dies to a rift, `last_damage_source` is `rift`; end-screen uses the
  localized `enemy.rift` label rather than an unknown key.
- Reduced-motion mode may drop the spokes/rotating arcs but must keep the warning ring and
  active fill clearly distinct.

## 16. Echo collapse

One active echo can be sacrificed during a wave. This is a permanent resource spend, not a
temporary silence.

Mechanism API:

- Input action `collapse_echo`, bound to Space and controller right shoulder by `Controls`.
- `Sim.can_collapse_echo()` is true only in `Phase.WAVE`, when `collapse_used` is false and
  at least one echo is active.
- `Sim.collapse_oldest_echo()` consumes `echoes[0]` and its `EchoTake` from `EchoBank`,
  reindexes the survivors, marks `collapse_used`, deals damage in a 180 radius around the
  echo's last position, heals 15% max HP, and emits one explosion event with
  `effect = &"echo_collapse"`.
- Burst damage is `max(12, take.power() * echo_power() * 3 * synergy_damage_mult())`; it
  counts as player damage (`source = -1`) so it does not leave a stale echo index.
- `Sim.collapse_used` resets in `start_wave`; one use per wave.
- Signals: `echo_collapsed(pos, color, radius)`. The existing `explosion_info` event carries
  the echo tint, radius and `echo_collapse` effect; no new ExplosionInfo kind is required.
- No echoes (e.g. Soloist) means no action and no input consumption.

Presentation requirements:

- HUD shows `SPACE` plus `hud.collapse` only when `can_collapse_echo()` is true; hide it
  immediately after use. Controller binding is RB.
- Play the burst as an echo-tinted explosion at the echo position; use the existing
  weapon-explosion audio path unless a distinct cue is added later.
- Do not show a confirmation dialog; the cost is permanent, so keep the hint explicit.
- Main's input handler must ignore the action while paused, modal, in shop, or after the
  run ends.

## 17. Endless mode

After a normal win, the player may continue the same build into waves 21+ instead of ending
the run. Endless is an explicit opt-in; normal 20-wave results and balance are unchanged.

Mechanism API:

- `Sim.endless: bool` and `Sim.boss_rush: bool` default false and reset in `start_run`.
- `Sim.begin_endless() -> bool` only from `Phase.WON`, not already endless. It sets
  `endless = true`, keeps the run seed/build/bank, sets `wave = FINAL_WAVE`, clears boss
  shards/rifts, switches to `Phase.SHOP`, and rolls a fresh shop.
- `Sim.begin_boss_rush() -> bool` uses the same entry conditions and shop setup, sets
  `boss_rush = true`, rolls a **starting boon offer** into `pending_boons`, and jumps only
  on subsequent waves. If `echo_capacity() <= 0`, it also adds
  `BOSS_RUSH_SOLO_SHIELD = 10` max shield, fills it, and sets
  `boss_rush_bonus_boon` for a second sequential three-choice offer. Main must show each
  boon before opening the shop. `Sim.next_wave_number()` returns `wave + 5` under boss rush
  and `wave + 1` otherwise; `start_next_wave` uses it.
- `Sim.is_boss_wave(n = wave)` is true for the normal wave 20, or for endless waves
  `n > 20` where `n % 5 == 0` (25, 30, 35…).
- `start_wave(n)` uses that helper: normal wave 20 and endless boss waves append Paradox;
  endless wave 21+ otherwise has no boss. Endless boss waves use a 0.55 trash-budget
  multiplier, normal final uses 0.35.
- `step` requires the boss to die on every boss wave; normal endless waves end by the 60s
  timer. An endless boss does not auto-end at 60s.
- Endless boss HP scales by `1 + 0.20 × (n - 20)` before ascension; damage keeps the normal
  wave damage scaling. The phase-2 split and all boss signals are unchanged.
- Wave planning/budget/hp/damage continue from `WaveDirector`; endless waves also keep
  one elite per wave, rifts on the 8s/16s cadence, and continuation contracts (clear target
  caps at 40). Normal waves 1–20 are unchanged.
- `AnomalyContract.make(wave, rng, endless = false)` only allows wave 20+ when `endless`;
  `Shop.roll` passes `sim.endless`.
- `RunLog.append` includes `endless: bool` and `boss_rush: bool`. Main removes the
  just-written wave-20 win line when continuing, then writes one final endless death line
  with the endless wave; Meta still records the wave-20 win/unlocks once.
- `Sim.boons_taken` records chosen boon IDs in application order; `Sim.echo_refreshes`
  counts successful refresh transactions. Both reset at `start_run`.
- `RunLog.append` includes `boons` and `echo_refreshes` alongside `endless`/`boss_rush`.
- `Meta.record_endless(sim)` persists `best_endless` or `best_boss_rush` separately; normal
  `best_wave` is not raised by an endless death. The character-select summary displays both
  values when non-zero.

Presentation requirements:

- End screen shows `Continue · Endless` and `Boss Rush` only on a normal win; both hidden
  on losses and endless deaths. Boss Rush opens the existing boon modal before the first
  shop. The shop start button must use `Sim.next_wave_number()` so Boss Rush shows
  25/30/35… rather than 21/22/….
- HUD endless branch shows `hud.endless` with the current wave and the 60s timer; it hides
  the 20-wave progress pips. Endless boss waves show `hud.endless_boss` plus the existing
  boss health bar and phase-2 pips, still without the 20-wave pips.
- On endless death, end title/stats use `end.endless_lose` / `end.endless_run`; Play again,
  Change character, retry seed and log folder remain available.
- Main must call `ArenaView.clear_victory()` before opening the endless shop so the victory
  overlay does not persist into the next wave.
- Endless never emits `run_won` a second time.

## 18. Item sets

Three small completion rewards use the existing 11 items; no new art, drops or item IDs.

Mechanism data:

- `Content.ITEM_SETS` and `Content.item_sets()` define:
  - `echo`: spare_deck, long_play, loud_speaker (3/3) → `echo_power +0.02`, plus a
    two-material discount on echo refresh (`Shop.echo_refresh_cost`).
  - `gunsmith`: sharp_edge, quick_trigger, long_barrel, lucky_coin (3/4) → `damage_pct +0.02`,
    `attack_speed_pct +0.02`, and every sixth player shot is a guaranteed crit.
  - `field`: iron_heart, regen_patch, sneakers, magnet (3/4) → `shield +8`, refilled
    each wave, plus an 8-damage / 72-radius knockback shockwave when the shield breaks.
- `PlayerState.add_item()` calls `_apply_item_sets()` after applying the item's own mods.
- `PlayerState.set_bonus_applied` records which sets have paid out, so adding a fourth member
  cannot apply the same bonus twice. Max-HP set bonuses also add current HP.
- `Sim.player_shots` counts only player-origin volleys, resets at `start_run`, and drives the
  Gunsmith sixth-shot guaranteed crit. Echo volleys increment `shot_sequence` but not
  `player_shots`.
- For the Field Kit, `Sim._hurt_player` emits a one-shot shockwave when positive shield
  reaches zero. It damages/knocks back enemies within 72 radius and emits an
  `ExplosionInfo` with `effect = "shield_burst"`; no extra event type is required.
- `Hud.gunsmith_remaining()` returns `-1` without the set, otherwise `6 - player_shots % 6`;
  HUD text is `CRIT IN N` or `NEXT SHOT CRITS`. It never mutates combat state.
- `ShopState` captures/restores `items`, `stats` and `set_bonus_applied`; undo after the
  third item removes both the item and the set contribution.

Presentation requirements:

- BuildPanel shows only sets already started, as `Name n/required`; when complete it
  appends the localized bonus text.
- Item cards keep their existing individual descriptions. The current offer DPS preview
  does not simulate completing a set; do not claim it does.
- Set bonuses are small numeric completion rewards, not hidden affinity or drop bias.
- No new icons, audio or item IDs; use the existing item icons.

## 19. Ascension

Optional difficulty levels 0–3 are selected on the character select screen and apply for
the whole run, including endless.

Mechanism/API:

- `Meta.ascension` is the saved selected level; `Meta.max_ascension()` returns
  `min(3, wins)` and `Meta.set_ascension(value)` clamps and saves.
- `Sim.ascension` defaults 0. Main sets it before `sim.start_run()` from Meta, or forces 0
  for the daily challenge.
- Enemy scaling at materialization (A1 and above; A2/A3 do not add another stat layer):
  - HP × `1.10`;
  - damage × `1.10`;
  - speed × `1.05`.
  Bosses and elites use the same multipliers; wave scaling is applied first. A0 is unchanged.
- Level rules also change:
  - A2+: `Sim.ascension_rift_wave()` is 10 (vs 12) and
    `Sim.ascension_rift_interval()` is 14s (vs 16s).
  - A3: `Sim.ascension_elite_count()` is 2; `WaveDirector.plan` accepts an `elite_count`
    argument and marks that many distinct events.
- `RunLog` records `ascension`.
- A0 keeps wave planning, shop prices, drops, echo power and item sets unchanged.
- Normal `ascension = 0` keeps all existing stats/balance unchanged.

Presentation requirements:

- Character select shows an `Ascension N` button beside Seed. It is disabled when
  `max_ascension() == 0`; clicking cycles 0..max and persists immediately.
- Tooltip explains A1's HP/damage/speed increase, A2 rifts, A3 two elites, and that wins unlock levels.
- Do not offer in-run ascension changes; retry/restart uses the saved Meta selection.
- Daily challenge always starts at 0.
- The end screen need not add a new line for ascension; RunLog remains the evidence source.

## 20. Survival shield

The Field Kit's 3-piece bonus is a per-wave shield pool. It is not a global defense
stat and is not sold as an item.

Mechanism API:

- `Stats.SHIELD` (flat, default 0) is the shield cap; only the Field Kit adds it.
- `PlayerState.shield` is the current pool; `PlayerState.max_shield()` reads the stat.
- `Sim.start_wave()` sets `player.shield = player.max_shield()` after positioning.
- All player damage should call `Sim._hurt_player(amount, source, effect, pos, direction,
  grant_iframes = true)`:
  - shield absorbs first; HP receives `amount - absorbed`;
  - `PlayerHurtInfo.amount` is HP damage, `PlayerHurtInfo.absorbed` is shield damage;
  - contact/bomber hits grant the normal contact iframes; rift hits call with
    `grant_iframes = false` so standing in a rift does not shield the player from enemies.
- Shield does not persist through the shop; the next wave refills from the stat.
- `ShopState` still captures stats and set flags, so undo restores the shield cap; the
  current pool is not a shop transaction.

Presentation requirements:

- HUD draws a thin cyan bar below the HP bar whenever `max_shield() > 0`, filling by
  `shield / max_shield()`; keep the empty track visible when depleted.
- Do not add a new health-like numeric label; the bar is the shield readout.
- Shield absorption should not change enemy visuals, drops or boss logic.
- Reduced-motion settings do not need special shield animation.

## 21. Daily anomaly

Daily challenge gets one rule derived from its date seed. It affects only Daily runs; normal
runs stay empty and unchanged.

Mechanism API:

- `DailyAnomaly.ALL`: `echo_surge`, `riftfall`, `twin_hunt`, `fortune`, `riftstorm`,
  `glass_cannon`.
- `DailyAnomaly.for_seed(date_seed)` deterministically picks one.
- `Sim.daily_modifier: StringName` defaults empty and is set by Main before `start_run`.
- Effects:
  - `echo_surge`: `Sim.echo_power()` adds 0.15.
  - `riftfall`: `ascension_rift_wave()` = 8 and `ascension_rift_interval()` = 14.
  - `twin_hunt`: `ascension_elite_count()` = 2.
  - `fortune`: `Sim.material_drop_multiplier()` = 1.5; pickup value is rounded and floored
    at 1.
  - `riftstorm`: `ascension_rift_wave()` = 8 and `ascension_rift_interval()` = 8.
  - `glass_cannon`: `DailyAnomaly.apply_start(sim)` adds +0.30 damage and removes 20% of
    the starting max HP before the run begins; current HP is clamped to the new maximum.
- Daily runs force `ascension = 0`; retrying the daily seed preserves the date anomaly.
- `Meta.record_daily` tracks `daily_streak` and `daily_last_win_seed`; a win on the next
  calendar day increments the streak, a skipped day resets it to 1, and repeat wins on the
  same day do not add. The character-select Daily button appends the streak when non-zero.
- `RunLog` records `daily_modifier`.
- Normal/Ascension/Endless runs pass an empty modifier.

Presentation requirements:

- Character select `Daily` button tooltip shows `select.daily_anomaly` plus the localized
  anomaly title. Keep the button's best-score label intact.
- Do not add a second Daily card or a run-selection screen.
- The anomaly uses existing visuals; no new icons or audio are required.
- A daily retry must use the same anomaly as the original date seed.
- History rows read `endless`, `boss_rush` and `daily_modifier` from RunLog to show the mode;
  Replay still starts the normal seeded run and does not restore an endgame mode.

## 22. Endless boons

After each endless boss kill, the player chooses one permanent run upgrade before the next
shop. Normal wave 20, non-boss endless waves and all normal runs never create boons.

Mechanism API:

- `Boon.ALL`: damage, haste, vitality, echo, shield, fortune, precision, slipstream,
  magnet, eternity, second_wind.
- `Boon.roll(rng, 3, sim = null)` samples three distinct IDs; when `sim` is supplied and
  `sim.echo_capacity()` is 0, it removes `echo` and `eternity` before sampling.
- `Sim.pending_boons: Array[StringName]` is set by `_end_wave` only when `endless` and
  `is_boss_wave()`; `Shop.roll` has already produced the shop.
- `Sim.boon_reroll_cost()` = `15 + 10 × boon_rerolls`; `Sim.reroll_boons()` spends
  materials, increments the counter, replaces the three choices and returns false when the
  pending array is empty or materials are insufficient. The counter resets after each boss
  offer and at `start_run`.
- `Sim.choose_boon(index)` applies one and clears the pending array; failed indices leave
  the offer intact. Effects are immediate and permanent for the run:
  - damage +10%; haste +10%; vitality +15 max/current HP; echo +10%; shield +5 cap/current;
    fortune +30 materials; precision +5% crit; slipstream +20 move speed; magnet +30 pickup
    range; eternity +1 echo lifespan; second_wind adds one charge. Echo lifespan is read
    from `Stats.ECHO_LIFESPAN` immediately; no boon changes echo capacity or the Soloist's
    zero-slot identity.
- `Sim.second_wind_charges` starts at 0 each run. When a real HP hit would drop the player
  to 0 or below, one charge is consumed and HP is set to 1. Shield absorption happens first;
  a fully absorbed hit does not consume a charge. Charges stack and are not refunded on undo.
- Boons are not equipment undo transactions and are not recorded by ShopState.
- `Sim.pending_boons` is not serialized; there is no mid-run save.

Presentation requirements:

- Main shows the `BoonUi` modal and does not open the shop while `pending_boons` is non-empty.
  Boss Rush zero-slot characters receive a second offer after the first choice; keep the
  modal open until `pending_boons` is empty.
- BoonUi shows exactly three buttons with localized name/description; no cancel is allowed.
- When `BoonUi.open` receives a `Sim`, it also shows one `Reroll <cost>` button. It must
  call `Sim.reroll_boons` through Main, then rebuild the modal; disabled when unaffordable.
- Choosing applies via `Sim.choose_boon` and then opens the already-rolled shop once no
  follow-up offer remains.
- The modal pauses simulation; Hide/quit flows close it without applying.
- No new art is required; reuse UiTheme panels/buttons.

## 23. Echo organization undo

Echo discard and overdub merge are shop transactions and share the existing equipment Undo
history. Reroll/start-wave lock boundaries are unchanged.

Mechanism API:

- `Shop.discard_echo(sim, take) -> ShopResult` and
  `Shop.merge_echoes(sim, a, b) -> ShopResult`; actions
  `ShopResult.ECHO_DISCARD` / `ShopResult.ECHO_MERGE`.
- Both capture a full `ShopState`, mutate the bank, push history, emit
  `shop_action_resolved` / `shop_history_changed`.
- `ShopState` now captures/restores every EchoTake: samples, weapon IDs, levels, stats, wave,
  age, tint index, merged flag and bank tint counter.
- Undo rebuilds new EchoTake objects. Any UI/tool holding old take references must re-read
  the bank after undo.
- Direct `Sim.discard_take` / `Sim.merge_takes` remain compatibility methods but do not
  create history.
- Boons, contracts, rerolls and wave starts are outside this undo history.

Presentation requirements:

- EchoPanel discard/merge actions must call the Shop transaction methods, not mutate the
  bank directly.
- After an echo undo, rebuild EchoPanel rows and selection state; stale take references are
  invalid.
- Undo button already reflects `Shop.can_undo()`; no separate echo undo control.

## 24. Echo refresh

Shop-only material sink: reduce one echo's age by one wave. It does not change the route,
weapons, stats or tint, and it uses the same Undo history as equipment.

Mechanism API:

- `Shop.ECHO_REFRESH_BASE = 5`, `Shop.ECHO_REFRESH_PER_AGE = 2`;
  `Shop.echo_refresh_cost(take, sim = null) = 5 + 2 * max(0, age)`, minus 2 when the
  echo set is complete, floored at 1.
- `Shop.echo_refresh_block_reason(sim, take)` returns `invalid`, `new` (age 0) or `poor`.
- `Shop.refresh_echo(sim, take) -> ShopResult`; action `ShopResult.ECHO_REFRESH`.
  On success it subtracts the cost, decrements `age`, captures `ShopState`, pushes history
  and emits the same shop signals as discard/merge.
- There is no per-shop refresh limit. Repeated refreshes are allowed while age > 0 and
  materials remain; undo restores the exact prior materials/age bank.
- New echoes (age 0) cannot be refreshed.

Presentation requirements:

- EchoPanel exposes `refresh_requested(take)` and one `Refresh <cost>` button for each
  aged take; disabled when the player cannot afford it.
- Do not recompute the cost in UI; call `Shop.echo_refresh_cost(take, sim)` so set discounts
  are reflected.
- After refresh/undo, rebuild rows; age pips and the button disappear when age reaches 0.
- No new art is required; reuse the existing button style.
