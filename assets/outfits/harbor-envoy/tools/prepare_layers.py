"""Prepare exact PixelLab BASE/MASK conversion for the Citizen proposal."""
from pathlib import Path
from PIL import Image
from collections import Counter
import hashlib
import json

ROOT=Path(__file__).resolve().parents[1]
RAW=ROOT/'male/source/v1-citizen'
OUT=ROOT/'male/source/v2-recolorable'
MASKS={'head':(255,255,0,255),'body':(255,0,0,255),
       'legs':(0,255,0,255),'feet':(0,0,255,255)}
RAMP=(0,24,48,80,120,168,216,255)
hexrgba=lambda c:'#'+''.join(f'{v:02x}'for v in c)


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    source=RAW/'pixellab-harbor-envoy-clean.png'
    if not source.exists():source=RAW/'pixellab-harbor-envoy-raw.png'
    image=Image.open(source).convert('RGBA')
    native=Image.open(RAW/'native-source-sheet.png').convert('RGBA')
    masks=Image.open(RAW/'native-color-mask-sheet.png').convert('RGBA')
    allowed=Image.open(RAW/'garment-redesign-mask.png').convert('RGB')
    protected=Image.open(RAW/'protected-body-anchors.png').convert('L')
    base_pixels=[];mask_pixels=[];counts=Counter();back_clasps=0;changes_outside=0;anchor_changes=0
    for y in range(192):
        for x in range(144):
            p=image.getpixel((x,y));old=native.getpixel((x,y));m=masks.getpixel((x,y))
            if p!=old and allowed.getpixel((x,y))!=(255,255,255):changes_outside+=1
            if p!=old and protected.getpixel((x,y)):anchor_changes+=1
            if not p[3]:continue
            r,g,b,a=p;d=['north','east','south','west'][y//48]
            metal=r>=80 and r>g*1.2 and g>b*1.6 and g>=40
            native_fixed=old[3] and p==old and not m[3]
            rear_clasp=metal and allowed.getpixel((x,y))==(255,255,255) and d in ['north','west'] and y%48>=22
            if native_fixed:channel=None
            elif m==MASKS['head']:channel='head'
            elif m==MASKS['feet']:channel='feet'
            elif rear_clasp:channel='feet';back_clasps+=1
            elif metal:channel=None
            elif m==MASKS['legs'] and not (r>g*1.5 and r>b*1.4):channel='legs'
            elif max(r,g,b)>=100 and max(r,g,b)-min(r,g,b)<90:channel='legs'
            elif r>g*1.5 and r>b*1.4:channel='body'
            elif r>g*1.15 and g>b*1.12:channel='feet'
            else:channel='legs' if y%48>=25 else 'body'
            counts[channel or 'fixed']+=1
            target_mask=MASKS[channel] if channel else (0,0,0,0)
            if target_mask!=p:mask_pixels.append([x,y,hexrgba(p),hexrgba(target_mask)])
            if channel:
                # Retain original native hair/boot shading. Large cloth areas
                # use an eight-value ramp to reduce noisy near-identical colors.
                if rear_clasp:value=48
                elif channel=='legs' and m==MASKS['legs'] and y%48>=24:
                    # Keep the trousers dark, including the frozen native
                    # boot margin and pale generated trouser highlights.
                    desired=min(80,max(r,g,b))
                    value=min(RAMP,key=lambda v:abs(v-desired))
                elif channel=='head':value=max(r,g,b)
                elif channel=='feet':value=max(r,g,b)
                else:
                    gain=4/3 if channel=='body' else 1
                    desired=min(255,round(max(r,g,b)*gain))
                    value=min(RAMP,key=lambda v:abs(v-desired))
                neutral=(value,value,value,a)
                if neutral!=p:base_pixels.append([x,y,hexrgba(p),hexrgba(neutral)])
    assert changes_outside==anchor_changes==0,(changes_outside,anchor_changes)
    for name,pixels in [('base',base_pixels),('mask',mask_pixels)]:
        recipe=[{'operation':'patch_pixels','layer':'image','frames':[1],'pixels':pixels,
                 'reason':'Citizen-based Harbor Envoy: native four player-color channels, neutral clean cloth ramp, exact fixed skin, and a plain belt in rear views. No pose or silhouette changes.'}]
        (OUT/f'{name}-edit-recipe.json').write_text(json.dumps(recipe,indent=2)+'\n')
    meta={'reference_looktype':128,'source':str(source),
          'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
          'channels':dict(counts),'cloth_neutral_values':RAMP,'rear_gold_clasp_pixels_replaced_with_plain_belt':back_clasps,
          'inpaint_changes_outside_mask':changes_outside,'inpaint_body_anchor_changes':anchor_changes,
          'defaults':{'head':58,'body':112,'legs':2,'feet':58},
          'edits':{'base':len(base_pixels),'mask':len(mask_pixels)}}
    (OUT/'conversion.json').write_text(json.dumps(meta,indent=2)+'\n')
    print(json.dumps(meta))


if __name__=='__main__':main()
