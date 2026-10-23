# Take Stack Presentation Slice Implementation Plan

> Execution: native Codex executor subagents implement bounded tasks in this worktree; the parent owns integration and verification. The user has authorized execution.

**Goal:** Replace the geometric player/enemy/weapon placeholders with coherent generated artwork, readable echoes and basic motion; improve existing UI object presentation and selected action sounds in a running Godot build.

**Architecture:** Keep Sim, Combat, Shop and content definitions unchanged. Rendering consumes existing state; audio consumes existing signals. Import generated transparent art into a presentation-only catalog, reuse it in world/UI, and preserve the existing collision, projectile batching, spawn telegraphs, shield indicators and echo lifetime cues.

**Tech Stack:** Godot 4.7.2, GDScript, built-in image generation, PNG textures, WAV audio, existing test/smoke runners.

**Spec:** `/Users/yupeng/Documents/Codex/2026-10-23/qu/outputs/take-stack-asset-production-plan.md` and `take-stack-presentation-handoff.md`.

## Global constraints

- Work only in `/Users/yupeng/Documents/Codex/2026-10-23/qu/work/reverb-presentation`, branch `codex/presentation`, initially based on `d3d62b3`; the completed presentation commit `650ac4e` subsequently integrates fixed mechanics `8f555e4`.
- Do not edit `scripts/sim`, `scripts/data`, `scripts/echo`, version fields, releases, or the original OpenCode checkout.
- No new package dependencies. Keep UI text localization-compatible; decorative images carry no embedded labels.
- Use actual PNG assets, not newly drawn geometric substitutes. The source art may be cropped at render time by its alpha bounds, but retain original generated files and provenance.
- Use isolated Godot user data during verification; local `override.cfg` must not be committed/exported.
- This slice retains legacy signals. Fixed mechanics `8f555e4` now supplies rich events; binding per-weapon timing and transaction UI remains a subsequent presentation task. Do not claim those adapters are implemented here.

## Task 1: Art and resource contract — parent

Files: `assets/presentation/player.png`, `enemy_grunt.png`, `enemy_runner.png`, `weapon_pistol.png`, `weapon_shotgun.png`, `weapon_orb.png`, `SOURCES.md`.

- [x] Generate six isolated transparent assets, using the existing concept board for style reference.
- [x] Inspect alpha, clean bounds, silhouette and visual consistency. Copy originals into the worktree and record prompts/source files.
- [x] Use Godot texture regions/alpha bounds for display rather than destructively editing source images.

## Task 2: World presentation — executor

Files: `scripts/view/presentation_assets.gd`, `scripts/view/arena_painter.gd`, `scripts/view/arena_view.gd`, `tests/test_presentation.gd`.

Interfaces: `PresentationAssets.texture(key: StringName) -> Texture2D`, `PresentationAssets.region(key: StringName) -> Rect2`, `PresentationAssets.weapon_key(w: WeaponDef) -> StringName`.

- [x] Add meaningful checks that every required texture imports and mapped weapon families resolve to a valid texture, using the existing `Check` runner:

```gdscript
func test_required_art_loads(c: Check) -> void:
    for key: StringName in [&"player", &"enemy_grunt", &"enemy_runner", &"weapon_pistol", &"weapon_shotgun", &"weapon_orb"]:
        var texture := PresentationAssets.texture(key)
        c.ok(texture != null, "presentation texture %s" % key)
        c.ok(PresentationAssets.region(key).has_area(), "visible art bounds %s" % key)
```

- [x] Replace actor bodies and weapon sticks with textures. Use visible motion (idle/move sway and scale) without modifying simulation state. Reuse the player texture for tinted echoes, keeping silence and lifespan cues.
- [x] Preserve boss/warden/bomber tells, hp bars, spawn telegraphs and projectile batching. Unmapped enemy IDs get a coherent family texture fallback with their existing color and tells.
- [x] Check the renderer does not advance simulation RNG or mutate state. Run targeted presentation tests after resource import.

## Task 3: Action sound pass — executor

Files owned: `scripts/game/audio.gd`, `audio/presentation/**`, a presentation-audio build helper if needed, focused additions to `tests/test_audio.gd`.

- [x] Use clearly licensed source clips or documented procedural sources to create a small coherent set of mechanical UI/purchase/impact/replay cues.
- [x] Keep existing public methods and signal bindings working. Keep audio non-playing in headless mode and preserve cooldown limits.
- [x] Record provenance/license and validate WAV format/peak levels. Add only tests for actual routing/fallback/cooldown behavior changes.

## Task 4: UI asset integration — parent

Files: `scripts/ui/ui_theme.gd`, `scripts/ui/offer_card.gd`, `scripts/ui/build_panel.gd` as required.

- [x] Give existing panels/slots tactile but restrained styling and integrate the same weapon art as readable thumbnails.
- [x] Preserve existing prices, actions, focus and localized text. Do not fake the still-unimplemented shop undo API.
- [x] Check English/Chinese shop states and four-character selection in the actual window.

## Task 5: Verification and handoff — parent

- [x] Run `godot --headless --path . --import`, `./tools/test.sh`, and `./tools/smoke.sh` using isolated user data.
- [x] Run an actual-window presentation scene or deterministic smoke; capture world/shop/echo images and a short recording showing motion, plus an audio sample if useful.
- [x] Review the final diff for accidental sim/data/version changes and confirm the original mechanics checkout is untouched.
- [x] Commit the complete presentation slice on `codex/presentation`. Do not publish a tag/release.
- [x] Hand back the commit, runnable checkout, observed results and remaining limitations (notably rich-event adapters, transaction UI and complete animation coverage).

## Verification result

Pre-integration, 2026-10-23: 2396 checks passed; headless import and smoke passed; real-window English/Chinese UI captures passed. The 12-second presentation movie and full-loadout horizontal bounds checks passed. Independent review closed first-use image scanning, minification, and scroll-width findings. M3 compatibility-renderer crowd probe completed (300 chasing enemies: average 12.81 ms, p99 18.55 ms; synthetic stress, not a universal FPS guarantee). The original mechanics checkout was not written by this work. During final verification its branch advanced independently to 8f555e4 (shop transactions/undo and rich combat events), with separate uncommitted character-starting-loadout work. This presentation slice was validated on d3d62b3 before any subsequent integration.

The independent compatibility review found no touched-file overlap or mandatory legacy API migration in d3d62b3..8f555e4. Integration uses that immutable commit rather than following the moving mechanics branch; the combined tree is revalidated before handoff.
