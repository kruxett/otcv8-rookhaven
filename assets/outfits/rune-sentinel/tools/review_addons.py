"""Render native addon bit combinations directly from the local DAT/SPR."""
from pathlib import Path
import sys,json,hashlib,xml.etree.ElementTree as ET
from PIL import Image,ImageDraw,ImageFont

REPO=Path(__file__).resolve().parents[4]
sys.path.insert(0,str(REPO/'tools'))
sys.path.insert(0,str(REPO/'assets/outfits/rookwarden/tools'))
from item_assets import parse_dat,sprite_image
from export_editable import recolor

out=REPO/'assets/outfits/rune-sentinel/male/source/v3-addons/references'
out.mkdir(parents=True,exist_ok=True)
dat=(REPO/'data/things/860/Tibia.dat').read_bytes()
spr=(REPO/'data/things/860/Tibia.spr').read_bytes()
things,_=parse_dat(dat)
table={t.client_id:t for t in things if t.category==1}
definitions=ET.parse(REPO.parent/'Rookhaven/data/XML/outfits.xml').getroot()
looks=[128,131,134,144,152,279,335]
rows=[o for o in definitions if int(o.get('looktype')) in looks and o.get('enabled')=='yes']
atlas=Image.new('RGB',(1120,len(rows)*164),(43,43,43))
draw=ImageDraw.Draw(atlas);font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',13)
records=[]
for ri,o in enumerate(rows):
    look=int(o.get('looktype'));t=table[look];w,h=t.size;l,nx,ny,nz,nf=t.layout
    def layer(addon,di,phase):
        parts=[]
        for lay in range(min(l,2)):
            im=Image.new('RGBA',(w*32,h*32))
            for y in range(h):
                for x in range(w):
                    idx=(((((phase*nz)*ny+addon)*nx+di)*l+lay)*h+y)*w+x
                    im.paste(sprite_image(spr,t.sprites[idx]),((w-x-1)*32,(h-y-1)*32))
            parts.append(im)
        return recolor(parts[0],parts[1],(58,49,2,58)) if len(parts)>1 else parts[0]
    folder=out/str(look);folder.mkdir(exist_ok=True)
    for di,direction in enumerate(['north','east','south','west']):
        for addon in range(ny):layer(addon,di,0).save(folder/f'{direction}-layer-{addon}.png')
        for bits in range(4):
            im=layer(0,di,0)
            for addon in range(1,min(ny,3)):
                if bits&(1<<(addon-1)):im.alpha_composite(layer(addon,di,0))
            im.save(folder/f'{direction}-bits-{bits}.png')
    draw.text((8,ri*164+3),f'{o.get("name")} [{look}]',fill='white',font=font)
    for bits,label in enumerate(['Base','Base + addon 1','Base + addon 2','Base + both']):
        x=128+bits*248;draw.text((x,ri*164+3),label,fill='white',font=font)
        for di,direction in enumerate(['south','north']):
            im=Image.open(folder/f'{direction}-bits-{bits}.png').convert('RGBA').resize((128,128),Image.Resampling.NEAREST)
            atlas.paste(im,(x+di*114-14,ri*164+24),im)
    records.append({'name':o.get('name'),'looktype':look,'layout':t.layout,'pattern_y_layers':ny,'native_order':'base first; bit1 -> patternY1; bit2 -> patternY2'})
atlas.save(out/'existing-addon-combinations.png')
base=Image.open(REPO/'assets/outfits/style-study-20261026/c-rune-sentinel/pixellab-concept.png').convert('RGBA')
one=Image.open(REPO/'assets/outfits/rune-sentinel/male/source/v2-runecrown/pixellab-runecrown.png').convert('RGBA')
erased=[(x,y)for y in range(64)for x in range(64)if base.getpixel((x,y))[3] and not one.getpixel((x,y))[3]]
report={'dat_sha256':hashlib.sha256(dat).hexdigest(),'spr_sha256':hashlib.sha256(spr).hexdigest(),'references':records,'rune_sentinel_base_pixels_erased_by_addon1':erased}
(out/'review.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report))
