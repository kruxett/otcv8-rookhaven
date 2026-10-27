"""Stage original selected modern outfits as legacy 8.60 art/mask frames.

Legacy phase 0 is source idle phase 0; phases 1..8 are all original walk phases.
Source files are read only. No rescaling, painting, inferred masks or addons.
"""
from pathlib import Path
from functools import lru_cache
from PIL import Image, ImageDraw, ImageFont
import argparse, bisect, hashlib, importlib.util, io, json, lzma, shutil, struct, subprocess, sys, time
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
SERVER = ROOT.parent / 'Rookhaven'
ASSET = ROOT / 'assets/outfits/modern-shop-20261026'
sys.path.insert(0, str(ROOT / 'tools'))
import item_assets as M
spec = importlib.util.spec_from_file_location('modern_reference', ROOT / 'assets/outfits/reference-review-20261026/build_tibia_atlas.py')
T = importlib.util.module_from_spec(spec); spec.loader.exec_module(T)
PICKS = [('Rune Master', 1385, 0), ('Rune Master', 1384, 1), ('Lion of War', 1207, 0), ('Lion of War', 1206, 1)]
SIZES = [(32,32),(32,64),(64,32),(64,64),(32,96),(32,128),(32,192),(32,384),
         (64,96),(64,128),(64,192),(64,384),(96,32),(96,64),(96,96),(96,128),(96,192),(96,384),
         (128,32),(128,64),(128,96),(128,128),(128,192),(128,384),(192,32),(192,64),(192,96),(192,128),(192,192),(192,384),
         (384,32),(384,64),(384,96),(384,128),(384,192),(384,384)]
def sha(data): return hashlib.sha256(data).hexdigest()


