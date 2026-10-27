"""Read all currently enabled Rookhaven outfit graphics, including addons."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import xml.etree.ElementTree as ET
import json
import sys
import hashlib

HERE=Path(__file__).resolve().parent
REPO=HERE.parents[2]
sys.path.insert(0,str(REPO/'tools'))
sys.path.insert(0,str(REPO/'assets/outfits/rookwarden/tools'))
from item_assets import parse_dat,sprite_image
from export_editable import recolor


def main():
    dat=(REPO/'data/things/860/Tibia.dat').read_bytes();spr=(REPO/'data/things/860/Tibia.spr').read_bytes()
    things,_=parse_dat(dat);table={t.client_id:t for t in things if t.category==1}
    definitions=ET.parse(REPO.parent/'Rookhaven/data/XML/outfits.xml').getroot()
    records=[];font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',12)
    (HERE/'rookhaven').mkdir(exist_ok=True)
    for sex in ['1','0']:
        rows=[o for o in definitions if o.get('type')==sex and o.get('enabled')=='yes']
        canvas=Image.new('RGB',(1088,1008),(43,43,43));draw=ImageDraw.Draw(canvas)
        for i,o in enumerate(rows):
            look=int(o.get('looktype'));t=table[look];w,h=t.size;l,nx,ny,nz,nf=t.layout
            def frame(direction,phase,addons):
                result=Image.new('RGBA',(w*32,h*32))
                for addon in addons:
                    parts=[]
                    for layer in range(min(2,l)):
                        im=Image.new('RGBA',(w*32,h*32))
                        for y in range(h):
                            for x in range(w):
                                index=(((((phase*nz+0)*ny+addon)*nx+direction)*l+layer)*h+y)*w+x
                                im.paste(sprite_image(spr,t.sprites[index]),((w-x-1)*32,(h-y-1)*32))
                        parts.append(im)
                    colored=recolor(parts[0],parts[1],(58,49,2,58)) if len(parts)>1 else parts[0]
                    result.alpha_composite(colored)
                return result
            folder=HERE/'rookhaven'/f'{look}-{sex}';folder.mkdir(exist_ok=True)
            for direction,name in enumerate(['north','east','south','west']):
                for phase in range(nf):
                    for variant,addons in [('base',[0]),('full',list(range(ny)))]:
                        frame(direction,phase,addons).save(folder/f'{name}-{phase}-{variant}.png')
            x,y=(i%4)*272,(i//4)*168
            draw.text((x+8,y+4),f'{o.get("name")}  [{look}]',fill='white',font=font)
            draw.text((x+8,y+22),'Base',fill=(170,170,170),font=font)
            draw.text((x+144,y+22),'Full addons',fill=(170,170,170),font=font)
            for variant,dx in [('base',0),('full',136)]:
                im=Image.open(folder/f'south-0-{variant}.png').convert('RGBA').resize((128,128),Image.Resampling.NEAREST)
                canvas.paste(im,(x+dx,y+36),im)
            records.append({**o.attrib,'base_and_full_directions':4,'phases':nf,'layout':t.layout,'source':str(folder.relative_to(HERE))})
        canvas.save(HERE/f'rookhaven-{"male" if sex=="1" else "female"}.png')
    metadata={'outfit_variants':len(records),'families':len(set(o['name'].replace('Norsewoman','Norseman') for o in records)),
        'dat_sha256':hashlib.sha256(dat).hexdigest(),'spr_sha256':hashlib.sha256(spr).hexdigest(),
        'items':records,'note':'All enabled server-defined outfit variants, both sexes, base/full addons, four directions, all three native phases.'}
    (HERE/'rookhaven-index.json').write_text(json.dumps(metadata,indent=2)+'\n')
    print(json.dumps({'variants':len(records),'rendered_frames':sum(r['phases']*4*2 for r in records)}))


if __name__=='__main__':main()
