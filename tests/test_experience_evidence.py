import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from PIL import Image

spec = importlib.util.spec_from_file_location('experience_verifier', Path(__file__).resolve().parents[1] / 'tools/verify_experience_evidence.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ExperienceEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        self.commit = 'a' * 40
        shots = {}
        for index in range(14):
            name = f'{index}.png'
            Image.new('RGB', (1280, 720), (index * 10, 50, 70)).save(self.folder / name)
            shots[str(index)] = {'file': name}
        self.source = {'success': True, 'failed': False, 'commit': self.commit, 'variant': 'normal',
                       'source': 'scripted fixture', 'canvas': [1280, 720], 'native_frames': 820,
                       'capture': {'fps': 60, 'speed': 1.0, 'audio': 'real unmuted GameAudio master mix'},
                       'cases': [{'name': name, 'audio_route_delta': 1} for name in module.CASES],
                       'screenshots': shots, 'read_only_checks': [dict.fromkeys(('strict_roundtrip', 'full_snapshot_unchanged', 'rng_unchanged', 'hazard_rng_unchanged'), True) for _ in range(14)],
                       'route_evidence': [{'count': 8, 'actual_future_steps': 120, 'maximum_position_error': .001} for _ in range(3)]}
        self.write_source()
        (self.folder / 'video.json').write_text(json.dumps({'streams': [
            {'codec_type': 'video', 'width': 1280, 'height': 720, 'avg_frame_rate': '60/1', 'duration': '13.7'},
            {'codec_type': 'audio', 'channels': 2, 'duration': '13.7'}]}))
        (self.folder / 'audio-analysis.txt').write_text('RMS level dB: -26.1\nPeak level dB: -4.5\n')

    def write_source(self):
        (self.folder / 'experience_source.json').write_text(json.dumps(self.source))

    def test_complete_native_evidence_and_audible_mix(self):
        result = module.validate_source(self.folder, self.commit, 'normal')
        self.assertEqual(len(result['screenshots']), 14)
        self.assertEqual(module.validate_media(self.folder, [1280, 720])['rms_db'], [-26.1])

    def test_reject_another_commit_and_bad_future_path(self):
        with self.assertRaisesRegex(ValueError, 'source mismatch'):
            module.validate_source(self.folder, 'b' * 40, 'normal')
        self.source['route_evidence'][0]['maximum_position_error'] = 4.0
        self.write_source()
        with self.assertRaisesRegex(ValueError, 'route differs'):
            module.validate_source(self.folder, self.commit, 'normal')

    def test_render_mutation_cannot_be_accepted(self):
        self.source['read_only_checks'][0]['rng_unchanged'] = False
        self.write_source()
        with self.assertRaisesRegex(ValueError, 'render mutated'):
            module.validate_source(self.folder, self.commit, 'normal')

    def test_silent_or_clipped_sound_is_rejected(self):
        for rms, peak in [('-inf', '-inf'), ('-8.0', '0.0')]:
            (self.folder / 'audio-analysis.txt').write_text(f'RMS level dB: {rms}\nPeak level dB: {peak}\n')
            with self.assertRaises(ValueError):
                module.validate_media(self.folder, [1280, 720])