class Source:
    def __init__(self):
        prior = json.loads((ROOT / 'assets/outfits/reference-review-20261026/tibia-index.json').read_text())
        self.path = Path(prior['installed_assets'])
        raw = (self.path / 'catalog-content.json').read_bytes()
        assert sha(raw) == prior['catalog_sha256'], 'Installed source changed; review the new assets first'
        catalog = json.loads(raw)
        self.appearance_file = next(x['file'] for x in catalog if x['type'] == 'appearances')
        self.data = (self.path / self.appearance_file).read_bytes()
        self.sheets = sorted((r for r in catalog if r['type'] == 'sprite'), key=lambda r: r['firstspriteid'])
        self.first = [s['firstspriteid'] for s in self.sheets]
        self.sheet_hashes, self.models = {}, {}
        for raw in T.fields(self.data)[2]:
            o = T.fields(raw); look = T.one(o, 1)
            if look not in {x[1] for x in PICKS}: continue
            flags = T.fields(T.one(o, 3, b''))
            assert set(flags) <= {26}, 'Unexpected rendering flags require explicit conversion'
            shift = T.fields(T.one(flags, 26, b''))
            model = {'raw':raw, 'shift':(T.one(shift,1),T.one(shift,2)), 'groups':{}}
            for gb in o[2]:
                g = T.fields(gb); s = T.fields(T.one(g,3,b'')); ids = []
                for value in s[5]:
                    if isinstance(value,int): ids.append(value)
                    else:
                        pos = 0
                        while pos < len(value): v,pos = T.varint(value,pos); ids.append(v)
                nx,ny,nz,layers = [T.one(s,k,1) for k in [1,2,3,4]]
                nf = len(ids)//(nx*ny*nz*layers)
                assert (nx,ny,layers,nf)==(4,3,2,8) and len(ids)==nx*ny*nz*layers*nf
                model['groups'][T.one(g,1)] = {'nz':nz,'ids':ids,'bounds':T.one(s,7,64),'info':s}
            assert set(model['groups'])=={0,1}
            self.models[look] = model
        assert len(self.models)==4

    @lru_cache(maxsize=32)
    def sheet(self, i):
        s = self.sheets[i]; raw = (self.path/s['file']).read_bytes(); p = raw[32]
        self.sheet_hashes[s['file']] = sha(raw)
        decoder = lzma.LZMADecompressor(format=lzma.FORMAT_RAW, filters=[{'id':lzma.FILTER_LZMA1,
            'dict_size':int.from_bytes(raw[33:37],'little'),'lc':p%9,'lp':(p//9)%5,'pb':p//45}])
        im = Image.open(io.BytesIO(decoder.decompress(raw[45:]))).convert('RGBA')
        assert im.size == (384,384)
        im.putdata([(0,0,0,0) if v[:3]==(255,0,255) or not v[3] else v for v in im.get_flattened_data()])
        return im

    @lru_cache(maxsize=3000)
    def sprite(self, sid):
        if not sid: return Image.new('RGBA',(64,64))
        i = bisect.bisect_right(self.first,sid)-1; s = self.sheets[i]
        assert s['firstspriteid'] <= sid <= s['lastspriteid']
        w,h = SIZES[s['spritetype']]; assert w<=64 and h<=64
        offset = sid-s['firstspriteid']; x=(offset%(384//w))*w; y=(offset//(384//w))*h
        tile=self.sheet(i).crop((x,y,x+w,y+h))
        assert {v[3] for v in tile.get_flattened_data()} <= {0,255}
        im=Image.new('RGBA',(64,64)); im.paste(tile,(64-w,64-h)); return im

    def layer(self, look, phase, direction, addon, layer):
        group = 0 if phase==0 else 1; frame = 0 if phase==0 else phase-1
        g=self.models[look]['groups'][group]
        index=((((frame*g['nz']+0)*3+addon)*4+direction)*2+layer)
        return self.sprite(g['ids'][index])


def run(output, apply):
    output=output.resolve(); output.mkdir(parents=True,exist_ok=False); ASSET.mkdir(parents=True,exist_ok=True)
    paths=[ROOT/'data/things/860/Tibia.dat', ROOT/'data/things/860/Tibia.spr', SERVER/'data/XML/outfits.xml']
    before={p:p.read_bytes() for p in paths}; dat,spr,xml=[before[p] for p in paths]
    rels={p:(Path('server/data/XML/outfits.xml') if p==paths[2] else Path('client/data/things/860')/p.name) for p in paths}
    for p,b in before.items():
        dest=output/'originals'/rels[p]; dest.parent.mkdir(parents=True,exist_ok=True); dest.write_bytes(b)
    things,_=M.parse_dat(dat); old_count=M.u16(spr,4); last=M.u16(dat,6)
    assert last==max(t.client_id for t in things if t.category==1)
    registered={int(n.get('looktype')) for n in ET.fromstring(xml)}
    assert not any(n.get('name') in {x[0] for x in PICKS} for n in ET.fromstring(xml)), 'Selected outfits already registered'
    targets=list(range(last+1,last+5)); assert not registered.intersection(targets)
    source=Source(); tiles=[]; tile_ids={bytes(4096):0}; records=[]; definitions=[]
    for (name,look,sex),target in zip(PICKS,targets):
        model=source.models[look]; ids=[]
        folder=ASSET/'source'/str(look); folder.mkdir(parents=True,exist_ok=True)
        (folder/'appearance.pb').write_bytes(model['raw'])
        for phase in range(9):
            for addon in range(3):
                for direction in range(4):
                    for layer in range(2):
                        im=source.layer(look,phase,direction,addon,layer)
                        im.save(folder/f'f{phase}-d{direction}-addon{addon}-layer{layer}.png')
        # Native getSpriteIndex: phase,z,y,x,layer,tileY,tileX.
        for phase in range(9):
            for addon in range(3):
                for direction in range(4):
                    for layer in range(2):
                        im=source.layer(look,phase,direction,addon,layer)
                        for h in range(2):
                            for w in range(2):
                                tile=im.crop(((1-w)*32,(1-h)*32,(2-w)*32,(2-h)*32)); pixels=tile.tobytes()
                                if pixels not in tile_ids: tile_ids[pixels]=old_count+len(tiles)+1; tiles.append(tile)
                                ids.append(tile_ids[pixels])
        attrs=b'\x18'+struct.pack('<HH',*model['shift'])+b'\xff'
        exact=max(g['bounds'] for g in model['groups'].values()); assert 0<exact<=64
        definitions.append(attrs+bytes([2,2,exact,2,4,3,1,9])+struct.pack(f'<{len(ids)}H',*ids))
        records.append({'name':name,'source_id':look,'looktype':target,'sex':sex,'offer_id':6001+len(records),
            'shift':model['shift'],'exact_size':exact,'layout':[2,4,3,1,9],'sprite_slots':len(ids)})
    assert old_count+len(tiles)<=65535
    delta=len(tiles)*4; old_table=6+old_count*4; old_payload=spr[old_table:]
    pointers=[M.u32(spr,6+i*4) for i in range(old_count)]; shifted=[p+delta if p else 0 for p in pointers]
    payloads=[M.encode_sprite(im) for im in tiles]; pos=len(spr)+delta; new_pointers=[]
    for payload in payloads: new_pointers.append(pos); pos+=len(payload)
    new_spr=spr[:4]+struct.pack('<H',old_count+len(tiles))+struct.pack(f'<{old_count+len(tiles)}I',*(shifted+new_pointers))+old_payload+b''.join(payloads)
    assert new_spr[old_table+delta:old_table+delta+len(old_payload)]==old_payload
    end=next(t.end for t in things if t.category==1 and t.client_id==last)
    new_dat=bytearray(dat[:end]+b''.join(definitions)+dat[end:]); struct.pack_into('<H',new_dat,6,last+4); new_dat=bytes(new_dat)
    parsed,_=M.parse_dat(new_dat); old={(t.category,t.client_id):dat[t.start:t.end] for t in things}
    for t in parsed:
        if (t.category,t.client_id) in old: assert new_dat[t.start:t.end]==old[t.category,t.client_id]
    compared=0
    for record in records:
        t=next(t for t in parsed if t.category==1 and t.client_id==record['looktype']); index=0
        for phase in range(9):
            for addon in range(3):
                for direction in range(4):
                    for layer in range(2):
                        image=Image.new('RGBA',(64,64))
                        for h in range(2):
                            for w in range(2):
                                tile=M.sprite_image(new_spr,t.sprites[index]); index+=1
                                image.paste(tile,((1-w)*32,(1-h)*32)); compared+=1
                        assert image.tobytes()==source.layer(record['source_id'],phase,direction,addon,layer).tobytes()
    newline=b'\r\n' if b'\r\n' in xml else b'\n'; new_xml=xml
    for sex,marker in [(0,b'\t<!-- Female outfits -->'),(1,b'\t<!-- Male outfits -->')]:
        assert xml.count(marker)==1
        lines=[f'\t<outfit type="{sex}" looktype="{r["looktype"]}" name="{r["name"]}" premium="no" unlocked="no" enabled="yes" />'.encode() for r in records if r['sex']==sex]
        new_xml=new_xml.replace(marker,marker+newline+newline.join(lines))
    assert [n.attrib for n in ET.fromstring(new_xml) if int(n.get('looktype')) not in targets]==[n.attrib for n in ET.fromstring(xml)]
    outputs=dict(zip(paths,[new_dat,new_spr,new_xml]))
    for p,b in outputs.items():
        dest=output/'staged'/rels[p];dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(b)
    manifest={'status':'staged','outfits':records,'original_sprites':old_count,'added_sprites':len(tiles),
        'source_tile_slots_compared':compared,'unrelated_DAT_records_byte_exact':len(old),'all_original_SPR_payload_bytes_preserved':True,
        'source_appearance_sha256':sha(source.data),'source_sheet_sha256':source.sheet_hashes,
        'legacy_animation':'Idle source group 0 phase 0; all eight original unmounted walking frames. Modern animated idle/timing and mounted patterns are not imported.',
        'input_sha256':{str(p):sha(b) for p,b in before.items()},'output_sha256':{str(p):sha(b) for p,b in outputs.items()}}
    (output/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    if apply:
        for p,b in before.items(): assert p.read_bytes()==b, 'Concurrent source modification'
        quote=lambda p:"'"+str(p).replace("'","''")+"'"
        for p in paths:
            for attempt in range(3):
                result=subprocess.run(['powershell.exe','-NoProfile','-Command',"$ErrorActionPreference='Stop'; Copy-Item -LiteralPath "+quote(output/'staged'/rels[p])+" -Destination "+quote(p)+" -Force"],capture_output=True)
                if result.returncode==0: break
                if attempt==2: raise RuntimeError(result.stderr.decode(errors='replace'))
                time.sleep(.5)
        for p,b in outputs.items(): assert p.read_bytes()==b
        manifest['status']='Applied locally; gameplay/rendering checks pending'
    (output/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    shutil.copyfile(output/'manifest.json',ASSET/'import-manifest.json')
    print(json.dumps({k:manifest[k] for k in ['status','outfits','added_sprites','source_tile_slots_compared','unrelated_DAT_records_byte_exact']}))


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--apply',action='store_true');a=p.parse_args();run(a.output,a.apply)
