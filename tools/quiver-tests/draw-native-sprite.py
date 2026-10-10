"""Draw a native 32x32 Magic Quiver from integer geometry.

Empty opening, indigo leather, aged metal and one cyan rune/gem.
Reference pixels are never loaded, traced automatically or downsampled.
This tool writes only the two artwork PNGs; gameplay definitions stay separate.
"""
from pathlib import Path
import json
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[2]
asset = root / "assets/items/magic-quiver"
asset.mkdir(parents=True, exist_ok=True)
im = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
outline = "#191721"
dark = "#20203b"
leather = "#353559"
mid = "#50517a"
light = "#797aa2"
gold_dark = "#76502b"
gold = "#c49348"
gold_light = "#efcf87"
turquoise_dark = "#14677a"
turquoise = "#37cbd2"
turquoise_light = "#b9f5e9"

# Right loop strap is drawn first: the body hides its left attachment. Keep a
# broad transparent hole, and use contiguous two-pixel leather clusters.
d.line([(22, 15), (26, 18), (26, 23), (23, 26), (17, 28), (12, 28)], fill=outline, width=4)
d.line([(23, 16), (25, 19), (25, 23), (22, 26), (17, 28), (12, 28)], fill=leather, width=2)
d.line([(25, 19), (25, 22), (22, 25), (18, 27)], fill=mid, width=1)

# Long diagonal leather tube, broad highlight on its upper-left face and a
# dark lower-right face. No decorative noise or isolated sparkle pixels.
d.polygon([(14, 10), (24, 15), (15, 28), (12, 30), (5, 28), (5, 25)], fill=outline)
d.polygon([(14, 12), (22, 16), (14, 28), (12, 29), (7, 27), (7, 25)], fill=leather)
d.polygon([(14, 12), (17, 14), (10, 25), (8, 27), (7, 26)], fill=mid)
d.line([(14, 13), (12, 16), (10, 20), (8, 24), (8, 25)], fill=light, width=1)
d.polygon([(20, 15), (22, 16), (14, 28), (12, 29), (11, 27), (15, 21)], fill=dark)

# Two complete leather cross-bindings, rather than a gold line substituting
# for the reference's lower leather band.
for edge, face in [([(12, 16), (19, 21)], [(12, 16), (19, 20)]),
                   ([(7, 24), (14, 28)], [(7, 24), (14, 27)])]:
    d.line(edge, fill=outline, width=3)
    d.line(face, fill=mid, width=2)
    d.line(face, fill=light, width=1)

# Empty dark mouth with aged metal rim; never paint ammunition into artwork.
d.polygon([(13, 7), (16, 7), (25, 12), (26, 14), (24, 17), (21, 17), (11, 11)], fill=outline)
d.polygon([(14, 8), (16, 8), (24, 12), (25, 14), (23, 16), (21, 16), (12, 11)], fill=gold)
d.line([(14, 8), (16, 8), (23, 12)], fill="#c5c5bd", width=1)
d.line([(13, 9), (12, 10), (15, 12)], fill=gold_light, width=1)
d.polygon([(15, 9), (17, 9), (23, 12), (24, 14), (22, 15), (14, 11)], fill="#2b2637")
d.polygon([(16, 10), (18, 10), (22, 12), (23, 14), (21, 14), (15, 11)], fill="#100f19")
d.line([(13, 11), (21, 16), (23, 16)], fill=gold_dark, width=1)
d.line([(14, 12), (20, 15)], fill=gold_light, width=1)
d.point((15, 8), fill="#f0ece0")

# One bright gem and a connected enchanted rune above/left of the count badge.
d.polygon([(20, 15), (23, 17), (22, 20), (19, 18), (19, 16)], fill=outline)
d.polygon([(20, 16), (22, 17), (22, 19), (20, 18)], fill=gold)
d.line([(20, 16), (21, 17), (21, 18)], fill=turquoise_dark, width=2)
d.point((20, 16), fill=turquoise_light)
d.point((21, 17), fill=turquoise)
d.line([(13, 16), (12, 18), (14, 19), (15, 20), (13, 22), (11, 22), (12, 20)], fill=turquoise_dark, width=3)
d.line([(13, 16), (12, 18), (14, 19), (14, 20), (12, 22), (11, 21)], fill=turquoise, width=1)
d.line([(13, 16), (12, 18)], fill=turquoise_light, width=1)
d.point((12, 22), fill=turquoise_light)

# Metal heel and no loose sparkle pixels, transparency haze or antialiasing.
d.polygon([(5, 26), (7, 26), (13, 29), (12, 30), (9, 30), (5, 29)], fill=outline)
d.polygon([(6, 26), (7, 27), (12, 29), (12, 30), (9, 30), (6, 28)], fill=gold)
d.polygon([(8, 29), (11, 30), (12, 29), (12, 30), (9, 30)], fill=gold_dark)
d.line([(6, 26), (6, 28), (9, 29)], fill=gold_light, width=1)
d.point((6, 27), fill="#f0ece0")

# Centre the visible 24x24 artwork inside its native tile. Keep every opaque
# pixel unchanged: inventory, container and shop render this same tile origin.
assert im.getbbox() == (5, 7, 29, 31)
before = im.crop(im.getbbox()).tobytes()
centred = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
centred.alpha_composite(im, (-1, -3))
im = centred
assert im.getbbox() == (4, 4, 28, 28)
assert im.crop(im.getbbox()).tobytes() == before

assert im.size == (32, 32)
assert {value for _, value in im.getchannel("A").getcolors(256)} == {0,255}
im.save(asset / "sprite.png")
preview=Image.new("RGBA", (512,256), "#383b3b")
preview.alpha_composite(im.resize((256,256), Image.Resampling.NEAREST), (0,0))
preview.alpha_composite(im,(368,112))
preview.save(asset / "preview.png")
print(json.dumps({"native_size":im.size,"colors":len(im.getcolors(1024)),"path":str(asset/"sprite.png")}))
