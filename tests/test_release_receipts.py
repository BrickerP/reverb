"""Release identity/inventory contracts; no Godot process or real package needed."""
from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
import shutil
import stat
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("release_receipts", ROOT / "tools/release_receipts.py")
RECEIPTS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RECEIPTS)

COMMIT = "a" * 40
BASELINE = "b" * 40
VERSION = "0.18.0"
REF = "refs/tags/v0.18.0"
CASE_NAMES = ("pin", "stamp", "cut", "ink", "return", "arc", "repair", "machine", "retirement", "shield", "duplicate", "gait")
INVARIANTS = ("full_snapshot_unchanged", "rng_unchanged", "hazard_rng_unchanged", "strict_snapshot_roundtrip", "native_process_and_draw")


def put_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value), encoding="utf-8")


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def make_zip(path: Path, files: dict[str, tuple[bytes, int]]) -> None:
    with zipfile.ZipFile(path, "w") as archive:
        for name, (data, mode) in files.items():
            entry = zipfile.ZipInfo(name)
            entry.external_attr = (stat.S_IFREG | mode) << 16
            archive.writestr(entry, data)


class ReleaseReceiptTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.repo = self.root / "repo"
        (self.repo / "tools").mkdir(parents=True)
        (self.repo / "project.godot").write_text('config/version="0.18.0"\n')
        (self.repo / "tools/presentation_stress_probe.gd").write_bytes(b"one pressure probe")
        (self.repo / "tools/release_save_compat.gd").write_bytes(b"one compatibility probe")
        self.pressure_hash = RECEIPTS.digest(self.repo / "tools/presentation_stress_probe.gd")
        self.compat_hash = RECEIPTS.digest(self.repo / "tools/release_save_compat.gd")
        self.audit_dir = self.root / "audit"
        self.out = self.root / "packages"
        self.out.mkdir()
        self.pack = b"audited platform-independent resource pack fixture"
        self.binaries = {"windows": b"audited PE fixture", "linux": b"audited ELF fixture"}
        self.audit = {"commit": COMMIT, "overlay": {"build_commit": COMMIT, "custom_user_dir_name": "TakeStack Preview"},
                      "exports": {}, "macos_signature": {"valid": True},
                      "macos_smoke": {"preview_player_files_unchanged": True}}
        for platform in ("macOS", "Windows", "Linux"):
            folder = self.audit_dir / "artifacts" / platform.lower()
            folder.mkdir(parents=True)
            if platform == "macOS":
                make_zip(folder / "TakeStack-macos.zip", {"Take Stack.app/Contents/Resources/Take Stack.pck": (self.pack, 0o644)})
            else:
                executable = "TakeStack.exe" if platform == "Windows" else "TakeStack.x86_64"
                (folder / executable).write_bytes(self.binaries[platform.lower()])
                (folder / "TakeStack.pck").write_bytes(self.pack)
            self.audit["exports"][platform] = {
                "audit": {"ok": True, "failures": [], "forbidden_hits": []},
                "delivered_pack": {"sha256": sha(self.pack)},
                "package_files": [{"relative_path": p.name, "sha256": RECEIPTS.digest(p)} for p in sorted(folder.iterdir())],
            }
        shutil.copyfile(self.audit_dir / "artifacts/macos/TakeStack-macos.zip", self.out / "TakeStack-macos.zip")
        make_zip(self.out / "TakeStack-windows.zip", {"TakeStack.exe": (self.binaries["windows"], 0o644), "TakeStack.pck": (self.pack, 0o644)})
        make_zip(self.out / "TakeStack-linux.zip", {"TakeStack.x86_64": (self.binaries["linux"], 0o755), "TakeStack.pck": (self.pack, 0o644)})
        put_json(self.audit_dir / "result.json", self.audit)
        self.info = {"version": VERSION, "commit": COMMIT, "godot": "4.7.2.stable.official.ed1daf0bf", "release_status": "public-release"}
        (self.out / "BUILD_INFO.txt").write_text("".join(f"{key}={value}\n" for key, value in self.info.items()))
        self.evidence = self.root / "evidence"
        for variant, canvas, language in (("normal", [1280, 720], "en"), ("compact", [960, 540], "zh"), ("reduced", [1280, 720], "en")):
            folder = self.evidence / variant
            folder.mkdir(parents=True)
            screenshots = {}
            for index in range(56):
                name = f"sample-{index:02}.png"
                (folder / name).write_bytes(b"PNG inventory placeholder")
                screenshots[f"{CASE_NAMES[index % 12]}/{index}"] = {"file": name, "width": canvas[0], "height": canvas[1], "case_frame": index, "native_frame": index + 1}
            source = {"success": True, "commit": COMMIT, "source": "scripted fixture", "canvas": canvas, "language": language,
                      "capture": {"fps": 60, "speed": 1.0, "startup_config_pixels": canvas},
                      "cases": [{"name": name} for name in CASE_NAMES], "screenshots": screenshots,
                      "read_only_checks": [{"case": name, "frame": 30, "manual_view_delta": 0.0, **dict.fromkeys(INVARIANTS, True)} for name in CASE_NAMES],
                      "teardown": {"main_freed": True, "simulation_detached": True, "native_frames_waited": 2}}
            put_json(folder / "paper_action_source.json", source)
            (folder / "paper_action.mp4").write_bytes(b"encoded movie inventory placeholder")
            put_json(folder / "video.json", {"streams": [{"codec_type": "video", "width": canvas[0], "height": canvas[1], "avg_frame_rate": "60/1"}]})
        for side, commit in (("current", COMMIT), ("baseline", BASELINE)):
            put_json(self.evidence / f"pressure-{side}/presentation_stress_summary.json", {
                "game_commit": commit, "probe_sha256": self.pressure_hash,
                "cases": [{"name": name, "frame_avg_ms": 30.0} for name in ("96_legal_8echo_12support_standard", "96_legal_8echo_12support_reduced")],
            })
        (self.evidence / "pressure-baseline/source_commit.txt").write_text(BASELINE + "\n")
        self.compat = {"success": True, "source_version": "0.17.0", "reader_version": VERSION,
                       "source_game_commit": BASELINE, "reader_game_commit": COMMIT, "probe_sha256": self.compat_hash,
                       "schema": 4, "scenarios": ["wave", "shop"],
                       "details": [{"scenario": name, **dict.fromkeys(("full_snapshot_equal", "rng_preserved", "hazard_rng_preserved", "resumed"), True)} for name in ("wave", "shop")]}
        self.writer = {"success": True, "source_version": "0.17.0", "game_commit": BASELINE, "probe_sha256": self.compat_hash, "schema": 4}
        put_json(self.evidence / "save-compat/result.json", self.compat)
        put_json(self.evidence / "save-compat/writer-result.json", self.writer)
        self.needs = self.root / "needs.json"
        self.gates = {name: {"result": "success"} for name in RECEIPTS.GATES}
        put_json(self.needs, self.gates)
        self.args = argparse.Namespace(repo=self.repo, audit_dir=self.audit_dir, evidence_dir=self.evidence,
                                       out=self.out, needs=self.needs, commit=COMMIT, ref=REF,
                                       run_id="12345", run_attempt="2", repository="BrickerP/reverb")

    def test_identity_binds_version_tag_full_sha_and_public_directory(self) -> None:
        RECEIPTS.validate_identity(VERSION, COMMIT, REF, self.audit, self.info)
        cases = [("version", "0.17.0"), ("commit", "abc123"), ("ref", "refs/tags/v0.17.0")]
        for field, value in cases:
            with self.subTest(field=field), self.assertRaises(ValueError):
                values = {"version": VERSION, "commit": COMMIT, "ref": REF}
                values[field] = value
                RECEIPTS.validate_identity(**values, audit=self.audit, info=self.info)
        for field, value in (("version", "0.17.0"), ("commit", BASELINE), ("release_status", "preview-candidate")):
            bad = {**self.info, field: value}
            with self.subTest(info=field), self.assertRaises(ValueError):
                RECEIPTS.validate_identity(VERSION, COMMIT, REF, self.audit, bad)
        for field, value in (("build_commit", BASELINE), ("custom_user_dir_name", "Take Stack")):
            bad = copy.deepcopy(self.audit)
            bad["overlay"][field] = value
            with self.subTest(overlay=field), self.assertRaises(ValueError):
                RECEIPTS.validate_identity(VERSION, COMMIT, REF, bad, self.info)

    def test_export_inventory_rejects_missing_and_tampered_raw_payload(self) -> None:
        RECEIPTS.validate_exports(self.audit_dir, self.audit)
        path = self.audit_dir / "artifacts/windows/TakeStack.exe"
        original = path.read_bytes()
        path.write_bytes(b"stale executable")
        with self.assertRaises(ValueError):
            RECEIPTS.validate_exports(self.audit_dir, self.audit)
        path.write_bytes(original)
        path.unlink()
        with self.assertRaises(ValueError):
            RECEIPTS.validate_exports(self.audit_dir, self.audit)

    def test_native_validates_three_actual_scopes_and_pixel_dimensions(self) -> None:
        valid = RECEIPTS.validate_native(self.evidence, COMMIT)
        self.assertEqual(set(valid), {"normal", "compact", "reduced"})
        self.assertEqual(valid["compact"]["canvas"], [960, 540])
        self.assertEqual(valid["compact"]["language"], "zh")
        self.assertTrue(all(v["cases"] == 12 and v["png_count"] == 56 for v in valid.values()))

    def test_native_rejects_wrong_identity_disclosure_language_or_capture_time(self) -> None:
        path = self.evidence / "compact/paper_action_source.json"
        original = RECEIPTS.read_json(path)
        for field, value in (("commit", BASELINE), ("success", False), ("source", "human playthrough"),
                             ("language", "en"), ("canvas", [1280, 720])):
            put_json(path, {**original, field: value})
            with self.subTest(field=field), self.assertRaises(ValueError):
                RECEIPTS.validate_native(self.evidence, COMMIT)
        for field, value in (("fps", 30), ("speed", 0.5)):
            bad = copy.deepcopy(original)
            bad["capture"][field] = value
            put_json(path, bad)
            with self.subTest(capture=field), self.assertRaises(ValueError):
                RECEIPTS.validate_native(self.evidence, COMMIT)

    def test_native_rejects_partial_case_and_read_only_evidence(self) -> None:
        path = self.evidence / "normal/paper_action_source.json"
        original = RECEIPTS.read_json(path)
        mutations = []
        bad = copy.deepcopy(original)
        bad["cases"].pop()
        mutations.append(bad)
        bad = copy.deepcopy(original)
        bad["cases"][-1] = bad["cases"][0]
        mutations.append(bad)
        bad = copy.deepcopy(original)
        bad["read_only_checks"].pop()
        mutations.append(bad)
        for field in INVARIANTS + ("manual_view_delta",):
            bad = copy.deepcopy(original)
            bad["read_only_checks"][0][field] = 0.1 if field == "manual_view_delta" else False
            mutations.append(bad)
        for index, bad in enumerate(mutations):
            put_json(path, bad)
            with self.subTest(mutation=index), self.assertRaises(ValueError):
                RECEIPTS.validate_native(self.evidence, COMMIT)

    def test_native_rejects_missing_png_and_movie_frame_or_audio_distortion(self) -> None:
        path = self.evidence / "normal/video.json"
        original = RECEIPTS.read_json(path)
        for field, value in (("width", 960), ("avg_frame_rate", "30/1")):
            bad = copy.deepcopy(original)
            bad["streams"][0][field] = value
            put_json(path, bad)
            with self.subTest(field=field), self.assertRaises(ValueError):
                RECEIPTS.validate_native(self.evidence, COMMIT)
        put_json(path, {"streams": original["streams"] + [{"codec_type": "audio"}]})
        with self.assertRaises(ValueError):
            RECEIPTS.validate_native(self.evidence, COMMIT)
        put_json(path, original)
        (self.evidence / "normal/sample-00.png").unlink()
        with self.assertRaises(ValueError):
            RECEIPTS.validate_native(self.evidence, COMMIT)

    def test_performance_requires_same_probe_and_explicit_old_source(self) -> None:
        RECEIPTS.validate_performance(self.evidence, COMMIT, self.pressure_hash)
        path = self.evidence / "pressure-baseline/presentation_stress_summary.json"
        original = RECEIPTS.read_json(path)
        for field, value in (("game_commit", COMMIT), ("probe_sha256", "c" * 64), ("cases", [])):
            put_json(path, {**original, field: value})
            with self.subTest(field=field), self.assertRaises(ValueError):
                RECEIPTS.validate_performance(self.evidence, COMMIT, self.pressure_hash)

    def test_save_compatibility_requires_017_writer_018_reader_and_exact_resumption(self) -> None:
        RECEIPTS.validate_save_compat(self.evidence, COMMIT, VERSION, BASELINE, self.compat_hash)
        for field, value in (("success", False), ("source_version", "0.16.0"), ("reader_version", "0.17.0"),
                             ("source_game_commit", COMMIT), ("reader_game_commit", BASELINE),
                             ("probe_sha256", "c" * 64), ("schema", 3), ("scenarios", ["wave"])):
            put_json(self.evidence / "save-compat/result.json", {**self.compat, field: value})
            with self.subTest(field=field), self.assertRaises(ValueError):
                RECEIPTS.validate_save_compat(self.evidence, COMMIT, VERSION, BASELINE, self.compat_hash)
        for field in ("full_snapshot_equal", "rng_preserved", "hazard_rng_preserved", "resumed"):
            bad = copy.deepcopy(self.compat)
            bad["details"][0][field] = False
            put_json(self.evidence / "save-compat/result.json", bad)
            with self.subTest(detail=field), self.assertRaises(ValueError):
                RECEIPTS.validate_save_compat(self.evidence, COMMIT, VERSION, BASELINE, self.compat_hash)
        put_json(self.evidence / "save-compat/result.json", self.compat)
        put_json(self.evidence / "save-compat/writer-result.json", {**self.writer, "game_commit": COMMIT})
        with self.assertRaises(ValueError):
            RECEIPTS.validate_save_compat(self.evidence, COMMIT, VERSION, BASELINE, self.compat_hash)

    def test_prepare_binds_same_run_gate_identity_and_generates_verifiable_receipts(self) -> None:
        RECEIPTS.prepare(self.args)
        verified = RECEIPTS.verify_files(self.out)
        self.assertTrue(RECEIPTS.PACKAGES <= set(verified))
        self.assertTrue({"AUDIT.json", "VERIFICATION.json", "PERFORMANCE.json", "NATIVE_EVIDENCE.zip"} <= set(verified))
        result = RECEIPTS.read_json(self.out / "VERIFICATION.json")
        self.assertEqual(result["ci"]["source_commit"], COMMIT)
        self.assertEqual(result["ci"]["run_id"], 12345)
        self.assertEqual(result["ci"]["run_attempt"], 2)
        self.assertEqual(result["ci"]["ref"], REF)

    def test_prepare_refuses_failed_or_missing_current_run_gates_and_invalid_run_identity(self) -> None:
        for result in ("failure", "cancelled", "skipped"):
            bad = copy.deepcopy(self.gates)
            bad["paper-feedback"]["result"] = result
            put_json(self.needs, bad)
            with self.subTest(result=result), self.assertRaises(ValueError):
                RECEIPTS.prepare(self.args)
        bad = copy.deepcopy(self.gates)
        bad.pop("export-preview")
        put_json(self.needs, bad)
        with self.assertRaises(ValueError):
            RECEIPTS.prepare(self.args)
        put_json(self.needs, self.gates)
        for field, value in (("run_id", "not-a-run"), ("run_attempt", "wrong"), ("repository", "not-a-repo")):
            args = copy.copy(self.args)
            setattr(args, field, value)
            with self.subTest(field=field), self.assertRaises(ValueError):
                RECEIPTS.prepare(args)

    def test_prepare_rejects_relabelled_old_final_payload_even_if_build_info_is_current(self) -> None:
        path = self.out / "TakeStack-windows.zip"
        make_zip(path, {"TakeStack.exe": (b"old public executable", 0o644), "TakeStack.pck": (self.pack, 0o644)})
        with self.assertRaises(ValueError):
            RECEIPTS.prepare(self.args)

    def test_prepare_rejects_linux_zip_that_loses_execution_permission(self) -> None:
        make_zip(self.out / "TakeStack-linux.zip", {"TakeStack.x86_64": (self.binaries["linux"], 0o644), "TakeStack.pck": (self.pack, 0o644)})
        with self.assertRaises(ValueError):
            RECEIPTS.prepare(self.args)

    def test_checksums_reject_missing_tampered_or_unlisted_files(self) -> None:
        RECEIPTS.write_checksums(self.out)
        self.assertTrue(RECEIPTS.PACKAGES <= set(RECEIPTS.verify_files(self.out)))
        path = self.out / "TakeStack-windows.zip"
        original = path.read_bytes()
        path.write_bytes(b"tampered download")
        with self.assertRaises(ValueError):
            RECEIPTS.verify_files(self.out)
        path.write_bytes(original)
        extra = self.out / "unlisted.txt"
        extra.write_text("not in the uploaded inventory")
        with self.assertRaises(ValueError):
            RECEIPTS.verify_files(self.out)
        extra.unlink()
        path.unlink()
        with self.assertRaises(ValueError):
            RECEIPTS.verify_files(self.out)

    def test_required_package_name_cannot_be_a_directory(self) -> None:
        path = self.out / "TakeStack-macos.zip"
        path.unlink()
        path.mkdir()
        RECEIPTS.write_checksums(self.out)
        with self.assertRaises(ValueError):
            RECEIPTS.verify_files(self.out)

    def test_checksum_manifest_rejects_duplicate_entries_and_path_escape(self) -> None:
        RECEIPTS.write_checksums(self.out)
        path = self.out / "SHA256SUMS.txt"
        original = path.read_text()
        first = original.splitlines()[0]
        path.write_text(original + first + "\n")
        with self.assertRaises(ValueError):
            RECEIPTS.verify_files(self.out)
        path.write_text(original + f"{'c' * 64}  ../escaped.zip\n")
        with self.assertRaises(ValueError):
            RECEIPTS.verify_files(self.out)


if __name__ == "__main__":
    unittest.main()
