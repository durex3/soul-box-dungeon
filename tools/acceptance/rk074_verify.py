"""Audit RK074 native assets, formal SoulTable mapping, rebuild and graphical previews."""
import argparse
import csv
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from build_rk074_assets import build,SOURCE,OUTPUT,ASEPRITE
from pngio import read_rgba
COLORS=dict(fire='FF8A1F',frost='A8EEFF',lightning='4F7BFF',mechanical='C9A25E',undead='5FD38D',holy='FFE8A3',melee='B8C2CC')
PICKS={'xp_small':(4,'B48CFF'),'xp_medium':(6,'B48CFF'),'xp_large':(8,'B48CFF'),'soul_crystal':(6,'FFC93C'),'energy':(6,'3DF2C5')}

def require(condition,message):
    if not condition:raise ValueError(message)

def rgb(code):return tuple(bytes.fromhex(code))+(255,)

def run(command,marker=None):
    result=subprocess.run(command,cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=45)
    print(result.stdout,flush=True)
    require(result.returncode==0 and not re.search(r'^\s*(?:ERROR:|SCRIPT ERROR\b|Error:|lua:)',result.stdout,re.M),'subprocess failed')
    if marker:require(result.stdout.splitlines().count(marker)==1,'missing unique marker '+marker)
    return result.stdout

def godot(arguments,graphical=False,marker=None):
    return run([os.environ.get('GODOT_BIN','/Applications/Godot.app/Contents/MacOS/Godot')]+([] if graphical else ['--headless'])+['--path',str(ROOT/'game')]+arguments,marker)

