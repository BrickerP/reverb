#!/usr/bin/env python3
"""Check real first-run/clinic captures without claiming human comprehension."""
from __future__ import annotations
import argparse
import hashlib
import json
import math
import re
import struct
from fractions import Fraction
from pathlib import Path

VARIANTS = ('journey', 'clinic-en', 'clinic-zh', 'clinic-reduced')
CASE_IDS = {f'{number:02d}' for number in range(1, 41)}


def require(value: bool, message: str) -> None:
    if not value:
        raise ValueError(message)


def validate_capture(folder: Path, commit: str, variant: str) -> dict:
    require(variant in VARIANTS, 'unknown perception variant')
    source = json.loads((folder / 'perception_source.json').read_text())
    mode = 'journey' if variant == 'journey' else 'clinic'
    canvas = [960, 540] if variant == 'clinic-zh' else [1280, 720]
    require(source.get('success') is True and source.get('failed') is False, 'perception capture failed')
    require(source.get('commit') == commit and source.get('mode') == mode, 'perception source mismatch')
    require(source.get('canvas') == canvas and source.get('fps') == 60 and source.get('uncut') is True, 'native capture configuration mismatch')
    require(source.get('language') == ('zh' if variant == 'clinic-zh' else 'en'), 'language mismatch')
    require(source.get('reduced') == (variant == 'clinic-reduced'), 'reduced-effects mismatch')
    require(source.get('audio') == 'real unmuted GameAudio master mix', 'actual audio mix missing')
    frames = source.get('native_frames', 0)
    require(60 <= frames <= (60 * 250 if mode == 'journey' else 60 * 90), 'native frame budget mismatch')
    rows = source.get('case_coverage', [])
    require(len(rows) == 40 and {row['id'] for row in rows} == CASE_IDS, 'forty-case inventory mismatch')
    require(all(row.get('status') in ('native_observed', 'not_exercised') for row in rows), 'unsupported comprehension claim')
    shots = source.get('screenshots', {})
    checks = source.get('read_only_checks', [])
    require(shots and checks, 'native state/image proofs missing')
    require(all(all(row.get(key) is True for key in ('strict_roundtrip', 'full_snapshot_unchanged', 'rng_unchanged', 'hazard_rng_unchanged')) for row in checks), 'render changed model or RNG')
    hashes = {}
    for row in shots.values():
        name = row['file']
        require(Path(name).name == name, 'unsafe screenshot path')
        data = (folder / name).read_bytes()
        require(data[:8] == b'\x89PNG\r\n\x1a\n' and list(struct.unpack('>II', data[16:24])) == canvas, 'wrong native image dimensions')
        hashes[name] = hashlib.sha256(data).hexdigest()
    observed = sorted(row['id'] for row in rows if row['status'] == 'native_observed')
    require(observed and source.get('inputs'), 'no exercised player entry path')
    if mode == 'journey':
        policy = source.get('policy', {})
        require(policy.get('fresh_run') is True and policy.get('native_main_physics') is True, 'journey is not a fresh actual Main run')
        require(all(policy.get(key) is False for key in ('preseeded_knowledge', 'preseeded_gear', 'invulnerability', 'skip_waves', 'simulation_time_jumps', 'manual_sim_step')), 'journey manipulates gameplay')
        require(source.get('highest_wave', 0) >= 4 and source.get('first_boss_spawned') is True and source.get('first_boss_defeated') is True, 'natural first-boss journey incomplete')
    else:
        require({'11', '13', '25', '32', '33', '34', '35', '40'} <= set(observed), 'critical clinic paths unobserved')
        if variant == 'clinic-zh':
            handoff = source.get('first_echo_native', {})
            require(handoff.get('familiar_before') is False and all(handoff.get(key) is True for key in ('identity_visible', 'panel_visible', 'inside_viewport')), 'compact first Echo handoff missing')
    media = json.loads((folder / 'video.json').read_text())['streams']
    video = next(row for row in media if row['codec_type'] == 'video')
    audio = next(row for row in media if row['codec_type'] == 'audio')
    require([video['width'], video['height']] == canvas and Fraction(video['avg_frame_rate']) == 60, 'encoded video configuration mismatch')
    require(abs(float(video['duration']) - frames / 60) < .25, 'movie and native event clock diverge')
    require(float(audio['duration']) >= frames / 60 - .25, 'audio mix truncated')
    analysis = (folder / 'audio-analysis.txt').read_text()
    rms = [float(value) for value in re.findall(r'RMS level dB:\s*(-?[\d.]+|[-+]?inf)', analysis)]
    peak = [float(value) for value in re.findall(r'Peak level dB:\s*(-?[\d.]+|[-+]?inf)', analysis)]
    require(rms and all(math.isfinite(value) and -80 < value < 0 for value in rms), 'silent/invalid game audio')
    require(peak and all(math.isfinite(value) and value < -.05 for value in peak), 'clipped/invalid game audio')
    return {'verified': True, 'commit': commit, 'variant': variant, 'mode': mode,
            'canvas': canvas, 'native_frames': frames, 'observed_cases': observed,
            'catalog_size': 40, 'human_understanding_verified': False,
            'screenshots': hashes, 'audio': {'rms_db': rms, 'peak_db': peak}}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folder', type=Path)
    parser.add_argument('--commit', required=True)
    parser.add_argument('--variant', choices=VARIANTS, required=True)
    args = parser.parse_args()
    receipt = validate_capture(args.folder, args.commit, args.variant)
    (args.folder / 'verified.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({key: value for key, value in receipt.items() if key != 'screenshots'}))


if __name__ == '__main__':
    main()
