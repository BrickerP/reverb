# Bureau rituals production sources

Two original RGBA atlases were produced with the built-in imagegen tool from the user-provided Cursor concept illustrations and the existing Take Stack player atlas. Original generated pixels are copied unchanged; transparency, regions and pivots are measured offline. No pixel repainting, compositing or background removal was applied after generation.

- Facilities: vending closed/open, copier closed/printing, stamp raised/down, inbox, archive drawer. The open bay and copier output are deliberately blank so the UI can render the actual saved identity rather than a fabricated person.
- Binding: pair, descending stapler, compression, one bound body; bound idle, unstapler, separation, two restored bodies. The second half depicts a successful canonical Shop Undo.

Each source is a1536x1024 image. Eight cells form a4x2 authored layout. Facilities are eight static identities; binding is one eight-pose strip. `carbon_copy_assets.json` preserves source paths, reference roles, pose order, hashes and alpha counts. `manifest.json` contains measured bounds.

## Prompt set

Facilities generation: convert the vending/confession machine concepts to chunky paper-cartoon game props. Transparent RGBA, exactly4x2 equal cells, thick uneven ink, cream/moldgreen/red accents, eight declared facilities, no lettering, no background and readable at80–160pixels. Targeted edit removed the generic vending person and copier portrait while keeping the machines and blank output sheet.

Binding generation: transform stapled/unstapled paper-puppet concepts into an eight-pose4x2 strip matching the current player. Frames0/7 contain two originals, frames3/4 contain one bound body; red office tools, flat cream folds, no text/background. Targeted layout edit placed every puppet/tool within its own384x512cell with transparent gutters.

These are project-bound production assets, not claims that the reference concept boards themselves were runtime-ready. References remain outside the shipped asset inventory.
