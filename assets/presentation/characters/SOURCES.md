# Carbon Copy Purgatory character animation artwork

Generated on 2026-10-28 with the built-in `image_gen` tool. The eight game PNGs are
unchanged copies of the selected generated originals. This replaces the previous
static mechanical-operator artwork with the approved flat-ink paper-puppet style.

## Runtime layout

- Every PNG is RGBA, 2172 × 724 pixels, with four equal horizontal cells of 543 × 724.
- Frame order: neutral idle, left step, right step, creased/squashed hurt.
- Front sheets face generally down/right; rear sheets face generally up/right.
- All sheets contain true silhouette/foot/arm pose changes. Runtime may mirror horizontally.
- Weapons are deliberately absent: the existing independently mounted weapon artwork supplies them.
- Alpha was checked at 20/255. All four frames contain nonempty artwork and have transparent margins.
- `carbon_copy_assets.json` records full prompts, exact original paths, hashes, cell sizes,
  each frame's measured alpha bounds and the shared frame-local union. Use one union
  region per sheet when selecting frames; do not resize each pose to its own tight bounds.
- The manifest here contains seven files in this folder; `../player.png` is the Looper
  front sheet and is included in `carbon_copy_assets.json` and the parent catalog.

## Style and identity

The sole broad art reference was the approved Take Stack art-direction board:
`/Users/yupeng/.codex/generated_images/01a18296-db63-7bb2-9605-61f40b908744/exec-1e58b345-a0ae-40f8-b50a-bbb74b7a6c00.png`.

Looper is the tired creased square paper doll with a paper-feed satchel. Soloist
uses a triangular patched tape poncho. Mirror has a bruised-purple misprint stripe
and two paper rolls. Conductor has broad sage paper shoulders and a multi-folder
backpack. All use thick irregular near-black ink, flat paper fills and a single
simple shadow; no metallic armor, neon, scenery, embedded text or attached weapons.

Rear sheets used their corresponding finished front sheet as an additional identity
reference. They preserve character proportions and costume while removing facial
features from the rear of the head.

## Selected originals

- `assets/presentation/player.png`: `/Users/yupeng/.codex/generated_images/01a182df-8d11-75b2-8706-4dc8bcaa176f/exec-6b58ecc1-514b-4b11-afa0-28251217bf99.png`.
- `assets/presentation/characters/solo_front.png`: `/Users/yupeng/.codex/generated_images/01a182df-8d11-75b2-8706-4dc8bcaa176f/exec-cf2471fc-f1d5-4849-9c4a-1b4ff9371a9a.png`.
- `assets/presentation/characters/mirror_front.png`: `/Users/yupeng/.codex/generated_images/01a182df-8d11-75b2-8706-4dc8bcaa176f/exec-d80bd630-38ae-49fb-8831-93609ec715e6.png`.
- `assets/presentation/characters/conductor_front.png`: `/Users/yupeng/.codex/generated_images/01a182df-8d11-75b2-8706-4dc8bcaa176f/exec-d3d4ab62-7a06-404d-aaf8-6984e712a4ca.png`.
- `assets/presentation/characters/looper_back.png`: `/Users/yupeng/.codex/generated_images/01a182df-8d11-75b2-8706-4dc8bcaa176f/exec-665abcb3-53fe-4813-94d1-561e1e246fa8.png`.
- `assets/presentation/characters/solo_back.png`: `/Users/yupeng/.codex/generated_images/01a182df-8d11-75b2-8706-4dc8bcaa176f/exec-cb834b37-8cf5-407b-bf4c-7df181c453ea.png`.
- `assets/presentation/characters/mirror_back.png`: `/Users/yupeng/.codex/generated_images/01a182df-8d11-75b2-8706-4dc8bcaa176f/exec-35588097-a42f-4494-92d3-b4c4efe174e4.png`.
- `assets/presentation/characters/conductor_back.png`: `/Users/yupeng/.codex/generated_images/01a182df-8d11-75b2-8706-4dc8bcaa176f/exec-4433ea1b-d1ab-4964-9290-10fa0eeb51b3.png`.
