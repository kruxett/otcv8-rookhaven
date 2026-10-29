"""Complete native armor references, including every addon and color mask."""
from pathlib import Path
import sys,json
from PIL import Image
P=Path(__file__).resolve().parent
sys.path.insert(0,str(P.parent))
from prepare_v20_full_outfit import tile_pos,extract,REPO
from item_assets import parse_dat
O=P/'armor-complete';O.mkdir(exist_ok=False)
things,_=parse_dat((REPO/'data/things/860/Tibia.dat').read_bytes());spr=(REPO/'data/things/860/Tibia.spr').read_bytes()
context=Image.new('RGBA',(720,720));records=[]
for look,name,crop in [(335,'Warmaster',4),(131,'Knight',20)]:
    t=next(t for t in things if t.category==1 and t.client_id==look)
    cell=64-crop
    raw=Image.new('RGBA',(cell*9,cell*8))
    art=Image.new('RGBA',(cell*6,cell*6));mask=art.copy()
    for d in range(4):
        for phase in range(3):
            b=Image.new('RGBA',(64,64));m=b.copy()
            for tier in range(3):
                ims=[extract(t,spr,tier,d,phase,layer) for layer in range(2)]
                for layer,im in enumerate(ims):
                    box=im.getbbox();assert not box or box[0]>=crop and box[1]>=crop,(look,tier,layer,d,phase,box)
                    raw.paste(im.crop((crop,crop,64,64)),(tier*3*cell+phase*cell,(layer*4+d)*cell))
                b=Image.alpha_composite(b,ims[0]);m=Image.alpha_composite(m,ims[1])
                pos=((d%2)*3*cell+phase*cell,(tier*2+d//2)*cell)
                art.paste(b.crop((crop,crop,64,64)),pos);mask.paste(m.crop((crop,crop,64,64)),pos)
    raw.save(O/f'{look}-{name.lower()}-native-all-base-addons-masks.png')
    art.save(O/f'{look}-{name.lower()}-all36-composed.png');mask.save(O/f'{look}-{name.lower()}-all36-masks.png')
    if look==335:
        context.paste(art,(0,0));context.paste(mask,(360,0))
    else:
        for d in range(4):
            for phase in range(3):
                for tier in range(3):
                    x=(d%2)*3*cell+phase*cell;y=(tier*2+d//2)*cell
                    context.paste(art.crop((x,y,x+cell,y+cell)),(tier*132+phase*44,360+d*44))
                    context.paste(mask.crop((x,y,x+cell,y+cell)),(tier*132+phase*44,536+d*44))
    records.append({'looktype':look,'name':name,'art_frames':36,'mask_frames':36,'directions':['north','east','south','west'],
        'phases':[0,1,2],'addon_states':[0,1,3],'independent_raw_layers_and_masks_saved':True,
        'native_crop':[crop,crop,64,64],'cropping_lost_pixels':0,'resized':False})
target=Image.open(P/'composed-ai/armor-refinement/target-three-complete-states.png').convert('RGBA')
target.save(O/'target-three-complete-states.png')
context.paste(target,(480,360));context.save(O/'complete-reference-context.png')
(O/'reference-manifest.json').write_text(json.dumps({'references':records,'reference_art_and_mask_frames':144,
    'additional_reference_set':'../reference-manifest.json','native_scale':True,
    'source_bbox_in_context':{'x':480,'y':360,'width':240,'height':240},'same_all36_target_layout':True,
    'target_provenance':'Earlier v19 armor is edit target, explicitly unfinished; actual Knight and Warmaster supply style/structure.'},indent=2)+'\n')
print(json.dumps({'output':str(O),'reference_frames':144,'all_directions_animations_addons_masks':True,'no_crop_loss':True}))
