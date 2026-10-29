# Carbon Copy Purgatory

Take Stack's visual identity is a world that recycles yesterday's versions of
you. The Creased, Reject, Misprint and Binder are original paper puppets;
discarded copies are printed, stapled and eventually consumed. Humor comes from
their silhouettes, expressions and actions. Gameplay IDs and rules are unchanged.

## Visual grammar

- Strong charcoal ink contours, flat cream paper, one restrained shadow.
- Quiet sage-gray arena; red hazards, paper actors and distinct enemy silhouettes.
- Copies use faded paper and offset-print marks. Only the active section of their
  recorded route is visible, avoiding full-length lines covering the arena.
- Menus use paper panels, ink type, stamp buttons and visible focus rings.
  Both languages use live Godot text, never lettering baked into artwork.
- Focus, locked content and dangerous actions use shape/text as well as color.

## Animation and simulation contract

Eight character direction sheets and seven enemy sheets each contain eight drawn
poses in a four-column, two-row atlas. The UI merchant retains four expressions.
Ordinary actors add action/recovery and crumple/flatten to idle, alternating steps
and hurt. The Original also has authored tear-transition drawings; phase one
never samples torn live poses. Phase-two shards select their own half from their
persistent position in `Sim.boss_shards`. See [battle-direction.md](battle-direction.md).

`PresentationAssets.frame_region()` uses a shared per-sheet crop; `idle_region()`
calibrates live scale and `frame_pivot()` aligns each drawn foot baseline. `ArenaPainter`
retains batch drawing without an animation node tree per enemy. Visual clocks
stop on pause; reduced effects simplify optional motion. Recoil, paper fragments,
recording arrival, stapling, collapse and victory stamps use existing events.

Animation changes no simulated position, collision, hit timing, damage, economy
or RNG. World rendering and thumbnails share the same identity catalog.

## Reproduction and verification

```
python3 tools/sync_art_catalog.py  # offline metadata; requires Pillow
make test
make smoke
REVERB_LANG=en godot --path . --fixed-fps 60 --disable-vsync --script res://tools/carbon_copy_ui_probe.gd
REVERB_LANG=zh godot --path . --fixed-fps 60 --disable-vsync --script res://tools/carbon_copy_ui_probe.gd
godot --path . --fixed-fps 60 --disable-vsync --script res://tools/presentation_stress_probe.gd
godot --path . --fixed-fps 60 --disable-vsync --write-movie res://shots/presentation.avi --script res://tools/presentation_preview.gd
```

The UI probe checks all menu/modal states, contrast, scrolling and injected
keyboard/joypad navigation. Injection validates the input path; it is not a
physical controller or Steam Deck test. Stress captures use real rendering and
report frame-production headroom, not a universal FPS promise. Presentation
fixtures stage durability, waves and offers for legible footage; they are not
balance or human-playtest data. All probes use isolated fixture files.

Prompts and hashes are in each group's `SOURCES.md`, `carbon_copy_assets.json`
and `manifest.json`. Exports are audited from an immutable Git commit with
`tools/export_release_audit.py`.

## Organic interface language (0.11.1)

The interface uses one native InkStyleBox resource with hand-shaped curves,
local-coordinate triangulation and restrained ink marks. Large sheets, squat
action tabs and unboxed data rows have different visual weights. Focus is
drawn as ink brackets rather than a glowing rectangular border. The old raster
panel path is removed. Main hit areas and text remain still while decorative
objects react to events.

Character selection is an open stage; only the current character receives a
strong ink silhouette. The supply desk uses larger objects and price tags,
with build and copy dossiers stacked to one side. The merchant reacts only
to actual transaction outcomes. An unaffordable purchase retains its exact
reason; flavor text does not replace the functional message. Undo, reroll,
merge and purchase each have a distinct short, interruptible visual action.

English display text uses Amatic SC and Chinese display text uses ZCOOL KuaiLe;
Noto remains the readable body face. Font licenses and source hashes ship in
the exported resource pack. Inspiration is the drawn marks, negative space
and expressive interaction of Klei's official Don't Starve gallery:
https://www.klei.com/games/dont-starve-together
All characters and game-specific illustration remain original.

## Recycling depot and field hierarchy (0.13.0)

The discarded-crate wall is replaced by a quiet ash-paper floor and structural
ink perimeter. A returns conveyor, a stamping workstation and an absurd notice
occupy localized edge/corner clusters. Prop artwork keeps natural proportions;
the horizontal notice is a native torn-paper shape with live bilingual text.
The central fighting space stays empty. One `RecyclingDepot` child redraws at
12 Hz from the presentation clock; pause freezes it and Reduced Effects holds
one stationary state. Props are scenery, without new collision or rules.

The world is a descendant of a fixed `Control.clip_contents` rectangle equal
to `Sim.ARENA`. An intermediate inverse origin preserves world coordinates,
while shake remains inside the crop. Actor art, particles and batched projectile
heads cannot enter transparent HUD margins. The active player draws after
routine debris; bowed paper/ink edges separate locally overlapping bodies.
Enemies and their authoritative threat geometry are not faded or relocated.

Copy states use whole-body value and shape plus large closed/stapled/torn marks;
the tiny below-foot lifetime meter is removed. The Original's 0.62-second tear
has tension, seam break and spring release; decorative prints never hold or move
the real phase-two bodies. These states are assessed in the actual 1280x720
battlefield, alongside Reduced Effects and scaled windows.

All 35 sounds use one strict presentation palette from pinned CC0 object
recordings plus original granular paper synthesis. Staple, stamp, crumple,
feed and jam cues share a quiet mechanical room bed. Important events briefly
duck the bed; voice budgets, mute and pause remain bounded. This is material
sound design, without a new composed soundtrack or a claim of listening approval.
See `audio/presentation/SOURCES.md` for complete recipes and provenance.

`tools/depot_art_probe.gd` records copy states, crowd overlap, edge clipping
and six tear timestamps. Its staged fixture declares positions/ages/durability;
zero changed pixels outside the crop proves the draw boundary, not human
recognition speed. Real handling and listening remain separate acceptance work.
