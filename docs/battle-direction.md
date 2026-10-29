# Battle direction

The 0.15 battlefield connects paper-puppet acting to real expedition rules.
Warnings explain where damage will occur, support bodies communicate ownership
and mortality, and role/Echo effects preserve their causal source. Decoration
must never move a hit, hide a mission, or imply a reward the model did not grant.

## Spatial hierarchy

The standard 1280×720 canvas shows a 1200×600 follow-camera window inside the
2400×1200 world; smaller native canvases derive their own battle rectangle. Five
cover machines and the expedition press, conveyor, recycler and mission targets
use model geometry. Camera movement, shake, corpses, projectile marks and
particles stay clipped to the battle window.

The HUD uses separate paper islands:

- top-left health and Echo condition;
- top-center act/stage, boss health or Endless stage;
- top-right mission phase and cash/debt context;
- bottom weapon slots, role energy/readiness and contextual controls.

The lower row clears the battle world instead of covering actors. Native resize
derives a real camera rectangle from the canvas: 960×540 adapts FOV while keeping
actor pixels at their authored size, with no global scale-down. Workshop copies
and Character Select page explicitly; End, Archive and HUD keep controls inside
the native canvas. Physics spawns still use the constant 1200×600 field so the
responsive presentation cannot change gameplay RNG.

Stable movement phases drive player, enemies and Echoes. Mounted-weapon recoil
does not replace locomotion. Optional motion freezes on pause. Reduced Effects
keeps all warnings, hazards, support health, selected-Echo state, mission
progress, interaction availability and input labels.

## Boss language

Each act boss has an authored silhouette and a different locked primitive:

| Boss | Warning | Active hit | Acting cue |
|---|---|---|---|
| Foreman | Point lock, 1.1 seconds | Circular press at the locked target | Raises and commits the heavy press body |
| Collector | Direction lock, 0.95 seconds | Swept segment during a 0.65-second charge | Compresses, then drives forward along the warning |
| Paradox | Point lock, 1.1 seconds | Perpendicular cross centered on the target | Folds into opposing cut axes before impact |

`EnemyBrain.attack_profile()` supplies warning and active geometry to
presentation. The same locked target/direction supplies damage. Supports use
their real body radius in these tests. Warning, impact and recovery remain
separate states.

Paradox's phase-two split remains physical. Capacity reserves two boss slots;
presentation may stitch the halves visually but cannot invent a beam, move a
shard, or mark the encounter complete while one body lives.

## Machines and work-order targets

Interactive machines use a shared availability profile. The prompt shows the
current `E / X` label from InputMap and appears only when the player is in range.

- The press displays its 1.1-second warning, then the same radius used against
  player, enemies and supports.
- The conveyor shows direction and active time; its ink motion follows actual
  push state.
- The recycler shows the real 8-material cost and cannot animate success when
  unaffordable or cooling down.
- Salvage parts, audit terminals, the repair target, rescue target and Boss
  negotiation use distinct mission-letter/office-machine marks.

Audit interaction exposes the danger zone it creates. Repair visibly disables
the faulty press. Rescue health loss comes from actual enemy contact. Recruit
keeps the defeated Boss present during the eight-second negotiation window;
autofire does not play an ordinary loot/death beat first.

## Support ownership and failure

Support art covers hound idle/attack, turret idle/fire, repair station, paper
tree early/grown and decoy. Recruited bosses reuse their identity with a friendly
outline. Every body exposes HP and remaining-life state without looking like a
cash pickup.

Spawn, attack, repair, production, damage, destroy, retrieve and expire visuals
come from `support_event` snapshots. Source slot, stable Echo token, tint and
weapon ID survive delayed attacks and save/restore. Presentation never resolves
an old slot to a different Echo.

Natural expiry folds or powers down. Destruction uses a distinct hurt/failure
beat. A paper tree shows limited deliveries of shield/energy; it never emits a
cash shower. The single-companion and 12-unit caps are rules, not visual-only
crowd reduction.

## Role abilities and Echo actions

Role readiness is driven by the authoritative 0–100 energy meter and six-second
cooldown. Each successful ability has a bounded, recognizable emblem:

- Looper: backward route ticks and a brief clock-fold;
- Solo: one paper dash strip and parry crease;
- Mirror: a two-point swap stitch;
- Conductor: one selected-Echo anchor and three relay pulses;
- Mender: a real repair-station placement;
- Overloader: a stamp burst scaled by the retiring Echo's condition.

Failed activation shows no spent-energy flourish. `Shift / LB` remains visually
separate from `Space / RB` Echo retirement.

Echo bodies show condition, merge trait, archive origin, silence and rewind.
Merge preview keeps the host path and renders only the chosen donor trait. The
preview is not a temporary live body. Active retirement uses the actual skill
profile; natural exhaustion uses a smaller terminal beat and grants no full
skill.

## End and archive beats

Boss defeat and final outcome are separate beats. Released, collective and
indebted receipts use the applied model outcome, not inferred route flavor:

- released repairs current Echoes and clears credit debt;
- collective heals and restores or schedules one companion;
- indebted adds 24 cash while leaving debt visible.

The end screen has an explicit archive button and a live best-Echo path preview.
Daily, Solo and unpaid-debt states visibly disable it. A protected stronger
record returns distinct feedback from a storage failure. The title archive view
previews one record per eligible character and exposes the inheritance toggle.

## Bounded presentation

`BattleDirector` caps normal corpse snapshots at 24. `ArenaView`, `WeaponInk`,
skill emblems, support reactions and expedition marks each keep explicit bounded
arrays. Reduced Effects lowers optional counts without removing required
geometry. Session detach, new wave, pause and terminal states clear or freeze the
appropriate caches.

Sound maps all 35 weapon profiles onto the existing 35 dry SFX files. Support,
boss and ability mappings may reuse cues with controlled pitch/volume; they do
not create unlimited voices or change combat timing. Five synchronized
96-second music arrangements continue to follow actual phase and threat state.

## Verification

- `tests/test_expedition_presentation.gd` checks support art, boss warning/hit
  primitives, shared interaction availability, bounded rendering and distinct
  role emblems.
- `tests/test_closeout_main.gd` drives real Main inputs, modal blocking, archive
  actions and save/continue.
- `tools/expedition_art_probe.gd` captures EN/ZH and 1280×720/960×540 fixtures.
- `tools/expedition_gameplay_probe.gd` is the integrated native gameplay probe
  replacing the obsolete 0.14 core probe.

The gameplay probe completed EN 1280×720 (46 PNGs, 440 checks) and ZH Reduced
960×540 (47 PNGs, 449 checks), both with empty failure lists. Each profile
strictly restores the authoritative Snapshot around 43 Sim screenshots. These
scripted fixtures are evidence of the production input/UI/model path, not a
human playthrough. Export status is recorded separately in
[closeout-acceptance.md](closeout-acceptance.md). Automated fixtures do not prove
human readability speed, balance, addictiveness, physical-controller behavior,
Windows GUI behavior or target-hardware frame rate.
