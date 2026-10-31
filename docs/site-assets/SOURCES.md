# Front-page media

This page reuses Take Stack production artwork and real game capture. It introduces no replacement game assets.

- `player.png` and `facilities.png` are unchanged RGBA sources from game release `v0.17.0` / `cd07f16`. Browser SVG view boxes use measured regions from `PresentationAssets` and the bureau manifest. Original prompts and provenance: [production sources](https://github.com/BrickerP/reverb/blob/v0.17.0/assets/presentation/bureau/SOURCES.md), [art direction](https://github.com/BrickerP/reverb/blob/v0.17.0/docs/art-direction.md).
- `readme-cover-zh.png` / `readme-cover-en.png` are 1200×540 browser renders of this page's `#readme-cover`, with reduced motion enabled and bundled display fonts loaded. The composition and lettering come from HTML/CSS, while game pixels remain unchanged. These are promotional covers, not gameplay screenshots. Both were regenerated for the English-first front page and the bureau notice “You’re dead. Your shift isn’t.” / “人没了，班还得上。”. Versioned page references prevent cached banners or scripts from restoring the retired wording.
- `shop-{zh,en}.png` and `archive-{zh,en}.png` are native 0.17 UI captures from disclosed clinical fixtures. They demonstrate real interfaces and rules; they are not human playthrough or economy-balance evidence.
- `combat-loop.mp4`, `combat-cover.png` and `combat-loop.gif` are the Chinese in-game capture. `combat-loop-en.mp4`, `combat-cover-en.png` and `combat-loop-en.gif` are the English HUD capture of the same kind of run: seed 20261022, balanced automatic controller, encounter 3 after encounters 1–2 were simulated, then 18 seconds recorded at normal speed. Both are muted. The English page and README use the English files; Chinese keeps the original.
- `AmaticSC-Bold.ttf` and `ZCOOLKuaiLe-Regular.ttf` are the game's bundled display fonts. Their OFL license files are included beside them. Body text uses the viewer's system font; the 16MB CJK game font is not loaded by this site.

The page is original semantic HTML/CSS with a small bilingual text switch. The retired three-second-follow canvas experiment is not part of the game download.
