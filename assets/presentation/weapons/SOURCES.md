# Weapon artwork — full identity pass

Created on 2026-10-23 with the built-in image generation tool. Each PNG is the
original generated RGBA file copied without cropping, resizing, color correction
or other pixel edits. `manifest.json` records its source filename, SHA-256, source
dimensions and the exclusive visible-alpha bounds measured at alpha >= 20/255.

The existing `weapon_pistol.png`, `weapon_shotgun.png` and `weapon_orb.png` were
used only as style references. All nine outputs are new images. Their role is to
give every base weapon and evolution a readable silhouette rather than continuing
to reuse one picture per family.

## Common prompt contract

All calls requested a transparent 2D production sprite for a top-down roguelite,
readable at roughly 32–64 display pixels: crisp illustrated matte equipment,
ivory/off-white casing, charcoal structure, bold clean contour and restrained cel
shading. The weapon is isolated, fully visible and padded, with a side or slightly
elevated side view and its firing direction toward screen-right. Prompts prohibit
hands, people, loose ammunition, projectiles, muzzle flashes, floors, cast shadows,
text, logos, letters, numbers, UI and scenery, and ask for restrained internal
light rather than bloom-heavy effects.

## Per-asset prompt details

| ID | Distinct request | Family color |
| --- | --- | --- |
| `smg` | Compact rectangular receiver, short barrel, obvious box magazine and stub/folding stock; lighter and faster than pistol/shotgun. | Mint-cyan, small mustard hardware |
| `rifle` | Long slim precision barrel, stock, compact sight and small straight magazine; high-damage piercing marksman silhouette. | Coral-pink, small mustard hardware |
| `flechette` | Compact three-channel triangular muzzle cluster for a precise three-dart fan, narrower than the shotgun. | Amber/gold, tiny cyan status light |
| `longbow` | An actual mechanical bow with long curved limbs, taut string, central ivory riser and right-pointing arrow rest; no firearm barrel or loose arrow. | Amber/copper, tiny coral light |
| `hex_bolt` | Slender faceted six-sided receiver with forked prongs around a contained crystal chamber; no round orb or written runes. | Icy blue and violet, mustard clamp |
| `twin_fangs` | One integrated evolved sidearm with two separated parallel muzzles on one receiver, clearly expressing two projectiles. | Cyan-white, mustard clamp |
| `flak_crown` | Stout evolved scatter weapon with a crown/fan of multiple short muzzle ports and broad armored chamber. | Evolved gold/amber, tiny cyan light |
| `rail_spike` | Very long evolved railgun with two parallel rails framing a central spike channel and compact rear stock. | Hot pink/coral, mustard lock |
| `nova_core` | Large contained violet reactor inside mechanically attached concentric stabilizer rings and a right-facing emitter collar. | Violet/magenta, cyan tracking lights, mustard clamps |

## Generated source files

All originals remain under the generated-images session directory
`/Users/yupeng/.codex/generated_images/01a16843-48ef-75a1-8792-094cb261eb7b/`.

| ID | Source filename |
| --- | --- |
| `smg` | `exec-0ff81802-89b2-4b70-a2bd-b167f472a352.png` |
| `rifle` | `exec-1e71ab80-69af-4358-9cca-ae413b6c86bd.png` |
| `flechette` | `exec-4ce1b200-aa3d-4e31-a8f8-9cd51c8bb6ac.png` |
| `longbow` | `exec-ece92093-0d21-4b5a-baf7-c0d0e2ef56ae.png` |
| `hex_bolt` | `exec-5298ce9f-e58a-43f2-a58e-55d00af409f0.png` |
| `twin_fangs` | `exec-41a21e43-a399-41bc-b1d0-51d4943c4277.png` |
| `flak_crown` | `exec-cdd71377-ec6b-4623-a068-9f33c910758f.png` |
| `rail_spike` | `exec-b7cfe8e8-94f2-4df1-8733-9c2225f71356.png` |
| `nova_core` | `exec-e05a024e-536e-40ce-bd74-a810a32504d8.png` |

## Visual QA notes

- The four evolved silhouettes are materially distinct from their base-family art:
  dual muzzle, fan crown, parallel rail and concentric core.
- SMG, rifle, flechette and hex bolt preserve a horizontal screen-right firing axis.
- The mechanical longbow is intentionally tall because its curved limbs are the
  primary identity; its central rest points right. Runtime fit must preserve its
  aspect ratio rather than forcing it into a firearm-shaped rectangle.
- All files contain real alpha with transparent canvas pixels. Some antialiased
  edge pixels are below the 20/255 visible-bound threshold and are retained in the
  original files.
