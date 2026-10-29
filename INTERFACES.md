# Gameplay and presentation interfaces

This is the current 0.14 contract. Simulation is authoritative; menus, drawing,
audio and camera code read its state and submit explicit actions. They must not
change damage, wear, economy, random streams or the result of a saved run.

## Ownership and entry points

| Layer | Canonical entry points | Responsibility |
|---|---|---|
| Main | `scripts/game/main.gd` | Input, screens, pause, modal priority, lifecycle and persistence envelope |
| Simulation | `scripts/sim/sim.gd` | Run/wave state, authoritative step order, actors, economy and events |
| World | `WorldArena`, `WaveDirector`, `EnemyBrain` | Collision/cover, local spawn planning, phase pacing and enemy attacks |
| Weapons | `Content`, `WeaponDef`, `Combat` | Canonical definitions, actual attacks, fields, status interactions and attribution |
| Copies | `EchoRecorder`, `EchoTake`, `EchoBank`, `EchoActor`, `EchoSystem` | Recording, stable identities, playback, condition, selection and retirement |
| Transactions | `Shop`, `ShopState`, `ShopResult` | Quotes, commits, replacement and exact undo |
| Persistence | `RunSnapshot`, `SuspendStore`, `Meta`, `StoryLedger` | Exact suspension, atomic storage, local unlocks and discovered clues |
| Presentation | `ArenaView`, `ArenaPainter`, `BattleDirector`, `GameAudio` | Bounded, read-only visual/audio reactions |

New run, unbind, reload and Continue detach prior session listeners before
binding the next session. Wave start clears the relevant presentation caches
while retaining session subscriptions. Simulated actors, cooldowns and RNG come
from the authoritative session.

## World, movement and wave pacing

- `Sim.ARENA = WorldArena.BOUNDS = Rect2(40, 80, 2400, 1200)` is the world.
  `Sim.VIEWPORT = Rect2(40, 80, 1200, 600)` is the fixed HUD-safe drawing window.
- `WorldArena.camera_rect(focus)` and `camera_offset(focus)` clamp the follow
  camera. Recording samples, attacks and model positions stay in world space.
- `move_body(pos, delta, radius)` sweeps and slides against bounds and five fixed
  machines; `move_straight` resolves straight-line motion. `body_clear` validates
  placement and `blocks_projectile` supplies cover checks.
- Spawn planning uses the current camera neighborhood, player distance and clear
  geometry. Pending spawns have a real 0.8-second telegraph before activation.
- `WaveDirector.phase_profile(time, duration)` supplies localized phase identity
  and intensity. Cohorts occupy 0–24%, 36–60% and 72–90% of the wave; rendering and
  music read these same phases rather than inventing separate pacing clocks.
- `EnemyBrain.step(sim, enemy, delta)` owns approach, warned direction/target,
  attack and recovery. Runner dash, Brute slam and Silencer seal geometry are
  authoritative. `attack_profile(enemy)` supplies Runner/Brute shapes; Silencer
  rendering reads the saved `EnemyZone` warning/active geometry. Warden's facing
  has limited turn speed. Enemy warning/status timers are saved.
- A supply pickup may appear once at 45% duration on non-Boss waves divisible by
  three. Its 8-second lifetime and `15 + wave` reward are model state. It requires
  collection during combat and is excluded from ordinary wave-end collection.

## Weapons and hit identity

Content has 18 offered weapons and six earned evolution forms in six families:
`sidearm`, `scatter`, `marksman`, `arcane`, `press`, `salvage`. Every shipped
weapon, item, enemy and character has an explicit presentation catalog key.

`Combat.step_weapons` / `fire` create actual projectile, burst, pin, cone, slam,
line, ink, tape, boomerang, chain and orbit attacks. `AttackField` stores delayed
or persistent work as a value snapshot: owner identity, weapon, level, position,
direction, damage, status, cadence and remaining lifetime. `Projectile` carries
its own source identity and return/flight state. Active limits are 192 fields,
1,200 projectiles and eight chain targets; enemy seal zones are capped at 12.
An action requiring persistent capacity must reject before consuming its copy
when the relevant budget is full.

