"""Read-only atlas from the installed official Tibia client's appearance files.

Wire fields and sheet decoding were checked against OpenTibiaBR/otclient's
appearances.proto and spriteappearances.cpp. No installed file is modified.
"""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
from functools import lru_cache
import bisect
import collections
import hashlib
import io
import json
import lzma
import sys

HERE=Path(__file__).resolve().parent
ASSETS=Path('C:/Users/marcu/AppData/Local/Tibia/packages/Tibia/assets')
sys.path.insert(0,str(HERE.parents[2]/'assets/outfits/rookwarden/tools'))
from export_editable import recolor


def varint(data,pos=0):
    value=shift=0
    while True:
        b=data[pos];pos+=1;value|=(b&127)<<shift
        if not b&128:return value,pos
        shift+=7
        assert shift<70


def fields(data):
    out=collections.defaultdict(list);pos=0
    while pos<len(data):
        tag,pos=varint(data,pos);number,wire=tag>>3,tag&7
        if wire==0:value,pos=varint(data,pos)
        elif wire==2:
            length,pos=varint(data,pos);value=data[pos:pos+length];pos+=length
        elif wire in [1,5]:
            length=8 if wire==1 else 4;value=data[pos:pos+length];pos+=length
        else:raise ValueError((number,wire,pos))
        assert pos<=len(data)
        out[number].append(value)
    return out


def one(data,key,default=0):return data[key][0] if data.get(key) else default


