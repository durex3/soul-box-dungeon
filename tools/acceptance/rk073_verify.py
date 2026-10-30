"""Validate RK073 delivery, re-export native sources, then optionally render previews."""
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
from pngio import read_rgba
from build_rk073_assets import build, MANIFEST, OUTPUT, ASEPRITE


def require(condition, message):
    if not condition:
        raise ValueError(message)


def validate(directory=OUTPUT):
    entries = json.loads(MANIFEST.read_text())['assets']
    expected = {'knight':(32,0), 'alchemist':(32,0), 'skeleton_rat':(16,24), 'crypt_zombie':(16,24),
                'charge_boar':(24,36), 'bone_archer':(24,36), 'blast_mushroom':(16,24),
                'slime':(16,24), 'fire_mage':(24,36), 'lava_golem':(32,48)}
    names = set()
    for entry in entries:
        id, action, elite = entry['id'], entry['action'], entry['elite']
        require(id in expected and action in ('idle','run') and type(elite) is bool, 'bad id/action/elite')
        n = expected[id][int(elite)]
        require(n > 0, 'unexpected elite hero')
        base = ('chr_' if id in ('knight','alchemist') else 'enm_') + id + ('_elite' if elite else '')
        name = base + '_' + action + '.png'
        require(entry['file'] == name and name not in names, 'bad filename or duplicate ' + name)
        names.add(name)
        require(entry['frame_size'] == {'w':n,'h':n} and entry['frames'] == 2, 'manifest size')
        require(entry['pivot'] == {'x':n//2,'y':n-3}, 'manifest pivot')
        require(entry['palette']==('ally' if id in ('knight','alchemist') else 'master'), 'palette mapping')
        require(entry['source'] == 'art/source/rk073/'+base+'.aseprite' and entry['tag']==action, 'source/tag')
        source = ROOT / entry['source']
        header = source.read_bytes()[:128]
        require(len(header)==128 and header[4:6]==b'\xe0\xa5' and int.from_bytes(header[6:8],'little')==4, 'native source header/4 frames')
        w,h,px = read_rgba(directory/name)
        require((w,h)==(2*n+1,n), 'PNG size '+name)
        require(all(px[y*w+n][3]==0 for y in range(n)), 'gap '+name)
        slices = [[px[y*w+x+f*(n+1)] for y in range(n) for x in range(n)] for f in range(2)]
        require(slices[0]!=slices[1], 'identical poses '+name)
        require(all(any(c[3] for c in frame) for frame in slices), 'empty frame '+name)
        data=json.loads((directory/Path(name).with_suffix('.json')).read_text())
        require(len(data['frames'])==2, 'JSON frame count '+name)
        require(data['meta']['id']==id and type(data['meta']['elite']) is bool and data['meta']['elite']==elite and data['meta']['action']==action, 'JSON identity')
        require(data['meta']['image']==name and data['meta']['source']==entry['source'], 'JSON paths')
        require(data['meta']['size']=={'w':w,'h':h}, 'JSON sheet size')
        require({l['name'] for l in data['meta']['layers']} >= {'Body','Shadow'}, 'editable layers')
        require([(t['name'],t['from'],t['to']) for t in data['meta']['frameTags']]==[('idle',0,1),('run',2,3)], 'source tag ranges')
        for i,frame in enumerate(data['frames']):
            require(frame['frame']=={'x':i*(n+1),'y':0,'w':n,'h':n}, 'frame rectangle '+name)
            require(frame['pivot']==entry['pivot'] and not frame['trimmed'] and not frame['rotated'], 'frame pivot/trim')
            require(frame['duration']==(167 if action=='idle' else 83), 'frame timing '+name)
    require(len(names)==36 and names=={p.name for p in directory.glob('*.png')}, 'delivery must have exact 36 PNG')
    require({(ROOT/e['source']).resolve() for e in entries}==set((ROOT/'art/source/rk073').glob('*.aseprite')), 'exact 18 native sources')
    require({Path(n).with_suffix('.json').name for n in names}=={p.name for p in directory.glob('*.json')}, 'exact 36 JSON')
    with (ROOT/'art/ai_log.csv').open(encoding='utf-8-sig',newline='') as stream:
        records=list(csv.DictReader(stream))
    for entry in entries:
        rows=[r for r in records if r['资源文件名']==entry['file']]
        require(len(rows)==1 and rows[0]['接口名']=='手绘' and rows[0]['原始文件名']==entry['source'], 'provenance '+entry['file'])
    print('RK073: 36 PNG / 36 JSON / 18 native sources / provenance validated',flush=True)
    return entries


def godot(arguments, headless=True):
    binary=os.environ.get('GODOT_BIN','/Applications/Godot.app/Contents/MacOS/Godot')
    result=subprocess.run([binary]+(['--headless'] if headless else [])+['--path',str(ROOT/'game')]+arguments,
                          cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=45)
    print(result.stdout,flush=True)
    require(result.returncode==0 and not re.search(r'^\s*(?:ERROR:|SCRIPT ERROR\b)',result.stdout,re.M), 'Godot failed')
    return result.stdout


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--preview',action='store_true',help='launch graphical Godot to render 1x/3x and silhouette pages')
    parser.add_argument('--output-dir',type=Path,default=Path('/private/tmp/rk073-checks'))
    args=parser.parse_args()
    try:
        entries=validate()
        native=subprocess.run([os.environ.get('ASEPRITE_BIN',ASEPRITE),'-b','--script-param','root='+str(ROOT),
                               '--script',str(ROOT/'art/source/rk073/audit_sources.lua')],
                              stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=45,cwd=ROOT)
        print(native.stdout,flush=True)
        require(native.returncode==0 and native.stdout.splitlines().count('RK073_SOURCES: passed')==1,
                'native Aseprite layer/tag/frame/pivot audit failed')
        with tempfile.TemporaryDirectory(prefix='rk073-rebuild-') as directory:
            target=Path(directory)
            build(target)
            for entry in entries:
                name=entry['file']
                require(read_rgba(OUTPUT/name)==read_rgba(target/name),'re-export pixel mismatch '+name)
                meta=Path(name).with_suffix('.json')
                require(json.loads((OUTPUT/meta).read_text())==json.loads((target/meta).read_text()),'re-export metadata mismatch '+name)
        print('RK073: native-source re-export matches all production pixels/metadata',flush=True)
        godot(['--import'])
        if args.preview:
            output=args.output_dir.resolve();output.mkdir(parents=True,exist_ok=True)
            result=godot(['-s',str(Path(__file__).with_name('rk073_preview.gd')),'--',str(output)],headless=False)
            require(result.splitlines().count('RK073_PREVIEW: passed')==1,'missing preview marker')
            for page in (1,2):
                for prefix,scale in [('poses',1),('poses',3),('silhouette',1)]:
                    w,h,_=read_rgba(output/('%s_%d_%dx.png'%(prefix,page,scale)))
                    require((w,h)==(640*scale,360*scale),'preview dimensions')
            answers=[dict(number=i+1,id=entries[i*2]['id'],elite=entries[i*2]['elite'],page=i//9+1) for i in range(18)]
            (output/'silhouette_answers.json').write_text(json.dumps(answers,indent=2)+'\n')
        print('RK073: passed',flush=True)
        return 0
    except (OSError,ValueError,KeyError,TypeError,subprocess.TimeoutExpired) as exc:
        print('RK073: failed: '+str(exc),flush=True)
        return 1


if __name__=='__main__':
    sys.exit(main())
