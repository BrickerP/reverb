# Presentation slice

This branch starts from `d3d62b3` (v0.1.36, including Conductor). It changes the
presentation layer only. Rules, prices, collision radii, save formats and version
fields remain on that baseline.

## Assets and rendering

`PresentationAssets` is the shared catalog for world sprites and shop thumbnails.
The six generated originals and their hashes/prompts are in
`assets/presentation/`. Their offline-measured visible regions are stored as
source-pixel rectangles in the catalog, then scaled to the imported texture size.
When replacing an original, update its manifest and source metadata together.
Godot imports at 512 px with mipmaps; rendering uses linear mipmap filtering.

The player and echoes share one operator sprite. Grunts and runners have separate
silhouettes; other enemies reuse the grunt body with their existing tint, size and
special tells. Sidearms/marksman weapons share the pistol image, scatter weapons
the shotgun image, and arcane weapons the emitter image. World art keeps its
aspect ratio, with deterministic sway/bob and visible weapon mounts. These are
single-pose images with procedural motion, not directional animation sheets.

Boss rings, shield arcs, bomber radii, health bars, spawn warnings, echo lifespan
segments, rewind/silence marks and projectile batching remain active. Rendering
does not step the simulation or consume its RNG.

## UI and audio

Godot controls still own text, prices, focus and actions. The shop uses the same
weapon assets as the world, a restrained dark equipment-panel theme, and a
scrollable build panel for full loadouts. This slice does not add drag purchases
or undo; those require the agreed mechanics transaction interface.

Five CC0-derived cues replace click, purchase, hit, echo and wave-end sounds.
Other sounds retain their existing files. `audio/presentation/SOURCES.md` records
the exact sources; `tools/build_presentation_audio.py` reproduces the WAVs.

## Verification and preview

Run resource import, the existing `tools/test.sh` and `tools/smoke.sh`, then
`tools/ui_shots.gd` in English and Chinese. `tools/frame_probe.gd` measures a real
window with the existing crowd fixtures. Use a custom Godot user-data directory
when running those tools, so test settings and progression stay isolated.

`tools/presentation_preview.gd` records a short deterministic presentation fixture:
four-character selection, combat with two echoes and three weapon families, then
a shop purchase through the existing UI action. Fixture resources and spawn setup
are intentionally staged for readability; its outcomes are not balance evidence.

```sh
godot --path . --fixed-fps 60 --disable-vsync \
  --write-movie /absolute/output/preview.avi \
  --script res://tools/presentation_preview.gd
```

## Next mechanics interface

Exact muzzle flashes, recoil and distinct gunfire need a shot event containing
source, weapon ID, origin, direction, pellet count and sequence. Richer damage and
explosion events need weapon/source/target/direction or cause. Until then mounted
weapons aim using current visible state and sound uses the existing generic event.

Direct-drop transactions and repeated undo need mechanics-owned quote/apply
results, history boundaries at successful reroll/start-wave, and change signals.
The UI must consume those results instead of maintaining a second price or undo
implementation. DeepSeek owns those rules and interfaces; Codex owns their visual
and audio response, shared-file integration and eventual fixed-commit release.
