# Take Stack / 回响

[中文](README.md)

**Yesterday's you is today's consumable.**

In the scrap-recycling bureau you move, and the weapons fire themselves. Each fight leaves an Echo. It wears out. You can staple it, repair it, or scrap it early. The ending is a signature. Debt does not choose it for you.

![You move. The weapons fire.](docs/wave.png)

You move. The weapons fire.

![Echoes wear out](docs/echo_selection.png)

Echoes wear out. Pick one to staple, repair, or spend.

![Choices leave a signature](docs/story.png)

Choices leave a signature.

## Download

Builds are on [GitHub Releases](https://github.com/BrickerP/reverb/releases). For 0.16, use the page for that tag.

- **macOS**: ad-hoc signature, not notarized. A “damaged” warning means the system does not trust an un-notarized app.
- **Windows**: unsigned. SmartScreen may complain.
- **Linux**: mark `TakeStack.x86_64` executable, then run it.

To try the verb first, open [thirty seconds on paper](docs/play/index.html). That is not the game. You walk, a copy from three seconds ago follows, then it is crumpled.

## Roles

![Six paper clerks](docs/select.png)

<details>
<summary>Six people, six ways to move</summary>

| Role | Skill | Unlock |
|---|---|---|
| Creased / 折痕 | Rewind your position, Echo playback, and weapon cooldown | Start |
| Reject / 拒收件 | No Echoes. A paper dash that hurts along its path and blocks briefly | Best stage 4 |
| Misprint / 套印件 | Swap places with the selected Echo | Clear once |
| Binder / 装订员 | Three arcing bolts, anchored on the selected Echo | Best stage 8 |
| Mender / 修补员 | Drop a repair station with limited uses | Best stage 3 |
| Overloader / 超载员 | Scrap the selected Echo. The burst scales with durability left | Best stage 7 |

The role skill and Echo scrap are different buttons. A skill that cannot fire does not spend energy.

</details>

## Work orders

![Work orders in the shop](docs/shop.png)

<details>
<summary>What you are responsible for next</summary>

The shop always offers six goods: two weapons, two passives, two different work orders. You hold one order at a time.

| Order | Next fight |
|---|---|
| Salvage | You must pick up the parts yourself |
| Audit | Terminals become real hazards. Finishing grants clearance. It does not pick your ending |
| Repair | Fix a machine that is already broken. You can fix it without buying the order |
| Rescue | Coworkers can actually die. A saved person joins the roster. They do not become bait |
| Recruit | After the boss falls, the fight pauses for that boss's own terms |
| Credit | Take 30 materials now. Owe 40. You can pay it back later |

Breakdowns and people in danger come from the next shift. Buying an order means taking the job, not purchasing the danger.

</details>

## Endings

<details>
<summary>After stage 12, you sign</summary>

- **Release**: free if you have clearance, otherwise you pay and your current Echoes are repaired.
- **Leave together**: someone you actually saved has to still be here.
- **Take over the bureau**: you stay. The last Echo becomes staff and leaves the fight.

Debt stays on the books. It does not automatically become the bad ending.

</details>

## Controls

| Action | Key |
|---|---|
| Move | WASD / arrows / left stick |
| Fire | Automatic |
| Role skill | Shift / LB |
| Use a machine | E / X |
| Scrap the selected Echo | Tap Space / RB |
| Pick another Echo | Hold Space / RB, release to confirm |
| Pause | P / Esc / Start |

A fight can be saved and continued from the title. Runs saved on 0.15 or earlier cannot resume. Unlocks, settings, and Echo archives remain.

Numbers, slots, and the save format live in [DESIGN.md](DESIGN.md). Picture and combat direction live in [art-direction.md](docs/art-direction.md) and [battle-direction.md](docs/battle-direction.md).

Source needs **Godot 4.7.2**:

```bash
git clone https://github.com/BrickerP/reverb.git
cd reverb
make run
```

Language follows the system. Override with `make run-zh` or `REVERB_LANG=en`.

## License

Code and docs are [MIT](LICENSE). Fonts and third-party assets are in [THIRD_PARTY.md](THIRD_PARTY.md).
