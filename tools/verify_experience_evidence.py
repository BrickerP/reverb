#!/usr/bin/env python3
"""Verify the short native route/assault/accent capture, including audible audio."""
from __future__ import annotations
import argparse
import hashlib
import json
import math
import re
import struct
from fractions import Fraction
from pathlib import Path

CASES = {'eight_routes', 'combo_and_charge', 'worker_rescue', 'active_retirement', 'finite_assault_close'}


def require(value: bool, message: str) -> None:
    if not value:
        raise ValueError(message)


def validate_source(folder: Path, commit: str, variant: str) -> dict:
    source = json.loads((folder / 'experience_source.json').read_text())
    require(source.get('success') is True and source.get('failed') is False, 'native probe failed')
    require(source.get('commit') == commit and source.get('variant') == variant, 'capture source mismatch')
    require(source.get('source') == 'scripted fixture', 'fixture disclosure missing')
    canvas = [960, 540] if variant == 'compact' else [1280, 720]
    require(source.get('canvas') == canvas, 'native canvas mismatch')
    require(810 <= source.get('native_frames', 0) <= 960, 'native frame budget mismatch')
    capture = source.get('capture', {})
    require(capture.get('fps') == 60 and capture.get('speed') == 1.0, 'capture speed mismatch')
    require(capture.get('audio') == 'real unmuted GameAudio master mix', 'real audio capture missing')
    cases = source.get('cases', [])
    require(len(cases) == len(CASES) and {row.get('name') for row in cases} == CASES, 'case inventory mismatch')
    require(all(row.get('audio_route_delta', 0) > 0 for row in cases), 'case never reached actual audio routing')
    shots = source.get('screenshots', {})
    checks = source.get('read_only_checks', [])
    require(len(shots) == len(checks) == 14, 'screenshot/read-only proof inventory mismatch')
    for row in checks:
        require(all(row.get(key) is True for key in ('strict_roundtrip', 'full_snapshot_unchanged', 'rng_unchanged', 'hazard_rng_unchanged')), 'render mutated the model or random streams')
    routes = source.get('route_evidence', [])
    require(len(routes) == 3, 'route comparison missing')
    for route in routes:
        error = route.get('maximum_position_error', math.inf)
        require(route.get('count') == 8 and route.get('actual_future_steps') == 120 and math.isfinite(error) and error < .05, 'route differs from actual future simulation')
    hashes = {}
    for row in shots.values():
        name = row['file']
        require(Path(name).name == name, 'unsafe screenshot path')
        data = (folder / name).read_bytes()
        require(data[:8] == b'\x89PNG\r\n\x1a\n' and list(struct.unpack('>II', data[16:24])) == canvas, 'PNG canvas mismatch')
        hashes[name] = hashlib.sha256(data).hexdigest()
    require(len(set(hashes.values())) >= 5, 'capture did not show distinct states')
    return {'commit': commit, 'variant': variant, 'screenshots': hashes, 'native_frames': source['native_frames']}


def validate_media(folder: Path, canvas: list[int]) -> dict:
    streams = json.loads((folder / 'video.json').read_text())['streams']
    video = next(row for row in streams if row['codec_type'] == 'video')
    audio = next(row for row in streams if row['codec_type'] == 'audio')
    require([video['width'], video['height']] == canvas and Fraction(video['avg_frame_rate']) == 60, 'encoded native video mismatch')
    require(13.0 <= float(video['duration']) <= 16.2, 'native movie duration mismatch')
    require(int(audio['channels']) >= 1 and float(audio['duration']) >= 13.0, 'audio track is incomplete')
    analysis = (folder / 'audio-analysis.txt').read_text()
    rms = [float(v) for v in re.findall(r'RMS level dB:\s*(-?[\d.]+|[-+]?inf)', analysis)]
    peaks = [float(v) for v in re.findall(r'Peak level dB:\s*(-?[\d.]+|[-+]?inf)', analysis)]
    require(rms and all(math.isfinite(v) and -80 < v < 0 for v in rms), 'audio is silent or invalid')
    require(peaks and all(math.isfinite(v) and v < -.05 for v in peaks), 'audio is clipped or invalid')
    return {'rms_db': rms, 'peak_db': peaks, 'scope': 'real engine mix; subjective listening remains manual'}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folder', type=Path)
    parser.add_argument('--commit', required=True)
    parser.add_argument('--variant', choices=['normal', 'compact', 'reduced'], required=True)
    args = parser.parse_args()
    result = validate_source(args.folder, args.commit, args.variant)
    result['audio'] = validate_media(args.folder, [960, 540] if args.variant == 'compact' else [1280, 720])
    (args.folder / 'verified.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'verified': True, 'variant': args.variant, 'screenshots': len(result['screenshots']), 'audio': result['audio']}))


if __name__ == '__main__':
    main()
