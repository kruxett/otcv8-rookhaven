"""Render original Rookhaven passive pixel grids at native 32x32 resolution.

`--author` regenerates the checked-in original palette grids from the native
pixel primitives below. Default operation renders the grids without resizing.
Preview zoom is nearest-neighbour and is never used as a runtime asset.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "assets/passives/pixel-sources"
OUTPUT = ROOT / "data/images/game/passives"
PREVIEWS = ROOT / "assets/passives/previews"
PALETTE = {
    ".": "#00000000", "o": "#17161bff", "s": "#30353eff",
    "g": "#616c75ff", "i": "#a5b2b3ff", "h": "#e2e0caff",
    "w": "#523725ff", "b": "#967045ff", "y": "#d5b974ff",
    "r": "#4f202cff", "R": "#a53d43ff", "f": "#e77855ff",
    "n": "#293f59ff", "c": "#568aafff", "l": "#a0ced4ff",
    "v": "#78916aff",
}
RGBA = {key: tuple(bytes.fromhex(value[1:])) for key, value in PALETTE.items()}
PURPOSES = {
    "minor_precision": "Axe with target reticle: ordinary axe critical chance.",
    "minor_critical": "Bright steel edge and sparks: critical bonus damage.",
    "minor_power": "Clenched leather gauntlet: direct axe power.",
    "minor_efficiency": "Mana vessel and returning gold arrow: mana efficiency.",
    "minor_vitality": "Living red heart: maximum health.",
    "minor_resilience": "Riveted steel shield and impact: physical resilience.",
    "minor_recovery": "Blood droplet with green shoots: life recovery.",
    "minor_focus": "Blue mana crystal with restrained shimmer: mana recovery.",
    "major_precision": "Watchful eye above axe edge: critical readiness.",
    "major_pressure": "Axe breaking stone: pressure and adjacent impact.",
    "major_guard": "Tall shield with warm central boss: guard and vitality.",
    "major_recovery": "Blood vessel with living leaves: leech and recovery.",
    "major_tactical": "Crossed axe and blue rune: alternating attack and spell.",
    "major_steady": "Steadfast helm in green wreath: endurance at low health.",
    "cap_berserker": "Horned battle mask and paired axes: rage phase.",
    "cap_bloodletting": "Three bleeding cuts on steel: three owned wound stacks.",
    "cap_bloodguard": "Steel shield with blood-red heart: damage-built ward.",
    "reaver": "Single axe with bronze binding: standalone test-tree emblem.",
}
BASE_NODE_IDS = tuple(identifier for identifier in PURPOSES
                      if identifier.startswith(("minor_", "major_")))
TREE_SPECS = {
    "blademaster": ("sword", ["duelist", "riposte", "bladestorm"]),
    "earthshaker": ("club", ["aftershock", "stoneguard", "stonebond"]),
    "marksman": ("bow", ["deadeye", "skirmisher", "quarry"]),
    "arcanist": ("wand", ["conduit", "resonance", "spellweaver"]),
    "lifekeeper": ("rod", ["renewal", "aegis", "concord"]),
}
CAP_PURPOSES = {
    "duelist": "Sword and finishing target: a prepared single-target finisher.",
    "riposte": "Shield and returning blade: a prepared counterattack.",
    "bladestorm": "Crossed blades inside an angular sweep: an area sword attack.",
    "aftershock": "Heavy club impact and spreading stone rings: an aftershock.",
    "stoneguard": "Layered stone wall and steel boss: a protective guard.",
    "stonebond": "Three linked shields: damage sharing with a nearby party member.",
    "deadeye": "Watchful eye and a focused arrow: a prepared accurate shot.",
    "skirmisher": "Arrow bouncing between three targets: nearby-target bounces.",
    "quarry": "Marked beast and converging signs: a marked party-hunt target.",
    "conduit": "Blue lightning joining three orbs: a bounded lightning chain.",
    "resonance": "Blue central rune and echoing arcs: spell resonance.",
    "spellweaver": "Three elemental threads tied at a gold rune: spell weaving.",
    "renewal": "Living leaves, warm heart and a returning arc: healing over time.",
    "aegis": "Blue steel shield and healing cross: a healing-created shield.",
    "concord": "Three linked party hands around a living heart: party support.",
}
TREE_ICONS = {"reaver": list(PURPOSES)}
for tree, (weapon, caps) in TREE_SPECS.items():
    for identifier in BASE_NODE_IDS:
        PURPOSES[f"{tree}_{identifier}"] = (tree.title() + ": " + PURPOSES[identifier]
            .replace("Axe", weapon.title()).replace("axe", weapon))
    for cap in caps:
        PURPOSES[f"cap_{cap}"] = CAP_PURPOSES[cap]
    PURPOSES[tree] = f"Single {weapon} with its native material accents: {tree} tree emblem."
    TREE_ICONS[tree] = [f"{tree}_{identifier}" for identifier in BASE_NODE_IDS]
    TREE_ICONS[tree] += [f"cap_{cap}" for cap in caps] + [tree]
PURPOSES["lifekeeper_minor_precision"] = "Open mending hands and a living heart: additional direct healing."
PURPOSES["lifekeeper_minor_critical"] = "A pale flower and green leaves: stronger direct healing."
PURPOSES["lifekeeper_major_precision"] = "A mending hand and a rod: healing readiness."


class Pixels:
    def __init__(self):
        self.image = Image.new("RGBA", (32, 32), RGBA["."])
        self.draw = ImageDraw.Draw(self.image)

    def polygon(self, points, fill, outline="o"):
        self.draw.polygon(points, fill=RGBA[fill], outline=RGBA[outline])

    def rect(self, box, fill, outline=None):
        self.draw.rectangle(box, fill=RGBA[fill], outline=RGBA[outline] if outline else None)

    def line(self, points, fill, width=1):
        self.draw.line(points, fill=RGBA[fill], width=width)

    def dot(self, x, y, fill):
        self.draw.point((x, y), fill=RGBA[fill])

    def axe(self, dx=0, dy=0, facing=1):
        def p(x, y):
            return ((31 - x if facing < 0 else x) + dx, y + dy)
        self.line([p(7, 26), p(23, 7)], "o", 5)
        self.line([p(7, 26), p(23, 7)], "w", 3)
        self.line([p(8, 25), p(23, 8)], "b")
        self.polygon([p(16, 5), p(20, 3), p(28, 9), p(27, 15), p(22, 19), p(18, 15), p(19, 10)], "g")
        self.polygon([p(20, 4), p(27, 9), p(26, 14), p(23, 17), p(22, 12)], "i")
        self.line([p(21, 5), p(26, 9), p(25, 14), p(23, 16)], "h")
        self.line([p(18, 8), p(22, 12)], "s", 2)
        self.line([p(15, 16), p(18, 18)], "y", 2)
        self.line([p(8, 24), p(10, 26)], "s", 2)

    def shield(self, center=16, top=4, fill="g"):
        self.polygon([(center-9, top+2), (center, top), (center+9, top+2),
                      (center+8, top+14), (center+4, top+20),
                      (center, top+24), (center-5, top+20), (center-8, top+14)], fill)
        self.line([(center-8,top+3),(center,top+1),(center+8,top+3),(center+7,top+14)], "i")
        self.line([(center-7,top+4),(center-6,top+14),(center-3,top+19)], "s", 2)
        self.line([(center+6,top+5),(center+5,top+14),(center+2,top+20)], "h")
        for x, y in [(center-5,top+5),(center+5,top+5),(center-4,top+15),(center+4,top+15)]:
            self.dot(x,y,"y")

    def heart(self, x=16, y=16, small=False):
        if small:
            self.polygon([(x-5,y-3),(x-3,y-5),(x,y-3),(x+3,y-5),(x+5,y-3),
                          (x+5,y),(x,y+6),(x-5,y)], "R")
            self.line([(x-3,y-3),(x-2,y-3),(x-2,y-2)], "f")
            self.line([(x-3,y+1),(x,y+4)], "r")
        else:
            self.polygon([(4,11),(7,6),(11,5),(16,9),(21,5),(25,6),(28,11),
                          (27,17),(22,23),(16,28),(9,23),(5,17)], "r")
            self.polygon([(6,11),(9,7),(12,7),(16,12),(21,7),(24,8),(26,12),
                          (25,17),(21,21),(16,25),(10,20)], "R", "R")
            self.line([(8,12),(10,9),(12,9)], "f", 2)
            self.line([(21,9),(23,10),(24,12)], "f")
            self.line([(8,17),(11,21),(16,25)], "o")

    def drop(self, x=16, y=15, radius=7):
        self.polygon([(x,y-radius-4),(x+radius-1,y-1),(x+radius,y+3),
                      (x+radius-2,y+7),(x,y+9),(x-radius+2,y+7),
                      (x-radius,y+3),(x-radius+1,y-1)], "r")
        self.polygon([(x,y-radius-1),(x+radius-2,y),(x+radius-2,y+4),
                      (x,y+7),(x-radius+2,y+4),(x-radius+2,y)], "R", "R")
        self.line([(x-2,y-1),(x-3,y+2),(x-2,y+4)], "f", 2)
        self.dot(x-1,y-3,"h")

    def leaf(self, points):
        self.polygon(points,"v")

    def spark(self, x, y, fill="y"):
        self.line([(x,y-2),(x,y+2)],fill)
        self.line([(x-2,y),(x+2,y)],fill)
        self.dot(x,y,"h")

    def ellipse(self, box, fill=None, outline="o", width=1):
        self.draw.ellipse(box, fill=RGBA[fill] if fill else None,
                          outline=RGBA[outline], width=width)

    def sword(self, facing=1):
        def p(x, y):
            return (31 - x if facing < 0 else x, y)
        self.line([p(6,27),p(13,20)],"o",5)
        self.line([p(6,27),p(13,20)],"w",3)
        self.line([p(7,26),p(12,21)],"b")
        self.polygon([p(12,19),p(22,4),p(27,3),p(28,7),p(16,22)],"g")
        self.polygon([p(14,19),p(24,5),p(27,4),p(26,8),p(16,21)],"i","i")
        self.line([p(15,19),p(25,5)],"h")
        self.line([p(9,18),p(17,25)],"o",4)
        self.line([p(10,19),p(16,24)],"b",2)
        self.dot(*p(11,19),"y"); self.dot(*p(16,23),"y")
        self.rect((4 if facing>0 else 24,26,7 if facing>0 else 27,29),"g","o")

    def club(self):
        self.line([(6,27),(21,10)],"o",5)
        self.line([(6,27),(21,10)],"w",3)
        self.line([(7,26),(21,11)],"b")
        self.polygon([(18,3),(25,3),(29,8),(28,14),(23,19),(18,17),(15,12),(16,7)],"s")
        self.polygon([(19,5),(24,5),(27,9),(26,13),(22,16),(19,14),(17,10)],"g","g")
        self.line([(20,5),(24,6),(27,10)],"i")
        self.line([(18,9),(23,14)],"o",2)
        self.line([(17,11),(20,14)],"b",2)
        self.line([(22,6),(25,9)],"y")
        self.line([(7,24),(10,27)],"g",2)

    def bow(self):
        self.line([(14,4),(8,8),(5,15),(7,22),(14,27)],"o",5)
        self.line([(14,4),(8,8),(5,15),(7,22),(14,27)],"w",3)
        self.line([(13,5),(9,9),(7,16),(9,22),(13,26)],"b")
        self.line([(14,4),(14,28)],"i")
        self.line([(7,25),(27,5)],"o",3)
        self.line([(7,25),(26,6)],"b")
        self.polygon([(21,5),(27,4),(27,10),(25,8)],"g")
        self.line([(23,6),(26,5),(26,8)],"h")
        self.line([(6,23),(9,26)],"i",2)
        self.line([(8,21),(11,24)],"i",2)
        self.dot(10,10,"y");self.dot(9,21,"y")

    def wand(self):
        self.line([(6,27),(22,10)],"o",5)
        self.line([(6,27),(22,10)],"w",3)
        self.line([(7,26),(22,11)],"b")
        self.polygon([(17,5),(23,3),(28,7),(27,12),(23,16),(17,13),(15,9)],"n")
        self.polygon([(18,6),(22,4),(26,8),(25,12),(22,14),(18,12),(17,9)],"c","c")
        self.polygon([(22,5),(25,8),(23,10),(20,8)],"l","l")
        self.line([(18,7),(18,10),(20,12)],"h")
        self.line([(17,13),(20,16),(24,15)],"y",2)
        self.line([(8,24),(10,26)],"i",2)

    def rod(self):
        self.line([(7,27),(21,10)],"o",5)
        self.line([(7,27),(21,10)],"w",3)
        self.line([(8,26),(21,11)],"b")
        self.polygon([(18,4),(24,3),(28,7),(27,12),(23,16),(18,14),(15,9)],"w")
        self.polygon([(19,5),(23,4),(26,8),(25,12),(22,14),(18,11)],"v","v")
        self.line([(20,6),(23,6),(24,8)],"h")
        self.line([(17,12),(19,15),(24,15)],"b",2)
        self.leaf([(16,8),(15,4),(19,3),(19,6)])
        self.leaf([(25,14),(27,10),(29,12),(28,17)])
        self.line([(9,23),(12,25)],"y",2)

    def weapon(self, kind):
        getattr(self,kind)()

    def target(self, x=7, y=9):
        self.ellipse((x-4,y-4,x+4,y+4),"r","o")
        self.line([(x-3,y),(x+3,y)],"R")
        self.line([(x,y-3),(x,y+3)],"R")
        self.dot(x,y,"h")

    def eye(self):
        self.polygon([(3,9),(8,5),(15,3),(22,5),(28,9),(23,13),(15,15),(8,13)],"s")
        self.polygon([(5,9),(10,7),(15,5),(21,7),(26,9),(21,11),(15,13),(10,11)],"i")
        self.polygon([(13,6),(17,6),(19,9),(17,12),(13,12),(11,9)],"y")
        self.rect((14,7,16,11),"o");self.dot(14,7,"h")

    def small_shield(self, x, y, fill="g"):
        self.polygon([(x-5,y),(x,y-2),(x+5,y),(x+4,y+7),(x,y+12),(x-4,y+7)],fill)
        self.line([(x-4,y+1),(x,y-1),(x+4,y+1),(x+3,y+6)],"i")
        self.line([(x,y+1),(x,y+8)],"y")

    def mending_hands(self):
        self.polygon([(3,18),(6,15),(10,18),(13,19),(15,23),(13,27),(8,27),(3,22)],"w")
        self.polygon([(28,18),(25,15),(21,18),(18,19),(16,23),(18,27),(23,27),(28,22)],"w")
        self.line([(5,19),(9,21),(12,21),(13,23)],"y",2)
        self.line([(26,19),(22,21),(19,21),(18,23)],"y",2)
        self.heart(16,10,True)
        self.leaf([(10,12),(7,9),(5,10),(7,14)])
        self.leaf([(22,12),(25,9),(27,10),(25,14)])


def copy_pixels(source):
    p=Pixels();p.image=source.image.copy();p.draw=ImageDraw.Draw(p.image)
    return p


def author_other_trees(icons):
    for tree,(weapon,_) in TREE_SPECS.items():
        for identifier in BASE_NODE_IDS:
            icons[f"{tree}_{identifier}"]=copy_pixels(icons[identifier])
        p=Pixels();p.weapon(weapon);p.target();icons[f"{tree}_minor_precision"]=p
        p=Pixels();p.weapon(weapon);p.spark(6,6);p.spark(9,14,"h")
        icons[f"{tree}_minor_critical"]=p
        p=Pixels();p.weapon(weapon);p.spark(23,25);p.line([(17,27),(21,29),(25,28)],"b")
        icons[f"{tree}_minor_power"]=p
        p=Pixels();p.weapon(weapon);p.eye();icons[f"{tree}_major_precision"]=p
        p=Pixels();p.polygon([(3,25),(6,22),(13,22),(17,25),(26,23),(29,28),(3,28)],"s")
        p.weapon(weapon);p.line([(12,26),(16,23),(21,26)],"o");p.spark(25,24)
        icons[f"{tree}_major_pressure"]=p
        p=Pixels();p.polygon([(6,6),(11,4),(17,7),(20,16),(15,24),(8,26),(3,19)],"n")
        p.line([(7,9),(11,7),(15,10),(12,14),(7,15),(10,20),(14,18)],"c",2)
        p.weapon(weapon);p.line([(13,25),(20,27),(27,25)],"y")
        icons[f"{tree}_major_tactical"]=p
        p=Pixels();p.weapon(weapon);icons[tree]=p
    p=Pixels();p.mending_hands();icons["lifekeeper_minor_precision"]=p
    p=Pixels();p.line([(16,14),(16,28)],"w",3)
    p.line([(16,15),(16,28)],"v")
    p.leaf([(15,22),(9,18),(7,20),(10,25),(15,26)])
    p.leaf([(17,20),(22,16),(25,18),(23,22),(17,24)])
    for x,y in [(16,5),(11,9),(21,9),(12,14),(20,14)]:
        p.polygon([(x,y-2),(x+3,y),(x+2,y+3),(x-2,y+3),(x-3,y)],"i")
        p.dot(x,y,"h")
    p.ellipse((13,9,19,15),"y","w");p.dot(16,11,"h")
    icons["lifekeeper_minor_critical"]=p
    p=Pixels();p.rod();p.polygon([(3,19),(5,15),(9,16),(11,21),(9,27),(4,28)],"w")
    p.line([(5,18),(7,21),(9,21)],"y",2);p.heart(12,12,True)
    icons["lifekeeper_major_precision"]=p

    p=Pixels();p.target(23,10);p.sword()
    p.line([(3,16),(6,13),(9,13)],"y",2);p.line([(3,21),(6,18),(9,18)],"y",2)
    p.spark(25,13,"R");icons["cap_duelist"]=p
    p=Pixels();p.shield(11,3,"s")
    p.polygon([(24,4),(28,8),(24,21),(21,19),(21,10)],"g")
    p.line([(24,6),(25,9),(22,18)],"h")
    p.line([(18,19),(27,22)],"b",3);p.line([(21,20),(19,27)],"w",3)
    p.line([(17,4),(22,3),(27,5)],"y")
    p.polygon([(24,3),(28,5),(25,8)],"y")
    icons["cap_riposte"]=p
    p=Pixels();p.line([(5,13),(3,8),(8,3),(16,2),(25,5),(28,12)],"b",2)
    p.line([(27,19),(28,25),(22,29),(13,29),(5,25),(3,20)],"b",2)
    p.sword();p.sword(-1);p.spark(16,15)
    icons["cap_bladestorm"]=p

    p=Pixels();p.ellipse((3,20,28,28),None,"g");p.ellipse((8,22,23,27),None,"i")
    p.rect((13,8,18,23),"w","o");p.line([(14,11),(14,21)],"b")
    p.polygon([(10,3),(21,3),(24,7),(21,13),(10,13),(7,7)],"s")
    p.polygon([(11,4),(20,4),(22,7),(20,10),(11,10),(9,7)],"g","g")
    p.line([(12,5),(20,5)],"i");p.spark(16,23)
    p.polygon([(4,17),(7,15),(9,18),(7,20)],"g")
    p.polygon([(24,16),(27,15),(29,18),(27,20)],"g")
    icons["cap_aftershock"]=p
    p=Pixels();p.polygon([(4,7),(8,4),(24,4),(28,7),(27,28),(5,28)],"s")
    for box in [(5,7,12,12),(14,6,25,12),(6,14,18,19),(20,14,26,19),(6,21,13,26),(15,21,25,26)]:
        p.rect(box,"g","o");p.line([(box[0]+1,box[1]+1),(box[2]-1,box[1]+1)],"i")
    p.small_shield(16,11,"s");icons["cap_stoneguard"]=p
    p=Pixels();p.line([(7,13),(16,21),(24,13)],"o",5)
    p.line([(7,13),(16,21),(24,13)],"b",3)
    p.small_shield(7,7,"s");p.small_shield(24,7,"s");p.small_shield(16,14,"g")
    p.dot(11,18,"y");p.dot(21,18,"y");icons["cap_stonebond"]=p

    p=Pixels();p.ellipse((12,12,27,27),None,"r",2)
    p.line([(4,27),(26,7)],"o",3);p.line([(4,27),(26,7)],"b")
    p.polygon([(22,5),(28,4),(27,10)],"g");p.line([(24,6),(27,5),(26,8)],"h")
    p.polygon([(3,8),(7,4),(12,4),(17,8),(12,12),(7,12)],"i")
    p.ellipse((7,5,12,11),"y","o");p.rect((9,6,10,10),"o")
    p.dot(9,6,"h");icons["cap_deadeye"]=p
    p=Pixels()
    for x,y in [(6,23),(16,7),(26,22)]:
        p.polygon([(x,y-4),(x+3,y),(x,y+4),(x-3,y)],"r")
        p.dot(x,y,"R")
    p.line([(7,23),(11,14),(16,10)],"o",4);p.line([(7,23),(11,14),(16,10)],"y",2)
    p.polygon([(12,10),(17,9),(17,14)],"i")
    p.line([(18,10),(23,14),(25,20)],"o",4);p.line([(18,10),(23,14),(25,20)],"y",2)
    p.polygon([(22,18),(27,21),(23,24)],"i")
    p.line([(3,19),(5,17),(7,18)],"c");icons["cap_skirmisher"]=p
    p=Pixels();p.polygon([(8,10),(5,5),(11,6),(14,9),(19,9),(23,5),(27,5),(24,12),
        (25,20),(21,26),(16,29),(10,25),(7,20)],"r")
    p.polygon([(10,12),(15,10),(20,11),(23,15),(21,21),(17,25),(12,23),(9,18)],"R","R")
    p.rect((10,15,13,16),"o");p.rect((20,15,23,16),"o")
    p.line([(3,10),(3,3),(10,3)],"y");p.line([(21,3),(28,3),(28,10)],"y")
    p.line([(3,21),(3,28),(10,28)],"y");p.line([(21,28),(28,28),(28,21)],"y")
    p.line([(15,17),(16,21),(18,21)],"h");icons["cap_quarry"]=p

    p=Pixels();p.line([(6,9),(13,12),(10,17),(18,17),(15,23),(25,10)],"o",5)
    p.line([(6,9),(13,12),(10,17),(18,17),(15,23),(25,10)],"c",3)
    p.line([(7,9),(12,12),(10,16),(17,16),(15,22),(25,10)],"l")
    for x,y in [(5,8),(16,24),(26,8)]:
        p.ellipse((x-3,y-3,x+3,y+3),"n","o")
        p.ellipse((x-2,y-2,x+2,y+2),"c","c");p.dot(x-1,y-1,"h")
    icons["cap_conduit"]=p
    p=Pixels();p.line([(8,5),(4,10),(3,17),(6,25),(10,28)],"n",3)
    p.line([(8,6),(5,11),(5,18),(8,25)],"c")
    p.line([(23,5),(27,10),(28,17),(25,25),(21,28)],"n",3)
    p.line([(23,6),(26,11),(26,18),(23,25)],"c")
    p.line([(10,10),(8,15),(9,21)],"l");p.line([(21,10),(23,15),(22,21)],"l")
    p.polygon([(16,4),(20,10),(19,23),(16,28),(12,23),(11,11)],"n")
    p.line([(15,8),(17,12),(14,16),(18,18),(15,23)],"y",2)
    p.dot(15,10,"h");icons["cap_resonance"]=p
    p=Pixels();p.line([(7,9),(12,17),(24,26)],"r",4)
    p.line([(7,9),(12,17),(24,26)],"R",2)
    p.line([(16,6),(16,19),(11,27)],"n",4);p.line([(16,6),(16,19),(11,27)],"c",2)
    p.line([(25,9),(20,17),(7,26)],"o",4);p.line([(25,9),(20,17),(7,26)],"v",2)
    for x,y,color in [(7,6,"R"),(16,4,"c"),(25,6,"v")]:
        p.polygon([(x,y-2),(x+3,y),(x+2,y+4),(x-2,y+4),(x-3,y)],color)
        p.dot(x,y,"h")
    p.polygon([(16,14),(20,18),(16,23),(12,18)],"b")
    p.line([(16,16),(18,18),(16,21),(14,18),(16,16)],"y")
    icons["cap_spellweaver"]=p

    p=Pixels();p.leaf([(4,20),(3,12),(8,7),(11,12),(8,20)])
    p.leaf([(23,20),(21,12),(25,7),(29,12),(28,20)])
    p.line([(7,17),(11,25),(20,25),(26,17)],"v",2)
    p.heart(16,13,True);p.line([(8,5),(15,3),(23,5)],"y")
    p.polygon([(21,3),(26,5),(22,8)],"y");p.spark(16,26,"h")
    icons["cap_renewal"]=p
    p=Pixels();p.shield(16,3,"s")
    p.polygon([(10,8),(16,6),(22,8),(22,18),(16,25),(10,18)],"n")
    p.line([(11,9),(16,7),(21,9)],"c")
    p.rect((14,10,18,21),"v","o");p.rect((11,13,21,17),"v","o")
    p.line([(15,11),(15,20)],"h");p.line([(12,14),(20,14)],"h")
    p.spark(5,8,"c");p.spark(27,8,"c");icons["cap_aegis"]=p
    p=Pixels();p.mending_hands()
    p.polygon([(12,24),(11,21),(13,18),(16,20),(19,18),(21,21),
               (20,25),(17,29),(14,28)],"w")
    p.line([(13,21),(15,24),(18,24),(19,21)],"y",2)
    p.line([(14,26),(18,26),(17,28)],"b",2)
    p.line([(5,12),(3,8),(7,4),(11,6)],"b",2)
    p.line([(20,6),(25,4),(28,8),(27,12)],"b",2)
    p.line([(5,13),(8,15)],"y");p.line([(26,13),(23,15)],"y")
    p.heart(16,8,True);icons["cap_concord"]=p


def author_icons():
    icons = {}
    p = Pixels(); p.axe(-2, 1)
    p.polygon([(21,3),(27,3),(29,5),(29,11),(27,13),(21,13),(19,11),(19,5)],"r")
    p.line([(20,8),(28,8)],"R"); p.line([(24,4),(24,12)],"R")
    p.rect((23,7,25,9),"h"); icons["minor_precision"] = p

    p=Pixels(); p.axe(-1,1); p.line([(21,6),(27,10),(26,15),(23,18)],"y")
    p.spark(7,8); p.spark(11,5); p.line([(24,21),(27,24)],"y")
    icons["minor_critical"]=p

    p=Pixels(); p.line([(5,25),(26,6)],"o",5); p.line([(5,25),(26,6)],"w",3)
    p.polygon([(7,14),(10,10),(14,9),(17,7),(22,8),(25,11),(24,17),
               (21,22),(15,25),(8,21)],"w")
    p.polygon([(10,14),(11,11),(15,11),(16,9),(20,9),(23,12),(22,16),(18,20),(12,20)],"b")
    p.line([(11,13),(15,14),(16,11),(20,12),(21,15)],"y")
    p.line([(12,11),(12,14)],"w"); p.line([(17,10),(17,14)],"w")
    p.line([(21,11),(21,14)],"w"); p.line([(9,16),(12,17),(14,20)],"w")
    p.line([(10,16),(15,18),(20,17)],"w",2); p.rect((9,20,15,23),"s","o")
    p.line([(10,21),(14,22)],"i"); icons["minor_power"]=p

    p=Pixels(); p.rect((12,4,19,7),"b","o"); p.rect((13,5,18,5),"y")
    p.polygon([(12,8),(19,8),(19,12),(24,16),(23,25),(20,28),(11,28),(8,25),(7,16),(12,12)],"n")
    p.polygon([(9,18),(22,18),(21,25),(18,27),(12,26),(9,23)],"c","c")
    p.line([(11,16),(10,21),(12,24)],"l"); p.line([(4,14),(4,8),(8,5)],"y",2)
    p.polygon([(6,4),(9,4),(9,8)],"y"); p.line([(27,18),(27,24),(24,27)],"y")
    icons["minor_efficiency"]=p

    p=Pixels(); p.heart(); icons["minor_vitality"]=p

    p=Pixels(); p.shield(14,3); p.spark(26,13,"h")
    p.line([(22,5),(26,8)],"y"); p.line([(24,23),(28,25)],"y")
    p.line([(13,8),(13,18)],"i"); icons["minor_resilience"]=p

    p=Pixels(); p.drop(16,13,6)
    p.leaf([(5,23),(4,17),(8,18),(11,22),(10,25)])
    p.leaf([(22,24),(23,18),(28,17),(27,23)])
    p.line([(7,20),(13,27),(20,27),(25,20)],"v")
    icons["minor_recovery"]=p

    p=Pixels(); p.polygon([(15,4),(22,10),(24,22),(16,28),(7,23),(9,11)],"n")
    p.polygon([(15,5),(16,15),(9,22),(10,11)],"c")
    p.polygon([(16,6),(21,11),(22,21),(17,15)],"l")
    p.polygon([(17,17),(21,22),(16,26),(11,23)],"c")
    p.line([(15,7),(15,14),(10,21)],"h"); p.spark(26,7,"c"); p.spark(5,15,"c")
    icons["minor_focus"]=p

    p=Pixels(); p.line([(6,27),(24,12)],"o",5); p.line([(6,27),(24,12)],"w",3)
    p.polygon([(17,14),(22,12),(28,17),(25,23),(19,25),(15,22),(20,18)],"g")
    p.line([(23,14),(27,17),(24,22),(20,24)],"h")
    p.polygon([(3,9),(8,5),(15,3),(22,5),(28,9),(23,13),(15,15),(8,13)],"s")
    p.polygon([(5,9),(10,7),(15,5),(21,7),(26,9),(21,11),(15,13),(10,11)],"i")
    p.polygon([(13,6),(17,6),(19,9),(17,12),(13,12),(11,9)],"y")
    p.rect((14,7,16,11),"o"); p.dot(14,7,"h"); icons["major_precision"]=p

    p=Pixels(); p.polygon([(3,25),(6,21),(12,21),(16,24),(26,23),(29,28),(3,28)],"s")
    p.line([(5,24),(11,23),(15,25),(24,25)],"g")
    p.axe(-2,-1); p.line([(13,24),(17,22),(21,24),(24,23)],"o")
    p.polygon([(3,18),(5,15),(8,17),(6,20)],"g"); p.polygon([(24,20),(27,17),(29,20),(27,22)],"g")
    p.spark(21,24); icons["major_pressure"]=p

    p=Pixels(); p.shield(16,3); p.polygon([(12,11),(16,8),(20,11),(20,17),(16,21),(12,17)],"b")
    p.polygon([(14,12),(16,10),(18,12),(18,16),(16,19),(14,16)],"y")
    p.line([(16,12),(16,17)],"h"); icons["major_guard"]=p

    p=Pixels(); p.polygon([(10,9),(21,9),(22,15),(24,19),(23,26),(20,28),(11,28),(8,25),(8,19),(10,15)],"w")
    p.rect((10,6,21,10),"g","o"); p.line([(11,7),(20,7)],"i")
    p.polygon([(11,17),(20,17),(22,20),(20,25),(12,25),(10,21)],"r")
    p.heart(16,20,True); p.leaf([(6,16),(3,11),(4,5),(9,8),(10,12)])
    p.leaf([(23,14),(23,8),(27,4),(29,10),(27,14)])
    p.line([(6,9),(10,17)],"v"); p.line([(27,8),(22,19)],"v")
    icons["major_recovery"]=p

    p=Pixels(); p.polygon([(6,6),(11,4),(17,7),(20,16),(15,24),(8,26),(3,19)],"n")
    p.line([(7,9),(11,7),(15,10),(12,14),(7,15),(10,20),(14,18)],"c",2)
    p.dot(11,8,"l"); p.axe(1,0); p.line([(13,25),(20,27),(27,25)],"y")
    p.polygon([(25,24),(28,24),(27,28)],"y"); icons["major_tactical"]=p

    p=Pixels(); p.leaf([(5,22),(3,17),(4,11),(7,12),(8,18)])
    p.leaf([(5,12),(5,7),(9,4),(11,8),(8,13)])
    p.leaf([(24,13),(21,8),(23,4),(27,7),(27,12)])
    p.leaf([(25,23),(23,18),(25,12),(28,11),(29,17)])
    p.polygon([(10,8),(14,5),(19,5),(23,9),(24,18),(21,25),(16,28),(10,24),(8,17)],"g")
    p.polygon([(11,10),(15,7),(19,7),(21,10),(21,19),(17,24),(12,20)],"i")
    p.rect((10,13,21,16),"s","o"); p.line([(11,14),(14,14)],"o")
    p.line([(18,14),(20,14)],"o"); p.line([(16,9),(16,23)],"y")
    p.line([(11,22),(14,25)],"s"); icons["major_steady"]=p

    p=Pixels(); p.line([(4,26),(26,7)],"o",4); p.line([(4,26),(26,7)],"b",2)
    p.line([(27,26),(5,7)],"o",4); p.line([(27,26),(5,7)],"b",2)
    p.polygon([(3,3),(8,4),(11,9),(7,13),(3,12)],"g")
    p.line([(4,4),(7,5),(9,8)],"h")
    p.polygon([(28,3),(23,4),(20,9),(24,13),(28,12)],"g")
    p.line([(27,4),(24,5),(22,8)],"h")
    p.polygon([(7,10),(6,5),(10,7),(12,11),(20,11),(22,7),(26,5),(24,11),
               (25,20),(22,26),(17,29),(11,26),(8,20)],"r")
    p.polygon([(10,12),(14,10),(19,10),(23,13),(22,21),(18,26),(13,25),(10,20)],"R")
    p.line([(9,9),(7,7)],"y"); p.line([(23,9),(25,7)],"y")
    p.polygon([(11,16),(15,17),(14,19),(11,18)],"o")
    p.polygon([(18,17),(22,16),(22,18),(19,19)],"o")
    p.dot(12,17,"y"); p.dot(21,17,"y")
    p.line([(16,13),(16,20)],"f"); p.rect((13,23,20,24),"o")
    p.line([(14,23),(14,24)],"h"); p.line([(18,23),(18,24)],"h")
    icons["cap_berserker"]=p

    p=Pixels(); p.polygon([(8,4),(24,4),(28,9),(26,24),(22,28),(5,26),(3,17)],"s")
    p.polygon([(9,6),(23,6),(26,10),(24,23),(21,26),(7,24),(5,17)],"g")
    p.line([(9,7),(22,7),(25,10)],"i")
    for x,y in [(9,13),(14,14),(19,15)]:
        p.line([(x+2,y-5),(x-2,y+4)],"o",3)
        p.line([(x+2,y-4),(x-1,y+3)],"R",2)
        p.line([(x+3,y-3),(x,y+4)],"f")
        p.polygon([(x-1,y+4),(x+1,y+7),(x,y+9),(x-3,y+8),(x-3,y+6)],"R")
        p.dot(x-2,y+7,"f")
    icons["cap_bloodletting"]=p

    p=Pixels(); p.shield(16,3,"s"); p.polygon([(10,8),(16,6),(22,8),(22,18),(16,25),(10,18)],"r")
    p.line([(11,9),(16,7),(21,9)],"R"); p.heart(16,15,True)
    p.line([(4,11),(3,17),(6,24)],"y"); p.line([(28,11),(29,17),(26,24)],"y")
    p.spark(5,8,"R"); p.spark(27,8,"R"); icons["cap_bloodguard"]=p

    p=Pixels(); p.axe(); p.line([(4,28),(13,28)],"b")
    p.dot(5,27,"y"); p.dot(12,27,"y"); icons["reaver"]=p
    author_other_trees(icons)
    SOURCES.mkdir(parents=True,exist_ok=True)
    reverse = {rgba:key for key,rgba in RGBA.items()}
    for identifier,p in icons.items():
        rows = ["".join(reverse[p.image.getpixel((x,y))] for x in range(32)) for y in range(32)]
        used = sorted(set("".join(rows)))
        document={"id":identifier,"width":32,"height":32,"purpose":PURPOSES[identifier],
                  "palette":{key:PALETTE[key] for key in used},"rows":rows}
        (SOURCES / f"{identifier}.json").write_text(json.dumps(document,indent=2)+"\n",encoding="utf-8")


def render():
    OUTPUT.mkdir(parents=True,exist_ok=True)
    records=[]; images={}
    for identifier,purpose in PURPOSES.items():
        source=SOURCES / f"{identifier}.json"
        document=json.loads(source.read_text(encoding="utf-8"))
        rows=document["rows"]
        assert document["width"] == document["height"] == 32
        assert len(rows)==32 and all(len(row)==32 for row in rows)
        palette={key:tuple(bytes.fromhex(value[1:])) for key,value in document["palette"].items()}
        used=set("".join(rows))
        assert used <= palette.keys()
        opaque={key for key in used if palette[key][3]}
        assert len(opaque)<=14, (identifier,len(opaque))
        assert all(palette[key][3] in (0,255) for key in used)
        icon=Image.new("RGBA",(32,32)); icon.putdata([palette[key] for row in rows for key in row])
        assert all(icon.getpixel((x,y))[3]==0 for y in range(32) for x in range(32)
                   if x<2 or x>29 or y<2 or y>29), identifier
        path=OUTPUT / f"{identifier}.png"; icon.save(path,optimize=False)
        records.append({"id":identifier,"runtime":path.relative_to(ROOT).as_posix(),
                        "source":source.relative_to(ROOT).as_posix(),"purpose":purpose,
                        "size":[32,32],"opaque_colors":len(opaque),
                        "source_sha256":hashlib.sha256(source.read_bytes()).hexdigest(),
                        "sha256":hashlib.sha256(path.read_bytes()).hexdigest()})
        images[identifier]=icon
    manifest={"version":2,"art_direction":"Original native 32x32 pixel primitives; no downsampling or antialiasing.",
              "reference":"Existing default spell atlas and classic equipment panels inspected for style only; no copied pixels.",
              "palette":PALETTE,"icon_count":len(records),"trees":TREE_ICONS,"icons":records}
    (ROOT / "assets/passives/manifest.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")
    PREVIEWS.mkdir(parents=True,exist_ok=True)
    for tree,identifiers in TREE_ICONS.items():
        contact_sheets(tree,[(identifier,images[identifier]) for identifier in identifiers],tree + "_")
    cap_ids=[identifier for identifier in PURPOSES if identifier.startswith("cap_")]
    contact_sheets("all-capstones",[(identifier,images[identifier]) for identifier in cap_ids]+[
        (tree,images[tree]) for tree in TREE_ICONS])
    print(f"Rendered and validated {len(records)} native icons: 32x32, binary alpha, <=14 opaque colors, 2px safe border.")


def contact_sheets(name,images,prefix=""):
    font=ImageFont.load_default()
    rows=(len(images)+5)//6
    sheet=Image.new("RGB",(6*128,rows*78),(37,38,40)); draw=ImageDraw.Draw(sheet)
    zoom=Image.new("RGB",(6*146,rows*164),(37,38,40)); zd=ImageDraw.Draw(zoom)
    for index,(identifier,icon) in enumerate(images):
        x=(index%6)*128; y=(index//6)*78
        draw.rectangle((x+45,y+5,x+80,y+40),fill=(48,49,52),outline=(108,108,108))
        sheet.paste(icon,(x+47,y+7),icon)
        label=identifier.removeprefix(prefix).replace("minor_","m:").replace("major_","M:").replace("cap_","C:")
        draw.text((x+4,y+48),label,font=font,fill=(210,205,190))
        zx=(index%6)*146; zy=(index//6)*164
        zoom.paste(icon.resize((128,128),Image.Resampling.NEAREST),(zx+9,zy+4),
                   icon.resize((128,128),Image.Resampling.NEAREST))
        zd.text((zx+4,zy+137),label,font=font,fill=(210,205,190))
    sheet.save(PREVIEWS / f"{name}-native-contact.png")
    zoom.save(PREVIEWS / f"{name}-diagnostic-4x.png")


if __name__ == "__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--author",action="store_true",help="Regenerate original palette grid sources.")
    args=parser.parse_args()
    if args.author:
        author_icons()
    render()
