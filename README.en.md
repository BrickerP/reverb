# Take Stack / 回响

[中文](README.md) · [Enter the recycling bureau](https://brickerp.github.io/reverb/?lang=en)

**Pick up a playable copy:** [Download for macOS](https://github.com/BrickerP/reverb/releases/latest/download/TakeStack-macos.zip) · [Download for Windows](https://github.com/BrickerP/reverb/releases/latest/download/TakeStack-windows.zip) · [Download for Linux](https://github.com/BrickerP/reverb/releases/latest/download/TakeStack-linux.zip)

[![Take Stack: yesterday's you is today's consumable. A tired paper clerk and a copy vending machine on the bureau noticeboard.](docs/site-assets/readme-cover-en.png)](https://brickerp.github.io/reverb/?lang=en)

At the recycling bureau, even your past self has another shift to work.

Take Stack is a hand-drawn, auto-firing roguelite about fighting alongside your previous routes. Move, build your loadout, and leave an Echo of each encounter's path and equipment. Copies wear down as they replay. Repair one, bind two together, or spend a copy on its final skill—you decide what survives into the next fight.

![Actual combat with an automatic controller: the player and recorded Echoes face hostile office waste.](docs/site-assets/combat-loop.gif)

- **Put your past to work.** Old routes add firepower and replay recorded machine operations. Hold to choose an Echo; tap to scrap it for a final skill shaped by its equipment.
- **Make use of the machinery.** Pull a lever, carry a document, dodge a stamp, or lure enemies into a press. Six roles have distinct abilities; pets, turrets and repair stations can be damaged and expire.
- **Read the terms before signing.** Build from 35 weapons, matching-weapon assembly, family evolution branches and work orders. Repaired machines and rescued workers carry forward through the expedition.
- **Sign your own last page.** Three acts, twelve encounters and three distinct bosses. Leave alone, leave with your colleagues, or take over the bureau. Debt does not choose the ending for you.

[Explore the game](https://brickerp.github.io/reverb/?lang=en) · [Release notes and in-game footage](https://github.com/BrickerP/reverb/releases/latest)

<details>
<summary>Controls, installation and saves</summary>

- Move: WASD / arrow keys / left stick.
- Role ability: Shift / LB. Machine interaction: E / X.
- Scrap an Echo: tap Space / RB. Select one: hold, then release to confirm.
- Pause: P / Esc / Start. Save and return from the pause menu.

Download the ZIP for your platform, extract it, and run the game. The macOS build is ad-hoc signed and is not notarized; follow the included `MAC_START_HERE.txt` on first launch. Windows builds are unsigned and may show a system prompt.

Version 0.17 uses a new suspended-run format, so start a new run when upgrading. Permanent role unlocks, settings and saved Echo archives are kept.

</details>

<details>
<summary>Run from source</summary>

Use **Godot 4.7.2**. These commands check out the source corresponding to the public 0.17 release:

```bash
git clone --branch v0.17.0 https://github.com/BrickerP/reverb.git
cd reverb
make run
```

You can also open `project.godot` in Godot and press F5. Use `make run-zh` for Chinese.

[Gameplay interfaces](https://github.com/BrickerP/reverb/blob/v0.17.0/INTERFACES.md) · [Art direction](https://github.com/BrickerP/reverb/blob/v0.17.0/docs/art-direction.md) · [Validation scope](https://github.com/BrickerP/reverb/blob/v0.17.0/docs/closeout-acceptance.md)

</details>

Code and docs are [MIT licensed](LICENSE). See the [art direction](https://github.com/BrickerP/reverb/blob/v0.17.0/docs/art-direction.md) and [third-party notices](THIRD_PARTY.md) for artwork provenance, audio sources and bundled font licenses.
