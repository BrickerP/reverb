# Presentation slice

The presentation commit `650ac4e` starts from `d3d62b3` (v0.1.36, including
Conductor) and changes presentation only. The branch subsequently integrates the
fixed mechanics commit `8f555e4`, including its shop transaction/undo API and rich
combat events. Uncommitted work in the separate mechanics checkout is excluded.
Version fields remain unchanged. Presentation adds no rules, prices or collisions.

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
or undo controls. The mechanics transaction API is present after integration, but
the current UI still uses its compatible legacy action methods.

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

## Next presentation adapters

`INTERFACES.md` documents the integrated `ShotInfo`, `DamageInfo`, `ExplosionInfo`
and `WeaponChangeInfo` events. A subsequent pass can bind exact muzzle flashes,
recoil and weapon-specific sounds to those events. This slice still uses legacy
signals, with mounted weapons aiming from current visible state.

Direct-drop transactions and repeated undo must migrate UI calls to the available
mechanics-owned `quote/apply/undo` API and consume its history/change signals.
Legacy action methods do not record undo history. Undo restores fresh Offer
objects, so the UI must rebuild its offer references. It must not maintain a
second price or undo implementation. DeepSeek owns those rules and interfaces;
Codex owns their visual/audio response and fixed-commit integration and release.
