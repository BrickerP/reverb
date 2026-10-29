# Core gameplay rebuild (0.14)

This is an implementation contract for the approved gameplay rebuild. The game
keeps timed survival waves and the between-wave shop, in a larger scrolling
arena. Echoes wear continuously during combat playback and can be repaired or
actively retired. Godot 2D and the existing paper/ink identity remain.

## Shared ownership and state

The integration owner edits `scripts/sim/sim.gd`, `scripts/game/main.gd`, version,
export/catalog files and shared integration tests. Other lanes own their named
modules. Do not overwrite another lane's work or run the shared Godot importer
or GPU probes without coordination.

Simulation remains authoritative. UI reads quotes/profiles and commits through
simulation/shop methods. Renderer clocks, camera visibility and music never
change damage, wear, RNG or saved state. New mechanics replace the old route;
there is no parallel wave-age lifetime or generic collapse implementation.

## World and enemy lane

- `Sim.ARENA` becomes `Rect2(40,80,2400,1200)`; `Sim.VIEWPORT` is the old
  `Rect2(40,80,1200,600)` HUD-safe window. World geometry is defined by
  `WorldArena`, including a small fixed set of useful machine obstacles.
- World/recording positions remain world coordinates. The camera translates
  only drawing below the fixed HUD-safe crop, and stays within world bounds.
- `WorldArena.move_body(pos, delta, radius)` resolves world bounds/obstacles.
  `WorldArena.blocks_projectile(pos, radius)` handles machine cover.
- Spawn positions are outside the current camera neighborhood with a real
  telegraph, inside world bounds and outside obstacles. No distant outer-wall
  spawn policy that empties the pressure around the player.
- `EnemyBrain.step(sim, enemy, delta)` owns movement/attack state. Runner locks
  a warned dash, Brute warns a directional slam, Silencer warns a fixed seal
  area; Warden turns with inertia. All actual attacks have recovery/safe windows.
- EnemyState adds `brain_state`, `brain_time`, `attack_direction`, `attack_target`,
  `attack_tick`, `pin_left`, `ink_left`, `stun_left`. These are saved gameplay.
- Renderer exposes the same authoritative warning/attack geometry. Ordinary
  walking, player gait and mounted-weapon recoil share stable movement phases.

## Weapon/content lane

There are 18 shop weapons and 6 evolution forms. Existing IDs remain, with new
attack behavior where appropriate. Families have three shop weapons each:

| Family | Shop weapons | Evolution |
|---|---|---|
| sidearm | pistol, smg, stapler | twin_fangs |
| scatter | shotgun, flechette, paper_saw | flak_crown |
| marksman | rifle, longbow, hole_punch | rail_spike |
| arcane | orb, hex_bolt, ink_bottle | nova_core |
| press | stamp, mallet, cutter | hydraulic_press |
| salvage | tape_spool, rubber_band, paper_plane | redaction_engine |

WeaponDef owns actual attack style and only fields used by shipped attacks.
Distinct primitives include burst, pinning projectile, cone/cut, delayed slam,
continuous line, persistent ink/tape field, boomerang and chain/orbit attacks.
`Combat` owns their execution and bounded active fields. Shared active-state
type/API names must be reported to the integration and snapshot owners before
use. All hit paths preserve actor token, tint, weapon and attribution.

At least two real cross-weapon interactions are explicit: pinned target plus
press attack, and wet/inked targets plus arcane conduction. Emit
`Sim.combo_triggered(info: ComboInfo)` after a real combo. Limit chain depth and
budgets, do not recursively create unbounded combo hits. The shop and HUD explain
actual prerequisites and actual triggers, not just piece counts.

Character IDs are looper, solo, mirror, conductor, mender, overloader. Existing
identities remain recognizable. Mender repairs the selected deployed copy while
collecting scrap and pays less for repairs; Overloader trades faster wear for
stronger retirement. CharacterDef adds only used fields: `repair_discount`,
`wear_rate_mult`, `retirement_mult`, `pickup_repair`. Sim mirrors these at start.
New characters unlock at best wave 5 and 12 respectively.

## Echo/shop lane

- EchoTake replaces `age` with `condition: float = 100.0` and adds
  `uid: int = 0`. EchoBank allocates monotonically increasing positive UIDs;
  restoration preserves UIDs and the next counter. Actor tokens are now these
  stable take UIDs (`-1` player, `0` unknown), not process object IDs.
- Replace `Stats.ECHO_LIFESPAN` with `Stats.ECHO_DURATION`, default 120 seconds.
  Long Play adds 40 seconds, the existing longevity boon also adds seconds.
