"""Read existing installed modern Tibia assets for a selection preview only."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
from functools import lru_cache
import importlib.util,hashlib,json,collections,bisect,lzma,io,urllib.request
OUT=Path(__file__).resolve().parent
REPO=OUT.parents[2]
REF=REPO/'assets/outfits/reference-review-20261026'
spec=importlib.util.spec_from_file_location('modern_reader',REF/'build_tibia_atlas.py')
T=importlib.util.module_from_spec(spec);spec.loader.exec_module(T)
PICKS=[('Rune Master',1384,1385),('Dream Warden',577,578),('Crystal Warlord',512,513),('Lion of War',1206,1207),('Royal Costume',1457,1456),('Death Herald',667,666)]
def main():
    prior=json.loads((REF/'tibia-index.json').read_text())
    assets=Path(prior['installed_assets'])
    catalog_path=assets/'catalog-content.json'
    assert hashlib.sha256(catalog_path.read_bytes()).hexdigest()==prior['catalog_sha256']
    catalog=json.loads(catalog_path.read_text());appearance=next(x for x in catalog if x['type']=='appearances')
    data=(assets/appearance['file']).read_bytes();root=T.fields(data)
    sheets=sorted([r for r in catalog if r['type']=='sprite'],key=lambda r:r['firstspriteid'])
    first=[s['firstspriteid'] for s in sheets]
    sizes=[(w,h) for w in [32,64,96,128,192,384] for h in [32,64,96,128,192,384]]
    # Sprite type enum is not a Cartesian sequence for the first twelve entries.
    sizes=[(32,32),(32,64),(64,32),(64,64),(32,96),(32,128),(32,192),(32,384),(64,96),(64,128),(64,192),(64,384),(96,32),(96,64),(96,96),(96,128),(96,192),(96,384),(128,32),(128,64),(128,96),(128,128),(128,192),(128,384),(192,32),(192,64),(192,96),(192,128),(192,192),(192,384),(384,32),(384,64),(384,96),(384,128),(384,192),(384,384)]
    @lru_cache(maxsize=32)
    def sheet(i):
        raw=(assets/sheets[i]['file']).read_bytes();p=raw[32]
        decoder=lzma.LZMADecompressor(format=lzma.FORMAT_RAW,filters=[{'id':lzma.FILTER_LZMA1,'dict_size':int.from_bytes(raw[33:37],'little'),'lc':p%9,'lp':(p//9)%5,'pb':p//45}])
        im=Image.open(io.BytesIO(decoder.decompress(raw[45:]))).convert('RGBA')
        assert im.size==(384,384)
        im.putdata([(0,0,0,0) if p[:3]==(255,0,255) else p for p in im.get_flattened_data()])
        return im
    @lru_cache(maxsize=3000)
    def sprite(sid):
        if not sid:return Image.new('RGBA',(64,64))
        i=bisect.bisect_right(first,sid)-1;s=sheets[i];assert s['firstspriteid']<=sid<=s['lastspriteid']
        w,h=sizes[s['spritetype']];offset=sid-s['firstspriteid'];x=(offset%(384//w))*w;y=(offset//(384//w))*h
        return sheet(i).crop((x,y,x+w,y+h))
    wanted={i for name,m,f in PICKS for i in (m,f)};models={}
    for raw in root[2]:
        outfit=T.fields(raw);look=T.one(outfit,1)
        if look not in wanted:continue
        groups={}
        for gb in outfit[2]:
            g=T.fields(gb);s=T.fields(T.one(g,3,b''));nx,ny,nz,l=[T.one(s,k,1) for k in [1,2,3,4]]
            ids=[]
            for v in s[5]:
                if isinstance(v,int):ids.append(v)
                else:
                    pos=0
                    while pos<len(v):value,pos=T.varint(v,pos);ids.append(value)
            frames=len(ids)//(nx*ny*nz*l)
            assert nx==4 and ny==3 and l==2 and len(ids)==frames*nx*ny*nz*l
            groups[T.one(g,1,-1)]={'nx':nx,'ny':ny,'nz':nz,'layers':l,'frames':frames,'ids':ids}
        assert groups[1]['frames']==8
        models[look]=groups
    assert len(models)==12
    @lru_cache(maxsize=400)
    def frame(look,group,phase,direction):
        g=models[look][group];result=Image.new('RGBA',(64,64))
        for addon in range(3):
            parts=[]
            for layer in range(2):
                index=((((phase*g['nz']+0)*g['ny']+addon)*g['nx']+direction)*g['layers']+layer)
                im=sprite(g['ids'][index]);assert im.width<=64 and im.height<=64
                slot=Image.new('RGBA',(64,64));slot.paste(im,(64-im.width,64-im.height));parts.append(slot)
            result.alpha_composite(T.recolor(parts[0],parts[1],(58,49,2,58)))
        assert result.getbbox() is not None
        return result
    font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',14);bold=ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf',17)
    def board(group=0,phase=0):
        im=Image.new('RGB',(960,448),'#24272b');d=ImageDraw.Draw(im)
        d.text((12,8),'Nyare Tibia-outfits · urval för Rookhaven',font=bold,fill='white')
        d.text((12,34),'Male till vänster, female till höger · båda addons · exempelfärger',font=font,fill='#c0c5cd')
        for i,(name,m,f) in enumerate(PICKS):
            x=i%3*320;y=i//3*192+62;d.text((x+12,y+2),name,font=bold,fill='#e4bd73' if name=='Rune Master' else 'white')
            for sex,look in enumerate((m,f)):
                art=frame(look,group,phase,2).resize((128,128),Image.Resampling.NEAREST);im.paste(art,(x+12+sex*160,y+38),art)
        return im
    board().save(OUT/'modern-six-male-female.png')
    frames=[board(1,p) for p in range(8)]
    frames[0].save(OUT/'modern-six-male-female-walking.gif',save_all=True,append_images=frames[1:],duration=100,loop=0,disposal=2)
    inspected=0
    for look in sorted(models):
        for direction in range(4):
            for group in [0,1]:
                for phase in range(models[look][group]['frames']):
                    frame(look,group,phase,direction);inspected+=1
    info={'status':'Selection preview only; no imported outfits or shop changes.','source':'Installed official Tibia client; original art, addon layers and player-color masks. Not freely licensed.',
        'catalog_sha256':prior['catalog_sha256'],'appearance_sha256':hashlib.sha256(data).hexdigest(),
        'source_version_file':appearance['file'],'names_source':'https://github.com/opentibiabr/canary/blob/main/data/XML/outfits.xml',
        'families':[{'name':name,'male':m,'female':f} for name,m,f in PICKS],
        'all12_variants':{str(k):[{key:v for key,v in g.items() if key!='ids'}|{'group':gi} for gi,g in groups.items()] for k,groups in models.items()},
        'frames_composed_including_all4_directions':inspected,'modern_idle_groups_preserved_in_source':True,
        'walking_preview':'All8 original walk frames;100ms illustrative preview speed.','source_art_repainted':False,
        'import_limitations':'8.60 DAT conversion and in-game checks not yet done. Separate modern idle/movement groups and timing require an explicit conversion choice.'}
    (OUT/'modern-inventory.json').write_text(json.dumps(info,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    print(json.dumps({'families':6,'variants':12,'all_direction_frames_composed':inspected,'walk_frames':8,'output':str(OUT)}))
if __name__=='__main__':main()

