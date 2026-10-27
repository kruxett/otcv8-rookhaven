"""Package PixelLab's exact sprite frames at the native 8.60 item cadence."""
from pathlib import Path
from PIL import Image, ImageDraw
import hashlib
import json

HERE = Path(__file__).resolve().parent
ASSET = HERE.parent
ROOT = HERE.parents[3]
source = Image.open(ASSET / 'source/pixellab-light-ring.png').convert('RGBA')
sheet = Image.open(HERE / 'pixellab-frames.png').convert('RGBA')
frames, checks = [], []
for index in range(8):
    x, y = index % 3 * 32, index // 3 * 32
    frame = sheet.crop((x, y, x + 32, y + 32))
    assert frame.getchannel('A').tobytes() == source.getchannel('A').tobytes()
    changed = []
    for pixel, (before, after) in enumerate(zip(source.get_flattened_data(), frame.get_flattened_data())):
        if before[3] == after[3] == 0:
            continue
        if before != after:
            assert 10 <= pixel % 32 <= 15 and 11 <= pixel // 32 <= 15
            changed.append(pixel)
    frame.save(HERE / f'frame-{index+1:02}.png')
    frames.append(frame)
    checks.append({'frame': index + 1, 'changed_gem_pixels': len(changed),
                   'silhouette_and_alpha_unchanged': True, 'all_pixels_outside_gem_unchanged': True})

# Explicit palette avoids Pillow's automatic quantizer merging dark outline shades.
colors = sorted({p[:3] for frame in frames for p in frame.get_flattened_data() if p[3]})
assert len(colors) < 256
lookup = {rgb: index + 1 for index, rgb in enumerate(colors)}
palette = [0, 0, 0] + [channel for rgb in colors for channel in rgb]
palette += [0] * (768 - len(palette))
indexed = []
for frame in frames:
    image = Image.new('P', (32, 32))
    image.putpalette(palette)
    image.putdata([lookup[p[:3]] if p[3] else 0 for p in frame.get_flattened_data()])
    image.info['transparency'] = 0
    indexed.append(image)
for scale, name in ((1, 'light-pulse-native.gif'), (6, 'light-pulse-preview.gif')):
    preview = [im.resize((32 * scale, 32 * scale), Image.Resampling.NEAREST) for im in indexed]
    preview[0].save(HERE / name, save_all=True, append_images=preview[1:],
                    duration=500, loop=0, disposal=2, transparency=0, optimize=False)
    gif = Image.open(HERE / name)
    assert gif.n_frames == 8
    for i, frame in enumerate(frames):
        gif.seek(i)
        assert gif.info['duration'] == 500
        expected = frame.resize((32 * scale, 32 * scale), Image.Resampling.NEAREST)
        for actual, pixel in zip(gif.convert('RGBA').get_flattened_data(), expected.get_flattened_data()):
            assert actual == pixel or actual[3] == pixel[3] == 0

board = Image.new('RGB', (576, 296), '#3b3b3b')
draw = ImageDraw.Draw(board)
for index, frame in enumerate(frames):
    x, y = index % 4 * 144, index // 4 * 148
    zoom = frame.resize((128, 128), Image.Resampling.NEAREST)
    board.paste(zoom, (x + 8, y + 2), zoom)
    draw.text((x + 8, y + 131), str(index + 1), fill='#dddddd')
board.save(HERE / 'all-frames-review.png')

proof = json.loads((ROOT / 'assets/items/premium-scroll/verification.json').read_text())
for name in ('Tibia.dat', 'Tibia.spr'):
    key = 'otcv8-rookhaven/data/things/860/' + name
    assert hashlib.sha256((ROOT / 'data/things/860' / name).read_bytes()).hexdigest() == proof['files_sha256'][key]
validation = {'status': 'draft-awaiting-pulse-approval', 'frame_count': 8,
              'duration_per_frame_ms': 500, 'loop_duration_ms': 4000, 'canvas': [32, 32],
              'edit_region_inclusive': [10, 11, 15, 15], 'single_flattened_sprite_frames': True,
              'overlay_layers': False, 'frames': checks, 'all_visible_gif_pixels_roundtrip_exact': True,
              'game_DAT_and_SPR_still_equal_to_completed_scroll_state': True,
              'ingame_implementation_or_equipped_screenshot': 'Not performed; user requested pulse artwork first.'}
(HERE / 'validation.json').write_text(json.dumps(validation, indent=2) + '\n')
print(json.dumps(validation))