- During deployed combat playback, condition decreases by
  `100 * delta / sim.echo_duration() * sim.wear_rate_mult`. Pause and shops do
  not wear copies; rendering/offscreen status does not affect wear. Silence
  does not protect a running copy from wear. Damage does not linearly degrade.
- At zero condition, remove actor/take and emit an exhausted retirement event;
  do not award the full active retirement skill for waiting to zero.
- `EchoSystem.step(sim, delta)`, `skill_profile(take, sim)`, `retire(sim)` and
  selection helpers own rules. Sim exposes `selected_echo_uid`,
  `retire_cooldown`, `echo_duration()`, `can_retire_echo()`,
  `retire_selected_echo()`, `select_echo(uid)`, `cycle_echo(direction)`.
- Active retirement consumes the selected copy; the copy is the cost. Remove
  the once-per-wave `collapse_used` gate. A short 0.35s input cooldown prevents
  accidental repeat actions. Skills derive deterministically from recorded
  dominant weapon/style, with six visible categories (pin, stamp, cut, ink,
  return, arc). Remove universal explosion plus heal. Mirror's actual firing
  loadout and shown retirement prediction must agree explicitly.
- Emit `Sim.echo_retired(info: EchoRetirementInfo)` for active/exhausted cases;
  remove unused `echo_recorded` / `echo_collapsed` pathways and direct
  `Sim.merge_takes` bypass. Record arrival remains an actual wave/shop event.
- Repair through Shop transaction/undo: restore up to 40 condition, cost derived
  from missing condition with the existing material economy and role discount.
  Merge keeps the lower condition, combines recorded route/loadout through the
  existing bank rule and gives a new stable UID. No free condition restoration.
- Full weapon slots still allow weapon offers and the existing replacement UI.
  ShopState preserves IDs, condition, counters and all exact undo state.

## Persistence and narrative lane

`RunSnapshot.capture(sim)` / `restore(data)` round-trip the complete active run:
world actors and aliases, projectiles, active fields, warning plans, both RNGs,
timers, recorder accumulator/samples, copy UIDs/condition/playback/cooldowns,
shop offers/locks/history, contracts/boons, role and narrative state. Stable IDs
must retain delayed attacks from retired copies. Derived spatial caches rebuild.
Use canonical content references; preserve 64-bit RNG values exactly. Save only
known simulation data/types, never arbitrary executable paths from a save file.

`SuspendStore` atomically saves the snapshot plus Main envelope and validates
before replacing a live session. Save/return and Continue use this same path.
Language reloads preserve the active run through this path; no silent wave
restart, HP refill, reroll or lost recording. Save errors are visible and keep
the live run. Main owns its screen/delay/context envelope integration.

`StoryLedger` supplies a short optional receipt after meaningful wave/retirement
milestones and an archive of discovered clues. The thread is who signs the
player's own disposal orders. Narrative progress extends the existing Meta file;
no new cloud service. Actions and choices select clues; combat never requires
reading a long modal. Expose localized receipt/archive text and real triggers.

## UI/audio lane

HUD always identifies the selected copy, condition, predicted retirement effect
and offscreen direction. Short Space/RB executes; holding opens a paused
selection wheel, release only selects. Add device-correct labels, complete
keyboard/mouse/controller focus and Reduced Effects states.

Pause has Save and Return; title has Continue, with meaningful save errors.
Shop exposes repair/merge costs and outcomes, offers at full capacity, current
combos and next prerequisites. Six characters fit the selection screen.

Music is original melodic material, distinct from the existing mechanical
ambient loop: a crooked piano/low-woodwind/office-percussion theme with combat,
pressure, shop and boss treatments. Retain dry restrained effects, independent
music/effect controls, pause/mute/reset and bounded voices. Dynamic intensity is
presentation-only and uses real wave/threat states.

## Verification

New behavior gets happy/boundary tests. Exact suspend must match before/after
both in battle and shop, including subsequent RNG-driven progression. Gameplay
has intentionally changed, so the former byte-identical old-version oracle is
not the acceptance criterion. Rendering remains read-only and deterministic.

Native probes cover large-world edges/obstacles, offscreen copies, all attack
styles/combos, enemy windup/impact/recovery, held selection vs accidental retire,
wear/repair/exhaustion, long-session gait at 30/60/120/144 sampling, story and
music transitions, language changes and suspend/resume. Final builds retain the
strict actual-ZIP macOS signing gate and explicit platform limitations.
