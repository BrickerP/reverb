# Recycling bureau landmarks

`depot_landmarks.png` is original Carbon Copy Purgatory production artwork made
with the built-in image-generation tool on 2026-10-29. The three static props
are a rejected-mail feeder/conveyor, a scrap-processing stamp workstation, and
a crooked blank notice board. Characters and machinery from the existing
project were used only as visual references.

The generated RGBA file was copied without repainting, cropping, resampling or
alpha replacement. Its three measured source regions are independent sprite
cuts, not animation cells. The generated layout does not use equal columns;
the renderer uses explicit measured rectangles. All lettering is live localized
Godot text. The belt tick, paper feed, rubber shoe and lamp are restrained native
drawing layered onto the atlas, with a static Reduced Effects presentation.

The floor is the replacement production image in
`../surfaces/arena_floor.png`; no generic crate-wall background is retained as
another environment path. Exact prompts, reference/source paths, dimensions
and hashes are in `carbon_copy_assets.json`, with measured rectangles in
`manifest.json`.
