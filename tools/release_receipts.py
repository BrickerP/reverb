#!/usr/bin/env python3
"""Bind release packages and evidence to this exact CI run; verify draft downloads."""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import zipfile
from fractions import Fraction
from pathlib import Path

GATES = {"test", "paper-feedback", "export-preview", "export-linux", "export-windows"}
PACKAGES = {f"TakeStack-{platform}.zip" for platform in ("macos", "windows", "linux")}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def digest(path: Path) -> str:
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def read_json(path: Path) -> dict:
    require(path.is_file(), f"missing evidence: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def project_version(repo: Path) -> str:
    matches = re.findall(r'^config/version="([^"]+)"$', (repo / "project.godot").read_text(), re.M)
    require(len(matches) == 1, "project must declare exactly one version")
    return matches[0]


def build_info(path: Path) -> dict:
    rows = path.read_text(encoding="utf-8").splitlines()
    result = dict(row.split("=", 1) for row in rows if row)
    require(len(result) == len([row for row in rows if row]), "duplicate BUILD_INFO fields")
    return result


def validate_identity(version: str, commit: str, ref: str, audit: dict, info: dict) -> None:
    require(re.fullmatch(r"[0-9a-f]{40}|[0-9a-f]{64}", commit) is not None, "source must be a full commit SHA")
    if ref.startswith("refs/tags/"):
        require(ref == f"refs/tags/v{version}", "release tag does not match project version")
    require(audit.get("commit") == commit and audit.get("overlay", {}).get("build_commit") == commit,
            "export audit source SHA mismatch")
    require(info.get("version") == version and info.get("commit") == commit, "BUILD_INFO identity mismatch")
    require(info.get("release_status") == "public-release", "package is not a public release candidate")
    require(audit.get("overlay", {}).get("custom_user_dir_name") == "TakeStack Preview",
            "public save directory must remain unchanged")


def validate_exports(audit_dir: Path, audit: dict) -> None:
    packs = set()
    for platform in ("macOS", "Windows", "Linux"):
        exported = audit["exports"][platform]
        result = exported["audit"]
        require(result.get("ok") is True and not result.get("failures") and not result.get("forbidden_hits"),
                f"{platform} pack audit failed")
        require(bool(exported.get("package_files")), f"missing {platform} package inventory")
        folder = audit_dir / "artifacts" / platform.lower()
        for record in exported["package_files"]:
            relative = record["relative_path"]
            require(Path(relative).name == relative, "unexpected nested export artifact")
            path = folder / relative
            require(path.is_file() and digest(path) == record["sha256"], f"export file hash mismatch: {path}")
        packs.add(exported["delivered_pack"]["sha256"])
        if platform != "macOS":
            require(digest(folder / "TakeStack.pck") == exported["delivered_pack"]["sha256"], "delivered pack mismatch")
    require(len(packs) == 1, "platforms do not share the audited PCK")
    with zipfile.ZipFile(audit_dir / "artifacts/macos/TakeStack-macos.zip") as archive:
        names = [name for name in archive.namelist() if name.endswith(".pck")]
        require(len(names) == 1, "macOS package must contain one audited PCK")
        with archive.open(names[0]) as source:
            require(hashlib.file_digest(source, "sha256").hexdigest() in packs, "macOS delivered PCK mismatch")
    require(audit.get("macos_signature", {}).get("valid") is True, "macOS signature audit missing")
    smoke = audit.get("macos_smoke", {})
    require(smoke.get("preview_player_files_unchanged") is True, "macOS save-isolation smoke missing")


def validate_native(evidence: Path, commit: str) -> dict:
    variants = {}
    for variant, canvas, language in (("normal", [1280, 720], "en"), ("compact", [960, 540], "zh"),
                                      ("reduced", [1280, 720], "en")):
        folder = evidence / variant
        source = read_json(folder / "paper_action_source.json")
        require(source.get("success") is True and source.get("commit") == commit, f"{variant} native source mismatch/failure")
        require(source.get("source") == "scripted fixture", "native evidence must disclose fixture scope")
        require(source.get("canvas") == canvas and source.get("language") == language, "native dimensions/language mismatch")
        require(source.get("capture", {}).get("fps") == 60 and source["capture"].get("speed") == 1.0,
                "native capture must retain normal playback speed")
        cases = source.get("cases", [])
        case_names = {case["name"] for case in cases}
        require(len(cases) == len(case_names) == 12, "native evidence must complete twelve unique cases")
        proofs = source.get("read_only_checks", [])
        require(len(proofs) == 12 and {proof.get("case") for proof in proofs} == case_names,
                "native evidence must prove every case read-only")
        proof_keys = ("full_snapshot_unchanged", "rng_unchanged", "hazard_rng_unchanged",
                      "strict_snapshot_roundtrip", "native_process_and_draw")
        require(all(all(proof.get(key) is True for key in proof_keys) and proof.get("manual_view_delta") == 0.0
                    for proof in proofs), "native snapshot/RNG/process proof failed")
        screenshots = source.get("screenshots", {})
        declared = {row["file"] for row in screenshots.values()}
        actual = {path.name for path in folder.glob("*.png")}
        require(len(actual) == 56 and actual == declared, "native screenshot inventory mismatch")
        require(all(Path(name).name == name for name in declared), "unsafe screenshot filename")
        movie = folder / "paper_action.mp4"
        require(movie.is_file() and movie.stat().st_size > 0, "native movie missing")
        streams = read_json(folder / "video.json")["streams"]
        videos = [stream for stream in streams if stream["codec_type"] == "video"]
        require(len(videos) == 1 and not any(s["codec_type"] == "audio" for s in streams), "movie must contain one silent video")
        require([videos[0]["width"], videos[0]["height"]] == canvas and Fraction(videos[0]["avg_frame_rate"]) == 60,
                "encoded movie changed native dimensions or playback speed")
        variants[variant] = {"commit": commit, "source": source["source"], "canvas": canvas, "language": language,
                             "cases": len(source["cases"]), "png_count": len(actual), "movie_sha256": digest(movie),
                             "source_sha256": digest(folder / "paper_action_source.json"), "fps": 60, "speed": 1.0}
    return variants


def validate_performance(evidence: Path, commit: str, probe_hash: str) -> dict:
    current = read_json(evidence / "pressure-current/presentation_stress_summary.json")
    baseline = read_json(evidence / "pressure-baseline/presentation_stress_summary.json")
    require(current.get("game_commit") == commit, "pressure candidate source mismatch")
    baseline_commit = (evidence / "pressure-baseline/source_commit.txt").read_text().strip()
    require(baseline.get("game_commit") == baseline_commit and baseline_commit != commit, "pressure baseline source mismatch")
    require(current.get("probe_sha256") == baseline.get("probe_sha256") == probe_hash, "pressure harness differs between versions")
    require(bool(current.get("cases")) and bool(baseline.get("cases")), "pressure cases missing")
    require([c["name"] for c in current["cases"]] == [c["name"] for c in baseline["cases"]], "pressure case mismatch")
    return {"scope": "same-run Linux software rendering fixture; not universal FPS or human playtesting",
            "candidate": current, "baseline": baseline}


def validate_save_compat(evidence: Path, commit: str, version: str, baseline_commit: str, probe_hash: str) -> dict:
    result = read_json(evidence / "save-compat/result.json")
    writer = read_json(evidence / "save-compat/writer-result.json")
    require(result.get("success") is True and writer.get("success") is True, "cross-version save compatibility failed")
    require(result.get("source_version") == writer.get("source_version") == "0.17.0" and result.get("reader_version") == version,
            "save compatibility versions mismatch")
    require(result.get("source_game_commit") == writer.get("game_commit") == baseline_commit
            and result.get("reader_game_commit") == commit, "save compatibility source SHA mismatch")
    require(result.get("probe_sha256") == writer.get("probe_sha256") == probe_hash, "save compatibility harness mismatch")
    require(result.get("schema") == writer.get("schema") == 4 and set(result.get("scenarios", [])) == {"wave", "shop"},
            "save compatibility must cover current wave/shop schema")
    require(len(result.get("details", [])) == 2 and all(all(row.get(key) is True for key in
            ("full_snapshot_equal", "rng_preserved", "hazard_rng_preserved", "resumed")) for row in result["details"]),
            "save snapshots did not resume with exact state and both RNGs")
    return result


def write_checksums(output: Path) -> None:
    files = sorted(path for path in output.iterdir() if path.is_file() and path.name != "SHA256SUMS.txt")
    (output / "SHA256SUMS.txt").write_text("".join(f"{digest(path)}  {path.name}\n" for path in files), encoding="utf-8")


def verify_files(output: Path) -> dict:
    require(PACKAGES <= {path.name for path in output.iterdir() if path.is_file()}, "release platform package missing")
    entries = {}
    for row in (output / "SHA256SUMS.txt").read_text().splitlines():
        expected, name = row.split("  ", 1)
        require(Path(name).name == name and name not in entries and re.fullmatch(r"[0-9a-f]{64}", expected) is not None,
                "invalid or duplicate checksum entry")
        require((output / name).is_file() and digest(output / name) == expected, f"release asset hash mismatch: {name}")
        entries[name] = expected
    actual = {path.name for path in output.iterdir() if path.is_file()}
    require(actual == set(entries) | {"SHA256SUMS.txt"}, "release asset set differs from checksums")
    entries["SHA256SUMS.txt"] = digest(output / "SHA256SUMS.txt")
    return entries


def validate_packaged(output: Path, audit_dir: Path) -> None:
    """Final downloadable ZIP payloads must be the exports just audited by this run."""
    artifacts = audit_dir / "artifacts"
    require(digest(output / "TakeStack-macos.zip") == digest(artifacts / "macos/TakeStack-macos.zip"),
            "packaged macOS ZIP differs from the audited package")
    for platform, binary in (("windows", "TakeStack.exe"), ("linux", "TakeStack.x86_64")):
        with zipfile.ZipFile(output / f"TakeStack-{platform}.zip") as archive:
            require(len(archive.namelist()) == 2 and set(archive.namelist()) == {binary, "TakeStack.pck"},
                    "packaged ZIP contains unexpected files")
            for name in (binary, "TakeStack.pck"):
                with archive.open(name) as source:
                    require(hashlib.file_digest(source, "sha256").hexdigest() == digest(artifacts / platform / name),
                            f"packaged payload differs from the audited export: {platform}/{name}")
            if platform == "linux":
                require((archive.getinfo(binary).external_attr >> 16) & 0o777 == 0o755,
                        "packaged Linux binary lost its executable permissions")


def prepare(args: argparse.Namespace) -> None:
    version = project_version(args.repo)
    audit = read_json(args.audit_dir / "result.json")
    validate_identity(version, args.commit, args.ref, audit, build_info(args.out / "BUILD_INFO.txt"))
    validate_exports(args.audit_dir, audit)
    validate_packaged(args.out, args.audit_dir)
    gates = read_json(args.needs)
    require(set(gates) == GATES and all(gates[name]["result"] == "success" for name in GATES), "release CI gate failed/missing")
    require(args.run_id.isdigit() and args.run_attempt.isdigit() and re.fullmatch(r"[\w.-]+/[\w.-]+", args.repository), "invalid CI run identity")
    variants = validate_native(args.evidence_dir, args.commit)
    perf = validate_performance(args.evidence_dir, args.commit, digest(args.repo / "tools/presentation_stress_probe.gd"))
    compat = validate_save_compat(args.evidence_dir, args.commit, version, perf["baseline"]["game_commit"],
                                  digest(args.repo / "tools/release_save_compat.gd"))
    run = {"repository": args.repository, "run_id": int(args.run_id), "run_attempt": int(args.run_attempt),
           "url": f"https://github.com/{args.repository}/actions/runs/{args.run_id}/attempts/{args.run_attempt}",
           "source_commit": args.commit, "ref": args.ref, "version": version}
    verification = {"ci": run, "gates": {key: gates[key]["result"] for key in sorted(GATES)},
                    "native": variants, "save_compatibility": compat, "scope": "automated fixtures and export startup checks; not human playtesting"}
    for name, value in (("AUDIT.json", audit), ("VERIFICATION.json", verification), ("PERFORMANCE.json", {"ci": run, **perf})):
        (args.out / name).write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    shutil.copyfile(args.evidence_dir / "normal/paper_action.mp4", args.out / "TakeStack-Paper-Actions-Demo.mp4")
    with zipfile.ZipFile(args.out / "NATIVE_EVIDENCE.zip", "w", compression=zipfile.ZIP_STORED) as archive:
        for path in sorted(args.evidence_dir.rglob("*")):
            relative = path.relative_to(args.evidence_dir)
            if path.is_file() and "userdata" not in relative.parts and path.suffix in {".png", ".mp4", ".json", ".txt"}:
                archive.write(path, relative.as_posix())
    write_checksums(args.out)
    verify_files(args.out)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["prepare", "verify"])
    for name in ("repo", "audit-dir", "evidence-dir", "out", "needs", "expected"):
        parser.add_argument(f"--{name}", type=Path)
    for name in ("commit", "ref", "run-id", "run-attempt", "repository", "version"):
        parser.add_argument(f"--{name}")
    args = parser.parse_args()
    if args.mode == "prepare":
        prepare(args)
    else:
        values = verify_files(args.out)
        validate_identity(args.version, args.commit, args.ref, read_json(args.out / "AUDIT.json"), build_info(args.out / "BUILD_INFO.txt"))
        ci = read_json(args.out / "VERIFICATION.json")["ci"]
        require(ci["source_commit"] == args.commit, "verification source mismatch")
        if args.expected:
            require(values == verify_files(args.expected), "downloaded release bytes differ from the current-run artifact")
        print(json.dumps({"ci": ci, "source_commit": args.commit, "ref": args.ref,
                          "draft_download_verified": bool(args.expected), "verified_assets": values}, indent=2))


if __name__ == "__main__":
    main()
