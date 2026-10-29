"""Guarded PixelLab decisions for one anatomical LEFT feather mantle.

Raster masks below describe feather shapes; all artwork writes are performed
by PixelLab pixelart_workbench, independently for BASE and native color MASK.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import json
import hashlib

HERE = Path(__file__).resolve().parent
MALE = HERE.parent.parent
REFS = MALE.parent/'source/reference'
OLD = MALE/'source/v8-premium-recolorable'
RED = (255,0,0,255)
GREEN = (0,255,0,255)
BLUE = (0,0,255,255)
YELLOW = (255,255,0,255)
TRANSPARENT = (0,0,0,0)
hexrgba = lambda c: '#' + ''.join(f'{v:02x}' for v in c)

# Native shoulder landmarks, not screen-side mirroring. S/W show the near
# left arm; N/E show the far left arm, partly occluded by the native hood.
BLADES = {
 'north': [([(-1,0),(-5,1),(-7,3),(-3,4),(1,2)],64),
           ([(-1,2),(-5,4),(-7,7),(-2,7),(2,4)],78),
           ([(0,4),(-3,7),(-4,10),(0,9),(3,6)],58)],
 'east': [([(0,0),(2,-3),(6,-4),(7,-2),(4,1)],70),
          ([(2,1),(5,-2),(11,-1),(9,2),(5,4)],84),
          ([(3,3),(6,0),(12,3),(9,6),(5,6)],62)],
 'south': [([(1,-1),(4,-3),(10,-3),(7,0),(3,1)],74),
           ([(2,1),(6,-1),(13,1),(10,4),(4,4)],90),
           ([(2,4),(6,2),(14,5),(10,7),(5,7)],64)],
 'west': [([(-1,0),(-5,-1),(-10,1),(-8,4),(-3,4)],86),
          ([(-2,2),(-6,3),(-10,6),(-5,7),(0,5)],102),
          ([(-1,4),(-5,6),(-7,10),(-2,9),(2,6)],74)]}


def components(points):
    points = set(points)
    result = []
    while points:
        p = next(iter(points)); points.remove(p); todo=[p]; comp=set()
        while todo:
            x,y = todo.pop(); comp.add((x,y))
            for q in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
                if q in points: points.remove(q); todo.append(q)
        result.append(comp)
    return result


def center(component):
    return (sum(x for x,y in component)/len(component),sum(y for x,y in component)/len(component))


def prepare():
    base = Image.open(OLD/'base-48-sheet.png').convert('RGBA')
    mask = Image.open(OLD/'mask-48-sheet.png').convert('RGBA')
    edits = {'base':{},'mask':{}}; frames=[]
    for row,direction in enumerate(['north','east','south','west']):
        for phase in range(3):
            native = Image.open(REFS/f'nobleman-{direction}-{phase}.png').convert('RGBA')
            native_mask = Image.open(REFS/f'nobleman-{direction}-{phase}-mask.png').convert('RGBA')
            protected = Image.new('L',(48,48))
            green = set(); blue = set()
            for y in range(48):
                for x in range(48):
                    p = native.getpixel((x,y)); m = native_mask.getpixel((x,y))
                    if m in [YELLOW,BLUE]: protected.putpixel((x,y),255)
                    if p[3] and not m[3] and p[0]>p[1]*1.05 and p[1]>p[2]*1.1:
                        protected.putpixel((x,y),255)
                    if m==GREEN: green.add((x,y))
                    if m==BLUE: blue.add((x,y))
            protected = protected.filter(ImageFilter.MaxFilter(3))
            # An arm can touch a boot during walking. Select by the actual
            # anatomical shoulder region rather than connected-component size
            # or boot adjacency, which would switch to the far arm in W steps.
            regions={'north':(6,13,16,27),'east':(18,7,26,16),
                     'south':(20,10,34,24),'west':(14,20,27,34)}
            x0,y0,x1,y1=regions[direction]
            chosen={(x,y) for x,y in green if x0<=x<x1 and y0<=y<y1}
            assert chosen, (direction,phase,'missing native left shoulder')
            offset={'north':(1,-2),'east':(1,1),'south':(-3,-2),'west':(-1,-2)}[direction]
            cx,cy = center(chosen); anchor=(round(cx)+offset[0],round(cy)+offset[1])
            target=set(); blade_counts=[]; removed=0

            def put(x,y,pixel,mask_pixel):
                if not (0<=x<40 and 0<=y<40) or protected.getpixel((x,y)):
                    return False
                q=(phase*48+x,row*48+y)
                edits['base'][q]=pixel; edits['mask'][q]=mask_pixel; target.add((x,y))
                return True

            # Remove the feather fan from the anatomical RIGHT in back views.
            # Existing skin/head/boots are protected; the right sleeve itself
            # retains the original native limb outline and is plain soft cloth.
            if direction in ['north','west']:
                roi=(21,8,40,27) if direction=='north' else (20,7,40,23)
                x0,y0,x1,y1=roi
                for y in range(y0,y1):
                    for x in range(x0,x1):
                        q=(phase*48+x,row*48+y)
                        if not native.getpixel((x,y))[3] and base.getpixel(q)[3]:
                            removed += int(put(x,y,TRANSPARENT,TRANSPARENT))
                wrong_roi=(20,14,34,27) if direction=='north' else (14,7,27,16)
                wx0,wy0,wx1,wy1=wrong_roi
                wrong={(x,y) for x,y in green if wx0<=x<wx1 and wy0<=y<wy1}
                wx,wy=center(wrong)
                for x,y in wrong:
                    # Broad cloth light and one fold, not the old metal texture.
                    value = 78 if x+y<wx+wy-2 else (45 if x-y>wx-wy+1 else 59)
                    put(x,y,(value,value,value,255),RED)

            # Explicit three broad lobes per view. Direction-specific shapes
            # are anchored to the SAME native anatomical left shoulder.
            for points,shade in BLADES[direction]:
                polygon=[(anchor[0]+x,anchor[1]+y) for x,y in points]
                shape=Image.new('L',(48,48)); draw=ImageDraw.Draw(shape)
                draw.polygon(polygon,fill=255)
                inner=shape.filter(ImageFilter.MinFilter(3))
                spine=Image.new('L',(48,48)); sd=ImageDraw.Draw(spine)
                # A short 1px vein stops inside the broad blade, not at its tip.
                end=polygon[2]
                vein_end=(round(anchor[0]+(end[0]-anchor[0])*.68),round(anchor[1]+(end[1]-anchor[1])*.68))
                sd.line([anchor,vein_end],fill=255,width=1)
                count=0
                for y in range(40):
                    for x in range(40):
                        if shape.getpixel((x,y)):
                            value = shade if inner.getpixel((x,y)) else 24
                            if spine.getpixel((x,y)) and inner.getpixel((x,y)): value=138
                            count += int(put(x,y,(value,value,value,255),RED))
                blade_counts.append(count)
            assert min(blade_counts)>0, (direction,phase,'hidden feather blade')
            frames.append({'direction':direction,'phase':phase,'anatomical_shoulder':'left',
                'native_shoulder_center':[cx,cy],'anchor':list(anchor),'blade_visible_pixels':blade_counts,
                'removed_wrong_side_silhouette_pixels':removed,'allowed_pixels':sorted(target),
                'protected_native_pixels':sum(bool(protected.getpixel((x,y))) for y in range(48) for x in range(48))})
    for kind in ['base','mask']:
        image=base if kind=='base' else mask
        pixels=[[*q,hexrgba(image.getpixel(q)),hexrgba(new)] for q,new in sorted(edits[kind].items(),key=lambda i:(i[0][1],i[0][0])) if image.getpixel(q)!=new]
        recipe=[{'operation':'patch_pixels','layer':'image','frames':[1],'pixels':pixels,
            'reason':'Keep the raven feather mantle on the anatomical LEFT shoulder in all directions. Three readable feather blades; native head, skin, hands and boots are immutable. Feather pixels use the existing primary/body RED mask.'}]
        (HERE/f'{kind}-edit-recipe.json').write_text(json.dumps(recipe,indent=2)+'\n')
    metadata={'generator':'PixelLab pixelart_workbench, guarded base/mask patches',
        'anatomical_shoulder':'left','frames':frames,'reference':'Actual Nobleman native clothing/arm masks, three original phases',
        'before_editor_hashes':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (MALE/'editable-premium').iterdir() if p.is_file()}}
    (HERE/'shoulder-plan.json').write_text(json.dumps(metadata,indent=2)+'\n')
    print(json.dumps({'frames':[{k:v for k,v in f.items() if k not in ['allowed_pixels']} for f in frames],
        'edit_counts':{k:len(json.loads((HERE/f'{k}-edit-recipe.json').read_text())[0]['pixels']) for k in ['base','mask']}}))


if __name__=='__main__': prepare()
