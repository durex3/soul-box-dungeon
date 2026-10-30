"""Appending another task must not hide missing/duplicate original provenance."""
import copy
import csv
import unittest
from acceptance.rk074_verify import ROOT, validate_original_records


class OriginalProvenanceTests(unittest.TestCase):
    def setUp(self):
        with (ROOT / 'art/ai_log.csv').open(encoding='utf-8-sig', newline='') as stream:
            self.records = list(csv.DictReader(stream))

    def test_boss_append_preserves_exact_original_group(self):
        names = {'bos_' + id + '_' + action + '.png'
                 for id in ('gravekeeper', 'furnace_colossus') for action in ('idle', 'run')}
        original = [r for r in self.records if r['资源文件名'] not in names]
        bosses = [r for r in self.records if r['资源文件名'] in names]
        self.assertEqual(len(bosses), 4)
        validate_original_records(original)
        validate_original_records(original + bosses)

    def test_missing_or_duplicate_original_name_fails_for_both_tasks(self):
        for name in ('chr_knight_idle.png', 'box_fireball_t4.png'):
            with self.subTest(name=name):
                row = next(r for r in self.records if r['资源文件名'] == name)
                with self.assertRaises(ValueError):
                    validate_original_records([r for r in self.records if r is not row])
                with self.assertRaises(ValueError):
                    validate_original_records(self.records + [row])

    def test_wrong_original_source_still_fails(self):
        records = copy.deepcopy(self.records)
        records[0]['原始文件名'] = 'wrong.aseprite'
        with self.assertRaises(ValueError):
            validate_original_records(records)
