"""Package full AI outfit states and mask without hand-painted sprite changes."""
from pathlib import Path
from collections import Counter
import json,hashlib,importlib.util,shutil,sys,struct
from PIL import Image,ImageDraw,ImageFont,ImageFilter

P=Path(__file__).resolve().parent
MALE=P.parents[2]
REPO=MALE.parents[3]
OUT=MALE/'editable-v20-complete-outfit'
sys.path.insert(0,str(P.parent.parent))
from prepare_v20_full_outfit import tile_pos
spec=importlib.util.spec_from_file_location('editable',REPO/'assets/outfits/rookwarden/tools/export_editable.py')
export=importlib.util.module_from_spec(spec);spec.loader.exec_module(export)
COLORS=export.COLORS
DIRS=['north','east','south','west']
LABELS=['Norr','Öster','Söder','Väster']
TIERS=['Bas','Bas + addon 1','Bas + båda']
FONT=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',17)
SMALL=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',13)

def read(name):return Image.open(P/name).convert('RGBA')
def js(path,value):path.write_text(json.dumps(value,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def state(sheet,tier):
    im=Image.new('RGBA',(120,160))
    for d in range(4):
        for phase in range(3):
            x,y=tile_pos(tier,d,phase)
            im.paste(sheet.crop((x,y,x+40,y+40)),(phase*40,d*40))
    return im

def native64(sheet):
    im=Image.new('RGBA',(192,256))
    for d in range(4):
        for phase in range(3):
            im.paste(sheet.crop((phase*40,d*40,(phase+1)*40,(d+1)*40)),(phase*64+24,d*64+24))
    return im

def idle_board(sheet):
    c=Image.new('RGB',(660,800),'#24272b');draw=ImageDraw.Draw(c)
    for tier,label in enumerate(TIERS):
        for d,heading in enumerate(LABELS):
            x,y=tile_pos(tier,d,0);cell=sheet.crop((x,y,x+40,y+40))
            draw.text((tier*220+8,d*200+4),f'{heading} · {label}',font=FONT,fill='white')
            zoom=cell.resize((160,160),Image.Resampling.NEAREST)
            c.paste(zoom,(tier*220+16,d*200+30),zoom)
            c.paste(cell,(tier*220+175,d*200+150),cell)
    return c

def all_frames_board(sheet):
    c=Image.new('RGB',(840,1040),'#24272b');draw=ImageDraw.Draw(c)
    for tier,label in enumerate(TIERS):
        draw.text((8,tier*340+5),label,font=FONT,fill='white')
        for d,heading in enumerate(LABELS):
            for phase,step in enumerate(['Stå','Gång A','Gång B']):
                x,y=tile_pos(tier,d,phase);cell=sheet.crop((x,y,x+40,y+40))
                bx=(d%2)*420+phase*140;by=tier*340+(d//2)*150+35
                draw.text((bx+5,by),f'{heading} · {step}',font=SMALL,fill='white')
                zoom=cell.resize((120,120),Image.Resampling.NEAREST)
                c.paste(zoom,(bx+8,by+23),zoom)
    return c

def main():
    assert not OUT.exists(),'Never overwrite a potentially user-edited source.'
    art=read('base-and-addons-neutral-all36.png');raw=read('pixellab-ai-original.png')
    ai_mask=read('pixellab-color-layer-original.png')
    fixed=Image.open(P.parent/'composed-ai/fixed-native-skin-all36.png').convert('RGBA')
    generation_mask=Image.open(P.parent/'composed-ai/generation-mask.png').convert('RGB')
    target=read('target-three-complete-states.png')
    native_mask=Image.open(P.parent/'citizen-all12-mask.png').convert('RGBA')
    assert art.size==raw.size==ai_mask.size==fixed.size==(240,240)
    protected=0;hue=0;lost=0;gained=0
    mask=Image.new('RGBA',art.size);uncertain=[];snapped=0;ai_mask_alpha_mismatches=0
    native_mask_fallback=0;nearest_label_fallback=0
    for y in range(240):
        for x in range(240):
            p=art.getpixel((x,y));original=raw.getpixel((x,y));native=fixed.getpixel((x,y))
            assert p[3]==original[3] and p[3] in (0,255)
            if native[3]:
                assert p==original==native;protected+=1
            elif p[3]:
                value=round(.2126*original[0]+.7152*original[1]+.0722*original[2])
                assert p==(value,value,value,original[3]);hue+=p!=original
                predicted=ai_mask.getpixel((x,y));ai_mask_alpha_mismatches+=predicted[3]!=p[3]
                maximum=max(predicted[:3]);chroma=maximum-min(predicted[:3])
                normalized=[round(v*255/maximum) for v in predicted[:3]] if maximum else [0,0,0]
                distances=[sum((normalized[i]-c[i])**2 for i in range(3)) for c in COLORS]
                index=min(range(4),key=distances.__getitem__)
                if predicted[3] and maximum>=24 and chroma>=12 and chroma/maximum>=.5:
                    mask.putpixel((x,y),COLORS[index]);snapped+=predicted!=COLORS[index]
                else:uncertain.append([x,y,list(predicted)])
            if generation_mask.getpixel((x,y))==(0,0,0):assert original==target.getpixel((x,y))
            lost+=target.getpixel((x,y))[3]>p[3]
            gained+=target.getpixel((x,y))[3]<p[3]
    assert hue==1635
    initially_uncertain=list(uncertain)
    # Mask metadata only: recover missing AI class labels from original native
    # body channels, then nearest labeled costume pixel within the SAME cell.
    # Artwork/alpha remain byte-identical; no costume pixels are painted here.
    pending=[]
    for x,y,predicted in uncertain:
        local_x=x%40;local_y=y%40
        direction=(y%80//40)*2+x//120
        phase=x%120//40
        label=native_mask.getpixel((phase*40+local_x,direction*40+local_y))
        if label in COLORS:
            mask.putpixel((x,y),label);native_mask_fallback+=1
        else:pending.append([x,y,predicted])
    uncertain=[]
    for x,y,predicted in pending:
        bx=x//40*40;by=y//40*40
        labels=[(xx,yy,mask.getpixel((xx,yy))) for yy in range(by,by+40) for xx in range(bx,bx+40)
                if mask.getpixel((xx,yy)) in COLORS]
        if labels:
            xx,yy,label=min(labels,key=lambda t:((t[0]-x)**2+(t[1]-y)**2,t[1],t[0]))
            mask.putpixel((x,y),label);nearest_label_fallback+=1
        else:uncertain.append([x,y,predicted])
    # Expose model limitations instead of presenting composite states as ready-made addons.
    tier_diffs=[]
    for d in range(4):
        for phase in range(3):
            xs=[tile_pos(t,d,phase) for t in range(3)]
            cells=[art.crop((x,y,x+40,y+40)) for x,y in xs]
            tier_diffs.append({'direction':DIRS[d],'phase':phase,
                'base_to_addon1_changed_pixels':sum(a!=b for a,b in zip(cells[0].get_flattened_data(),cells[1].get_flattened_data())),
                'addon1_to_both_changed_pixels':sum(a!=b for a,b in zip(cells[1].get_flattened_data(),cells[2].get_flattened_data()))})
    layers=[('PREVIOUS ARMOR EDIT TARGET - hidden',target,False,False),
            ('PIXELLAB ORIGINAL - before neutral encoding',raw,False,False)]
    for tier,name in enumerate(TIERS):
        layer=Image.new('RGBA',art.size);layer.paste(art.crop((0,tier*80,240,(tier+1)*80)),(0,tier*80))
        layers.append((f'{name} - 12 complete worn-state frames',layer,True,True))
    layers.append(('WORKING COLOR MASK - hidden; review boundaries',mask,False,True))
    merged=Image.new('RGBA',art.size)
    for _,im,visible,_ in layers:
        if visible:merged=Image.alpha_composite(merged,im)
    assert merged.tobytes()==art.tobytes()
    assert export.recolor(art,mask,(0,0,0,0)).tobytes()==art.tobytes()
    for channel in range(4):
        indices=[0,0,0,0];indices[channel]=114
        tinted=export.recolor(art,mask,indices)
        assert tinted.getchannel('A').tobytes()==art.getchannel('A').tobytes()
        for y in range(240):
            for x in range(240):
                if mask.getpixel((x,y))!=COLORS[channel]:assert tinted.getpixel((x,y))==art.getpixel((x,y))
    OUT.mkdir();(OUT/'states').mkdir()
    shutil.copyfile(P/'base-and-addons-neutral-all36.png',OUT/'base-and-addons-all36.png')
    shutil.copyfile(P/'pixellab-ai-original.png',OUT/'pixellab-ai-original.png')
    shutil.copyfile(P/'pixellab-color-layer-original.png',OUT/'pixellab-color-layer-original.png')
    mask.save(OUT/'working-four-channel-mask.png')
    export.write_ase(OUT/'rune-sentinel-full-outfit.aseprite',layers)
    export.write_ora(OUT/'rune-sentinel-full-outfit.ora',layers,art,'Rune Sentinel v20 - complete AI outfit states')
    idle_board(art).save(OUT/'all-directions-three-states.png')
    all_frames_board(art).save(OUT/'all36-frames-review.png')
    combined=Image.new('RGB',(960,500),'#24272b');dr=ImageDraw.Draw(combined)
    for col,(label,im) in enumerate([('Neutral grafik',art),('Arbetsmask',mask)]):
        dr.text((col*480+10,4),label,font=FONT,fill='white');zoom=im.resize((480,480),Image.Resampling.NEAREST);combined.paste(zoom,(col*480,24),zoom)
    combined.save(OUT/'art-and-color-mask-review.png')
    anim=[]
    for phase in [1,2]:
        c=Image.new('RGB',(640,540),'#24272b');dr=ImageDraw.Draw(c)
        for tier,label in enumerate(TIERS):
            for d,heading in enumerate(LABELS):
                x,y=tile_pos(tier,d,phase);cell=art.crop((x,y,x+40,y+40))
                dr.text((d*160+5,tier*180+4),f'{label} · {heading}',font=SMALL,fill='white')
                zoom=cell.resize((120,120),Image.Resampling.NEAREST);c.paste(zoom,(d*160+20,tier*180+35),zoom)
        anim.append(c)
    anim[0].save(OUT/'walking-all-states.gif',save_all=True,append_images=anim[1:],duration=220,loop=0,disposal=2)
    palette_sets=[(0,0,0,0),(57,49,2,58),(57,56,21,58),(57,45,2,58)]
    palette_board=Image.new('RGB',(640,540),'#24272b');draw=ImageDraw.Draw(palette_board)
    for col,indices in enumerate(palette_sets):
        colored=export.recolor(art,mask,indices)
        for tier,label in enumerate(TIERS):
            x,y=tile_pos(tier,2,0);cell=colored.crop((x,y,x+40,y+40));zoom=cell.resize((120,120),Image.Resampling.NEAREST)
            draw.text((col*160+5,tier*180+4),label,font=SMALL,fill='white');palette_board.paste(zoom,(col*160+20,tier*180+35),zoom)
    palette_board.save(OUT/'player-color-preview.png')
    sys.path.insert(0,str(REPO/'tools'))
    from item_assets import encode_sprite,sprite_image
    tiles=0
    for tier in range(3):
        for kind,sheet in [('art',art),('mask',mask)]:
            extracted=state(sheet,tier);extracted.save(OUT/'states'/f'state-{tier}-{kind}-all12.png')
            native=native64(extracted);native.save(OUT/'states'/f'state-{tier}-{kind}-native64.png')
            for y in range(0,256,32):
                for x in range(0,192,32):
                    cell=native.crop((x,y,x+32,y+32));encoded=b'TEST'+struct.pack('<HI',1,10)+encode_sprite(cell)
                    assert sprite_image(encoded,1).tobytes()==cell.tobytes();tiles+=1
    reference=json.loads((P.parent/'reference-manifest.json').read_text(encoding='utf-8'))
    assert sha(REPO/'data/things/860/Tibia.dat')==reference['source_dat_sha256']
    assert sha(REPO/'data/things/860/Tibia.spr')==reference['source_spr_sha256']
    verification={'status':'review draft; known visual inconsistencies; NOT ready for import',
        'art_generator':'PixelLab inpaint_image_pro_flash','art_job_id':'e6f3fdd9-4c74-45db-90ac-bc1604c1817b',
        'mask_generator':'PixelLab inpaint_image_pro_flash','mask_job_id':'c90b85f1-ee63-4425-9d7b-bc2fa7310d55',
        'all36_art_frames_generated_together':True,'all36_mask_frames_generated_together':True,
        'manual_artistic_edits':0,'technical_neutral_encoding_pixels':hue,
        'neutral_encoding_preserves_art_alpha':True,'native_fixed_pixels_exact':protected,
        'AI_costume_opacity_losses_against_native':lost,'AI_costume_opacity_gains_against_native':gained,
        'visible_layer_merge_exact':True,'ase_cels_and_flags_roundtrip':True,'ora_layers_roundtrip':True,
        'four_independent_tint_channels_checked':True,'spr_860_lossless_tiles':tiles,
        'DAT_SPR_unchanged':True,'pure_mask_palette_snapped_pixels':snapped,
        'AI_mask_alpha_mismatches':ai_mask_alpha_mismatches,'initially_uncertain_AI_mask_pixels':initially_uncertain,
        'mask_native_channel_fallback_pixels':native_mask_fallback,
        'mask_same_frame_nearest_label_fallback_pixels':nearest_label_fallback,
        'unresolved_mask_pixels':uncertain,
        'tier_pixel_differences':tier_diffs,'mask_counts':{str(c):Counter(mask.get_flattened_data())[c] for c in COLORS},
        'limitations':['Helmet crest geometry and direction consistency still need visual review.',
            'AI changes underlying garment pixels across addon tiers; these are full worn-state studies, not final independent native addon layers.',
            'Costume alpha is not identical to native source; fixed native faces/hands remain exact.',
            'Working four-channel mask requires visual boundary review, including any unresolved pixels.',
            'No game import, shader screenshot, female counterpart, outfit ID or shop change.']}
    verification['sha256']={name:sha(OUT/name) for name in ['base-and-addons-all36.png','working-four-channel-mask.png','rune-sentinel-full-outfit.aseprite','rune-sentinel-full-outfit.ora']}
    js(OUT/'verification.json',verification)
    (OUT/'README.md').write_text('''# Rune Sentinel v20 – helt outfitutkast

PixelLab målade bas, bas + addon 1 samt bas + båda addons tillsammans i en och
samma generering, alla fyra riktningar och alla tre poser. Det är tre kompletta
bärlägen, inte färdiga fristående addonlager. AI varierar fortfarande vissa
grundkläder mellan stadierna och hjälmutsmyckningen behöver vidare granskning.
Grafiken är inte godkänd eller redo att importeras.

Referenserna innehåller kompletta originalark från DAT/SPR med bas, båda addons,
samtliga riktningar/gångbilder och färgmasker. Förberedda referenser: Warrior,
Demon Hunter, Wayfarer, Knight och Warmaster. Den sista genereringen använder
hela Knight och Warmaster inklusive deras färgmasker. Tidigare v19-rustning är
uttryckligen en ofärdig redigeringstarget för att behålla rustningskaraktären,
inte ett godkänt resultat.

AI-originalen är bevarade. Enda bearbetningen av outfitgrafiken efter AI är
automatisk Rec709-konvertering av kläder till neutralt grått i PixelLabs
workbench. Inga former eller detaljpixels har målats för hand. Originalets fasta
ansikten/händer är byte-identiska. AI har ändrat vissa klädkanter; full silhuett-
identitet hävdas därför inte. Numeriska kontroller ersätter inte visuell granskning.

PixelLab genererade även färglagret för hela arket gemensamt, men behöll skuggor
och vissa felaktiga hudfärger i masken. Arbetsmasken begränsas därför tekniskt
till grafikens opaka klädpixlar; färgade AI-prediktioner normaliseras till rent
gult/rött/grönt/blått. Där AI saknar tydlig etikett används originalets native
kroppskanal, därefter närmaste giltiga klädetikett inom samma bildruta för nya
addonkanter. Det är automatisk maskmetadata, inte ommålning av outfitgrafiken.
Antal kompletterade pixlar redovisas i verification.json. Maskgränserna behöver
visuell kontroll; klassificeringen är inte användargodkänd.

Öppna rune-sentinel-full-outfit.aseprite eller .ora. Bas och båda bärlägena har
egna redigerbara lager på olika rader; mask och originalreferenser är dolda.
Varje cell är 40×40 och visas utan omskalning i källarket. Rader 0–1 är bas,
2–3 bas + addon 1, 4–5 bas + båda. För varje par: N0 N1 N2 E0 E1 E2 på första
raden, S0 S1 S2 W0 W1 W2 på nästa. states/ innehåller motsvarande 12-bildsark
och native64-atlaser med samma +24,+24-placering utan omskalning.

Inga DAT/SPR-, server- eller shopfiler ändrades. Inget bygger på användargodkänd
grafik ännu. Fullt speltest och extraktion av oberoende addons återstår efter
designgranskning.
''',encoding='utf-8')
    manifest_path=MALE/'design-manifest.json'
    if not (P/'design-manifest-before-packaging.json').exists():
        shutil.copyfile(manifest_path,P/'design-manifest-before-packaging.json')
    manifest=json.loads(manifest_path.read_text(encoding='utf-8'))
    if not any(p['version']=='v19-complete-sheet' for p in manifest.setdefault('rejected_proposals',[])):
        manifest['rejected_proposals'].append({'version':'v19-complete-sheet','reason':'User: animations look good, but white speckling and inconsistent details remain. New attempt must include BASE AND BOTH ADDONS jointly with complete outfit/addon/mask references.'})
    manifest.update({'iteration':'v20 complete base and addon worn-state study',
        'status':'New full36-frame AI draft; known visual inconsistencies; pending user review, no integration.',
        'source':'source/v20-base-and-addons/armor-complete','preview':'editable-v20-complete-outfit/all-directions-three-states.png',
        'all_frames_preview':'editable-v20-complete-outfit/all36-frames-review.png',
        'walking_preview':'editable-v20-complete-outfit/walking-all-states.gif',
        'editable':'editable-v20-complete-outfit/rune-sentinel-full-outfit.aseprite',
        'editable_alternative':'editable-v20-complete-outfit/rune-sentinel-full-outfit.ora',
        'validation':'editable-v20-complete-outfit/verification.json','mask':'editable-v20-complete-outfit/working-four-channel-mask.png',
        'latest_feedback':'User approves animation direction, rejects v19 art details and base-only workflow; requests base/addons together with complete actual outfit/addon/color-mask references.',
        'base_style_approved':False,'addon1_style_approved':False,'addon2_style_approved':False,
        'base_directions_approved':[],'addon1_directions_approved':[],'technical_color_finish_image':'ea7415ff-3c4f-46d1-b484-aa77422e5b9e',
        'next_workflow':'Review full base/addon worn-state draft, refine helmet and underlying costume consistency using PixelLab AI. Extract native independent addons only after artwork is settled.',
        'remaining':['User review and refinement of full36-frame outfit design','Consistent unchanged underlying garment across addon tiers',
            'Final independent addon1/addon2 layers and all bit combinations','Final four-channel mask boundary review','Female counterpart',
            'Approved import, shop/grants and in-game verification']})
    for job in ['3df50b74-5169-45b2-8ba4-a05bec0dd76b','d9c3899d-93e5-4e3a-98a7-5e2461c09d8e','89ad0255-9dc3-4cea-96b1-82a28ae30c70','e6f3fdd9-4c74-45db-90ac-bc1604c1817b','c90b85f1-ee63-4425-9d7b-bc2fa7310d55']:
        if job not in manifest['artwork_generator_jobs']:manifest['artwork_generator_jobs'].append(job)
    js(manifest_path,manifest)
    for path in [P/'generation.json',P/'color-layer-generation.json']:
        g=json.loads(path.read_text(encoding='utf-8'));g['status']='complete; unapproved review draft';js(path,g)
    js(OUT/'generation-provenance.json',{'art_job':'e6f3fdd9-4c74-45db-90ac-bc1604c1817b','mask_job':'c90b85f1-ee63-4425-9d7b-bc2fa7310d55',
        'art_and_mask_cost_generations':18,'all_v20_generations_including_internal_rejects':45,'final_native_reference_looks':[131,335],
        'additional_native_reference_looks':[134,289,367],'no_hand_painted_art_pixels':True})
    print(json.dumps({'output':str(OUT),'art_frames':36,'mask_frames':36,'skin_fixed_pixels':protected,
        'neutral_encoding_pixels':hue,'unresolved_mask_pixels':len(uncertain),'spr_roundtrip_tiles':tiles,
        'runtime_ready':False,'DAT_SPR_unchanged':True}))

if __name__=='__main__':main()
