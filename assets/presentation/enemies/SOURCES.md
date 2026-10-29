# Enemy motion artwork

Original creatures use the Carbon Copy Purgatory identity: cream paper, muted
gray or red, thick ink contours, tired faces and small complete silhouettes.
They are original eraser, clip, shredder, bottle, bag, stamp and paper creatures.

`carbon_copy_assets.json` is the production source catalog. Each entry identifies
the current PNG, original generated output, old identity reference, exact prompt
and any refinement prompt, byte hash, columns/rows, local alpha bounds and pivots.
PNG bytes are copied unchanged from the built-in image generation tool. No pixel
repainting or resampling is performed by scripts.

All seven current PNGs are 1536 by 1024 RGBA eight-frame atlases. The format is
row-major, four columns and two rows. Ordinary actors
use idle, alternating steps, hurt, action start, followthrough and two death
drawings. The Original boss has intact, roar, left half, right half, two tearing
poses, whole crumple and torn-flat poses. The runtime reads the per-file grid
dimensions, rather than guessing the sheet layout from its aspect ratio.

All current accepted eight-frame sheets have nonempty poses and transparent
internal grid lines at the visible-alpha threshold 20/255. Their frame pivot X
is fixed at the cell center; pivot Y is the measured alpha-bottom, allowing the
renderer to keep the actor's feet planted without altering source PNG pixels.
`manifest.json` and runtime bounds are generated separately by the root asset
catalog synchronizer from the actual file bytes.
