"""Stage the matched Lifekeeper rod DAT/SPR/OTB/XML batch without changing source files.

Keeps every donor DAT layout (including stack patterns and focus frames) and all
existing records byte-for-byte. Each new pattern references the new static tile.
Apply only after reviewing manifest.json and verifying its source hashes.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import xml.etree.ElementTree as ET

import item_assets as m


def sha(data):
    return hashlib.sha256(data).hexdigest()


def stage(client, server, output):
    client, server, output = client.resolve(), server.resolve(), output.resolve()
    if output.exists() or not output.is_relative_to(client / 'out'):
        raise ValueError('Use a fresh output directory inside client/out')
    paths = {
        'client/data/things/860/Tibia.dat': client / 'data/things/860/Tibia.dat',
        'client/data/things/860/Tibia.spr': client / 'data/things/860/Tibia.spr',
        'server/data/items/items.otb': server / 'data/items/items.otb',
        'server/data/items/items.xml': server / 'data/items/items.xml',
    }
    original = {key: path.read_bytes() for key, path in paths.items()}
    dat, spr, otb, xml = original.values()
    old_dat, old_spr, old_otb = dat, spr, otb
    original_things, _ = m.parse_dat(dat)
    original_nodes = m.item_nodes(m.parse_otb(otb))
    old_count = m.u16(spr, 4)
    records = []
    definitions = sorted((client / 'assets/items/rods').glob('*/definition.json'),
                         key=lambda path: json.loads(path.read_text(encoding='utf-8'))['server_id'])
    if len(definitions) != 8:
        raise ValueError('Expected exactly eight rods')
    for path in definitions:
        definition = json.loads(path.read_text(encoding='utf-8'))
        sid, expected_cid = definition['server_id'], definition['client_id']
        root = m.parse_otb(otb)
        if otb[:4] + m.write_node(root) != otb:
            raise ValueError('OTB round trip changed bytes')
        nodes = m.item_nodes(root)
        xmlroot = ET.fromstring(xml)
        if sid in nodes or any(int(n.get('id', n.get('fromid', '0'))) <= sid <=
                int(n.get('toid', n.get('id', n.get('fromid', '0')))) for n in xmlroot):
            raise ValueError(f'Occupied server ID {sid}')
        cid = m.u16(dat, 4) + 1
        if cid != expected_cid or cid > 65535:
            raise ValueError(f'Unexpected next client ID {cid}, expected {expected_cid}')
        things, item_end = m.parse_dat(dat)
        items = {t.client_id: t for t in things if t.category == 0}
        donor = nodes[definition['prototype_server_id']]
        prototype = items[m.u16(m.attributes(donor)[0x11], 0)]
        if prototype.size != (1, 1):
            raise ValueError('Only one-tile donors are supported')
        imagepath = path.parent / 'sprite.png'
        image = m.Image.open(imagepath).convert('RGBA')
        if image.size != (32, 32) or any(p[3] not in (0, 255) for p in image.getdata()):
            raise ValueError(f'{imagepath}: exact32x32 and binary alpha required')
        image.putdata([p if p[3] else (0, 0, 0, 0) for p in image.getdata()])
        spr = m.append_sprite(spr, image)
        sprite_id = m.u16(spr, 4)
        if m.sprite_image(spr, sprite_id).tobytes() != image.tobytes():
            raise ValueError('New SPR tile did not decode losslessly')
        record = dat[prototype.start:prototype.sprite_start] + struct.pack(
            '<' + 'H' * len(prototype.sprites), *([sprite_id] * len(prototype.sprites)))
        dat = dat[:4] + struct.pack('<H', cid) + dat[6:item_end] + record + dat[item_end:]
        attrs = m.attributes(donor).copy()
        attrs.update({0x10: struct.pack('<H', sid), 0x11: struct.pack('<H', cid),
                      0x20: m.editor_sprite_hash(image)})
        props = donor.props[:4] + b''.join(bytes((key,)) + struct.pack('<H', len(value)) + value
                                           for key, value in attrs.items())
        root.children.append(m.Node(donor.kind, props, []))
        otb = otb[:4] + m.write_node(root)
        item = ET.Element('item', {'id': str(sid), 'article': definition['article'], 'name': definition['name']})
        for key, value in definition['attributes'].items():
            ET.SubElement(item, 'attribute', {'key': key, 'value': str(value)})
        ET.indent(item, space='\t', level=1)
        newline = b'\r\n' if b'\r\n' in xml else b'\n'
        block = (b'\t' + ET.tostring(item, encoding='utf-8') + b'\n').replace(b'\n', newline)
        if xml.count(b'</items>') != 1:
            raise ValueError('Unexpected XML root')
        xml = xml.replace(b'</items>', block + b'</items>')
        records.append({'server_id': sid, 'client_id': cid, 'sprite_id': sprite_id,
                        'donor': definition['prototype_server_id'], 'layout': prototype.layout,
                        'image_sha256': sha(imagepath.read_bytes())})
    new_things, _ = m.parse_dat(dat)
    new_lookup = {(t.category, t.client_id): t for t in new_things}
    for thing in original_things:
        new = new_lookup[(thing.category, thing.client_id)]
        if old_dat[thing.start:thing.end] != dat[new.start:new.end]:
            raise ValueError('Existing DAT record changed')
    new_nodes = m.item_nodes(m.parse_otb(otb))
    for sid, node in original_nodes.items():
        if m.write_node(node) != m.write_node(new_nodes[sid]):
            raise ValueError(f'Existing OTB node {sid} changed')
    added = len(records)
    if spr[6 + (old_count + added) * 4:len(old_spr) + added * 4] != old_spr[6 + old_count * 4:]:
        raise ValueError('Existing SPR payloads changed')
    for sprite_id in range(1, old_count + 1):
        old_offset = m.u32(old_spr, 6 + (sprite_id - 1) * 4)
        new_offset = m.u32(spr, 6 + (sprite_id - 1) * 4)
        if new_offset != (old_offset + added * 4 if old_offset else 0):
            raise ValueError('Existing SPR index changed unexpectedly')
    ET.fromstring(xml)
    outputs = dict(zip(paths, (dat, spr, otb, xml)))
    for key, value in outputs.items():
        target = output / key
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(value)
    manifest = {'items': records, 'source_files': {key: sha(value) for key, value in original.items()},
                'files': {key: sha(value) for key, value in outputs.items()},
                'validated_existing_sprites': old_count, 'validated_existing_dat_records': len(original_things),
                'validated_existing_otb_records': len(original_nodes)}
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(manifest, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--client', type=Path, default=Path.cwd())
    parser.add_argument('--server', type=Path, default=Path.cwd().parent / 'Rookhaven')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    stage(args.client, args.server, args.output)
