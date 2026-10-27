"""Verify native pass flags, approved pixels and every pre-existing record."""
from pathlib import Path
from PIL import Image
import argparse
import json
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
SERVER = ROOT.parent / 'Rookhaven'
sys.path.insert(0, str(ROOT / 'tools'))
import item_assets as m
parser = argparse.ArgumentParser()
parser.add_argument('--originals', type=Path, required=True)
args = parser.parse_args()
dat = (ROOT / 'data/things/860/Tibia.dat').read_bytes()
spr = (ROOT / 'data/things/860/Tibia.spr').read_bytes()
nodes = m.item_nodes(m.parse_otb((SERVER / 'data/items/items.otb').read_bytes()))
old_dat = (args.originals / 'client/data/things/860/Tibia.dat').read_bytes()
old_spr = (args.originals / 'client/data/things/860/Tibia.spr').read_bytes()
old_nodes = m.item_nodes(m.parse_otb((args.originals / 'server/data/items/items.otb').read_bytes()))
old_things, _ = m.parse_dat(old_dat)
things, _ = m.parse_dat(dat)
things = {(t.category, t.client_id): t for t in things}
for old in old_things:
    new = things[old.category, old.client_id]
    assert old_dat[old.start:old.end] == dat[new.start:new.end]
for sid, node in old_nodes.items():
    assert m.write_node(node) == m.write_node(nodes[sid])
count = m.u16(old_spr, 4)
assert m.u16(dat, 4) == m.u16(old_dat, 4) + 1
assert m.u16(spr, 4) == count + 1
assert spr[6+(count+1)*4:len(old_spr)+4] == old_spr[6+count*4:]
node = nodes[12867]
attrs = m.attributes(node)
assert node.kind == 0 and m.u32(node.props, 0) == 0x60
assert m.u16(attrs[0x11], 0) == 11904
thing = things[0, 11904]
assert dat[thing.start:thing.sprite_start] == bytes([16,255,1,1,1,1,1,1,1])
assert thing.sprites == [36701]
asset = ROOT / 'assets/items/magic-gold-converter'
assert (asset / 'sprite.png').read_bytes() == (asset / 'source/v6-three-coin-medallion/pixellab-magic-gold-converter.png').read_bytes()
image = Image.open(asset / 'sprite.png').convert('RGBA')
assert image.size == (32,32) and set(image.getchannel('A').get_flattened_data()) == {0,255}
actual = m.sprite_image(spr, 36701)
for a, b in zip(image.get_flattened_data(), actual.get_flattened_data()):
    assert a == b or a[3] == b[3] == 0
assert attrs[0x20] == m.editor_sprite_hash(image)
xml = ET.parse(SERVER / 'data/items/items.xml').getroot()
matches = [n for n in xml if int(n.get('id',n.get('fromid','0'))) <= 12867 <= int(n.get('toid',n.get('id',n.get('fromid','0'))))]
assert len(matches) == 1 and matches[0].get('name') == 'magic gold converter'
values = {a.get('key'):a.get('value') for a in matches[0]}
assert values['weight'] == '100' and 'containerSize' not in values and 'duration' not in values
print(json.dumps({'result':'MAGIC_GOLD_CONVERTER_ASSETS_OK','sid':12867,'cid':11904,'sprite':36701,
    'preserved_dat':len(old_things),'preserved_otb':len(old_nodes),'preserved_sprites':count}))
