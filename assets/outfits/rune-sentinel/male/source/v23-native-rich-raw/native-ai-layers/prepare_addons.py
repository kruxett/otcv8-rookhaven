"""Explicit native layer paint domains BEFORE AI generation, never art extraction."""
from pathlib import Path
from PIL import Image,ImageFilter
import json
P=Path(__file__).resolve().parent
C=[(255,255,0,255),(255,0,0,255)]

def slot(t,d,f):return (d%2*120+f*40,t*80+d//2*40)

def main():
    base=Image.open(P/'base-all12-pixellab-original.png').convert('RGBA')
    parts=Image.open(P/'native-part-mask-all12.png').convert('RGBA')
    protected=Image.open(P/'protected-native-all12.png').convert('RGBA')
    target=Image.new('RGBA',(240,240));mask=Image.new('RGB',(240,240),'black')
    crown_domains=Image.new('L',(120,160));shoulder_domains=crown_domains.copy();details=[]
    for d in range(4):
        for f in range(3):
            box=(f*40,d*40,f*40+40,d*40+40);actor=base.crop(box);guide=parts.crop(box);keep=protected.crop(box)
            head=Image.new('L',(40,40));red=head.copy()
            for y in range(40):
                for x in range(40):
                    if guide.getpixel((x,y))==C[0]:head.putpixel((x,y),255)
                    if guide.getpixel((x,y))==C[1]:red.putpixel((x,y),255)
            x0,y0,x1,y1=head.getbbox();middle_y=(y0+y1)//2
            crest=Image.new('L',(40,40));caps=crest.copy();head_keep=head.filter(ImageFilter.MaxFilter(3));near_head=head.filter(ImageFilter.MaxFilter(17))
            upper=Image.new('L',(40,40))
            for y in range(40):
                for x in range(40):
                    if red.getpixel((x,y)) and near_head.getpixel((x,y)) and y<=middle_y+4:upper.putpixel((x,y),255)
            upper=upper.filter(ImageFilter.MaxFilter(7))
            for y in range(1,39):
                for x in range(1,39):
                    if keep.getpixel((x,y))[3]:continue
                    if d==0:in_crest=(x0-1<=x<=x1+1 and y1-4<=y<=y1+4)
                    elif d==1:in_crest=(x0-4<=x<=x0+2 and y0-1<=y<=y1+1)
                    elif d==2:in_crest=(x0-1<=x<=x1+1 and y0-4<=y<=y0+2)
                    else:in_crest=(x1-4<=x<=x1+4 and y0-1<=y<=y1+1)
                    if in_crest:crest.putpixel((x,y),255)
            for y in range(1,39):
                for x in range(1,39):
                    if keep.getpixel((x,y))[3] or head_keep.getpixel((x,y)) or crest.getpixel((x,y)):continue
                    if upper.getpixel((x,y)) and y<=middle_y+7:caps.putpixel((x,y),255)
            for t in range(3):target.paste(actor,slot(t,d,f))
            for t,domain in [(1,crest),(2,caps)]:
                sx,sy=slot(t,d,f)
                for y in range(40):
                    for x in range(40):
                        if domain.getpixel((x,y)):mask.putpixel((sx+x,sy+y),(255,255,255))
            crown_domains.paste(crest,(f*40,d*40));shoulder_domains.paste(caps,(f*40,d*40))
            details.append({'direction':['north','east','south','west'][d],'phase':f,'native_head_bbox':[x0,y0,x1,y1],
                'crown_domain_pixels':sum(v>0 for v in crest.get_flattened_data()),'shoulder_domain_pixels':sum(v>0 for v in caps.get_flattened_data())})
    target.save(P/'addon-generation-visible-base-all36.png');mask.save(P/'addon-generation-domains.png')
    crown_domains.save(P/'addon1-explicit-domain-all12.png');shoulder_domains.save(P/'addon2-explicit-domain-all12.png')
    context=Image.open(P.parent/'rear-crest-reference-context.png').convert('RGBA');context.paste(target,(480,360))
    for y in range(600,720):
        for x in range(480,720):
            if context.getpixel((x,y))==(70,220,255,255):context.putpixel((x,y),(235,235,235,255))
    context.save(P/'addon-native-reference-context.png')
    metadata={'base':'one actual AI base pose for each of12 frames, reused exactly before generation',
        'tier0':'base reference only, black mask, no new-layer output','tier1':'addon1 rear helmet comb only, all12 poses',
        'tier2':'addon2 shoulder/collar regions only, all12 poses, disjoint with base helmet and addon1 domain',
        'export':'PixelLab New layer with changes, transparent everywhere outside explicit pre-generation mask',
        'no_post_generation_art_clipping_or_color_processing':True,'native_eyes_hands_and_contours_excluded':True,
        'crest_rear_projection_constrained_by_mask':{'north':'below helmet','east':'left of helmet','south':'above helmet','west':'right of helmet'},'per_pose_domains':details}
    (P/'addon-layer-contract.json').write_text(json.dumps(metadata,indent=2)+'\n')
    print(json.dumps({'base_poses':12,'addon1_poses':12,'addon2_poses':12,'new_layer_domains_predefined':True,'actor_leg_pixels_mutable':False}))

if __name__=='__main__':main()
