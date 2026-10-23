#!/usr/bin/env python3
"""Build the presentation audio cues from Kenney's CC0 source packs."""

from __future__ import annotations

import array
import argparse
import hashlib
import shutil
import subprocess
import sys
import tempfile
import urllib.request
import wave
import zipfile
from pathlib import Path


PACKS = {
    "interface": (
        "https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip",
        "f2193d072726d6758a5f7871b2dcc54dcce0d5c35c6f0a62f92549b327c81232",
    ),
    "impact": (
        "https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip",
        "029d734af1582474edf3a694d1b0cebc97c1c152f2f39fa34d4c2bafc5de77f8",
    ),
}
MAX_PEAK = 0.72
FFMPEG = [
    "ffmpeg",
    "-hide_banner",
    "-loglevel",
    "error",
    "-threads",
    "1",
    "-filter_threads",
    "1",
    "-filter_complex_threads",
    "1",
    "-y",
]


def download_and_extract(root: Path) -> dict[str, Path]:
    extracted: dict[str, Path] = {}
    for name, (url, expected_sha256) in PACKS.items():
        archive = root / f"{name}.zip"
        request = urllib.request.Request(
            url,
            headers={"User-Agent": "take-stack-audio-builder/1.0"},
        )
        with urllib.request.urlopen(request, timeout=30) as response, archive.open("wb") as output:
            shutil.copyfileobj(response, output)
        actual_sha256 = hashlib.sha256(archive.read_bytes()).hexdigest()
        if actual_sha256 != expected_sha256:
            raise RuntimeError(f"source archive checksum mismatch: {name}")
        destination = root / name
        with zipfile.ZipFile(archive) as bundle:
            bundle.extractall(destination)
        extracted[name] = destination / "Audio"
    return extracted


def render(inputs: list[Path], output: Path, filter_graph: str) -> None:
    with tempfile.TemporaryDirectory(prefix="take-stack-pcm-") as temporary:
        decoded: list[Path] = []
        for index, source in enumerate(inputs):
            intermediate = Path(temporary) / f"{index}.wav"
            subprocess.run(
                FFMPEG
                + [
                    "-i",
                    str(source),
                    "-ar",
                    "44100",
                    "-ac",
                    "1",
                    "-c:a",
                    "pcm_s16le",
                    str(intermediate),
                ],
                check=True,
            )
            decoded.append(intermediate)

        command = list(FFMPEG)
        for source in decoded:
            command.extend(["-i", str(source)])
        if len(decoded) == 1:
            command.extend(["-af", filter_graph])
        else:
            command.extend(["-filter_complex", filter_graph, "-map", "[out]"])
        command.extend(["-ar", "44100", "-ac", "1", "-c:a", "pcm_s16le", str(output)])
        subprocess.run(command, check=True)


def validate(output: Path) -> tuple[float, float]:
    with wave.open(str(output), "rb") as wav:
        if wav.getnchannels() != 1 or wav.getsampwidth() != 2 or wav.getframerate() != 44100:
            raise RuntimeError(f"unexpected WAV format: {output}")
        duration = wav.getnframes() / wav.getframerate()
        samples = array.array("h", wav.readframes(wav.getnframes()))
    if sys.byteorder != "little":
        samples.byteswap()
    peak = max(abs(sample) for sample in samples) / 32768.0
    if not 0.02 <= duration <= 1.0:
        raise RuntimeError(f"duration outside cue bounds: {output} ({duration:.3f}s)")
    if not 0.05 <= peak <= MAX_PEAK:
        raise RuntimeError(f"peak outside cue bounds: {output} ({peak:.3f})")
    return duration, peak


def build(output_dir: Path) -> None:
    if shutil.which("ffmpeg") is None:
        raise SystemExit("ffmpeg is required to build presentation audio")
    output_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="take-stack-audio-") as temporary:
        source = download_and_extract(Path(temporary))
        interface = source["interface"]
        impact = source["impact"]

        render(
            [interface / "click_001.ogg"],
            output_dir / "click.wav",
            "highpass=f=180,volume=0.62,atrim=0:0.10,afade=t=out:st=0.07:d=0.03,"
            "alimiter=limit=0.70:level=false",
        )
        render(
            [interface / "confirmation_003.ogg", impact / "impactPlate_light_001.ogg"],
            output_dir / "buy.wav",
            "[0:a]volume=0.62,atrim=0:0.34[a];"
            "[1:a]volume=0.20,atrim=0:0.36,adelay=22[b];"
            "[a][b]amix=inputs=2:duration=longest:normalize=0,"
            "highpass=f=120,afade=t=out:st=0.29:d=0.09,"
            "alimiter=limit=0.70:level=false[out]",
        )
        render(
            [impact / "impactMetal_light_004.ogg"],
            output_dir / "hit.wav",
            "highpass=f=150,lowpass=f=9000,volume=0.72,atrim=0:0.22,"
            "afade=t=out:st=0.16:d=0.06,alimiter=limit=0.70:level=false",
        )
        render(
            [interface / "switch_003.ogg"],
            output_dir / "echo.wav",
            "volume=0.90,aecho=0.9:0.8:34:0.18,"
            "atrim=0:0.72,afade=t=out:st=0.58:d=0.14,"
            "alimiter=limit=0.70:level=false",
        )
        render(
            [interface / "confirmation_002.ogg", impact / "impactBell_heavy_001.ogg"],
            output_dir / "wave_end.wav",
            "[0:a]volume=0.58,atrim=0:0.56[a];"
            "[1:a]volume=0.18,atrim=0:0.82,adelay=55[b];"
            "[a][b]amix=inputs=2:duration=longest:normalize=0,"
            "highpass=f=90,lowpass=f=8500,afade=t=out:st=0.64:d=0.20,"
            "alimiter=limit=0.70:level=false[out]",
        )
        for output in sorted(output_dir.glob("*.wav")):
            duration, peak = validate(output)
            print(f"{output.name}: {duration:.3f}s, peak {peak:.3f}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "audio" / "presentation",
    )
    args = parser.parse_args()
    build(args.output)


if __name__ == "__main__":
    main()
