"""Read-only alpha, immutable-source and authored-layout checks for expedition art."""
import hashlib
import json
from pathlib import Path
import unittest
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "assets/presentation"
FILES = ("enemies/foreman.png", "enemies/collector.png", "weapons/expedition_arsenal.png", "supports/crew.png")


class ExpeditionArt(unittest.TestCase):
    def test_new_originals_are_byte_preserved_rgba_and_transparent(self):
        for relative in FILES:
            path = ART / relative
            group = relative.split('/')[0]
            data = json.loads((ART / group / 'carbon_copy_assets.json').read_text())
            rows = data['assets'] if isinstance(data, dict) else data
            record = next(row for row in rows if row.get('path', row.get('file')) == str(path.relative_to(ROOT)))
            self.assertEqual(record['sha256'], hashlib.sha256(path.read_bytes()).hexdigest())
            source = Path(record['source_file'])
            if source.exists():
                self.assertEqual(source.read_bytes(), path.read_bytes())
            with Image.open(path) as image:
                self.assertEqual(image.mode, 'RGBA')
                alpha = image.getchannel('A')
                self.assertEqual(alpha.getextrema()[0], 0)
                self.assertGreater(alpha.getextrema()[1], 200)
                self.assertGreater(alpha.histogram()[0], image.width * image.height * .3)
            importer = Path(str(path) + '.import').read_text()
            self.assertIn('process/size_limit=512', importer)
            self.assertIn('mipmaps/generate=true', importer)

    def test_bosses_have_eight_authored_poses_and_supports_have_eight_static_regions(self):
        data = json.loads((ART / 'enemies/carbon_copy_assets.json').read_text())
        for identity in ('foreman', 'collector'):
            record = next(row for row in data['assets'] if row['id'] == identity)
            self.assertEqual([record['columns'], record['rows'], record['frame_count']], [4, 2, 8])
            self.assertEqual(record['pose_order'][6:], ['defeated_alive', 'flat'])
        support = json.loads((ART / 'supports/carbon_copy_assets.json').read_text())[0]
        self.assertEqual(len(support['regions']), 8)
        self.assertEqual(support['frame_count'], 1)
        arsenal = json.loads((ART / 'weapons/carbon_copy_assets.json').read_text())[-1]
        self.assertEqual(len(arsenal['regions']), 12)
        self.assertIn('mission_letter', arsenal['regions'])


    def test_foreman_idle_keeps_complete_body_and_excludes_neighbor_pixels(self):
        data = json.loads((ART / 'enemies/carbon_copy_assets.json').read_text())
        record = next(row for row in data['assets'] if row['id'] == 'foreman')
        rects = record['frame_visible_rects']['0']
        with Image.open(ART / 'enemies/foreman.png') as image:
            alpha = image.getchannel('A').load()
            seen, components = set(), []
            for y in range(512):
                for x in range(384):
                    if (x, y) in seen or alpha[x, y] < 20:
                        continue
                    pending, component = [(x, y)], []
                    seen.add((x, y))
                    while pending:
                        px, py = pending.pop()
                        component.append((px, py))
                        for point in ((px-1, py), (px+1, py), (px, py-1), (px, py+1)):
                            nx, ny = point
                            if 0 <= nx < 384 and 0 <= ny < 512 and point not in seen and alpha[nx, ny] >= 20:
                                seen.add(point)
                                pending.append(point)
                    if len(component) > 100:
                        components.append(component)
            components.sort(key=len, reverse=True)
            covered = lambda point: any(x <= point[0] < x+w and y <= point[1] < y+h for x, y, w, h in rects)
            self.assertEqual(len(components[0]), 98204)
            self.assertEqual(len(components[1]), 2021)
            self.assertTrue(all(covered(point) for point in components[0]), 'entire own body retained')
            self.assertFalse(any(covered(point) for point in components[1]), 'no neighboring pose pixels drawn')


if __name__ == '__main__':
    unittest.main()
