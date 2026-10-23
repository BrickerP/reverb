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

## Rich combat and transaction feedback

`tools/build_feedback_audio.py` uses the same checksum-pinned CC0 archives and
the same fixed-PCM render path. It adds physical, sub-second cues without
changing the five WAV files above.

| Outputs | Kenney source clips | Treatment |
| --- | --- | --- |
| `weapon_pistol`, `weapon_smg` | Impact `impactMetal_light_000/001` | Short, filtered mechanical snaps |
| `weapon_shotgun`, `weapon_rifle` | Impact `impactMetal_heavy_000`, `impactMetal_medium_003` | Weighty close blast and tighter long report |
| `weapon_orb` | Interface `glass_003`; Impact `impactBell_heavy_003` | Glass launch layered with a quiet resonant body |
| `weapon_flechette` | Impact `impactMetal_light_003`, `impactGeneric_light_003` | Layered needle-like mechanical release |
| `weapon_longbow` | Interface `pluck_001` | Natural pluck; intentionally no firearm burst |
| `weapon_hex_bolt` | Interface `glass_005`, `switch_004` | Glassy arcane release with switch body |
| `weapon_twin_fangs` | Impact `impactMetal_light_000/002` | Two offset light strikes |
| `weapon_flak_crown` | Impact `impactMetal_heavy_002`, `impactPlate_heavy_001` | Heavy blast with plate tail |
| `weapon_rail_spike` | Impact `impactMetal_heavy_004`, `impactMetal_medium_004` | Dense spike strike with a short metallic tail |
| `weapon_nova_core` | Impact `impactBell_heavy_003`; Interface `glass_003` | Bell body and glass transient |
| `hit_crit`, `shield_block` | Impact `impactMetal_medium_002`, `impactPlate_heavy_001` | Strong critical strike and distinct shield clang |
| `weapon_explosion`, `bomber_explosion` | Impact punch/metal and punch/soft layers | Separate compact weapon blast and heavier bomber body |
| `hurt_contact`, `hurt_blast` | Impact `impactSoft_medium_002`, `impactPunch_heavy_000` | Contact body hit and explosive player hit |
| `equipment_apply`, `equipment_undo`, `shop_reroll` | Interface confirmation/back/switch; Impact plate | Mechanical transaction confirmation, reversal and reroll |

Every added file is mono 44.1 kHz 16-bit PCM, lasts at most one second, and
passes the same silence and peak bounds as the original presentation set.

## Existing ambient bed

`audio/ambient.wav` is original deterministic procedural synthesis from
`tools/gen_audio.py`, not a third-party recording. It is a 12-second seamless
55/110/165 Hz sine drone with a whole-cycle low-frequency envelope. Its SHA-256
is `ac5b898712d821859faf7698f61b4a6652fb459f5eeed56c054ad02589eecec9`.
