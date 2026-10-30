"""Run the graphical interaction probe; never silently fall back to headless."""
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]


def main():
    binary = os.environ.get('GODOT_BIN', '/Applications/Godot.app/Contents/MacOS/Godot')
    command = [binary, '--path', str(ROOT / 'game'), '-s',
               str(Path(__file__).with_name('rk119_interact.gd'))]
    if len(sys.argv) > 1:
        command += ['--'] + sys.argv[1:]
    try:
        result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True, timeout=45)
    except subprocess.TimeoutExpired as exc:
        output = exc.stdout or b''
        print(output.decode(errors='replace') if isinstance(output, bytes) else output)
        print('RK119 graphical timeout (45s); child killed')
        return 1
    print(result.stdout, end='', flush=True)
    if (result.returncode or re.search(r'^\s*(?:SCRIPT ERROR\b|ERROR:)', result.stdout, re.M)
            or result.stdout.splitlines().count('RK119_INTERACT: passed') != 1):
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
