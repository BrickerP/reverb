#!/usr/bin/env python3
"""Export and audit Take Stack from an immutable Git commit.

The source checkout is never edited. A Git archive is expanded into a new staging
directory, where an isolated Godot user-data name is injected before import/export.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import stat
import subprocess
import tarfile
import time
from pathlib import Path
from typing import Any, Dict, Optional

ENGINE_ERRORS = re.compile(r"SCRIPT ERROR|^ERROR:|Parse Error|FAILED:", re.MULTILINE)
PRESETS = {
    "macOS": "TakeStack-macos.zip",
    "Windows": "TakeStack.exe",
    "Linux": "TakeStack.x86_64",
}
PROVENANCE_FILES = [
    "LICENSE",
    "THIRD_PARTY.md",
    "assets/fonts/OFL.txt",
    "assets/fonts/AmaticSC-OFL.txt",
    "assets/fonts/ZCOOLKuaiLe-OFL.txt",
    "assets/fonts/SOURCES.json",
    "assets/presentation/SOURCES.md",
    "assets/presentation/manifest.json",
    "assets/presentation/app_icon/SOURCES.md",
    "assets/presentation/app_icon/manifest.json",
    "assets/presentation/characters/SOURCES.md",
    "assets/presentation/characters/manifest.json",
    "assets/presentation/enemies/SOURCES.md",
    "assets/presentation/enemies/manifest.json",
    "assets/presentation/environment/SOURCES.md",
    "assets/presentation/environment/manifest.json",
    "assets/presentation/items/SOURCES.md",
    "assets/presentation/items/manifest.json",
    "assets/presentation/surfaces/SOURCES.md",
    "assets/presentation/surfaces/manifest.json",
    "assets/presentation/weapons/SOURCES.md",
    "assets/presentation/weapons/manifest.json",
    "audio/presentation/SOURCES.md",
]
FORBIDDEN_PATHS = [
    "assets/presentation/surfaces/panel_skin.png",
    "shots/",
    "tests/",
    "tools/",
    "docs/",
    ".omx/",
    "override.cfg",
    "scripts/dev/",
    # The single paper-bureau palette supersedes every legacy tonal cue.
    "audio/boss.wav",
    "audio/buy.wav",
    "audio/click.wav",
    "audio/echo.wav",
    "audio/hit.wav",
    "audio/hurt.wav",
    "audio/kill.wav",
    "audio/lose.wav",
    "audio/pickup.wav",
    "audio/shoot.wav",
    "audio/silence.wav",
    "audio/wave_end.wav",
    "audio/wave_start.wav",
    "audio/win.wav",
]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def run_checked(
    command: list[str], cwd: Path, log_path: Path, timeout: int = 600,
    environment: Optional[Dict[str, str]] = None,
) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        command,
        cwd=cwd,
        env=environment,
        text=True,
        capture_output=True,
        timeout=timeout,
    )
    output = result.stdout + result.stderr
    log_path.parent.mkdir(parents=True, exist_ok=True)
    log_path.write_text(output)
    if result.returncode != 0 or ENGINE_ERRORS.search(output):
        raise RuntimeError(
            f"command failed ({result.returncode}): {' '.join(command)}; see {log_path}"
        )
    return result


def git(repo: Path, *args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=repo, text=True).strip()


def archive_commit(repo: Path, commit: str, stage: Path) -> None:
    archive = stage.parent / f"{stage.name}.tar"
    subprocess.run(
        ["git", "archive", "--format=tar", "-o", str(archive), commit],
        cwd=repo,
        check=True,
    )
    stage.mkdir(parents=False)
    with tarfile.open(archive) as source:
        for member in source.getmembers():
            target = (stage / member.name).resolve()
            if target != stage and stage not in target.parents:
                raise RuntimeError(f"unsafe archive member: {member.name}")
        source.extractall(stage)
    archive.unlink()


def inject_isolated_user_dir(
    project_file: Path, custom_name: str, build_commit: str,
) -> dict[str, str]:
    if re.fullmatch(r"(?:[0-9a-f]{40}|[0-9a-f]{64})", build_commit) is None:
        raise RuntimeError("build commit must be a full hexadecimal Git object ID")
    original = project_file.read_text()
    marker = "[application]\n"
    if original.count(marker) != 1:
        raise RuntimeError("project.godot must contain exactly one [application] section")
    if "config/use_custom_user_dir=" in original or "config/custom_user_dir_name=" in original:
        raise RuntimeError("fixed source commit already defines a custom user directory")
    addition = (
        "config/use_custom_user_dir=true\n"
        f'config/custom_user_dir_name="{custom_name}"\n'
        f'config/build_commit="{build_commit}"\n'
    )
    overlaid = original.replace(marker, marker + addition, 1)
    project_file.write_text(overlaid)
    return {
        "source_sha256": hashlib.sha256(original.encode()).hexdigest(),
        "overlay_sha256": hashlib.sha256(overlaid.encode()).hexdigest(),
        "custom_user_dir_name": custom_name,
        "build_commit": build_commit,
    }


def cue_names(audio_source: str) -> list[str]:
    match = re.search(
        r"const ALL_NAMES: Array\[StringName\] = \[(.*?)\]\nconst WEAPON_PROFILES",
        audio_source,
        re.DOTALL,
    )
    if match is None:
        raise RuntimeError("could not parse GameAudio.ALL_NAMES")
    names = re.findall(r'&"([^"]+)"', match.group(1))
    if len(names) != 35 or len(set(names)) != 35:
        raise RuntimeError(f"expected 35 unique runtime cues, found {len(names)}")
    return names


def expected_inventory(stage: Path) -> dict[str, Any]:
    pngs = sorted(path.relative_to(stage).as_posix() for path in (stage / "assets/presentation").rglob("*.png"))
    if len(pngs) != 43:
        raise RuntimeError(f"expected 43 presentation PNGs, found {len(pngs)}")
    names = cue_names((stage / "scripts/game/audio.gd").read_text())
    cues: list[str] = []
    for name in names:
        selected = stage / "audio/presentation" / f"{name}.wav"
        if not selected.exists():
            raise RuntimeError(f"runtime audio cue has no source file: {name}")
        cues.append(selected.relative_to(stage).as_posix())
    if len(set(cues)) != 35:
        raise RuntimeError("runtime cue paths are not unique")
    missing_provenance = [path for path in PROVENANCE_FILES if not (stage / path).is_file()]
    if missing_provenance:
        raise RuntimeError(f"missing provenance sources: {missing_provenance}")
    resources = [f"res://{path}" for path in pngs]
    fonts = ["assets/fonts/NotoSansCJKsc-Regular.otf", "assets/fonts/AmaticSC-Bold.ttf",
             "assets/fonts/ZCOOLKuaiLe-Regular.ttf"]
    resources.extend(f"res://{path}" for path in fonts)
    resources.extend(f"res://{path}" for path in cues)
    resources.append("res://audio/ambient.wav")
    return {
        "resources": resources,
        "files": [f"res://{path}" for path in PROVENANCE_FILES],
        "forbidden_prefixes": FORBIDDEN_PATHS,
        "counts": {
            "presentation_png": len(pngs),
            "font": len(fonts),
            "runtime_cues": len(cues),
            "ambient": 1,
            "provenance": len(PROVENANCE_FILES),
        },
        "runtime_cue_paths": cues,
    }


def artifact_record(path: Path) -> dict[str, Any]:
    info = path.stat()
    return {
        "path": str(path),
        "bytes": info.st_size,
        "mtime_ns": info.st_mtime_ns,
        "sha256": sha256(path),
    }


def artifact_records(directory: Path) -> list[dict[str, Any]]:
    records = []
    for path in sorted(item for item in directory.rglob("*") if item.is_file()):
        record = artifact_record(path)
        record["relative_path"] = path.relative_to(directory).as_posix()
        records.append(record)
    return records


def one_pack(directory: Path, platform: str) -> Path:
    packs = list(directory.glob("*.pck"))
    if len(packs) != 1:
        raise RuntimeError(f"expected one delivered {platform} PCK, found {len(packs)}")
    return packs[0]


def tree_fingerprint(directory: Path) -> dict[str, Any]:
    if not directory.exists():
        return {"exists": False, "files": []}
    return {"exists": True, "files": artifact_records(directory)}


def extract_macos(zip_path: Path, smoke_dir: Path, logs: Path) -> dict[str, Path]:
    ditto = shutil.which("ditto")
    if ditto is None:
        raise RuntimeError("macOS export audit requires /usr/bin/ditto to preserve executable modes")
    run_checked(
        [ditto, "-x", "-k", str(zip_path), str(smoke_dir)],
        zip_path.parent,
        logs / "macos-extract.log",
        timeout=120,
    )
    applications = list(smoke_dir.rglob("*.app"))
    if len(applications) != 1:
        raise RuntimeError(f"expected one macOS app in export, found {len(applications)}")
    executables = [
        path for path in (applications[0] / "Contents/MacOS").iterdir()
        if path.is_file() and path.stat().st_mode & stat.S_IXUSR
    ]
    if len(executables) != 1:
        raise RuntimeError(f"expected one macOS executable, found {len(executables)}")
    packs = list((applications[0] / "Contents/Resources").glob("*.pck"))
    if len(packs) != 1:
        raise RuntimeError(f"expected one delivered macOS PCK, found {len(packs)}")
    return {"app": applications[0], "executable": executables[0], "pack": packs[0]}


def macos_smoke(
    macos: dict[str, Path], smoke_dir: Path, logs: Path, custom_name: str,
) -> dict[str, Any]:
    normal_user_dir = Path.home() / "Library/Application Support/Godot/app_userdata/Take Stack"
    isolated_user_dir = Path.home() / "Library/Application Support" / custom_name
    isolated_log = isolated_user_dir / "export-audit.log"
    if isolated_log.exists():
        raise RuntimeError(f"isolated export smoke log already exists: {isolated_log}")
    if isolated_user_dir.resolve() not in isolated_log.resolve().parents:
        raise RuntimeError("isolated export smoke log escaped its exact custom user directory")
    normal_before = tree_fingerprint(normal_user_dir)
    environment = os.environ.copy()
    environment.update({
        "REVERB_SAVE": "user://export_audit_save.json",
        "REVERB_RUN_LOG": "user://export_audit_runs.jsonl",
        "REVERB_SETTINGS": "user://export_audit_settings.json",
    })
    run_checked(
        [str(macos["executable"]), "--headless", "--log-file", "user://export-audit.log",
         "--quit-after", "30"],
        smoke_dir,
        logs / "macos-smoke.log",
        timeout=60,
        environment=environment,
    )
    normal_after = tree_fingerprint(normal_user_dir)
    if not isolated_log.is_file():
        raise RuntimeError(
            "exported macOS app did not resolve user:// to the injected isolated directory"
        )
    isolated_output = isolated_log.read_text(errors="replace")
    if ENGINE_ERRORS.search(isolated_output):
        raise RuntimeError(f"exported macOS app logged an engine error: {isolated_log}")
    if normal_before != normal_after:
        raise RuntimeError("exported preview changed the normal Take Stack user-data directory")
    return {
        "app": str(macos["app"]),
        "executable": str(macos["executable"]),
        "delivered_pack": artifact_record(macos["pack"]),
        "custom_user_dir_name": custom_name,
        "isolated_user_dir": str(isolated_user_dir),
        "isolated_log": artifact_record(isolated_log),
        "normal_user_dir_unchanged": True,
        "frames": 30,
        "log": str(logs / "macos-smoke.log"),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--ref", required=True, help="immutable commit/tag/SHA to export")
    parser.add_argument("--stage-dir", type=Path, required=True)
    parser.add_argument("--godot", default="godot")
    args = parser.parse_args()

    repo = args.repo.resolve()
    stage = args.stage_dir.resolve()
    audit_dir = stage.parent / f"{stage.name}-audit"
    if stage.exists():
        raise SystemExit(f"stage directory already exists; choose a fresh path: {stage}")
    if audit_dir.exists():
        raise SystemExit(f"audit directory already exists; choose a fresh stage path: {audit_dir}")
    stage.parent.mkdir(parents=True, exist_ok=True)
    commit = git(repo, "rev-parse", f"{args.ref}^{{commit}}")
    archive_commit(repo, commit, stage)

    short = commit[:12]
    created_at = int(time.time())
    custom_name = f"Codex/TakeStack-ExportAudit-{short}-{created_at}"
    overlay = inject_isolated_user_dir(stage / "project.godot", custom_name, commit)
    expected = expected_inventory(stage)
    # Keep every audit script, pack and binary outside res:// so `all_resources`
    # cannot accidentally package its own verification machinery or outputs.
    logs = audit_dir / "logs"
    artifacts = audit_dir / "artifacts"
    runner = audit_dir / "runner"
    for directory in [logs, artifacts, runner]:
        directory.mkdir(parents=True, exist_ok=True)
    expected_path = audit_dir / "expected.json"
    expected_path.write_text(json.dumps(expected, indent=2) + "\n")
    (runner / "project.godot").write_text(
        '; Isolated empty project for mounting exported packs.\nconfig_version=5\n'
    )
    shutil.copy2(stage / "tools/export_package_audit.gd", runner / "audit.gd")

    godot = shutil.which(args.godot) or args.godot
    godot_version = subprocess.check_output([godot, "--version"], text=True).strip()
    run_checked([godot, "--headless", "--path", ".", "--import"], stage, logs / "import.log")
    exported: dict[str, Any] = {}
    for preset, filename in PRESETS.items():
        platform_dir = artifacts / preset.lower()
        platform_dir.mkdir()
        artifact = platform_dir / filename
        run_checked(
            [godot, "--headless", "--path", ".", "--export-release", preset, str(artifact)],
            stage,
            logs / f"export-{preset.lower()}.log",
        )

    smoke_dir = audit_dir / "macos-smoke"
    macos = extract_macos(artifacts / "macos" / PRESETS["macOS"], smoke_dir, logs)
    delivered_packs = {
        "macOS": macos["pack"],
        "Windows": one_pack(artifacts / "windows", "Windows"),
        "Linux": one_pack(artifacts / "linux", "Linux"),
    }
    for preset, filename in PRESETS.items():
        platform_dir = artifacts / preset.lower()
        pack = delivered_packs[preset]
        if not pack.is_file():
            raise RuntimeError(f"export did not deliver an auditable sidecar PCK: {pack}")
        audit_result = audit_dir / f"audit-{preset.lower()}.json"
        run_checked(
            [godot, "--headless", "--path", str(runner), "--script", "res://audit.gd", "--",
             str(pack), str(expected_path), str(audit_result)],
            runner,
            logs / f"audit-{preset.lower()}.log",
        )
        exported[preset] = {
            "package_files": artifact_records(platform_dir),
            "delivered_pack": artifact_record(pack),
            "audit": json.loads(audit_result.read_text()),
        }

    smoke = macos_smoke(macos, smoke_dir, logs, custom_name)
    result = {
        "commit": commit,
        "source_repo": str(repo),
        "godot_version": godot_version,
        "stage": str(stage),
        "audit_dir": str(audit_dir),
        "overlay": overlay,
        "expected": expected,
        "exports": exported,
        "macos_smoke": smoke,
        "user_data_isolation": {
            "macOS": "runtime_verified",
            "Windows": "compiled_from_staging_overlay_not_runtime_verified_on_macos",
            "Linux": "compiled_from_staging_overlay_not_runtime_verified_on_macos",
        },
        "created_at_unix": created_at,
        "release_actions": False,
    }
    result_path = audit_dir / "result.json"
    result_path.write_text(json.dumps(result, indent=2) + "\n")
    print(f"Take Stack export audit OK: {commit}")
    print(result_path)


if __name__ == "__main__":
    main()
