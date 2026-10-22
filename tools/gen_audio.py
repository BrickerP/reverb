#!/usr/bin/env python3
"""Generate the placeholder sound set. Deterministic, no dependencies.

Run from the project root: python3 tools/gen_audio.py
"""
import math
import os
import random
import struct
import wave

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "audio")


def write(name, samples):
    os.makedirs(OUT, exist_ok=True)
    frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(frames)


def env(i, n, attack=0.004, release=0.05):
    a = min(1.0, i / (SR * attack)) if attack > 0 else 1.0
    r = min(1.0, (n - i) / (SR * release)) if release > 0 else 1.0
    return a * r


def tone(n, start, end, amp=0.35, kind="sine", attack=0.004, release=0.05, noise=0.0):
    out = []
    phase = 0.0
    rng = random.Random(7)
    for i in range(n):
        t = i / SR
        f = start + (end - start) * (i / max(1, n - 1))
        phase += 2.0 * math.pi * f / SR
        if kind == "square":
            s = 1.0 if math.sin(phase) >= 0.0 else -1.0
        elif kind == "saw":
            s = 2.0 * ((phase / (2.0 * math.pi)) % 1.0) - 1.0
        else:
            s = math.sin(phase)
        s = s * amp
        if noise:
            s += (rng.random() * 2.0 - 1.0) * noise
        out.append(s * env(i, n, attack, release))
    return out


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for track in tracks:
        for i, s in enumerate(track):
            out[i] += s
    return out


def sequence(notes, note_time, amp=0.3, kind="sine"):
    n = int(SR * note_time) * len(notes)
    out = [0.0] * n
    for k, f in enumerate(notes):
        part = tone(int(SR * note_time), f, f, amp=amp, kind=kind, attack=0.006, release=0.03)
        off = int(SR * note_time) * k
        for i, s in enumerate(part):
            out[off + i] += s
    return out


def main():
    rng = random.Random(11)

    # shoot: short falling blip with a noise edge
    n = int(SR * 0.07)
    write("shoot", tone(n, 980.0, 220.0, amp=0.32, kind="square", release=0.03, noise=0.12))

    # hit: tiny tick
    n = int(SR * 0.04)
    hit = tone(n, 1700.0, 1500.0, amp=0.18, release=0.015, noise=0.35)
    write("hit", hit)

    # kill: low crunch
    n = int(SR * 0.22)
    write("kill", tone(n, 360.0, 70.0, amp=0.34, kind="saw", release=0.1, noise=0.18))

    # pickup: two rising notes
    n = int(SR * 0.12)
    pick = [0.0] * n
    for k, (start, end) in enumerate([(880.0, 880.0), (1320.0, 1320.0)]):
        part = tone(n // 2, start, end, amp=0.22, attack=0.002, release=0.02)
        off = (n // 2) * k
        for i, s in enumerate(part):
            pick[off + i] += s
    write("pickup", pick)

    # buy: three-note chime
    write("buy", sequence([523.25, 659.25, 783.99], 0.075, amp=0.24))

    # hurt: falling low buzz
    n = int(SR * 0.25)
    write("hurt", mix(
        tone(n, 140.0, 55.0, amp=0.4, kind="saw", release=0.12),
        tone(n, 90.0, 50.0, amp=0.2, kind="sine", release=0.12, noise=0.08),
    ))

    # echo spawn: rising shimmer with tremolo
    n = int(SR * 0.55)
    echo = []
    phase = 0.0
    for i in range(n):
        t = i / SR
        f = 300.0 + 600.0 * (i / max(1, n - 1))
        phase += 2.0 * math.pi * f / SR
        trem = 0.65 + 0.35 * math.sin(2.0 * math.pi * 9.0 * t)
        echo.append(math.sin(phase) * 0.26 * trem * env(i, n, 0.16, 0.2))
    write("echo", echo)

    # wave start: low swell
    n = int(SR * 0.42)
    write("wave_start", mix(
        tone(n, 70.0, 70.0, amp=0.3, attack=0.12, release=0.2),
        tone(n, 500.0, 140.0, amp=0.12, kind="sine", attack=0.02, release=0.2, noise=0.1),
    ))

    # wave end / recording: tape-stop descent
    n = int(SR * 0.5)
    write("wave_end", tone(n, 620.0, 110.0, amp=0.3, kind="saw", attack=0.01, release=0.2, noise=0.05))

    # run lost
    write("lose", sequence([220.0, 185.0, 146.83], 0.22, amp=0.26))

    # run won
    write("win", sequence([523.25, 659.25, 783.99, 1046.5], 0.17, amp=0.24))

    # ui click
    n = int(SR * 0.03)
    write("click", tone(n, 2600.0, 2200.0, amp=0.12, release=0.012, noise=0.2))

    # boss arrival: low growl
    n = int(SR * 0.9)
    write("boss", mix(
        tone(n, 72.0, 42.0, amp=0.4, kind="saw", attack=0.12, release=0.4, noise=0.08),
        tone(n, 110.0, 55.0, amp=0.2, kind="sine", attack=0.1, release=0.4),
    ))

    # echo silence: a dull cut-off thud
    n = int(SR * 0.45)
    write("silence", tone(n, 300.0, 70.0, amp=0.35, kind="saw", attack=0.005, release=0.18, noise=0.06))

    # ambient loop: 12s, whole-cycle frequencies keep the seam quiet
    seconds = 12
    n = SR * seconds
    drone = []
    for i in range(n):
        t = i / SR
        lfo = 0.6 + 0.4 * math.sin(2.0 * math.pi * t / seconds)
        s = (math.sin(2.0 * math.pi * 55.0 * t) * 0.5
             + math.sin(2.0 * math.pi * 110.0 * t) * 0.22
             + math.sin(2.0 * math.pi * 165.0 * t) * 0.08)
        drone.append(s * 0.13 * lfo)
    write("ambient", drone)

    print("wrote", len(os.listdir(OUT)), "files to", OUT)


if __name__ == "__main__":
    main()
