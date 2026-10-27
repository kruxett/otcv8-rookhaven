"""Read-only catalogue of named player outfits missing from Rookhaven.

Original installed source pixels, directions, walk phases and colour masks.
Never imports into DAT/SPR or changes the server/shop.
"""
from pathlib import Path
from functools import lru_cache
import argparse, bisect, hashlib, importlib.util, io, json, lzma, shutil
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/outfits/missing-modern-catalog-20261026'
SOURCE = Path('C:/Users/marcu/AppData/Local/Tibia/packages/Tibia/assets')
spec = importlib.util.spec_from_file_location('reference', ROOT / 'assets/outfits/reference-review-20261026/build_tibia_atlas.py')
T = importlib.util.module_from_spec(spec); spec.loader.exec_module(T)
from export_editable import COLORS, outfit_color
SIZES = [(32,32),(32,64),(64,32),(64,64),(32,96),(32,128),(32,192),(32,384),
         (64,96),(64,128),(64,192),(64,384),(96,32),(96,64),(96,96),(96,128),(96,192),(96,384),
         (128,32),(128,64),(128,96),(128,128),(128,192),(128,384),(192,32),(192,64),(192,96),(192,128),(192,192),(192,384),
         (384,32),(384,64),(384,96),(384,128),(384,192),(384,384)]
DIRECTIONS = ['north', 'east', 'south', 'west']
# appearances.proto: east49, west50, south51, north52.
REVERSE = {'north':52, 'east':49, 'south':51, 'west':50}
PALETTE = (58,49,2,58)

def sha(data): return hashlib.sha256(data).hexdigest()

