# Item presentation artwork

Created on 2026-10-23 with the built-in image generation tool. Each file is one
original generated PNG copied without cropping, resampling, compositing or other
pixel editing. `manifest.json` records the exact hash, original dimensions and
visible alpha bounds (alpha >= 20/255). These files are source assets; runtime
catalog/import integration is intentionally handled by the parent presentation
task after serialized Godot verification.

## Shared prompt

Use case: `stylized-concept`. Asset type: transparent 2D Take Stack inventory
icon, readable at 32–64 display pixels. Match the established project artwork:
crisp illustrated matte hardware, bold clean dark contour, restrained cel-like
shading, compact chunky industrial design, ivory/off-white casing, charcoal
structure, small mustard/brass and cyan accents; use subtle violet recording-light
accents for echo items. Use a slightly elevated three-quarter game-icon view.

Show one centered physical object, fully uncropped with even padding on a square
canvas. Require genuine transparency. No floor, cast shadow, backdrop, UI card,
person, hands, text, letters, numerals, logo, watermark or extra objects. Avoid
bloom, visual noise and thin fragile details.

## Per-item subjects

- `iron_heart.png`: compact armored heart-shaped life-support module; mechanical,
  not anatomical; ivory plates, charcoal core, amber chamber and a cyan seam.
- `sneakers.png`: one cohesive icon containing a matched pair of futuristic utility
  boots; thick dark soles, ivory toes, mustard heel clips and cyan tread inserts.
- `sharp_edge.png`: compact replaceable blade-edge module; a broad sharpened wedge
  in a charcoal mount with an ivory housing and mustard locking latch.
- `quick_trigger.png`: standalone trigger cartridge; visible curved trigger inside
  a chunky charcoal/ivory guard, mustard spring latch and cyan readiness light.
- `long_barrel.png`: extended barrel attachment rather than a firearm; long charcoal
  tube, ivory heat shroud, brass collar and cyan alignment strip.
- `lucky_coin.png`: thick brass token with abstract concentric mechanical grooves
  and a cyan enamel inset; explicitly no writing or symbolic markings.
- `magnet.png`: rugged industrial horseshoe magnet; squared arms, ivory casing,
  charcoal poles, mustard mount and cyan charge lamps.
- `regen_patch.png`: reusable medical repair patch/module; rectangular ivory pad in
  a charcoal/mustard frame, cyan generic plus window and two attachment tabs.
- `spare_deck.png`: portable field recorder/deck with handle and one visible extra
  tape-reel chamber behind a violet-tinted window; unmarked controls.
- `long_play.png`: chunky cassette cartridge with two oversized reels and extended
  violet tape loop behind a window, with ivory shell and brass locks.
- `loud_speaker.png`: compact powered loudspeaker; broad charcoal cone, ivory angular
  enclosure, brass feet and restrained violet/cyan signal accents.

## Generated source files

| Item | Built-in output filename |
| --- | --- |
| iron_heart | `exec-7b150613-5213-403f-8603-f4170c4a6618.png` |
| sneakers | `exec-0f112704-a838-4c8e-b203-5b3854f024cd.png` |
| sharp_edge | `exec-343a94bf-1110-40ce-95bb-721f966556c9.png` |
| quick_trigger | `exec-01045cdc-9b87-41fc-bd4e-dbc2b2bd1556.png` |
| long_barrel | `exec-5a5d0adc-0b9e-41e8-8010-7071f3466bf4.png` |
| lucky_coin | `exec-d667ca33-7a39-4fca-8dee-1d5a2bdfe07a.png` |
| magnet | `exec-86eb1bb1-c80b-4e0f-954f-437b5c93b35c.png` |
| regen_patch | `exec-b66bb754-8d49-49a4-b15f-cb22e4fcfdb6.png` |
| spare_deck | `exec-42156a55-c4da-4d17-9fbf-e97308827563.png` |
| long_play | `exec-d186db56-5b8d-4c0b-8970-001bd4de587b.png` |
| loud_speaker | `exec-e0a0701b-afd4-4d87-b005-d5d7829196dd.png` |

All source outputs remain under
`/Users/yupeng/.codex/generated_images/01a16842-f0ff-7a23-b839-d5fd27b64ffe/`.
