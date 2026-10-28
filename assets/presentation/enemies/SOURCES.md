# Carbon Copy Purgatory enemy animation artwork

Produced with the built-in image generation tool on 2026-10-28, using the approved
Take Stack art-direction board as a style reference. These files replace the prior
mechanical-scavenger artwork. Selected PNG files are unchanged copies of tool
outputs; runtime pixel scanning or image manipulation is not required.

`carbon_copy_assets.json` contains complete prompts, original output paths,
SHA-256 hashes, dimensions, per-frame visible bounds, pivots and transparency QA
for all seven enemies. `manifest.json` lists the five files in this directory;
the two base enemy files remain in the parent presentation directory.

Every sheet has four equal columns and one row on a transparent 2172 x 724 canvas
(543 x 724 per cell). Frame 0 is idle, frames 1 and 2 provide distinct foot/body
or mouth poses, and frame 3 is a crushed or creased hurt pose. Paradox instead
supplies intact, bellowing, left torn half and right torn half poses.
At alpha >= 20/255 all three cell boundaries are clear in every sheet.

| File | Identity |
| --- | --- |
| `../enemy_grunt.png` | Worn squat eraser scrap with a crooked grin |
| `../enemy_runner.png` | Sharp V-shaped binder-clip bug with alternating long legs |
| `brute.png` | Broad, tooth-slot shredder beast with chewing and crushing poses |
| `silencer.png` | Narrow living ink bottle with its mouth sealed by a paper X |
| `bomber.png` | Inflated discarded paper sack tied with a red drawstring |
| `warden.png` | Rubber-stamp goblin behind a thick folded file-folder shield |
| `paradox.png` | Smug Original paper figure stapled down the center, then torn in two |

The shared visual contract is a thick irregular ink contour, flat cream/sage/
charcoal/brick-red fills, restrained cel shadows and readable major shapes. No
labels, gameplay hazard circles or new collision geometry are embedded in the art.
Brute's accidental ground ellipses and Paradox's detached cross-cell reaction marks
were removed by targeted built-in image edits. See the manifest for exact sources.
