# Carbon Copy Purgatory artwork

All 42 production PNGs use the approved original paper-puppet art direction:
thick dark ink contours, flat recycled-paper fills, tired expressions, limited
sage/yellow/red accents, and visual jokes about disposable copies. They replace
the previous mechanical character, weapon, enemy and metal-panel artwork.

Generated with the built-in OpenAI image generation tool; group records retain exact sources. Final
PNG bytes are retained from tool outputs; required edits used the same tool.
No existing game's characters or artwork are included.

The runtime catalog preserves all content IDs. Character fronts/backs and all
seven enemy identities are four-column, two-row action atlases. Common crop bounds
are measured across all four cells so changing poses never changes scale.
Weapons remain independently mounted; echoes reuse the selected character art.

## Production provenance

| Top-level file | Group containing full prompts and original outputs |
|---|---|
| `player.png` | [Characters](characters/SOURCES.md) |
| `enemy_grunt.png`, `enemy_runner.png` | [Enemies](enemies/SOURCES.md) |
| `weapon_pistol.png`, `weapon_shotgun.png`, `weapon_orb.png` | [Weapons](weapons/SOURCES.md) |

Each group's `carbon_copy_assets.json` retains the exact prompt, original output,
dimensions, alpha checks and SHA256. Group and root `manifest.json` are generated
from the actual PNG bytes by `python3 tools/sync_art_catalog.py`. Pixel scanning
occurs only offline; the game reads precomputed bounds.

Other groups: [Items](items/SOURCES.md), [Surfaces](surfaces/SOURCES.md),
[Application icon](app_icon/SOURCES.md).

`bounds_ltrb` measures the complete PNG; `frame_union_ltrb` measures all poses
in local cell coordinates. Right and bottom are exclusive. Visible alpha is
20/255. Runtime imports retain mipmaps and a maximum 512px texture edge.
