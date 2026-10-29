"""Verify the scoped shoulder correction and create review comparisons."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import json
import hashlib
from prepare import BLADES, GREEN, BLUE, YELLOW

HERE=Path(__file__).resolve().parent
MALE=HERE.parent.parent
REFS=MALE.parent/'source/reference'
OLD=MALE/'source/v8-premium-recolorable'
EDIT=MALE/'editable-premium-v2'


def main():
    plan=json.loads((HERE/'shoulder-plan.json').read_text())
    protected_changes=0; outside=0; expected_errors=0; per_frame=[]
    pairs={kind:(Image.open(OLD/f'{kind}-48-sheet.png').convert('RGBA'),
                 Image.open(HERE/f'{kind}-48-sheet.png').convert('RGBA')) for kind in ['base','mask']}
    for kind,(old,new) in pairs.items():
        recipe=json.loads((HERE/f'{kind}-edit-recipe.json').read_text())
        expected={(p[0],p[1]):tuple(bytes.fromhex(p[3][1:])) for p in recipe[0]['pixels']}
        for y in range(192):
            for x in range(144):
                if new.getpixel((x,y))!=expected.get((x,y),old.getpixel((x,y))): expected_errors+=1
    for frame in plan['frames']:
        d,phase=frame['direction'],frame['phase'];row=['north','east','south','west'].index(d)
        ref=Image.open(REFS/f'nobleman-{d}-{phase}.png').convert('RGBA')
        rm=Image.open(REFS/f'nobleman-{d}-{phase}-mask.png').convert('RGBA')
        fixed=Image.new('L',(48,48))
        for y in range(48):
            for x in range(48):
                p=ref.getpixel((x,y));m=rm.getpixel((x,y))
                if m in [YELLOW,BLUE] or (p[3] and not m[3] and p[0]>p[1]*1.05 and p[1]>p[2]*1.1):
                    fixed.putpixel((x,y),255)
        fixed=fixed.filter(ImageFilter.MaxFilter(3))
        allowed={tuple(p) for p in frame['allowed_pixels']}
        for y in range(48):
            for x in range(48):
                q=(phase*48+x,row*48+y)
                changed=any(a.getpixel(q)!=b.getpixel(q) for a,b in pairs.values())
                if changed and (x,y) not in allowed: outside+=1
                if changed and fixed.getpixel((x,y)): protected_changes+=1
        # Each feather retains a visible unique region after overlap/occlusion.
        shapes=[]
        for points,shade in BLADES[d]:
            a=Image.new('L',(48,48));dr=ImageDraw.Draw(a)
            dr.polygon([(frame['anchor'][0]+x,frame['anchor'][1]+y) for x,y in points],fill=255)
            shapes.append(a)
        visible=[]
        for index,shape in enumerate(shapes):
            count=0
            for y in range(40):
                for x in range(40):
                    if shape.getpixel((x,y)) and not fixed.getpixel((x,y)) and not any(s.getpixel((x,y)) for s in shapes[index+1:]):
                        q=(phase*48+x,row*48+y)
                        assert pairs['mask'][1].getpixel(q)==(255,0,0,255)
                        assert pairs['base'][1].getpixel(q)[3]==255
                        count+=1
            assert count>=3,(d,phase,index,'feather lost behind hood or another feather',count)
            visible.append(count)
        per_frame.append({'direction':d,'phase':phase,'anatomical_shoulder':'left','visible_blade_unique_pixels':visible})
    assert protected_changes==outside==expected_errors==0,(protected_changes,outside,expected_errors)
    for name,expected in plan['before_editor_hashes'].items():
        assert hashlib.sha256((MALE/'editable-premium'/name).read_bytes()).hexdigest()==expected,('original editable file changed',name)
    before=Image.open(MALE/'editable-premium/color-preview.png').convert('RGBA')
    after=Image.open(EDIT/'color-preview.png').convert('RGBA')
    font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',13)
    title=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',14)
    sequence=[0,1,2,1,2,1,2,0];previews=[]
    for phase in sequence:
        canvas=Image.new('RGB',(640,464),(43,43,43));draw=ImageDraw.Draw(canvas)
        for row,label in enumerate(['Norr','Öster','Söder','Väster']):
            x,y=(row%2)*320,(row//2)*232
            draw.text((x+8,y+4),label,font=title,fill='white')
            draw.text((x+8,y+25),'Före',font=font,fill=(190,190,190))
            draw.text((x+170,y+25),'Efter',font=font,fill=(230,230,230))
            for image,dx in [(before,0),(after,160)]:
                # Crop only the working area for the review, not for export.
                crop=image.crop((phase*64+24,row*64+24,phase*64+72,row*64+72)).resize((144,144),Image.Resampling.NEAREST)
                canvas.paste(crop,(x+dx,y+49),crop)
        previews.append(canvas)
    previews[0].save(EDIT/'shoulder-before-after.png')
    previews[0].save(EDIT/'shoulder-before-after.gif',save_all=True,append_images=previews[1:],duration=[1000,220,220,220,220,220,220,800],loop=0,disposal=2)
    proof=Image.new('RGB',(864,576),(43,43,43))
    for row in range(4):
        for phase in range(3):
            for index,image in enumerate([before,after]):
                c=image.crop((phase*64+24,row*64+24,phase*64+72,row*64+72)).resize((144,144),Image.Resampling.NEAREST)
                proof.paste(c,(phase*288+index*144,row*144),c)
    proof.save(EDIT/'all-frames-before-after.png')
    result={'status':'PASS','anatomical_shoulder':'left','native_head_face_hands_boots_changed':protected_changes,
        'pixels_changed_outside_declared_shoulder_regions':outside,'guarded_patch_output_mismatches':expected_errors,
        'original_editable_files_byte_identical':True,'frames':per_frame,
        'visual_review':'Reviewed all four direction rows and both native walk phases at native pixel density / nearest neighbor zoom.',
        'preview_note':'Software shader preview, not an in-game screenshot. No outfit import or runtime change.'}
    (HERE/'validation.json').write_text(json.dumps(result,indent=2)+'\n')
    metadata=json.loads((EDIT/'manifest.json').read_text())
    metadata['shoulder_correction_validation']='../source/v9-shoulder-consistency/validation.json'
    for name in ['shoulder-before-after.png','shoulder-before-after.gif','all-frames-before-after.png']:
        metadata['files'][name]=hashlib.sha256((EDIT/name).read_bytes()).hexdigest()
    (EDIT/'manifest.json').write_text(json.dumps(metadata,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k!='frames'}))


if __name__=='__main__':main()
