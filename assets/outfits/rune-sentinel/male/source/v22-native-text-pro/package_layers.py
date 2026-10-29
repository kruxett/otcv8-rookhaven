"""Save lossless editable native layers and inspect every composed walk frame."""
from pathlib import Path
import importlib.util,json,hashlib,struct,sys,shutil
from PIL import Image,ImageDraw,ImageFont
P=Path(__file__).resolve().parent
MALE=P.parents[1];REPO=MALE.parents[3];OUT=MALE/'editable-v22-native-layers'
spec=importlib.util.spec_from_file_location('export',REPO/'assets/outfits/rookwarden/tools/export_editable.py')
E=importlib.util.module_from_spec(spec);spec.loader.exec_module(E)
COLORS=E.COLORS

def js(path,value):path.write_text(json.dumps(value,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
def native(im):
    result=Image.new('RGBA',(192,256))
    for d in range(4):
        for f in range(3):result.paste(im.crop((f*40,d*40,f*40+40,d*40+40)),(f*64+24,d*64+24))
    return result

def main():
    assert not OUT.exists(),'Never overwrite user-editable source.'
    arts=[Image.open(P/f'isolated-layer-{i}-all12.png').convert('RGBA') for i in range(3)]
    masks=[Image.open(P/f'isolated-mask-{i}-all12.png').convert('RGBA') for i in range(3)]
    for a,m in zip(arts,masks):
        for px,c in zip(a.get_flattened_data(),m.get_flattened_data()):
            assert px[3] in (0,255) and c[3] in (0,255)
            if c[3]:assert c in COLORS and px[3] and px[0]==px[1]==px[2]
    combinations={}
    for bits in range(4):
        art=arts[0].copy();mask=masks[0].copy()
        for layer in (1,2):
            if bits&(1<<(layer-1)):
                art=Image.alpha_composite(art,arts[layer]);mask=Image.alpha_composite(mask,masks[layer])
        combinations[bits]=(art,mask)
        assert E.recolor(art,mask,(0,0,0,0)).tobytes()==art.tobytes()
        for channel in range(4):
            indices=[0,0,0,0];indices[channel]=114;tinted=E.recolor(art,mask,indices)
            for p,q,c in zip(art.get_flattened_data(),tinted.get_flattened_data(),mask.get_flattened_data()):
                assert p[3]==q[3]
                if c!=COLORS[channel]:assert p==q
    OUT.mkdir();(OUT/'layers').mkdir()
    native_arts=[native(im) for im in arts];native_masks=[native(im) for im in masks]
    layers=[]
    for i,name in enumerate(['BASE','ADDON 1 - AI armor accents','ADDON 2 - shoulder and collar accents']):
        layers.append((name,native_arts[i],True,True))
        native_arts[i].save(OUT/'layers'/f'art-{i}-native64.png')
        native_masks[i].save(OUT/'layers'/f'mask-{i}-native64.png')
    for i,im in enumerate(native_masks):layers.append((f'MASK {i} - hidden working color channel map',im,False,True))
    merged=native(combinations[3][0]);E.write_ase(OUT/'rune-sentinel-native-layers.aseprite',layers)
    E.write_ora(OUT/'rune-sentinel-native-layers.ora',layers,merged,'Rune Sentinel v22 native layers')
    shutil.copyfile(P/'isolated-composed-all-directions-review.png',OUT/'all-directions-base-addons.png')
    for bits,(art,mask) in combinations.items():
        art.save(OUT/f'outfit-bits-{bits}-all12.png');mask.save(OUT/f'color-mask-bits-{bits}-all12.png')
    F=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',14)
    board=Image.new('RGB',(840,1010),'#24272b');draw=ImageDraw.Draw(board)
    for tier,(bits,label) in enumerate([(0,'Bas'),(1,'Bas + addon 1'),(3,'Bas + båda')]):
        draw.text((8,tier*334+3),label,font=F,fill='white');im=combinations[bits][0]
        for d,heading in enumerate(['Norr','Öster','Söder','Väster']):
            for f,phase in enumerate(['Stå','Gång A','Gång B']):
                x=d%2*420+f*140;y=tier*334+d//2*150+26
                cell=im.crop((f*40,d*40,f*40+40,d*40+40));draw.text((x+5,y),f'{heading} · {phase}',font=F,fill='white')
                zoom=cell.resize((120,120),Image.Resampling.NEAREST);board.paste(zoom,(x+8,y+23),zoom)
    board.save(OUT/'all36-frames-reviewed.png')
    frames=[]
    for f in [1,2]:
        board=Image.new('RGB',(640,540),'#24272b');draw=ImageDraw.Draw(board)
        for tier,(bits,label) in enumerate([(0,'Bas'),(1,'Bas + addon 1'),(3,'Bas + båda')]):
            im=combinations[bits][0]
            for d,heading in enumerate(['Norr','Öster','Söder','Väster']):
                x=d*160;y=tier*180;cell=im.crop((f*40,d*40,f*40+40,d*40+40))
                draw.text((x+4,y+4),f'{label} · {heading}',font=F,fill='white')
                zoom=cell.resize((120,120),Image.Resampling.NEAREST);board.paste(zoom,(x+20,y+30),zoom)
        frames.append(board)
    frames[0].save(OUT/'walking-all-angles.gif',save_all=True,append_images=frames[1:],duration=220,loop=0,disposal=2)
    sys.path.insert(0,str(REPO/'tools'));from item_assets import encode_sprite,sprite_image
    tiles=0
    for im in [*native_arts,*native_masks]:
        for y in range(0,256,32):
            for x in range(0,192,32):
                cell=im.crop((x,y,x+32,y+32));encoded=b'TEST'+struct.pack('<HI',1,10)+encode_sprite(cell)
                assert sprite_image(encoded,1).tobytes()==cell.tobytes();tiles+=1
    ref=json.loads((P/'reference-manifest.json').read_text())
    for filename,key in [('Tibia.dat','dat_sha256'),('Tibia.spr','spr_sha256')]:
        assert hashlib.sha256((REPO/'data/things/860'/filename).read_bytes()).hexdigest()==ref[key]
    qa={'status':'graphical proposal; not user-approved; not game-imported','generator':'PixelLab Pro text edit + constrained Pro inpaint correction',
        'generation_jobs':['e9f8871c-b2d2-480d-9ea9-26cd46629441','1ceec07b-43ad-4668-9a6c-5f1b362a3496'],
        'generation_cost':35,'all36_frames_generated_jointly':True,'base_and_two_independent_native_addons':True,
        'art_source':'PixelLab AI output only; automatic mask-based layer extraction and neutral-luma encoding; no hand-painted costume pixels',
        'technical_processing':json.loads((P/'layer-extraction.json').read_text()),
        'four_addon_bit_combinations_composed':[0,1,2,3],'four_tint_channels_isolated':True,
        'ase_cel_and_flags_readback':True,'ora_layer_readback':True,'sprite_860_lossless_tiles':tiles,
        'DAT_SPR_unchanged':True,'native_canvas':[64,64],'native_placement':[24,24],'frames_each_layer':12,
        'visual_checks':['all36 composed frames reviewed separately','NORTH has back of helmet and armor rather than chest rune','base clothing reused exactly under both addons'],
        'limitations':['Working mask boundaries and addon extraction need user graphic review.','No in-game rendering verification or female counterpart yet.']}
    js(OUT/'verification.json',qa)
    (OUT/'README.md').write_text('''# Rune Sentinel v22 – grafikförslag

PixelLab Pro målade alla 36 bärlägen tillsammans: bas, bas + addon1 och bas + båda,
med Warrior/Knight-originalens samtliga vinklar, gångbilder, addons och färgmasker
i samma underlag. Pro-inpaint korrigerade sedan norrbildernas fram/bak-fel och
stövlarnas material med övriga pixlar låsta. Originalen finns orörda under source/.

Detta är inte frihandsritat. Den tekniska uppdelningen väljer AI-målade pixlar
med hjälm-/överkroppsmasker till två oberoende addonlager. Resten av basens kläder
återanvänds exakt, som i native-outfits. Automatisk gråkonvertering behåller varje
vald pixels Rec709-ljushet. Maskmetadata använder native kroppskanaler och AI:s
etiketter; maskgränserna och detaljerna i lageruppdelningen behöver granskning.
Detta är ett grafiskt förslag, inte en pixel-exakt kopia av native anatomi eller
en spelverifierad import. Inga nya klient/server-outfits eller shoprättigheter
har lagts till.

Öppna rune-sentinel-native-layers.aseprite eller .ora. De tre översta lagren är
bas, addon1 och addon2. Slå av/på addons för kombinationerna 0/1/2/3. Färgmaskerna
är dolda och redigerbara. Varje native-cell är 64×64; AI-grafikens 40×40-celler
placeras oförstorade vid +24,+24. Rader N/E/S/W, kolumner stå/gång A/gång B.

Verification.json redovisar lager-/färg-/SPR-kontrollerna. Male-grafiken kräver
användargodkännande innan import. Female återstår efter godkänd stil.
''',encoding='utf-8')
    manifest_path=MALE/'design-manifest.json';old=json.loads(manifest_path.read_text(encoding='utf-8'));js(P/'manifest-before-v22.json',old)
    old.update({'status':'User requested renewed PixelLab attempt. v22 native-layer proposal pending graphic approval; nothing imported.',
        'iteration':'v22 native references, Pro text mode plus targeted back/boot correction','source':'source/v22-native-text-pro',
        'preview':'editable-v22-native-layers/all-directions-base-addons.png','all_frames_preview':'editable-v22-native-layers/all36-frames-reviewed.png',
        'walking_preview':'editable-v22-native-layers/walking-all-angles.gif','editable':'editable-v22-native-layers/rune-sentinel-native-layers.aseprite',
        'editable_alternative':'editable-v22-native-layers/rune-sentinel-native-layers.ora','validation':'editable-v22-native-layers/verification.json',
        'latest_feedback':'User explicitly requested another PixelLab attempt with clear instructions and actual references.',
        'base_style_approved':False,'addon1_style_approved':False,'addon2_style_approved':False,
        'base_directions_approved':[],'addon1_directions_approved':[],
        'next_workflow':'Review male base and independent AI addon layers and working masks. Refine only identified visual issues; no game integration before user graphic approval.',
        'remaining':['User graphic approval of base/addon design and working masks','Female counterpart','Approved game import, shop grants/purchase verification and in-game rendering']})
    old.pop('selected_existing_fallback',None)
    for job in qa['generation_jobs']:
        if job not in old.setdefault('artwork_generator_jobs',[]):old['artwork_generator_jobs'].append(job)
    js(manifest_path,old)
    print(json.dumps({'output':str(OUT),'frames_per_layer':12,'independent_addon_layers':2,'addon_combinations':4,'lossless_sprite_tiles':tiles,'DAT_SPR_unchanged':True}))

if __name__=='__main__':main()
