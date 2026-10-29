"""Package PixelLab's four native idle direction studies without repainting art."""
from pathlib import Path
import sys,json,hashlib
from PIL import Image,ImageDraw,ImageFont

REPO=Path(__file__).resolve().parents[4]
sys.path.insert(0,str(REPO/'assets/outfits/rookwarden/tools'))
from export_editable import write_ase,write_ora
root=REPO/'assets/outfits/rune-sentinel/male'
src=root/'source/v8-four-directions';out=root/'editable-v8-four-directions'
if out.exists():raise SystemExit('Preserve existing editable project; select a new version.')
directions=['north','east','south','west'];labels=['Nord','Öst','Syd','Väst']
native_sheet=Image.new('RGBA',(256,64));mask_sheet=Image.new('RGBA',(256,64));full_sheet=Image.new('RGBA',(256,64));layers=[];qa={}
for i,di in enumerate(directions):
    native=Image.open(src/f'{di}-native.png').convert('RGBA')
    mask=Image.open(src/f'{di}-native-mask.png').convert('RGBA')
    if di=='south':
        source=root/'editable-v7b-shoulder-fit/variant-3.png'
        im=Image.open(source).convert('RGBA')
        qa[di]={'existing_south_unchanged':True,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest()}
    else:
        folder=src/di;im=Image.open(folder/'full-outfit.png').convert('RGBA')
        guard=Image.open(folder/'fixed-native-pixels.png').convert('L');edit=Image.open(folder/'generation-mask.png').convert('RGB')
        coverage=fixed=outside=partial=0
        for y in range(64):
            for x in range(64):
                p=x,y;v=im.getpixel(p);old=native.getpixel(p)
                coverage+=bool(old[3]) and not bool(v[3])
                fixed+=bool(guard.getpixel(p)) and v!=old
                outside+=edit.getpixel(p)!=(255,255,255) and v!=old
                partial+=v[3] not in [0,255]
        assert coverage==fixed==outside==partial==0,(di,coverage,fixed,outside,partial)
        assert all(bool(im.getpixel((x,y))[3])==bool(native.getpixel((x,y))[3]) for y in range(45,64)for x in range(64)),('lower pose silhouette shifted',di)
        qa[di]={'erased_native_coverage':coverage,'fixed_native_face_hands_outline_changes':fixed,'outside_mask_changes':outside,'partial_alpha':partial,'lower_pose_silhouette_identical':True}
    full_sheet.alpha_composite(im,(i*64,0));native_sheet.alpha_composite(native,(i*64,0));mask_sheet.alpha_composite(mask,(i*64,0))
    layer=Image.new('RGBA',(256,64));layer.alpha_composite(im,(i*64,0));layers.append((f'{di.upper()} - fully dressed color concept',layer,True,True))
layers=[('NATIVE_CITIZEN_POSE_REFERENCE',native_sheet,False,False),('NATIVE_CITIZEN_MASK_REFERENCE_NOT_FINAL',mask_sheet,False,False)]+layers
out.mkdir();full_sheet.save(out/'rune-sentinel-four-directions.png');native_sheet.save(out/'native-pose-reference.png')
for i,di in enumerate(directions):full_sheet.crop((i*64,0,(i+1)*64,64)).save(out/f'{di}.png')
write_ase(out/'rune-sentinel-four-directions.aseprite',layers)
write_ora(out/'rune-sentinel-four-directions.ora',layers,full_sheet,'Rune Sentinel - four native idle direction color studies')
font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',17);small=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',12)
preview=Image.new('RGB',(520,672),(43,43,43));draw=ImageDraw.Draw(preview)
for i,(di,label)in enumerate(zip(directions,labels)):
    x=(i%2)*260;y=(i//2)*336;im=full_sheet.crop((i*64,0,(i+1)*64,64));draw.text((x+12,y+9),label,font=font,fill='white')
    zoom=im.crop((24,20,64,64)).resize((200,220),Image.Resampling.NEAREST);preview.paste(zoom,(x+12,y+41),zoom)
    draw.text((x+12,y+279),'1× spelstorlek',font=small,fill=(190,190,190));preview.paste(im,(x+134,y+266),im)
preview.save(out/'four-directions-preview.png')
report={'stage':'fully dressed male idle color concept studies, all four directions; awaiting user graphic review','directions':directions,'native_canvas_per_direction':[64,64],'scaled':False,'direction_qa':qa,'ase_ora_layer_readback':'PASS: pixel-identical cels and PNG layers','reference_pose':'Actual Citizen looktype128 phase0 for each direction, translated from original extraction by +24 with no rotation/rescaling','remaining':['user review of the new north/east/west interpretations and shoulder placement','walking phases','coherent neutral base/four player-color masks','separate base/addon1/addon2 art layers for north/east/west','female counterpart','native import and in-game render verification'],'files':{p.name:hashlib.sha256(p.read_bytes()).hexdigest()for p in out.iterdir()if p.is_file()}}
(out/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(qa))