def validate(table,directory=OUTPUT):
    entries=json.loads((SOURCE/'manifest.json').read_text())['assets']
    require(len(table)==12,'formal SoulTable must contain 12 prototype souls')
    expected={'box_'+id+'_t'+str(t)+'.png' for id in table for t in range(1,5)}
    expected|={'pick_'+id+'.png' for id in PICKS}
    expected|={'ui_tag_'+tag+'.png' for tag in COLORS}
    require(len(entries)==60 and {e['file'] for e in entries}==expected,'exact 60 asset manifest')
    require({p.name for p in directory.glob('*.png')}==expected,'exact production PNG set')
    require({p.stem for p in directory.glob('*.json')}=={Path(n).stem for n in expected},'exact JSON set')
    require({p.name for p in SOURCE.glob('*.aseprite')}=={Path(n).with_suffix('.aseprite').name for n in expected},'exact native source set')
    for e in entries:
        name=e['file'];cat=e['category'];tier=e.get('tier',0)
        if name.startswith('box_'):
            require(cat=='soul' and e['id'] in table and tier in (1,2,3,4),'soul identity')
            require(e['tags']==table[e['id']],'SoulTable tag order mismatch '+name)
            require(name=='box_'+e['id']+'_t'+str(tier)+'.png','tier filename')
            n,size,x,y={1:(6,6,0,0),2:(8,8,0,0),3:(10,8,2,1),4:(12,10,1,1)}[tier]
            body=dict(x=x,y=y,w=size,h=size)
        elif name.startswith('pick_'):
            require(cat=='pickup' and e['id'] in PICKS and not tier and e['tags']==[],'pickup identity')
            require(name=='pick_'+e['id']+'.png','pickup filename')
            n=PICKS[e['id']][0];body=dict(x=0,y=0,w=n,h=n)
        else:
            require(cat=='tag' and e['id'] in COLORS and e['tags']==[e['id']] and not tier,'icon identity')
            require(name=='ui_tag_'+e['id']+'.png','icon filename')
            n=8;body=dict(x=0,y=0,w=8,h=8)
        pivot=dict(x=body['x']+body['w']/2,y=body['y']+body['h']/2)
        require(e['canvas_size']=={'w':n,'h':n} and e['body_rect']==body and e['pivot']==pivot,'canvas/body/pivot '+name)
        require(e['source']=='art/source/rk074/'+Path(name).with_suffix('.aseprite').name and e['palette']=='ally','source/palette')
        w,h,pixels=read_rgba(directory/name);require((w,h)==(n,n),'PNG dimensions '+name)
        require(any(p[3] for p in pixels) and all(p[3] in (0,255) for p in pixels),'empty/semitransparent '+name)
        require(all(p[:3] not in ((255,46,151),(255,59,48),(0,0,0),(255,255,255)) for p in pixels if p[3]),'reserved color '+name)
        decor={(0,7),(1,6)} if tier==3 else ({(0,0),(11,0),(0,11),(11,11)} if tier==4 else set())
        for yy in range(n):
            for xx in range(n):
                pixel=pixels[yy*n+xx]
                if cat=='soul':
                    in_body=body['x']<=xx<body['x']+body['w'] and body['y']<=yy<body['y']+body['h']
                    if not in_body:
                        require(bool(pixel[3])==((xx,yy) in decor),'decor structure '+name)
                        if pixel[3]:require(pixel==rgb(COLORS[e['tags'][0]]),'decor color '+name)
                    else:
                        disk=((xx+0.5-pivot['x'])/(body['w']/2))**2+((yy+0.5-pivot['y'])/(body['h']/2))**2<=1
                        require(bool(pixel[3])==disk,'native orb body shape '+name)
                        if pixel[3]:
                            core=tier>=2 and (xx,yy)==(body['x']+body['w']//2-1,body['y']+body['h']//2-1)
                            tag=e['tags'][1] if len(e['tags'])==2 and xx>=pivot['x'] else e['tags'][0]
                            require(pixel==rgb('F0F0F0' if core else COLORS[tag]),'body/core/left-right color '+name)
                elif pixel[3]:
                    require(pixel==rgb(COLORS[e['id']] if cat=='tag' else PICKS[e['id']][1]),'pickup/icon functional color '+name)
        data=json.loads((directory/Path(name).with_suffix('.json')).read_text())
        require(len(data['frames'])==1,'static frame count')
        frame=data['frames'][0]
        require(frame['frame']==dict(x=0,y=0,w=n,h=n) and frame['pivot']==pivot and frame['body_rect']==body,'frame/body/pivot '+name)
        require(not frame['trimmed'] and not frame['rotated'],'trim/rotation')
        require(data['meta']['size']=={'w':n,'h':n} and data['meta']['image']==name,'sheet size/path')
        for key in ('category','id','tags','source','palette'):require(data['meta'][key]==e[key],'metadata '+key)
        require(data['meta'].get('tier',0)==tier,'metadata tier')
    with (ROOT/'art/ai_log.csv').open(encoding='utf-8-sig',newline='') as stream:records=list(csv.DictReader(stream))
    require(len(records)==96,'preserve old 36 + append 60 provenance records')
    for e in entries:
        rows=[r for r in records if r['资源文件名']==e['file']]
        require(len(rows)==1 and rows[0]['接口名']=='手绘' and rows[0]['原始文件名']==e['source'],'provenance '+e['file'])
    print('RK074: 48 souls / 5 pickups / 7 icons; native metadata, colors, tiers, pivots and table tags checked',flush=True)
    return entries

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--preview',action='store_true')
    parser.add_argument('--output-dir',type=Path,default=Path('/private/tmp/rk074-checks'))
    args=parser.parse_args()
    try:
        godot(['--import'])
        probe=['-s',str(Path(__file__).with_name('rk074_preview.gd'))]
        output=godot(probe,marker='RK074_PROBE: passed')
        tables=[line.removeprefix('RK074_TABLE ') for line in output.splitlines() if line.startswith('RK074_TABLE ')]
        require(len(tables)==1,'missing unique SoulTable result')
        entries=validate(json.loads(tables[0]))
        run([os.environ.get('ASEPRITE_BIN',ASEPRITE),'-b','--script-param','root='+str(ROOT),
             '--script',str(SOURCE/'audit_sources.lua')],'RK074_SOURCES: passed')
        with tempfile.TemporaryDirectory(prefix='rk074-rebuild-') as temp:
            target=Path(temp);build(target)
            for e in entries:
                name=e['file'];meta=Path(name).with_suffix('.json')
                require(read_rgba(OUTPUT/name)==read_rgba(target/name),'native rebuild pixels '+name)
                require(json.loads((OUTPUT/meta).read_text())==json.loads((target/meta).read_text()),'native rebuild metadata '+name)
        if args.preview:
            out=args.output_dir.resolve();out.mkdir(parents=True,exist_ok=True)
            godot(probe+['--',str(out)],graphical=True,marker='RK074_PROBE: passed')
            for name in ('all','guides'):
                w,h,small=read_rgba(out/(name+'_1x.png'));W,H,large=read_rgba(out/(name+'_3x.png'))
                require((w,h,W,H)==(640,360,1920,1080),'preview dimensions')
                for y in range(h):
                    for x in range(w):
                        for dy in range(3):
                            require(large[(y*3+dy)*W+x*3:(y*3+dy)*W+x*3+3]==[small[y*w+x]]*3,'nearest 3x pixels')
            answers={str(i+1):tag for i,tag in enumerate(COLORS)}
            (out/'icons_answers.json').write_text(json.dumps(answers,indent=2)+'\n')
        print('RK074: passed',flush=True);return 0
    except (OSError,ValueError,KeyError,TypeError,subprocess.TimeoutExpired) as exc:
        print('RK074: failed: '+str(exc),flush=True);return 1
if __name__=='__main__':sys.exit(main())
