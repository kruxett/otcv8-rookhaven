"""Package AI artwork losslessly; never paint, move or redesign its geometry."""
from pathlib import Path
from collections import Counter
import hashlib
import importlib.util
import json
import shutil
import sys
from PIL import Image, ImageDraw, ImageFont

SOURCE = Path(__file__).resolve().parent
MALE = SOURCE.parents[2]
REPO = MALE.parents[3]
OUT = MALE / 'editable-v19-complete-sheet'
spec = importlib.util.spec_from_file_location('editable_export', REPO / 'assets/outfits/rookwarden/tools/export_editable.py')
export = importlib.util.module_from_spec(spec)
spec.loader.exec_module(export)
DIRECTIONS = ['north', 'east', 'south', 'west']
LABELS = ['Norr', 'Öster', 'Söder', 'Väster']
CHANNEL_NAMES = ['H - helmet', 'R - chest and arms', 'G - legs', 'B - boots and runestone']


def load(name):
    return Image.open(SOURCE / name).convert('RGBA')


def save_json(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def native64(sheet):
    result = Image.new('RGBA', (192, 256))
    for row in range(4):
        for phase in range(3):
            cell = sheet.crop((phase*32, row*32, (phase+1)*32, (row+1)*32))
            result.paste(cell, (phase*64+32, row*64+32))
    return result


def review(sheet, path):
    canvas = Image.new('RGB', (672, 752), '#24272b')
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf', 17)
    for row, label in enumerate(LABELS):
        for phase, step in enumerate(['stå', 'gång A', 'gång B']):
            x, y = phase*224+10, row*188+6
            draw.text((x,y), f'{label} · {step}', font=font, fill='#ededed')
            cell = sheet.crop((phase*32, row*32, (phase+1)*32, (row+1)*32))
            zoom = cell.resize((160,160), Image.Resampling.NEAREST)
            canvas.paste(zoom, (x+10,y+25), zoom)
            # The actual unscaled sprite is beside its magnification.
            canvas.paste(cell, (x+180,y+135), cell)
    canvas.save(path)


def main():
    assert not OUT.exists(), 'Never overwrite a potentially user-edited source.'
    base = load('base-neutral-all12.png')
    ai = load('pixellab-ai-original.png')
    native = load('native-target-all12.png')
    native_mask = load('native-color-mask-all12.png')
    assert base.size == ai.size == native.size == native_mask.size == (96,128)
    colors = export.COLORS
    mask = native_mask.copy()
    gem_pixels = []
    outside_alpha_mask_pixels = []
    changed_hue = 0
    protected = 0
    for y in range(128):
        for x in range(96):
            p, raw, old, m = [im.getpixel((x,y)) for im in [base,ai,native,native_mask]]
            assert p[3] == raw[3] == old[3] and p[3] in (0,255), ('alpha',x,y)
            if m[3] and not p[3]:
                mask.putpixel((x,y),(0,0,0,0))
                outside_alpha_mask_pixels.append([x,y])
            if m[3] and p[3]:
                assert m in colors and p[3] == 255
                v = round(.2126*raw[0] + .7152*raw[1] + .0722*raw[2])
                assert p == (v,v,v,raw[3]), ('hue-only conversion',x,y,p,raw)
                changed_hue += p != raw
                # Mask metadata only: route AI's cyan chest stone to detail tint.
                if m == colors[1] and raw[2] > raw[0]+40 and raw[1] > raw[0]+25 and max(raw[:3]) > 90:
                    mask.putpixel((x,y),colors[3])
                    gem_pixels.append([x,y])
            else:
                assert p == raw == old, ('protected native pixel',x,y)
                protected += p[3] != 0
    conversion = json.loads((SOURCE/'technical-neutral-conversion.json').read_text(encoding='utf-8'))
    assert changed_hue == conversion['color_pixels'] == 2508
    # Original AI paint and neutral encoding share every alpha and every luma.
    assert base.getchannel('A').tobytes() == native.getchannel('A').tobytes()

    layers = [('NATIVE CITIZEN - pose guide',native,False,False),
              ('PIXELLAB AI ORIGINAL - before neutral encoding',ai,False,False)]
    fixed = Image.new('RGBA',base.size)
    partitions = [Image.new('RGBA',base.size) for _ in colors]
    for y in range(128):
        for x in range(96):
            p,m = base.getpixel((x,y)),mask.getpixel((x,y))
            if m in colors:
                partitions[colors.index(m)].putpixel((x,y),p)
            else:
                fixed.putpixel((x,y),p)
    layers.append(('FIXED native face and hands',fixed,True,False))
    layers.extend((name,im,True,True) for name,im in zip(CHANNEL_NAMES,partitions))
    layers.append(('WORKING COLOR MASK - hidden',mask,False,True))
    merged = Image.new('RGBA',base.size)
    for _,im,visible,_ in layers:
        if visible:
            merged = Image.alpha_composite(merged,im)
    assert merged.tobytes() == base.tobytes()
    assert export.recolor(base,mask,(0,0,0,0)).tobytes() == base.tobytes()
    for channel in range(4):
        indices = [0,0,0,0]
        indices[channel] = 114
        tinted = export.recolor(base,mask,indices)
        assert tinted.getchannel('A').tobytes() == base.getchannel('A').tobytes()
        for y in range(128):
            for x in range(96):
                if mask.getpixel((x,y)) != colors[channel]:
                    assert tinted.getpixel((x,y)) == base.getpixel((x,y))

    OUT.mkdir()
    (OUT/'layers').mkdir()
    (OUT/'frames').mkdir()
    shutil.copyfile(SOURCE/'base-neutral-all12.png',OUT/'base-neutral-all12.png')
    shutil.copyfile(SOURCE/'pixellab-ai-original.png',OUT/'pixellab-ai-original.png')
    mask.save(OUT/'working-color-mask.png')
    native.save(OUT/'native-anatomy-reference.png')
    native64(base).save(OUT/'native64-base-atlas.png')
    native64(mask).save(OUT/'native64-working-mask-atlas.png')
    for name,im,_,_ in layers[2:-1]:
        im.save(OUT/'layers'/f'{name.split(" ")[0].lower()}.png')
    export.write_ase(OUT/'rune-sentinel-all12.aseprite',layers)
    export.write_ora(OUT/'rune-sentinel-all12.ora',layers,base,'Rune Sentinel male - all12 PixelLab AI base')
    review(base,OUT/'complete-sheet-review.png')
    font = ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',15)
    animation = []
    frame_checks = []
    for phase in [1,2]:
        canvas = Image.new('RGB',(640,180),'#24272b')
        draw = ImageDraw.Draw(canvas)
        for row,label in enumerate(LABELS):
            draw.text((row*160+10,6),label,font=font,fill='white')
            cell = base.crop((phase*32,row*32,(phase+1)*32,(row+1)*32))
            zoom = cell.resize((128,128),Image.Resampling.NEAREST)
            canvas.paste(zoom,(row*160+16,35),zoom)
        animation.append(canvas)
    animation[0].save(OUT/'walking-preview.gif',save_all=True,append_images=animation[1:],duration=220,loop=0,disposal=2)
    for row,direction in enumerate(DIRECTIONS):
        for phase in range(3):
            bbox=(phase*32,row*32,(phase+1)*32,(row+1)*32)
            cell=base.crop(bbox)
            old=native.crop(bbox)
            cell.save(OUT/'frames'/f'{direction}-{phase}.png')
            assert cell.getbbox() and cell.getchannel('A').tobytes()==old.getchannel('A').tobytes()
            frame_checks.append({'direction':direction,'phase':phase,'native_alpha_equal':True})
    # Real 8.60 SPR tile encoding/decoding; no DAT or SPR file is changed.
    sys.path.insert(0,str(REPO/'tools'))
    from item_assets import encode_sprite,sprite_image
    import struct
    tiles=0
    for sheet in [base,mask]:
        for row in range(4):
            for col in range(3):
                cell=sheet.crop((col*32,row*32,(col+1)*32,(row+1)*32))
                encoded=b'TEST'+struct.pack('<HI',1,10)+encode_sprite(cell)
                assert sprite_image(encoded,1).tobytes()==cell.tobytes()
                tiles+=1

    counts=Counter(mask.getdata())
    verification={'status':'asset checks passed; artwork NOT approved; no game import',
        'generator':'PixelLab inpaint_image_pro_flash','job_id':'67d10c48-86ba-43d7-a272-c5936c615505',
        'generation_scope':'all12 frames jointly with four complete existing outfit references',
        'sheet_size':[96,128],'rows':DIRECTIONS,'columns':['idle0','walk1','walk2'],
        'native_cell_size':[32,32],'native64_atlas_size':[192,256],
        'manual_artistic_edits':0,'technical_hue_only_pixels':changed_hue,
        'all_native_alpha_preserved':True,'protected_native_pixels_preserved':protected,
        'visible_layer_merge_byte_exact':True,'ase_cels_and_flags_readback_passed':True,
        'ora_layers_readback_passed':True,'independent_tint_channels_passed':4,
        'lossless_860_spr_tiles_roundtrip':tiles,
        'working_mask_channels':{name:counts[color] for name,color in zip(CHANNEL_NAMES,colors)},
        'native_mask_outside_visible_alpha_clipped':outside_alpha_mask_pixels,
        'mask_only_gem_reroute':{'rule':'red torso mask AND AI B>R+40 AND G>R+25 AND maxRGB>90',
                                'pixels':gem_pixels,'artwork_changed':False},
        'frames':frame_checks,
        'limitations':['Visual consistency and garment design require user review.',
            'Working mask uses native body regions plus automatically detected chest stone; final mask needs visual approval.',
            'No addons, female counterpart or game rendering verification yet.']}
    verification['files_sha256']={name:sha(OUT/name) for name in ['base-neutral-all12.png','pixellab-ai-original.png',
        'working-color-mask.png','rune-sentinel-all12.aseprite','rune-sentinel-all12.ora']}
    save_json(OUT/'verification.json',verification)
    (OUT/'README.md').write_text('''# Rune Sentinel – komplett basförslag v19

Ej godkänt och ej importerat. PixelLab målade alla tolv poser samtidigt med kompletta
referensark från Citizen, Knight, Nightmare och Brotherhood. Citizen låser den
befintliga silhuetten samt ansikten och händer. Inga underkända Rune Sentinel-bilder
användes som referens.

`rune-sentinel-all12.aseprite` och `.ora` har separata redigerbara lager för hjälm,
överkropp, ben och stövlar/rundetalj. Ursprungliga ansikten/händer är låsta.
Mask och Citizen-guide är dolda. AI-originalet finns som separat dold referens.
Äldre redigerbara filer har inte skrivits över.

Rader: norr, öster, söder, väster. Kolumner: stå, gång A, gång B. Varje ruta är
32×32 utan omskalning. Native64-atlasen placerar dessa rutor vid +32,+32 i respektive
64×64-cell utan att skala eller centrera om dem.

Enda efterbearbetningen av AI-grafiken är automatisk neutral gråkonvertering för
spelets färgval. Den ändrar inga former. Färgmasken är ett arbetsunderlag; den
ursprungliga kroppsmasken kompletteras med automatisk identifiering av AI:ns
cyanblå bröststen till detaljkanalen. Inga outfitpixlar har ritats för hand.

Förhandsvisningen visar alla tolv bilder samt en oskalad 32×32-bild bredvid varje
förstoring. GIF:en växlar de två verkliga gångfaserna. Den är ingen verifiering i
spelklienten. Addon 1, addon 2 och female återstår efter godkänd bas.

`verification.json` redovisar bildkontroller, lageråterläsning och SPR-rundtur.
Inga klient/server-filer eller shopdata ändrades för detta förslag.
''',encoding='utf-8')
    manifest_path=MALE/'design-manifest.json'
    shutil.copyfile(manifest_path,SOURCE/'design-manifest-before-v19.json')
    manifest=json.loads(manifest_path.read_text(encoding='utf-8'))
    rejected=manifest.setdefault('rejected_proposals',[])
    if not any(p['version']=='v18-ai-base-turnaround' for p in rejected):
        rejected.append({'version':'v18-ai-base-turnaround','reason':'User rejected. Supply several COMPLETE existing outfit spritesheets and generate every direction and walk frame jointly; do not anchor other views on one generated south design.'})
    manifest.update({'status':'Complete twelve-frame PixelLab AI base draft, pending graphic review. No addons or game integration.',
        'iteration':'v19 joint whole-sheet generation from multiple complete native references',
        'reference_body':'Citizen male all four directions and all three native poses',
        'source':'source/v19-full-sheets-pro/full-sheet-constrained-ai',
        'preview':'editable-v19-complete-sheet/complete-sheet-review.png',
        'walking_preview':'editable-v19-complete-sheet/walking-preview.gif',
        'editable':'editable-v19-complete-sheet/rune-sentinel-all12.aseprite',
        'editable_alternative':'editable-v19-complete-sheet/rune-sentinel-all12.ora',
        'validation':'editable-v19-complete-sheet/verification.json',
        'body_source_phases':[0,1,2],'body_source_directions':DIRECTIONS,
        'selected_design_theme':'Rune Sentinel, elite guard from an ancient rune order; theme approved, no current artwork approved.',
        'latest_feedback':'v18 rejected. User requests multiple complete outfit references and simultaneous generation of the entire sheet.',
        'base_style_approved':False,'base_directions_approved':[],
        'technical_color_finish_image':'86370190-533e-452f-aeff-be68b763f756',
        'next_workflow':'Review the jointly generated twelve-frame complete base sheet and real two-phase walk preview; maintain PixelLab AI artwork provenance and disclose technical color conversion.',
        'remaining':['User graphic review of complete twelve-frame base and walking consistency',
            'Final visual review of four-channel tint mask','Independent addon1/addon2 and combinations 0/1/2/3',
            'Female counterpart','Approved import, shop/grant behavior and in-game verification']})
    for obsolete in ['body_source_phase','direction_workbench_ids']:
        manifest.pop(obsolete,None)
    jobs=manifest.setdefault('artwork_generator_jobs',[])
    for job in ['abc3214a-3868-4caf-9f21-9efb7d16435d','6775969f-95af-4109-b47c-28f64717b9f0','67d10c48-86ba-43d7-a272-c5936c615505']:
        if job not in jobs: jobs.append(job)
    save_json(manifest_path,manifest)
    generation=json.loads((SOURCE/'generation.json').read_text(encoding='utf-8'))
    generation.update({'status':'complete, not approved','editable_output':'../../../editable-v19-complete-sheet',
        'neutral_encoding_image_id':'86370190-533e-452f-aeff-be68b763f756'})
    save_json(SOURCE/'generation.json',generation)
    print(json.dumps({'output':str(OUT),'verified_frames':len(frame_checks),'native_skin_pixels':protected,
        'hue_only_changes':changed_hue,'gem_mask_pixels':len(gem_pixels),'lossless_tiles':tiles}))


if __name__ == '__main__':
    main()
