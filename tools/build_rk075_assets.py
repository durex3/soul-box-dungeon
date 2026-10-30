"""Export the editable RK075 native sources; never regenerate or overwrite them."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'art/source/rk075'
OUTPUT = ROOT / 'game/assets/sprites/greybox/rk075'
ASEPRITE = '/Applications/Aseprite.app/Contents/MacOS/aseprite'


def build(output: Path) -> None:
    output.mkdir(parents=True, exist_ok=True)
    for entry in json.loads((SOURCE / 'manifest.json').read_text())['assets']:
        path = output / entry['file']
        raw = path.with_suffix('.json')
        result = subprocess.run(
            [os.environ.get('ASEPRITE_BIN', ASEPRITE), '-b', '--tag', entry['tag'],
             str(ROOT / entry['source']), '--sheet-type', 'horizontal', '--shape-padding', '1',
             '--format', 'json-array', '--list-tags', '--list-layers',
             '--sheet', str(path), '--data', str(raw)], cwd=ROOT, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, text=True, timeout=45)
        if (result.returncode or re.search(r'^(?:Error:|ERROR:|lua:)', result.stdout, re.M)
                or not path.is_file() or not raw.is_file()):
            raise ValueError('Aseprite export failed: ' + entry['file'] + '\n' + result.stdout)
        data = json.loads(raw.read_text())
        data['meta']['image'] = entry['file']
        for frame in data['frames']:
            frame['filename'] = Path(frame['filename']).name
            frame['pivot'] = entry['pivot']
        for key in ('category', 'id', 'action', 'source', 'palette'):
            data['meta'][key] = entry[key]
        raw.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    print('RK075_EXPORT: 4 native-source exports completed', flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path, default=OUTPUT)
    args = parser.parse_args()
    try:
        build(args.output_dir.resolve())
    except (OSError, ValueError, subprocess.TimeoutExpired) as exc:
        print('RK075 export failed: ' + str(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
