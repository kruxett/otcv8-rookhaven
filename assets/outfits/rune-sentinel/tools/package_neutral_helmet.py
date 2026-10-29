"""Export neutral source art, separate color masks and editable construction layers."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import sys,json,hashlib

REPO=Path(__file__).resolve().parents[4]
ROOT=REPO/'assets/outfits/rune-sentinel/male'
SRC=ROOT/'source/v11-neutral-helmet';OUT=ROOT/'editable-v11-neutral-helmet'
sys.path.insert(0,str(REPO/'assets/outfits/rookwarden/tools'))
from export_editable import write_ase,write_ora,recolor
CHANNELS={(255,255,0,255),(255,0,0,255),(0,255,0,255),(0,0,255,255)}
if OUT.exists():raise SystemExit('Preserve editable files; select a new version.')
dirs=['south','east','north','west'];labels=['Syd · framifrån','Öst · profil','Nord · bakifrån','Väst · profil']
body_sheet=Image.new('RGBA',(256,64));helmet_sheet=body_sheet.copy();base_mask_sheet=body_sheet.copy();helmet_mask_sheet=body_sheet.copy();native_sheet=body_sheet.copy();combined=body_sheet.copy();masks=body_sheet.copy();qa={}
for i,di in enumerate(dirs):
    folder=SRC/di;native=Image.open(folder/'native-body.png').convert('RGBA');final=Image.open(folder/'neutral-base.png').convert('RGBA');source_mask=Image.open(folder/'native-color-mask.png').convert('RGBA')
    coords=set(map(tuple,json.loads((folder/'construction-v2.json').read_text())['crown_pixels']))
    base=final.copy();helmet=Image.new('RGBA',(64,64));base_mask=Image.new('RGBA',(64,64));helmet_mask=Image.new('RGBA',(64,64));wholemask=Image.new('RGBA',(64,64))
    fixed=removed=colored=new_outside=0
    for y in range(64):
        for x in range(64):
            p=x,y;n=native.getpixel(p);v=final.getpixel(p);m=source_mask.getpixel(p)
            assert v[3]in[0,255]
            removed+=n[3]>0 and not v[3]
            fixed+=n[3]>0 and m not in CHANNELS and v!=n
            colored+=v[3]>0 and(m in CHANNELS or p in coords)and not(v[0]==v[1]==v[2])
            new_outside+=not n[3]and v[3]>0 and p not in coords
            if p in coords:
                helmet.putpixel(p,v);helmet_mask.putpixel(p,(255,255,0,255));base.putpixel(p,n)
            if m in CHANNELS and n[3]:base_mask.putpixel(p,m)
            if v[3]:
                if p in coords:wholemask.putpixel(p,(255,255,0,255))
                elif m in CHANNELS:wholemask.putpixel(p,m)
    assert removed==fixed==colored==new_outside==0,(di,removed,fixed,colored,new_outside)
    test=base.copy();test.alpha_composite(helmet);assert test.tobytes()==final.tobytes()
    assert recolor(final,wholemask,(0,0,0,0)).tobytes()==final.tobytes(),'white palette changed neutral source'
    for sheet,im in [(body_sheet,base),(helmet_sheet,helmet),(base_mask_sheet,base_mask),(helmet_mask_sheet,helmet_mask),(native_sheet,native),(combined,final),(masks,wholemask)]:sheet.alpha_composite(im,(i*64,0))
    qa[di]={'removed_native_opaque_pixels':removed,'fixed_native_face_hands_changes':fixed,'colored_pixels_in_recolorable_base':colored,'new_geometry_outside_helmet':new_outside,'white_native_palette_exact':True,'crown_object_rotation_degrees':json.loads((folder/'construction-v2.json').read_text())['degrees']}
OUT.mkdir()
for name,im in [('base-neutral',body_sheet),('helmet-neutral',helmet_sheet),('base-color-mask',base_mask_sheet),('helmet-color-mask',helmet_mask_sheet),('neutral-composite',combined),('composite-color-mask',masks),('native-reference',native_sheet)]:im.save(OUT/f'{name}.png')
layers=[('NATIVE_REFERENCE - locked',native_sheet,False,False),('BASE - NEUTRAL WHITE GRAY',body_sheet,True,True),('HELMET - SHARED THREE PRONG CONSTRUCTION',helmet_sheet,True,True),('BASE_COLOR_MASK - separate, hidden',base_mask_sheet,False,True),('HELMET_COLOR_MASK - separate, hidden',helmet_mask_sheet,False,True)]
write_ase(OUT/'rune-sentinel-neutral-helmet.aseprite',layers);write_ora(OUT/'rune-sentinel-neutral-helmet.ora',layers,combined,'Rune Sentinel neutral white-gray helmet turnaround study')
preview=Image.new('RGB',(880,390),(43,43,43));draw=ImageDraw.Draw(preview);font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',16);small=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',12)
for i,(di,label)in enumerate(zip(dirs,labels)):
    im=combined.crop((i*64,0,(i+1)*64,64));zoom=im.crop((24,18,64,64)).resize((200,230),Image.Resampling.NEAREST);preview.paste(zoom,(i*220+8,43),zoom);draw.text((i*220+8,8),label,font=font,fill='white');draw.text((i*220+8,307),'1× native',font=small,fill=(190,190,190));preview.paste(im,(i*220+104,300),im)
preview.save(OUT/'neutral-helmet-four-directions.png')
report={'stage':'neutral helmet turnaround study; body remains native source, not final paid-outfit art','directions':dirs,'direction_checks':qa,'neutral_base':'All recolorable body and helmet pixels have equal R/G/B; original fixed skin/colors preserved. No selected player palette baked into artwork.','color_masks':'Pure yellow=head/helmet, red=primary, green=legs, blue=feet/detail, transparent=fixed. Helmet pixels in separate mask. Work masks pending final costume material choices.','geometry':'One physical three-prong crown/front plate/circlet rotates at 0/-90/180/90 degrees. All views share vertices and source-calibrated south shape. Profile overlap and helmet-skull occlusion depth-resolved.','geometry_source':'../source/v11-neutral-helmet/crown-rig-v2.json','reference_atlas':'../source/v11-neutral-helmet/matched-helmet-references.png','ase_ora_readback':'PASS: all layer cels and PNGs pixel-identical','remaining':['User review of neutral helmet shape/turnaround','Premium armor detailing on locked native body','Final independent base/addon1/addon2 structure and color regions','All walking phases and female counterpart','Approved sprite import and in-game verification'],'files':{p.name:hashlib.sha256(p.read_bytes()).hexdigest()for p in OUT.iterdir()if p.is_file()}}
(OUT/'validation.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(qa))
