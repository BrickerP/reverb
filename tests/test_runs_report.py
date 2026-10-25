import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tools" / "runs_report.py"
SPEC = importlib.util.spec_from_file_location("runs_report", SCRIPT)
REPORT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(REPORT)


def run_row(**updates):
    row = {
        "schema_version": 2,
        "run_id": "run-0001",
        "recorded_at_utc": "2026-10-23T10:00:00Z",
        "source": "manual",
        "build_commit": "abc123",
        "version": "0.4",
        "seed": 42,
        "character": "conductor",
        "wave": 7,
        "won": False,
        "kills": 18,
        "seconds": 91.5,
        "weapons": ["pulse"],
        "death_cause": "enemy",
    }
    row.update(updates)
    return row


def feedback_row(**updates):
    row = {
        "schema_version": 1,
        "version": "0.4",
        "run_id": "run-0001",
        "category": "echoes",
        "rating": "mixed",
        "note": "clear enough",
        "submitted_at_utc": "2026-10-23T10:02:00Z",
        "build_commit": "abc123",
        "seed": 42,
        "character": "conductor",
        "wave": 7,
        "won": False,
        "source": "manual",
    }
    row.update(updates)
    return row


class RunsReportTest(unittest.TestCase):
    def test_mixed_provenance_legacy_and_conductor(self):
        rows = [
            REPORT.norm(run_row()),
            REPORT.norm(
                {
                    "version": "0.3",
                    "seed": "9",
                    "character": "looper",
                    "wave": "3",
                    "won": 1,
                    "kills": "5",
                    "seconds": "12.5",
                    "weapons": [],
                }
            ),
            REPORT.norm(run_row(run_id="run-0002", source="fixture", build_commit="def456", character="solo")),
            REPORT.norm(run_row(run_id="run-0003", source="bot", build_commit="def456", character="mirror")),
        ]
        text = REPORT.build_report(rows)
        self.assertIn("Conductor", text)
        self.assertIn("Sources: manual: 1 · fixture: 1 · bot: 1 · unknown: 1", text)
        self.assertIn("Builds: def456: 2 · abc123: 1 · unavailable: 1", text)
        self.assertNotIn("human", text.lower())

    def test_modes_and_anomalies_are_separated(self):
        rows = [
            REPORT.norm(run_row(run_id="run-0001")),
            REPORT.norm(run_row(run_id="run-0002", endless=True, boss_rush=True, wave=30)),
            REPORT.norm(run_row(run_id="run-0003", endless=True, wave=22)),
            REPORT.norm(run_row(run_id="run-0004", daily_modifier="riftstorm", wave=9)),
        ]
        text = REPORT.build_report(rows)
        self.assertIn("| Normal | 1 | 0 | 7.0 |", text)
        self.assertIn("| Daily | 1 | 0 | 9.0 |", text)
        self.assertIn("| Endless | 1 | 0 | 22.0 |", text)
        self.assertIn("| Boss Rush | 1 | 0 | 30.0 |", text)
        self.assertIn("## Daily anomalies", text)
        self.assertIn("| riftstorm | 1 | 0 | 0.0% | 9.0 |", text)

    def test_boons_and_refreshes_are_reported(self):
        rows = [
            REPORT.norm(run_row(run_id="run-0001", boons=["damage", "haste"], echo_refreshes=2)),
            REPORT.norm(run_row(run_id="run-0002", boons=["damage"], echo_refreshes=1)),
        ]
        text = REPORT.build_report(rows)
        self.assertIn("Echo refreshes: **3** total · **1.50** per run", text)
        self.assertIn("| damage | 2 |", text)
        self.assertIn("| haste | 1 |", text)
        self.assertIn("| 2 | 92s |", text)

    def test_contract_outcomes_are_reported(self):
        rows = [
            REPORT.norm(run_row(run_id="run-0001", contracts_accepted=2,
                                contracts_completed=1, contracts_failed=1)),
            REPORT.norm(run_row(run_id="run-0002", contracts_accepted=1,
                                contracts_completed=1, contracts_failed=0)),
        ]
        text = REPORT.build_report(rows)
        self.assertIn("Contracts: accepted **3** · completed **2** · failed **1**", text)

    def test_malformed_endgame_fields_are_skipped(self):
        malformed = [
            run_row(run_id="bad-endless", endless="yes"),
            run_row(run_id="bad-rush", boss_rush=2),
            run_row(run_id="bad-daily", daily_modifier=3),
            run_row(run_id="bad-ascension", ascension=-1),
            run_row(run_id="bad-boons", boons="damage"),
            run_row(run_id="bad-refreshes", echo_refreshes=-1),
            run_row(run_id="bad-contracts", contracts_accepted=-1),
        ]
        self.assertTrue(all(REPORT.norm(row) is None for row in malformed))

    def test_malformed_values_are_skipped_without_crashing(self):
        malformed = [
            run_row(run_id="bad-bool", won="yes"),
            run_row(run_id="bad-character", character=3),
            run_row(run_id="bad-wave", wave=float("inf")),
            run_row(run_id="bad-seconds", seconds="nan"),
            run_row(run_id="bad-kills", kills=True),
            run_row(run_id="bad-weapons", weapons="pulse"),
            run_row(run_id="bad-seed", seed="nan"),
            run_row(run_id="bad-version", version=[]),
        ]
        self.assertTrue(all(REPORT.norm(row) is None for row in malformed))
        legacy = REPORT.norm(run_row(schema_version=1, won="false", wave="2.0", kills=3.0, seconds="4"))
        self.assertIsNotNone(legacy)
        self.assertFalse(legacy["won"])

    def test_feedback_join_escapes_note_and_rejects_bad_provenance(self):
        run = REPORT.norm(run_row())
        valid = REPORT.norm_feedback(feedback_row(note="a | b\nnext"))
        mismatch = REPORT.norm_feedback(feedback_row(run_id="run-mismatch", build_commit="wrong"))
        orphan = REPORT.norm_feedback(feedback_row(run_id="missing-1"))
        text = REPORT.build_report([run, REPORT.norm(run_row(run_id="run-mismatch"))], feedback=[valid, mismatch, orphan])
        self.assertIn("a \\| b next", text)
        self.assertIn("Conductor", text)
        self.assertIn("Ignored 1 orphan feedback record", text)
        self.assertIn("Ignored 1 feedback record(s) with mismatched run provenance", text)
        self.assertNotIn("wrong |", text)

    def test_duplicate_feedback_is_not_joined(self):
        run = REPORT.norm(run_row())
        entries = [REPORT.norm_feedback(feedback_row(note="first")), REPORT.norm_feedback(feedback_row(note="second"))]
        text = REPORT.build_report([run], feedback=entries)
        self.assertNotIn("## Feedback", text)
        self.assertIn("Ignored 2 duplicate feedback record(s)", text)

    def test_duplicate_run_ids_are_not_joined(self):
        runs = [REPORT.norm(run_row()), REPORT.norm(run_row(character="solo"))]
        text = REPORT.build_report(runs, feedback=[REPORT.norm_feedback(feedback_row())])
        self.assertNotIn("## Feedback", text)
        self.assertIn("2 run record(s) with duplicate run IDs", text)

    def test_invalid_feedback_values_are_rejected(self):
        self.assertIsNone(REPORT.norm_feedback(feedback_row(category="aim")))
        self.assertIsNone(REPORT.norm_feedback(feedback_row(rating="great")))
        self.assertIsNone(REPORT.norm_feedback(feedback_row(note="x" * 501)))
        self.assertIsNone(REPORT.norm_feedback(feedback_row(run_id=4)))
        self.assertIsNone(REPORT.norm_feedback(feedback_row(source="person")))
        self.assertIsNone(REPORT.norm_feedback(feedback_row(build_commit=3)))
        self.assertIsNone(REPORT.norm_feedback(feedback_row(schema_version=2)))
        self.assertIsNone(REPORT.norm_feedback(feedback_row(run_id="bad id")))
        self.assertIsNone(REPORT.norm_feedback(feedback_row(run_id="short")))

    def test_schema_two_requires_valid_provenance_but_legacy_defaults_unknown(self):
        self.assertIsNone(REPORT.norm(run_row(source="person")))
        self.assertIsNone(REPORT.norm(run_row(build_commit=[])))
        self.assertIsNone(REPORT.norm(run_row(run_id="bad id")))
        self.assertIsNone(REPORT.norm(run_row(run_id="short")))
        legacy = REPORT.norm({"character": "solo", "wave": 1, "won": False, "kills": 0, "seconds": 1, "weapons": []})
        self.assertEqual("unknown", legacy["source"])
        self.assertEqual("unavailable", legacy["build_commit"])

        claimed = REPORT.norm(
            {
                "schema_version": 1,
                "source": "manual",
                "build_commit": "claimed",
                "character": "solo",
                "wave": 1,
                "won": False,
                "kills": 0,
                "seconds": 1,
                "weapons": [],
            }
        )
        self.assertEqual("unknown", claimed["source"])
        self.assertEqual("unavailable", claimed["build_commit"])
        self.assertIsNone(REPORT.build_report([claimed], source_filter={"manual"}))

    def test_cli_filters_sources_and_supports_repeated_feedback_paths_and_out(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            runs = directory / "runs.jsonl"
            feedback_a = directory / "feedback-a.jsonl"
            feedback_b = directory / "feedback-b.jsonl"
            output = directory / "report.md"
            legacy_claiming_manual = {
                "schema_version": 1,
                "source": "manual",
                "build_commit": "claimed",
                "seed": 8,
                "character": "mirror",
                "wave": 2,
                "won": False,
                "kills": 1,
                "seconds": 5,
                "weapons": [],
            }
            runs.write_text(
                "\n".join(
                    json.dumps(row)
                    for row in [
                        run_row(),
                        run_row(run_id="run-0002", source="fixture", character="looper"),
                        legacy_claiming_manual,
                    ]
                )
                + "\n",
                encoding="utf-8",
            )
            feedback_a.write_text(json.dumps(feedback_row()) + "\n", encoding="utf-8")
            feedback_b.write_text(json.dumps(feedback_row(run_id="missing-1")) + "\n", encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(SCRIPT), str(runs), "--feedback", str(feedback_a), "--feedback", str(feedback_b), "--source", "manual", "--out", str(output)],
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(0, result.returncode, result.stderr)
            text = output.read_text(encoding="utf-8")
            self.assertIn("Runs: **1**", text)
            self.assertIn("Source filter: manual", text)
            self.assertIn("## Feedback", text)
            self.assertIn("orphan feedback", text)
            self.assertNotIn("Looper", text)

    def test_cli_counts_json_and_validation_failures(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "runs.jsonl"
            path.write_text(json.dumps(run_row()) + "\nnot-json\n" + json.dumps(run_row(run_id="bad-row1", won=[])) + "\n", encoding="utf-8")
            result = subprocess.run([sys.executable, str(SCRIPT), str(path)], text=True, capture_output=True, check=False)
            self.assertEqual(0, result.returncode, result.stderr)
            self.assertIn("Skipped 2 malformed run record(s).", result.stdout)

    def test_cli_skips_invalid_utf8_line(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "runs.jsonl"
            path.write_bytes((json.dumps(run_row()) + "\n").encode("utf-8") + b"\xff\n")
            result = subprocess.run([sys.executable, str(SCRIPT), str(path)], text=True, capture_output=True, check=False)
            self.assertEqual(0, result.returncode, result.stderr)
            self.assertIn("Runs: **1**", result.stdout)
            self.assertIn("Skipped 1 malformed run record(s).", result.stdout)


if __name__ == "__main__":
    unittest.main()
