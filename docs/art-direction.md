# Carbon Copy Purgatory art direction

Take Stack is a bureau that recycles yesterday's versions of you. Six original
paper-puppet identities, worn copies and hostile office waste share charcoal
contours, recycled cream paper, tired expressions and restrained sage, yellow
and red accents. Humor comes from silhouettes and actions; readable threats and
player identity take priority over decoration.

## Visual grammar

- Quiet ash-paper floor, localized conveyor/workstation/notice clusters, useful
  machine cover and a structural ink perimeter support the larger scrolling world.
- Copies retain whole-body faded paper, offset-print identity, staples and clear
  wear/silence/rewind marks. Only the active route segment is emphasized. The HUD
  names the selected copy, condition, skill prediction and offscreen direction.
- The player draws clearly over routine debris. Enemy bodies and authoritative
  threats keep their actual positions and geometry during crowd overlap.
- Organic paper panels, stamp buttons, unboxed data rows and ink-bracket focus
  form one native UI language. Functional text and hit areas stay stable while
  merchant and paper decorations react to real transaction outcomes.
- English display text uses Amatic SC, Chinese display text ZCOOL KuaiLe, and
  Noto Sans CJK SC supplies readable body text. Labels remain live, localized
  Godot text; focus, locks and danger also use shape or text rather than color alone.

## Production assets and animation

The production set contains **48 PNGs**. The runtime catalog has **56 identity
keys**, including all 24 weapons, 11 items, seven enemies, 12 character views,
merchant and recording cartridge. One office-arsenal sheet supplies independent
static weapon regions; the depot-landmark sheet also uses static prop regions.
Neither is a strip of animation frames.

There are **20 animated atlases**: 12 character front/back sheets and seven enemy
sheets each have eight authored poses, plus the merchant's four expressions.
Actors use four columns by two rows. Common poses are idle, alternating steps,
hurt, preparation, follow-through, crumple and flatten. The Original has distinct
intact, roar, half-body and tear-transition drawings. Phase one never samples
live torn halves; phase-two art follows persistent shard identity.

`PresentationAssets.frame_region()` uses a common measured crop across an atlas;
`idle_region()` calibrates live size and thumbnails, and `frame_pivot()` aligns
each pose's foot. Wide terminal poses cannot shrink living actors. Source PNG
bytes remain the original image-generation outputs; regions, bounds and pivots
are metadata, not programmatic repainting. Runtime uses precomputed metadata
and never scans source alpha pixels.

Imports retain mipmaps. Maximum imported edges are 2048 pixels for the arena
floor, 1024 for depot landmarks and the application icon, and 512 for the other
presentation PNGs. Source resolution, exact prompts, output paths and hashes
remain in group manifests.

## Simulation and presentation boundary

World positions, recordings, collision and attacks use the 2400×1200 world.
Camera translation and shake draw below the fixed 1200×600 HUD-safe clip. Culling
only reduces draw work; offscreen copies still play, fire and wear by simulation
rules. The five cover machines have model collision; decorative perimeter props
do not acquire extra collision from their pictures.

`BattleDirector` coordinates stable locomotion, recoil, actions and bounded
value-snapshot corpses without a node tree per actor. `ArenaPainter` keeps batch
drawing. Visual clocks freeze on pause; Reduced Effects removes optional motion
while retaining selection, warnings, real fields and all functional feedback.
Rendering cannot alter position, hit timing, damage, economy, wear or RNG.

## Sound identity

Original score **Paperwork Waltz** develops a crooked piano / low-reed / office-
percussion melody across five synchronized 96-second arrangements: menu, shop,
battle, pressure and Boss. Two music voices crossfade at the same score position
according to actual simulation threats and wave phases. The 35 dry paper/office
effects keep their pinned CC0 recording and original synthesis provenance.
Music, effects and master gain are independently adjustable; pause, mute,
transition ducking and session reset have bounded lifecycle behavior.

Recipes and licensing are in [music sources](../audio/music/SOURCES.md),
[effect sources](../audio/presentation/SOURCES.md) and
[third-party notices](../THIRD_PARTY.md). Objective file and lifecycle checks do
not establish subjective listening approval.

## Reproduction and verification

```bash
python3 tools/sync_art_catalog.py
make test
make smoke
REVERB_LANG=en godot --path . --disable-vsync --script res://tools/core_gameplay_probe.gd
REVERB_LANG=zh REVERB_PROBE_REDUCED=1 godot --path . --disable-vsync --script res://tools/core_gameplay_probe.gd
godot --path . --fixed-fps 60 --disable-vsync --script res://tools/presentation_stress_probe.gd
godot --path . --fixed-fps 60 --disable-vsync --script res://tools/frame_probe.gd
```

Catalog sync is offline metadata work using Pillow. Native probes stage declared
fixtures, capture actual pixels and exercise production input paths. They use
isolated files. These are regression and layout evidence, not human balance,
recognition-speed, physical-controller or target-device evidence. Pressure
captures report their own machine and scene; there is no universal FPS promise.

All source records live in group `SOURCES.md`, `carbon_copy_assets.json` and
`manifest.json` files. `tools/export_release_audit.py` validates actual exported
resources and provenance from a fixed commit; it does not replace visual review.
