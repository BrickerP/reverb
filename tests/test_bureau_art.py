"""Immutable source, transparent grid and export provenance checks for bureau art."""
import hashlib
import json
from pathlib import Path
import unittest
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets/presentation/bureau'


class BureauArt(unittest.TestCase):
    def test_generated_sources_preserve_rgba_pixels_and_complete_cells(self):
        records = json.loads((ART / 'carbon_copy_assets.json').read_text())
        self.assertEqual({r['id'] for r in records}, {'facilities', 'binding'})
        for record in records:
            path = ROOT / record['path']
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), record['sha256'])
            source = Path(record['source_file'])
            if source.exists():
                self.assertEqual(source.read_bytes(), path.read_bytes())
            with Image.open(path) as image:
                self.assertEqual(image.mode, 'RGBA')
                self.assertEqual(image.size, (1536, 1024))
                alpha = image.getchannel('A')
                self.assertEqual(alpha.getextrema()[0], 0)
                self.assertGreater(alpha.histogram()[0], image.width * image.height * .3)
                for row in range(2):
                    for column in range(4):
                        cell = alpha.crop((column * 384, row * 512, (column + 1) * 384, (row + 1) * 512))
                        self.assertGreater(sum(cell.histogram()[20:]), 1000, (record['id'], column, row))
            importer = Path(str(path) + '.import').read_text()
            self.assertIn('process/size_limit=512', importer)
            self.assertIn('mipmaps/generate=true', importer)

    def test_facility_regions_and_binding_sequence_have_closed_explicit_meaning(self):
        facilities, binding = json.loads((ART / 'carbon_copy_assets.json').read_text())
        self.assertEqual(len(facilities['regions']), 8)
        self.assertEqual([binding['columns'], binding['rows'], binding['frame_count']], [4, 2, 8])
        self.assertEqual(binding['pose_order'][3:5], ['bound', 'bound_idle'])
        self.assertEqual(binding['pose_order'][-1], 'originals_restored')
        self.assertTrue(all(record['pixels_preserved'] for record in [facilities, binding]))
        presets = (ROOT / 'export_presets.cfg').read_text()
        self.assertEqual(presets.count('assets/presentation/bureau/SOURCES.md'), 3)
        self.assertEqual(presets.count('assets/presentation/bureau/manifest.json'), 3)
