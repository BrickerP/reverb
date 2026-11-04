import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from PIL import Image

spec = importlib.util.spec_from_file_location('perception_verifier', Path(__file__).resolve().parents[1] / 'tools/verify_perception_evidence.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class PerceptionEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        self.commit = 'a' * 40
        Image.new('RGB', (1280, 720), (50, 60, 70)).save(self.folder / 'state.png')
        self.source = {'success': True, 'failed': False, 'commit': self.commit,
                       'mode': 'journey', 'canvas': [1280, 720], 'language': 'en', 'reduced': False,
                       'fps': 60, 'uncut': True, 'audio': 'real unmuted GameAudio master mix',
                       'native_frames': 1800, 'inputs': [{'action': 'move_right'}],
                       'case_coverage': [{'id': f'{number:02d}', 'status': 'native_observed' if number == 1 else 'not_exercised'} for number in range(1, 41)],
                       'screenshots': {'state': {'file': 'state.png'}},
                       'read_only_checks': [dict.fromkeys(('strict_roundtrip', 'full_snapshot_unchanged', 'rng_unchanged', 'hazard_rng_unchanged'), True)],
                       'policy': {'fresh_run': True, 'native_main_physics': True,
                                  **dict.fromkeys(('preseeded_knowledge', 'preseeded_gear', 'invulnerability', 'skip_waves', 'simulation_time_jumps', 'manual_sim_step'), False)},
                       'highest_wave': 4, 'first_boss_spawned': True, 'first_boss_defeated': True}
        self.write()
        (self.folder / 'video.json').write_text(json.dumps({'streams': [
            {'codec_type': 'video', 'width': 1280, 'height': 720, 'avg_frame_rate': '60/1', 'duration': '30.0'},
            {'codec_type': 'audio', 'duration': '30.0'}]}))
        (self.folder / 'audio-analysis.txt').write_text('RMS level dB: -25.0\nPeak level dB: -5.0\n')

    def write(self):
        (self.folder / 'perception_source.json').write_text(json.dumps(self.source))

    def test_valid_source_retains_unexercised_cases_and_human_limit(self):
        receipt = module.validate_capture(self.folder, self.commit, 'journey')
        self.assertEqual(receipt['observed_cases'], ['01'])
        self.assertFalse(receipt['human_understanding_verified'])

    def test_wrong_source_or_cheated_journey_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'source mismatch'):
            module.validate_capture(self.folder, 'b' * 40, 'journey')
        self.source['policy']['invulnerability'] = True
        self.write()
        with self.assertRaisesRegex(ValueError, 'manipulates'):
            module.validate_capture(self.folder, self.commit, 'journey')

    def test_render_mutation_or_false_comprehension_claim_is_rejected(self):
        self.source['read_only_checks'][0]['rng_unchanged'] = False
        self.write()
        with self.assertRaisesRegex(ValueError, 'render changed'):
            module.validate_capture(self.folder, self.commit, 'journey')
        self.source['read_only_checks'][0]['rng_unchanged'] = True
        self.source['case_coverage'][0]['status'] = 'player_understood'
        self.write()
        with self.assertRaisesRegex(ValueError, 'comprehension claim'):
            module.validate_capture(self.folder, self.commit, 'journey')

    def test_truncated_movie_cannot_be_a_continuous_journey(self):
        video = json.loads((self.folder / 'video.json').read_text())
        video['streams'][0]['duration'] = '2.0'
        (self.folder / 'video.json').write_text(json.dumps(video))
        with self.assertRaisesRegex(ValueError, 'clock diverge'):
            module.validate_capture(self.folder, self.commit, 'journey')
