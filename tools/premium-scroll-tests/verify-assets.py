"""Verify approved scroll pixels, complete legacy mappings and preserved records."""
from pathlib import Path
import argparse
import json
import sys
import xml.etree.ElementTree as ET
from PIL import Image

CLIENT = Path(__file__).resolve().parents[2]
SERVER = CLIENT.parent / 'Rookhaven'
sys.path.insert(0, str(CLIENT / 'tools'))
import item_assets as m

parser = argparse.ArgumentParser()
parser.add_argument('--originals', type=Path, required=True)
args = parser.parse_args()
dat = (CLIENT / 'data/things/860/Tibia.dat').read_bytes()
spr = (CLIENT / 'data/things/860/Tibia.spr').read_bytes()
otb = (SERVER / 'data/items/items.otb').read_bytes()
xml = ET.parse(SERVER / 'data/items/items.xml').getroot()
things, _ = m.parse_dat(dat)
things = {(t.category, t.client_id): t for t in things}
nodes = m.item_nodes(m.parse_otb(otb))
old_dat = (args.originals / 'client/data/things/860/Tibia.dat').read_bytes()
old_spr = (args.originals / 'client/data/things/860/Tibia.spr').read_bytes()
old_nodes = m.item_nodes(m.parse_otb((args.originals / 'server/data/items/items.otb').read_bytes()))
old_things, _ = m.parse_dat(old_dat)
for old in old_things:
    new = things[old.category, old.client_id]
    assert old_dat[old.start:old.end] == dat[new.start:new.end], (old.category, old.client_id)
for sid, node in old_nodes.items():
    assert m.write_node(node) == m.write_node(nodes[sid]), sid
old_count = m.u16(old_spr, 4)
assert spr[6 + (old_count + 3) * 4:len(old_spr) + 12] == old_spr[6 + old_count * 4:]
rows = []
for offset, days in enumerate((30, 60, 90)):
    sid, cid, sprite = 12858 + offset, 11895 + offset, 36692 + offset
    node = nodes[sid]
    assert node.kind == 0 and m.u32(node.props, 0) == 0x60
    assert m.u16(m.attributes(node)[0x11], 0) == cid
    thing = things[0, cid]
    assert dat[thing.start:thing.sprite_start] == bytes([16, 255, 1, 1, 1, 1, 1, 1, 1])
    assert thing.sprites == [sprite]
    image = Image.open(CLIENT / f'assets/items/premium-scroll/{days}/sprite.png').convert('RGBA')
    assert image.size == (32, 32) and set(image.getchannel('A').get_flattened_data()) == {0, 255}
    expected = bytes(channel for pixel in image.get_flattened_data() for channel in (pixel if pixel[3] else (0, 0, 0, 0)))
    assert m.sprite_image(spr, sprite).tobytes() == expected
    assert m.attributes(node)[0x20] == m.editor_sprite_hash(image)
    matches = [x for x in xml if int(x.get('id', x.get('fromid', '0'))) <= sid <= int(x.get('toid', x.get('id', x.get('fromid', '0'))))]
    assert len(matches) == 1 and matches[0].get('name') == f'premium scroll ({days} days)'
    attributes = {x.get('key'): x.get('value') for x in matches[0]}
    assert attributes['weight'] == '100' and f'{days} days' in attributes['description']
    rows.append({'days': days, 'sid': sid, 'cid': cid, 'sprite': sprite})
print(json.dumps({'result': 'PREMIUM_SCROLL_ASSETS_OK', 'items': rows,
                  'preserved_dat_records': len(old_things), 'preserved_otb_records': len(old_nodes),
                  'preserved_sprites': old_count}))
