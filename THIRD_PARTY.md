# Third-party notices

## gamedev agent skills

`.agents/skills/` is installed from
[gamedev-skills/awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills)
and is licensed under the Apache License 2.0:
https://www.apache.org/licenses/LICENSE-2.0

These files are development tooling for AI coding agents. They are not loaded
by the game at runtime. `skills-lock.json` records the installed versions.

## Fonts

The game bundles **Noto Sans CJK SC Regular** at
`assets/fonts/NotoSansCJKsc-Regular.otf` so Chinese text does not depend on a
system font. It is licensed under the SIL Open Font License 1.1; the full text
is in `assets/fonts/OFL.txt`.

Source: <https://github.com/notofonts/noto-cjk>

System CJK fonts (Hiragino Sans GB, PingFang SC, Noto Sans CJK SC, Source Han
Sans SC, Microsoft YaHei, WenQuanYi Micro Hei) remain as a fallback when the
bundled font cannot be loaded.

## Godot Engine

Built with [Godot Engine](https://godotengine.org/), MIT licensed.

## Hand-drawn display fonts

Amatic SC Bold (`assets/fonts/AmaticSC-Bold.ttf`) and ZCOOL KuaiLe
(`assets/fonts/ZCOOLKuaiLe-Regular.ttf`) are bundled under the SIL Open Font
License 1.1. Full licenses are `assets/fonts/AmaticSC-OFL.txt` and
`assets/fonts/ZCOOLKuaiLe-OFL.txt`; original URLs and byte hashes are recorded
in `assets/fonts/SOURCES.json`. These notices and licenses are included in
each audited export. Noto Sans CJK SC remains the body font.

## Recorded object sounds

The paperbureau palette layers processed recordings from Kenney Interface Sounds
and Impact Sounds, licensed Creative Commons Zero (CC0), with original granular
paper synthesis. Original clip names, checksum-pinned source archives, preserved
development inputs and reproduction are recorded in `audio/presentation/SOURCES.md`.
License: https://creativecommons.org/publicdomain/zero/1.0/ . Development source
snapshots are excluded from game exports; the provenance notice is included.

## Original score

**Paperwork Waltz** is original melodic material authored for Take Stack with
Codex. Its score, synthesizer recipe and five 96-second arrangement files follow
the repository [MIT license](LICENSE). They use no commercial composition, stock
MIDI, SoundFont or sampled acoustic instrument. The synthesized piano/reed voices
are not claimed to be recordings of acoustic instruments.

Each arrangement includes the existing quiet room layer; its Kenney CC0 object
recording and original synthesis provenance remains in
`audio/presentation/SOURCES.md`. The complete score recipe, source hash and
finished-track hashes are in `audio/music/SOURCES.md` and `audio/music/score.json`.
NumPy 2.0.2 is a development-only generation/test dependency in
`tools/requirements-audio.txt`; Python and NumPy are not required by the game.
