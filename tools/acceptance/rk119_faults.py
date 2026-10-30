"""Deliberate breakage acceptance; restore exact original bytes in finally blocks."""
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
VERIFY = Path(__file__).with_name('rk119_ui_verify.py')


def probe(arguments=()):
    result = subprocess.run([sys.executable, str(VERIFY)] + list(arguments), cwd=ROOT,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, timeout=55)
    print(result.stdout, end='', flush=True)
    return result


def main():
    path = ROOT / 'game/assets/sprites/greybox/rk073/chr_knight_run.json'
    original = path.read_bytes()
    cases = ('rect', 'pivot', 'image', 'json')
    for case in cases:
        data = json.loads(original)
        if case == 'rect':
            data['frames'][0]['frame']['x'] = 99999
        elif case == 'pivot':
            del data['frames'][0]['pivot']
        elif case == 'image':
            data['meta']['image'] = 'rk119_intentionally_missing.png'
        try:
            path.write_text('{' if case == 'json' else json.dumps(data))
            result = probe(['--bad'])
            if result.returncode:
                raise ValueError('Bad resource UI failed: ' + case)
            print('RK119 fault detected: ' + case, flush=True)
        finally:
            path.write_bytes(original)
    script = ROOT / 'game/app/dev/asset_review_lab.gd'
    original_script = script.read_bytes()
    before = b'(widgets.controls["Next"] as Button).pressed.connect(_step.bind(1))'
    after = b'(widgets.controls["Next"] as Button).pressed.connect(_toggle_play)'
    if original_script.count(before) != 1:
        raise ValueError('Step mutation target must occur exactly once')
    try:
        script.write_bytes(original_script.replace(before, after))
        result = probe()
        if result.returncode != 1 or 'RK119 UI FAIL next advances exactly one and pauses' not in result.stdout:
            raise ValueError('Step mutation escaped the actual mouse-input check')
        print('RK119 fault detected: next incorrectly starts playing', flush=True)
    finally:
        script.write_bytes(original_script)
    if path.read_bytes() != original or script.read_bytes() != original_script:
        raise ValueError('Fault restoration failed')
    if probe().returncode:
        raise ValueError('Restored graphical regression failed')
    print('RK119_FAULTS: passed; exact original bytes restored', flush=True)
    return 0


if __name__ == '__main__':
    sys.exit(main())
