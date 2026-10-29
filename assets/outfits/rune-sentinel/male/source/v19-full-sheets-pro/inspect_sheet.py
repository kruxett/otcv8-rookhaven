"""Inspect and preview a complete AI sheet; never repaint its source pixels."""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
DIRECTIONS = ['north','east','south','west']
LABELS = ['Norr','Öster','Söder','Väster']
BG = (35,38,43)


def main():
    source = HERE / 'pixellab-pro-original.png'
    art = Image.open(source).convert('RGBA')
    report = {'source_size':list(art.size),
              'source_file_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
              'native_requested_size_matches':art.size == (192,256),
              'artwork_process':'One PixelLab Pro generation with four full reference sheets; no per-facing anchor or hand-painted edits.',
              'alpha_values':sorted(set(art.getchannel('A').getdata()))}
    if art.size != (192,256):
        (HERE / 'inspection.json').write_text(json.dumps(report,indent=2))
        print(json.dumps(report))
        return
    frames = HERE / 'frames'
    frames.mkdir(exist_ok=True)
    font = ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',18)
    board = Image.new('RGB',(672,936),BG)
    draw = ImageDraw.Draw(board)
    idle = Image.new('RGB',(1088,346),BG)
    idle_draw = ImageDraw.Draw(idle)
    report['frames'] = []
    report['walk_phase_differences'] = {}
    for row,direction in enumerate(DIRECTIONS):
        cells=[]
        for phase in range(3):
            box=(phase*64,row*64,phase*64+64,row*64+64)
            cell=art.crop(box)
            cells.append(cell)
            cell.save(frames / f'{direction}-{phase}.png')
            report['frames'].append({'direction':direction,'phase':phase,'bbox':cell.getbbox(),
                                     'opaque_pixels':sum(v>0 for v in cell.getchannel('A').getdata())})
            x=phase*224;y=row*234
            draw.text((x+8,y+5),LABELS[row]+' · '+['stå','gång A','gång B'][phase],font=font,fill='white')
            large=cell.resize((192,192),Image.Resampling.NEAREST)
            board.paste(large,(x+12,y+33),large)
        x=row*272
        idle_draw.text((x+10,8),LABELS[row],font=font,fill='white')
        large=cells[0].resize((256,256),Image.Resampling.NEAREST)
        idle.paste(large,(x+4,35),large)
        idle.paste(cells[0],(x+10,277),cells[0])
        idle_draw.text((x+80,306),'1×',font=font,fill='#adb8c4')
        report['walk_phase_differences'][direction]=sum(cells[1].getpixel((x,y))!=cells[2].getpixel((x,y))for y in range(64)for x in range(64))
        animation=[]
        for phase in [1,2]:
            frame=Image.new('RGB',(64,64),BG)
            frame.paste(cells[phase],(0,0),cells[phase])
            animation.append(frame.resize((256,256),Image.Resampling.NEAREST))
        animation[0].save(HERE / f'{direction}-walk-preview.gif',save_all=True,append_images=animation[1:],duration=180,loop=0)
    board.save(HERE / 'complete-sheet-review.png')
    idle.save(HERE / 'four-directions-review.png')
    report['native_scale_preserved'] = True
    report['source_repainted'] = False
    report['scope'] = 'Generated concept sheet for visual review, not an approved outfit or validated native gait. Frame differences do not establish correct animation.'
    (HERE / 'inspection.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps(report))


if __name__ == '__main__':
    main()
