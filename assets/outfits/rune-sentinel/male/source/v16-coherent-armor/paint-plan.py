"""Explicit PixelLab painting decisions. This writes guards/masks, never artwork."""
from pathlib import Path
from PIL import Image
import base64
import json

HERE = Path(__file__).resolve().parent
MALE = HERE.parents[1]
current = Image.open(MALE / 'editable-v15-armor-articulation/base-neutral.png').convert('RGBA')
native = Image.open(HERE.parent / 'v14-approved-concept/native-citizen-south.png').convert('RGBA')
original_mask = Image.open(HERE.parent / 'v14-approved-concept/native-citizen-mask.png').convert('RGBA')
H,R,G,B = [(255,255,0,255),(255,0,0,255),(0,255,0,255),(0,0,255,255)]
target = {}
mask = Image.new('RGBA', native.size)
parts = {}

# Dark fitted cloth under all the plates; its folds stay subordinate to the armor.
for y in range(64):
    for x in range(64):
        if original_mask.getpixel((x,y)) not in (H,R,G,B):
            continue
        v = round(sum(native.getpixel((x,y))[:3])/3)
        v = 61 if v >= 160 else 39 if v >= 70 else 18 if v >= 20 else 4
        target[x,y] = (v,v,v,255)
        mask.putpixel((x,y), G)


def put(name, pixels, channel=R):
    for x,y,v in pixels:
        assert (x,y) in target, ('outside native clothing',name,x,y)
        target[x,y] = (v,v,v,255)
        mask.putpixel((x,y),channel)
        parts.setdefault(name,[]).append([x,y,v])


def rows(name, top, lines, channel=R):
    put(name,[(left+i,top+j,v) for j,(left,values) in enumerate(lines) for i,v in enumerate(values)],channel)


# A broad frontal facet and a continuous brow, replacing the previous checkered helmet.
rows('helmet',32,[
    (35,[18,18,18,18,18,18]),
    (34,[18,116,199,235,199,156,61,18]),
    (33,[18,116,199,235,235,199,156,116,61,18]),
    (33,[18,156,235,235,199,156,116,83,61,39,18]),
    (33,[18,199,235,199,156,116,83,61,39,39,18]),
    (33,[18,156,199,156,116,116,83,61,39,39,18]),
    (33,[18,39,61,83,116,116,83,61,39,39,18]),
],H)
put('helmet-side-plates',[(33,39,18),(34,39,156),(35,39,116),(40,39,61),(41,39,116),(42,39,39),(43,39,18),(34,40,83),(41,40,61)],H)

# The visible simple shoulder cap; the near cap is naturally occluded by the native head.
rows('shoulder-cap',38,[
    (44,[39,156,235,235,199,116,39]),
    (44,[61,199,199,156,116,83,18]),
    (44,[61,116,116,83,61,18]),
])

# Both vambraces share one stepped plate construction, registered to the actual hands.
bracer=[(0,0,199),(1,0,156),(2,0,61),(0,1,156),(1,1,156),(2,1,83),(1,2,116),(2,2,116),(3,2,61)]
for name,ox,oy in [('right-bracer',34,43),('left-bracer',54,42)]:
    put(name,[(ox+x,oy+y,v)for x,y,v in bracer])

put('collar',[(44,41,156),(45,41,156),(46,41,83),(44,42,199),(45,42,156),(46,42,83),
              (41,44,199),(42,44,235),(39,45,83),(40,45,199),(41,45,199),(42,45,156)])

# One solid faceted breastplate, not alternating decorative pixels over the whole torso.
rows('breastplate',43,[
    (43,[235,235,199,199,156,83]),
    (43,[235,199,199,61,156,83,39]),
    (43,[199,199,61,199,61,116,61]),
    (42,[156,199,61,199,255,116,61,116,39]),
    (43,[156,199,61,83,61,116,83,39]),
    (44,[156,156,61,116,83,61,39]),
    (45,[83,116,83,61,39]),
])
put('runestone',[(46,45,199),(45,46,199),(46,46,255),(47,46,116),(46,47,83)],B)

put('belt',[(43,49,39),(44,49,83),(43,50,39),(47,50,83),(48,50,116),(49,50,156),
            (50,50,83),(51,50,61),(47,51,61),(48,51,83),(49,51,116),(50,51,61),(51,51,39)])

# The same short three-row hip plate on BOTH sides, not one hanging strip and one flat patch.
hip=[(0,0,199),(1,0,199),(2,0,116),(1,1,156),(2,1,156),(3,1,83),(2,2,116),(3,2,83),(4,2,39)]
for name,ox,oy in [('right-hip-plate',44,50),('left-hip-plate',51,49)]:
    put(name,[(ox+x,oy+y,v)for x,y,v in hip])

# Both leg assemblies contain the SAME cap, flexion gap and tapered four-row greave.
# Only their anatomical placement differs in the native south pose.
knee=[(0,0,199),(1,0,235),(2,0,116),(0,1,156),(1,1,199),(2,1,116)]
greave=[(0,0,18),(1,0,199),(2,0,116),
        (1,1,235),(2,1,156),(3,1,61),
        (1,2,39),(2,2,199),(3,2,116),(4,2,39),
        (2,3,156),(3,3,83),(4,3,18)]
for side,ox,oy in [('right',48,54),('left',55,53)]:
    put(side+'-knee',[(ox+x,oy+y,v)for x,y,v in knee])
    put(side+'-knee-flexion',[(ox+1,oy+2,61),(ox+2,oy+2,39)],G)
    put(side+'-greave',[(ox+2+x,oy+3+y,v)for x,y,v in greave])

# Both boots finish at the real native toe line with matching shaft and toe-plate construction.
boot=[(0,0,18),(1,0,61),(2,0,116),(3,0,61),(4,0,39),(5,0,18),
      (0,1,18),(1,1,199),(2,1,235),(3,1,199),(4,1,116),(5,1,39),
      (0,2,18),(1,2,156),(2,2,199),(3,2,156),(4,2,83),(5,2,18),
      (1,3,18),(2,3,39),(3,3,18),(4,3,18)]
for side,ox in [('right',50),('left',58)]:
    put(side+'-boot',[(ox+x,60+y,v if side=='right' else {235:199,199:156,156:116}.get(v,v))for x,y,v in boot],B)

# Greaves overlap the boot shaft, so the same complete lower bevel remains visible on both.
for side,ox,oy in [('right',48,54),('left',55,53)]:
    put(side+'-greave-lower-bevel',[(ox+2+x,oy+3+y,v)for x,y,v in greave if y==3])

# Preserve a deliberate continuous outline at the existing native silhouette.
for (x,y),p in list(target.items()):
    if any(not (0<=x+dx<64 and 0<=y+dy<64) or not native.getpixel((x+dx,y+dy))[3]
           for dx,dy in [(0,-1),(-1,0),(1,0),(0,1)]):
        target[x,y]=(4,4,4,255)

hx=lambda p:'#'+''.join(f'{v:02x}'for v in p)
patches=[[x,y,hx(current.getpixel((x,y))),hx(color)]for (x,y),color in target.items()if current.getpixel((x,y))!=color]
(HERE/'patches.json').write_text(json.dumps(patches,indent=2),encoding='utf-8')
(HERE/'parts-plan.json').write_text(json.dumps(parts,indent=2),encoding='utf-8')
mask.save(HERE/'base-color-mask.png')
print(json.dumps({'source':base64.b64encode((MALE/'editable-v15-armor-articulation/base-neutral.png').read_bytes()).decode(),'patches':patches,'part_count':len(parts)}))
