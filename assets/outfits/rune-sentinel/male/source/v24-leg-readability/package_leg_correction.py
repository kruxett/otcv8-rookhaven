"""Package the AI leg correction; keep v23 and all actual addon pixels intact."""
from pathlib import Path
import importlib.util, json, hashlib, shutil, struct, sys
from PIL import Image, ImageDraw
P=Path(__file__).resolve().parent
MALE=P.parents[1]
REPO=MALE.parents[3]
OLD=MALE/'editable-v23-ai-native-layers'
OUT=MALE/'editable-v24-leg-readability'
spec=importlib.util.spec_from_file_location('prior_package',MALE/'source/v23-native-rich-raw/native-ai-layers/package_native_ai_layers.py')
H=importlib.util.module_from_spec(spec);spec.loader.exec_module(H)
E=H.E
def main():
    assert not OUT.exists(), 'Never overwrite a user-editable version.'
    oldqa=json.loads((OLD/'verification.json').read_text())
    for name,checksum in oldqa['source_file_sha256'].items():assert H.sha(OLD/name)==checksum, 'Existing editable source changed: '+name
    before=Image.open(P/'base-before-legs.png').convert('RGBA')
    current=Image.open(P/'base-leg-correction-composited.png').convert('RGBA')
    raw=Image.open(P/'legs-pixellab-opaque-original.png').convert('RGBA')
    domain=Image.open(P/'legs-only-mask.png').convert('L')
    assert current.getchannel('A').tobytes()==before.getchannel('A').tobytes()
    for a,b,r,m in zip(before.get_flattened_data(),current.get_flattened_data(),raw.get_flattened_data(),domain.get_flattened_data()):
        assert b==(r if m else a)
    arts=[current.crop((0,0,120,160))]+[Image.open(OLD/'layers'/f'art-{i}-all12.png').convert('RGBA') for i in (1,2)]
    masks=[Image.open(OLD/'layers'/f'working-mask-{i}-all12.png').convert('RGBA') for i in range(3)]
    protected=Image.open(H.P/'protected-native-all12.png').convert('RGBA').crop((0,0,120,160))
    crown=Image.open(H.P/'addon1-explicit-domain-all12.png').convert('L')
    combos={}
    for bits in range(4):
        art=arts[0].copy();mask=masks[0].copy()
        for i in (1,2):
            if bits&(1<<(i-1)):art=Image.alpha_composite(art,arts[i]);mask=Image.alpha_composite(mask,masks[i])
        combos[bits]=(art,mask)
        assert E.recolor(art,mask,(0,0,0,0)).tobytes()==art.tobytes()
        for pixel,fixed in zip(art.get_flattened_data(),protected.get_flattened_data()):
            if fixed[3]:assert pixel==fixed
        for d in range(4):assert art.crop((0,d*40+25,120,d*40+40)).tobytes()==arts[0].crop((0,d*40+25,120,d*40+40)).tobytes()
        for channel in range(4):
            indices=[0]*4;indices[channel]=114;tinted=E.recolor(art,mask,indices)
            for a,b,c in zip(art.get_flattened_data(),tinted.get_flattened_data(),mask.get_flattened_data()):
                assert a[3]==b[3]
                if c!=H.C[channel]:assert a==b
    for a,b,m in zip(combos[1][0].get_flattened_data(),combos[3][0].get_flattened_data(),crown.get_flattened_data()):
        if m:assert a==b
    OUT.mkdir();(OUT/'layers').mkdir()
    layers=[]
    for i,(a,m) in enumerate(zip(arts,masks)):
        a.save(OUT/'layers'/f'art-{i}-all12.png');H.native(a).save(OUT/'layers'/f'art-{i}-native64.png')
        shutil.copyfile(OLD/'layers'/f'working-mask-{i}-all12.png',OUT/'layers'/f'working-mask-{i}-all12.png')
        shutil.copyfile(OLD/'layers'/f'working-mask-{i}-native64.png',OUT/'layers'/f'working-mask-{i}-native64.png')
        if i:assert (OUT/'layers'/f'art-{i}-all12.png').read_bytes()==(OLD/'layers'/f'art-{i}-all12.png').read_bytes()
        layers.append((['BASE - AI leg repair, other art frozen','ADDON 1 - unchanged actual AI layer','ADDON 2 - unchanged actual AI layer'][i],H.native(a),True,True))
    layers += [(f'WORKING MASK {i} - hidden, review before import',H.native(m),False,True) for i,m in enumerate(masks)]
    layers.append(('NATIVE ANATOMY REFERENCE - hidden',H.native(Image.open(H.P/'native-original-all12.png').convert('RGBA')),False,False))
    E.write_ase(OUT/'rune-sentinel-leg-correction.aseprite',layers)
    E.write_ora(OUT/'rune-sentinel-leg-correction.ora',layers,H.native(combos[3][0]),'Rune Sentinel leg readability - review draft')
    for bits,(a,m) in combos.items():a.save(OUT/f'outfit-bits-{bits}.png');m.save(OUT/f'working-mask-bits-{bits}.png')
    for name in ['base-before-legs.png','legs-pixellab-opaque-original.png','legs-only-mask.png','base-leg-correction-composited.png','east-native-leg-reference-before-after.png','base-all12-native-leg-review.png']:shutil.copyfile(P/name,OUT/name)
    shutil.copyfile(OLD/'addons-pixellab-original.png',OUT/'addons-pixellab-original.png')
    board=Image.new('RGB',(660,800),'#24272b');draw=ImageDraw.Draw(board)
    full=Image.new('RGB',(840,1010),'#24272b');fd=ImageDraw.Draw(full)
    for tier,(bits,label) in enumerate([(0,'Bas'),(1,'Bas + addon 1'),(3,'Bas + båda')]):
        for d,heading in enumerate(H.LABELS):
            for f,step in enumerate(['Stå','Gång A','Gång B']):
                cell=combos[bits][0].crop((f*40,d*40,f*40+40,d*40+40))
                if f==0:
                    draw.text((tier*220+6,d*200+5),f'{heading} · {label}',font=H.F,fill='white')
                    zoom=cell.resize((160,160),Image.Resampling.NEAREST);board.paste(zoom,(tier*220+12,d*200+29),zoom);board.paste(cell,(tier*220+176,d*200+155),cell)
                x=d%2*420+f*140;y=tier*334+d//2*150+26
                fd.text((x+4,y),f'{heading} · {step}',font=H.F,fill='white');zoom=cell.resize((120,120),Image.Resampling.NEAREST);full.paste(zoom,(x+8,y+23),zoom)
        fd.text((8,tier*334+3),label,font=H.F,fill='white')
    board.save(OUT/'overview-all-directions.png');full.save(OUT/'all36-frames-review.png')
    frames=[]
    for f in [1,2]:
        board=Image.new('RGB',(640,540),'#24272b');draw=ImageDraw.Draw(board)
        for tier,(bits,label) in enumerate([(0,'Bas'),(1,'Bas + addon 1'),(3,'Bas + båda')]):
            for d,heading in enumerate(H.LABELS):
                cell=combos[bits][0].crop((f*40,d*40,f*40+40,d*40+40));draw.text((d*160+4,tier*180+4),f'{label} · {heading}',font=H.F,fill='white')
                zoom=cell.resize((120,120),Image.Resampling.NEAREST);board.paste(zoom,(d*160+20,tier*180+30),zoom)
        frames.append(board)
    frames[0].save(OUT/'walking-all-angles.gif',save_all=True,append_images=frames[1:],duration=220,loop=0,disposal=2)
    sys.path.insert(0,str(REPO/'tools'));from item_assets import encode_sprite,sprite_image
    count=0
    for im in [*[H.native(a) for a in arts],*[H.native(m) for m in masks]]:
        for y in range(0,256,32):
            for x in range(0,192,32):
                tile=im.crop((x,y,x+32,y+32));data=b'TEST'+struct.pack('<HI',1,10)+encode_sprite(tile)
                assert sprite_image(data,1).tobytes()==tile.tobytes();count+=1
    ref=json.loads((H.P.parent/'reference-manifest.json').read_text())
    for filename,key in [('Tibia.dat','dat_sha256'),('Tibia.spr','spr_sha256')]:assert H.sha(REPO/'data/things/860'/filename)==ref[key]
    qa={'status':'Leg correction candidate; graphic approval pending; no game import',
        'scope':'Base leg shading only in all12 poses; existing addons and masks unchanged.',
        'all12_pose_alpha_exact_to_v23':True,'unselected_RGBA_exact_to_v23':True,'selected_RGBA_exact_to_raw_PixelLab_output':True,
        'manual_painted_pixels':0,'postprocessing':'Predeclared binary inpaint-mask composition to retain original unselected RGBA; complete native-frame packing and standard addon alpha composition. No repainting, recoloring or inferred addon extraction.',
        'all_original_face_hand_contour_RGBA_preserved':True,'all4_addon_combinations_checked':True,
        'base_legs_identical_across_all4_combinations':True,'addon1_crest_identical_with_or_without_addon2':True,
        'addon_art_and_working_mask_PNGs_byte_exact_to_v23':True,'four_tint_channels_independent':True,
        'ASE_ORA_readback_passed':True,'lossless_SPR_860_tiles':count,'DAT_SPR_unchanged':True,
        'jobs_this_turn':['6746f5b0-8aa2-4cb2-8429-6f6d7acb9d28','ad49f0a0-bbcb-460e-98f1-243d1d017340'],
        'generations_this_turn':16,'limitations':['Visual approval pending. Native side poses retain natural leg overlap.','Working color masks still require final visual approval.','No client/server integration or in-game rendering verification.']}
    qa['source_file_sha256']={n:H.sha(OUT/n) for n in ['base-leg-correction-composited.png','legs-pixellab-opaque-original.png','addons-pixellab-original.png','rune-sentinel-leg-correction.aseprite','rune-sentinel-leg-correction.ora']}
    H.js(OUT/'verification.json',qa)
    (OUT/'README.md').write_text('Rune Sentinel – begränsad AI-korrigering av benens läsbarhet\n\nGrafiskt förslag, inte användargodkänt eller importerat.\n\nPixelLab målade ben i samtliga 12 originalposer. Originalets faktiska benteckning användes som inmatningsunderlag inom den fördefinierade målningsmasken. Övrig grafik, poser, fotpositioner, addonlager och arbetsmasker är oförändrade.\n\nOriginalets sidoposer överlappar benen. Bedöm deras interna konturer och skuggning visuellt; identiska ytterkonturer bevisar inte god läsbarhet.\n\nPro-exporten var opak. Endast dess pixlar inom den uttryckliga ursprungliga målningsmasken kompositerades in. Samtliga dessa RGBA-värden är exakt AI-utdata och samtliga omarkerade RGBA-värden är exakt föregående bas. Ingen egen pixelmålning, färgkonvertering eller gissad addonuppdelning. Omodifierad råexport och mask finns här.\n\nASE/ORA: tre synliga redigerbara grafikskikt, tre dolda arbetsmasker, en dold originalreferens. Rutor64×64 med oförändrade40×40-celler vid+24,+24. Rader N/E/S/W, kolumner stå/gångA/gångB. Äldre versioner är bevarade.\n\nTvå försök:6+10=16 PixelLab-genereringar. Det första bedömdes inte ge tillräcklig separation. verification.json redovisar genomförda kontroller.\n',encoding='utf-8')
    print(json.dumps({'output':str(OUT),'lossless_sprite_tiles':count,'all4_combinations_checked':True,'old_editable_source_preserved':True,'game_import':False}))
if __name__=='__main__':main()

