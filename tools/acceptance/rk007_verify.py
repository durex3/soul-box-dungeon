"""Bounded, cwd-independent production SpatialHash correctness/performance probe."""
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]


def run(arguments, marker=''):
    command = [os.environ.get('GODOT_BIN', '/Applications/Godot.app/Contents/MacOS/Godot'),
               '--headless', '--path', str(ROOT / 'game')] + arguments
    result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True, timeout=45)
    print(result.stdout, end='', flush=True)
    if result.returncode or re.search(r'^\s*(?:ERROR:|SCRIPT ERROR\b)', result.stdout, re.M):
        raise ValueError('Godot error or nonzero exit')
    if marker and result.stdout.splitlines().count(marker) != 1:
        raise ValueError('Missing/duplicate marker ' + marker)


def main():
    try:
        run(['--import'])
        run(['-s', str(Path(__file__).resolve().with_name('rk007_probe.gd'))], 'RK007_PROBE: passed')
    except (OSError, ValueError, subprocess.TimeoutExpired) as exc:
        print('RK007: failed: ' + str(exc), flush=True)
        return 1
    print('RK007: passed', flush=True)
    return 0


if __name__ == '__main__':
    sys.exit(main())
