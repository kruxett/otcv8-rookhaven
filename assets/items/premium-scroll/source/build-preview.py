"""Compose draft PixelLab sprites for review, without changing sprite pixels."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
FONT = Path('C:/Windows/Fonts/segoeui.ttf')


def font(size):
    return ImageFont.truetype(str(FONT), size)


board = Image.new('RGB', (840, 420), '#1b1d21')
draw = ImageDraw.Draw(board)
draw.text((26, 15), 'Premium Scroll', font=font(25), fill='#f2e1be')
draw.text((26, 51), 'PixelLab / 32 x 32 px / grafikforslag', font=font(15), fill='#b6b7bc')
checks = []
for index, days in enumerate((30, 60, 90)):
    image = Image.open(HERE / f'pixellab-{days}.png').convert('RGBA')
    assert image.size == (32, 32), (days, image.size)
    alpha = sorted(set(image.getchannel('A').get_flattened_data()))
    assert alpha == [0, 255], (days, alpha)
    checks.append({'days': days, 'size': list(image.size), 'alpha': alpha,
                   'bbox': list(image.getbbox()), 'colors': len(image.getcolors(1024))})
    x = 24 + index * 274
    draw.rounded_rectangle((x, 91, x + 250, 397), radius=8,
                           fill='#282a30', outline='#42434a')
    draw.text((x + 20, 103), f'{days} dagar', font=font(21), fill='#ece5d5')
    enlarged = image.resize((192, 192), Image.Resampling.NEAREST)
    board.paste(enlarged, (x + 29, 140), enlarged)
    draw.text((x + 19, 344), '1:1', font=font(15), fill='#b6b7bc')
    draw.rectangle((x + 56, 339, x + 93, 376), fill='#3b3b3b', outline='#626262')
    board.paste(image, (x + 59, 342), image)
    draw.text((x + 112, 344), 'Ovan: 6x', font=font(15), fill='#b6b7bc')

board.save(ROOT / 'approval-preview.png')
(ROOT / 'sprite-validation.json').write_text(json.dumps(checks, indent=2) + '\n')
print(json.dumps(checks))
