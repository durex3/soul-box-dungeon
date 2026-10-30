"""Bounded production driver and graphical input acceptance."""
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]


def run(arguments, marker='', graphical=False):
    command = [os.environ.get('GODOT_BIN', '/Applications/Godot.app/Contents/MacOS/Godot')]
    command += ([] if graphical else ['--headless']) + ['--path', str(ROOT / 'game')] + arguments
    result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True, timeout=45)
    print(result.stdout, end='', flush=True)
    if result.returncode or re.search(r'^\s*(?:ERROR:|SCRIPT ERROR\b)', result.stdout, re.M):
        raise ValueError('Godot error/nonzero exit')
    if marker and result.stdout.splitlines().count(marker) != 1:
        raise ValueError('Missing/duplicate marker ' + marker)
    return result.stdout


def main():
    try:
        run(['--import'])
        for fps in (30, 60):
            for bonus in (0.0, 0.5):
                run(['-s', str(Path(__file__).with_name('rk012_probe.gd')), '--', str(fps), str(bonus)],
                    'RK012_DRIVER: passed')
        run(['-s', str(Path(__file__).with_name('rk012_input.gd'))], 'RK012_INPUT: passed', True)
    except (OSError, ValueError, subprocess.TimeoutExpired) as exc:
        print('RK012: failed: ' + str(exc))
        return 1
    print('RK012: passed')
    return 0


if __name__ == '__main__':
    sys.exit(main())
