"""Draw a native 32x32 Magic Quiver from integer geometry.

Match the generated reference's silhouette, gold caps, straps and clasp.
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
outline = "#291a13"
dark = "#4e2a1b"
leather = "#8f482a"
mid = "#b36940"
light = "#df9861"
gold_dark = "#905600"
gold = "#dfa513"
gold_light = "#ffe267"
feather = "#f6f1e9"
feather_shadow = "#bab6ae"
wood = "#b67738"
turquoise_dark = "#145658"
turquoise = "#1ba6a7"
turquoise_light = "#a6efe4"

# Right loop strap is drawn first: the body hides its left attachment. Keep a
# broad transparent hole, and use contiguous two-pixel leather clusters.
d.line([(22, 15), (26, 18), (26, 23), (23, 26), (17, 28), (12, 28)], fill=outline, width=4)
d.line([(23, 16), (25, 19), (25, 23), (22, 26), (17, 28), (12, 28)], fill=leather, width=2)
d.line([(25, 19), (25, 22), (22, 25), (18, 27)], fill=mid, width=1)

# Four arrows fan from the mouth with separate, bright white fletchings. The
# white/grey polygons use hand-chosen native coordinates, not scaled artwork.
arrows = [
    ([(15, 13), (21, 3)], [(18, 1), (20, 1), (21, 3), (20, 5), (18, 7), (17, 5)],
     [(18, 2), (19, 2), (20, 3), (19, 5), (18, 5)], [(17, 5), (18, 5), (19, 4), (18, 6)]),
    ([(18, 14), (24, 5)], [(21, 3), (23, 3), (24, 5), (23, 7), (21, 9), (20, 7)],
     [(21, 4), (22, 4), (23, 5), (22, 7), (21, 7)], [(20, 7), (21, 7), (22, 6), (21, 8)]),
    ([(21, 15), (27, 7)], [(24, 5), (26, 5), (27, 7), (26, 9), (24, 11), (23, 9)],
     [(24, 6), (25, 6), (26, 7), (25, 9), (24, 9)], [(23, 9), (24, 9), (25, 8), (24, 10)]),
    ([(23, 16), (29, 10)], [(27, 8), (29, 8), (30, 10), (29, 12), (27, 14), (26, 12)],
     [(27, 9), (28, 9), (29, 10), (28, 12), (27, 12)], [(26, 12), (27, 12), (28, 11), (27, 13)]),
]
for shaft, plume, white, grey in arrows:
    d.line(shaft, fill=outline, width=3)
    d.line(shaft, fill=wood, width=1)
    d.polygon(plume, fill=outline)
    d.polygon(grey, fill=feather_shadow)
    d.polygon(white, fill=feather)

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

# The mouth and bottom cap are deliberately bold readable gold shapes, a
# defining feature of the supplied concept even at the real 32x32 size.
d.line([(13, 10), (23, 15)], fill=outline, width=5)
d.line([(13, 11), (23, 16)], fill=gold_dark, width=3)
d.line([(13, 10), (23, 15)], fill=gold, width=3)
d.line([(13, 9), (20, 13)], fill=gold_light, width=1)
d.line([(21, 14), (23, 14)], fill=gold_light, width=1)
d.polygon([(5, 26), (7, 26), (13, 29), (12, 30), (9, 30), (5, 29)], fill=outline)
d.polygon([(6, 26), (7, 27), (12, 29), (12, 30), (9, 30), (6, 28)], fill=gold)
d.polygon([(8, 29), (11, 30), (12, 29), (12, 30), (9, 30)], fill=gold_dark)
d.line([(6, 26), (6, 28), (9, 29)], fill=gold_light, width=1)

# Turquoise jewel in a gold frame; no glow, gradients or antialiasing.
d.polygon([(21, 13), (24, 16), (22, 19), (19, 17), (19, 15)], fill=outline)
d.polygon([(21, 14), (23, 16), (22, 18), (20, 17), (20, 15)], fill=gold)
d.line([(21, 14), (20, 15)], fill=gold_light, width=1)
d.polygon([(21, 15), (22, 15), (23, 16), (22, 17), (21, 17), (20, 16)], fill=turquoise_dark)
d.rectangle((21, 15, 22, 16), fill=turquoise)
d.point((21, 15), fill=turquoise_light)

assert im.size == (32, 32)
assert {value for _, value in im.getchannel("A").getcolors(256)} == {0,255}
im.save(asset / "sprite.png")
preview=Image.new("RGBA", (512,256), "#383b3b")
preview.alpha_composite(im.resize((256,256), Image.Resampling.NEAREST), (0,0))
preview.alpha_composite(im,(368,112))
preview.save(asset / "preview.png")
print(json.dumps({"native_size":im.size,"colors":len(im.getcolors(1024)),"path":str(asset/"sprite.png")}))
