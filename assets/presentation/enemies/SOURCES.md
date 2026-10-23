# Special enemy artwork

Generated on 2026-10-23 with the built-in image generation tool. The PNGs in
this folder are unchanged copies of the original generated files. They are
single-pose transparent sprites, intended to replace the temporary shared grunt
body for the five special enemy IDs. Import settings and runtime integration are
handled separately.

The existing `enemy_grunt.png` and `enemy_runner.png` were supplied to the tool
only as references for the project's crisp illustrated metal treatment and
slightly elevated top-down three-quarter camera. The prompts explicitly required
new silhouettes rather than copied bodies.

All prompts shared these requirements: one complete isolated mechanical enemy;
bold clean contour and restrained cel-like shading; matte charcoal, warm gray and
rust-orange scavenger materials; readable at roughly 40–80 display pixels (70–120
for the boss); genuine transparent background; no text, UI, floor, environment,
cast shadow, halo, border, duplicate subject, photorealism, fuzzy edges or heavy
bloom.

## Asset prompts

### `brute.png`

Heavy broad armored scavenger combat machine: a low-slung six-legged mechanical
bruiser with a very wide tank-like chassis, massive layered frontal armor,
oversized reinforced shoulder/foreleg plates and tiny recessed orange optics.
Facing diagonally down-left. Its wide, dense silhouette must communicate weight.

Original: `exec-f286a18a-8244-455d-8ebd-8edf6a48bdf8.png`

### `silencer.png`

Narrow stealthy electronic-jamming scavenger: a hooded mechanical stalker with
four thin articulated legs, a recessed masked face, forked antenna mast and
compact jammer coils/dish integrated into its back. Cold violet and pale-blue
signal details distinguish the silence function. Facing diagonally down-left;
avoid robes, organic humanoid anatomy and copying the runner body.

Original: `exec-d5404e39-9f9a-4025-8da9-8839ed83a72a.png`

### `bomber.png`

Compact unstable self-destructing scavenger: a round armored crawler with four
short clamp legs, exposed orange reactor chamber, segmented warning shutters and
a mechanical charge assembly. It must communicate impending explosion without
showing an active blast, flame or smoke. Facing diagonally down-left.

Original: `exec-1d352aad-9ad8-4af0-9df2-879938c645ae.png`

### `warden.png`

Directional guardian: a squat four-legged machine with a broad physical shield
plate built into its front, like a thick angular plow or buckler covering its face
and forward legs. Rear and flanks are visibly less protected; a small amber sensor
slit sits behind the plate. Facing diagonally down-left so the protected direction
is unmistakable. No force-field bubble or separate shield aura.

Original: `exec-c696e748-99fa-4a54-80e6-974e43208f8b.png`

### `paradox.png`

Large recording-and-time-distortion boss: an imposing low crawler with a central
tape-reel/timepiece core, two segmented mechanical recording rings integrated
around its body, asymmetric rewind-head modules and four heavy anchor legs.
Violet/cyan recording accents remain contained within the machinery. No numbered
clock face, magical portal or separate external VFX rings.

Original: `exec-fd1a26f8-d05b-4a12-a8fc-7b6670d8b482.png`

## Integrity and crop metadata

`manifest.json` records the original generated filename, SHA-256, source pixel
size, RGBA mode and the exclusive left/top/right/bottom bounding rectangle for
pixels whose alpha is at least 20/255. The files were not cropped or transformed;
the bounds are metadata for runtime region selection.
