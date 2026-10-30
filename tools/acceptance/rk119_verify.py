"""Cwd-independent, bounded scene/catalog smoke. UI acceptance remains graphical."""
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
GODOT = os.environ.get('GODOT_BIN', '/Applications/Godot.app/Contents/MacOS/Godot')


def run(arguments, marker=''):
    """Import and probe must both exit cleanly within 45 seconds."""
    result = subprocess.run(
        [GODOT, '--headless', '--path', str(ROOT / 'game')] + arguments,
        cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, timeout=45)
    print(result.stdout, end='', flush=True)
    if result.returncode or re.search(r'^\s*(?:SCRIPT ERROR\b|ERROR:)', result.stdout, re.M):
        raise ValueError('Godot failed: exit=%d' % result.returncode)
    if marker and result.stdout.splitlines().count(marker) != 1:
        raise ValueError('Missing unique marker ' + marker)


def main():
    try:
        run(['--import'])
        run(['-s', str(Path(__file__).with_name('rk119_smoke.gd'))], 'RK119_SMOKE: passed')
    except (OSError, ValueError, subprocess.TimeoutExpired) as exc:
        print('RK119: failed: %s' % exc, flush=True)
        return 1
    print('RK119: passed', flush=True)
    return 0


if __name__ == '__main__':
    sys.exit(main())
