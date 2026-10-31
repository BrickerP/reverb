# Carbon Copy Purgatory art direction

Take Stack is a bureau that recycles yesterday's versions of you. Paper
puppets, worn copies, support contraptions and hostile office waste share thick
charcoal contours, recycled cream paper, tired expressions and restrained sage,
yellow, blue and red accents. Readable identity and causal threats take priority
over decoration.

## Production visual inventory

The current production set contains **54 PNG source files**, **87 runtime
identity keys**, and **23 animated strips**. The strips are twelve character
front/back atlases, nine enemy atlases and the four-expression merchant atlas and the eight-pose binding ceremony.
Characters and enemies use authored 4×2, eight-pose sheets; the merchant uses
4×1. Static multi-object sheets use explicit regions and must never be inferred
as animation from their aspect ratio.

The 0.15 closeout adds four original, true-alpha PNG sources generated with the
built-in image-generation workflow:

- `enemies/foreman.png` and `enemies/collector.png`: distinct eight-pose Boss
  identities for press and charge behavior;
- `weapons/expedition_arsenal.png`: six alternate final forms, five support
  weapons and a mission-letter region;
- `supports/crew.png`: hound, turret, repair station, paper tree and decoy
  states on one static region sheet.

Source PNG pixels remain the original generated outputs. Production integration
may adjust region bounds, pivots and measured crop metadata; it does not repaint,
resample or splice the source pixels. Manifests retain prompts, source paths,
dimensions, alpha checks and hashes.

## Visual grammar

- The 2400×1200 ash-paper world keeps quiet floor space around localized
  conveyors, presses, recyclers, mission targets and cover machines.
- Actors are recognizable from silhouette before color. The Foreman reads as a
  heavy press body, the Collector as a forward-driving collector, and the
  Paradox as the original folded anomaly.
- Support units read as friendly machinery, carry visible health/lifetime
  state, and remain distinct from loot. Recruited bosses preserve their identity
  while using a friendly outline and attribution.
- Echoes retain faded whole-body paper, offset-print marks, staples and clear
  wear/silence/rewind/archive cues. Merge traits do not create a second body.
- Mission targets and machine interactions use shape plus localized live text.
  Locks, danger, debt and focus never rely on color alone.
- UI uses torn paper panels, stamp controls, unboxed rows and ink-bracket focus.
  Functional text and hit areas remain stable while decorative paper reactions
  respond to actual outcomes.

English display text uses Amatic SC, Chinese display text uses ZCOOL KuaiLe, and
Noto Sans CJK SC supplies readable body text. All user-facing copy stays live
and localized rather than baked into source art.

## Animation and crops

Common eight-pose order is idle, alternating steps, hurt, preparation,
follow-through, crumple and flattened remains. Foreman and Collector keep the
same row-major contract but use action poses that match their actual press and
charge. Paradox retains the phase-two split identity.

`PresentationAssets.frame_region()` and `frame_pivot()` use offline-measured
alpha bounds. `idle_region()` calibrates thumbnails and live scale. Crop metadata
may be tightened when a native capture exposes a small intrusion, but a wide
terminal pose must never shrink or shift the living actor. Runtime never scans
source alpha pixels.

Imports keep mipmaps. The arena floor uses the largest edge budget; character,
enemy, weapon, item and support sources use their declared import limits. No
runtime resampling pipeline rewrites the tracked source PNGs.

## Simulation boundary and HUD

Model positions, collision, recordings and attacks stay in the 2400×1200 world.
Camera translation and shake are clipped to the native display battle region;
the standard 1280×720 canvas uses 1200×600. Culling reduces draw work only:
offscreen Echoes and support units still play, fire, wear, take damage and
expire.

The root HUD uses compact top and bottom islands. The bottom weapon/ability row
sits below the battle world. `WorldArena.display_viewport()` maps the available
native canvas into a real camera rectangle: at 960×540 the FOV adapts while actor
pixels keep their size, rather than globally scaling the UI/world down. Boss
warnings, interaction prompts, mission progress, energy and debt read
authoritative state. Physics spawn planning keeps the constant 1200×600 field,
so presentation resize does not change RNG.

`BattleDirector`, `ExpeditionInk`, `ArenaPainter`, `WeaponInk` and `EchoInk`
store bounded value snapshots. Reduced Effects removes optional motion but keeps
attack geometry, active hazards, support health, selected-Echo identity,
interaction prompts and skill readiness. Rendering cannot change damage,
economy, wear, support lifetime, debt, RNG or save results.

## Sound identity

The original **Paperwork Waltz** score remains five synchronized 96-second
arrangements: menu, shop, battle, pressure and Boss. The 35 dry paper/office SFX
files remain distinct, and the 35 weapon profiles reuse those cues through
explicit mappings rather than adding hidden audio dependencies. Master, music
and effects gains remain independent.

Music and effects provenance is recorded in
[audio/music/SOURCES.md](../audio/music/SOURCES.md),
[audio/presentation/SOURCES.md](../audio/presentation/SOURCES.md) and
[THIRD_PARTY.md](../THIRD_PARTY.md). File and lifecycle checks do not establish
subjective listening approval.

## Reproduction and verification

```bash
python3 -m pip install -r tools/requirements-dev.txt
python3 tools/sync_art_catalog.py
make test
make smoke
REVERB_LANG=en godot --path . --disable-vsync --script res://tools/expedition_art_probe.gd
REVERB_LANG=zh REVERB_PROBE_REDUCED=1 REVERB_PROBE_SIZE=960x540 godot --path . --disable-vsync --script res://tools/expedition_art_probe.gd
```

`tools/requirements-dev.txt` pins NumPy 2.0.2 and Pillow 11.3.0 for score tools,
alpha validation and Python CI. The shipped game has no Python runtime.

Current native evidence includes EN1280×720 and ZHReduced960×540, family-wall/vending, three distinct merge traits, confession states, actual delivery and Echo switch replay, and bounded cleanup. Probes explicitly disclose clinical staging, retain original pixels and validate full snapshots and both RNGs. Physical-controller recognition, subjective listening and human balance are separate playtests.

All 54 source records live in group `carbon_copy_assets.json`, `manifest.json`
and `SOURCES.md` files. Export auditing must inspect the actual immutable build;
source-tree inventory alone is not release evidence.

## Bureau facilities and rituals

Two built-in imagegen RGBA atlases live under assets/presentation/bureau. Facilities has eight static machine states; binding has eight authored staple/unstaple poses. Blank vending bays and copier output receive the actual archived identity at runtime. Prompts, references, original source hashes and measured alpha regions are in that group's SOURCES.md and manifests; concept JPGs are references rather than bulk runtime assets.

Family frames, receipts, local goal arrows and three trait overlays use native ink geometry. Stamp warnings and phase labels read actual radius/state/safe interval; completed payout text appears only when the model has rewarded it. Night cleanup is driven by actual safe workers and retirement records. Neither decoration nor cleanup removes living end-of-wave enemies.
