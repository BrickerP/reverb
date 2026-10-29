#!/usr/bin/env python3
"""Build the complete paperbureau sound palette offline from pinned CC0 objects.

Source snapshots are development inputs, never exported runtime resources.
No microphone recording is claimed: paper grain is original granular synthesis,
layered over recorded soft/metal/plate/object transients from Kenney's CC0 packs.
"""

from __future__ import annotations

import argparse
import array
import hashlib
import json
import math
import random
import sys
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SR = 44100
SOURCE_DIR = ROOT / "tools/audio_sources/kenney_objects"
AMBIENT_SECONDS = 16
MAX_PEAK = 0.64
NAMES = [
    "shoot", "hit", "kill", "pickup", "buy", "hurt", "echo", "wave_start",
    "wave_end", "lose", "win", "click", "boss", "silence", "weapon_pistol",
    "weapon_smg", "weapon_shotgun", "weapon_rifle", "weapon_orb", "weapon_flechette",
    "weapon_longbow", "weapon_hex_bolt", "weapon_twin_fangs", "weapon_flak_crown",
    "weapon_rail_spike", "weapon_nova_core", "hit_crit", "shield_block",
    "weapon_explosion", "bomber_explosion", "hurt_contact", "hurt_blast",
    "equipment_apply", "equipment_undo", "shop_reroll",
]


def read_wav(path: Path) -> list[float]:
    with wave.open(str(path), "rb") as source:
        if (source.getnchannels(), source.getsampwidth(), source.getframerate()) != (1, 2, SR):
            raise ValueError(f"unexpected input format: {path}")
        samples = array.array("h", source.readframes(source.getnframes()))
    if sys.byteorder != "little":
        samples.byteswap()
    return [sample / 32768.0 for sample in samples]


