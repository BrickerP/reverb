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

Eight character direction sheets, seven enemy sheets and the UI merchant each contain four drawn
poses. Ordinary actors use idle, alternating steps and a compressed hurt pose.
The Original instead has intact, bellowing, left-half and right-half drawings;
phase one never samples torn poses. Phase-two shards select their own half from
their persistent position in `Sim.boss_shards`.

`PresentationAssets.frame_region()` uses a shared per-sheet crop. `ArenaPainter`
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
