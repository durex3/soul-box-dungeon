"""Required mutations; verify specific test failures and restore exact source bytes."""
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'game/sim/core/spatial_hash.gd'


def main():
    original = SOURCE.read_bytes()
    cases = [
        (b'position.distance_squared_to(center) <= squared',
         b'position.distance_squared_to(center) < squared', 'test_circle_filter_and_boundaries'),
        ('\t_positions[entity_id] = position\n\treturn true\n\n## 返回圆内'.encode(),
         '\t# Deliberately omit position update\n\treturn true\n\n## 返回圆内'.encode(), 'test_move_and_bucket_cleanup'),
        (b'\tresult.sort()', b'\t# Deliberately omit sorting', 'test_order_independence_and_result_copy'),
    ]
    for before, after, method in cases:
        if original.count(before) != 1:
            raise ValueError('Mutation target not unique: ' + method)
        try:
            SOURCE.write_bytes(original.replace(before, after))
            result = subprocess.run(
                [os.environ.get('GODOT_BIN', '/Applications/Godot.app/Contents/MacOS/Godot'),
                 '--headless', '--path', str(ROOT / 'game'), '-s', 'res://tests/lib/run_tests.gd'],
                cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=45)
            failures = [line for line in result.stdout.splitlines() if line.startswith('FAIL ') and method in line]
            if result.returncode != 1 or not failures:
                print(result.stdout)
                raise ValueError('Mutation not caught by intended test: ' + method)
            print('RK007 mutation caught: ' + method + '\n' + failures[0], flush=True)
        finally:
            SOURCE.write_bytes(original)
    print('RK007_FAULTS: passed; original bytes restored', flush=True)


if __name__ == '__main__':
    main()
