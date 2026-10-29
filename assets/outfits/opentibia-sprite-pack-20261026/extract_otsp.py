"""Read-only OTSP10.41 DAT/SPR extraction using its bundled OTFI settings."""
from pathlib import Path
from dataclasses import dataclass
from functools import lru_cache
from math import prod
import json,struct,sys,hashlib
from PIL import Image,ImageDraw,ImageFont
HERE=Path(__file__).resolve().parent
REPO=HERE.parents[2]
sys.path.insert(0,str(REPO/'assets/outfits/rookwarden/tools'))
from export_editable import recolor,COLORS
@dataclass
class Thing:
    id:int
    category:int
    size:tuple
    layout:tuple
    sprites:list
    legacy_attributes:bytes=b'\xff'
    exact_size:int=32
def read_dat(data):
    p=12;things=[]
    sizes={0:2,8:2,9:2,21:4,24:4,25:2,28:2,29:2,32:2,34:2,38:16}
    for cat,maximum in enumerate(struct.unpack_from('<4H',data,4)):
        for look in range(100 if cat==0 else 1,maximum+1):
            attrs=bytearray()
            for _ in range(255):
                attr=data[p];p+=1
                if attr==255:break
                attr=253 if attr==16 else attr-1 if attr>16 else attr
                assert attr<=38 or attr==253,(look,cat,attr,p)
                payload_start=p
                if attr==33:
                    p+=6;length=struct.unpack_from('<H',data,p)[0];p+=2+length+4
                else:p+=sizes.get(attr,0)
                attrs.extend(bytes([attr])+data[payload_start:p])
            else:raise ValueError('Unterminated DAT attributes')
            w,h=data[p:p+2];p+=2
            exact_size=32
            if w>1 or h>1:exact_size=data[p];p+=1
            layout=tuple(data[p:p+5]);p+=5
            count=w*h*prod(layout)
            assert 0<count<=4096,(look,cat,w,h,layout)
            sprites=list(struct.unpack_from(f'<{count}I',data,p));p+=4*count
            things.append(Thing(look,cat,(w,h),layout,sprites,bytes(attrs)+b'\xff',exact_size))
    assert p==len(data),(p,len(data))
    return things
