"""Pack actual PixelLab base/addon exports without recoloring or art masking."""
from pathlib import Path
import importlib.util,json,hashlib,struct,sys,shutil
from PIL import Image,ImageDraw,ImageFont,ImageFilter
P=Path(__file__).resolve().parent
MALE=P.parents[2];REPO=MALE.parents[3];OUT=MALE/'editable-v23-ai-native-layers'
spec=importlib.util.spec_from_file_location('export',REPO/'assets/outfits/rookwarden/tools/export_editable.py')
E=importlib.util.module_from_spec(spec);spec.loader.exec_module(E)
C=E.COLORS
F=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',14)
LABELS=['Norr','Öster','Söder','Väster']

def js(path,value):path.write_text(json.dumps(value,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def native(im):
    out=Image.new('RGBA',(192,256))
    for d in range(4):
        for f in range(3):out.paste(im.crop((f*40,d*40,f*40+40,d*40+40)),(f*64+24,d*64+24))
    return out

def main():
    assert not OUT.exists(),'Never overwrite a user-editable source.'
    base_original=Image.open(P/'base-all12-pixellab-original.png').convert('RGBA')
    assert base_original.size==(128,192) and base_original.getbbox()[2]<=120 and base_original.getbbox()[3]<=160
    base=base_original.crop((0,0,120,160))
    raw=Image.open(P/'addons-pixellab-new-layer-original.png').convert('RGBA')
    domain=Image.open(P/'addon-generation-domains.png').convert('RGB')
    assert raw.size==(240,240)
    assert all(not p[3] or m==(255,255,255) for p,m in zip(raw.get_flattened_data(),domain.get_flattened_data()))
    arts=[base,Image.new('RGBA',(120,160)),Image.new('RGBA',(120,160))]
    for d in range(4):
        for f in range(3):
            for tier in (1,2):
                x=d%2*120+f*40;y=tier*80+d//2*40
                cell=raw.crop((x,y,x+40,y+40));arts[tier].paste(cell,(f*40,d*40))
                assert arts[tier].crop((f*40,d*40,f*40+40,d*40+40)).tobytes()==cell.tobytes()
    # Metadata only. Preserve all actual AI art colors byte-for-byte.
    original_parts=Image.open(P/'native-part-mask-all12.png').convert('RGBA').crop((0,0,120,160))
    protected=Image.open(P/'protected-native-all12.png').convert('RGBA').crop((0,0,120,160))
    masks=[Image.new('RGBA',(120,160)) for _ in range(3)]
    fallback=0
    for d in range(4):
        for f in range(3):
            possible=[(x,y,original_parts.getpixel((f*40+x,d*40+y))) for y in range(40) for x in range(40)
                if original_parts.getpixel((f*40+x,d*40+y)) in C]
            for y in range(40):
                for x in range(40):
                    xy=(f*40+x,d*40+y);p=base.getpixel(xy);m=original_parts.getpixel(xy)
                    if p[3]:
                        if m in C:masks[0].putpixel(xy,m)
                        elif not protected.getpixel(xy)[3]:
                            label=min(possible,key=lambda q:((q[0]-x)**2+(q[1]-y)**2,q[1],q[0]))[2]
                            masks[0].putpixel(xy,label);fallback+=1
                    for layer,color in [(1,C[0]),(2,C[1])]:
                        if arts[layer].getpixel(xy)[3]:masks[layer].putpixel(xy,color)
    combos={}
    for bits in range(4):
        art=arts[0].copy();mask=masks[0].copy()
        for layer in (1,2):
            if bits&(1<<(layer-1)):
                art=Image.alpha_composite(art,arts[layer]);mask=Image.alpha_composite(mask,masks[layer])
        combos[bits]=(art,mask)
        assert E.recolor(art,mask,(0,0,0,0)).tobytes()==art.tobytes()
        for p,fixed in zip(art.get_flattened_data(),protected.get_flattened_data()):
            if fixed[3]:assert p==fixed
        for d in range(4):
            assert art.crop((0,d*40+25,120,d*40+40)).tobytes()==base.crop((0,d*40+25,120,d*40+40)).tobytes()
        for channel in range(4):
            indices=[0,0,0,0];indices[channel]=114;tinted=E.recolor(art,mask,indices)
            for p,q,c in zip(art.get_flattened_data(),tinted.get_flattened_data(),mask.get_flattened_data()):
                assert p[3]==q[3]
                if c!=C[channel]:assert p==q
    crown=Image.open(P/'addon1-explicit-domain-all12.png').convert('L')
    for p,q,c in zip(combos[1][0].get_flattened_data(),combos[3][0].get_flattened_data(),crown.get_flattened_data()):
        if c:assert p==q
    OUT.mkdir();(OUT/'layers').mkdir()
    for i,(a,m) in enumerate(zip(arts,masks)):
        a.save(OUT/'layers'/f'art-{i}-all12.png');m.save(OUT/'layers'/f'working-mask-{i}-all12.png')
        native(a).save(OUT/'layers'/f'art-{i}-native64.png');native(m).save(OUT/'layers'/f'working-mask-{i}-native64.png')
    layers=[('BASE - actual PixelLab base',native(arts[0]),True,True),
        ('ADDON 1 - actual PixelLab new-layer export',native(arts[1]),True,True),
        ('ADDON 2 - actual PixelLab new-layer export',native(arts[2]),True,True)]
    for i,m in enumerate(masks):layers.append((f'WORKING MASK {i} - hidden, review before import',native(m),False,True))
    layers.append(('NATIVE ANATOMY REFERENCE - hidden',native(Image.open(P/'native-original-all12.png').convert('RGBA')),False,False))
    E.write_ase(OUT/'rune-sentinel-ai-native-layers.aseprite',layers)
    E.write_ora(OUT/'rune-sentinel-ai-native-layers.ora',layers,native(combos[3][0]),'Rune Sentinel native AI layers - review draft')
    shutil.copyfile(P/'base-all12-pixellab-original.png',OUT/'base-pixellab-original.png')
    shutil.copyfile(P/'addons-pixellab-new-layer-original.png',OUT/'addons-pixellab-original.png')
    for bits,(a,m) in combos.items():a.save(OUT/f'outfit-bits-{bits}.png');m.save(OUT/f'working-mask-bits-{bits}.png')
    board=Image.new('RGB',(660,800),'#24272b');draw=ImageDraw.Draw(board)
    full=Image.new('RGB',(840,1010),'#24272b');fd=ImageDraw.Draw(full)
    for tier,(bits,label) in enumerate([(0,'Bas'),(1,'Bas + addon 1'),(3,'Bas + båda')]):
        art=combos[bits][0];fd.text((8,tier*334+3),label,font=F,fill='white')
        for d,heading in enumerate(LABELS):
            for f,step in enumerate(['Stå','Gång A','Gång B']):
                cell=art.crop((f*40,d*40,f*40+40,d*40+40))
                if f==0:
                    draw.text((tier*220+6,d*200+5),f'{heading} · {label}',font=F,fill='white');zoom=cell.resize((160,160),Image.Resampling.NEAREST);board.paste(zoom,(tier*220+12,d*200+29),zoom)
                    board.paste(cell,(tier*220+176,d*200+155),cell)
                x=d%2*420+f*140;y=tier*334+d//2*150+26;fd.text((x+4,y),f'{heading} · {step}',font=F,fill='white');zoom=cell.resize((120,120),Image.Resampling.NEAREST);full.paste(zoom,(x+8,y+23),zoom)
    board.save(OUT/'overview-all-directions.png');full.save(OUT/'all36-frames-review.png')
    frames=[]
    for f in [1,2]:
        board=Image.new('RGB',(640,540),'#24272b');draw=ImageDraw.Draw(board)
        for tier,(bits,label) in enumerate([(0,'Bas'),(1,'Bas + addon 1'),(3,'Bas + båda')]):
            art=combos[bits][0]
            for d,heading in enumerate(LABELS):
                cell=art.crop((f*40,d*40,f*40+40,d*40+40));draw.text((d*160+4,tier*180+4),f'{label} · {heading}',font=F,fill='white');zoom=cell.resize((120,120),Image.Resampling.NEAREST);board.paste(zoom,(d*160+20,tier*180+30),zoom)
        frames.append(board)
    frames[0].save(OUT/'walking-all-angles.gif',save_all=True,append_images=frames[1:],duration=220,loop=0,disposal=2)
    sys.path.insert(0,str(REPO/'tools'));from item_assets import encode_sprite,sprite_image
    count=0
    for im in [*[native(a) for a in arts],*[native(m) for m in masks]]:
        for y in range(0,256,32):
            for x in range(0,192,32):
                tile=im.crop((x,y,x+32,y+32));data=b'TEST'+struct.pack('<HI',1,10)+encode_sprite(tile)
                assert sprite_image(data,1).tobytes()==tile.tobytes();count+=1
    original=Image.open(P/'native-original-all12.png').convert('RGBA').crop((0,0,120,160))
    assert all(not old[3] or p[3] for p,old in zip(base.get_flattened_data(),original.get_flattened_data()))
    qa={'status':'Native AI layer proposal, user graphic approval pending, not imported',
        'pixel_art_drawing':'PixelLab AI only','art_postprocessing':'Known complete-frame rectangle packing and standard alpha compositing only; no recoloring, repainting or guessed part extraction.',
        'native_face_hand_and_contour_RGBA_preserved_all4_combinations':True,
        'all_original_native_body_pixels_covered':True,'base_legs_identical_all4_combinations':True,
        'helmet_crest_identical_with_or_without_addon2':True,'AI_addon_alpha_outside_requested_domains':0,
        'all3_art_layers_byte_exact_to_PixelLab_source_cells':True,'ASE_ORA_readback_passed':True,
        'four_tint_channels_independent':True,'sprite_860_lossless_tiles':count,
        'working_base_mask_nearest_label_pixels':fallback,'addon_mask_labels':'entire addon1 yellow, entire addon2 red, source alpha retained',
        'final_layer_workflow_jobs':['36246344-9f1a-4a4c-8de4-62a05b7a07d1','8a1d3e74-e3d5-4f72-969d-2b278214362b'],
        'all_jobs_this_user_turn':['139a9a9b-972d-4381-8c20-bf43f632893b','d521d620-4cbb-49da-8c9d-30779d501d55','5689b301-2a4a-4dbf-a104-02d8e8c75f29','36246344-9f1a-4a4c-8de4-62a05b7a07d1','8a1d3e74-e3d5-4f72-969d-2b278214362b'],
        'generations_this_user_turn':43,'limitations':['User must review visual design and working mask boundaries.','No new outfit ID, DAT/SPR import, shop access, female counterpart or in-game rendering test.']}
    ref=json.loads((P.parent/'reference-manifest.json').read_text())
    for filename,key in [('Tibia.dat','dat_sha256'),('Tibia.spr','spr_sha256')]:assert sha(REPO/'data/things/860'/filename)==ref[key]
    qa['DAT_SPR_unchanged']=True
    qa['source_file_sha256']={name:sha(OUT/name) for name in ['base-pixellab-original.png','addons-pixellab-original.png','rune-sentinel-ai-native-layers.aseprite','rune-sentinel-ai-native-layers.ora']}
    js(OUT/'verification.json',qa)
    (OUT/'README.md').write_text('''# Rune Sentinel – nya native-lager målade av PixelLab

Grafiskt förslag. Inget är importerat eller användargodkänt.

Den AI-målade basen finns en gång per originalpose. PixelLab målade båda addons
för alla tolv poser gemensamt över synliga basfigurer och exporterade direkt
"New layer with changes". Utrustningen kommer alltså från riktiga transparenta
AI-lager, inte efterhandsklippning av sammanslagna figurer.

Förberedda anatomiska målningsområden låser ansikte/händer/kroppskonturer,
huvudets bakåtriktning och axlarnas placering. Addon2 kan inte rita om huvud,
addon1 eller ben. Hjälmfjädrarnas riktning är styrd genom målningsområden och
ett bilddiagram, inte en efterhandsflytt av pixlar. Originalets gångposer och
fotankare återanvänds. Alla fyra addon-kombinationer kompositeras på samma bas.

Färger och skuggor är oförändrade från PixelLabs slutliga lagerutdata.
Ingen neutralgråkonvertering, egen pixelmålning eller gissad delmask har
applicerats på grafiken efter generering. Endast kända hela bildrutor packas
om utan omskalning. De orörda exporterade PNG-filerna finns i denna mapp.

ASE/ORA innehåller tre synliga redigerbara native64-lager (bas, addon1,
addon2), dolda arbetsmasker och originalets anatomireferens. Varje ruta är
64×64; AI:s 40×40-rutor placeras vid +24,+24 utan omskalning. Rader N/E/S/W,
kolumner stå/gång A/gång B. Slå av/på addonlagren för kombinationerna 0/1/2/3.

Arbetsmaskernas gränser och runstenens färgkanal behöver visuell granskning
före import; de är inte en färdig godkänd färgsättning. Native gameplay,
female-variant och shopregistrering återstår efter godkänd grafisk design.

verification.json redovisar faktiska kontroller och samtliga genereringsjobb.
43 genereringar användes i denna användartur, inklusive tre tidigare försök
före den slutliga separata lagergenereringen.
''',encoding='utf-8')
    mpath=MALE/'design-manifest.json';m=json.loads(mpath.read_text(encoding='utf-8'));js(P/'manifest-before-native-ai-layers.json',m)
    if not any(x['version']=='v22-native-layers' for x in m['rejected_proposals']):m['rejected_proposals'].append({'version':'v22-native-layers','reason':'User: substantially worse; confirmed over-simplified design and destructive inferred addon extraction/gray conversion. New attempt must preserve actual reference anatomy and stronger original design.'})
    m.update({'status':'New AI-native base/addon layer proposal; no post-generation artwork edits; graphic approval pending.',
        'iteration':'v23 actual PixelLab native layers after all-view native reference generation',
        'source':'source/v23-native-rich-raw/native-ai-layers','preview':'editable-v23-ai-native-layers/overview-all-directions.png',
        'all_frames_preview':'editable-v23-ai-native-layers/all36-frames-review.png','walking_preview':'editable-v23-ai-native-layers/walking-all-angles.gif',
        'editable':'editable-v23-ai-native-layers/rune-sentinel-ai-native-layers.aseprite','editable_alternative':'editable-v23-ai-native-layers/rune-sentinel-ai-native-layers.ora',
        'validation':'editable-v23-ai-native-layers/verification.json','base_style_approved':False,'addon1_style_approved':False,'addon2_style_approved':False,
        'latest_feedback':'User: start over correctly with clear instructions and every important reference invariant retained.',
        'pixel_art_generator':'PixelLab Pro Flash + targeted Pro correction; final addons exported as real new transparent layers',
        'next_workflow':'User graphic review of base and real independent AI addon layers. Do not alter the presented art after review without explicit scope. Final mask boundaries, female and game integration follow approval.',
        'remaining':['User graphic approval of base/addons and final mask boundary work','Female counterpart','Approved native import/shop unlocks and in-game verification']})
    for job in qa['all_jobs_this_user_turn']:
        if job not in m.setdefault('artwork_generator_jobs',[]):m['artwork_generator_jobs'].append(job)
    js(mpath,m)
    print(json.dumps({'output':str(OUT),'real_AI_addon_layers':2,'all4_native_combinations_checked':True,'native_anatomy_exact':True,'unchanged_legs_and_helmet_checked':True,'lossless_spr_tiles':count,'post_generation_art_pixel_changes':0,'new_import':False}))

if __name__=='__main__':main()
