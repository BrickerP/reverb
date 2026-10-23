# Presentation audio sources

The five WAV files in this directory are derived from Kenney's public-domain
sound packs. Both source packs are licensed **Creative Commons Zero (CC0)**.

- Interface Sounds 1.0: https://kenney.nl/assets/interface-sounds
  - Download used: `kenney_interface-sounds.zip`
  - SHA-256: `f2193d072726d6758a5f7871b2dcc54dcce0d5c35c6f0a62f92549b327c81232`
- Impact Sounds 1.0: https://kenney.nl/assets/impact-sounds
  - Download used: `kenney_impact-sounds.zip`
  - SHA-256: `029d734af1582474edf3a694d1b0cebc97c1c152f2f39fa34d4c2bafc5de77f8`
- License: https://creativecommons.org/publicdomain/zero/1.0/

The original archives include `License.txt` files that identify Kenney as the
creator/distributor and state the CC0 license. Credit is optional under that
license; it is recorded here for traceability.

| Output | Source clips | Treatment |
| --- | --- | --- |
| `click.wav` | Interface `click_001.ogg` | Shortened, high-pass filtered, faded and level-limited |
| `buy.wav` | Interface `confirmation_003.ogg`; Impact `impactPlate_light_001.ogg` | Layered confirmation and light mechanical plate closure |
| `hit.wav` | Impact `impactMetal_light_004.ogg` | Band-limited, shortened and faded for rapid repeated hits |
| `echo.wav` | Interface `switch_003.ogg` | Level-shaped switch with a short decaying echo tail |
| `wave_end.wav` | Interface `confirmation_002.ogg`; Impact `impactBell_heavy_001.ogg` | Layered confirmation and cropped bell tail |

`tools/build_presentation_audio.py` downloads the exact official archives and
decodes each source to a fixed PCM intermediate before reproducing these 44.1
kHz, mono, 16-bit PCM WAV files using `ffmpeg`. Its output limiter targets a
peak no higher than 0.70 full scale (about -3.1 dBFS), and the builder rejects
wrong formats, silent files, out-of-range peaks and cues longer than one second.