class Reader:
    def __init__(self):
        self.dat=(HERE/'upstream/client_files/otsp.dat').read_bytes()
        self.spr=(HERE/'upstream/client_files/otsp.spr').read_bytes()
        self.things=read_dat(self.dat);self.count=struct.unpack_from('<I',self.spr,4)[0]
        assert 8+4*self.count<=len(self.spr)
        self.outfits={t.id:t for t in self.things if t.category==1}
    @lru_cache(maxsize=16384)
    def sprite(self,sid):
        im=Image.new('RGBA',(32,32))
        if not sid:return im
        assert 0<sid<=self.count
        p=struct.unpack_from('<I',self.spr,8+(sid-1)*4)[0]
        if not p:return im
        size=struct.unpack_from('<H',self.spr,p+3)[0];p+=5;end=p+size;cursor=0;pix=im.load()
        while p<end:
            transparent,colored=struct.unpack_from('<2H',self.spr,p);p+=4;cursor+=transparent
            assert cursor+colored<=1024
            for _ in range(colored):
                pix[cursor%32,cursor//32]=(*self.spr[p:p+3],255);p+=3;cursor+=1
        assert p==end
        return im
    @lru_cache(maxsize=3000)
    def layer(self,look,direction,phase,pattern,layer):
        t=self.outfits[look];w,h=t.size;l,nx,ny,nz,nf=t.layout
        assert 0<=direction<nx and 0<=phase<nf and 0<=pattern<ny and 0<=layer<l
        im=Image.new('RGBA',(w*32,h*32))
        for y in range(h):
            for x in range(w):
                i=((((phase*nz+0)*ny+pattern)*nx+direction)*l+layer)*w*h+y*w+x
                im.paste(self.sprite(t.sprites[i]),((w-1-x)*32,(h-1-y)*32))
        return im
    def frame(self,look,direction=2,phase=0,full=True,indices=(58,49,2,58)):
        t=self.outfits[look];l,nx,ny,nz,nf=t.layout
        im=Image.new('RGBA',(t.size[0]*32,t.size[1]*32))
        for pattern in range(ny if full else 1):
            art=self.layer(look,direction,phase,pattern,0)
            if l==2:art=recolor(art,self.layer(look,direction,phase,pattern,1),indices)
            im.alpha_composite(art)
        return im
def main():
    r=Reader();(HERE/'extracted').mkdir(exist_ok=True);records=[];poses=0
    for look,t in r.outfits.items():
        l,nx,ny,nz,nf=t.layout
        folder=HERE/'extracted'/f'{look:02}';folder.mkdir(exist_ok=True)
        labels=set();visible=[False]*l
        for d in range(nx):
            for phase in range(nf):
                for pattern in range(ny):
                    for layer in range(l):
                        im=r.layer(look,d,phase,pattern,layer);im.save(folder/f'd{d}-f{phase}-p{pattern}-layer{layer}.png')
                        visible[layer]|=im.getbbox() is not None
                        if layer==1:labels.update(p for p in im.get_flattened_data() if p[3])
                im=r.frame(look,d,phase);im.save(folder/f'd{d}-f{phase}-full-colored.png');poses+=1
                r.frame(look,d,phase,indices=(0,0,0,0)).save(folder/f'd{d}-f{phase}-full-original.png')
        records.append({'id':look,'tile_size':t.size,'pixel_size':[n*32 for n in t.size],'layers':l,'directions':nx,'patterns':ny,'z_patterns':nz,'phases':nf,
                        'has_visible_art':visible[0],'has_visible_color_layer':l>1 and visible[1],'mask_colors':[list(x) for x in sorted(labels)],
                        'all_mask_labels_native':not labels.difference(COLORS),'addon_layers':max(0,ny-1),
                        'recommended_for_players_in_upstream_guide':17<=look<=21,'source':str(folder.relative_to(HERE))})
    f=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',13);bold=ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf',17)
    board=Image.new('RGB',(1056,((len(records)+5)//6)*180+64),'#24272b');draw=ImageDraw.Draw(board)
    draw.text((12,8),f'OpenTibia Sprite Pack · samtliga {len(records)} creature/outfit-definitioner',font=bold,fill='white')
    draw.text((12,33),'Gröna ID:n17–21 rekommenderas för spelare av paketets skapare · exempelfärger',font=f,fill='#bfc5cd')
    for i,t in enumerate(r.outfits.values()):
        x=i%6*176;y=i//6*180+58
        draw.text((x+8,y+3),f'ID {t.id:02}',font=bold,fill='#94d8ae' if 17<=t.id<=21 else 'white')
        im=r.frame(t.id);bbox=im.getbbox()
        if bbox:
            im=im.crop(bbox);scale=2 if max(im.size)*2<=156 else 1
            im=im.resize((im.width*scale,im.height*scale),Image.Resampling.NEAREST)
            assert im.width<=164 and im.height<=156,im.size
            board.paste(im,(x+(176-im.width)//2,y+26+(150-im.height)//2),im)
    board.save(HERE/'all-outfits.png')
    metadata={'upstream':'https://github.com/peonso/opentibia_sprite_pack','license':'CC BY4.0','originals':'upstream/LICENSE.txt and upstream/AUTHORS.md',
              'source_manifest':'source-manifest.json','original_art_repainted':False,'source_protocol':1041,'source_settings':{'extended':True,'transparency':False,'frame_durations':False,'frame_groups':False},
              'DAT_consumed_exactly':True,'sprite_count':r.count,'creature_outfit_definitions':len(records),'native_direction_phase_compositions':poses,'items':records,
              'preview_note':'Original art extracted losslessly; optional original four-channel client tinting; integer nearest scaling. No invented source outfit names or gender pairs.'}
    (HERE/'inventory.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'definitions':len(records),'composed_poses':poses,'sprite_count':r.count,'players':[x for x in records if x['recommended_for_players_in_upstream_guide']]}))
if __name__=='__main__':main()