class Source:
    def __init__(self, ids):
        raw = (SOURCE / 'catalog-content.json').read_bytes()
        self.catalog_hash = sha(raw)
        assert self.catalog_hash == '97d0963444e147f5eebb02ed8024abc7e2e80707ef03b08dce226117bebdcb4d'
        catalog = json.loads(raw)
        self.appearance_file = next(x['file'] for x in catalog if x['type'] == 'appearances')
        data = (SOURCE / self.appearance_file).read_bytes()
        self.appearance_hash = sha(data)
        self.sheets = sorted((x for x in catalog if x['type']=='sprite'), key=lambda x:x['firstspriteid'])
        self.first = [x['firstspriteid'] for x in self.sheets]
        self.models = {}
        self.sheet_hashes = {}
        for raw in T.fields(data)[2]:
            outfit = T.fields(raw); look = T.one(outfit,1)
            if look not in ids: continue
            flags = T.fields(T.one(outfit,3,b'')); groups = {}
            for graw in outfit[2]:
                g = T.fields(graw); s = T.fields(T.one(g,3,b''))
                sprites = []
                for packed in s[5]:
                    if isinstance(packed,int): sprites.append(packed)
                    else:
                        pos = 0
                        while pos < len(packed):
                            sid,pos = T.varint(packed,pos); sprites.append(sid)
                nx,ny,nz,nl = (T.one(s,k,1) for k in [1,2,3,4])
                assert nx==4 and nl==2 and ny in (1,3), (look,nx,ny,nz,nl)
                assert len(sprites)%(nx*ny*nz*nl)==0
                nf = len(sprites)//(nx*ny*nz*nl)
                sizes = [self.sprite_size(sid) for sid in sprites if sid]
                groups[T.one(g,1)] = dict(nx=nx,ny=ny,nz=nz,nl=nl,nf=nf,sprites=sprites,
                    width=max(w for w,h in sizes),height=max(h for w,h in sizes))
            width=max(g['width'] for g in groups.values());height=max(g['height'] for g in groups.values())
            self.models[look] = dict(groups=groups,flags=flags,size=(width,height))
        assert set(self.models)==ids

    def sheet_index(self,sid):
        i = bisect.bisect_right(self.first,sid)-1
        assert i>=0 and sid<=self.sheets[i]['lastspriteid'], sid
        return i

    def sprite_size(self,sid): return SIZES[self.sheets[self.sheet_index(sid)]['spritetype']]

    @lru_cache(maxsize=64)
    def sheet(self,i):
        name = self.sheets[i]['file'];raw=(SOURCE/name).read_bytes();self.sheet_hashes[name]=sha(raw)
        p=raw[32]
        decoder=lzma.LZMADecompressor(format=lzma.FORMAT_RAW,filters=[dict(id=lzma.FILTER_LZMA1,
            dict_size=int.from_bytes(raw[33:37],'little'),lc=p%9,lp=(p//9)%5,pb=p//45)])
        a=np.array(Image.open(io.BytesIO(decoder.decompress(raw[45:]))).convert('RGBA'))
        a[(a[:,:,:3]==(255,0,255)).all(axis=2)]=0
        a[a[:,:,3]==0]=0
        return Image.fromarray(a)

    @lru_cache(maxsize=8192)
    def sprite(self,sid,size):
        result=Image.new('RGBA',size)
        if sid:
            i=self.sheet_index(sid);w,h=self.sprite_size(sid);offset=sid-self.first[i]
            x=(offset%(384//w))*w;y=(offset//(384//w))*h
            result.paste(self.sheet(i).crop((x,y,x+w,y+h)),(size[0]-w,size[1]-h))
        return result

    @lru_cache(maxsize=8192)
    def colored(self,base,mask,size):
        a=np.array(self.sprite(base,size));m=np.array(self.sprite(mask,size))
        for label,index in zip(COLORS,PALETTE):
            select=(m==label).all(axis=2)
            a[select,:3]=np.rint(a[select,:3].astype(np.float64)*np.array(outfit_color(index))/255).astype(np.uint8)
        return Image.fromarray(a)

    def frame(self,look,group,direction,phase,addons):
        model=self.models[look];g=model['groups'][group];result=Image.new('RGBA',model['size'])
        selected=[0]+([1] if addons&1 and g['ny']>1 else [])+([2] if addons&2 and g['ny']>2 else [])
        # Primary flag docs put addons UNDER the base in these directions.
        # Descending addon1/2 order is an inference; see audit/reverse-addons/evidence.json.
        if REVERSE[DIRECTIONS[direction]] in model['flags']: selected.reverse()
        for addon in selected:
            offset=(((phase*g['nz'])*g['ny']+addon)*g['nx']+direction)*g['nl']
            result.alpha_composite(self.colored(g['sprites'][offset],g['sprites'][offset+1],model['size']))
        return result

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--limit',type=int);args=parser.parse_args()
    registry=json.loads((OUT/'audit/player-family-registry.json').read_text())
    families=sorted((f for f in registry['families'] if not f['already_in_rookhaven']),key=lambda f:f['name'].casefold())
    if args.limit: families=families[:args.limit]
    source=Source({f[k] for f in families for k in ['male','female']})
    result={'summary':dict(catalogId='rookhaven-missing-20261026',asOf='2026-10-26',sourceLabel='Installerade originalsprites från Tibia',
        sourceVersion='15.33.c9e45e',missingFamilies=len(families),missingVariants=len(families)*2,existingFamilies=26,
        scope='Namngivna player-outfits. NPC:er, monster och förklädnader ingår inte.',
        notes=['Katalog för att välja outfits till Rookhaven; inget i denna katalog har importerats.',
               'Rune Master och Lion of War finns redan och har därför räknats bort.',
               'Samma färgval används på alla: head58, body49, legs2, feet58. Originalets färgmasker används.',
               'Gånganimationer visar samtliga källrutor. Visningshastigheten motsvarar inte en bestämd spelhastighet.',
               '102 familjer har två addons. Jersey och sju Retro-outfits saknar separata addons.'],
        sources=[dict(label='Komplett ID-register',url='https://exetares.wiki/Outfit_IDs'),
                 dict(label='Canary outfitregister',url='https://github.com/opentibiabr/canary/blob/main/data/XML/outfits.xml')]),'outfits':[]}
    stats={'variants':0,'png':0,'apng':0,'sourceWalkFrames':{},'reverseFlagVariants':[],'dimensions':{},'emptyFrames':[]}
    for number,family in enumerate(families,1):
        addons=2 if family['addon_pattern_rows']==3 else 0
        entry=dict(key=family['key'],name=family['name'],number=number,addonCount=addons,status='Saknas i Rookhaven',
                   notes=[] if addons else ['Inga separata addons i originalet.'])
        for sex in ['male','female']:
            look=family[sex];model=source.models[look];groups=model['groups']
            idle=0 if 0 in groups else min(groups);walk=1 if 1 in groups else idle
            nf=groups[walk]['nf'];folder=OUT/'media'/str(look);folder.mkdir(parents=True,exist_ok=True)
            images={}
            for d,direction in enumerate(DIRECTIONS):
                for a,mode in enumerate(['base','a1','a2','full']):
                    still=source.frame(look,idle,d,0,a)
                    assert still.getbbox(), (look,direction,mode,'empty idle')
                    name=f'idle-{direction}-{mode}.png';still.save(folder/name)
                    images[f'idle-{direction}-{mode}']=f'media/{look}/{name}';stats['png']+=1
                    frames=[source.frame(look,walk,d,p,a) for p in range(nf)]
                    assert all(im.getbbox() for im in frames),(look,direction,mode,'empty walk')
                    name=f'walk-{direction}-{mode}.png'
                    frames[0].save(folder/name,format='PNG',save_all=True,append_images=frames[1:],
                                   duration=max(80,1000//max(1,nf)),loop=0,disposal=1,blend=0)
                    images[f'walk-{direction}-{mode}']=f'media/{look}/{name}';stats['apng']+=1
            flags=[d for d,k in REVERSE.items() if k in model['flags']]
            entry[sex]=dict(looktype=look,images=images,canvas=list(model['size']),walkFrames=nf,
                            idleFrames=groups[idle]['nf'],reverseAddonDirections=flags)
            stats['variants']+=1;stats['sourceWalkFrames'][str(look)]=nf;stats['dimensions'][str(look)]=list(model['size'])
            if flags:stats['reverseFlagVariants'].append(look)
        result['outfits'].append(entry)
        if number%10==0 or number==len(families):print(f'Rendered {number}/{len(families)} families',flush=True)
    (OUT/'catalog.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    (OUT/'catalog.js').write_text('window.OUTFIT_CATALOG = '+json.dumps(result,ensure_ascii=False,separators=(',',':'))+';\n',encoding='utf-8')
    shutil.copyfile(ROOT/'tools/modern-outfit-tests/catalog-template.html',OUT/'index.html')
    manifest=dict(source=str(SOURCE),sourceVersion='15.33.c9e45e',catalogHash=source.catalog_hash,
        appearanceFile=source.appearance_file,appearanceHash=source.appearance_hash,
        registryHash=sha((OUT/'audit/player-family-registry.json').read_bytes()),palette=PALETTE,statistics=stats,sheetHashes=source.sheet_hashes)
    (OUT/'render-manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    print(json.dumps({'families':len(families),'variants':stats['variants'],'files':stats['png']+stats['apng'],'output':str(OUT)}),flush=True)

if __name__=='__main__':main()