`Combat.combo_profile(weapons)` reports prerequisites for the build UI. A real
press hit on a pinned target triggers `pin_press`; a non-ink/tape arcane hit on
an inked target triggers `ink_arc`. Bounded extra hits never recursively spawn
an unlimited chain. `Sim.combo_triggered(info: ComboInfo)` is emitted only after
the interaction occurs, with target UID, source, tint, weapon, affected count
and bonus damage.

Every shot, delayed field, projectile and hit preserves `actor_token`,
`source_tint` and `weapon_id`. **-1 is the player, 0 unknown, positive tokens are
stable `EchoTake.uid` values.** The numeric `source` remains the statistical slot;
it must not be used to recover a current copy's identity. A removed copy's
in-flight or delayed attacks retain their original token and tint through save.

## Copy condition, selection and retirement

`EchoBank.add` allocates monotonically increasing positive UIDs. Restore retains
them and the next counter; no runtime object ID becomes a saved actor token.
`EchoTake.condition` starts at 100. `Stats.ECHO_DURATION` defaults to 120 seconds.
During deployed combat playback, `EchoSystem.step` applies:

```
condition -= 100 * delta / sim.echo_duration() * sim.wear_rate_mult
```

Pause, selection wheel and shops do not step combat. Offscreen copies and
silenced playback still wear. Condition does not scale damage. At zero,
`EchoSystem` removes actor and bank entry and emits an exhausted event without
awarding the full active skill.

`Sim.selected_echo_uid`, `select_echo(uid)`, `cycle_echo(direction)`,
`can_retire_echo()` and `retire_selected_echo()` are the action surface.
`EchoSystem.skill_profile(take, sim)` is the HUD/wheel prediction and execution
input. It chooses the highest level-DPS weapon; Mirror uses the same live
loadout/levels/stats as its actual fire. Styles map to six skills:

| Styles | Skill |
|---|---|
| projectile, burst, pin | pin |
| slam | stamp |
| cone, line | cut |
| ink, tape | ink |
| boomerang | return |
| chain, orbit | arc |

An accepted active skill consumes the selected copy, sets a 0.35-second input
cooldown and emits `echo_retired(info: EchoRetirementInfo)`. The payload contains
`reason` (`active` / `exhausted`), UID/token, wave, position, condition, tint,
kind, weapon and profile. Active retirement has no once-per-wave gate and no
universal explosion/heal. Recording arrival is the actual wave/shop transition.

Main records a Space/RB press. Releasing before 0.24 seconds retires; crossing
0.24 seconds pauses simulation and opens `EchoSelectionWheel`. Wheel release
only calls `select_echo` and resumes. Cancel closes without retiring. The wheel
supports mouse, keyboard and left stick; HUD shows selected condition, predicted
skill and offscreen direction with device-correct labels.

## Shop transactions and undo

UI reads `Shop.quote`, repair/merge quotes and block reasons, then commits through
Shop. `ShopResult` carries action, success, reason, cost, slot/offer identity and
before/after state. Reactions use `shop_action_resolved` and
`shop_history_changed`; presentation must not replace a functional error message
with merchant flavor text.

- Equipment uses `apply`, upgrade/evolve/sell methods and `undo`.
- Copies use `repair_echo`, `discard_echo` and `merge_echoes`; `EchoPanel` emits
  requests, never mutates the bank directly.
- `echo_repair_amount` is `min(40, 100 - condition)`. Cost is ceil(amount ×0.25),
  with the existing echo-set reduction and role discount, minimum one. A full
  copy, invalid membership/phase or insufficient materials returns a reason.
- Merge joins routes and up to eight highest level-DPS weapons, retains the lower
  condition and assigns a new UID. It does not restore condition for free.
- Full player weapon slots retain weapon offers and use explicit replacement.
  Upgrade/evolution/refund values come from Shop, not duplicated UI arithmetic.
- `ShopState` retains materials, HP/stats/items, loadout/levels/cooldowns, copy
  samples/UIDs/condition/counters/selection, playback actors, offers/locks and
  rerolls. Undo rebuilds objects; views must re-read bank entries after undo.
- Undo does not reroll RNG. Reroll and wave start clear history. Contracts and
  boon choices are separate from equipment/copy undo.

