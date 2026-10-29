"""Validate final Citizen source/layers and make the pose comparison preview."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json
import hashlib
import sys

ROOT=Path(__file__).resolve().parents[1]
REPO=Path(__file__).resolve().parents[4]
sys.path.insert(0,str(REPO/'assets/outfits/rookwarden/tools'))
from export_editable import native_sheet,recolor


def main():
    source_dir=ROOT/'male/source/v1-citizen';layers=ROOT/'male/source/v2-recolorable';ed=ROOT/'male/editable-v2'
    source=Image.open(source_dir/'pixellab-harbor-envoy-clean.png').convert('RGBA')
    original=Image.open(source_dir/'native-source-sheet.png').convert('RGBA')
    native_mask=Image.open(source_dir/'native-color-mask-sheet.png').convert('RGBA')
    base=Image.open(layers/'base-48-sheet.png').convert('RGBA')
    mask=Image.open(layers/'mask-48-sheet.png').convert('RGBA')
    errors=0
    for kind,actual in [('base',base),('mask',mask)]:
        recipe=json.loads((layers/f'{kind}-edit-recipe.json').read_text())
        wanted={(p[0],p[1]):tuple(bytes.fromhex(p[3][1:])) for p in recipe[0]['pixels']}
        errors+=sum(actual.getpixel((x,y))!=wanted.get((x,y),source.getpixel((x,y))) for y in range(192) for x in range(144))
    assert errors==0,errors
    skin_changes=head_coverage=boot_coverage=0;new_strays=[]
    for y in range(192):
        for x in range(144):
            old=original.getpixel((x,y));m=native_mask.getpixel((x,y));new=base.getpixel((x,y))
            if old[3] and not m[3] and old[0]>old[1]*1.05 and old[1]>old[2]*1.1 and old!=new:skin_changes+=1
            if m==(255,255,0,255) and new[3]!=old[3]:head_coverage+=1
            if m==(0,0,255,255) and new[3]!=old[3]:boot_coverage+=1
    for row in range(4):
        for phase in range(3):
            points={(x,y) for y in range(48) for x in range(48) if base.getpixel((phase*48+x,row*48+y))[3]}
            while points:
                p=next(iter(points));points.remove(p);todo=[p];component=[]
                while todo:
                    x,y=todo.pop();component.append((x,y))
                    for dx in [-1,0,1]:
                        for dy in [-1,0,1]:
                            p=(x+dx,y+dy)
                            if p in points:points.remove(p);todo.append(p)
                if len(component)<3 and any(not original.getpixel((phase*48+x,row*48+y))[3] for x,y in component):
                    new_strays.append((row,phase,component))
    assert skin_changes==head_coverage==boot_coverage==0
    assert not new_strays,new_strays
    reference=recolor(native_sheet(original),native_sheet(native_mask),(58,49,114,58))
    after=Image.open(ed/'color-preview.png').convert('RGBA')
    font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',12)
    title=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',13)
    previews=[];sequence=[0,1,2,1,2,1,2,0]
    for phase in sequence:
        canvas=Image.new('RGB',(512,356),(43,43,43));draw=ImageDraw.Draw(canvas)
        draw.text((12,6),'Citizen som kroppsmall / Harbor Envoy',font=title,fill='white')
        for row,label in enumerate(['Norr','Öster','Söder','Väster']):
            x,y=(row%2)*256,32+(row//2)*160
            draw.text((x+12,y),label,font=title,fill='white')
            draw.text((x+12,y+20),'Citizen-referens',font=font,fill=(190,190,190))
            draw.text((x+140,y+20),'Nytt förslag',font=font,fill=(230,230,230))
            for image,dx in [(reference,6),(after,134)]:
                crop=image.crop((phase*64+24,row*64+24,phase*64+72,row*64+72)).resize((96,96),Image.Resampling.NEAREST)
                canvas.paste(crop,(x+dx,y+42),crop)
        previews.append(canvas)
    previews[0].save(ed/'citizen-comparison.png')
    previews[0].save(ed/'citizen-comparison.gif',save_all=True,append_images=previews[1:],duration=[1000,220,220,220,220,220,220,800],loop=0,disposal=2)
    reference.save(ed/'colored-citizen-reference.png')
    manifest=json.loads((ed/'manifest.json').read_text())
    manifest.update({'reference_looktype':128,'reference_name':'Citizen male starter, no addons',
        'reference_prefix':'citizen-male','reference_frames':12,'native_skin_pixels_changed':skin_changes,
        'native_head_coverage_changes':head_coverage,'native_boot_coverage_changes':boot_coverage,
        'guarded_pixel_patch_mismatches':errors,'new_isolated_components':new_strays})
    for filename in ['citizen-comparison.png','citizen-comparison.gif','colored-citizen-reference.png']:
        manifest['files'][filename]=hashlib.sha256((ed/filename).read_bytes()).hexdigest()
    (ed/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    validation={'status':'PASS','reference_looktype':128,'frames':12,
        'native_skin_pixels_changed':skin_changes,'native_head_coverage_changes':head_coverage,
        'native_boot_coverage_changes':boot_coverage,'guarded_pixel_patch_mismatches':errors,
        'new_isolated_components':new_strays,'cleaned_generated_fragment':[[38,123],[38,124]],
        'export_regression':'export-regression.json','preview':'../../editable-v2/citizen-comparison.gif',
        'runtime_note':'Graphic proposal only. No DAT/SPR, outfit rights, shop or game runtime changes.'}
    (layers/'validation.json').write_text(json.dumps(validation,indent=2)+'\n')
    print(json.dumps(validation))


if __name__=='__main__':main()
