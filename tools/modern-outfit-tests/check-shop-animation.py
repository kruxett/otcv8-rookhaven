"""Inspect actual native screenshots for visible, changing outfit frames.

The GIF is a recording cropped to the real shop window, with no painted assets.
"""
from pathlib import Path
from collections import Counter
from PIL import Image
import argparse, hashlib, json, re

p=argparse.ArgumentParser();p.add_argument('--run',type=Path,required=True);a=p.parse_args()
run=a.run.resolve();log=(run/'client-stdout.log').read_text(errors='replace')
capture=json.loads(re.search(r'^SHOP_CAPTURE (.+)$',log,re.MULTILINE).group(1))
results={}
for name in ('cycle','regression'):
    group=capture[name];frames=[Image.open(run/f'shop-native-{name}-{i}.png').convert('RGB') for i in range(1,group['frames']+1)]
    rows=[]
    for widget in group['widgets']:
        r=widget['rect'];box=(r['x'],r['y'],r['x']+r['width'],r['y']+r['height'])
        visible=[];hashes=[]
        for frame in frames:
            image=frame.crop(box);pixels=list(image.get_flattened_data());background=Counter(pixels).most_common(1)[0][0]
            visible.append(sum(max(abs(v[c]-background[c]) for c in range(3))>20 for v in pixels))
            hashes.append(hashlib.sha256(image.tobytes()).hexdigest())
        unique=len(set(hashes));look=widget['look']
        assert min(visible)>40,(name,look,'blank native preview',visible)
        if name=='cycle':assert unique>=6,(look,'not all native walking frames visible',unique)
        elif look==126:assert unique==1,('static appearance changed',unique)
        else:assert unique>=2,(look,'native animated appearance did not change',unique)
        rows.append({'looktype':look,'frames':len(frames),'unique_native_images':unique,'minimum_sprite_pixels':min(visible)})
    results[name]=rows
window=capture['window'];box=(window['x'],window['y'],window['x']+window['width'],window['y']+window['height'])
frames=[Image.open(run/f'shop-native-shop-{i}.png').convert('RGB').crop(box) for i in range(1,capture['shop']['frames']+1)]
frames[0].save(run/'shop-native-recording.gif',save_all=True,append_images=frames[1:],duration=capture['shop']['delay'],loop=0,disposal=2)
report={'status':'PASS','scope':'Actual fresh native client screenshots; fixed-direction walk cycles and existing appearance regressions','results':results,'recording':'shop-native-recording.gif'}
(run/'animation-result.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report))
