# Paperbureau audio sources

All 35 routed cues now live in this directory. The old tonal placeholder WAVs
and their runtime fallback have been removed. `audio/ambient.wav` is a separate
16-second quiet room/feed-roller loop. This batch designs material and machine
sound. The original melodic soundtrack is documented in `../music/SOURCES.md`.

## Recorded source objects (CC0)

Nine processed recordings from the previous committed palette are preserved as
immutable development inputs in `tools/audio_sources/kenney_objects/`.
`sources.json` records each exact SHA-256 and snapshot commit
`be0214e7dd3dd118caca5ed5e31bac6850cb5ef1`. Development source snapshots are not
included in game exports. They derive from these checksum-pinned official packs:

- Kenney Interface Sounds 1.0: https://kenney.nl/assets/interface-sounds
  - Archive: `kenney_interface-sounds.zip`
  - SHA-256: `f2193d072726d6758a5f7871b2dcc54dcce0d5c35c6f0a62f92549b327c81232`
- Kenney Impact Sounds 1.0: https://kenney.nl/assets/impact-sounds
  - Archive: `kenney_impact-sounds.zip`
  - SHA-256: `029d734af1582474edf3a694d1b0cebc97c1c152f2f39fa34d4c2bafc5de77f8`
- License: https://creativecommons.org/publicdomain/zero/1.0/

The original archives identify Kenney as creator/distributor and grant CC0.
Credit is optional; source identity remains documented here for traceability.
This batch uses the preserved local recordings and makes no new download.

| Preserved input | Original source clips | Prior processing |
| --- | --- | --- |
| `click` | Interface `click_001.ogg` | High-pass, crop, fade, level limit |
| `weapon_pistol` | Impact `impactMetal_light_000.ogg` | Filtered short mechanical snap |
| `weapon_longbow` | Interface `pluck_001.ogg` | Filtered natural object pluck |
| `shield_block` | Impact `impactPlate_heavy_001.ogg` | Cropped plate resonance |
| `hurt_contact` | Impact `impactSoft_medium_002.ogg` | Cropped soft object hit |
| `hurt_blast` | Impact `impactPunch_heavy_000.ogg` | Low-pass punch/body impact |
| `weapon_explosion` | Impact `impactPunch_medium_003.ogg`, `impactMetal_medium_000.ogg` | Layered compact impact |
| `shop_reroll` | Interface `switch_001.ogg` | Filtered mechanical switch |
| `weapon_nova_core` | Impact `impactBell_heavy_003.ogg`, Interface `glass_003.ogg` | Quiet resonant object body |

## Original paper material and recipes

`tools/build_presentation_audio.py` is the single offline production path. It
checks all source hashes, resamples the recorded objects, layers original
deterministic granular friction and buckling fibres, removes DC, then applies
zero-ended envelopes and conservative peak levels. The granular paper material
is synthesis; no new recorded paper, microphone session or subjective listening
validation is claimed. Original code/material is covered by the repository's
`LICENSE`; recorded ingredients remain CC0.

| Cue group | Physical language |
| --- | --- |
| `weapon_pistol`, `weapon_smg`, `shoot` | Dry staple/hole-punch releases with short paper edge |
| `weapon_shotgun`, `weapon_rifle` | Folder slap and weighted stamp |
| `weapon_orb`, `weapon_hex_bolt`, `weapon_nova_core` | Quiet resonant object body with fibre envelope |
| `weapon_flechette`, `weapon_twin_fangs` | Offset puncture/staple clicks |
| `weapon_longbow` | Object pluck and taut paper flick |
| `weapon_flak_crown`, `weapon_rail_spike` | Heavy press and restrained plate tail |
| `hit`, `hit_crit`, `kill` | Soft paper body, stronger buckle and crumple |
| `shield_block` | Register clamp/plate closure |
| `weapon_explosion`, `bomber_explosion` | Compact shredding burst and heavier discarded body |
| `hurt`, `hurt_contact`, `hurt_blast` | Soft body collapse with paper friction |
| `pickup`, `click`, `buy`, `equipment_apply` | Dry desk action and rubber-stamp closure |
| `equipment_undo`, `shop_reroll` | Feed-roller reversal and sheet movement |
| `echo`, `silence` | Copy fed/registered and register clamped shut |
| `wave_start`, `wave_end` | Feed motor engages; completed sheet is stamped |
| `lose`, `win` | Crumple followed by flattened-paper closure; completed-file stamp |
| `boss` | Tension, seam snap at 0.18 seconds, paperjam body/release |

The actual PHASE silence event owns the Boss tear cue; ordinary contact silence
does not trigger it. Major paper actions briefly duck the quiet room bed.
The twelve-voice pool, protected priorities, cooldowns, pause and mute paths stay
bounded. Rapid weapon and hit levels are lower than transition/player signals.
Condition/merge spawn pitch and six retirement material accents use existing
event snapshots and never consume simulation randomness. Exhaustion uses a
quiet feed-out accent; active retirement no longer has a universal burst cue.

## Room loop and validation

The ambient loop uses low, whole-cycle motor modes, filtered air, and four sparse
recorded feed/soft-object movements. It has no musical melody or bright constant
buzz. Its standalone reference mix was -24 dB; both endpoints and their nearby slopes
are zero. The new score recipe embeds this retained quiet room layer into all
five arrangements, which pause together through the game pause path. Normalized preview playback is louder
than its runtime level and is clearly labeled in the audition timeline.

All production files are mono, 44.1 kHz, 16-bit PCM. Cue durations range from
0.075 to 0.88 seconds, peak no higher than 0.64 full scale; the room loop is
16 seconds with peak 0.18. `tests/test_audio_assets.py` checks format, body/RMS,
headroom, DC, seam, exact reproduction, source corruption failure and the
Boss transition accent. `tests/test_audio.gd` checks routing, voice bounds,
cooldowns, mute, pause, detach, phase identity and bed envelopes.

Reproduce the complete palette and an optional labeled audition:

```
python3 tools/build_presentation_audio.py --audition-dir /absolute/output/audio
python3 -m unittest discover -s tests -p test_audio_assets.py
```

The audition starts with isolated representative materials, then a mixed scene
at the actual runtime gains. It is an artifact for human listening; objective
file checks alone do not establish perceived quality, comfort or speaker balance.
