"""Draw the native 32x32 Magic Quiver using integer geometry.

A slim
indigo tube, distinct brown leather loop, gold trim and a connected cyan S.
Reference images are not loaded, traced or resampled into this artwork.
Only the artwork PNGs are written; item definitions remain separate.
"""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[2]
asset = root / "assets/items/magic-quiver"
asset.mkdir(parents=True, exist_ok=True)
im = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
outline = "#191721"
dark = "#161c38"
leather = "#29325c"
mid = "#45568a"
light = "#7386b0"
strap_dark = "#4b2c20"
strap = "#8c5435"
strap_light = "#bc8052"
gold_dark = "#80512a"
gold = "#d2a050"
gold_light = "#f4dc99"
turquoise_dark = "#125a78"
turquoise = "#29d5df"
turquoise_light = "#bdffff"

# Distinct brown loop behind the tube, with the original broad transparent hole.
d.line([(22, 15), (26, 18), (26, 23), (23, 26), (17, 28), (12, 28)], fill=outline, width=4)
d.line([(23, 16), (25, 19), (25, 23), (22, 26), (17, 28), (12, 28)], fill=strap_dark, width=3)
d.line([(23, 16), (25, 19), (25, 23), (22, 26), (17, 28), (12, 28)], fill=strap, width=2)
d.line([(25, 19), (25, 22), (22, 25), (18, 27)], fill=strap_light, width=1)

# Slim continuous diagonal tube. Removing the two pale cross-bindings leaves
# its long face legible instead of dividing it into a triangular bag shape.
d.polygon([(14, 10), (23, 15), (13, 29), (11, 30), (5, 27), (5, 25)], fill=outline)
d.polygon([(14, 12), (21, 16), (12, 28), (11, 29), (7, 27), (6, 25)], fill=leather)
d.polygon([(14, 12), (16, 13), (8, 26), (7, 27), (6, 25)], fill=mid)
d.line([(14, 13), (12, 16), (10, 19), (8, 23), (7, 25)], fill=light, width=1)
d.polygon([(20, 15), (21, 16), (12, 28), (11, 29), (10, 27), (14, 20)], fill=dark)

# Gold rim around an empty dark mouth. No painted ammunition or alpha haze.
d.polygon([(13, 7), (16, 7), (25, 12), (26, 14), (24, 17), (21, 17), (11, 11)], fill=outline)
d.polygon([(14, 8), (16, 8), (24, 12), (25, 14), (23, 16), (21, 16), (12, 11)], fill=gold)
d.line([(14, 8), (16, 8), (23, 12)], fill=gold_light, width=1)
d.line([(13, 9), (12, 10), (15, 12)], fill=gold_light, width=1)
d.polygon([(15, 9), (17, 9), (23, 12), (24, 14), (22, 15), (14, 11)], fill="#2b2637")
d.polygon([(16, 10), (18, 10), (22, 12), (23, 14), (21, 14), (15, 11)], fill="#100f19")
d.line([(13, 11), (21, 16), (23, 16)], fill=gold_dark, width=1)
d.line([(14, 12), (20, 15)], fill=gold_light, width=1)

# Move the gold setting one pixel inward/down from the mouth's edge. A 2x2
# cyan core stays inside its frame rather than replacing the frame's top pixel.
d.polygon([(19, 16), (22, 18), (21, 21), (18, 19), (18, 17)], fill=outline)
d.polygon([(19, 17), (21, 18), (21, 20), (19, 20), (18, 18)], fill=gold)
d.rectangle([(19, 18), (20, 19)], fill=turquoise)
d.point((19, 18), fill=turquoise_light)
d.point((20, 19), fill=turquoise_dark)

# Thin connected 4x7 S: preserve indigo negative gaps between its strokes.
# No broad cyan underpaint or halo; every bright pixel belongs to the rune.
for y, row in enumerate(("0111", "1000", "1000", "0110", "0001", "0001", "1110"), 16):
    for x, filled in enumerate(row, 10):
        if filled == "1":
            d.point((x, y), fill=turquoise)
d.point((11, 16), fill=turquoise_light)
d.point((12, 22), fill=turquoise_light)

# Gold heel follows the slim tube rather than a broad pale diagonal binding.
d.polygon([(5, 25), (7, 25), (13, 28), (12, 30), (10, 30), (5, 27)], fill=outline)
d.polygon([(6, 25), (7, 26), (12, 29), (11, 30), (9, 29), (6, 27)], fill=gold)
d.polygon([(7, 28), (10, 30), (12, 30), (12, 29), (8, 27)], fill=gold_dark)
d.line([(6, 25), (6, 27), (9, 29)], fill=gold_light, width=1)

# Exact integer translation into the same centered native tile. All transparent
# margins remain four pixels; neither the reference nor the sprite is reduced.
assert im.getbbox() == (5, 7, 29, 31), im.getbbox()
before = im.crop(im.getbbox()).tobytes()
centred = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
centred.alpha_composite(im, (-1, -3))
im = centred
assert im.getbbox() == (4, 4, 28, 28)
assert im.crop(im.getbbox()).tobytes() == before
assert im.size == (32, 32)
assert {value for _, value in im.getchannel("A").getcolors(256)} == {0, 255}
im.save(asset / "sprite.png")
preview = Image.new("RGBA", (512, 256), "#383b3b")
preview.alpha_composite(im.resize((256, 256), Image.Resampling.NEAREST), (0, 0))
preview.alpha_composite(im, (368, 112))
preview.save(asset / "preview.png")
print(json.dumps({"native_size": im.size, "bounds": im.getbbox(),
    "colors": len(im.getcolors(1024)), "opaque_pixels": sum(count for count, alpha in im.getchannel('A').getcolors(256) if alpha),
    "sprite_sha256": hashlib.sha256((asset/'sprite.png').read_bytes()).hexdigest(),
    "path": str(asset/'sprite.png')}))
