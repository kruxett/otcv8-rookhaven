"""Read native art and masks. Pack references/templates only; no sprite painting."""
from pathlib import Path
import sys,json,hashlib
from PIL import Image,ImageDraw,ImageFont
SOURCE=Path(__file__).resolve().parent
MALE=SOURCE.parent
REPO=MALE.parents[3]
OUT=SOURCE/'v20-base-and-addons'
sys.path.insert(0,str(REPO/'tools'))
from item_assets import parse_dat,sprite_image
COLORS=[(255,255,0,255),(255,0,0,255),(0,255,0,255),(0,0,255,255)]
DIRECTIONS=['north','east','south','west']

def tile_pos(layer,direction,phase):
    return ((direction%2)*120+phase*40,layer*80+(direction//2)*40)

def extract(t,spr,addon,direction,phase,layer):
    w,h=t.size;L,nx,ny,nz,nf=t.layout
    im=Image.new('RGBA',(w*32,h*32))
    for y in range(h):
        for x in range(w):
            index=(((((phase*nz)*ny+addon)*nx+direction)*L+layer)*h+y)*w+x
            im.paste(sprite_image(spr,t.sprites[index]),((w-x-1)*32,(h-y-1)*32))
    return im

def main():
    assert not OUT.exists()
    OUT.mkdir()
    (OUT/'references').mkdir()
    dat=(REPO/'data/things/860/Tibia.dat').read_bytes()
    spr=(REPO/'data/things/860/Tibia.spr').read_bytes()
    things,_=parse_dat(dat)
    records=[]
    raw_refs=[];mask_refs=[];full_refs=[]
    all_full=Image.new('RGBA',(240,240))
    colored_full=Image.new('RGBA',(240,240))
    for ref_index,(looktype,name) in enumerate([(134,'Warrior'),(289,'Demon Hunter'),(367,'Wayfarer')]):
        t=next(t for t in things if t.category==1 and t.client_id==looktype)
        assert t.size==(2,2) and t.layout==(2,4,3,1,3)
        art=Image.new('RGBA',(240,240));mask=Image.new('RGBA',(240,240))
        native=Image.new('RGBA',(576,512))
        native_combinations=Image.new('RGBA',(768,256))
        for d in range(4):
            for phase in range(3):
                combined=Image.new('RGBA',(64,64))
                combined_mask=Image.new('RGBA',(64,64))
                original=[]
                for addon in range(3):
                    ims=[]
                    for layer in range(2):
                        im=extract(t,spr,addon,d,phase,layer)
                        bbox=im.getbbox()
                        assert not bbox or bbox[0]>=24 and bbox[1]>=24,(name,addon,d,phase,layer,bbox)
                        # Exact 64px source saved too; crop removes empty margins only.
                        native.paste(im,(addon*192+phase*64,layer*256+d*64))
                        cropped=im.crop((24,24,64,64))
                        (art if layer==0 else mask).paste(cropped,tile_pos(addon,d,phase))
                        ims.append(im)
                    original.append(ims)
                    combined=Image.alpha_composite(combined,ims[0])
                    combined_mask=Image.alpha_composite(combined_mask,ims[1])
                for bits in range(4):
                    composed=original[0][0].copy()
                    for addon in (1,2):
                        if bits&(1<<(addon-1)):
                            composed=Image.alpha_composite(composed,original[addon][0])
                    native_combinations.paste(composed,(bits*192+phase*64,d*64))
                all_full.paste(combined.crop((24,24,64,64)),tile_pos(ref_index,d,phase))
                tint=combined.copy()
                palette=[(130,150,190),(65,95,140),(125,130,145),(160,175,195)]
                for y in range(64):
                    for x in range(64):
                        m=combined_mask.getpixel((x,y));p=combined.getpixel((x,y))
                        if m in COLORS and p[3]:
                            c=palette[COLORS.index(m)]
                            tint.putpixel((x,y),(*(round(p[i]*c[i]/255) for i in range(3)),p[3]))
                colored_full.paste(tint.crop((24,24,64,64)),tile_pos(ref_index,d,phase))
        slug=name.lower().replace(' ','-')
        art.save(OUT/'references'/f'{looktype}-{slug}-all36-art.png')
        mask.save(OUT/'references'/f'{looktype}-{slug}-all36-color-mask.png')
        native.save(OUT/'references'/f'{looktype}-{slug}-NATIVE-base-addons-masks.png')
        native_combinations.save(OUT/'references'/f'{looktype}-{slug}-NATIVE-all-combinations.png')
        raw_refs.append(art);mask_refs.append(mask)
        records.append({'looktype':looktype,'name':name,'art_frames':36,'color_mask_frames':36,
            'directions':DIRECTIONS,'phases':[0,1,2],'independent_layers':['base','addon1','addon2'],
            'all_combinations_exported':[0,1,2,3],'native_layout':list(t.layout),
            'reference_native_canvas':[64,64],'lossless_crop':[24,24,64,64],
            'body_and_addons_clipped':False,'resized':False})
    citizen=next(t for t in things if t.category==1 and t.client_id==128)
    template=Image.new('RGBA',(240,240));paint=Image.new('RGB',(240,240),'black')
    native_citizen=Image.new('RGBA',(120,160));native_mask=Image.new('RGBA',(120,160))
    for d in range(4):
        for phase in range(3):
            im=extract(citizen,spr,0,d,phase,0).crop((24,24,64,64))
            m=extract(citizen,spr,0,d,phase,1).crop((24,24,64,64))
            pos=tile_pos(0,d,phase)
            template.paste(im,pos)
            native_citizen.paste(im,(phase*40,d*40));native_mask.paste(m,(phase*40,d*40))
            for y in range(40):
                for x in range(40):
                    if im.getpixel((x,y))[3] and m.getpixel((x,y)) in COLORS:
                        paint.putpixel((pos[0]+x,pos[1]+y),(255,255,255))
            for addon in (1,2):
                ax,ay=tile_pos(addon,d,phase)
                # Blank independent overlay cells, keep one pixel transparent gutter.
                ImageDraw.Draw(paint).rectangle((ax+1,ay+1,ax+38,ay+38),fill='white')
    template.save(OUT/'target-all36.png');paint.save(OUT/'generation-mask-all36.png')
    native_citizen.save(OUT/'citizen-all12-poses.png');native_mask.save(OUT/'citizen-all12-mask.png')
    context=Image.new('RGBA',(720,720))
    for index in range(3):
        context.paste(raw_refs[index],(0,index*240))
        context.paste(mask_refs[index],(240,index*240))
    context.paste(template,(480,0))
    context.paste(all_full,(480,240))
    context.paste(colored_full,(480,480))
    context.save(OUT/'complete-reference-context.png')
    all_full.save(OUT/'references/full-outfit-combinations-all36.png')
    colored_full.save(OUT/'references/full-outfit-tint-example-all36.png')
    # Review board labels live outside the actual reference images.
    board=Image.new('RGB',(1020,900),'#25282c');draw=ImageDraw.Draw(board)
    font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',16)
    for i,record in enumerate(records):
        y=i*300
        draw.text((10,y+4),f'{record["name"]}: bas / addon 1 / addon 2 – samtliga poser',font=font,fill='white')
        art=raw_refs[i].resize((240,240),Image.Resampling.NEAREST)
        board.paste(art,(12,y+35),art)
        board.paste(mask_refs[i],(270,y+35),mask_refs[i])
        draw.text((525,y+35),'Separata native-lager och färgmasker',font=font,fill='white')
        draw.text((525,y+65),'Varje lager: N stå/gång A/gång B, Ö stå/gång A/gång B',font=font,fill='white')
        draw.text((525,y+95),'Nästa rad: S stå/gång A/gång B, V stå/gång A/gång B',font=font,fill='white')
    board.save(OUT/'references-overview.png')
    manifest={'status':'references prepared; no new artwork generated yet',
        'references':records,'reference_art_frames':108,'reference_color_mask_frames':108,
        'extra_composite_and_tint_frames':72,'all_reference_pixels_from_existing_DAT_SPR':True,
        'old_rune_sentinel_art_as_reference':False,'native_pose_source':128,
        'sheet_size':[240,240],'cell_size':[40,40],
        'rows':['base N0 N1 N2 E0 E1 E2','base S0 S1 S2 W0 W1 W2',
            'addon1 N0 N1 N2 E0 E1 E2','addon1 S0 S1 S2 W0 W1 W2',
            'addon2 N0 N1 N2 E0 E1 E2','addon2 S0 S1 S2 W0 W1 W2'],
        'context_size':[720,720],'source_bbox_in_context':{'x':480,'y':0,'width':240,'height':240},
        'source_dat_sha256':hashlib.sha256(dat).hexdigest(),'source_spr_sha256':hashlib.sha256(spr).hexdigest()}
    (OUT/'reference-manifest.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    print(json.dumps({'output':str(OUT),'native_art_and_mask_frames':216,'native_composite_examples':72,'target_frames':36,'no_cropping_loss':True}))

if __name__=='__main__':main()
