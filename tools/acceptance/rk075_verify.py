"""Audit native Boss sources, deterministic exports and actual Godot graphical review."""
import argparse
import csv
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from build_rk075_assets import build, SOURCE, OUTPUT, ASEPRITE
from pngio import read_rgba

SPECS = {'gravekeeper': 64, 'furnace_colossus': 96}


def require(value, message):
    if not value:
        raise ValueError(message)


def run(command, marker):
    result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True, timeout=45)
    print(result.stdout, flush=True)
    require(not result.returncode and not re.search(r'^\s*(?:ERROR:|SCRIPT ERROR\b|Error:|lua:)', result.stdout, re.M), 'subprocess error')
    require(result.stdout.splitlines().count(marker) == 1, 'missing unique marker ' + marker)


def godot(arguments, graphical=False, marker='RK075_PREVIEW: passed'):
    command = [os.environ.get('GODOT_BIN', '/Applications/Godot.app/Contents/MacOS/Godot')]
    run(command + ([] if graphical else ['--headless']) + ['--path', str(ROOT / 'game')] + arguments, marker)


def validate(directory=OUTPUT):
    entries = json.loads((SOURCE / 'manifest.json').read_text())['assets']
    expected = {'bos_' + id + '_' + action + '.png' for id in SPECS for action in ('idle', 'run')}
    require(len(entries) == 4 and {e['file'] for e in entries} == expected, 'exact four manifest identities')
    require({p.name for p in directory.glob('*.png')} == expected, 'exact four PNG')
    require({p.name for p in directory.glob('*.json')} == {Path(n).with_suffix('.json').name for n in expected}, 'exact four JSON')
    require({p.name for p in SOURCE.glob('*.aseprite')} == {'bos_' + id + '.aseprite' for id in SPECS}, 'exact two native sources')
    with (ROOT / 'art/ai_log.csv').open(encoding='utf-8-sig', newline='') as stream:
        records = list(csv.DictReader(stream))
    for e in entries:
        id, action, name = e['id'], e['action'], e['file']
        n = SPECS[id]
        require(name == 'bos_' + id + '_' + action + '.png' and action in ('idle', 'run'), 'filename/action')
        require(e['category'] == 'boss' and e['frames'] == 2 and e['palette'] == 'master', 'category/frames/palette')
        require(e['frame_size'] == dict(w=n, h=n) and e['pivot'] == dict(x=n // 2, y=n - 3), 'manifest size/pivot')
        require(e['source'] == 'art/source/rk075/bos_' + id + '.aseprite' and e['tag'] == action, 'source/tag')
        header = (ROOT / e['source']).read_bytes()[:128]
        require(header[4:6] == b'\xe0\xa5' and int.from_bytes(header[6:8], 'little') == 4, 'native four-frame header')
        w, h, pixels = read_rgba(directory / name)
        require((w, h) == (n * 2 + 1, n), 'sheet dimensions ' + name)
        require(all(pixels[y * w + n][3] == 0 for y in range(n)), 'transparent gap ' + name)
        require(all(p[3] in (0, 255) for p in pixels), 'opaque alpha ' + name)
        forbidden = {(255, 46, 151), (255, 59, 48), (255, 255, 255), (0, 0, 0)}
        require(all(p[:3] not in forbidden for p in pixels if p[3]), 'reserved body colors ' + name)
        poses = [[pixels[y * w + x + i * (n + 1)] for y in range(n) for x in range(n)] for i in range(2)]
        require(poses[0] != poses[1], 'distinct poses ' + name)
        for pose in poses:
            body = [(i % n, i // n) for i, p in enumerate(pose) if p[3] and p[:3] != (11, 10, 18)]
            require(body and max(y for x, y in body) == n - 4, 'body baseline ' + name)
            require(all(0 < x < n - 1 and 0 < y < n - 1 for x, y in body), 'body/weapon crop ' + name)
        data = json.loads((directory / Path(name).with_suffix('.json')).read_text())
        require(len(data['frames']) == 2, 'frame count ' + name)
        for key in ('id', 'action', 'category', 'source', 'palette'):
            require(data['meta'][key] == e[key], 'metadata ' + key)
        require(data['meta']['image'] == name and data['meta']['size'] == dict(w=w, h=h), 'sheet metadata')
        require({l['name'] for l in data['meta']['layers']} == {'Body', 'Shadow'}, 'layer metadata')
        require([(t['name'], t['from'], t['to']) for t in data['meta']['frameTags']] == [('idle', 0, 1), ('run', 2, 3)], 'tag metadata')
        for i, frame in enumerate(data['frames']):
            require(frame['frame'] == dict(x=i * (n + 1), y=0, w=n, h=n), 'frame rectangle ' + name)
            require(frame['sourceSize'] == dict(w=n, h=n) and not frame['trimmed'] and not frame['rotated'], 'source size/trim')
            require(frame['pivot'] == e['pivot'] and frame['duration'] == (167 if action == 'idle' else 83), 'pivot/duration ' + name)
        rows = [r for r in records if r['资源文件名'] == name]
        require(len(rows) == 1 and rows[0]['接口名'] == '手绘' and rows[0]['原始文件名'] == e['source'], 'provenance ' + name)
    print('RK075: exact 4 PNG / 4 JSON / 2 native sources; baseline, tags, timing and provenance checked', flush=True)
    return entries


def check_nearest(out):
    w, h, small = read_rgba(out / 'poses_1x.png')
    W, H, large = read_rgba(out / 'poses_3x.png')
    require((w, h, W, H) == (640, 360, 1920, 1080), 'preview dimensions')
    for y in range(h):
        for x in range(w):
            for dy in range(3):
                require(large[(y * 3 + dy) * W + x * 3:(y * 3 + dy) * W + x * 3 + 3] == [small[y * w + x]] * 3, 'nearest 3x block')
    require(read_rgba(out / 'silhouettes_1x.png')[:2] == (640, 360), 'blind native image dimensions')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path, default=Path('/private/tmp/rk075-checks'))
    args = parser.parse_args()
    try:
        # Import emits no custom script marker; use a separate bounded check.
        result = subprocess.run([os.environ.get('GODOT_BIN', '/Applications/Godot.app/Contents/MacOS/Godot'),
                                 '--headless', '--path', str(ROOT / 'game'), '--import'], cwd=ROOT,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=45)
        print(result.stdout, flush=True)
        require(not result.returncode and not re.search(r'^\s*(?:ERROR:|SCRIPT ERROR\b)', result.stdout, re.M), 'import error')
        entries = validate()
        run([os.environ.get('ASEPRITE_BIN', ASEPRITE), '-b', '--script-param', 'root=' + str(ROOT),
             '--script', str(SOURCE / 'audit_sources.lua')], 'RK075_SOURCES: passed')
        with tempfile.TemporaryDirectory(prefix='rk075-rebuild-') as temp:
            target = Path(temp)
            build(target)
            for e in entries:
                name = e['file']; meta = Path(name).with_suffix('.json')
                require(read_rgba(OUTPUT / name) == read_rgba(target / name), 'native re-export pixels ' + name)
                require(json.loads((OUTPUT / meta).read_text()) == json.loads((target / meta).read_text()), 'native re-export metadata ' + name)
        out = args.output_dir.resolve(); out.mkdir(parents=True, exist_ok=True)
        godot(['-s', str(Path(__file__).with_name('rk075_preview.gd')), '--', str(out)], graphical=True)
        check_nearest(out)
        godot(['-s', str(Path(__file__).with_name('rk075_interact.gd')), '--', str(out)], graphical=True, marker='RK075_UI: passed')
        print('RK075: passed', flush=True)
        return 0
    except (OSError, ValueError, KeyError, TypeError, subprocess.TimeoutExpired) as exc:
        print('RK075: failed: ' + str(exc), flush=True)
        return 1


if __name__ == '__main__':
    sys.exit(main())
