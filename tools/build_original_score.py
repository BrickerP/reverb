#!/usr/bin/env python3
"""Render the original 48-bar Paperwork Waltz with deterministic instruments.

Uses the pinned NumPy tooling dependency in tools/requirements-audio.txt. The game only loads
finished PCM, and never synthesizes audio or consumes simulation randomness.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SR = 22050
BPM = 90
BEAT = 60 / BPM
BAR = BEAT * 3
BARS = 48
SECONDS = BARS * BAR
MODES = ("menu", "shop", "battle", "pressure", "boss")
SECTIONS = ("A: unsigned form", "A2: duplicate reply", "B: borrowed daylight",
            "C: red ink", "A3: carbon reprise", "turnaround: file still open")

# Original antecedent/answer phrases. (beat, MIDI pitch, length in beats).
# Deliberate rests and unequal note lengths leave room for the desk percussion.
PHRASES = (
    ((0, 62, .85), (1, 65, .45), (1.5, 64, .40), (2, 69, .75)),
    ((0, 67, 1.35), (1.5, 64, .45), (2, 62, .85)),
    ((0, 65, .85), (1, 69, .85), (2, 72, .80)),
    ((0, 73, .45), (.5, 69, .45), (1, 67, .80), (2, 64, .85)),
    ((0, 65, 1.35), (1.5, 69, .45), (2, 74, .80)),
    ((0, 70, .85), (1, 69, .45), (1.5, 67, .45), (2, 65, .80)),
    ((0, 64, .85), (1, 67, .85), (2, 70, .75)),
    ((0, 69, .95), (1.25, 67, .40), (1.75, 64, .40), (2.5, 61, .40)),
)
BRIDGE = (
    ((0, 72, 1.35), (1.5, 69, .45), (2, 67, .80)),
    ((0, 67, .85), (1, 64, .85), (2, 60, .80)),
    ((0, 65, .45), (.5, 69, .45), (1, 74, 1.50)),
    ((0, 72, 1.10), (1.5, 71, .45), (2, 69, .85)),
    ((0, 70, 1.35), (1.5, 69, .45), (2, 65, .80)),
    ((0, 67, .85), (1, 70, .45), (1.5, 74, .45), (2, 76, .75)),
    ((0, 76, .45), (.5, 74, .45), (1, 70, .85), (2, 67, .80)),
    ((0, 64, 1.10), (1.5, 61, .45), (2, 69, .80)),
)
# Root/bass, chord voicing. D minor, with a relative-major bridge and a
# chromatic descending bass in the red-ink section; not one repeated chord pad.
HARMONY_A = ((38, (53, 57, 62)), (43, (55, 58, 62)), (45, (53, 57, 62)),
             (45, (55, 61, 64)), (46, (53, 58, 62)), (43, (55, 58, 62)),
             (40, (55, 58, 64)), (45, (55, 61, 64)))
HARMONY_B = ((41, (53, 57, 60)), (40, (52, 55, 60)), (38, (53, 57, 62)),
             (45, (52, 57, 60)), (46, (53, 58, 62)), (43, (55, 58, 62)),
             (40, (55, 58, 64)), (45, (55, 61, 64)))
HARMONY_C = ((38, (53, 57, 62)), (37, (52, 55, 61)), (36, (53, 57, 62)),
             (35, (50, 55, 59)), (34, (53, 58, 62)), (43, (55, 58, 62)),
             (40, (55, 58, 64)), (45, (55, 61, 64)))


def events(mode: str) -> list[dict]:
    """Return the actual score, including phrase development and orchestration."""
    if mode not in MODES:
        raise ValueError(f"unknown arrangement: {mode}")
    score: list[dict] = []
    density = {"menu": .42, "shop": .58, "battle": .77, "pressure": .92, "boss": 1.0}[mode]

    def note(bar, beat, midi, length, instrument, gain):
        score.append({"bar": bar, "beat": beat, "midi": midi,
                      "seconds": (bar * 3 + beat) * BEAT,
                      "duration": length * BEAT, "instrument": instrument,
                      "gain": gain})

    for bar in range(BARS):
        section, local = divmod(bar, 8)
        harmony = HARMONY_B if section == 2 else HARMONY_C if section == 3 else HARMONY_A
        bass, chord = harmony[local]
        phrase = BRIDGE[local] if section == 2 else PHRASES[local]
        # Red ink changes contour and register; reprise preserves recognition
        # with an answering upper line rather than repeating a short audio loop.
        if section == 3:
            phrase = tuple((at, 124 - pitch, length * .9) for at, pitch, length in phrase)
        elif section == 4:
            phrase = tuple((at, pitch + (12 if index == len(phrase) - 1 else 0), length)
                           for index, (at, pitch, length) in enumerate(phrase))
        elif section == 5 and local >= 4:
            phrase = tuple((at, pitch - 12 if local < 7 else pitch, length * 1.12)
                           for at, pitch, length in phrase[:3])
        lead = "reed" if section in (1, 3) else "piano"
        for index, (at, pitch, length) in enumerate(phrase):
            # A tiny fixed swing in the offbeats is shared by every arrangement.
            onset = at + (.035 if index % 2 else 0)
            velocity = (.80, .64, .72, .60)[index % 4]
            note(bar, onset, pitch, length, lead, .20 * velocity * (1.08 if mode == "menu" else 1))
            if mode in ("pressure", "boss") and section in (2, 4):
                note(bar, onset + .018, pitch - 12, length * .85, "reed", .065)
        note(bar, 0, bass, 1.4 if mode in ("menu", "shop") else .85, "bass", .21 * density)
        if mode in ("battle", "pressure", "boss"):
            note(bar, 1.75, bass + 12, .55, "bass", .10 * density)
        # Quiet, uneven oom-pah. The changing inversions are explicitly scored.
        for beat in (1, 2):
            for index, pitch in enumerate(chord):
                note(bar, beat + index * .018, pitch, .56 if mode == "shop" else .40,
                     "piano", .062 * density * (1 if beat == 1 else .76))
        if section in (1, 4) or mode == "shop":
            answer = (chord[2] + 12, chord[1] + 12, chord[0] + 12)
            for index, pitch in enumerate(answer):
                if mode == "menu" and bar % 2 == 0:
                    continue
                note(bar, 1.25 + index * .5, pitch, .34, "pluck", .035 * density)
        if mode == "shop" and section in (2, 3) and local % 2 == 0:
            note(bar, .25, chord[0], 2.20, "reed", .055)
        if mode in ("pressure", "boss"):
            for index in range(6):
                pitch = chord[index % 3] + (12 if mode == "pressure" else 0)
                note(bar, index * .5, pitch, .31, "pluck", .043 * density)
        if mode != "menu" or bar % 2 == 1:
            note(bar, 0, 43, .12, "desk", .055 * density)
            note(bar, 1, 68, .08, "key", .033 * density)
            note(bar, 2.035, 71, .09, "key", .027 * density)
        if mode in ("pressure", "boss"):
            note(bar, 2.5, 74, .055, "key", .027 * density)
        if mode == "boss":
            note(bar, .05, bass - 12, 2.5, "reed", .066)
            if local in (3, 7):
                note(bar, 2.5, 55, .22, "desk", .07)
    return score


def instrument(kind: str, midi: int, seconds: float) -> np.ndarray:
    """Deterministic struck strings, odd-partial reeds and resonant desk bodies."""
    count = max(16, round((seconds + .20) * SR))
    t = np.arange(count, dtype=np.float64) / SR
    hz = 440 * 2 ** ((midi - 69) / 12)
    attack = 1 - np.exp(-t / (.028 if kind == "reed" else .0025))
    release = np.clip((seconds + .19 - t) / .19, 0, 1) ** 2
    value = np.zeros(count, dtype=np.float64)
    if kind in ("piano", "bass", "pluck"):
        decay = {"piano": 1.1, "bass": .70, "pluck": .30}[kind]
        for partial in range(1, 9 if kind == "piano" else 6):
            # Slight inharmonicity, fixed detuned paired strings, and faster
            # decay of upper modes supply a struck body rather than a sine beep.
            frequency = hz * partial * math.sqrt(1 + .00018 * partial * partial)
            if frequency > SR * .43:
                continue
            envelope = np.exp(-t * (1.0 + partial * .32) / decay)
            amplitude = 1 / partial ** (1.45 if kind != "pluck" else 1.18)
            value += amplitude * envelope * (np.sin(math.tau * frequency * t) * .72
                     + np.sin(math.tau * frequency * 1.0017 * t) * .28)
        value += .022 * np.sin(math.tau * 1231 * t) * np.exp(-t * 160)
    elif kind == "reed":
        phase = math.tau * hz * t + .012 * np.sin(math.tau * 4.7 * t)
        for partial, amplitude in ((1, .83), (2, .10), (3, .29), (5, .12), (7, .04)):
            value += amplitude * np.sin(phase * partial) * np.exp(-t * .22 * partial)
        value *= .88 + .12 * np.sin(math.pi * np.clip(t / max(seconds, .1), 0, 1))
    elif kind in ("desk", "key"):
        # Deterministic pseudo-grain, no hidden RNG or sample copyright.
        grain = np.mod(np.sin(np.arange(count) * 12.9898 + midi * 78.233) * 43758.5453, 1) * 2 - 1
        decay = 32 if kind == "desk" else 65
        for ratio, amplitude in ((1, .72), (2.74, .20), (4.17, .08)):
            value += amplitude * np.sin(math.tau * hz * ratio * t) * np.exp(-t * decay)
        value += grain * np.exp(-t * decay * 2) * .16
    else:
        raise ValueError(kind)
    value *= attack * release
    peak = float(np.max(np.abs(value)))
    if peak == 0:
        raise ValueError("silent instrument")
    value /= peak
    value[0] = value[-1] = 0
    return value


def read_wav(path: Path) -> np.ndarray:
    with wave.open(str(path), "rb") as source:
        if source.getsampwidth() != 2 or source.getnchannels() != 1:
            raise ValueError("expected mono PCM16 source")
        samples = np.frombuffer(source.readframes(source.getnframes()), dtype="<i2").astype(np.float64) / 32768
        rate = source.getframerate()
    if rate != SR:
        # The retained 44.1k room bed is low-passed by this two-sample average.
        if rate != 2 * SR:
            raise ValueError("unsupported room sample rate")
        samples = samples[:len(samples) // 2 * 2].reshape(-1, 2).mean(axis=1)
    return samples


def render(mode: str, room: np.ndarray | None = None) -> np.ndarray:
    output = np.zeros(round(SECONDS * SR), dtype=np.float64)
    cache: dict[tuple, np.ndarray] = {}
    for event in events(mode):
        key = (event["instrument"], event["midi"], round(event["duration"], 5))
        if key not in cache:
            cache[key] = instrument(key[0], key[1], key[2])
        part = cache[key]
        at = round(event["seconds"] * SR)
        count = min(len(part), len(output) - at)
        output[at:at + count] += part[:count] * event["gain"]
        # Short, dark reflections preserve the dry mix and a little room body.
        for delay, gain in ((.073, .08), (.149, .035)):
            reflected = at + round(delay * SR)
            count = min(len(part), len(output) - reflected)
            if count > 0:
                output[reflected:reflected + count] += part[:count] * event["gain"] * gain
    output -= np.mean(output)
    output *= .58 / max(float(np.max(np.abs(output))), .001)
    if room is not None:
        output += np.resize(room, len(output)) * .20
    # Musical release before the next downbeat, zero endpoints for safe looping.
    fade_in, fade_out = round(.012 * SR), round(.13 * SR)
    output[:fade_in] *= np.linspace(0, 1, fade_in) ** 2
    output[-fade_out:] *= np.linspace(1, 0, fade_out) ** 2
    output[0] = output[-1] = 0
    if float(np.max(np.abs(output))) >= .64:
        raise ValueError("score exceeds conservative mix headroom")
    return output


def write_wav(path: Path, samples: np.ndarray) -> None:
    if samples.size == 0 or not np.all(np.isfinite(samples)) or np.max(np.abs(samples)) >= 1:
        raise ValueError("empty, nonfinite or clipping output")
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as target:
        target.setparams((1, 2, SR, 0, "NONE", "not compressed"))
        target.writeframes(np.rint(samples * 32767).astype("<i2").tobytes())


def metrics(samples: np.ndarray) -> dict:
    return {"seconds": len(samples) / SR, "peak": float(np.max(np.abs(samples))),
            "rms": float(np.sqrt(np.mean(samples * samples))), "dc": float(np.mean(samples)),
            "seam_delta": float(abs(samples[-1] - samples[0]))}


def audition(directory: Path, tracks: dict[str, np.ndarray]) -> None:
    # Full 96s composition shown with runtime-aligned transitions at real gains.
    sequence = ((0, "menu"), (16, "shop"), (32, "battle"), (48, "pressure"), (64, "boss"), (84, "shop"))
    output = np.zeros(round(SECONDS * SR))
    timeline = []
    fade = round(1.2 * SR)
    for index, (start, mode) in enumerate(sequence):
        end = sequence[index + 1][0] if index + 1 < len(sequence) else SECONDS
        lo, hi = round(start * SR), round(end * SR)
        output[lo:hi] = tracks[mode][lo:hi] * 10 ** (-9 / 20) * .8 * .8
        if index:
            old = tracks[sequence[index - 1][1]][lo:lo + fade]
            new = tracks[mode][lo:lo + fade]
            blend = np.linspace(0, 1, len(new))
            output[lo:lo + len(new)] = (old * (1 - blend) + new * blend) * 10 ** (-9 / 20) * .8 * .8
        timeline.append({"at": start, "until": end, "arrangement": mode,
                         "score_position": start, "crossfade_seconds": 1.2 if index else 0})
    write_wav(directory / "paperwork-waltz-runtime-audition.wav", output)
    # Human-audition masters are copies at their unattenuated authored level.
    for mode, samples in tracks.items():
        write_wav(directory / f"paperwork-waltz-{mode}.wav", samples)
    report = {"title": "Paperwork Waltz", "original_composition": True, "bpm": BPM,
              "meter": "3/4", "seconds": SECONDS, "sample_rate": SR,
              "runtime_gains": {"music_db": -9, "music_slider": .8, "master_slider": .8},
              "timeline": timeline,
              "form": [{"at": i * 16, "until": (i + 1) * 16, "section": name} for i, name in enumerate(SECTIONS)],
              "listening_status": "Prepared for human audition; objective checks do not establish subjective quality."}
    (directory / "music-timeline.json").write_text(json.dumps(report, indent=2) + "\n")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=ROOT / "audio/music")
    parser.add_argument("--audition-dir", type=Path)
    args = parser.parse_args()
    room_path = ROOT / "audio/ambient.wav"
    room = read_wav(room_path)
    tracks = {mode: render(mode, room) for mode in MODES}
    manifest = {"title": "Paperwork Waltz", "composer": "Original score authored for this repository with Codex",
                "license": "Repository LICENSE; no third-party musical material or soundfont",
                "recipe": "python3 tools/build_original_score.py", "bpm": BPM, "meter": "3/4",
                "bars": BARS, "seconds": SECONDS, "sample_rate": SR, "format": "mono PCM16",
                "room_source": {"path": "audio/ambient.wav", "sha256": hashlib.sha256(room_path.read_bytes()).hexdigest(),
                                "license": "Existing documented CC0 objects and original synthesis; see audio/presentation/SOURCES.md"},
                "form": list(SECTIONS), "tracks": []}
    for mode, samples in tracks.items():
        path = args.output_dir / f"{mode}.wav"
        write_wav(path, samples)
        manifest["tracks"].append({"file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                                   "notes": len(events(mode)), **metrics(read_wav(path))})
    (args.output_dir / "score.json").write_text(json.dumps(manifest, indent=2) + "\n")
    if args.audition_dir:
        audition(args.audition_dir, tracks)
    print(json.dumps({"tracks": len(tracks), "seconds_each": SECONDS, "output": str(args.output_dir),
                      "audition": str(args.audition_dir) if args.audition_dir else None}))


if __name__ == "__main__":
    main()
