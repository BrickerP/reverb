# Presentation slice

The presentation line starts at `d3d62b3` (v0.1.36, including Conductor), integrates
fixed mechanics through `5a1e8c1`, and ends at immutable source
`d4a0e73784e775d996b2a27f0a5de6c9befa4aaa`. Uncommitted work in the separate
mechanics checkout is excluded. Version fields remain 0.1.36. Presentation adds no
rules, prices or collisions, and this local delivery does not create a tag, Release
or main-branch move.

## Assets and rendering

`PresentationAssets` is the shared catalog for world sprites and shop thumbnails.
The 38 runtime PNGs and their hashes/prompts are documented by
`assets/presentation/SOURCES.md` and the character, enemy, item and weapon
manifests. Offline-measured visible regions are stored as source-pixel rectangles
in the catalog, then scaled to the imported texture size. Godot imports at 512 px
with mipmaps; rendering uses linear mipmap filtering. G003 verified 39 keys because
`player` was a documented alias of Looper front; G006 cleanup removes that unused
alias, leaving 38 canonical keys with the same PNG bytes.

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

Audio routes 35 cue names. The five original presentation cues remain, and G004
adds 21 CC0 WAVs: 12 weapon profiles, critical/shield hits, weapon/bomber blasts,
contact/blast hurt, equipment apply/undo and reroll. Seven common and five protected
voices preserve important feedback under combat density. Rich signals are bound
once, combat/ambient pauses correctly, allowed UI transaction cues remain responsive,
and lifecycle rebind/reset is strict. `audio/presentation/SOURCES.md` records exact
sources; the two audio builders reproduce the presentation WAVs.

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
smoke pass.

G004 passes 3796 assertions, resource import, English/Chinese UI and smoke (5246
frames, wave 4, three purchases). The real-paced native probe observes 15 shots,
4 damage events, 2 explosions, 3 player hurts and 2 weapon changes; seven captures
are nonblank and actual-view checked. Pause holds audio position after settling,
resume advances, and cleanup clears old references, queues and motion. Reviewer
status is APPROVE/CLEAR after null-guard reconfirmation. Production is fixed at
`9e808ff`; the shareable `take-stack-feedback.mp4` is 7.45 seconds, 1280×720 at
60 FPS with H.264 video and AAC audio. Its verification directory contains seven
PNG captures, the feedback summary and logs.

G005 integrates arena-floor, panel-skin and recording-cartridge surfaces plus an
application icon, bringing the original PNG total to 42. Reduced effects persist
and propagate to world/shop/result presentation. Every modal has a closed focus
cycle and restores underlay focus; language changes are guarded during active runs.
Echo merge can be cancelled, merged badges use bounded HFlow layout, controls have
active accessible names, and drag previews use a nonblocking offset wrapper.

G005 is fixed at `24f4fd4`. Strict English and Chinese native geometry passes across
all ten states after Codex spacing, merged-badge HFlow and dense-panel paint-crop
fixes. The 960×540 English scaled and 1280×800 Chinese letterbox probes pass. The
final dense crop removes a duplicated inner panel body without changing layout or
source PNGs. Full verification is 3927 assertions plus smoke; the stable output
folder contains 20 bilingual PNGs, summaries and logs. Code review is APPROVE,
architecture review CLEAR and visual review PASS.

G006 cleanup removes the unused `player` alias and duplicate metadata. The final
catalog has 38 canonical keys and the same 42 PNGs; the earlier G003 39-key result
remains valid historical evidence for its one documented alias. Post-cleanup, 3915
assertions, smoke and English/Chinese UI pass. The fixed-HEAD 300-enemy standard
stress case runs at 6.761 ms average, 10.813 ms p99 and 13.640 ms max; reduced
effects runs at 6.916/12.516/14.490 ms. The fixture contains all seven enemies, six weapons and
four echoes, while feedback remains within 12 audio voices and 260 sparks.
This measures frame-production headroom on Apple M3 with Godot 4.7.2 OpenGL
Compatibility, fixed 60 FPS and vsync disabled; it is not a cross-hardware FPS
guarantee. Reduced effects is a readability/lower-motion mode, not a performance
claim.

macOS, Windows and Linux packages all load 79 runtime resources and 18 provenance
files with no forbidden content and identical PCK hashes. macOS passes isolated
headless smoke and a live Chinese app flow without modifying normal user data.
Windows/Linux packages are compiled and audited but not natively launched. Final
code review is APPROVE with zero findings and architecture review is CLEAR.

```sh
godot --path . --fixed-fps 60 --disable-vsync \
  --write-movie /absolute/output/preview.avi \
  --script res://tools/presentation_preview.gd
```

## Next stage

`INTERFACES.md` documents the integrated `ShotInfo`, `DamageInfo`, `ExplosionInfo`,
`WeaponChangeInfo` and `PlayerHurtInfo` events. G004 binds them to weapon-profile
recoil/muzzle/tracer feedback, directional hits and hurt, cause-specific explosions,
equipment apply/undo response and distinct audio without duplicate legacy playback.

Direct-drop transactions and repeated undo now use the mechanics-owned
`quote/apply/undo` API and history signals. G005 completes the drag wrapper, surface
art, reduced mode, focus and language/merge accessibility states with final
bilingual, scaled, letterbox and visual acceptance.

The remaining work is evidence from people and target platforms: human feel/balance
sessions, DeepSeek balance iteration from those runs, and native Windows/Linux
launch checks. Character movement uses authored front/back art, horizontal direction
derivation and procedural motion; it is not a frame-by-frame walk/attack animation
set. Future feel changes should follow observed play rather than adding unbounded
polish tasks.
DeepSeek owns the rules and interfaces;
Codex owns their visual/audio response and fixed-commit integration and release.
