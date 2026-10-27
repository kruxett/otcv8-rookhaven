"""Validate both static states and every pre-existing DAT/SPR/OTB record."""
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
xml = ET.parse(SERVER / 'data/items/items.xml').getroot()
things, _ = m.parse_dat(dat)
things = {(t.category,t.client_id):t for t in things}
old_dat = (args.originals / 'client/data/things/860/Tibia.dat').read_bytes()
old_spr = (args.originals / 'client/data/things/860/Tibia.spr').read_bytes()
old_nodes = m.item_nodes(m.parse_otb((args.originals / 'server/data/items/items.otb').read_bytes()))
old_things, _ = m.parse_dat(old_dat)
for old in old_things:
    new = things[old.category,old.client_id]
    assert old_dat[old.start:old.end] == dat[new.start:new.end]
for sid, node in old_nodes.items(): assert m.write_node(node) == m.write_node(nodes[sid])
old_count = m.u16(old_spr,4)
assert m.u16(dat,4) == m.u16(old_dat,4) + 2
assert m.u16(spr,4) == old_count + 2
assert spr[6+(old_count+2)*4:len(old_spr)+8] == old_spr[6+old_count*4:]
rows = []
for state,sid,cid,sprite,lit in [('unequipped',12861,11898,36695,False),('equipped',12862,11899,36696,True)]:
    node = nodes[sid]; attrs = m.attributes(node)
    assert node.kind == 0 and m.u32(node.props,0) == 0x60
    assert m.u16(attrs[0x11],0) == cid
    thing = things[0,cid]
    expected = bytes([16,21,7,0,206,0,255,1,1,1,1,1,1,1]) if lit else bytes([16,255,1,1,1,1,1,1,1])
    assert dat[thing.start:thing.sprite_start] == expected
    assert thing.sprites == [sprite]
    assert attrs.get(0x2a) == (b'\x07\0\xce\0' if lit else None)
    image = Image.open(ROOT / f'assets/items/light-ring/{state}/sprite.png').convert('RGBA')
    assert image.size == (32,32) and set(image.getchannel('A').get_flattened_data()) == {0,255}
    actual = m.sprite_image(spr,sprite)
    for a,b in zip(image.get_flattened_data(),actual.get_flattened_data()): assert a == b or a[3] == b[3] == 0
    assert attrs[0x20] == m.editor_sprite_hash(image)
    matches = [n for n in xml if int(n.get('id',n.get('fromid','0'))) <= sid <= int(n.get('toid',n.get('id',n.get('fromid','0'))))]
    assert len(matches) == 1 and matches[0].get('name') == 'light ring'
    values = {a.get('key'):a.get('value') for a in matches[0]}
    assert values['slotType'] == 'ring' and values['weight'] == '100'
    if lit: assert values['duration'] == '7200' and values['decayTo'] == '0' and values['transformDeEquipTo'] == '12861'
    else: assert values['stopduration'] == '1' and values['transformEquipTo'] == '12862' and 'duration' not in values
    rows.append({'state':state,'sid':sid,'cid':cid,'sprite':sprite,'light':7 if lit else 0,'animated':False})
print(json.dumps({'result':'LIGHT_RING_ASSETS_OK','states':rows,'preserved_dat':len(old_things),'preserved_otb':len(old_nodes),'preserved_sprites':old_count}))
