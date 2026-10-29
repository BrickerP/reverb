# Carbon Copy Purgatory artwork

All **48 production PNGs** use original paper-puppet artwork: thick dark ink
contours, flat recycled-paper fills, tired expressions, restrained sage/yellow/
red accents and jokes about disposable copies. No existing game's characters
or artwork are included.

Images were generated or edited with the built-in OpenAI image generation tool.
Final PNG bytes are preserved from those outputs. Group records retain exact
prompts, source/output paths, dimensions, alpha checks and SHA256 hashes;
production does not repaint or resample those source files with image scripts.

## Runtime identity and layout

The runtime catalog has **56 keys**: 24 weapons, 11 items, seven enemies, 12
character views, one merchant and one recording cartridge. Known content IDs
have explicit mappings. Twelve character front/back and seven enemy sheets
contain eight authored poses in a four-column, two-row grid. The merchant has
four expressions, making **20 animated atlases** in total.

The office arsenal uses independently cropped static weapon regions. Depot
landmarks also use static prop regions. Their region layouts do not imply
animation. The arena floor and application icon are separate production images.

`bounds_ltrb` measures complete PNG alpha; `frame_union_ltrb` measures all actor
poses in local cell coordinates. Right/bottom are exclusive; the alpha threshold
is 20/255. Shared crops, idle reference bounds and per-pose foot pivots are
measured offline and consumed directly by runtime. A wide terminal pose never
changes the living actor's scale.

Imports retain mipmaps. Maximum edges are 2048 pixels for the arena floor,
1024 for depot landmarks and the application icon, and 512 for other presentation
PNGs. Source PNGs retain their original resolution and bytes.

## Production provenance

| Top-level file | Group with full prompts and outputs |
|---|---|
| `player.png` | [Characters](characters/SOURCES.md) |
| `enemy_grunt.png`, `enemy_runner.png` | [Enemies](enemies/SOURCES.md) |
| `weapon_pistol.png`, `weapon_shotgun.png`, `weapon_orb.png` | [Weapons](weapons/SOURCES.md) |

Other groups: [Items](items/SOURCES.md), [Surfaces](surfaces/SOURCES.md),
[Recycling depot landmarks](environment/SOURCES.md),
[Application icon](app_icon/SOURCES.md).

Each group's `carbon_copy_assets.json` is the source record. Group/root
`manifest.json` and runtime metadata are generated from actual bytes by
`python3 tools/sync_art_catalog.py` using Pillow. Pixel scanning is offline;
the game reads metadata and imported textures. Export auditing checks the
shipped resources and provenance against this production set.
