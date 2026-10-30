"""RK120 graphical font, geometry, operation and fault acceptance; stdlib only."""
import os
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUT = Path('/private/tmp/rk120-checks')
BINARY = os.environ.get('GODOT_BIN', '/Applications/Godot.app/Contents/MacOS/Godot')
ERROR = re.compile(r'^\s*(?:SCRIPT ERROR\b|ERROR:)', re.M)


def run(args, marker=None, expected_failure=None):
    result = subprocess.run([BINARY, '--path', str(ROOT / 'game')] + args,
                            cwd=ROOT, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True, timeout=45)
    if marker:
        OUT.joinpath(args[-1] + '.log').write_text(result.stdout)
    if ERROR.search(result.stdout):
        raise RuntimeError(result.stdout)
    if expected_failure:
        if (result.returncode != 1 or expected_failure not in result.stdout
                or result.stdout.splitlines().count('RK120_PROBE: failed') != 1
                or 'RK120_PROBE: passed' in result.stdout):
            raise RuntimeError('Negative not detected: ' + result.stdout)
        print('RK120 caught ' + args[-1] + ': ' + expected_failure)
    elif result.returncode or (marker and result.stdout.splitlines().count(marker) != 1):
        raise RuntimeError(result.stdout)


def probe(mode, failure=None):
    run(['-s', str(Path(__file__).with_name('rk120_probe.gd')), '--', str(OUT), mode],
        'RK120_PROBE: passed', failure)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    run(['--headless', '--import'])
    for mode in ('review', 'player'):
        probe(mode)
    probe('review_unbound', 'U+8D44 资')
    probe('player_unbound', 'U+4F4D 位')
    canvas = ROOT / 'game/app/dev/review_canvas.gd'
    original = canvas.read_bytes()
    old = '_draw_text(_overlay, get_theme_font("font"), target +'
    new = '_draw_text(_overlay, ThemeDB.fallback_font, target +'
    try:
        text = original.decode()
        if text.count(old) != 1:
            raise RuntimeError('target mutation anchor changed')
        canvas.write_text(text.replace(old, new))
        probe('review_target_default', 'U+5C55 展')
    finally:
        canvas.write_bytes(original)
    probe('player_clipped', 'geometry width ')
    # Locate the production fixture without assuming the exported asset subdirectory.
    matches = list((ROOT / 'game/assets').rglob('chr_knight_run.json'))
    if len(matches) != 1:
        raise RuntimeError('expected one knight run metadata')
    metadata = matches[0]
    original = metadata.read_bytes()
    try:
        data = json.loads(original)
        del data['frames'][0]['pivot']
        metadata.write_text(json.dumps(data))
        probe('review_bad')
    finally:
        metadata.write_bytes(original)
    # Positive rerun after every temporary fault has been restored.
    for mode in ('review', 'player'):
        probe(mode)
    print('RK120: passed')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (RuntimeError, subprocess.TimeoutExpired, OSError) as exc:
        print('RK120: failed: ' + str(exc))
        sys.exit(1)
