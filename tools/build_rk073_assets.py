"""Export RK-073 native Aseprite sources; never regenerate or overwrite source art."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'art/source/rk073/manifest.json'
ASEPRITE = '/Applications/Aseprite.app/Contents/MacOS/aseprite'
OUTPUT = ROOT / 'game/assets/sprites/greybox/rk073'


def build(output: Path, binary: str = None) -> None:
    output.mkdir(parents=True, exist_ok=True)
    for entry in json.loads(MANIFEST.read_text())['assets']:
        name = entry['file']
        source = ROOT / entry['source']
        raw = output / (Path(name).stem + '.json')
        command = [binary or os.environ.get('ASEPRITE_BIN', ASEPRITE), '-b', '--tag', entry['action'],
                   str(source), '--sheet-type', 'horizontal', '--shape-padding', '1',
                   '--format', 'json-array', '--list-tags', '--list-layers',
                   '--sheet', str(output / name), '--data', str(raw)]
        result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True, timeout=45)
        if result.returncode != 0 or not raw.is_file() or not (output / name).is_file():
            raise ValueError('Aseprite export failed: %s\n%s' % (name, result.stdout))
        data = json.loads(raw.read_text())
        # Retain actual Aseprite frame rectangles, timing, layers and tags; normalize paths.
        data['meta']['image'] = name
        for frame in data['frames']:
            frame['filename'] = Path(frame['filename']).name
            frame['pivot'] = entry['pivot']
        data['meta']['id'] = entry['id']
        data['meta']['elite'] = entry['elite']
        data['meta']['action'] = entry['action']
        data['meta']['source'] = entry['source']
        raw.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
        print('EXPORTED ' + name, flush=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path, default=OUTPUT)
    args = parser.parse_args()
    try:
        build(args.output_dir.resolve())
    except (OSError, ValueError, subprocess.TimeoutExpired) as exc:
        print('RK073 export failed: %s' % exc, file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
