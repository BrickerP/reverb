# Expedition crew artwork

`crew.png` is original game artwork generated with the built-in OpenAI imagegen tool for Take Stack. The reference was this repository's `assets/presentation/weapons/office_arsenal.png`, used for visual style. The generated PNG is copied byte for byte: alpha inspection and runtime atlas regions do not alter source pixels.

The immutable source-file path, SHA256, canvas dimensions and authored regions are recorded in `carbon_copy_assets.json`; `manifest.json` is the reproducible runtime provenance inventory. The image contains eight authored regions, with the same characters retained across the two hound, turret and tree poses.

## Final generation prompt

Use case: stylized-concept. An eight-cell, four-column by two-row equal-grid 1536 by 1024 transparent-background sprite atlas for an original black-humor hand-drawn office-waste game. STYLE REFERENCE ONLY: the existing office arsenal. Bold rough black ink, muted cream, olive and rust, papery texture, full isolated icon views, ample padding, no text, numbers or background.

Row one: origami paper hound standing with tired drooping ears and a binder-clip collar; the same hound lunging playfully; a stationary battered desk-stapler turret on three paper legs with eyebrows, idle; the same turret firing forward with its bent paper barrel.

Row two: a small patched repair station, a paper first-aid cabinet on staple legs showing tape and needle; a paper tree made from folded newspaper leaves sprouting in an inkpot; the same paper tree freshly grown with wider leaves; a flimsy cardboard decoy bureaucrat with a blank paper face, narrow eyes and a tiny shield.

Readable at 60 pixels, crude affectionate dry humor. Each subject is centered and full body, with true-alpha gutters and outside background. No horizon, drop shadow or glow.

## Runtime handling

- Atlas regions and pose selection are defined by `carbon_copy_assets.json` and generated into `PresentationAssets`.
- Import limit is 512 pixels with mipmaps, matching the established actor/icon budget.
- Recruited Boss companions use their canonical Boss artwork plus a game-native friendly seal. No alternate bitmap is synthesized at runtime.
- Pillow is used for read-only alpha/region verification; the game does not load Pillow or Python.
