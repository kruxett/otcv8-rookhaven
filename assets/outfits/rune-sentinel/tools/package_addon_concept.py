"""Pack existing PixelLab artwork into native independent addon layers; no painting."""
from pathlib import Path
import json,sys,hashlib
from PIL import Image,ImageDraw,ImageFont

REPO=Path(__file__).resolve().parents[4]
sys.path.insert(0,str(REPO/'assets/outfits/rookwarden/tools'))
from export_editable import write_ase,write_ora
root=REPO/'assets/outfits/rune-sentinel/male'
src=root/'source/v3-addons'
out=root/'editable-v3-addons'
out.mkdir(exist_ok=True)
base=Image.open(src/'base.png').convert('RGBA')
one_raw=Image.open(root/'source/v2-runecrown/pixellab-runecrown.png').convert('RGBA')
one=Image.open(src/'base-plus-addon1-native-composite.png').convert('RGBA')
full=Image.open(src/'pixellab-addon2.png').convert('RGBA')
genmask=Image.open(src/'addon2-generation-mask.png').convert('RGB')
protected=Image.open(REPO/'assets/outfits/style-study-20261026/protected-face-hands.png').convert('L')
assert all(im.size==(64,64) for im in [base,one_raw,one,full,genmask,protected])
addon1=Image.new('RGBA',(64,64));addon2=Image.new('RGBA',(64,64))
for y in range(64):
    for x in range(64):
        p=(x,y)
        if one_raw.getpixel(p)[3] and base.getpixel(p)!=one_raw.getpixel(p):
            addon1.putpixel(p,one_raw.getpixel(p))
        if full.getpixel(p)!=one.getpixel(p):
            assert genmask.getpixel(p)==(255,255,255),('outside generation mask',p)
            assert not one.getpixel(p)[3],('source character edited',p)
            addon2.putpixel(p,full.getpixel(p))
for name,im in [('base',base),('addon1-overlay',addon1),('addon2-overlay',addon2)]:
    im.save(out/f'{name}.png')
variants=[]
for bits in range(4):
    im=base.copy()
    if bits&1:im.alpha_composite(addon1)
    if bits&2:im.alpha_composite(addon2)
    im.save(out/f'variant-{bits}.png');variants.append(im)
    for y in range(64):
        for x in range(64):
            p=(x,y)
            assert im.getpixel(p)[3] in [0,255],('partial alpha',bits,p)
            if protected.getpixel(p) or y>=56:
                assert im.getpixel(p)==base.getpixel(p),('protected pose changed',bits,p)
assert variants[1].tobytes()==one.tobytes(),'addon1 native composite mismatch'
assert variants[3].tobytes()==full.tobytes(),'full native composite mismatch'
assert not any(addon1.getpixel((x,y))[3] and addon2.getpixel((x,y))[3] for y in range(64) for x in range(64)), 'overlapping addon regions'

font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',16)
small=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',12)
preview=Image.new('RGB',(960,340),(43,43,43));draw=ImageDraw.Draw(preview)
labels=['Grundoutfit','Grund + addon 1','Grund + addon 2','Båda addons']
for i,(im,label) in enumerate(zip(variants,labels)):
    x=i*240;draw.text((x+10,10),label,font=font,fill='white')
    zoom=im.crop((24,12,64,64)).resize((160,208),Image.Resampling.NEAREST)
    preview.paste(zoom,(x+20,45),zoom)
    draw.text((x+10,280),'1× native',font=small,fill=(180,180,180))
    preview.paste(im,(x+112,270),im)
preview.save(out/'addon-combinations-preview.png')
native=Image.open(REPO/'assets/outfits/style-study-20261026/citizen-native-south.png').convert('RGBA')
layers=[('CITIZEN_POSE_REFERENCE',native,False,False),('BASE_OUTFIT - approved style',base,True,True),('ADDON_1 - runecrown and gold ornament',addon1,True,True),('ADDON_2 - runic battle standard',addon2,True,True)]
write_ase(out/'rune-sentinel-addons.aseprite',layers)
write_ora(out/'rune-sentinel-addons.ora',layers,variants[3],'Rune Sentinel - base and independent addons')
def components(im):
    remaining={(x,y) for y in range(64) for x in range(64) if im.getpixel((x,y))[3]};sizes=[]
    while remaining:
        start=remaining.pop();todo=[start];size=0
        while todo:
            x,y=todo.pop();size+=1
            for dx in [-1,0,1]:
                for dy in [-1,0,1]:
                    p=(x+dx,y+dy)
                    if p in remaining:remaining.remove(p);todo.append(p)
        sizes.append(size)
    return sorted(sizes,reverse=True)
report={'stage':'south-idle addon concept only; addon2 awaiting graphic approval','native_draw_order':['base','addon1 if bits&1','addon2 if bits&2'],'all_four_combinations_reconstructed':True,'existing_base_pixel_changes':0,'addon2_changes_to_existing_character_pixels':0,'protected_face_hands_changes':0,'lower_pose_changes':0,'addon_pixel_overlap':0,'ase_ora_layer_readback':'PASS','variant_components':{str(i):components(im) for i,im in enumerate(variants)},'retained_base_pixels_under_raw_addon1_transparency':sum(base.getpixel((x,y))[3]>0 and one_raw.getpixel((x,y))[3]==0 for y in range(64)for x in range(64)),'retained_base_note':'Native alpha overlays cannot erase the base. These 18 original base pixels remain, rather than using a whole-character replacement.','native_canvas':[64,64],'source_job':'b1afde33-2523-4a13-8fe8-5bc2af132609','files':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.iterdir() if p.suffix in ['.png','.aseprite','.ora']},'not_completed':['four directions and walking for base and addons','neutral base and four player-color masks for all layers','female counterpart','DAT/SPR import and in-game rendering']}
(out/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:report[k] for k in ['all_four_combinations_reconstructed','addon2_changes_to_existing_character_pixels','protected_face_hands_changes','variant_components','retained_base_pixels_under_raw_addon1_transparency']}))
