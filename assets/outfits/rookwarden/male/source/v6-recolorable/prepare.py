"""Prepare guarded PixelLab conversion decisions; does not overwrite artwork.

Source poses and the new v5 clothing are preserved. The only pixel changes
requested here are neutral material shading and a Tibia four-color mask.
"""
from pathlib import Path
from collections import Counter
import hashlib
import json
from PIL import Image

HERE = Path(__file__).resolve().parent
MALE = HERE.parent.parent
REFS = MALE.parent / 'source/reference'
SOURCE = MALE / 'source/v5-new-garments/pixellab-rookwarden-sheet.png'
COLOR = {'head': (255,255,0,255), 'primary': (255,0,0,255),
         'secondary': (0,255,0,255), 'detail': (0,0,255,255)}
rgba = lambda c: '#' + ''.join(f'{v:02x}' for v in c)


def prepare():
    source = Image.open(SOURCE).convert('RGBA')
    base_edits, mask_edits, frame_info = [], [], []
    for row, direction in enumerate(['north', 'east', 'south', 'west']):
        for phase in range(3):
            original = Image.open(REFS / f'nobleman-{direction}-{phase}.png').convert('RGBA')
            original_mask = Image.open(REFS / f'nobleman-{direction}-{phase}-mask.png').convert('RGBA')
            green = {(x,y) for y in range(48) for x in range(48)
                     if original_mask.getpixel((x,y)) == COLOR['secondary']}
            blue = {(x,y) for y in range(48) for x in range(48)
                    if original_mask.getpixel((x,y)) == COLOR['detail']}
            pants = set()
            while green:
                first = next(iter(green)); green.remove(first)
                todo, component = [first], set()
                while todo:
                    x,y = todo.pop(); component.add((x,y))
                    for point in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
                        if point in green:
                            green.remove(point); todo.append(point)
                if any((x+dx,y+dy) in blue for x,y in component
                       for dx,dy in [(1,0),(-1,0),(0,1),(0,-1)]):
                    pants.update(component)
            counts = Counter()
            for y in range(48):
                for x in range(48):
                    pos = (phase*48+x, row*48+y)
                    p = source.getpixel(pos)
                    if not p[3]:
                        continue
                    old = original.getpixel((x,y))
                    m = original_mask.getpixel((x,y))
                    r,g,b,a = p
                    native_fixed = old[3] and p == old and not m[3]
                    if native_fixed:
                        channel = None  # Exact original skin, eyes, hands, outlines.
                    elif m == COLOR['head']:
                        channel = 'head'
                    elif m == COLOR['detail']:
                        channel = 'detail'
                    elif (x,y) in pants and r > g*1.15:
                        channel = 'secondary'
                    elif r >= 95 and r > g*1.18 and g > b*1.8:
                        channel = None  # Fixed bronze clasps, not skin or leather.
                    elif r > g*1.15 and g > b*1.12:
                        channel = 'detail'  # Leather straps and bracers.
                    elif max(r,g,b) >= 95 and max(r,g,b)-min(r,g,b) < 65:
                        channel = 'secondary'  # Contrasting coat lining/collar.
                    else:
                        channel = 'primary'  # Main coat and dark feather mantle.
                    counts[channel or 'fixed'] += 1
                    mask_pixel = COLOR[channel] if channel else (0,0,0,0)
                    if p != mask_pixel:
                        mask_edits.append([*pos, rgba(p), rgba(mask_pixel)])
                    if channel:
                        # Remove baked hue. Preserve value contrasts, with head
                        # compensation for the darker default Tibia color 57.
                        gain = 1.75 if channel == 'head' else 1.4
                        value = min(255, round(max(r,g,b)*gain))
                        neutral = (value,value,value,a)
                        if p != neutral:
                            base_edits.append([*pos,rgba(p),rgba(neutral)])
            frame_info.append({'direction':direction,'phase':phase,'pixels':dict(counts)})
    for name, pixels in [('base',base_edits),('mask',mask_edits)]:
        recipe = [{'operation':'patch_pixels','layer':'image','frames':[1],
                   'pixels':pixels,'reason':f'Native Tibia recolorable {name}: no change to pose, transparency or fixed skin; exact four-channel material selection.'}]
        (HERE/f'{name}-edit-recipe.json').write_text(json.dumps(recipe,indent=2)+'\n')
    metadata = {'source':str(SOURCE.relative_to(MALE)),
                'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
                'generator':'PixelLab pixelart_workbench guarded pixel conversion',
                'channels':{name:rgba(c) for name,c in COLOR.items()},
                'default_outfit_colors':{'head':57,'body':47,'legs':21,'feet':58},
                'mask_rule':'Opaque pure yellow/red/green/blue; transparent means fixed color.',
                'frames':frame_info,
                'edits':{'base':len(base_edits),'mask':len(mask_edits)}}
    (HERE/'conversion.json').write_text(json.dumps(metadata,indent=2)+'\n')
    print(json.dumps({'edits':metadata['edits'],'channel_totals':dict(sum((Counter(f['pixels']) for f in frame_info),Counter()))}))


if __name__ == '__main__':
    prepare()
