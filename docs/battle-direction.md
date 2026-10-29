# Battle direction

The 0.14 battlefield connects paper-puppet action to actual weapon behaviors,
enemy attacks and copy condition. Threats must explain where and when a hit can
occur; decorative acting must preserve locomotion and ownership.

## Acting and spatial hierarchy

Nineteen eight-pose actor atlases cover six characters in front/back views and
seven enemy identities. Common actors have idle, left/right step, hurt,
preparation/follow-through and terminal poses. The Original has separate roar,
tear and shard drawings. The merchant's four expressions form a separate atlas.
Manifests declare layouts; runtime never guesses frame count from proportions.
Shared crops, idle calibration and per-pose foot pivots keep scale and placement
stable through wide action/death poses.

The follow camera shows a 1200×600 portion of the 2400×1200 world below the fixed
HUD. Five machine obstacles provide real cover. The clip contains camera motion,
shake, corpses, projectile heads and particles. Offscreen culling cannot change
actor stepping, weapon cadence, copy wear or attacks. HUD direction markers
keep offscreen copies actionable.

Stable movement phases drive player, enemy and copy steps together with mounted
weapons. Recoil is local to the fired weapon; rapid fire cannot consume every
walking pose. Idle breath does not rotate or displace a still puppet. Event
poses and optional motion freeze on pause; Reduced Effects retains actual
warnings, active weapon fields, selected-copy identity and functional feedback.

## Causal enemy and weapon geometry

`EnemyBrain` owns warned target/direction, attack and recovery. Runner commits
to its warned dash, Brute to a directional slam, Silencer to a fixed seal area,
and Warden turns with inertia. The same authoritative model geometry supplies
rendered attack shapes and real collision. Warning, impact and recovery are distinct readable
states; animation does not invent a harmless delay around contact damage.

`ThreatInk` also reads shield arcs, death-explosion radii and rift timers.
`AttackField` geometry explains delayed slams, continuous cuts, ink/tape fields,
chain links and orbit attacks. `WeaponInk` keeps all 24 weapon identities in
muzzle, head and impact profiles, with plain fallback only for unknown developer
projectiles. Optional trails can reduce under load without hiding required
warnings or persistent damaging fields.

Boss tear acting follows the real phase event. Actual phase-two shard bodies
remain at their model positions; persistent shard index selects the appropriate
half, and a decorative stitch line never becomes a damage beam.

## Copy identity and retirement

Copy bodies show condition, merged status, silence and rewind. HUD and wheel
identify the selected copy. Their prediction comes from `EchoSystem.skill_profile`, the same
profile used by the actual skill. Mirror uses its current firing loadout for both.
Low condition changes wear marks, never shot damage. Natural exhaustion removes
the copy and has its own restrained terminal beat; active retirement uses the
specific pin, stamp, cut, ink, return or arc effect.

All shot and hit paths carry stable identity: player -1, unknown 0, copy positive
`EchoTake.uid`. Source tint and weapon travel with delayed fields/projectiles,
including after retirement, undo or suspend/resume. Presentation must not look
up a new actor by an old statistical slot. Typed `ShotInfo`, `DamageInfo`,
`ExplosionInfo`, `EnemyDeathInfo`, `PlayerHurtInfo`, `EchoSilenceInfo`,
`EchoRetirementInfo` and `ComboInfo` describe real events at their causal point.

`BattleDirector` stores bounded value snapshots rather than mutable enemy
references. Normal corpses cap at 24, Reduced Effects at eight. Session detach,
new wave and pause clear or freeze the appropriate presentation state. Common
and protected sound voices remain bounded; skill and combo cues must retain the
same source attribution as their visual effect.

## Verification

- `tools/core_gameplay_probe.gd` runs real Main/Sim scenarios for six roles,
  attack styles, combinations, enemy warning/attack/recovery, scrolling/cover,
  copy wear/repair/exhaustion, held selection, stable gait, story and music.
  `REVERB_LANG`, `REVERB_PROBE_REDUCED` and `REVERB_PROBE_SIZE` select profiles.
- `tools/main_language_probe.gd` checks real scene reload with an exact run;
  `tools/music_lifecycle_probe.gd` exercises actual playback objects.
- `tools/presentation_stress_probe.gd` and `tools/frame_probe.gd` measure the
  declared rendered fixture and its budgets. Full tests and smoke protect
  current gameplay, source identity and lifecycle.

Fixtures declare staged durability, positions and offers. They are neither
human playtests nor balance measurements. Exact future progression after a
snapshot is required; byte identity with an older gameplay version is not.
Physical controllers, Steam Deck, Windows/Linux GUI, subjective listening and
lower-end hardware still require their own acceptance evidence.
