"""Selection boards from actual original OTSP frames, masks and addon layers."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,hashlib
import extract_otsp as E
HERE=Path(__file__).resolve().parent
PLAYERS=[16,17,18,19,20,21,44,45]
ADVANCED=[20,21,44,45]
def main():
    r=E.Reader();inventory=json.loads((HERE/'inventory.json').read_text())
    font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',13)
    bold=ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf',17)
    creditfont=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',11)
    def credits(board):
        ImageDraw.Draw(board).text((12,board.height-21),'OpenTibia Sprite Pack contributors · CC BY4.0 · github.com/peonso/opentibia_sprite_pack · exempelfärger/3×',font=creditfont,fill='#aeb7c2')
    def frame(look,direction,phase,bits=3,indices=(58,49,2,58)):
        t=r.outfits[look];l,nx,ny,nz,nf=t.layout
        result=Image.new('RGBA',(64,64))
        for pattern in range(ny):
            if pattern and not bits&(1<<(pattern-1)):continue
            art=r.layer(look,direction,phase,pattern,0)
            if l==2:art=E.recolor(art,r.layer(look,direction,phase,pattern,1),indices)
            result.alpha_composite(art)
        return result
    bounds=[]
    for look in PLAYERS:
        for d in range(4):
            for f in range(3):
                b=frame(look,d,f).getbbox()
                if b:bounds.append(b)
    crop=(max(0,min(b[0] for b in bounds)-1),max(0,min(b[1] for b in bounds)-1),min(64,max(b[2] for b in bounds)+1),min(64,max(b[3] for b in bounds)+1))
    assert max(crop[2]-crop[0],crop[3]-crop[1])*3<=166
    def place(board,look,d,phase,x,y,bits=3):
        art=frame(look,d,phase,bits).crop(crop);art=art.resize((art.width*3,art.height*3),Image.Resampling.NEAREST)
        board.paste(art,(x+(220-art.width)//2,y+(166-art.height)//2),art)
    def human_board(phase):
        board=Image.new('RGB',(880,544),'#24272b');draw=ImageDraw.Draw(board)
        draw.text((12,8),'OpenTibia Sprite Pack · åtta spelarkandidater',font=bold,fill='white')
        draw.text((12,34),'Paketets original-ID:n · befintliga addons visas · exempelfärger',font=font,fill='#bfc5cd')
        for i,look in enumerate(PLAYERS):
            x=i%4*220;y=i//4*222+62;t=r.outfits[look];l,nx,ny,nz,nf=t.layout
            draw.text((x+12,y+3),f'ID {look}',font=bold,fill='#e4bd73' if look in ADVANCED else 'white')
            place(board,look,2,phase,x,y+22)
            label=('Färgval' if l==2 else 'Fasta färger')+(' · två addons' if ny==3 else ' · utan addons')
            draw.text((x+12,y+195),label,font=font,fill='#c0c6ce')
        credits(board)
        return board
    human_board(0).save(HERE/'human-outfits-eight.png')
    frames=[human_board(f) for f in (1,2)]
    frames[0].save(HERE/'human-outfits-eight-walking.gif',save_all=True,append_images=frames[1:],duration=220,loop=0,disposal=2)
    detail=Image.new('RGB',(720,860),'#24272b');draw=ImageDraw.Draw(detail)
    draw.text((12,8),'Fyra outfits med två riktiga addonlager',font=bold,fill='white')
    for col,label in enumerate(['Bas','Bas + addon1','Bas + båda addons']):draw.text((col*240+15,35),label,font=font,fill='#c0c6ce')
    for row,look in enumerate(ADVANCED):
        y=row*192+63;draw.text((12,y),f'ID {look}',font=bold,fill='#e4bd73')
        for col,bits in enumerate([0,1,3]):place(detail,look,2,0,col*240+10,y+22,bits)
    credits(detail)
    detail.save(HERE/'four-outfits-addon-stages.png')
    def angle_board(phase):
        board=Image.new('RGB',(880,864),'#24272b');draw=ImageDraw.Draw(board)
        draw.text((12,8),'Outfits 20,21,44,45 · samtliga riktningar · båda addons',font=bold,fill='white')
        for d,name in enumerate(['Norr','Öster','Söder','Väster']):draw.text((d*220+12,35),name,font=font,fill='#c0c6ce')
        for row,look in enumerate(ADVANCED):
            y=row*192+64
            for d in range(4):
                draw.text((d*220+12,y),f'ID {look}',font=bold,fill='#e4bd73');place(board,look,d,phase,d*220,y+22)
        credits(board)
        return board
    angle_board(0).save(HERE/'four-outfits-all-directions.png')
    frames=[angle_board(f) for f in (1,2)]
    frames[0].save(HERE/'four-outfits-all-directions-walking.gif',save_all=True,append_images=frames[1:],duration=220,loop=0,disposal=2)
    qa={'source_art_repainted':False,'sprite_pack_art_and_masks_only':True,'native_phases_and_directions_preserved':True,'display':'Shared original-coordinate crop then nearest3x; no per-pose shape changes. Native four-channel shader tint sample.',
        'selected_humanoids':PLAYERS,'addon_candidates':ADVANCED,'native_player_poses_reviewed':0,'addon_nonempty_and_visible':{},
        'upstream_guide_stale_count':{'guide':24,'actual_DAT_definitions':46},'native_source_masks_valid':all(x['all_mask_labels_native'] for x in inventory['items']),
        'gender_note':'No sex/pair metadata in this pack.44/45 appear visually related; pairing not asserted from file data.',
        'access_status':'No source game DAT/SPR or shop modified. Graphic selection and8.60 conversion pending.'}
    for look in PLAYERS:
        l,nx,ny,nz,nf=r.outfits[look].layout
        for d in range(4):
            for f in range(3):
                art=frame(look,d,f);native=frame(look,d,f,indices=(0,0,0,0))
                assert art.getchannel('A').tobytes()==native.getchannel('A').tobytes()
                qa['native_player_poses_reviewed']+=1
                for bits in range(4):
                    merged=frame(look,d,f,bits)
                    assert merged.getbbox()
        if look in ADVANCED:
            qa['addon_nonempty_and_visible'][look]={}
            for pattern in (1,2):
                pixels=changed=0
                for d in range(4):
                    for f in range(3):
                        a=r.layer(look,d,f,pattern,0);b=r.layer(look,d,f,0,0)
                        pixels+=sum(p[3]>0 for p in a.get_flattened_data())
                        changed+=sum(p!=q for p,q in zip(b.get_flattened_data(),Image.alpha_composite(b,a).get_flattened_data()))
                assert pixels>0 and changed>0
                qa['addon_nonempty_and_visible'][look][pattern]={'opaque_pixels_all12':pixels,'visible_changes_to_base_all12':changed}
    # Detect exact matches to already-extracted official Tibia previews rather than assume novel art.
    signature=lambda im:hashlib.sha256(im.crop(im.getbbox()).tobytes()).hexdigest() if im.getbbox() else None
    ref=HERE.parents[0]/'reference-review-20261026/tibia'
    signatures={}
    if ref.exists():
        for file in ref.glob('*/south-full.png'):
            im=Image.open(file).convert('RGBA');signatures.setdefault(signature(im),[]).append(int(file.parent.name))
    qa['exact_colored_preview_matches_to_installed_Tibia']={look:signatures.get(signature(frame(look,2,0)),[]) for look in PLAYERS}
    (HERE/'selection-verification.json').write_text(json.dumps(qa,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    print(json.dumps({'human_figures':len(PLAYERS),'addon_ready_figures':len(ADVANCED),'native_direction_phase_pairs':qa['native_player_poses_reviewed'],'official_exact_matches':qa['exact_colored_preview_matches_to_installed_Tibia'],'output':str(HERE)}))
if __name__=='__main__':main()

