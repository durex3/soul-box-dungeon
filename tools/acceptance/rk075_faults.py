"""Deliberate mutations required by RK075; restore exact original bytes every time."""
import csv
import io
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from pngio import read_rgba, write_rgba
from acceptance.rk075_verify import validate, godot
from acceptance.rk074_verify import validate_original_records


def must_fail(action, label):
    try:
        action()
    except ValueError as exc:
        print('RK075 fault caught: ' + label + ': ' + str(exc), flush=True)
        return
    raise ValueError('Mutation escaped checks: ' + label)


def main():
    png = ROOT / 'game/assets/sprites/greybox/rk075/bos_gravekeeper_idle.png'
    original = png.read_bytes()
    try:
        w, h, pixels = read_rgba(png)
        pixels[64] = (237, 227, 204, 255)
        write_rgba(png, w, h, pixels)
        result = subprocess.run([sys.executable, str(ROOT / 'tools/art_check.py'), str(png)],
                                cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=45)
        if result.returncode != 1:
            raise ValueError('Corrupt gap escaped art_check')
        print('RK075 fault caught: gap art_check exit=1\n' + result.stdout, flush=True)
    finally:
        png.write_bytes(original)
    meta = png.with_suffix('.json')
    original = meta.read_bytes()
    out = Path('/private/tmp/rk075-checks/fault-scroll')
    out.mkdir(parents=True, exist_ok=True)
    for field in ('pivot', 'frame'):
        try:
            data = json.loads(original)
            data['frames'][0][field]['x'] = 99999
            meta.write_text(json.dumps(data))
            must_fail(validate, 'JSON ' + field)
            godot(['-s', str(Path(__file__).with_name('rk075_interact.gd')), '--', str(out), '--bad'],
                  graphical=True, marker='RK075_BAD: passed')
        finally:
            meta.write_bytes(original)
    provenance = ROOT / 'art/ai_log.csv'
    original = provenance.read_bytes()
    records = list(csv.DictReader(io.StringIO(original.decode('utf-8-sig'))))
    for duplicate in (False, True):
        try:
            rows = [r.copy() for r in records]
            index = next(i for i, r in enumerate(rows) if r['资源文件名'] == 'box_fireball_t4.png')
            if duplicate:
                rows.append(rows[index].copy())
            else:
                rows.pop(index)
            with provenance.open('w', encoding='utf-8-sig', newline='') as stream:
                writer = csv.DictWriter(stream, fieldnames=list(records[0]))
                writer.writeheader(); writer.writerows(rows)
            with provenance.open(encoding='utf-8-sig', newline='') as stream:
                actual = list(csv.DictReader(stream))
            must_fail(lambda: validate_original_records(actual), 'duplicate provenance' if duplicate else 'missing provenance')
        finally:
            provenance.write_bytes(original)
    validate_original_records(records)
    script = ROOT / 'game/app/dev/review_canvas.gd'
    original = script.read_bytes()
    target = b'if not frame.is_empty() and frame["rect"].size.y > 48:'
    if original.count(target) != 2:
        raise ValueError('Large-layout mutation must match exactly two branches')
    try:
        script.write_bytes(original.replace(target, b'if false and not frame.is_empty() and frame["rect"].size.y > 48:'))
        result = subprocess.run([os.environ.get('GODOT_BIN', '/Applications/Godot.app/Contents/MacOS/Godot'),
                                 '--path', str(ROOT / 'game'), '-s', str(Path(__file__).with_name('rk075_interact.gd')),
                                 '--', str(out)], cwd=ROOT, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True, timeout=45)
        print(result.stdout, flush=True)
        if (result.returncode != 1 or 'RK075 UI FAIL furnace_colossus_idle_640 full 1x/3x canvas in scroll plane' not in result.stdout
                or 'SCRIPT ERROR' in result.stdout or 'ERROR:' in result.stdout):
            raise ValueError('Disabled large canvas/scroll mutation escaped the specific clipping check')
        print('RK075 fault caught: disabled large canvas/scroll adaptation', flush=True)
    finally:
        script.write_bytes(original)
    print('RK075_FAULTS: passed; all original bytes restored', flush=True)
    return 0


if __name__ == '__main__':
    sys.exit(main())
