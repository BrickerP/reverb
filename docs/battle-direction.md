# Battle direction (0.12.0)

This batch gives the existing paper world action and threat hierarchy. It retains
the UI structure, simulation rules, collision, damage, economy and RNG sequence.

## Authored poses and geometry

Eight character direction sheets and seven enemy sheets now use four columns and
two rows: 120 authored poses. Common actors retain idle/left step/right step/hurt
in cells 0-3. Cells 4-5 supply event-driven action/recovery, and 6-7 crumple/flatten.
Contact enemies display the impact pose on the real contact event, then recover;
they do not acquire a new attack delay or harmless windup.

The Original retains intact/roar/left half/right half in cells 0-3; 4-5 depict a
tear transition, 6 is whole-body crumple and 7 is a generic flattened fragment.
Real shard bodies remain visible and at their authoritative positions during the
low-opacity transition. A phase-one one-shot and a phase-two shard death use
different starting poses.

Production manifests own `columns` and `rows`; the catalog never guesses layout
from image proportions. `frame_region` uses a common crop across the sheet,
`idle_region` provides live calibration and UI thumbnails, and `frame_pivot`
provides each pose's measured foot anchor. Scale stays tied to the idle reference:
a wide terminal pose cannot make a living body or selection portrait smaller.

## Causal rendering

`BattleDirector` stores bounded value snapshots, not mutable enemy references.
Normal corpses are capped at 24 and Reduced Effects at 8. Shooting reactions are
rate-limited so rapid fire cannot replace every walking pose. New run, new wave,
unbind and explicit pause clear or freeze the appropriate presentation state.

The kill signal has one typed `EnemyDeathInfo` payload at the actual kill point,
before compaction. `PlayerHurtInfo.source_uid` identifies the actual contact body.
`EchoSilenceInfo` distinguishes contact, boss cast and phase transition: a nearby
ink bottle cannot accidentally trigger a boss roar.

Shots capture `actor_token` and `source_tint` at fire time and carry them through
projectiles, direct damage, splash, explosions and death snapshots. Numeric
`source` remains the original statistic/slot; rendering never uses it to look up
a current copy. A removed copy's in-flight projectile keeps its original identity.
Tokens are opaque signed 64-bit values: -1 means player, 0 unknown, and every
other value can identify a copy. Godot RefCounted instance IDs can be negative.
These session tokens are not persistent save identifiers.

## Weapons, copies and hazards

`WeaponInk` batches projectile heads by weapon identity and keeps neutral heads
for unidentified developer projectiles. Twelve authored glyph/muzzle/impact
profiles remain distinct when optional trails are disabled at high load.
Non-weapon blasts stay in the arena renderer so effects are not drawn twice.

`EchoInk` derives wear from actual age and effective lifespan; merge staples,
silence, rewind and slot patterns supplement color. `ThreatInk` reads model shield
arcs, explosion radii and rift telegraph/active timers. Stitch lines between boss
halves are decorative, never a newly damaging beam.

Existing kill-cue voice and cooldown budgets are retained, with body-specific
pitch/weight. This is not a replacement of the complete music or ambient design.

## Verification tools

- `tools/battle_invariants_probe.gd`: deterministic gameplay snapshots for normal
  progression, mid-wave elites/rifts, boss phase two and eight copies. Run the same
  script against the previous commit and compare bytes; exclude presentation
  tokens, wall clocks, version and UUID fields.
- `tools/battle_art_probe.gd`: real Main/Sim window timeline, all weapons and enemy
  deaths, eight copies, silence/collapse, boss split and player terminal beat.
  Supports movie capture and Reduced Effects; missing eight-pose actors fail.
- Full tests, lifecycle checks, scene smoke and actual rendering pressure probes
  protect pause, budgets, attribution and simulation state.

All visual fixtures use isolated data files and staged durability. They are not
human-playtest or balance evidence. Physical controller, Steam Deck and native
Windows/Linux GUI testing remain separate device verification.
