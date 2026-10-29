"""Acoustic and reproducibility checks for shipped paperbureau audio."""
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import re
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("paper_audio_builder", ROOT / "tools/build_presentation_audio.py")
BUILDER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUILDER)


class PaperAudioAssetsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.palette = BUILDER.source_palette()
        cls.cues = BUILDER.build_cues(cls.palette)
        cls.ambient = BUILDER.build_ambient(cls.palette)

    def test_runtime_identities_are_complete_and_unique(self):
        code = (ROOT / "scripts/game/audio.gd").read_text()
        block = code.split("const ALL_NAMES:", 1)[1].split("const WEAPON_PROFILES", 1)[0]
        names = re.findall(r'&"([^"]+)"', block)
        self.assertEqual(35, len(names))
        self.assertEqual(set(names), set(self.cues))
        files = {p.stem for p in (ROOT / "audio/presentation").glob("*.wav")}
        self.assertEqual(set(names), files)
        digests = {hashlib.sha256((ROOT / "audio/presentation" / f"{n}.wav").read_bytes()).hexdigest() for n in names}
        self.assertEqual(35, len(digests), "distinct identities must not share a placeholder recording")

    def test_shipped_cues_have_headroom_body_and_zero_ended_envelopes(self):
        for name in self.cues:
            with self.subTest(cue=name):
                samples = BUILDER.read_wav(ROOT / "audio/presentation" / f"{name}.wav")
                metrics = BUILDER.metrics(samples)
                self.assertGreaterEqual(metrics["seconds"], .06)
                self.assertLessEqual(metrics["seconds"], .9)
                self.assertGreaterEqual(metrics["peak"], .4)
                self.assertLessEqual(metrics["peak"], .641)
                self.assertGreater(metrics["rms"], .025, "an isolated click is not enough body")
                self.assertLess(metrics["rms"], .16, "dense voices need mix headroom")
                self.assertLess(abs(metrics["dc"]), .001)
                self.assertEqual(0.0, samples[0])
                self.assertEqual(0.0, samples[-1])

    def test_room_loop_has_quiet_seam_and_no_placeholder_drone_level(self):
        samples = BUILDER.read_wav(ROOT / "audio/ambient.wav")
        metrics = BUILDER.metrics(samples)
        self.assertEqual(16.0, metrics["seconds"])
        self.assertLessEqual(metrics["peak"], .181)
        self.assertGreater(metrics["rms"], .015)
        self.assertLess(metrics["rms"], .05)
        self.assertLess(metrics["seam_delta"], 1 / 32768)
        self.assertLess(abs(samples[1] - samples[0]), 1 / 32768)
        self.assertLess(abs(samples[-1] - samples[-2]), 1 / 32768)
        self.assertLess(abs(metrics["dc"]), .0001)

    def test_rebuild_matches_every_shipped_byte(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            for name, samples in self.cues.items():
                output = directory / f"{name}.wav"
                BUILDER.write_wav(output, samples)
                self.assertEqual(output.read_bytes(), (ROOT / "audio/presentation" / output.name).read_bytes(), name)
            output = directory / "ambient.wav"
            BUILDER.write_wav(output, self.ambient)
            self.assertEqual(output.read_bytes(), (ROOT / "audio/ambient.wav").read_bytes())

    def test_changed_source_snapshot_fails_before_production(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            source = directory / "object.wav"
            source.write_bytes(b"unexpected bytes")
            (directory / "sources.json").write_text(json.dumps({"assets": [{"file": "object.wav", "sha256": "not-the-source-hash"}]}))
            with patch.object(BUILDER, "ROOT", directory), patch.object(BUILDER, "SOURCE_DIR", directory):
                with self.assertRaisesRegex(ValueError, "snapshot changed"):
                    BUILDER.source_palette()

    def test_invalid_output_is_rejected_instead_of_clipped(self):
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp) / "invalid.wav"
            for samples in [[], [0.0, 1.0, 0.0], [0.0, -1.01, 0.0]]:
                with self.subTest(samples=samples):
                    with self.assertRaisesRegex(ValueError, "empty or clipping"):
                        BUILDER.write_wav(output, samples)
                    self.assertFalse(output.exists())

    def test_boss_seam_snap_is_timed_to_visual_break(self):
        samples = self.cues["boss"]
        def rms(start, end):
            part = samples[round(start * BUILDER.SR):round(end * BUILDER.SR)]
            return math.sqrt(sum(s*s for s in part) / len(part))
        self.assertGreater(rms(.18, .22), rms(.10, .14) * 2.0,
                           "the seam break must read over the preceding tension")

    def test_audition_mixed_scene_keeps_real_gains_and_does_not_clip(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            BUILDER.audition(directory, self.cues, self.ambient, (ROOT / "scripts/game/audio.gd").read_text())
            samples = BUILDER.read_wav(directory / "paperbureau-audition.wav")
            report = json.loads((directory / "timeline.json").read_text())
            self.assertEqual(24 * BUILDER.SR, len(samples))
            self.assertLess(max(abs(s) for s in samples), .7)
            self.assertEqual(0.0, samples[-1])
            self.assertTrue(any(row["cue"] == "boss" and row["section"] == "runtime-gain mixed scene" for row in report["timeline"]))


if __name__ == "__main__":
    unittest.main()
