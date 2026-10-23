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
