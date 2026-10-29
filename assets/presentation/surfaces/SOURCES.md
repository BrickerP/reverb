# World and UI illustration sources

`arena_floor.png` is the 2026-10-29 recycling-bureau replacement: warm ash/sage
paper work floor, sparse low ink edge channels and stapled seams. The generic
crate and fence wall is removed. Its quiet center supports the original paper
actors; the recycling machinery and live notices are separate edge landmarks in
`../environment/depot_landmarks.png`.

`recording_cartridge.png` retains the original approved
Carbon Copy Purgatory production artwork. `shopkeeper.png` adds a soft,
hand-inked scrap merchant with four event-driven expressions: tired, payment,
empty hands and a round bite mouth.

The merchant was generated and spacing-refined with the built-in image tool
on 2026-10-29. Each frame is complete inside its own horizontal quarter; the
final transparent PNG was copied without programmatic repainting. Exact
prompts, source paths, dimensions, alpha bounds and SHA256 are in
`carbon_copy_assets.json`; authoritative measured bounds are in `manifest.json`.

The previous `panel_skin.png` is removed. All interface surfaces now use the
native `InkStyleBox` curves, so no old rectangular raster skin is retained as
a second styling path.
