#!/usr/bin/env python3
"""Audition existing cue materials at the current GameAudio gains and envelopes.

This offline illustration is not an engine capture. Event causality, voice
stealing, crossfades and actual gameplay mixing require the remote game probe.
"""
from __future__ import annotations

import argparse
import array
import hashlib
import json
import math
from pathlib import Path
import re
import sys
import wave

ROOT = Path(__file__).resolve().parents[1]
SR = 44100
SECONDS = 34.0


def block(code: str, name: str) -> str:
    match = re.search(r"const " + name + r" := \{(.*?)\n\}", code, re.S)
    if match is None:
        raise ValueError(f"missing runtime constant: {name}")
    return match.group(1)


def profiles(code: str, name: str) -> dict:
    result = {}
    for key, record in re.findall(r'&"([^"]+)": \{([^}]+)\}', block(code, name)):
        result[key] = {}
        for field, value in re.findall(r'"([^"]+)": ([^,]+)', record):
            result[key][field] = value[2:-1] if value.startswith('&"') else float(value)
    if not result:
        raise ValueError(f"empty runtime profiles: {name}")
    return result


def read_pcm(path: Path, seconds: float | None = None) -> list[float]:
    with wave.open(str(path), "rb") as source:
        if source.getsampwidth() != 2 or source.getnchannels() not in [1, 2]:
            raise ValueError(f"unsupported source format: {path}")
        rate, channels = source.getframerate(), source.getnchannels()
        count = source.getnframes() if seconds is None else min(source.getnframes(), math.ceil(seconds * rate))
        values = array.array("h", source.readframes(count))
    if sys.byteorder != "little":
        values.byteswap()
    mono = [sum(values[i:i+channels]) / (32768.0 * channels) for i in range(0, len(values), channels)]
    if rate == SR:
        return mono
    out = []
    for i in range(math.floor(len(mono) * SR / rate)):
        at = i * rate / SR
        left = int(at)
        fraction = at - left
        out.append(mono[left] * (1.0 - fraction) + mono[min(left+1, len(mono)-1)] * fraction)
    return out


def write_pcm(path: Path, samples: list[float]) -> None:
    peak = max(abs(value) for value in samples)
    if not math.isfinite(peak) or peak >= 1.0:
        raise ValueError(f"audition clips at actual gains: {peak}")
    data = array.array("h", (round(value * 32767.0) for value in samples))
    if sys.byteorder != "little":
        data.byteswap()
    with wave.open(str(path), "wb") as target:
        target.setnchannels(1)
        target.setsampwidth(2)
        target.setframerate(SR)
        target.writeframes(data.tobytes())


