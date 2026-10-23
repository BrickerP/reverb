# Presentation artwork — first slice

Created on 2026-10-23 with the built-in image generation tool. These are original
generated PNG outputs, copied without destructive image editing. Visible alpha
regions (alpha >= 20/255) were measured offline and recorded in `manifest.json`.
`PresentationAssets` stores those bounds and scales them to the imported texture
size; it never scans pixels during gameplay. Godot imports at a maximum of 512 px
with mipmaps for stable minification, while the original PNGs remain unchanged.

Style reference: `take-stack-visual-direction-v1.png`, the concept board produced
in the same design session. The PNGs are single-pose sprites, not frame animation
sheets or 3D models. World motion is currently procedural sway/bob; family variants
reuse the closest silhouette. Rich combat events are available after integrating
mechanics `8f555e4`; this slice still uses compatible legacy signals, so precise
per-weapon firing animation and audio remain a presentation follow-up.

## Generation prompts

Common actor specification: isolated production-oriented 2D game sprite matching
the reference's crisp illustrated matte equipment, bold clean contour and restrained
shading; square canvas, genuine transparent background, no floor, cast shadow, text,
labels, UI, grid or extra objects; whole asset uncropped with clear padding; readable
at approximately 40–60 display pixels; single static pose.

- `player.png`: compact recording operator in off-white/beige armor, cyan visor,
  dark trousers and boots, recording backpack and mustard accents. Full body,
  slightly facing screen-right at an elevated top-down viewpoint. Distinct head,
  torso, arms and feet, neutral ready stance, empty hands, no gun or halo.
- `enemy_grunt.png`: squat four-legged armored scavenger robot, rounded brown and
  charcoal shell, orange eyes, short angular legs, facing diagonally down-left.
- `enemy_runner.png`: narrow pointed scout creature-machine, charcoal/rust shell,
  orange eyes, front claws and rear legs, facing diagonally down-left; distinct from
  the grunt silhouette.

Common weapon specification: one isolated side-view weapon, slightly elevated,
long axis horizontal and muzzle pointing right; matte ivory/charcoal equipment,
clean outline, restrained shading, genuine transparent background, no person,
hands, floor, shadow, text, ammo, projectile or muzzle flash. Usable both as small
world weapon and larger UI thumbnail.

- `weapon_pistol.png`: compact chunky pistol, ivory casing, charcoal grip, cyan
  muzzle accent and one amber detail, matching the reference pistol.
- `weapon_shotgun.png`: stout broad double-barrel scattergun, ivory receiver,
  dark grip, burnt-orange chamber and foregrip, no scope.
- `weapon_orb.png`: compact arcane pulse emitter, ivory/charcoal housing holding
  a violet sphere, small lower-left grip, emitter facing right, restrained light
  near the sphere and a distinct round silhouette.

## Generated source files

All originals are retained under the session's generated-images directory:

| Asset | Source filename |
|---|---|
| player | `exec-d7d37d24-67e3-41dd-86fc-257c1ad6c5c3.png` |
| enemy_grunt | `exec-bc4790ce-43ed-49a4-bb3b-7b42b8ae0920.png` |
| enemy_runner | `exec-905060b9-55a5-4ccd-9006-4d566eb48762.png` |
| weapon_pistol | `exec-c3092e21-b9f9-4431-a59e-d1fa1ee09dc5.png` |
| weapon_shotgun | `exec-3a7c895e-431e-472c-8740-bd8b58b53ed8.png` |
| weapon_orb | `exec-1414532b-f29b-4e8e-8b42-3589f789020a.png` |

`manifest.json` records the exact file hashes, pixel dimensions and visible alpha
bounds of the imported originals. Runtime attribution is independent of the CC0
audio sources, which are documented in `audio/presentation/SOURCES.md`.
