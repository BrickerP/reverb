#!/usr/bin/env python3
"""Package audited Take Stack export artifacts into release files.

Expected input layout:
  artifacts/macos/TakeStack-macos.zip
  artifacts/windows/TakeStack.exe
  artifacts/windows/TakeStack.pck
  artifacts/linux/TakeStack.x86_64
  artifacts/linux/TakeStack.pck

The output contains the macOS zip unchanged, Windows/Linux zips, SHA256SUMS.txt
and BUILD_INFO.txt. Linux keeps the executable bit in the zip.
"""
from __future__ import annotations

import argparse
import hashlib
import shutil
import stat
import sys
import zipfile
from datetime import datetime, timezone
from pathlib import Path


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_zip(output: Path, files: list[tuple[Path, str, int]]) -> None:
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for source, name, mode in files:
            info = zipfile.ZipInfo(name)
            info.date_time = (1980, 1, 1, 0, 0, 0)
            info.external_attr = mode << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, source.read_bytes())


def package(artifacts: Path, output: Path, version: str, commit: str,
            godot: str = "4.7.2.stable.official.ed1daf0bf") -> dict:
    if output.exists():
        raise FileExistsError(f"output already exists: {output}")
    required = [
        artifacts / "macos" / "TakeStack-macos.zip",
        artifacts / "windows" / "TakeStack.exe",
        artifacts / "windows" / "TakeStack.pck",
        artifacts / "linux" / "TakeStack.x86_64",
        artifacts / "linux" / "TakeStack.pck",
    ]
    missing = [str(path) for path in required if not path.is_file()]
    if missing:
        raise FileNotFoundError("missing artifacts: " + ", ".join(missing))
    output.mkdir(parents=True)
    shutil.copy2(required[0], output / "TakeStack-macos.zip")
    write_zip(output / "TakeStack-windows.zip", [
        (required[1], "TakeStack.exe", stat.S_IFREG | 0o644),
        (required[2], "TakeStack.pck", stat.S_IFREG | 0o644),
    ])
    write_zip(output / "TakeStack-linux.zip", [
        (required[3], "TakeStack.x86_64", stat.S_IFREG | 0o755),
        (required[4], "TakeStack.pck", stat.S_IFREG | 0o644),
    ])
    packages = sorted(output.glob("TakeStack-*.zip"))
    checksums = {path.name: sha256(path) for path in packages}
    (output / "SHA256SUMS.txt").write_text(
        "".join(f"{checksums[path.name]}  {path.name}\n" for path in packages),
        encoding="utf-8",
    )
    (output / "BUILD_INFO.txt").write_text(
        "\n".join([
            f"version={version}",
            f"commit={commit}",
            f"godot={godot}",
            f"built_at_utc={datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}",
            "platforms=macos,windows,linux",
            "release_status=public-release",
            "",
        ]),
        encoding="utf-8",
    )
    return checksums


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifacts", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--godot", default="4.7.2.stable.official.ed1daf0bf")
    args = parser.parse_args(argv)
    try:
        checksums = package(args.artifacts, args.out, args.version, args.commit, args.godot)
    except (FileExistsError, FileNotFoundError, OSError) as exc:
        print(f"package failed: {exc}", file=sys.stderr)
        return 1
    for name, digest in checksums.items():
        print(f"{digest}  {name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
