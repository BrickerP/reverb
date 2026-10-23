# Presentation surface artwork

Created on 2026-10-23 with the built-in image generation tool. The three selected
outputs are copied unchanged: no cropping, resampling, cleanup or compositing was
performed. `manifest.json` records exact hashes, source dimensions, image modes
and alpha bounds at the project's existing 20/255 visibility threshold.

The style reference was the existing `assets/presentation/player.png` and
`assets/presentation/items/spare_deck.png`: matte ivory/charcoal hardware, small
warm-metal parts, restrained cyan status lighting and clean, readable contours.

## Assets and prompts

### `arena_floor.png`

An opaque, wide, perfectly top-down industrial recording-chamber floor. Graphite
and very dark navy modular panels with subtle wear and cool ambient light. The
central 85% is deliberately quiet, dark and even for dense combat; cable conduits,
thin rails, service seams and sparse hardware stay at the perimeter. No characters,
props, text, arrows, UI, hazard stripes, luminous hotspots, perspective or baked
collision border.

Built-in output: `exec-c1a760be-a4c8-42da-9837-55cc325e85eb.png`.

### `recording_cartridge.png`

A genuinely transparent, mostly front-facing horizontal recording cartridge,
readable at 64px. Ivory/charcoal shell, brass latch, cyan recording accent, two
compact reels and a completely blank label area. It is intentionally distinct
from the violet Long Play item. No text, purple tape glow, backdrop or cast shadow.

Built-in output: `exec-5737e085-83f8-424b-a3ce-f6b57f138eb5.png`.

The generated file contains very low-alpha canvas noise outside the recorded
20/255 visible bounds. Runtime integration should use the manifest bounds while
retaining the original source bytes, as the existing presentation catalog does.

### `panel_skin.png`

An opaque, square, perfectly front-facing equipment-panel surface for nine-patch
use. It has a modest graphite border, softly rounded visual corners, small aged
brass corner insets and a nearly uniform brushed graphite center. No controls,
icons, labels, central screws, highlights, shadows, perspective or baked UI.

Built-in output: `exec-b971844e-5e78-48d9-870c-489aeadfa773.png`.

Observed source geometry suggests an initial nine-patch margin near **80 source
pixels on each side**. This is only an integration recommendation; it has not been
configured or runtime-tested here. The parent UI task should tune the margins at
actual display sizes before treating them as a contract.

All generated source outputs remain under
`/Users/yupeng/.codex/generated_images/01a16842-f0ff-7a23-b839-d5fd27b64ffe/`.