def main():
    catalog=json.loads((ASSETS/'catalog-content.json').read_text())
    appearances=next(x for x in catalog if x['type']=='appearances')
    data=(ASSETS/appearances['file']).read_bytes();root=fields(data)
    sheets=sorted([r for r in catalog if r['type']=='sprite'],key=lambda r:r['firstspriteid'])
    first_ids=[s['firstspriteid'] for s in sheets]
    sizes=[(32,32),(32,64),(64,32),(64,64),(32,96),(32,128),(32,192),(32,384),
           (64,96),(64,128),(64,192),(64,384),(96,32),(96,64),(96,96),(96,128),(96,192),(96,384),
           (128,32),(128,64),(128,96),(128,128),(128,192),(128,384),(192,32),(192,64),(192,96),(192,128),(192,192),(192,384),
           (384,32),(384,64),(384,96),(384,128),(384,192),(384,384)]
    @lru_cache(maxsize=32)
    def sheet_image(index):
        raw=(ASSETS/sheets[index]['file']).read_bytes();properties=raw[32]
        decoder=lzma.LZMADecompressor(format=lzma.FORMAT_RAW,filters=[{'id':lzma.FILTER_LZMA1,
            'dict_size':int.from_bytes(raw[33:37],'little'),'lc':properties%9,'lp':(properties//9)%5,'pb':properties//45}])
        bitmap=decoder.decompress(raw[45:]);im=Image.open(io.BytesIO(bitmap)).convert('RGBA')
        assert im.size==(384,384)
        pixels=im.load()
        for y in range(384):
            for x in range(384):
                if pixels[x,y][:3]==(255,0,255):pixels[x,y]=(0,0,0,0)
        return im
    def sprite(sprite_id):
        if not sprite_id:return Image.new('RGBA',(64,64))
        index=bisect.bisect_right(first_ids,sprite_id)-1;s=sheets[index]
        assert s['firstspriteid']<=sprite_id<=s['lastspriteid']
        w,h=sizes[s['spritetype']];offset=sprite_id-s['firstspriteid'];cols=384//w
        x,y=(offset%cols)*w,(offset//cols)*h
        return sheet_image(index).crop((x,y,x+w,y+h))
    records=[]
    for raw in root[2]:
        outfit=fields(raw);look=one(outfit,1);groups=[fields(g) for g in outfit[2]]
        group=next((g for g in groups if one(g,1,-1)==0),groups[0])
        info=fields(one(group,3,b''));nx,ny,nz,layers=[one(info,k,1) for k in [1,2,3,4]]
        if nx!=4 or layers!=2:continue
        ids=[]
        for value in info[5]:
            if isinstance(value,int):ids.append(value)
            else:
                pos=0
                while pos<len(value):v,pos=varint(value,pos);ids.append(v)
        assert len(ids)>=nx*ny*nz*layers,(look,len(ids),nx,ny,nz,layers)
        name=one(outfit,4,b'')
        try:name=name.decode('utf-8') if isinstance(name,bytes) else ''
        except UnicodeDecodeError:name=''
        folder=HERE/'tibia'/str(look);folder.mkdir(parents=True,exist_ok=True)
        for direction,d in enumerate(['north','east','south','west']):
            for variant,addons in [('base',[0]),('full',range(ny))]:
                parts=[]
                for addon in addons:
                    base=sprite(ids[(addon*nx+direction)*layers])
                    mask=sprite(ids[(addon*nx+direction)*layers+1])
                    if base.size!=mask.size:
                        target=(max(base.width,mask.width),max(base.height,mask.height))
                        b=Image.new('RGBA',target);m=Image.new('RGBA',target)
                        b.paste(base,(target[0]-base.width,target[1]-base.height));m.paste(mask,(target[0]-mask.width,target[1]-mask.height));base,mask=b,m
                    parts.append(recolor(base,mask,(58,49,2,58)))
                target=(max(p.width for p in parts),max(p.height for p in parts));result=Image.new('RGBA',target)
                for p in parts:result.alpha_composite(p,(target[0]-p.width,target[1]-p.height))
                result.save(folder/f'{d}-{variant}.png')
        records.append({'id':look,'name':name,'patterns':[nx,ny,nz],'layers':layers,'source':str(folder.relative_to(HERE))})
        if len(records)%100==0:print(json.dumps({'rendered_outfits':len(records)}),flush=True)
    font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',12)
    for start in range(0,len(records),64):
        subset=records[start:start+64];canvas=Image.new('RGB',(1216,1280),(43,43,43));draw=ImageDraw.Draw(canvas)
        for i,r in enumerate(subset):
            x,y=(i%8)*152,(i//8)*160;draw.text((x+5,y+4),f'{r["id"]} {r["name"][:15]}',font=font,fill='white')
            image=Image.open(HERE/r['source']/'south-full.png').convert('RGBA');bbox=image.getbbox()
            if bbox:
                image=image.crop((max(0,bbox[0]-2),max(0,bbox[1]-2),min(image.width,bbox[2]+2),min(image.height,bbox[3]+2)))
                scale=2 if max(image.size)<=64 else 1;image=image.resize((image.width*scale,image.height*scale),Image.Resampling.NEAREST)
                image.thumbnail((144,132),Image.Resampling.NEAREST);canvas.paste(image,(x+4+(144-image.width)//2,y+23+(132-image.height)//2),image)
        canvas.save(HERE/f'tibia-page-{start//64+1:02}.png')
    metadata={'installed_assets':str(ASSETS),'catalog_sha256':hashlib.sha256((ASSETS/'catalog-content.json').read_bytes()).hexdigest(),
        'appearances_file':appearances['file'],'appearance_count':len(root[2]),'recolorable_four_direction_variants':len(records),
        'selection':'All appearance outfits with 4 directions and 2 recoloring layers, including player outfits and compatible NPCs; idle base/full addons, mount pattern zero.',
        'pages':(len(records)+63)//64,'items':records,
        'format_sources':['https://github.com/opentibiabr/otclient/blob/main/src/protobuf/appearances.proto','https://github.com/opentibiabr/otclient/blob/main/src/client/spriteappearances.cpp']}
    (HERE/'tibia-index.json').write_text(json.dumps(metadata,indent=2)+'\n')
    print(json.dumps({k:v for k,v in metadata.items() if k not in ['items','format_sources']}),flush=True)


if __name__=='__main__':main()
