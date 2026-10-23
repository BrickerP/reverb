# Character direction artwork

Generated on 2026-10-23 with the built-in image generation tool. The seven PNGs
in this folder are unchanged copies of the selected generated outputs. Existing
`assets/presentation/player.png` remains the Looper front pose; this set adds its
back pose and front/back identities for Soloist, Mirror and Conductor.

These are two direction choices, not walk or attack animation sheets. Runtime may
mirror each pose horizontally for left/right movement. The front poses use the
same elevated three-quarter view as the original operator, facing right/down. The
back poses face right/up and were generated with their corresponding accepted
front pose as the exact identity reference.

All prompts required genuine transparent background, a complete uncropped body,
both boots and all backpack parts, empty hands, clear padding and a bold silhouette
readable at 40–60 pixels. They prohibited weapons, text, UI, floor, environment,
cast shadows, halos, borders, photorealism and heavy bloom.

## Front identities

### `solo_front.png`

Lean lone operator in amber/ochre and ivory armor with charcoal clothing, a short
split longcoat/tabard, narrow amber visor and compact single-purpose backpack.
Small cyan technical details connect the character to the common equipment world;
the silhouette intentionally has no echo-recorder antenna array.

Original: `exec-92f9d898-026f-4be1-9093-e06b85994128.png`

### `mirror_front.png`

Compact silver/charcoal operator with restrained violet accents, smooth mirrored
visor and a symmetric twin-panel recorder rig behind both shoulders. Paired violet
recording fins and panel symmetry communicate the live-duplication identity.

Original: `exec-5a91d0d6-5b4f-4cc1-8da3-e26c8e16647c.png`

### `conductor_front.png`

Sturdy teal/ivory controller operator with broad shoulder armor, restrained brass
hardware, wrist controls and a horizontal four-channel backpack with four capped
signal posts. The equipment reads as a recording controller rather than a costume.

Original: `exec-7b60cd6e-7dfb-4887-9db9-3814fc9dc688.png`

## Back directions

Each back prompt changed only the viewing direction while preserving the accepted
front character's proportions, palette, equipment, panel shapes, line weight and
camera elevation. Each character faces right/up and exposes the complete rear
helmet, backpack and boot backs.

- `looper_back.png`: original `exec-7720b07a-12d7-4078-9d59-7a3b2b56515b.png`.
  A previous candidate with a gray semi-transparent fringe was rejected and was
  not copied into the project.
- `solo_back.png`: original `exec-1e91c0a8-87ff-4116-bc52-74047c1ea98b.png`.
  The compact pack and split coat tails remain visible.
- `mirror_back.png`: original `exec-14a1d45f-76cc-4510-aa5e-2e2196a63459.png`.
  Both recorder panels and both violet fins remain visible.
- `conductor_back.png`: original `exec-93e80b83-8021-4942-bc95-65c28705ea6c.png`.
  All four capped channels and the broad shoulder silhouette remain visible.

## Integrity and crop metadata

`manifest.json` records each selected original filename, SHA-256, source size,
RGBA mode and the exclusive left/top/right/bottom rectangle for pixels whose alpha
is at least 20/255. No source was cropped, rescaled, recolored or otherwise edited;
the bounds are metadata for later runtime region selection.
