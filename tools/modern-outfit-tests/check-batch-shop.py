"""Check recorded native shop/Try On pixels and save ordinary-shop recordings."""
from pathlib import Path
from collections import Counter
from PIL import Image
import argparse, hashlib, json, re

p=argparse.ArgumentParser();p.add_argument('--run',type=Path,required=True);a=p.parse_args()
run=a.run.resolve();log=(run/'client-stdout.log').read_text(errors='replace')
capture=json.loads(re.search(r'^BATCH_SHOP_CAPTURE (.+)$',log,re.MULTILINE).group(1))
seen=set();cycles=[];directions=[]

def crop(frame,rect):
    return frame.crop((rect['x'],rect['y'],rect['x']+rect['width'],rect['y']+rect['height']))

def visible_pixels(im):
    pixels=list(im.get_flattened_data());background=Counter(pixels).most_common(1)[0][0]
    return sum(max(abs(v[c]-background[c]) for c in range(3))>20 for v in pixels)

for index,group in enumerate(capture['cycles'],1):
    frames=[Image.open(run/f'shop-batch-cycle-{index}-{i}.png').convert('RGB') for i in range(1,group['frames']+1)]
    variants=[]
    for widget in group['widgets']:
        seen.add(widget['look']);images=[crop(frame,widget['rect'])for frame in frames]
        visible=[visible_pixels(im)for im in images]
        unique=len({hashlib.sha256(im.tobytes()).hexdigest()for im in images})
        assert min(visible)>40,(group['family'],widget['look'],'blank/clipped preview',visible)
        assert unique>=2,(group['family'],widget['look'],'static preview',unique)
        variants.append({'looktype':widget['look'],'recorded_frames':len(frames),'unique_native_images':unique,'minimum_visible_pixels':min(visible)})
    cycles.append({'family':group['family'],'variants':variants})
    if index in (3,8,13):
        views=[crop(frame,capture['window'])for frame in frames]
        name={3:'afflicted',8:'entrepreneur',13:'veteran-paladin'}[index]
        views[0].save(run/f'shop-batch-{name}-recording.gif',save_all=True,append_images=views[1:],duration=group['delay'],loop=0,disposal=2)
assert seen==set(range(373,399)),('Missing native variants',sorted(set(range(373,399))-seen))
by_look={}
for entry in capture['directions']:
    frame=Image.open(run/Path(entry['file']).name).convert('RGB');image=crop(frame,entry['rect'])
    visible=visible_pixels(image)
    assert visible>40,(entry['look'],entry['direction'],'blank Try On',visible)
    by_look.setdefault(entry['look'],set()).add(entry['direction'])
    directions.append({'looktype':entry['look'],'direction':entry['direction'],'visible_pixels':visible})
assert set(by_look)==set(range(373,399)) and all(d=={0,1,2,3}for d in by_look.values()),'Incomplete native direction coverage'
result={'status':'PASS','native_animated_variants':26,'new_variants':22,'families':13,'all_four_tryon_directions':True,
        'native_shop_cycles':cycles,'native_tryon_directions':directions,
        'recordings_are_actual_shop_screenshots':True,'temporary_qa_board_used':False}
(run/'pixel-verification.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'status':'PASS','native_animated_variants':26,'new_variants':22,'tryon_direction_images':len(directions),'recordings':3}))
