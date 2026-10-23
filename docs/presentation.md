# Presentation slice

The presentation commit `650ac4e` starts from `d3d62b3` (v0.1.36, including
Conductor) and changes presentation only. The branch now integrates fixed mechanics
through `c2e184e`, including shop transactions, upgrade trade-in refunds and rich
combat events. G002 presentation commit `2a44c2d` is integrated at `4b481d3`.
Uncommitted work in the separate mechanics checkout is excluded. Version fields
remain unchanged. Presentation adds no rules, prices or collisions.

## Assets and rendering

`PresentationAssets` is the shared catalog for world sprites and shop thumbnails.
The 38 runtime PNGs and their hashes/prompts are documented by
`assets/presentation/SOURCES.md` and the character, enemy, item and weapon
manifests. Offline-measured visible regions are stored as source-pixel rectangles
in the catalog, then scaled to the imported texture size. Godot imports at 512 px
with mipmaps; rendering uses linear mipmap filtering. The catalog has 39 keys only
because `player` is a documented alias of Looper front.

Every weapon, item and enemy Content ID has explicit art. Each character has an
authored front and back; horizontal mirroring supplies left/right. This is complete
static identity and front/back-derived direction coverage, not full walk/attack
frame animation. World art keeps its aspect ratio, with deterministic sway/bob and
visible weapon mounts. Warden has an authored-axis/pivot correction so its shield
and visual front agree with gameplay facing.

Boss rings, shield arcs, bomber radii, health bars, spawn warnings, echo lifespan
segments, rewind/silence marks and projectile batching remain active. Rendering
does not step the simulation or consume its RNG.

## UI and audio

Godot controls still own text, focus and actions; mechanics owns validation, costs,
refunds, snapshots and lock boundaries. The shop uses the same weapon assets as the
world, a restrained dark equipment-panel theme, and a scrollable build panel.
Dragging a weapon onto an empty or occupied valid slot commits BUY or REPLACE
immediately; dragging an item onto the item target commits BUY. Keyboard/controller
replacement, upgrade and evolve use the same transaction bridge. The Undo control
walks back equipment actions within the current offer batch; successful reroll or
wave start locks prior history. Echo discard/merge is intentionally outside undo.
Undo rebuilds Offers, and stale exact-offer drag payloads are rejected.

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

At the G002 integration checkpoint, 2660 assertions passed with zero failures;
smoke completed 5246 frames through wave 4 with three purchases. Native EN/ZH shop
probes passed 76 targeted assertions and exercised nine operation counters.

G003 adds four runtime gallery pages covering 12 weapons, 11 items, 7 enemies and
4 characters across 16 direction cases. Gallery/content-ID/linear-mipmap checks,
actual-size visual review, Warden facing, strict EN/ZH card geometry and the G002
interaction regression pass. On final HEAD `2fa3735` with fixed mechanics
`5a1e8c1`, resource import, English/Chinese UI, 3470 assertions and the 5246-frame
smoke pass. Three surface PNGs are prepared for G005 but are not runtime-complete.

```sh
godot --path . --fixed-fps 60 --disable-vsync \
  --write-movie /absolute/output/preview.avi \
  --script res://tools/presentation_preview.gd
```

## Next presentation adapters

`INTERFACES.md` documents the integrated `ShotInfo`, `DamageInfo`, `ExplosionInfo`,
`WeaponChangeInfo` and `PlayerHurtInfo` events. A subsequent pass can bind exact
muzzle flashes, recoil, directional hurt and weapon-specific sounds to those
events. This slice still uses legacy presentation signals, with mounted weapons
aiming from current visible state.

Direct-drop transactions and repeated undo now use the mechanics-owned
`quote/apply/undo` API and history signals. The remaining adapter work is visual and
audio: consume `WeaponChangeInfo` for equipment/undo feedback and the rich combat
events for exact firing and impact responses. G005 should also recheck the drag
preview wrapper/offset so it never crowds the active target; this is non-blocking
for the verified transaction behavior. DeepSeek owns the rules and interfaces;
Codex owns their visual/audio response and fixed-commit integration and release.
