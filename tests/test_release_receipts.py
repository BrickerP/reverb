"""Release identity/inventory contracts; no Godot process or real package needed."""
from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
import re
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
OLD_WRITER = "d" * 40
VERSION = "0.18.1"
REF = "refs/tags/v0.18.1"
CASE_NAMES = tuple(RECEIPTS.NATIVE_CASE_LABELS)
INVARIANTS = RECEIPTS.NATIVE_INVARIANTS


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
        (self.repo / "project.godot").write_text(f'config/version="{VERSION}"\n')
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
            cases = []
            for index, (name, labels) in enumerate(RECEIPTS.NATIVE_CASE_LABELS.items()):
                samples = {}
                for offset, label in enumerate(labels):
                    filename = f"{name}_{label}.png"
                    (folder / filename).write_bytes(b"PNG inventory placeholder")
                    frame = RECEIPTS.NATIVE_SAMPLE_FRAMES.get(name, {}).get(label, offset)
                    if name == "echo_machine":
                        frame = 12 + dict(zip(labels, (0, 4, 16, 78)))[label]
                    row = {"file": filename, "width": canvas[0], "height": canvas[1],
                           "case_frame": frame, "native_frame": index * 200 + frame + 1}
                    screenshots[f"{name}/{label}"] = row
                    samples[label] = row
                cases.append({"name": name, "first_action_frame": 12, "screenshots": samples,
                              "view_proofs": dict.fromkeys(("skill_body", "skill_settled", "echo_uid", "echo_grip",
                                                            "rescue_departure", "rescue_safe_visible", "rescue_receipt_expired"), True)})
            proof_frames = [(name, 30) for name in CASE_NAMES] + [("skill_looper", 86), ("echo_machine", 28)]
            source = {"success": True, "commit": COMMIT, "source": "scripted fixture", "canvas": canvas, "language": language,
                      "capture": {"fps": 60, "speed": 1.0, "startup_config_pixels": canvas},
                      "cases": cases, "screenshots": screenshots, "scene_count": len(cases), "png_count": len(screenshots),
                      "read_only_checks": [{"case": name, "frame": frame, "manual_view_delta": 0.0,
                                            **dict.fromkeys(INVARIANTS, True)} for name, frame in proof_frames],
                      "teardown": {"main_freed": True, "simulation_detached": True, "native_frames_waited": 2}}
            put_json(folder / "paper_action_source.json", source)
            (folder / "paper_action.mp4").write_bytes(b"encoded movie inventory placeholder")
            put_json(folder / "video.json", {"streams": [{"codec_type": "video", "width": canvas[0], "height": canvas[1], "avg_frame_rate": "60/1"}]})
        for side, commit in (("current", COMMIT), ("baseline", BASELINE)):
            put_json(self.evidence / f"pressure-{side}/presentation_stress_summary.json", {
                "game_commit": commit, "probe_sha256": self.pressure_hash,
                "cases": [{"name": name, "frame_avg_ms": 30.0} for name in RECEIPTS.PRESSURE_CASES],
            })
        put_json(self.evidence / "pressure-baseline/source.json", {"tag": "v0.18.0", "version": "0.18.0", "game_commit": BASELINE})
        self.compats, self.writers, self.payloads = {}, {}, {}
        for source_version, source_commit in (("0.17.0", OLD_WRITER), ("0.18.0", BASELINE)):
            folder = self.evidence / "save-compat" / source_version
            put_json(folder / "source.json", {"tag": f"v{source_version}", "version": source_version, "game_commit": source_commit})
            snapshots, details = [], []
            for name in ("shop", "wave"):
                encoded = json.dumps({"version": 4, "fixture": f"{source_version}-{name}"})
                snapshot = {"name": name, "snapshot_json": encoded, "snapshot_sha256": sha(encoded.encode()),
                            "rng_seed": "11", "rng_state": "22", "hazard_rng_seed": "33", "hazard_rng_state": "44",
                            "state": {"wave": 2, "phase": 1}}
                snapshots.append(snapshot)
                for side in ("old", "captured"):
                    (folder / f"{name}-{side}-snapshot.json").write_bytes(encoded.encode())
                details.append({"name": name, "snapshot_sha256": snapshot["snapshot_sha256"], "source_state": snapshot["state"],
                                "resumed_action": "undo" if name == "shop" else "step",
                                **dict.fromkeys(("full_snapshot_equal", "graph_json_domain_equal", "canonical_json_bytes_equal",
                                                 "canonical_snapshot_sha256_equal", "state_json_domain_equal",
                                                 "rng_preserved", "hazard_rng_preserved", "resumed"), True)})
            payload = {"source_version": source_version, "game_commit": source_commit, "probe_sha256": self.compat_hash,
                       "schema": 4, "scenarios": snapshots}
            put_json(folder / "compat-payload.json", payload)
            payload_hash = RECEIPTS.digest(folder / "compat-payload.json")
            compat = {"success": True, "source_version": source_version, "reader_version": VERSION,
                      "source_game_commit": source_commit, "reader_game_commit": COMMIT, "probe_sha256": self.compat_hash,
                      "payload_sha256": payload_hash, "schema": 4, "scenarios": ["wave", "shop"], "details": details}
            writer = {"success": True, "source_version": source_version, "game_commit": source_commit,
                      "probe_sha256": self.compat_hash, "payload_sha256": payload_hash, "schema": 4, "scenarios": ["shop", "wave"]}
            self.compats[source_version], self.writers[source_version], self.payloads[source_version] = compat, writer, payload
            put_json(folder / "result.json", compat)
            put_json(folder / "writer-result.json", writer)
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

    def test_native_case_contract_matches_the_actual_probe(self) -> None:
        probe = (ROOT / "tools/paper_action_probe.gd").read_text()
        # Read actual literal calls plus the two finite loops that expand cases;
        # deriving fixtures from the gate alone cannot detect an incorrect name.
        literal_cases = re.findall(r'_run_case\("([^"\n]+)",', probe)
        weapon_block = re.search(r'const WEAPONS:.*?= \[(.*?)\n\]', probe, re.S).group(1)
        weapon_cases = re.findall(r'"name": "([^"\n]+)"', weapon_block)
        role_block = re.search(r'for role: StringName in \[(.*?)\]:', probe).group(1)
        role_cases = [f"skill_{role}" for role in re.findall(r'&"([^"\n]+)"', role_block)]
        actual = literal_cases + weapon_cases + role_cases
        self.assertEqual(len(actual), len(set(actual)))
        self.assertEqual(set(CASE_NAMES), set(actual))
        self.assertIn("duplicate_slots", actual)

    def test_native_validates_three_actual_scopes_and_pixel_dimensions(self) -> None:
        valid = RECEIPTS.validate_native(self.evidence, COMMIT)
        self.assertEqual(set(valid), {"normal", "compact", "reduced"})
        self.assertEqual(valid["compact"]["canvas"], [960, 540])
        self.assertEqual(valid["compact"]["language"], "zh")
        self.assertEqual(len(CASE_NAMES), 20)
        self.assertTrue(all(v["cases"] == 20 and v["png_count"] == 95 for v in valid.values()))
        self.assertTrue({"echo_machine", "rescue", *(f"skill_{role}" for role in ("solo", "looper", "mirror", "conductor", "mender", "overloader"))} <= set(CASE_NAMES))

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

    def test_native_rejects_unlisted_case_phase_missing_active_proofs_and_new_view_failures(self) -> None:
        path = self.evidence / "normal/paper_action_source.json"
        original = RECEIPTS.read_json(path)
        mutations = []
        bad = copy.deepcopy(original)
        bad["cases"][-1]["name"] = "unlisted_case"
        mutations.append(bad)
        bad = copy.deepcopy(original)
        bad["screenshots"]["rescue/unknown"] = bad["screenshots"].pop("rescue/safe")
        mutations.append(bad)
        bad = copy.deepcopy(original)
        bad["read_only_checks"] = [proof for proof in bad["read_only_checks"] if proof["frame"] == 30]
        mutations.append(bad)
        for case_name, field in (("skill_looper", "skill_body"), ("echo_machine", "echo_grip"), ("rescue", "rescue_safe_visible")):
            bad = copy.deepcopy(original)
            next(case for case in bad["cases"] if case["name"] == case_name)["view_proofs"][field] = False
            mutations.append(bad)
        for key, field, value in (("rescue/safe", "case_frame", 20), ("skill_looper/contact", "case_frame", 30),
                                  ("echo_machine/grip", "case_frame", 12), ("pin/release", "width", 960)):
            bad = copy.deepcopy(original)
            bad["screenshots"][key][field] = value
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
        (self.evidence / "normal/pin_release.png").unlink()
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
        put_json(path, original)
        path = self.evidence / "pressure-baseline/source.json"
        source = RECEIPTS.read_json(path)
        for field, value in (("version", "0.17.0"), ("tag", "v0.17.0"), ("game_commit", OLD_WRITER), ("game_commit", "short")):
            put_json(path, {**source, field: value})
            with self.subTest(source=field, value=value), self.assertRaises(ValueError):
                RECEIPTS.validate_performance(self.evidence, COMMIT, self.pressure_hash)

    def test_save_compatibility_requires_both_actual_public_writers_and_current_reader(self) -> None:
        valid = RECEIPTS.validate_save_compat(self.evidence, COMMIT, VERSION, self.compat_hash)
        self.assertEqual(set(valid), {"0.17.0", "0.18.0"})
        self.assertEqual(valid["0.17.0"]["source_game_commit"], OLD_WRITER)
        self.assertEqual(valid["0.18.0"]["source_game_commit"], BASELINE)
        for source_version, original in self.compats.items():
            path = self.evidence / "save-compat" / source_version / "result.json"
            for field, value in (("success", False), ("source_version", "0.16.0"), ("reader_version", "0.18.0"),
                                 ("source_game_commit", COMMIT), ("reader_game_commit", BASELINE),
                                 ("probe_sha256", "c" * 64), ("payload_sha256", "c" * 64),
                                 ("schema", 3), ("scenarios", ["wave"]), ("scenarios", ["wave", "wave"])):
                put_json(path, {**original, field: value})
                with self.subTest(version=source_version, field=field, value=value), self.assertRaises(ValueError):
                    RECEIPTS.validate_save_compat(self.evidence, COMMIT, VERSION, self.compat_hash)
            put_json(path, original)

    def test_save_compatibility_requires_exact_bytes_state_both_rngs_and_actual_action(self) -> None:
        for source_version, original in self.compats.items():
            folder = self.evidence / "save-compat" / source_version
            for field in ("full_snapshot_equal", "graph_json_domain_equal", "canonical_json_bytes_equal",
                          "canonical_snapshot_sha256_equal", "state_json_domain_equal", "rng_preserved", "hazard_rng_preserved", "resumed"):
                bad = copy.deepcopy(original)
                bad["details"][0][field] = False
                put_json(folder / "result.json", bad)
                with self.subTest(version=source_version, detail=field), self.assertRaises(ValueError):
                    RECEIPTS.validate_save_compat(self.evidence, COMMIT, VERSION, self.compat_hash)
            for field, value in (("name", "wave"), ("source_state", {}), ("resumed_action", "step"), ("snapshot_sha256", "f" * 64)):
                bad = copy.deepcopy(original)
                bad["details"][0][field] = value
                put_json(folder / "result.json", bad)
                with self.subTest(version=source_version, detail=field), self.assertRaises(ValueError):
                    RECEIPTS.validate_save_compat(self.evidence, COMMIT, VERSION, self.compat_hash)
            put_json(folder / "result.json", original)
            for name in ("shop", "wave"):
                path = folder / f"{name}-captured-snapshot.json"
                before = path.read_bytes()
                path.write_bytes(before + b" ")
                with self.subTest(version=source_version, snapshot=name), self.assertRaises(ValueError):
                    RECEIPTS.validate_save_compat(self.evidence, COMMIT, VERSION, self.compat_hash)
                path.write_bytes(before)
            path = folder / "compat-payload.json"
            before = path.read_bytes()
            path.write_bytes(before + b" ")
            with self.subTest(version=source_version, payload=True), self.assertRaises(ValueError):
                RECEIPTS.validate_save_compat(self.evidence, COMMIT, VERSION, self.compat_hash)
            path.write_bytes(before)

    def test_save_compatibility_rejects_missing_version_and_unrelated_writer_source(self) -> None:
        folder = self.evidence / "save-compat/0.17.0"
        path = folder / "writer-result.json"
        original = RECEIPTS.read_json(path)
        for field, value in (("game_commit", BASELINE), ("schema", 3), ("probe_sha256", "f" * 64), ("scenarios", ["shop"])):
            put_json(path, {**original, field: value})
            with self.subTest(field=field), self.assertRaises(ValueError):
                RECEIPTS.validate_save_compat(self.evidence, COMMIT, VERSION, self.compat_hash)
        put_json(path, original)
        for source_version in ("0.17.0", "0.18.0"):
            path = self.evidence / "save-compat" / source_version / "source.json"
            original = RECEIPTS.read_json(path)
            for field, value in (("version", "0.16.0"), ("tag", "v0.16.0"), ("game_commit", "shortsha"), ("game_commit", COMMIT)):
                put_json(path, {**original, field: value})
                with self.subTest(version=source_version, field=field), self.assertRaises(ValueError):
                    RECEIPTS.validate_save_compat(self.evidence, COMMIT, VERSION, self.compat_hash)
            put_json(path, original)
        shutil.rmtree(self.evidence / "save-compat/0.18.0")
        with self.assertRaises(ValueError):
            RECEIPTS.validate_save_compat(self.evidence, COMMIT, VERSION, self.compat_hash)

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
