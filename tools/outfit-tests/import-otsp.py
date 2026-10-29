"""Append approved OTSP20/21 to legacy8.60 DAT/SPR without changing old assets."""
from pathlib import Path
import argparse,hashlib,importlib.util,json,shutil,struct,sys,xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[2]
SERVER=ROOT.parent/'Rookhaven'
ASSET=ROOT/'assets/outfits/opentibia-sprite-pack-20261026'
sys.path.insert(0,str(ROOT/'tools'));import item_assets as M
sys.path.insert(0,str(ASSET));import extract_otsp as E
def sha(b):return hashlib.sha256(b).hexdigest()
def run(output,apply):
    output=output.resolve();output.mkdir(parents=True,exist_ok=False)
    datp=ROOT/'data/things/860/Tibia.dat';sprp=ROOT/'data/things/860/Tibia.spr';xmlp=SERVER/'data/XML/outfits.xml'
    sources={str(p):p.read_bytes() for p in (datp,sprp,xmlp)}
    for p,b in sources.items():
        rel=Path('client/data/things/860')/Path(p).name if Path(p) in (datp,sprp) else Path('server/data/XML/outfits.xml')
        backup=output/'originals'/rel;backup.parent.mkdir(parents=True,exist_ok=True);backup.write_bytes(b)
    dat,spr,xml=(sources[str(p)] for p in (datp,sprp,xmlp))
    native=E.Reader();things,_=M.parse_dat(dat);last=max(t.client_id for t in things if t.category==1)
    assert M.u16(dat,6)==last
    existing_xml=ET.fromstring(xml);registered={int(n.get('looktype')) for n in existing_xml}
    target_ids=[last+1,last+2];assert all(x not in registered for x in target_ids)
    old_count=M.u16(spr,4);new_tiles=[];tile_ids={bytes(4096):0};mapping={};records=[];new_defs=[]
    for source_id,target_id,sex in zip((20,21),target_ids,(0,1)):
        t=native.outfits[source_id];assert t.size==(2,2) and t.layout==(2,4,3,1,3)
        ids=[]
        for sid in t.sprites:
            im=native.sprite(sid);pixels=im.tobytes()
            if pixels not in tile_ids:
                tile_ids[pixels]=old_count+len(new_tiles)+1;new_tiles.append(im)
            ids.append(tile_ids[pixels])
        header=t.legacy_attributes+bytes(t.size)+bytes([t.exact_size])+bytes(t.layout)
        new_defs.append(header+struct.pack(f'<{len(ids)}H',*ids))
        records.append({'source_id':source_id,'looktype':target_id,'sex':sex,'sex_name':'female' if sex==0 else 'male','name':'Acolyte','size':t.size,'layout':t.layout,'legacy_attributes_hex':t.legacy_attributes.hex(),'exact_size':t.exact_size,'sprite_slots':len(ids)})
    assert old_count+len(new_tiles)<=65535
    added=len(new_tiles);old_table=6+old_count*4;old_data=spr[old_table:];delta=added*4
    pointers=[M.u32(spr,6+i*4) for i in range(old_count)]
    shifted=[p+delta if p else 0 for p in pointers]
    payloads=[M.encode_sprite(im) for im in new_tiles];p=len(spr)+delta;new_ptr=[]
    for payload in payloads:new_ptr.append(p);p+=len(payload)
    new_spr=spr[:4]+struct.pack('<H',old_count+added)+struct.pack(f'<{old_count+added}I',*(shifted+new_ptr))+old_data+b''.join(payloads)
    new_table=6+(old_count+added)*4
    assert new_spr[new_table:new_table+len(old_data)]==old_data
    assert all(M.u32(new_spr,6+i*4)==(old+delta if old else 0) for i,old in enumerate(pointers))
    for i,im in enumerate(new_tiles):assert M.sprite_image(new_spr,old_count+i+1).tobytes()==im.tobytes()
    end=next(t.end for t in things if t.category==1 and t.client_id==last)
    new_dat=bytearray(dat[:end]+b''.join(new_defs)+dat[end:]);struct.pack_into('<H',new_dat,6,last+2);new_dat=bytes(new_dat)
    new_things,_=M.parse_dat(new_dat);old_records={(t.category,t.client_id):dat[t.start:t.end] for t in things}
    for t in new_things:
        if (t.category,t.client_id) in old_records:assert new_dat[t.start:t.end]==old_records[t.category,t.client_id]
    source_frames=0
    for source_id,target_id in zip((20,21),target_ids):
        t=native.outfits[source_id];n=next(t for t in new_things if t.category==1 and t.client_id==target_id)
        assert n.layout==t.layout and n.size==t.size
        for i,sid in enumerate(n.sprites):
            assert M.sprite_image(new_spr,sid).tobytes()==native.sprite(t.sprites[i]).tobytes();source_frames+=1
    newline=b'\r\n' if b'\r\n' in xml else b'\n'
    new_xml=xml
    for record,marker in zip(records,(b'\t<!-- Female outfits -->',b'\t<!-- Male outfits -->')):
        assert xml.count(marker)==1
        line=f'\t<outfit type="{record["sex"]}" looktype="{record["looktype"]}" name="Acolyte" premium="no" unlocked="no" enabled="yes" />'.encode()
        new_xml=new_xml.replace(marker,marker+newline+line)
    final_xml=ET.fromstring(new_xml);assert [x.attrib for x in final_xml if int(x.get('looktype')) not in target_ids]==[x.attrib for x in existing_xml]
    outputs={datp:new_dat,sprp:new_spr,xmlp:new_xml}
    manifest={'status':'Verified staged8.60 import','name':'Acolyte','source_commit':json.loads((ASSET/'source-manifest.json').read_text())['commit'],
        'gender_mapping':'Project assignment from visual design:20 female,21 male. Upstream DAT/SPR has no sex metadata.',
        'outfits':records,'original_sprites':old_count,'added_sprites':added,'source_tile_slots_compared':source_frames,
        'unrelated_DAT_records_byte_exact':len(old_records),'all_original_SPR_payload_bytes_preserved':True,
        'all_existing_outfit_XML_attributes_preserved':True,'input_sha256':{p:sha(b) for p,b in sources.items()},'output_sha256':{str(p):sha(b) for p,b in outputs.items()}}
    for p,b in outputs.items():
        rel=Path('client/data/things/860')/p.name if p in (datp,sprp) else Path('server/data/XML/outfits.xml')
        dest=output/'staged'/rel;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(b)
    if apply:
        for p,b in sources.items():assert Path(p).read_bytes()==b,'Concurrent source modification: '+p
        # Native Copy-Item replaces mapped files without truncating their mapped sections.
        import subprocess
        for p in outputs:
            rel=Path('client/data/things/860')/p.name if p in (datp,sprp) else Path('server/data/XML/outfits.xml')
            quote=lambda x:"'"+str(x).replace("'","''")+"'"
            subprocess.run(['powershell.exe','-NoProfile','-Command',"$ErrorActionPreference='Stop'; Copy-Item -LiteralPath "+quote(output/'staged'/rel)+" -Destination "+quote(p)+" -Force"],check=True,capture_output=True)
        for p,b in outputs.items():assert p.read_bytes()==b
        manifest['status']='Applied locally; native gameplay/rendering checks pending'
    (output/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    shutil.copyfile(output/'manifest.json',ASSET/'import-manifest.json')
    print(json.dumps({k:manifest[k] for k in ['status','outfits','added_sprites','source_tile_slots_compared','unrelated_DAT_records_byte_exact']}))
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--apply',action='store_true');a=p.parse_args();run(a.output,a.apply)

