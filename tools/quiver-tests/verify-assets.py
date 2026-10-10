"""Validate the actual Magic Quiver legacy mapping and functional asset flags."""
import importlib.util
import argparse
import json
from pathlib import Path
import struct
import sys
import xml.etree.ElementTree as ET
from PIL import Image

client=Path(__file__).resolve().parents[2]
server=client.parent/'Rookhaven'
spec=importlib.util.spec_from_file_location('item_assets',client/'tools/item_assets.py')
m=importlib.util.module_from_spec(spec)
sys.modules[spec.name]=m
spec.loader.exec_module(m)
args=argparse.ArgumentParser()
args.add_argument('--manifest',type=Path,default=client/'out/item-work/magic-quiver-empty-20261010/staged/manifest.json')
args.add_argument('--stage',action='store_true')
args=args.parse_args()
manifest=json.loads(args.manifest.read_text(encoding='utf-8'))
assert manifest['server_id']==12830 and manifest['client_id']==11867
sprite=manifest['sprite_id']
prefix=args.manifest.parent if args.stage else None
dat=(prefix/'client/data/things/860/Tibia.dat' if prefix else client/'data/things/860/Tibia.dat').read_bytes()
spr=(prefix/'client/data/things/860/Tibia.spr' if prefix else client/'data/things/860/Tibia.spr').read_bytes()
otb=(prefix/'server/data/items/items.otb' if prefix else server/'data/items/items.otb').read_bytes()
xml=(prefix/'server/data/items/items.xml' if prefix else server/'data/items/items.xml').read_bytes()
nodes=m.item_nodes(m.parse_otb(otb))
target=nodes[12830]
assert target.kind==2, 'OTB group must be container'
flags=struct.unpack_from('<I',target.props)[0]
assert flags==0x60, 'Expected movable/pickupable, nonstackable container flags'
cid=m.u16(m.attributes(target)[0x11],0)
assert cid==11867
things,_=m.parse_dat(dat)
thing=next(t for t in things if t.category==0 and t.client_id==cid)
assert dat[thing.start:thing.sprite_start]==bytes([4,16,255,1,1,1,1,1,1,1]), 'DAT must be static pickupable container, not stackable'
assert thing.sprites==[sprite]
im=Image.open(client/'assets/items/magic-quiver/sprite.png').convert('RGBA')
assert im.size==(32,32) and set(im.getchannel('A').getdata())=={0,255}
assert m.sprite_image(spr,sprite).tobytes()==im.tobytes(), 'Sprite must decode losslessly'
root=ET.fromstring(xml)
item=next(x for x in root if x.get('id')=='12830')
attrs={x.get('key'):x.get('value') for x in item}
assert attrs['containerSize']=='20' and attrs['slotType']=='ammo' and attrs['ammoContainer']=='true'
assert attrs['weight']=='1800'
quest=nodes[12425]
assert quest.kind==0 and struct.unpack_from('<I',quest.props)[0]==0xE0, 'Existing quest quiver must stay stackable/noncontainer'
assert next(x for x in root if x.get('id')=='12425').get('name')=="hunter's quiver"
print(json.dumps({'result':'QUIVER_ASSETS_OK','sid':12830,'cid':cid,'sprite':sprite,'capacity':20,'datContainer':True,'otbContainer':True,'stackable':False,'questUnchanged':True}))
