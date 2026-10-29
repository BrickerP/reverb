"""Real-score, envelope, headroom and shipped-byte checks for original music."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("original_score", ROOT / "tools/build_original_score.py")
BUILDER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUILDER)


class OriginalMusicTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.room = BUILDER.read_wav(ROOT / "audio/ambient.wav")
        cls.tracks = {mode: BUILDER.read_wav(ROOT / "audio/music" / f"{mode}.wav") for mode in BUILDER.MODES}

    def test_five_complete_original_arrangements_have_body_and_headroom(self):
        manifest = json.loads((ROOT / "audio/music/score.json").read_text())
        self.assertEqual(5, len(manifest["tracks"]))
        self.assertEqual(48, manifest["bars"])
        self.assertEqual("3/4", manifest["meter"])
        self.assertEqual(90, manifest["bpm"])
        digests = set()
        for record in manifest["tracks"]:
            path = ROOT / "audio/music" / record["file"]
            self.assertEqual(record["sha256"], hashlib.sha256(path.read_bytes()).hexdigest())
            digests.add(record["sha256"])
            samples = self.tracks[path.stem]
            metrics = BUILDER.metrics(samples)
            self.assertEqual(96, metrics["seconds"])
            self.assertGreater(metrics["peak"], .5)
            self.assertLess(metrics["peak"], .64)
            self.assertGreater(metrics["rms"], .035)
            self.assertLess(metrics["rms"], .17)
            self.assertLess(abs(metrics["dc"]), .0001)
            self.assertEqual((0, 0), (samples[0], samples[-1]))
            self.assertGreater(record["notes"], 400)
        self.assertEqual(5, len(digests))

    def test_score_develops_over_full_form_and_uses_melody_and_harmony(self):
        for mode in BUILDER.MODES:
            score = BUILDER.events(mode)
            instruments = {e["instrument"] for e in score}
            self.assertTrue({"piano", "reed", "bass", "desk", "key"} <= instruments)
            self.assertGreater(len({e["midi"] for e in score}), 20)
            self.assertGreater(max(e["seconds"] for e in score), 94)
            melodic = [e for e in score if e["instrument"] in ("piano", "reed") and e["gain"] > .08]
            sections = [tuple(e["midi"] for e in melodic if i * 16 <= e["seconds"] < (i + 1) * 16) for i in range(6)]
            self.assertGreaterEqual(len(set(sections)), 4)
            audio = self.tracks[mode]
            # A short repeated ambient loop cannot satisfy these differences.
            blocks = [audio[i * 16 * BUILDER.SR:(i + 1) * 16 * BUILDER.SR] for i in range(6)]
            self.assertTrue(all(float(np.sqrt(np.mean((blocks[0] - block) ** 2))) > .02 for block in blocks[1:]))

    def test_no_empty_nonfinite_or_clipping_output_is_written(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "bad.wav"
            for samples in (np.array([]), np.array([0, 1.0]), np.array([float("nan")])):
                with self.assertRaises(ValueError):
                    BUILDER.write_wav(path, samples)
                self.assertFalse(path.exists())

    def test_shipped_arrangements_reproduce_byte_for_byte(self):
        with tempfile.TemporaryDirectory() as temp:
            for mode in BUILDER.MODES:
                path = Path(temp) / f"{mode}.wav"
                BUILDER.write_wav(path, BUILDER.render(mode, self.room))
                self.assertEqual(path.read_bytes(), (ROOT / "audio/music" / path.name).read_bytes(), mode)

    def test_actual_gain_transition_audition_is_bounded_and_labeled(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            BUILDER.audition(directory, self.tracks)
            samples = BUILDER.read_wav(directory / "paperwork-waltz-runtime-audition.wav")
            timeline = json.loads((directory / "music-timeline.json").read_text())
            self.assertEqual(96 * BUILDER.SR, len(samples))
            self.assertLess(float(np.max(np.abs(samples))), .15)
            self.assertEqual(6, len(timeline["form"]))
            self.assertEqual(set(BUILDER.MODES), {e["arrangement"] for e in timeline["timeline"]})
            self.assertTrue(all(e["at"] == e["score_position"] for e in timeline["timeline"]))


if __name__ == "__main__":
    unittest.main()
