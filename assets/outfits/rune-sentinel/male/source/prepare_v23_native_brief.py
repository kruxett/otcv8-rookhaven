"""Native pose/reference preparation only. No generated artwork is altered."""
from pathlib import Path
from collections import deque
import sys,json,hashlib
from PIL import Image,ImageDraw,ImageFont,ImageFilter
P=Path(__file__).resolve().parent
MALE=P.parent;REPO=MALE.parents[3];OUT=P/'v23-native-rich-raw'
sys.path.insert(0,str(P))
from prepare_v20_full_outfit import extract,tile_pos
from item_assets import parse_dat
C=[(255,255,0,255),(255,0,0,255),(0,255,0,255),(0,0,255,255)]

def main():
    assert not OUT.exists();OUT.mkdir()
    dat=(REPO/'data/things/860/Tibia.dat').read_bytes();spr=(REPO/'data/things/860/Tibia.spr').read_bytes();things,_=parse_dat(dat)
    citizen=next(t for t in things if t.category==1 and t.client_id==128)
    target=Image.new('RGBA',(240,240));paint=Image.new('RGB',(240,240),'black');fixed=target.copy();posemask=target.copy()
    face_count=0;contour_count=0
    for d in range(4):
        for phase in range(3):
            native=extract(citizen,spr,0,d,phase,0).crop((24,24,64,64))
            labels=extract(citizen,spr,0,d,phase,1).crop((24,24,64,64))
            remaining={(x,y) for y in range(40) for x in range(40) if native.getpixel((x,y))[3] and
                labels.getpixel((x,y))[3]==0 and len(set(native.getpixel((x,y))[:3]))>1}
            protected=Image.new('L',(40,40))
            while remaining:
                first=remaining.pop();stack=[first];component={first}
                while stack:
                    x,y=stack.pop()
                    for dx,dy in [(0,1),(1,0),(-1,0),(0,-1),(-1,-1),(1,1),(-1,1),(1,-1)]:
                        q=(x+dx,y+dy)
                        if q in remaining:remaining.remove(q);component.add(q);stack.append(q)
                xs=[q[0] for q in component];ys=[q[1] for q in component]
                ImageDraw.Draw(protected).rectangle((max(0,min(xs)-1),max(0,min(ys)-1),min(39,max(xs)+1),min(39,max(ys)+1)),fill=255)
            # Only protect existing native RGBA inside the anatomical face/hand boxes.
            for y in range(40):
                for x in range(40):
                    if not native.getpixel((x,y))[3]:protected.putpixel((x,y),0)
            head=Image.new('L',(40,40));shoulders=head.copy()
            for y in range(40):
                for x in range(40):
                    if labels.getpixel((x,y))==C[0]:head.putpixel((x,y),255)
                    if labels.getpixel((x,y))==C[1] and y<27:shoulders.putpixel((x,y),255)
            alpha=native.getchannel('A');inner=alpha.filter(ImageFilter.MinFilter(3))
            for tier in range(3):
                x0,y0=tile_pos(tier,d,phase);target.paste(native,(x0,y0));posemask.paste(labels,(x0,y0))
                head_region=head.filter(ImageFilter.MaxFilter(3 if tier==0 else 7))
                shoulder_region=shoulders.filter(ImageFilter.MaxFilter(7)) if tier==2 else Image.new('L',(40,40))
                for y in range(40):
                    for x in range(40):
                        p=native.getpixel((x,y));is_protected=bool(protected.getpixel((x,y)))
                        # Keep original limb/foot perimeter; all inner clothing seams
                        # may be redesigned. Head/shoulder silhouette may carry equipment.
                        anchored_edge=p[3] and not inner.getpixel((x,y)) and not head_region.getpixel((x,y)) and not shoulder_region.getpixel((x,y))
                        if is_protected or anchored_edge:
                            fixed.putpixel((x0+x,y0+y),p);face_count+=is_protected;contour_count+=bool(anchored_edge)
                        elif p[3] or head_region.getpixel((x,y)) or shoulder_region.getpixel((x,y)):
                            if 0<x<39 and 0<y<39:paint.putpixel((x0+x,y0+y),(255,255,255))
    target.save(OUT/'native-target-all36.png');paint.save(OUT/'anatomy-protected-paint-mask.png');fixed.save(OUT/'protected-native-anatomy.png');posemask.save(OUT/'native-part-mask-guide.png')
    context=Image.new('RGBA',(720,720))
    old=P/'v20-base-and-addons/armor-complete'
    warm=Image.open(old/'335-warmaster-all36-composed.png').convert('RGBA');wm=Image.open(old/'335-warmaster-all36-masks.png').convert('RGBA')
    assert warm.size==wm.size==(360,360);context.paste(warm,(0,0));context.paste(wm,(360,0))
    knight=Image.open(P/'v21-final-pro-attempt/knight-all36-art.png').convert('RGBA');km=Image.open(P/'v21-final-pro-attempt/knight-all36-mask.png').convert('RGBA')
    assert knight.size==km.size==(252,252)
    for tier in range(3):
        for d in range(4):
            for phase in range(3):
                x=(d%2)*126+phase*42;y=tier*84+(d//2)*42;box=(x,y,x+42,y+42)
                context.paste(knight.crop(box),(tier*126+phase*42,360+d*42));context.paste(km.crop(box),(tier*126+phase*42,528+d*42))
    context.paste(target,(480,360))
    concept=Image.open(REPO/'assets/outfits/style-study-20261026/c-rune-sentinel/pixellab-concept.png').convert('RGBA')
    assert concept.size==(64,64);context.paste(concept,(500,627))
    font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',10)
    draw=ImageDraw.Draw(context);draw.text((482,604),'RUNE SENTINEL: wardrobe identity only',font=font,fill=(220,220,220,255));draw.text((572,635),'Native poses ABOVE',font=font,fill=(220,220,220,255))
    context.save(OUT/'complete-native-references-and-concept.png')
    manifest={'pose_source':128,'pose_name':'Citizen male, all original N/E/S/W and idle/walkA/walkB',
        'source_size':[240,240],'cell_size':[40,40],'context_size':[720,720],
        'source_bbox':{'x':480,'y':360,'width':240,'height':240},
        'native_complete_reference_outfits':[335,131],'all_reference_art_and_mask_frames':144,
        'refs_contain_all4_facings_all3_phases_base_and_addons':True,
        'concept_role':'Original selected Rune Sentinel wardrobe/material richness only. NOT a pose/facing anchor.',
        'old_rejected_v19_v20_v21_v22_art_used':False,'resized_reference_art':False,
        'protected_native_face_hand_pixels':face_count,'anchored_native_contour_pixels':contour_count,
        'inside_clothing_including_old_folds_editable':True,'manual_painted_art_pixels':0,
        'dat_sha256':hashlib.sha256(dat).hexdigest(),'spr_sha256':hashlib.sha256(spr).hexdigest()}
    (OUT/'reference-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps({'folder':str(OUT),'protected_face_hand_pixels':face_count,'anchored_limb_contour_pixels':contour_count,'native_ref_art_mask_frames':144,'all36_pose_cells':True}))

if __name__=='__main__':main()