def write_wav(path: Path, samples: list[float]) -> None:
    if not samples or max(abs(s) for s in samples) >= 1.0:
        raise ValueError(f"empty or clipping output: {path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    values = array.array("h", (round(s * 32767.0) for s in samples))
    if sys.byteorder != "little":
        values.byteswap()
    with wave.open(str(path), "wb") as target:
        target.setnchannels(1)
        target.setsampwidth(2)
        target.setframerate(SR)
        target.writeframes(values.tobytes())


def add(target: list[float], part: list[float], at: float = 0.0, gain: float = 1.0) -> None:
    start = round(at * SR)
    for i in range(min(len(part), len(target) - start)):
        target[start + i] += part[i] * gain


def lowpass(samples: list[float], hz: float) -> list[float]:
    alpha = 1.0 - math.exp(-math.tau * hz / SR)
    state = 0.0
    out = []
    for sample in samples:
        state += alpha * (sample - state)
        out.append(state)
    return out


def highpass(samples: list[float], hz: float) -> list[float]:
    low = lowpass(samples, hz)
    return [s - l for s, l in zip(samples, low)]


def finish(samples: list[float], peak: float = MAX_PEAK, fade: float = 0.008) -> list[float]:
    # Remove DC before applying a true zero-ended envelope; no hard clipping.
    mean = sum(samples) / len(samples)
    out = [sample - mean for sample in samples]
    ramp = min(round(fade * SR), len(out) // 2)
    for i in range(ramp):
        gain = i / max(1, ramp - 1)
        out[i] *= gain
        out[-1-i] *= gain
    actual = max(abs(sample) for sample in out)
    if actual <= 0.0:
        raise ValueError("silent recipe")
    return [sample * peak / actual for sample in out]


def source_palette() -> dict[str, list[float]]:
    manifest = json.loads((SOURCE_DIR / "sources.json").read_text())
    result = {}
    for record in manifest["assets"]:
        path = ROOT / record["file"]
        if hashlib.sha256(path.read_bytes()).hexdigest() != record["sha256"]:
            raise ValueError(f"CC0 source snapshot changed: {path}")
        result[path.stem] = read_wav(path)
    return result


def object_sound(source: list[float], seconds: float, speed: float = 1.0,
                 cutoff: float = 6500.0) -> list[float]:
    out = []
    for i in range(round(seconds * SR)):
        at = i * speed
        index = int(at)
        if index + 1 >= len(source):
            out.append(0.0)
        else:
            part = at - index
            out.append(source[index] * (1.0 - part) + source[index+1] * part)
    return lowpass(out, cutoff)


def paper(seconds: float, seed: int, intensity: float = 1.0, tear: bool = False) -> list[float]:
    """Deterministic non-tonal fibres: friction noise plus sparse buckling grains."""
    rng = random.Random(seed)
    count = round(seconds * SR)
    noise = [rng.uniform(-1.0, 1.0) for _ in range(count)]
    band = highpass(lowpass(noise, 5000.0 if tear else 3300.0), 380.0)
    out = [0.0] * count
    grain_count = max(3, round(seconds * (72 if tear else 48)))
    for _ in range(grain_count):
        start = rng.randrange(max(1, count - 100))
        length = rng.randrange(80, 460 if tear else 820)
        gain = rng.uniform(0.15, 0.65) * intensity
        for j in range(min(length, count-start)):
            envelope = math.sin(math.pi * j / length) ** 2
            out[start+j] += band[start+j] * gain * envelope
    # Low friction remains between the individually collapsing fibres.
    for i in range(count):
        phase = i / max(1, count - 1)
        out[i] += band[i] * 0.07 * intensity
        out[i] *= math.sin(math.pi * phase) ** (0.45 if tear else 0.8)
    return out


def build_cues(p: dict[str, list[float]]) -> dict[str, list[float]]:
    cues = {}

    def cue(name: str, seconds: float, layers: list[tuple[str, float, float, float]],
            fibre: float = 0.25, seed: int = 0, tear: bool = False, peak: float = 0.58) -> None:
        samples = paper(seconds, 1147 + seed, fibre, tear)
        for source, at, gain, speed in layers:
            part = object_sound(p[source], max(0.01, seconds-at), speed)
            add(samples, part, at, gain)
        cues[name] = finish(samples, peak)

    # Stapler, hole punch, rubber stamp and feed-roller variations. None contains
    # a synthesized musical pitch sweep; recorded objects supply the body.
    cue("weapon_pistol", .145, [("weapon_pistol", .006, 1.0, 1.25)], .20, 1)
    cue("weapon_smg", .080, [("click", .004, .85, 1.45), ("weapon_pistol", .010, .32, 1.6)], .12, 2, peak=.48)
    cue("weapon_shotgun", .280, [("hurt_contact", .008, .85, .76), ("weapon_explosion", .018, .42, 1.2)], .65, 3)
    cue("weapon_rifle", .180, [("weapon_pistol", .005, .68, .9), ("shield_block", .012, .34, 1.5)], .28, 4)
    cue("weapon_orb", .330, [("weapon_nova_core", .018, .55, 1.6), ("hurt_contact", .025, .3, 1.1)], .50, 5)
    cue("weapon_flechette", .140, [("click", .004, .8, 1.45), ("click", .031, .55, 1.65), ("click", .060, .24, 1.8)], .23, 6)
    cue("weapon_longbow", .220, [("weapon_longbow", .012, .85, .95), ("shop_reroll", .035, .16, 1.7)], .45, 7)
    cue("weapon_hex_bolt", .265, [("shop_reroll", .010, .45, 1.15), ("weapon_pistol", .045, .3, 1.6)], .43, 8)
    cue("weapon_twin_fangs", .195, [("weapon_pistol", .005, .8, 1.45), ("weapon_pistol", .056, .68, 1.6)], .22, 9)
    cue("weapon_flak_crown", .340, [("hurt_blast", .006, .7, 1.25), ("shield_block", .020, .3, .9)], .60, 10)
    cue("weapon_rail_spike", .285, [("weapon_pistol", .004, .65, .74), ("shield_block", .012, .65, .9)], .36, 11)
    cue("weapon_nova_core", .490, [("weapon_nova_core", .025, .52, .82), ("hurt_blast", .035, .42, 1.15)], .65, 12)

    cue("shoot", .140, [("weapon_pistol", .005, .72, 1.1)], .18, 13)
    cue("hit", .100, [("hurt_contact", .002, .72, 1.55)], .34, 14, peak=.45)
    cue("hit_crit", .185, [("hurt_contact", .004, .7, 1.18), ("click", .020, .45, .9)], .48, 15)
    cue("shield_block", .230, [("shield_block", .004, .85, 1.2)], .14, 16)
    cue("kill", .320, [("hurt_contact", .009, .55, .80), ("shop_reroll", .032, .16, .7)], 1.0, 17, True)
    cue("pickup", .105, [("click", .004, .5, 1.55), ("weapon_longbow", .022, .3, 1.6)], .12, 18, peak=.44)
    cue("hurt", .260, [("hurt_contact", .004, .85, .76)], .70, 19)
    cue("hurt_contact", .235, [("hurt_contact", .004, .9, .82)], .70, 20)
    cue("hurt_blast", .365, [("hurt_blast", .006, .85, .88), ("hurt_contact", .025, .3, .7)], .85, 21)
    cue("weapon_explosion", .380, [("weapon_explosion", .005, .75, 1.05), ("hurt_contact", .025, .4, .75)], .95, 22, True)
    cue("bomber_explosion", .520, [("hurt_blast", .008, .88, .75), ("weapon_explosion", .028, .4, .8)], 1.1, 23, True)

    # Copies are fed, registered, clamped and finally shredded. The Boss snap at
    # .18s is aligned with the three-beat visual tension -> seam -> spring.
    cue("echo", .440, [("shop_reroll", .012, .32, .82), ("weapon_pistol", .190, .5, 1.1)], .72, 24)
    cue("silence", .305, [("shield_block", .004, .62, .78), ("hurt_contact", .025, .4, .8)], .50, 25)
    cue("boss", .800, [("shop_reroll", .010, .25, .55), ("shield_block", .180, .7, .72), ("hurt_blast", .190, .4, .8)], .90, 26, True, peak=.64)
    tension_end = round(.18 * SR)
    cues["boss"] = finish([sample * (.32 + .25 * i / tension_end if i < tension_end else 1.0)
                           for i, sample in enumerate(cues["boss"])], .64)
    cue("wave_start", .420, [("shop_reroll", .006, .42, .9), ("weapon_pistol", .095, .6, .95)], .45, 27)
    cue("wave_end", .510, [("hurt_contact", .020, .55, .8), ("weapon_pistol", .110, .65, .95)], .65, 28)
    cue("lose", .820, [("hurt_contact", .022, .45, .68), ("hurt_contact", .190, .3, .54), ("weapon_pistol", .420, .25, .62)], 1.25, 29, True)
    cue("win", .880, [("weapon_pistol", .010, .6, .95), ("click", .170, .40, 1.0), ("shield_block", .285, .32, 1.2)], .65, 30)
    cue("click", .075, [("click", .003, .7, 1.15)], .15, 31, peak=.43)
    cue("buy", .270, [("hurt_contact", .010, .55, .9), ("weapon_pistol", .052, .45, .85)], .38, 32)
    cue("equipment_apply", .290, [("hurt_contact", .010, .45, .95), ("weapon_pistol", .060, .6, 1.1)], .42, 33)
    cue("equipment_undo", .340, [("shop_reroll", .008, .42, .85), ("click", .185, .45, 1.1)], .55, 34)
    cue("shop_reroll", .390, [("shop_reroll", .008, .45, .98), ("click", .265, .3, 1.2)], .65, 35)
    if set(cues) != set(NAMES):
        raise ValueError("the palette must supply exactly the 35 runtime cue identities")
    return cues


def build_ambient(p: dict[str, list[float]]) -> list[float]:
    count = SR * AMBIENT_SECONDS
    rng = random.Random(8823)
    air = lowpass([rng.uniform(-1, 1) for _ in range(count)], 470.0)
    out = []
    for i in range(count):
        t = i / SR
        # Whole-cycle room motor modes are deliberately below the bright paper
        # transients. There is no tune, dramatic drone or continuous harsh buzz.
        motor = math.sin(math.tau * 44.0 * t) * .008 + math.sin(math.tau * 88.0 * t) * .003
        breathing = .76 + .24 * math.sin(math.tau * t / AMBIENT_SECONDS)
        out.append(air[i] * .045 * breathing + motor)
    for at, speed in [(1.3, .54), (5.4, .62), (9.6, .48), (13.7, .58)]:
        add(out, object_sound(p['shop_reroll'], .75, speed, 900), at, .045)
        add(out, object_sound(p['hurt_contact'], .24, .66, 1400), at+.48, .055)
    return finish(out, .18, .12)


def metrics(samples: list[float]) -> dict[str, float]:
    return {"seconds": len(samples) / SR, "peak": max(abs(s) for s in samples),
            "rms": math.sqrt(sum(s*s for s in samples) / len(samples)),
            "dc": sum(samples)/len(samples), "seam_delta": abs(samples[-1]-samples[0])}


def audition(directory: Path, cues: dict[str, list[float]], ambient: list[float],
             audio_code: str) -> None:
    directory.mkdir(parents=True, exist_ok=True)
    names = ["click", "equipment_apply", "echo", "silence", "kill", "lose", "boss", "win"]
    reel = [0.0] * (SR * 24)
    timeline = []
    for i, name in enumerate(names):
        at = .5 + i*1.25
        add(reel, cues[name], at, .72)
        timeline.append({"start": at, "cue": name, "section": "isolated material audition", "gain": .72})
    # Full mix uses the real runtime gains and deterministic pitches. Overlapping
    # ambient, common shots and protected transitions exercise listening hierarchy.
    import re
    volume_block = audio_code.split('const VOLUMES := {', 1)[1].split('\n}', 1)[0]
    volumes = {name: float(value) for name, value in re.findall(r'&"([^"]+)": (-?[0-9.]+)', volume_block)}
    add(reel, ambient[:SR*12], 12.0, 10**(-24.0/20.0))
    for i in range(24):
        at = 12.3 + i*.22
        name = ["weapon_pistol", "weapon_smg", "weapon_rifle", "weapon_longbow"][i % 4]
        add(reel, cues[name], at, 10**(volumes[name]/20.0))
        if i % 2 == 0:
            add(reel, cues["hit"], at+.07, 10**(volumes["hit"]/20.0))
    for at, name in [(13.0,"echo"),(15.0,"weapon_explosion"),(16.1,"silence"),(18.2,"boss"),(20.2,"lose"),(22.0,"win")]:
        add(reel,cues[name],at,10**(volumes[name]/20.0))
        timeline.append({"start":at,"cue":name,"section":"runtime-gain mixed scene"})
    for i in range(220):
        fade = i / 219.0
        reel[i] *= fade
        reel[-1-i] *= fade
    write_wav(directory/'paperbureau-audition.wav', reel)
    # A short full-volume ambient preview makes the quiet loop inspectable. The
    # game itself plays it at -24 dB, as the mixed section above demonstrates.
    write_wav(directory/'room-loop-preview.wav', ambient)
    for name, samples in cues.items():
        write_wav(directory/'isolated'/f'{name}.wav', samples)
    (directory/'timeline.json').write_text(json.dumps({"sample_rate":SR,"timeline":timeline,"mix_metrics":metrics(reel),"ambient_preview_gain":"unity; runtime -24dB","listening_status":"not subjectively auditioned by an audio-capable model; human playback requested"},indent=2)+'\n')


def build(output: Path, ambient_path: Path, audition_dir: Path | None = None) -> None:
    palette = source_palette()
    cues = build_cues(palette)
    ambient = build_ambient(palette)
    output.mkdir(parents=True, exist_ok=True)
    for name, samples in cues.items():
        write_wav(output/f'{name}.wav', samples)
    write_wav(ambient_path, ambient)
    if audition_dir:
        audition(audition_dir, cues, ambient, (ROOT/'scripts/game/audio.gd').read_text())
        report = {"cues":{name:metrics(samples) for name,samples in cues.items()},"ambient":metrics(ambient),"source_snapshot_sha256":hashlib.sha256((SOURCE_DIR/'sources.json').read_bytes()).hexdigest()}
        (audition_dir/'asset-metrics.json').write_text(json.dumps(report,indent=2)+'\n')
    print(f'built {len(cues)} paperbureau cues and {AMBIENT_SECONDS}s room loop')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,default=ROOT/'audio/presentation')
    parser.add_argument('--ambient',type=Path,default=ROOT/'audio/ambient.wav')
    parser.add_argument('--audition-dir',type=Path)
    args = parser.parse_args()
    build(args.output,args.ambient,args.audition_dir)
