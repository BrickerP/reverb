# Front-page media

This page reuses Take Stack production artwork and real game capture. It introduces no replacement game assets.

- `player.png` and `facilities.png` are unchanged RGBA sources from game release `v0.17.0` / `cd07f16`. Browser SVG view boxes use measured regions from `PresentationAssets` and the bureau manifest. Original prompts and provenance: [production sources](https://github.com/BrickerP/reverb/blob/v0.17.0/assets/presentation/bureau/SOURCES.md), [art direction](https://github.com/BrickerP/reverb/blob/v0.17.0/docs/art-direction.md).
- `readme-cover-zh.png` / `readme-cover-en.png` are 1200×540 browser renders of this page's `#readme-cover`, with reduced motion enabled and bundled display fonts loaded. The composition and lettering come from HTML/CSS, while game pixels remain unchanged. These are promotional covers, not gameplay screenshots.
- `shop-{zh,en}.png` and `archive-{zh,en}.png` are native 0.17 UI captures from disclosed clinical fixtures. They demonstrate real interfaces and rules; they are not human playthrough or economy-balance evidence.
- `combat-loop.mp4`, `combat-cover.png` and the README animation show the actual 0.17 game with a balanced automatic controller and normal budgets. Earlier encounters are prepared through real simulation; the captured interval runs at normal speed. Exact seed, stages, frame counts, loadout and read-only state/RNG checks are in `combat-source.json`. The video is muted for its optional looping presentation.
- `AmaticSC-Bold.ttf` and `ZCOOLKuaiLe-Regular.ttf` are the game's bundled display fonts. Their OFL license files are included beside them. Body text uses the viewer's system font; the 16MB CJK game font is not loaded by this site.

The page is original semantic HTML/CSS with a small bilingual text switch. The retired three-second-follow canvas experiment is not part of the game download.
