"""Read the actual starter Citizen (128), preserving native frame geometry."""
from pathlib import Path
import sys
import json
import hashlib
from PIL import Image, ImageFilter

ROOT=Path(__file__).resolve().parents[1]
REPO=Path(__file__).resolve().parents[4]
sys.path.insert(0,str(REPO/'tools'))
from item_assets import parse_dat,sprite_image


def main():
    refs=ROOT/'source/reference';refs.mkdir(parents=True,exist_ok=True)
    out=ROOT/'male/source/v1-citizen';out.mkdir(parents=True,exist_ok=True)
    datp=REPO/'data/things/860/Tibia.dat';sprp=REPO/'data/things/860/Tibia.spr'
    dat,spr=datp.read_bytes(),sprp.read_bytes();things,_=parse_dat(dat)
    t=next(t for t in things if t.category==1 and t.client_id==128)
    assert t.size==(2,2) and t.layout==(2,4,3,1,3)
    sheets=[Image.new('RGBA',(144,192)) for _ in range(2)]
    allowed=Image.new('RGB',(144,192));protected_sheet=Image.new('L',(144,192));records=[]
    for row,d in enumerate(['north','east','south','west']):
        for phase in range(3):
            frames=[]
            for layer in range(2):
                image=Image.new('RGBA',(64,64));ids=[]
                for y in range(2):
                    for x in range(2):
                        index=((((phase*1)*3+0)*4+row)*2+layer)*4+y*2+x
                        sid=t.sprites[index];ids.append(sid)
                        image.paste(sprite_image(spr,sid),((1-x)*32,(1-y)*32))
                image=image.crop((24,24,72,72));frames.append(image)
                name=f'citizen-male-{d}-{phase}{"-mask" if layer else ""}.png'
                image.save(refs/name);sheets[layer].paste(image,(phase*48,row*48))
                records.append({'direction':d,'phase':phase,'layer':layer,'file':name,'sprite_ids':ids,'bbox':image.getbbox()})
            art,mask=frames;cloth=Image.new('L',(48,48));fixed=Image.new('L',(48,48))
            for y in range(48):
                for x in range(48):
                    p=art.getpixel((x,y));m=mask.getpixel((x,y))
                    if m[3] and m[:3] in [(255,0,0),(0,255,0)]:cloth.putpixel((x,y),255)
                    if m[3] and m[:3] in [(255,255,0),(0,0,255)]:fixed.putpixel((x,y),255)
                    if p[3] and not m[3] and p[0]>p[1]*1.05 and p[1]>p[2]*1.1:fixed.putpixel((x,y),255)
            cloth=cloth.filter(ImageFilter.MaxFilter(7));fixed=fixed.filter(ImageFilter.MaxFilter(3))
            for y in range(48):
                for x in range(48):
                    q=(phase*48+x,row*48+y)
                    if fixed.getpixel((x,y)):protected_sheet.putpixel(q,255)
                    if cloth.getpixel((x,y)) and not fixed.getpixel((x,y)) and 4<=x<40 and 10<=y<39:
                        allowed.putpixel(q,(255,255,255))
    sheets[0].save(out/'native-source-sheet.png');sheets[1].save(out/'native-color-mask-sheet.png')
    allowed.save(out/'garment-redesign-mask.png');protected_sheet.save(out/'protected-body-anchors.png')
    preview=Image.new('RGBA',sheets[0].size,(43,43,43,255));preview.alpha_composite(sheets[0]);preview.resize((576,768),Image.Resampling.NEAREST).save(out/'citizen-reference-preview.png')
    metadata={'reference_looktype':128,'reference_name':'Citizen male / standard starter outfit',
        'native_cell':[64,64],'working_cell':[48,48],'reference_crop_translation':[-24,-24],
        'scaled':False,'columns':['idle','step1','step2'],'rows':['north','east','south','west'],
        'dat_sha256':hashlib.sha256(dat).hexdigest(),'spr_sha256':hashlib.sha256(spr).hexdigest(),
        'frames':records,'native_body_anchors':'Head/hair, face, hands and boots fixed during garment inpainting.'}
    (refs/'native-poses.json').write_text(json.dumps(metadata,indent=2)+'\n')
    print(json.dumps({'reference':128,'layers':len(records),'source':str(out/'native-source-sheet.png')}))


if __name__=='__main__':main()
