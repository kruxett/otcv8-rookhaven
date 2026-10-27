"""Package PixelLab layers for manual editing, without changing sprite art.

ASE: https://github.com/aseprite/aseprite/blob/main/docs/ase-file-specs.md
ORA: https://www.openraster.org/baseline/file-layout-spec.html
The previews implement the local client's four-channel multiply shader.
"""
from pathlib import Path
from io import BytesIO
import argparse
import colorsys
import hashlib
import json
import struct
import sys
import xml.etree.ElementTree as ET
import zipfile
import zlib
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
REPO = Path(__file__).resolve().parents[4]
COLORS = [(255,255,0,255),(255,0,0,255),(0,255,0,255),(0,0,255,255)]
DIRECTIONS = ['north','east','south','west']


def outfit_color(index):
    """Source formula: src/framework/util/color.cpp, Color::getOutfitColor."""
    index = index if 0 <= index < 133 else 0
    if index % 19 == 0:
        v = int((1-index/19/7)*255)
        return (v,v,v)
    saturation, value = [(0.25,1),(0.25,.75),(.5,.75),(.667,.75),
                         (1,1),(1,.75),(1,.5)][index//19]
    return tuple(int(c*255) for c in colorsys.hsv_to_rgb(index%19/18,saturation,value))


def recolor(base, mask, indices):
    result = base.copy()
    palette = {m:outfit_color(i) for m,i in zip(COLORS,indices)}
    for y in range(base.height):
        for x in range(base.width):
            tint = palette.get(mask.getpixel((x,y)))
            if tint:
                p = base.getpixel((x,y))
                result.putpixel((x,y),(*[round(p[c]*tint[c]/255) for c in range(3)],p[3]))
    return result


def native_sheet(sheet):
    """Undo reference crop translation exactly, never scale or recenter."""
    result = Image.new('RGBA',(192,256))
    for row in range(4):
        for phase in range(3):
            cell = sheet.crop((phase*48,row*48,(phase+1)*48,(row+1)*48))
            bbox = cell.getbbox()
            assert not bbox or (bbox[2]<=40 and bbox[3]<=40), ('native canvas overflow',row,phase,bbox)
            # Crop away transparent right/bottom padding before placing at +24.
            result.paste(cell.crop((0,0,40,40)),(phase*64+24,row*64+24))
    return result


def png_bytes(image):
    stream = BytesIO(); image.save(stream,format='PNG'); return stream.getvalue()


def ase_string(value):
    value = value.encode('utf-8'); return struct.pack('<H',len(value))+value


def chunk(kind,data):
    return struct.pack('<IH',len(data)+6,kind)+data


def write_ase(path,layers):
    w,h = layers[0][1].size
    header = bytearray(128)
    struct.pack_into('<6H',header,4,0xA5E0,1,w,h,32,1)
    struct.pack_into('<I',header,14,1)
    struct.pack_into('<H',header,18,220)
    struct.pack_into('<BBhhHH',header,34,1,1,0,0,64,64)
    chunks = [chunk(0x2007,struct.pack('<HHI8s',1,0,65536,b'\0'*8))]
    names = ['Transparent / fixed','Head / yellow','Primary / red','Secondary / green','Detail / blue']
    swatches = [(0,0,0,0)]+COLORS
    palette = struct.pack('<III8s',5,0,4,b'\0'*8)
    for name,color in zip(names,swatches):
        palette += struct.pack('<H4B',1,*color)+ase_string(name)
    chunks.append(chunk(0x2019,palette))
    for name,im,visible,editable in layers:
        flags = 4 | int(visible) | (2 if editable else 0)
        data = struct.pack('<6HB3s',flags,0,0,0,0,0,255,b'\0'*3)+ase_string(name)
        chunks.append(chunk(0x2004,data))
    for index,(_,im,_,_) in enumerate(layers):
        data = struct.pack('<HhhBHh5sHH',index,0,0,255,2,0,b'\0'*5,w,h)+zlib.compress(im.tobytes(),9)
        chunks.append(chunk(0x2005,data))
    frame_data = b''.join(chunks)
    frame = struct.pack('<IHHHHI',len(frame_data)+16,0xF1FA,len(chunks),220,0,len(chunks))+frame_data
    struct.pack_into('<I',header,0,128+len(frame))
    path.write_bytes(header+frame)
    # Read back decompressed cels and layer flags independently of encoding.
    data = path.read_bytes()
    assert struct.unpack_from('<I',data,0)[0] == len(data)
    assert struct.unpack_from('<5H',data,4) == (0xA5E0,1,w,h,32)
    cursor = 144; decoded = {}; layer_flags = []
    while cursor < len(data):
        length,kind = struct.unpack_from('<IH',data,cursor); payload = cursor+6
        assert length>=6 and cursor+length<=len(data)
        if kind==0x2004: layer_flags.append(struct.unpack_from('<H',data,payload)[0])
        if kind==0x2005:
            index = struct.unpack_from('<H',data,payload)[0]
            assert struct.unpack_from('<HH',data,payload+16)==(w,h)
            decoded[index] = zlib.decompress(data[payload+20:cursor+length])
        cursor += length
    assert cursor==len(data) and len(decoded)==len(layers)
    for index,(_,im,visible,editable) in enumerate(layers):
        assert decoded[index] == im.tobytes()
        assert bool(layer_flags[index]&1)==visible
        assert bool(layer_flags[index]&2)==editable


def write_ora(path,layers,merged,title='Rookwarden male - editable native layers'):
    root = ET.Element('image',{'version':'0.0.6','w':str(merged.width),'h':str(merged.height),'name':title})
    stack = ET.SubElement(root,'stack')
    with zipfile.ZipFile(path,'w') as archive:
        archive.writestr('mimetype','image/openraster',compress_type=zipfile.ZIP_STORED)
        for index,(name,im,visible,_) in reversed(list(enumerate(layers))):
            src = f'data/layer{index}.png'
            ET.SubElement(stack,'layer',{'name':name,'src':src,'x':'0','y':'0','opacity':'1.0',
                'visibility':'visible' if visible else 'hidden','composite-op':'svg:src-over'})
            archive.writestr(src,png_bytes(im),compress_type=zipfile.ZIP_DEFLATED)
        archive.writestr('stack.xml',ET.tostring(root,encoding='utf-8',xml_declaration=True),compress_type=zipfile.ZIP_DEFLATED)
        archive.writestr('mergedimage.png',png_bytes(merged),compress_type=zipfile.ZIP_DEFLATED)
        thumb = merged.copy(); thumb.thumbnail((256,256))
        archive.writestr('Thumbnails/thumbnail.png',png_bytes(thumb),compress_type=zipfile.ZIP_DEFLATED)
    with zipfile.ZipFile(path) as archive:
        assert archive.infolist()[0].filename=='mimetype' and archive.infolist()[0].compress_type==zipfile.ZIP_STORED
        parsed = ET.fromstring(archive.read('stack.xml'))
        for layer in parsed.find('stack'):
            index = int(layer.attrib['src'].removeprefix('data/layer').removesuffix('.png'))
            assert Image.open(BytesIO(archive.read(layer.attrib['src']))).convert('RGBA').tobytes()==layers[index][1].tobytes()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--layers',type=Path,required=True)
    parser.add_argument('--source',type=Path,required=True)
    parser.add_argument('--out',type=Path,required=True)
    parser.add_argument('--reference-dir',type=Path,default=ROOT/'source/reference')
    parser.add_argument('--reference-prefix',default='nobleman')
    parser.add_argument('--stem',default='rookwarden-male')
    parser.add_argument('--colors',nargs=4,type=int,default=[57,49,2,58])
    parser.add_argument('--default-color-label',default='Marinblå')
    args = parser.parse_args()
    if any(not 0<=i<133 for i in args.colors):
        raise SystemExit('Player color IDs must be in 0..132.')
    if Path(args.stem).name!=args.stem or any(c in args.stem for c in '/\\:'):
        raise SystemExit('The project stem must be a simple filename.')
    if args.out.exists() and any(args.out.iterdir()):
        raise SystemExit('Choose a new empty output folder; user-edited layers must never be overwritten.')
    args.out.mkdir(parents=True,exist_ok=True)
    base48 = Image.open(args.layers/'base-48-sheet.png').convert('RGBA')
    mask48 = Image.open(args.layers/'mask-48-sheet.png').convert('RGBA')
    source48 = Image.open(args.source).convert('RGBA')
    assert base48.size == mask48.size == source48.size == (144,192)
    counts = {str(c):0 for c in COLORS}; fixed = 0
    for y in range(192):
        for x in range(144):
            p = base48.getpixel((x,y)); m = mask48.getpixel((x,y)); s = source48.getpixel((x,y))
            assert p[3] == s[3] and p[3] in [0,255]
            assert m[3] in [0,255]
            if m[3]:
                assert m in COLORS and p[3]==255 and p[0]==p[1]==p[2]
                counts[str(m)] += 1
            else:
                assert p==s, ('fixed pixel changed',x,y)
                if p[3]: fixed += 1
    assert all(counts.values())
    base,mask,concept = map(native_sheet,[base48,mask48,source48])
    native_reference = Image.new('RGBA',(192,256))
    for row,direction in enumerate(DIRECTIONS):
        for phase in range(3):
            ref = Image.open(args.reference_dir/f'{args.reference_prefix}-{direction}-{phase}.png').convert('RGBA')
            native_reference.paste(ref.crop((0,0,40,40)),(phase*64+24,row*64+24))
    sets = [tuple(args.colors),(57,56,21,58),(57,45,2,58),(57,52,19,58)]
    default = recolor(base,mask,sets[0])
    assert recolor(base,mask,(0,0,0,0)).tobytes()==base.tobytes()
    # Every player palette ID on every channel must leave all other pixels alone.
    for channel in range(4):
        values = {base.getpixel((x,y))[0] for y in range(base.height)
                  for x in range(base.width) if mask.getpixel((x,y))==COLORS[channel]}
        for index in range(133):
            tint = outfit_color(index)
            for value in values:
                assert all(0<=round(value*tint[c]/255)<=255 for c in range(3))
        indices = [0,0,0,0]; indices[channel]=114
        changed = recolor(base,mask,indices)
        for y in range(base.height):
            for x in range(base.width):
                if mask.getpixel((x,y))!=COLORS[channel]:
                    assert changed.getpixel((x,y))==base.getpixel((x,y))
    for name,im in [('base',base),('mask',mask),('color-preview',default),('native-reference',native_reference),('previous-color-concept',concept)]:
        im.save(args.out/f'{name}.png')
    layers = [('NATIVE_REFERENCE',native_reference,False,False),
              ('PREVIOUS_COLOR_CONCEPT_REFERENCE',concept,False,False),
              ('BASE - edit neutral shading here',base,True,True),
              ('MASK - edit pure yellow red green blue',mask,False,True),
              ('COLOR_PREVIEW_REFERENCE - not auto-updated',default,False,False)]
    write_ase(args.out/f'{args.stem}.aseprite',layers)
    ora_title='Rookwarden male - editable native layers' if args.stem=='rookwarden-male' else f'{args.stem} - editable native layers'
    write_ora(args.out/f'{args.stem}.ora',layers,base,ora_title)
    # Existing legacy encoder/decoder proves all 96 tiles are lossless.
    sys.path.insert(0,str(REPO/'tools'))
    from item_assets import encode_sprite, sprite_image
    tiles = 0
    for image in [base,mask]:
        for y in range(0,image.height,32):
            for x in range(0,image.width,32):
                tile = image.crop((x,y,x+32,y+32))
                spr = b'TEST'+struct.pack('<HI',1,10)+encode_sprite(tile)
                assert sprite_image(spr,1).tobytes()==tile.tobytes()
                tiles += 1
    font = ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',13)
    palette_preview = Image.new('RGB',(640,152),(43,43,43)); draw = ImageDraw.Draw(palette_preview)
    for column,(label,indices) in enumerate(zip([args.default_color_label,'Vinröd','Grön','Violett'],sets)):
        im = recolor(base,mask,indices).crop((0,128,64,192)).resize((128,128),Image.Resampling.NEAREST)
        draw.text((column*160+16,5),label,fill='white',font=font)
        palette_preview.paste(im,(column*160,22),im)
    palette_preview.save(args.out/'color-options-preview.png')
    overview = Image.new('RGB',(1152,540),(43,43,43)); draw = ImageDraw.Draw(overview)
    for col,(label,im) in enumerate([('Grundgrafik',base),('Färgmask',mask),('Färgförhandsvisning',default)]):
        draw.text((col*384+12,5),label,font=font,fill='white')
        zoom = im.resize((384,512),Image.Resampling.NEAREST); overview.paste(zoom,(col*384,26),zoom)
    overview.save(args.out/'layers-overview.png')
    animation = []
    for phase in [0,1,2,1,2,1,2,0]:
        canvas = Image.new('RGB',(320,320),(43,43,43)); draw = ImageDraw.Draw(canvas)
        for row,label in enumerate(['Norr','Öster','Söder','Väster']):
            x,y = (row%2)*160,(row//2)*160
            draw.text((x+8,y+4),label,font=font,fill='white')
            a = default.crop((phase*64,row*64,(phase+1)*64,(row+1)*64)).resize((128,128),Image.Resampling.NEAREST)
            canvas.paste(a,(x,y+20),a)
        animation.append(canvas)
    animation[0].save(args.out/'walking-color-preview.gif',save_all=True,append_images=animation[1:],duration=[1000,220,220,220,220,220,220,800],loop=0,disposal=2)
    metadata = {'status':'editable graphic proposal, not imported','native_canvas':[64,64],
        'sheet_canvas':[192,256],'columns':['idle','step1','step2'],'rows':DIRECTIONS,
        'unscaled_translation_from_48px_reference':[24,24], 'channel_pixels':counts,'fixed_pixels':fixed,
        'default_player_colors':dict(zip(['head','body','legs','feet'],sets[0])),
        'checks':['source alpha unchanged','only neutral grayscale under color masks','fixed pixels byte-identical',
          'pure native mask colors','all 133 palette colors on all 4 channels','per-channel isolation',
          'white tint identity','ASE cels/flags lossless readback','ORA PNG/XML readback',f'{tiles} legacy SPR tiles roundtrip'],
        'preview_note':'Software preview follows local shader multiplication and local palette formula. No native game rendering or outfit import performed.',
        'source':str(args.source),'layers_source':str(args.layers),
        'files':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in args.out.iterdir() if p.is_file() and p.suffix in ['.png','.ora','.aseprite','.gif']}}
    (args.out/'manifest.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'out':str(args.out),'files':len(metadata['files']),'fixed_pixels':fixed,'legacy_tiles':tiles,'status':'PASS'}))


if __name__=='__main__':
    main()
