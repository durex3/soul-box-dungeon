"""Check actual pool processing and isolated, expected invalid-configuration errors."""
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
GODOT = os.environ.get('GODOT_BIN', '/Applications/Godot.app/Contents/MacOS/Godot')
ERROR_LINE = re.compile(r'^\s*(?:ERROR:|SCRIPT ERROR\b).*', re.MULTILINE)
EXPECTED_ERROR = 'ERROR: NodePool.configure: invalid configuration'
NEGATIVE_CASES = ('null', 'zero', 'negative', 'empty', 'wrong_root', 'bad_child', 'canvas', 'reconfigure', 'in_tree')


def run(arguments: list[str], marker: str = '', expected_error: bool = False) -> None:
    """Allow exactly one known ERROR only in explicitly selected negative probes."""
    command = [GODOT, '--headless', '--path', str(ROOT / 'game')] + arguments
    try:
        result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True, timeout=45)
    except subprocess.TimeoutExpired as exc:
        output = exc.stdout or b''
        print(output.decode(errors='replace') if isinstance(output, bytes) else output, flush=True)
        raise ValueError('Godot timeout after 45 seconds; child killed') from exc
    print(result.stdout, end='' if result.stdout.endswith('\n') else '\n', flush=True)
    errors = [line.strip() for line in ERROR_LINE.findall(result.stdout)]
    if result.returncode != 0 or errors != ([EXPECTED_ERROR] if expected_error else []):
        raise ValueError('Unexpected engine exit/errors: exit=%d errors=%s' % (result.returncode, errors))
    if marker and result.stdout.splitlines().count(marker) != 1:
        raise ValueError('Missing unique result marker: ' + marker)


def main() -> int:
    try:
        run(['--import'])
        probe = ['-s', str(Path(__file__).with_name('rk008_probe.gd').resolve())]
        run(probe, 'RK008_PROBE: passed')
        for kind in NEGATIVE_CASES:
            print('RK008 negative case: ' + kind, flush=True)
            run(probe + ['--', '--negative', kind], 'RK008_NEGATIVE: passed', expected_error=True)
    except (OSError, ValueError) as exc:
        print('RK008: failed: %s; set GODOT_BIN to select Godot' % exc, flush=True)
        return 1
    print('RK008: passed', flush=True)
    return 0


if __name__ == '__main__':
    sys.exit(main())
