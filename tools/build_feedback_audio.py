#!/usr/bin/env python3
"""Build rich combat and transaction cues from checksum-pinned Kenney CC0 packs."""

from __future__ import annotations

import argparse
import shutil
import tempfile
from pathlib import Path

from build_presentation_audio import download_and_extract, render, validate


def build(output_dir: Path) -> None:
    if shutil.which("ffmpeg") is None:
        raise SystemExit("ffmpeg is required to build feedback audio")
    output_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="take-stack-feedback-") as temporary:
        source = download_and_extract(Path(temporary))
        ui = source["interface"]
        impact = source["impact"]

        recipes: list[tuple[str, list[Path], str]] = [
            (
                "weapon_pistol",
                [impact / "impactMetal_light_000.ogg"],
                "highpass=f=210,lowpass=f=8500,volume=0.72,atrim=0:0.18,"
                "afade=t=out:st=0.13:d=0.05,alimiter=limit=0.68:level=false",
            ),
            (
                "weapon_smg",
                [impact / "impactMetal_light_001.ogg"],
                "highpass=f=300,lowpass=f=9200,volume=0.58,atrim=0:0.11,"
                "afade=t=out:st=0.075:d=0.035,alimiter=limit=0.62:level=false",
            ),
            (
                "weapon_shotgun",
                [impact / "impactMetal_heavy_000.ogg"],
                "highpass=f=75,lowpass=f=6200,volume=0.72,atrim=0:0.42,"
                "afade=t=out:st=0.30:d=0.12,alimiter=limit=0.68:level=false",
            ),
            (
                "weapon_rifle",
                [impact / "impactMetal_medium_003.ogg"],
                "highpass=f=160,lowpass=f=7800,volume=0.70,atrim=0:0.30,"
                "afade=t=out:st=0.22:d=0.08,alimiter=limit=0.68:level=false",
            ),
            (
                "weapon_orb",
                [ui / "glass_003.ogg", impact / "impactBell_heavy_003.ogg"],
                "[0:a]volume=0.58,atrim=0:0.42[a];"
                "[1:a]volume=0.14,atrim=0:0.60,adelay=24[b];"
                "[a][b]amix=inputs=2:duration=longest:normalize=0,"
                "highpass=f=180,afade=t=out:st=0.46:d=0.16,"
                "alimiter=limit=0.66:level=false[out]",
            ),
            (
                "weapon_flechette",
                [impact / "impactMetal_light_003.ogg", impact / "impactGeneric_light_003.ogg"],
                "[0:a]volume=0.54,atrim=0:0.16[a];"
                "[1:a]volume=0.30,atrim=0:0.18,adelay=18[b];"
                "[a][b]amix=inputs=2:duration=longest:normalize=0,"
                "highpass=f=260,afade=t=out:st=0.13:d=0.05,"
                "alimiter=limit=0.62:level=false[out]",
            ),
            (
                "weapon_longbow",
                [ui / "pluck_001.ogg"],
                "highpass=f=90,lowpass=f=7000,volume=0.78,atrim=0:0.48,"
                "afade=t=out:st=0.34:d=0.14,alimiter=limit=0.66:level=false",
            ),
            (
                "weapon_hex_bolt",
                [ui / "glass_005.ogg", ui / "switch_004.ogg"],
                "[0:a]volume=0.48,atrim=0:0.36[a];"
                "[1:a]volume=0.30,atrim=0:0.38[b];"
                "[a][b]amix=inputs=2:duration=longest:normalize=0,"
                "highpass=f=190,afade=t=out:st=0.29:d=0.10,"
                "alimiter=limit=0.64:level=false[out]",
            ),
            (
                "weapon_twin_fangs",
                [impact / "impactMetal_light_000.ogg", impact / "impactMetal_light_002.ogg"],
                "[0:a]volume=0.48,atrim=0:0.17[a];"
                "[1:a]volume=0.42,atrim=0:0.18,adelay=52[b];"
                "[a][b]amix=inputs=2:duration=longest:normalize=0,"
                "highpass=f=240,afade=t=out:st=0.17:d=0.06,"
                "alimiter=limit=0.64:level=false[out]",
            ),
            (
                "weapon_flak_crown",
                [impact / "impactMetal_heavy_002.ogg", impact / "impactPlate_heavy_001.ogg"],
                "[0:a]volume=0.62,atrim=0:0.48[a];"
                "[1:a]volume=0.24,atrim=0:0.52,adelay=34[b];"
                "[a][b]amix=inputs=2:duration=longest:normalize=0,"
                "highpass=f=70,lowpass=f=6500,afade=t=out:st=0.40:d=0.14,"
                "alimiter=limit=0.68:level=false[out]",
            ),
            (
                "weapon_rail_spike",
                [impact / "impactMetal_heavy_004.ogg", impact / "impactMetal_medium_004.ogg"],
                "[0:a]volume=0.58,atrim=0:0.44[a];"
                "[1:a]volume=0.32,atrim=0:0.34,adelay=20[b];"
                "[a][b]amix=inputs=2:duration=longest:normalize=0,"
                "highpass=f=100,lowpass=f=7600,afade=t=out:st=0.35:d=0.12,"
                "alimiter=limit=0.68:level=false[out]",
            ),
            (
                "weapon_nova_core",
                [impact / "impactBell_heavy_003.ogg", ui / "glass_003.ogg"],
                "[0:a]volume=0.30,atrim=0:0.78[a];"
                "[1:a]volume=0.48,atrim=0:0.42,adelay=28[b];"
                "[a][b]amix=inputs=2:duration=longest:normalize=0,"
                "highpass=f=80,lowpass=f=7800,afade=t=out:st=0.62:d=0.18,"
                "alimiter=limit=0.66:level=false[out]",
            ),
            (
                "hit_crit",
                [impact / "impactMetal_medium_002.ogg"],
                "highpass=f=130,volume=0.70,atrim=0:0.28,afade=t=out:st=0.20:d=0.08,"
                "alimiter=limit=0.68:level=false",
            ),
            (
                "shield_block",
                [impact / "impactPlate_heavy_001.ogg"],
                "highpass=f=100,lowpass=f=7800,volume=0.64,atrim=0:0.46,"
                "afade=t=out:st=0.34:d=0.12,alimiter=limit=0.68:level=false",
            ),
            (
                "weapon_explosion",
                [impact / "impactPunch_medium_003.ogg", impact / "impactMetal_medium_000.ogg"],
                "[0:a]volume=0.62,atrim=0:0.45[a];"
                "[1:a]volume=0.22,atrim=0:0.36,adelay=18[b];"
                "[a][b]amix=inputs=2:duration=longest:normalize=0,"
                "lowpass=f=6200,afade=t=out:st=0.34:d=0.13,"
                "alimiter=limit=0.68:level=false[out]",
            ),
            (
                "bomber_explosion",
                [impact / "impactPunch_heavy_002.ogg", impact / "impactSoft_heavy_001.ogg"],
                "[0:a]volume=0.60,atrim=0:0.62[a];"
                "[1:a]volume=0.32,atrim=0:0.58,adelay=24[b];"
                "[a][b]amix=inputs=2:duration=longest:normalize=0,"
                "lowpass=f=5200,afade=t=out:st=0.48:d=0.16,"
                "alimiter=limit=0.68:level=false[out]",
            ),
            (
                "hurt_contact",
                [impact / "impactSoft_medium_002.ogg"],
                "highpass=f=70,lowpass=f=5200,volume=0.68,atrim=0:0.34,"
                "afade=t=out:st=0.24:d=0.10,alimiter=limit=0.66:level=false",
            ),
            (
                "hurt_blast",
                [impact / "impactPunch_heavy_000.ogg"],
                "lowpass=f=5600,volume=0.68,atrim=0:0.48,afade=t=out:st=0.35:d=0.13,"
                "alimiter=limit=0.68:level=false",
            ),
            (
                "equipment_apply",
                [ui / "confirmation_001.ogg", impact / "impactPlate_light_003.ogg"],
                "[0:a]volume=0.58,atrim=0:0.31[a];"
                "[1:a]volume=0.22,atrim=0:0.30,adelay=20[b];"
                "[a][b]amix=inputs=2:duration=longest:normalize=0,"
                "highpass=f=140,afade=t=out:st=0.25:d=0.08,"
                "alimiter=limit=0.66:level=false[out]",
            ),
            (
                "equipment_undo",
                [ui / "back_001.ogg", ui / "switch_001.ogg"],
                "[0:a]volume=0.56,atrim=0:0.34[a];"
                "[1:a]volume=0.24,atrim=0:0.32,adelay=18[b];"
                "[a][b]amix=inputs=2:duration=longest:normalize=0,"
                "highpass=f=130,afade=t=out:st=0.27:d=0.09,"
                "alimiter=limit=0.64:level=false[out]",
            ),
            (
                "shop_reroll",
                [ui / "switch_001.ogg"],
                "highpass=f=150,volume=0.66,atrim=0:0.42,afade=t=out:st=0.32:d=0.10,"
                "alimiter=limit=0.64:level=false",
            ),
        ]

        for name, inputs, filters in recipes:
            render(inputs, output_dir / f"{name}.wav", filters)
        for name, _inputs, _filters in recipes:
            output = output_dir / f"{name}.wav"
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
