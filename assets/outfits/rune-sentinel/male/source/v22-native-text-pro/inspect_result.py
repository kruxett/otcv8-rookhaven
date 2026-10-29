"""Inspect/preview PixelLab's unchanged native result. No sprite art edits."""
from pathlib import Path
from collections import Counter
import json
from PIL import Image,ImageDraw,ImageFont
P=Path(__file__).resolve().parent
F=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',15)
LABELS=['Norr','Öster','Söder','Väster']
TIERS=['Bas','Bas + addon 1','Bas + båda']

def pos(t,d,f):return (d%2*120+f*40,t*80+d//2*40)

def warm(p):return p[3]>0 and p[0]>=p[1]+8 and p[1]>=p[2]+8 and p[0]>55

def white_dots(cell):
    selected={(x,y) for y in range(40) for x in range(40) if cell.getpixel((x,y))[3] and min(cell.getpixel((x,y))[:3])>=235}
    components=[]
    while selected:
        first=selected.pop();stack=[first];n=0
        while stack:
            x,y=stack.pop();n+=1
            for dx in (-1,0,1):
                for dy in (-1,0,1):
                    q=(x+dx,y+dy)
                    if q in selected:selected.remove(q);stack.append(q)
        components.append(n)
    return sum(n==1 for n in components)

def main():
    im=Image.open(P/'pixellab-pro-original.png').convert('RGBA')
    original=Image.open(P/'single-input-native-outfits-and-masks.png').convert('RGBA')
    qa={'canvas_expected':[512,512],'canvas_actual':list(im.size),'manual_artistic_edits':0,
        'visual_verdict':'pending human/model visual inspection','original_PixelLab_output_preserved':True}
    if im.size!=(512,512):
        qa['visual_verdict']='FAIL: canvas changed; do not infer requested grid'
        (P/'verification.json').write_text(json.dumps(qa,indent=2)+'\n');print(json.dumps(qa));return
    art=im.crop((0,0,240,240));mask=im.crop((240,0,480,240));before=original.crop((0,0,240,240))
    art.save(P/'ai-art-all36.png');mask.save(P/'ai-mask-all36.png')
    qa['changed_art_pixels']=sum(a!=b for a,b in zip(art.get_flattened_data(),before.get_flattened_data()))
    qa['style_reference_changed_pixels']=sum(a!=b for a,b in zip(im.crop((0,256,504,508)).get_flattened_data(),original.crop((0,256,504,508)).get_flattened_data()))
    qa['art_alpha_values']=sorted(set(art.getchannel('A').get_flattened_data()))
    qa['frames']=[]
    board=Image.new('RGB',(660,800),'#24272b');draw=ImageDraw.Draw(board)
    full=Image.new('RGB',(840,1010),'#24272b');fd=ImageDraw.Draw(full)
    animations=[]
    for t,label in enumerate(TIERS):
        for d,heading in enumerate(LABELS):
            for f,phase in enumerate(['Stå','Gång A','Gång B']):
                x,y=pos(t,d,f);cell=art.crop((x,y,x+40,y+40));old=before.crop((x,y,x+40,y+40))
                head=cell.crop((0,0,28,26));old_head=old.crop((0,0,28,26))
                qa['frames'].append({'tier':t,'direction':heading,'phase':f,'bbox':cell.getbbox(),
                    'opaque_pixels':sum(p[3]>0 for p in cell.get_flattened_data()),
                    'warm_head_pixels':sum(warm(p) for p in head.get_flattened_data()),
                    'native_warm_head_pixels':sum(warm(p) for p in old_head.get_flattened_data()),
                    'isolated_white_clusters':white_dots(cell),'native_isolated_white_clusters':white_dots(old)})
                if f==0:
                    bx=t*220;by=d*200;draw.text((bx+6,by+5),f'{heading} · {label}',font=F,fill='white')
                    z=cell.resize((160,160),Image.Resampling.NEAREST);board.paste(z,(bx+12,by+29),z);board.paste(cell,(bx+174,by+151),cell)
                bx=d%2*420+f*140;by=t*334+d//2*150+26
                if d==0 and f==0:fd.text((8,t*334+2),label,font=F,fill='white')
                fd.text((bx+4,by),f'{heading} · {phase}',font=F,fill='white');z=cell.resize((120,120),Image.Resampling.NEAREST);full.paste(z,(bx+8,by+23),z)
    for f in [1,2]:
        c=Image.new('RGB',(640,540),'#24272b');cd=ImageDraw.Draw(c)
        for t,label in enumerate(TIERS):
            for d,heading in enumerate(LABELS):
                x,y=pos(t,d,f);cell=art.crop((x,y,x+40,y+40));bx=d*160;by=t*180
                cd.text((bx+4,by+4),f'{label} · {heading}',font=F,fill='white');z=cell.resize((120,120),Image.Resampling.NEAREST);c.paste(z,(bx+20,by+30),z)
        animations.append(c)
    board.save(P/'all-directions-three-states-review.png');full.save(P/'all36-frames-review.png')
    animations[0].save(P/'walking-all-states.gif',save_all=True,append_images=animations[1:],duration=220,loop=0,disposal=2)
    qa['nonempty_frames']=sum(bool(f['bbox']) for f in qa['frames'])
    qa['mask_palette_top12']=[(list(c),n) for c,n in Counter(mask.get_flattened_data()).most_common(12)]
    (P/'verification.json').write_text(json.dumps(qa,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    print(json.dumps({k:v for k,v in qa.items() if k not in ['frames','mask_palette_top12']}))

if __name__=='__main__':main()
