# Battle direction

The 0.18 battlefield connects paper-puppet acting to real expedition rules.
Warnings explain where damage will occur, support bodies communicate ownership
and mortality, and role/Echo effects preserve their causal source. Decoration
must never move a hit, hide a mission, or imply a reward the model did not grant.

The current action pass is defined in [paper-action-feedback.md](paper-action-feedback.md):
pin, stamp, cut, ink, return and arc have distinct release gestures and contact
results across all 35 weapon profiles. Dark local edges and paper deformation
make contact readable without enlarging collision bodies or adding a global
hit-stop. A confirmed actor token, equipment slot and weapon ID select exactly
one mounted tool; delayed output without a known slot never guesses a duplicate.
Full shield absorption uses a defensive clamp and shield sound, while actual HP
loss uses the body-hurt path.

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
keeps the defeated Boss present while simulation waits for an explicit choice;
there is no running negotiation countdown. Autofire does not play an ordinary
loot/death beat first. A committed recruitment tears the old badge and places a
temporary paper badge on the actual new companion.

## Support ownership and failure

Support art covers hound idle/attack, turret idle/fire, repair station, paper
tree early/grown and decoy. Recruited bosses reuse their identity with a friendly
outline. Every body exposes HP and remaining-life state without looking like a
cash pickup.

Spawn, attack, repair, production, damage, destroy, retrieve and expire visuals
come from `support_event` value snapshots. Stable helper UID, Echo owner token,
target identity and actual HP/life/charges identify the body and result.
Repairs follow still-living recipients by type and UID, and retain captured
positions after a recipient leaves. Concurrent repair and damage results do
not overwrite each other. Presentation never resolves an old slot to a
different Echo.

Natural expiry folds or powers down. Destruction uses a distinct hurt/failure
beat. A paper tree shows limited deliveries of shield/energy; it never emits a
cash shower. The single-companion and 12-unit caps are rules, not visual-only
crowd reduction.

## Role abilities and Echo actions

Role readiness is driven by the authoritative 0–100 energy meter and six-second
cooldown. Each successful ability has a bounded, recognizable emblem:

- Looper: backward route ticks and a brief clock-fold;
- Solo: one paper dash strip and an invulnerable guard crease;
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

The retiring copy itself remains briefly visible, with its captured tint,
weapon and condition. Its paper body folds, pulls apart or compresses according
to the actual final skill. Exhaustion uses a quiet fold rather than the same
particle burst. Repairs, lever operations and rejected operations likewise
have body/contact/result drawings driven by the committed model event.

## End and archive beats

Boss defeat and final outcome are separate beats. The last encounter enters a resumable discharge decision before recording a win. Released costs0 with clearance or12 cash otherwise and repairs retained copies; Collective releases actual living workers/crew and restores health; Takeover retains the latest copy as staff. Debt is independent of the chosen ending. Cancel returns to Pause; Resume and Continue reopen unresolved terms.

EndUi allows any retained valid archive, including utility-only and lower-output routes, with explicit replacement confirmation. Actual-entry previews share the runtime normalization (opening grade0/budget/condition60), including character synergy and support values. Daily, Solo and debt blockers remain visible. Family-wall and shift-history drawer distinguish actual retained, archived, staff and retired identities.

Bureau delivery in2/6/10 has actual pickup, lever, radius86 stamp and inbox. Warning1.1s/impact/recovery and the4s safety interval share the hit model; repeated transient feedback cannot overwrite world memory. E/X and old-route Echo lever replay emit one correct cue and show the named safety lever. An8-material reward is once-only. Inspection terminals expose an actual warned hazard, and the following Shop receipt states registered or unverified.

Three merge ceremonies share the authored stapler poses but have actual skill-transfer, patch and clamp geometry; Undo reverses the visual using original data. Animation is passive/skippable and cannot commit twice. Safe-phase retirement receipts record actual successful work; cleanup uses actual rescued people.

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
- `tests/test_paper_*`, `test_action_event_contracts` and the real Main input
  regression cover the action pass. CI runs `tools/paper_action_probe.gd` at
  normal speed in EN1280, ZH960 and Reduced1280, saves native phase PNGs and
  silent movies, and compares legal eight-Echo pressure with public 0.17 on
  the same runner. These are disclosed scripted fixtures, not human playtests.

The current bureau gameplay probe covers EN1280 and ZHReduced960 with real Main input, full-snapshot/RNG invariance, strict JSON restoration and native pixels. Dedicated archive and world probes cover all four menu canvas/language combinations and actual warning, impact, safe, inspection and cleanup states. These clinical fixtures are not human playthroughs. Runtime exports, checksum receipts and public downloads are audited separately; physical-controller behavior, Windows GUI, long-term balance and universal frame rate remain separate validation.