def audition(output: Path) -> dict:
    code = (ROOT / "scripts/game/audio.gd").read_text()
    weapon = profiles(code, "WEAPON_PROFILES")
    emphasis = profiles(code, "EMPHASIS_PROFILES")
    levels = {key: float(value) for key, value in re.findall(r'&"([^"]+)": (-?[0-9.]+)', block(code, "VOLUMES"))}
    track = [0.0] * round(SECONDS * SR)
    timeline = []
    ducks = []
    cache = {}

    def cue(at: float, label: str, name: str, volume: float, pitch: float = 1.0,
            gate: float = 0.0, duck: float = 0.0, section: str = "isolated"):
        if name not in cache:
            cache[name] = read_pcm(ROOT / "audio/presentation" / f"{name}.wav")
        source = cache[name]
        length = len(source) / SR / pitch
        if gate > 0:
            length = min(length, gate)
        count = min(round(length * SR), len(track)-round(at * SR))
        gain = 10 ** ((levels[name] + volume) / 20.0)
        start = round(at * SR)
        for i in range(count):
            position = i * pitch
            left = int(position)
            fraction = position - left
            sample = source[left] * (1.0-fraction) + source[min(left+1,len(source)-1)] * fraction
            release = min(1.0, (count-i) / (SR * .025)) if gate > 0 else 1.0
            track[start+i] += sample * gain * release
        timeline.append({"at": at, "section": section, "meaning": label, "cue": name,
                         "volume_db": levels[name] + volume, "pitch": pitch, "gate": gate})
        if duck > 0:
            ducks.append((at, duck))

    def accent(at: float, name: str, section: str = "isolated", copy: bool = False):
        p = emphasis[name]
        cue(at, name + (" / coalesced Echo group" if copy else ""), p["cue"], p["volume"] - (5.0 if copy else 0.0),
            p["pitch"], p["gate"], p["duck"] if not copy else 0.0, section)

    def shot(at: float, name: str, copy: bool = False, section: str = "isolated"):
        p = weapon[name]
        cue(at, name + (" / Echo" if copy else " / player"), p["cue"], p["volume"] - (6.0 if copy else 0.0),
            p["pitch"] - (.04 if copy else 0.0), p.get("gate", 0.0), section=section)

    for i, name in enumerate(["stapler", "hole_punch", "mallet", "rubber_band", "ink_bottle", "hydraulic_press"]):
        shot(.45 + i*.85, name)
    shot(6.0, "pistol", True)
    shot(6.35, "pistol")
    accent(7.3, "combo_pin_press")
    accent(8.2, "combo_ink_arc")
    cue(9.2, "full absorption; no HP-loss cue", "shield_block", -1.0, .91, .17, .08)
    cue(10.1, "actual severe HP loss", "hurt_contact", 2.0, .90, .28, .14)
    accent(11.2, "exhausted")
    cue(12.2, "accepted active stamp sacrifice", "weapon_rail_spike", 1.0, .71, .32, .32)
    accent(13.3, "machine_repaired")
    accent(14.4, "worker_saved")
    cue(15.6, "coalesced materials pickup", "pickup", 0.0, 1.06, .10)
    accent(16.1, "charged")
    accent(17.0, "second_push")
    accent(18.0, "final_push")
    cue(19.2, "actual Boss phase only; seam break at +.18 s", "boss", 1.5, 1.0, duck=.8)

    # A separate short mix keeps the exact cue gains. The eight-copy bed is
    # already coalesced to one same-material event per .16s, as in GameAudio.
    section = "offline mixed scene / illustrative, not an engine capture"
    for i in range(18):
        shot(22.2 + i*.19, "pistol", True, section)
    for i in range(10):
        shot(22.24 + i*.34, ["stapler","hole_punch","rubber_band"][i%3], False, section)
    accent(23.5,"combo_ink_arc",section,True)
    accent(24.5,"combo_pin_press",section)
    cue(26.0,"actual HP loss","hurt_contact",2.0,.9,.28,.14,section)
    accent(27.2,"worker_saved",section)
    cue(28.5,"accepted active stamp sacrifice","weapon_rail_spike",1.0,.71,.32,.32,section)
    cue(30.0,"actual Boss phase","boss",1.5,1.0,duck=.8,section=section)
    music = read_pcm(ROOT / "audio/music/battle.wav", 12.0)
    music_db = float(re.search(r"const MUSIC_DB := (-?[0-9.]+)",code).group(1))
    duck_db = float(re.search(r"const TRANSITION_DUCK_DB := (-?[0-9.]+)",code).group(1))
    for i, value in enumerate(music[:12*SR]):
        at = 22.0 + i/SR
        left = max([duration-(at-start) for start,duration in ducks if start <= at] + [0.0])
        level = music_db + 20*math.log10(.8) + duck_db * min(1.0,max(0.0,left)/.16)
        fade = min(1.0, i/(SR*.15), (len(music)-i)/(SR*.15))
        track[22*SR+i] += value * 10**(level/20.0) * fade
    for i in range(441):
        track[i] *= i/440.0
        track[-1-i] *= i/440.0
    output.mkdir(parents=True,exist_ok=True)
    audio = output/"audio-emphasis-audition.wav"
    write_pcm(audio,track)
    report = {"seconds":SECONDS,"sample_rate":SR,"peak":max(abs(v) for v in track),
              "rms":math.sqrt(sum(v*v for v in track)/len(track)),
              "audio_sha256":hashlib.sha256(audio.read_bytes()).hexdigest(),
              "runtime_audio_source_sha256":hashlib.sha256(code.encode()).hexdigest(),
              "meaning":"Offline cue/gain/pitch/gate illustration; no subjective listening claim. Remote engine/movie verifies actual routing, concurrency and timing.",
              "human_listening":"not verified","timeline":timeline}
    (output/"audio-emphasis-timeline.json").write_text(json.dumps(report,indent=2)+"\n")
    return {key:value for key,value in report.items() if key != "timeline"}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output",type=Path,required=True)
    print(json.dumps(audition(parser.parse_args().output),indent=2))
