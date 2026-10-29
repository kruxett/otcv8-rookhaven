"""Isolate AI-painted equipment by native part masks, no new pixel painting."""
from pathlib import Path
import importlib.util,json
from PIL import Image,ImageDraw,ImageFont,ImageFilter
P=Path(__file__).resolve().parent
C=[(255,255,0,255),(255,0,0,255),(0,255,0,255),(0,0,255,255)]
F=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',15)

def pos(t,d,f):return (d%2*120+f*40,t*80+d//2*40)
def warm(p):return p[3] and p[0]>=p[1]+8 and p[1]>=p[2]+8 and p[0]>55

def main():
    art=Image.open(P/'pixellab-corrected-original.png').convert('RGBA')
    source_mask=Image.open(P/'warrior-all36-native-mask.png').convert('RGBA')
    model_mask=Image.open(P/'ai-mask-all36.png').convert('RGBA')
    layers=[Image.new('RGBA',(120,160)) for _ in range(3)]
    masks=[Image.new('RGBA',(120,160)) for _ in range(3)]
    conversion=0;counts=[0,0];skin_protected=0;missing=[]
    for d in range(4):
        for phase in range(3):
            cells=[];guides=[];preds=[]
            for t in range(3):
                x,y=pos(t,d,phase);box=(x,y,x+40,y+40)
                cells.append(art.crop(box));guides.append(source_mask.crop(box));preds.append(model_mask.crop(box))
            head=Image.new('L',(40,40));shoulder=Image.new('L',(40,40))
            for y in range(40):
                for x in range(40):
                    # Use AI's matching helmet labels, not the old outfit's hair
                    # footprint which can extend down onto the new forearm.
                    for predicted in [preds[0].getpixel((x,y)),preds[1].getpixel((x,y))]:
                        r,g,b,alpha=predicted
                        if alpha and r>60 and g>60 and b<min(r,g)*.55 and abs(r-g)<80:
                            head.putpixel((x,y),255)
            # Reject detached yellow misclassifications on hands/equipment.
            remaining={(x,y) for y in range(40) for x in range(40) if head.getpixel((x,y))}
            components=[]
            while remaining:
                point=remaining.pop();component={point};stack=[point]
                while stack:
                    xx,yy=stack.pop()
                    for dx in (-1,0,1):
                        for dy in (-1,0,1):
                            neighbor=(xx+dx,yy+dy)
                            if neighbor in remaining:
                                remaining.remove(neighbor);component.add(neighbor);stack.append(neighbor)
                components.append(component)
            assert components
            component=max(components,key=len);head=Image.new('L',(40,40))
            for coordinate in component:head.putpixel(coordinate,255)
            head_bounds=head.getbbox();assert head_bounds
            head_allow=head.filter(ImageFilter.MaxFilter(3))
            near=head.filter(ImageFilter.MaxFilter(17))
            y_limit=(head_bounds[1]+head_bounds[3])//2+9
            for y in range(40):
                for x in range(40):
                    if guides[0].getpixel((x,y))==C[1] and near.getpixel((x,y)) and y<=y_limit:
                        shoulder.putpixel((x,y),255)
            shoulder_allow=shoulder.filter(ImageFilter.MaxFilter(3))
            label_map=Image.new('RGBA',(40,40));base=cells[0].copy();fixed=set()
            for y in range(40):
                for x in range(40):
                    p=base.getpixel((x,y));native=guides[0].getpixel((x,y));pred=preds[0].getpixel((x,y))
                    if not p[3]:continue
                    if warm(p) and (head_allow.getpixel((x,y)) or native[3]==0):
                        fixed.add((x,y));skin_protected+=1;continue
                    # Mask metadata: prefer native region, then saturated AI label.
                    label=native if native in C else None
                    if not label:
                        maximum=max(pred[:3]);chroma=maximum-min(pred[:3])
                        if pred[3] and maximum>=24 and chroma/maximum>=.5:
                            rgb=[round(v*255/maximum) for v in pred[:3]]
                            label=min(C,key=lambda c:sum((rgb[i]-c[i])**2 for i in range(3)))
                    if p[2]>p[0]+35 and p[1]>p[0]+15:label=C[3]
                    if label:label_map.putpixel((x,y),label)
                    else:missing.append((d,phase,x,y))
            # Complete only mask metadata from nearest existing part label in cell.
            labels=[(x,y,label_map.getpixel((x,y))) for y in range(40) for x in range(40) if label_map.getpixel((x,y)) in C]
            for dd,ff,x,y in [m for m in missing if m[0]==d and m[1]==phase]:
                if (x,y) not in fixed and labels:
                    label=min(labels,key=lambda q:((q[0]-x)**2+(q[1]-y)**2,q[1],q[0]))[2];label_map.putpixel((x,y),label)
            selected=[Image.new('RGBA',(40,40)) for _ in range(2)]
            selected_mask=[Image.new('RGBA',(40,40)) for _ in range(2)]
            for y in range(40):
                for x in range(40):
                    p0,p1,p2=[im.getpixel((x,y)) for im in cells]
                    if (x,y) in fixed:continue
                    # Keep AI-painted helmet upgrade and shoulder/collar equipment;
                    # discard unrelated wardrobe/weapons changing between raw tiers.
                    if head_allow.getpixel((x,y)) and y<=head_bounds[3] and p1[3] and not warm(p1) and p1!=p0:
                        selected[0].putpixel((x,y),p1);selected_mask[0].putpixel((x,y),C[0]);counts[0]+=1
                    if shoulder_allow.getpixel((x,y)) and not head_allow.getpixel((x,y)) and y<=y_limit and p2[3] and not warm(p2) and p2!=p1:
                        selected[1].putpixel((x,y),p2);selected_mask[1].putpixel((x,y),C[1]);counts[1]+=1
            # Required technical outfit encoding: neutral RGB at original luma.
            for im,mask in [(base,label_map),*zip(selected,selected_mask)]:
                for y in range(40):
                    for x in range(40):
                        p=im.getpixel((x,y))
                        if p[3] and mask.getpixel((x,y)) in C and not p[0]==p[1]==p[2]:
                            v=round(.2126*p[0]+.7152*p[1]+.0722*p[2]);im.putpixel((x,y),(v,v,v,p[3]));conversion+=1
            for layer,im,m in [(0,base,label_map),(1,selected[0],selected_mask[0]),(2,selected[1],selected_mask[1])]:
                layers[layer].paste(im,(phase*40,d*40));masks[layer].paste(m,(phase*40,d*40))
    result=Image.new('RGBA',(240,240));mask_result=result.copy()
    for d in range(4):
        for f in range(3):
            box=(f*40,d*40,f*40+40,d*40+40);composed=layers[0].crop(box);cmask=masks[0].crop(box)
            for t in range(3):
                if t:
                    composed=Image.alpha_composite(composed,layers[t].crop(box));cmask=Image.alpha_composite(cmask,masks[t].crop(box))
                result.paste(composed,pos(t,d,f));mask_result.paste(cmask,pos(t,d,f))
    for i,(layer,mask) in enumerate(zip(layers,masks)):
        layer.save(P/f'isolated-layer-{i}-all12.png');mask.save(P/f'isolated-mask-{i}-all12.png')
    result.save(P/'composed-neutral-all36.png');mask_result.save(P/'composed-working-mask-all36.png')
    board=Image.new('RGB',(660,800),'#24272b');draw=ImageDraw.Draw(board)
    for t,label in enumerate(['Bas','Bas + addon 1','Bas + båda']):
        for d,heading in enumerate(['Norr','Öster','Söder','Väster']):
            x,y=pos(t,d,0);cell=result.crop((x,y,x+40,y+40));draw.text((t*220+6,d*200+5),f'{heading} · {label}',font=F,fill='white');z=cell.resize((160,160),Image.Resampling.NEAREST);board.paste(z,(t*220+12,d*200+29),z)
    board.save(P/'isolated-composed-all-directions-review.png')
    report={'manual_painted_pixels':0,'art_pixels_source':'unchanged AI pixels selected into native base/addon layers; original source images preserved',
        'technical_grayscale_encoding_pixels':conversion,'addon_pixels':counts,'fixed_AI_skin_pixels':skin_protected,
        'mask_label_fallback_pixels':len(missing),'method':'largest connected AI yellow helmet-label component across base/addon1, expanded1px and limited to helmet bottom; native upper torso red mask within8px of head, limited by head center+9px, expanded1px. No arbitrary hand-painted shapes. All other base garment pixels reused exactly.',
        'review_status':'pending visual review of layer seams and geometry; not imported'}
    (P/'layer-extraction.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))

if __name__=='__main__':main()
