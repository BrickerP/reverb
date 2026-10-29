# Paperwork Waltz — original score

This is original melodic material authored for Take Stack with Codex. No
commercial music, downloaded MIDI, stock composition, model-generated audio,
SoundFont, sampled piano or sampled woodwind is used. The score, synthesizer
and resulting files follow the repository `LICENSE`. There is no claim that
these synthesized instruments were recorded from acoustic instruments.

`tools/build_original_score.py` is the sole production recipe. It requires the
existing development Python/NumPy environment; the exported game needs neither.
Reproduce all five finished tracks and the listening deliverables with:

```
python3 tools/build_original_score.py --audition-dir /absolute/output/audio
python3 -m unittest discover -s tests -p test_music_assets.py
```

The 96-second score contains 48 bars in 3/4 at 90 BPM. An original D-minor
antecedent/answer motif crosses six eight-bar sections: introduction, reed
answer, relative-major bridge, inverted motif over chromatic descending bass,
ornamented reprise, and a lowered-register turnaround to the opening. Phrase
rests, changing voicings, a second melodic line and a developing orchestration
are scored as notes, rather than obtained by repeating a short ambient sample.

Five complete arrangements share that harmonic map and timing:

| File | Treatment |
| --- | --- |
| `menu.wav` | Exposed crooked piano, sparse desk taps, low reed answers |
| `shop.wav` | Lighter piano and plucked upper replies; gentle desk waltz |
| `battle.wav` | Shorter bass, weighted piano chords and steady desk pulse |
| `pressure.wav` | Moving six-note accompaniment, octave reed replies |
| `boss.wav` | Low reed pedal, denser plucks and extra terminal desk accents |

Struck notes combine inharmonic partials, detuned paired strings, frequency-
dependent decay and a very short resonant strike. Reeds combine odd partials,
breath-like amplitude shape, slow vibrato and a soft release. Percussion uses
deterministic grain and non-integer resonant modes. All instruments have proper
attack/release envelopes; none is a repeating single sine beep. Short, quiet
reflections add body without replacing the dry office identity.

The existing `audio/ambient.wav` remains unchanged. A quiet copy is rendered
into each arrangement as a room layer so music crossfades need only two runtime
voices. Its previously documented CC0 object recordings and original synthesis
retain their provenance in `audio/presentation/SOURCES.md`; `score.json` pins
its source hash, each finished track hash, note count and acoustic measurements.
All music files are mono 22.05 kHz PCM16 with zero endpoints and headroom below
0.64 full scale. The 35 dry effects and their source recipe remain separate.

Runtime arrangement choice reads the real simulation phase, nearby live threat
count, enemy warning/attack state, the director's actual push/breather phase,
boss presence and low health. Pressure has
hysteresis and a short hold; two fixed players crossfade for 1.2 seconds at the
same score position. Music never changes simulation state or consumes its RNG.
Pause freezes both players and the transport; mute preserves transport;
session changes clear fades and restart the appropriate score. Master, music
and effects gains are independent, and active weapon voices use a bounded gate
envelope when their material calls for a shorter tail.

The delivery audition includes five full-length arrangement masters and a
96-second transitions preview at the actual music/master defaults. Its JSON
timeline labels score sections, modes and runtime gain. The files are ready
for human listening. Objective format, headroom and reproducibility checks do
not establish perceived musical quality or speaker balance, and no subjective
listening approval is claimed.
