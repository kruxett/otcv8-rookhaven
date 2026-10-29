"""Prepare actual composed outfit references and native anatomy edit templates."""
from pathlib import Path
import sys,json
from PIL import Image,ImageFilter
P=Path(__file__).resolve().parent
sys.path.insert(0,str(P.parent))
from prepare_v20_full_outfit import tile_pos
C=[(255,255,0,255),(255,0,0,255),(0,255,0,255),(0,0,255,255)]
O=P/'composed-ai'
assert not O.exists()
O.mkdir()
context=Image.new('RGBA',(720,720))
for r,(look,name) in enumerate([(134,'warrior'),(289,'demon-hunter'),(367,'wayfarer')]):
    art=Image.open(P/f'references/{look}-{name}-all36-art.png').convert('RGBA')
    mask=Image.open(P/f'references/{look}-{name}-all36-color-mask.png').convert('RGBA')
    composed=Image.new('RGBA',(240,240));cmask=Image.new('RGBA',(240,240))
    for d in range(4):
        for phase in range(3):
            b=Image.new('RGBA',(40,40));m=b.copy()
            for tier in range(3):
                x,y=tile_pos(tier,d,phase)
                b=Image.alpha_composite(b,art.crop((x,y,x+40,y+40)))
                m=Image.alpha_composite(m,mask.crop((x,y,x+40,y+40)))
                composed.paste(b,(x,y));cmask.paste(m,(x,y))
    composed.save(O/f'{look}-complete-three-states.png');cmask.save(O/f'{look}-complete-three-state-masks.png')
    context.paste(composed,(0,r*240));context.paste(cmask,(240,r*240))
native=Image.open(P/'citizen-all12-poses.png').convert('RGBA')
colors=Image.open(P/'citizen-all12-mask.png').convert('RGBA')
target=Image.new('RGBA',(240,240));paint=Image.new('RGB',(240,240),'black')
protection=Image.new('RGBA',(240,240))
for d in range(4):
    for phase in range(3):
        cell=native.crop((phase*40,d*40,phase*40+40,d*40+40))
        cm=colors.crop((phase*40,d*40,phase*40+40,d*40+40))
        head=Image.new('L',(40,40));shoulder=head.copy();body=head.copy();fixed=head.copy()
        for y in range(40):
            for x in range(40):
                p=cell.getpixel((x,y));m=cm.getpixel((x,y))
                if p[3] and m in C:
                    body.putpixel((x,y),255)
                    if m==C[0]:head.putpixel((x,y),255)
                    if m==C[1] and y<27:shoulder.putpixel((x,y),255)
                elif p[3]:fixed.putpixel((x,y),255)
        for tier in range(3):
            x0,y0=tile_pos(tier,d,phase)
            target.paste(cell,(x0,y0))
            allowed=body.copy()
            if tier>=1:
                extra=head.filter(ImageFilter.MaxFilter(7))
                allowed=Image.frombytes('L',(40,40),bytes(max(a,b) for a,b in zip(allowed.tobytes(),extra.tobytes())))
            if tier>=2:
                extra=shoulder.filter(ImageFilter.MaxFilter(7))
                allowed=Image.frombytes('L',(40,40),bytes(max(a,b) for a,b in zip(allowed.tobytes(),extra.tobytes())))
            for y in range(40):
                for x in range(40):
                    if cell.getpixel((x,y))[3] and fixed.getpixel((x,y)):
                        protection.putpixel((x0+x,y0+y),cell.getpixel((x,y)))
                    if allowed.getpixel((x,y)) and not fixed.getpixel((x,y)) and 0<x<39 and 0<y<39:
                        paint.putpixel((x0+x,y0+y),(255,255,255))
target.save(O/'target-three-complete-states.png');paint.save(O/'generation-mask.png');protection.save(O/'fixed-native-skin-all36.png')
context.paste(target,(480,0))
context.paste(Image.open(P/'references/full-outfit-combinations-all36.png'),(480,240))
context.paste(Image.open(P/'references/full-outfit-tint-example-all36.png'),(480,480))
context.save(O/'complete-reference-context.png')
(P/'REVIEW-isolated-layer-attempt.md').write_text('Internally rejected. Native base pose preserved and calmer shading, but isolated addon layers were not anchored to corresponding body positions. Helmet overlays duplicated faces; shoulder overlays floated near the head. No user approval; never import this attempt.\n',encoding='utf-8')
(O/'layout.json').write_text(json.dumps({'size':[240,240],'cell':[40,40],
    'tiers':['base','base+addon1','base+addon1+addon2'],'row_layout':['N0 N1 N2 E0 E1 E2','S0 S1 S2 W0 W1 W2'],
    'native_body_looktype':128,'all36_skin_exactly_protected':True,
    'mask_only_growth_allowance':'3px dilation around native head for addon1, around native upper red torso for addon2; fixed native pixels excluded. This is a placement constraint, no painted addon artwork.',
    'reference_art_and_matching_masks':216,'source_bbox_in_context':{'x':480,'y':0,'width':240,'height':240}},indent=2)+'\n',encoding='utf-8')
print(str(O))