Boon choices must resolve before opening the already-rolled shop. Invalid choice
or unaffordable reroll preserves the pending offer. Boss Rush's extra zero-slot
choice remains a pending offer; Continue must reopen it. Zero-slot characters
cannot receive echo-only rewards.

## Exact suspension and language changes

`RunSnapshot.capture(sim)` returns a versioned, bounded known-type object graph;
`restore(data)` returns a validated Sim or null with `last_error`. The codec
preserves shared aliases, including boss/shard references, copy actors/bank,
active contract/shop and undo history. Canonical content is encoded by kind/ID.
Derived spatial caches rebuild after restore.

The graph includes both RNGs, world positions, plans, warning/attack timers,
projectiles/fields/zones, recorder accumulator/samples, copy UID/condition,
playback/cooldowns/selection, role/mode, pickups, shop, contracts, pending/taken
boons and narrative choices. Integers and signed 64-bit RNG seed/state use decimal
strings; floating-point values use their exact eight-byte binary64 hex encoding,
not rounded JSON numbers. Validation rejects non-finite values, unknown classes,
invalid references, schema mismatch, disconnected rows and multiple Sim roots
before restoring a live session. Saves cannot name executable scripts or load
arbitrary object classes.

`SuspendStore.save(sim, envelope)` captures and validates before writing a
same-directory temporary file, flushes, then atomically renames it. The file is
`user://suspended_run.json` (test override: `REVERB_SUSPEND`), capped at 32 MiB.
Failure retains the live run and the prior usable file. `load()` validates before
Main swaps sessions. There is one current snapshot format, without a parallel
legacy run-restore path.

Main's envelope preserves character/daily identity, pause/context, record/end
beats, shop visibility, run elapsed time/context and unlock text. Save and Return,
Continue, window-close autosave and language reload all use this path. Continue
restores a battle, shop transition or pending boon without healing, rerolling or
restarting the wave. Language reload returns to Settings over the restored
session. A save error stays visible and prevents the requested exit/reload.

`StoryLedger` records short wave/repair/retirement/exhaustion/Boss clues. Current
receipt and run choices are snapshot state; discovered clue IDs extend the
existing Meta file. Reading or dismissing receipts never changes combat or RNG.

## Rendering, sound and lifecycle

`ArenaView` draws the world below a fixed clip equal to `Sim.VIEWPORT`; camera
translation and shake stay inside it. Culling only changes draw work. Collision,
attacks and copy wear remain independent of camera visibility. `BattleDirector`
uses bounded value snapshots and stable locomotion phases; fast weapon fire must
not continuously replace walking poses. `ThreatInk` uses authoritative attack
and hazard geometry; `WeaponInk` and `EchoInk` retain weapon/copy identity.

`GameAudio.music_profile` reads real phase, nearby threats, attack states, Boss
and health. Five original 96-second arrangements share score time and crossfade
for 1.2 seconds using two fixed music players. Pressure has hysteresis and a
short hold. The existing 35 effects use 12 fixed voices (seven common, five
protected), priorities, cooldowns and bounded envelopes. Master/music/effect
gains are independent. Pause freezes music transport and stops disallowed
effects; mute preserves transport; rebind clears old session voices/fades.
Neither audio nor rendering consumes a gameplay RNG.

## Verification and delivery

`make test` and `make smoke` cover rules, modal flow and lifecycle. Dedicated
probes are `tools/core_gameplay_probe.gd` (native Main/Sim, bilingual/reduced
profiles), `tools/main_language_probe.gd`, `tools/music_lifecycle_probe.gd`,
`tools/presentation_stress_probe.gd` and `tools/frame_probe.gd`. New gameplay is
verified against its current contract, including identical future progression
after suspend/restore; old-version byte identity is not a gameplay criterion.

`tools/export_release_audit.py` stages a fixed Git commit and checks 92 runtime
resources (48 PNGs, three fonts, 35 cues, ambient and five music tracks) plus 25
provenance/license files, including `audio/music/score.json`. It extracts the
actual macOS ZIP into a new directory and gates on `codesign --verify --deep
--strict --all-architectures`; the Godot built-in ad-hoc signature is integrity
protection, not Developer ID distribution or Apple notarization. Windows builds
are unsigned. Export startup and scripted input do not establish Windows/Linux
GUI, physical-controller, Steam Deck, subjective audio or hardware performance
acceptance.
