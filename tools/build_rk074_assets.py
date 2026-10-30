"""Export editable RK074 native sources without regenerating or modifying them."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'art/source/rk074'
OUTPUT=ROOT/'game/assets/sprites/greybox/rk074'
ASEPRITE='/Applications/Aseprite.app/Contents/MacOS/aseprite'


def build(output: Path) -> None:
    output.mkdir(parents=True,exist_ok=True)
    for entry in json.loads((SOURCE/'manifest.json').read_text())['assets']:
        path=output/entry['file']; raw=path.with_suffix('.json')
        result=subprocess.run([os.environ.get('ASEPRITE_BIN',ASEPRITE),'-b',str(ROOT/entry['source']),
                               '--sheet',str(path),'--data',str(raw),'--format','json-array','--list-layers'],
                              cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=45)
        if result.returncode or not path.is_file() or not raw.is_file():
            raise ValueError('Aseprite export failed: '+entry['file']+'\n'+result.stdout)
        data=json.loads(raw.read_text());data['meta']['image']=entry['file']
        for frame in data['frames']:
            frame['filename']=Path(frame['filename']).name
            frame['pivot']=entry['pivot'];frame['body_rect']=entry['body_rect']
        data['meta'].update({key:entry[key] for key in ('category','id','tags','source','palette')})
        if 'tier' in entry:data['meta']['tier']=entry['tier']
        raw.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    print('RK074_EXPORT: 60 native-source exports completed',flush=True)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir',type=Path,default=OUTPUT)
    args=parser.parse_args()
    try:build(args.output_dir.resolve())
    except (OSError,ValueError,subprocess.TimeoutExpired) as exc:
        print('RK074 export failed: '+str(exc),file=sys.stderr);return 1
    return 0
if __name__=='__main__':sys.exit(main())
