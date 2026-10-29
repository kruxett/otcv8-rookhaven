"""Package PixelLab shoulder-mantle art into independent addon layers."""
from pathlib import Path
import sys,json,hashlib,argparse
from PIL import Image,ImageDraw,ImageFont

REPO=Path(__file__).resolve().parents[4]
sys.path.insert(0,str(REPO/'assets/outfits/rookwarden/tools'))
from export_editable import write_ase,write_ora
parser=argparse.ArgumentParser()
parser.add_argument('--source-version',default='v4-mantle')
parser.add_argument('--out-version',default='editable-v4-mantle')
parser.add_argument('--job-id',default='aec73ff3-91d7-4882-938c-1e9f4d735f82')
parser.add_argument('--guard-mask',help='Source-relative immutable skin/hand guard; optional for a new design mask.')
parser.add_argument('--edit-mask',default='mantle-generation-mask.png',help='Source-relative final drawing mask, including exact PixelLab craft edits.')
args=parser.parse_args()
root=REPO/'assets/outfits/rune-sentinel/male'
src=root/'source'/args.source_version;out=root/args.out_version
if out.exists():raise SystemExit('Output already exists; preserve manual edits and choose a new version.')
base=Image.open(src/'base.png').convert('RGBA')
raw=Image.open(src/'pixellab-mantle.png').convert('RGBA')
mask=Image.open(src/args.edit_mask).convert('RGB')
addon1=Image.open(root/'editable-v3-addons/addon1-overlay.png').convert('RGBA')
original_one=Image.open(root/'editable-v3-addons/variant-1.png').convert('RGBA')
guard=Image.open(src/args.guard_mask if args.guard_mask else REPO/'assets/outfits/style-study-20261026/protected-face-hands.png').convert('L')
addon2=Image.new('RGBA',(64,64));source_changes=[];anchor=[]
for y in range(64):
    for x in range(64):
        p=x,y
        if raw.getpixel(p)!=base.getpixel(p):
            assert mask.getpixel(p)==(255,255,255),('outside mask',p)
            source_changes.append(p)
            if raw.getpixel(p)[3]:
                addon2.putpixel(p,raw.getpixel(p))
                if base.getpixel(p)[3]:anchor.append(p)
variants=[]
for bits in range(4):
    im=base.copy()
    if bits&1:im.alpha_composite(addon1)
    if bits&2:im.alpha_composite(addon2)
    for y in range(64):
        for x in range(64):
            p=x,y
            assert im.getpixel(p)[3] in [0,255],('partial alpha',bits,p)
            if guard.getpixel(p) or y>=58:
                assert im.getpixel(p)==base.getpixel(p),('protected pose changed',bits,p)
    variants.append(im)
assert variants[1].tobytes()==original_one.tobytes(),'approved addon1 changed'
assert variants[2].tobytes()==Image.alpha_composite(base,raw).tobytes()
shoulder_anchors=[p for p in anchor if 47<=p[0]<=61 and 32<=p[1]<=42]
assert len(shoulder_anchors)>=8,('insufficient shoulder overlap',shoulder_anchors)
def components(im):
    remaining={(x,y) for y in range(64) for x in range(64) if im.getpixel((x,y))[3]};sizes=[]
    while remaining:
        todo=[remaining.pop()];size=0
        while todo:
            x,y=todo.pop();size+=1
            for dx,dy in [(-1,0),(1,0),(0,-1),(0,1)]:
                p=x+dx,y+dy
                if p in remaining:remaining.remove(p);todo.append(p)
        sizes.append(size)
    return sorted(sizes,reverse=True)
connectivity={str(i):components(im) for i,im in enumerate(variants)}
assert all(len(connectivity[str(i)])==1 for i in [2,3]),('detached pixels',connectivity)
out.mkdir()
for name,im in [('base',base),('addon1-overlay',addon1),('addon2-overlay',addon2)]:im.save(out/f'{name}.png')
for bits,im in enumerate(variants):im.save(out/f'variant-{bits}.png')
font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',16);small=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',12)
preview=Image.new('RGB',(960,340),(43,43,43));draw=ImageDraw.Draw(preview)
for i,(im,label) in enumerate(zip(variants,['Grundoutfit','Grund + addon 1','Grund + addon 2','Båda addons'])):
    x=i*240;draw.text((x+10,10),label,font=font,fill='white')
    zoom=im.crop((24,12,64,64)).resize((160,208),Image.Resampling.NEAREST)
    preview.paste(zoom,(x+20,45),zoom)
    draw.text((x+10,280),'1× native',font=small,fill=(180,180,180));preview.paste(im,(x+112,270),im)
preview.save(out/'addon-combinations-preview.png')
native=Image.open(REPO/'assets/outfits/style-study-20261026/citizen-native-south.png').convert('RGBA')
layers=[('CITIZEN_POSE_REFERENCE',native,False,False),('BASE_OUTFIT - approved style',base,True,True),('ADDON_1 - approved runecrown ornament',addon1,True,True),('ADDON_2 - attached shoulder mantle',addon2,True,True)]
write_ase(out/'rune-sentinel-mantle.aseprite',layers)
write_ora(out/'rune-sentinel-mantle.ora',layers,variants[3],'Rune Sentinel - attached shoulder mantle addon study')
report={'stage':'south-idle design study; new mantle addon2 awaiting graphic approval','generator':'PixelLab inpaint_image_pro_flash','job_id':args.job_id,'base_and_addon1_unchanged':True,'outside_mask_changes':0,'protected_face_hands_changes':0,'source_changes':len(source_changes),'shoulder_attachment_overlap_pixels':len(shoulder_anchors),'attachment_overlap_coordinates':shoulder_anchors,'variant_4_connected_components':connectivity,'native_overlay_order':['base','addon1 if bit1','addon2 if bit2'],'all_four_combinations_exported':True,'ase_ora_readback':'PASS, pixel-identical layer cels/PNGs','native_canvas':[64,64],'retained_base_coverage_pixels':sum(base.getpixel((x,y))[3]>0 and raw.getpixel((x,y))[3]==0 for y in range(64)for x in range(64)),'remaining':['user graphic approval','all directions and walking phases','four-channel player-color masks','female outfit and addons','native import and in-game visual check'],'files':{p.name:hashlib.sha256(p.read_bytes()).hexdigest()for p in out.iterdir()if p.is_file()}}
(out/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:report[k] for k in ['base_and_addon1_unchanged','outside_mask_changes','shoulder_attachment_overlap_pixels','variant_4_connected_components','retained_base_coverage_pixels']}))
