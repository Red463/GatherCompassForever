"""Generate supplied zone masks from a read-only local Forever snapshot.

No game-install writes or external extraction executables. Raw data stays local.
"""
from pathlib import Path
import argparse,hashlib,json,math,sys,zlib

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'.test-deps'))
sys.path.insert(0,str(ROOT/'tools/terrain'))
from PIL import Image
from local_casc import LocalCasc
from rules import TILE,CELL,ORIGIN,chunks,tile_mask,cleanup,encode_rows


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--snapshot-root',type=Path,default=ROOT.parent/'output/forever-datamine-70959')
    parser.add_argument('--output',type=Path,default=ROOT/'Data/Terrain.lua')
    parser.add_argument('--artifacts',type=Path,default=ROOT.parent/'output/terrain-overlays-70959')
    parser.add_argument('--zone',type=int,action='append')
    args=parser.parse_args();src=args.snapshot_root.resolve();out=args.artifacts.resolve()
    # All writes are explicitly separate from the read-only snapshot.
    if out.is_relative_to(src/'snapshot') or args.output.resolve().is_relative_to(src/'snapshot'):
        raise ValueError('Outputs must not be inside the snapshot')
    out.mkdir(parents=True,exist_ok=True);cache=out/'tile-cache';cache.mkdir(exist_ok=True)
    ui=json.loads((ROOT/'tools/terrain/zones.json').read_text())['zones']
    casc=LocalCasc(src);wdts={};inventory=[];zones={};hashes={}
    def wdt_for(mapid,fdid):
        if mapid not in wdts:
            data=casc.read_fdid(fdid)
            wdts[mapid]=next(data[a:b] for tag,a,b in chunks(data) if tag=='MAID')
        return wdts[mapid]
    def tile(fdid):
        p=cache/f'{fdid}.zlib'
        if p.exists():return zlib.decompress(p.read_bytes())
        data=casc.read_fdid(fdid);hashes[fdid]=hashlib.sha256(data).hexdigest()
        result=tile_mask(data);p.write_bytes(zlib.compress(result));return result
    for index,u in enumerate(ui):
        id=u['id'];name=u['name']
        if args.zone and id not in args.zone:continue
        row=dict(id=id,name=name,status='unavailable')
        if u['type'] not in (3,6) or 'wdt' not in u:
            row['reason']='Overview map: use a local zone for routing';inventory.append(row);zones[id]=row;continue
        try:
            mapid=u['terrainMap'];maid=wdt_for(mapid,u['wdt'])
            north,south=u['north'],u['south']
            west,east=u['west'],u['east']
            if north<=south or west<=east:raise ValueError('Invalid map bounds')
            tx0,tx1=math.floor((ORIGIN-west)/TILE),math.floor((ORIGIN-east)/TILE)
            ty0,ty1=math.floor((ORIGIN-north)/TILE),math.floor((ORIGIN-south)/TILE)
            if not(0<=tx0<=tx1<64 and 0<=ty0<=ty1<64):raise ValueError('Map outside indexed terrain')
            mw,mh=(tx1-tx0+1)*128,(ty1-ty0+1)*128
            mosaic=Image.new('L',(mw,mh),64);missing=[];decoded=0
            for ty in range(ty0,ty1+1):
                for tx in range(tx0,tx1+1):
                    fdid=int.from_bytes(maid[(ty*64+tx)*32:(ty*64+tx)*32+4],'little')
                    if not fdid:missing.append([tx,ty,'no tile']);continue
                    try:
                        data=tile(fdid)
                        mosaic.paste(Image.frombytes('L',(128,128),data),((tx-tx0)*128,(ty-ty0)*128));decoded+=1
                    except (ValueError,FileNotFoundError,StopIteration,NotImplementedError) as error:
                        missing.append([tx,ty,str(error)])
            w,h=math.ceil((west-east)/CELL),math.ceil((north-south)/CELL)
            crop=((ORIGIN-west)/CELL-tx0*128,(ORIGIN-north)/CELL-ty0*128,(ORIGIN-east)/CELL-tx0*128,(ORIGIN-south)/CELL-ty0*128)
            raw=mosaic.transform((w,h),Image.Transform.EXTENT,crop,Image.Resampling.NEAREST).tobytes()
            cleaned,stats=cleanup(raw,w,h)
            image=Image.frombytes('L',(w,h),cleaned);image.save(out/f'{id}.png')
            allowed=sum(v in (128,255) for v in cleaned);unknown=cleaned.count(64)
            row.update(w=w,h=h,widthYards=west-east,heightYards=north-south,terrainMap=int(mapid),
                       status='complete' if unknown==0 else 'partial',allowedCells=allowed,
                       missingCells=unknown,decodedTiles=decoded,missingTiles=missing,**stats)
            if not allowed:row.update(status='unavailable',reason='No usable permitted terrain in this map')
            row['maskSha256']=hashlib.sha256(cleaned).hexdigest()
            row['rows']=encode_rows(cleaned,w,h)
            if id==1440:
                expected=ROOT.parent/'output/ashenvale-generated-overlay-50deg-connected/Ashenvale-connected-mask.png'
                if expected.exists():
                    assert Image.open(expected).tobytes()==cleaned,'Ashenvale final-rule regression'
                    row['ashenvaleRegression']='byte-identical'
            zones[id]=row;inventory.append({k:v for k,v in row.items() if k!='rows'})
            print(f'{index+1}/{len(ui)} {id} {name}: {row["status"]}, {w}x{h}, {allowed} permitted',flush=True)
        except (ValueError,FileNotFoundError,KeyError,StopIteration,NotImplementedError) as error:
            row['reason']=f'Terrain unavailable: {error}';zones[id]=row;inventory.append(row)
            print(f'{id} {name}: {row["reason"]}',flush=True)
    lines=['-- Generated from Forever 1.60.1.70959; terrain heuristic, not collision geometry.',
           '-- Own generator: tools/build_terrain.py. Swimming/backtracking allowed.',
           'local _,A=...', 'A.TerrainData={version=1,build=70959,zones={}}','local Z=A.TerrainData.zones']
    for id,row in sorted(zones.items()):
        fields=[]
        for k in ('name','status','reason','w','h','widthYards','heightYards','terrainMap','maskSha256'):
            if k in row:fields.append(k+'='+json.dumps(row[k],ensure_ascii=True))
        lines.append(f'Z[{id}]={{'+','.join(fields)+',rows={')
        lines.extend('"'+s+'",' for s in row.get('rows',[]));lines.append('}}')
    args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text('\n'.join(lines)+'\n',encoding='utf8')
    report=dict(build=70959,slopeDegrees=50,tinyPatchMaxCells=2,connectivity=8,swimmingAllowed=True,
                backtrackingAllowed=True,repeatPenalty=False,zones=inventory,tileHashes=hashes)
    (out/'inventory.json').write_text(json.dumps(report,indent=2),encoding='utf8')
    (out/'index.html').write_text('<!doctype html><meta charset="utf-8"><title>Forever terrain overlays</title><style>body{background:#171b20;color:white;font:16px sans-serif}img{width:480px;max-width:95vw}section{display:inline-block;vertical-align:top;margin:12px}</style><h1>Supplied terrain masks: build 70959</h1><p>White: candidate. Black: restriction. Grey: liquid, permitted. Dark grey: unavailable, prohibited.</p>'+''.join(f'<section><h2>{r["id"]} {r["name"]}</h2><p>{r["status"]}</p>'+ (f'<a href="{r["id"]}.png"><img src="{r["id"]}.png"></a>' if 'w' in r else '<p>'+r.get('reason','')+'</p>')+'</section>' for r in inventory),encoding='utf8')
    print('Generated',len(zones),'map records;',args.output.stat().st_size,'Lua bytes',flush=True)


if __name__=='__main__':main()
