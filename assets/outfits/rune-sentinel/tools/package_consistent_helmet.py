"""Pack the fixed south design and its explicit four-way direction mapping."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import sys,json,hashlib
REPO=Path(__file__).resolve().parents[4];ROOT=REPO/'assets/outfits/rune-sentinel/male'
SRC=ROOT/'source/v12-consistent-directions';OUT=ROOT/'editable-v12-consistent-directions'
sys.path.insert(0,str(REPO/'assets/outfits/rookwarden/tools'))
from export_editable import write_ase,write_ora,recolor
if OUT.exists():raise SystemExit('Preserve existing edits; select a new output version.')
dirs=['south','east','north','west'];labels=['Syd · uppåt','Öst · åt vänster','Nord · nedåt','Väst · åt höger'];channels={(255,255,0,255),(255,0,0,255),(0,255,0,255),(0,0,255,255)}
neutral_base=Image.open(ROOT/'editable-v11-neutral-helmet/base-neutral.png').convert('RGBA');old=Image.open(ROOT/'editable-v11-neutral-helmet/neutral-composite.png').convert('RGBA');old_mask=Image.open(ROOT/'editable-v11-neutral-helmet/composite-color-mask.png').convert('RGBA');body=neutral_base.copy();shell=Image.new('RGBA',(256,64));ornaments=shell.copy();masks=shell.copy();whole=shell.copy();qa={}
canonical=json.loads((SRC/'south/ornament-placement.json').read_text());canonical_points={(x-38,y-34):tuple(c)for x,y,*c in canonical['mapped_pixels']};inverse={'south':lambda x,y:(x,y),'east':lambda x,y:(-y,x),'north':lambda x,y:(-x,-y),'west':lambda x,y:(y,-x)}
for i,di in enumerate(dirs):
    folder=SRC/di;final=Image.open(folder/'neutral-helmet.png').convert('RGBA');native=Image.open(folder/'native-reference.png').convert('RGBA');native_mask=Image.open(folder/'native-mask.png').convert('RGBA');previous=old.crop((i*64,0,(i+1)*64,64));placement=json.loads((folder/'ornament-placement.json').read_text());mx,my=placement['mount'];mapped={(x,y):tuple(c)for x,y,*c in placement['mapped_pixels']};recover={inverse[di](x-mx,y-my):c for(x,y),c in mapped.items()};assert recover==canonical_points,('design changed',di)
    if di=='south':assert final.tobytes()==previous.tobytes(),'canonical south changed'
    fixed=legs=colored=removed=0
    for y in range(64):
        for x in range(64):
            q=x,y;pos=i*64+x,y;v=final.getpixel(q);n=native.getpixel(q);m=native_mask.getpixel(q);b=body.getpixel(pos)
            # Rebuild a genuinely neutral base layer from the verified PixelLab
            # result where an old layer had restored a colored native hair shadow.
            if b[3] and m in channels and not(b[0]==b[1]==b[2]):
                assert v[3]and v[0]==v[1]==v[2]
                body.putpixel(pos,v);b=v
            fixed+=n[3]>0 and m not in channels and v!=previous.getpixel(q)
            legs+=n[3]>0 and m in[(0,255,0,255),(0,0,255,255)]and v!=previous.getpixel(q)
            removed+=n[3]>0 and not v[3]
            colored+=v[3]>0 and(m in channels or q in mapped)and not(v[0]==v[1]==v[2])
            if v[3]and m in channels:masks.putpixel(pos,m)
            if di=='south':
                masks.putpixel(pos,old_mask.getpixel(pos))
                if v!=b:
                    if q in mapped:ornaments.putpixel(pos,v)
                    else:shell.putpixel(pos,v)
            else:
                allowed=q in mapped and(not n[3] or m in[(255,255,0,255),(255,0,0,255)])
                if allowed and v==mapped[q]:ornaments.putpixel(pos,v);masks.putpixel(pos,(255,255,0,255))
                elif v!=b:shell.putpixel(pos,v)
    assert fixed==legs==colored==removed==0,(di,fixed,legs,colored,removed)
    qa[di]={'canonical_ornament_inverse_transform_exact':True,'source_pixel_count':len(canonical_points),'fixed_source_pixels_changed':fixed,'leg_foot_pixels_changed':legs,'colored_recolorable_pixels':colored,'native_coverage_removed':removed,'canonical_south_unchanged':True if di=='south'else None,'mount':placement['mount'],'design_axis':placement['rearward_design_axis']}
    whole.alpha_composite(final,(i*64,0))
composed=body.copy();composed.alpha_composite(shell);composed.alpha_composite(ornaments);assert composed.tobytes()==whole.tobytes(),'layer composition drift'
assert recolor(whole,masks,(0,0,0,0)).tobytes()==whole.tobytes()
OUT.mkdir()
for name,im in [('base-neutral',body),('helmet-shell',shell),('helmet-ornament',ornaments),('neutral-composite',whole),('color-mask',masks)]:im.save(OUT/f'{name}.png')
layers=[('NEUTRAL_BODY - native poses',body,True,True),('HELMET_SHELL - fitted per native head',shell,True,True),('SAME_ORNAMENT - south canonical direction mapping',ornaments,True,True),('COLOR_MASK - separate hidden',masks,False,True)]
write_ase(OUT/'rune-sentinel-consistent-helmet.aseprite',layers);write_ora(OUT/'rune-sentinel-consistent-helmet.ora',layers,whole,'Rune Sentinel consistent neutral helmet direction study')
preview=Image.new('RGB',(880,390),(43,43,43));d=ImageDraw.Draw(preview);font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',16);small=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',12)
for i,label in enumerate(labels):
    im=whole.crop((i*64,0,(i+1)*64,64));zoom=im.crop((20,20,64,64)).resize((198,198),Image.Resampling.NEAREST);preview.paste(zoom,(i*220+10,45),zoom);d.text((i*220+8,8),label,font=font,fill='white');d.text((i*220+8,293),'1× native',font=small,fill=(190,190,190));preview.paste(im,(i*220+110,290),im)
preview.save(OUT/'consistent-helmet-directions.png')
(OUT/'validation.json').write_text(json.dumps({'stage':'Explicit design-consistency direction study; user review required, not finished shop art','directions':qa,'white_palette_exact':True,'ase_ora_readback':'PASS: exact cels and PNG layers','design_contract':'../source/v12-consistent-directions/direction-contract.json','scope_note':'Exact ornament transform establishes consistent source shape and the user-defined directions. It does not establish final perspective, occlusion, attachment or lighting quality; those still require visual user review. Do not apply this design-specific mapping to all helmet types.','files':{p.name:hashlib.sha256(p.read_bytes()).hexdigest()for p in OUT.iterdir()if p.is_file()}},indent=2)+'\n')
print(json.dumps(qa))
