"""Stage a static 8.60 item or replacement artwork without editing repo assets."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import sys
import xml.etree.ElementTree as ET


def stage(args):
    client, server, output = args.client.resolve(), args.server.resolve(), args.output.resolve()
    if output.exists() or not output.is_relative_to(client / 'out'):
        raise ValueError('Use a fresh staging directory under client out/')
    spec = importlib.util.spec_from_file_location('rookhaven_item_assets', client / 'tools/item_assets.py')
    m = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = m
    spec.loader.exec_module(m)
    definition = json.loads(args.definition.read_text(encoding='utf-8-sig'))
    sid = int(definition['server_id'])
    if not 100 <= sid <= 65535:
        raise ValueError('Server ID must fit the legacy 16-bit format')
    paths = {
        'client/data/things/860/Tibia.dat': client / 'data/things/860/Tibia.dat',
        'client/data/things/860/Tibia.spr': client / 'data/things/860/Tibia.spr',
        'server/data/items/items.otb': server / 'data/items/items.otb',
        'server/data/items/items.xml': server / 'data/items/items.xml',
    }
    dat, spr, otb, xml = (p.read_bytes() for p in paths.values())
    root = m.parse_otb(otb)
    if otb[:4] + m.write_node(root) != otb:
        raise ValueError('OTB round trip must preserve all bytes')
    nodes = m.item_nodes(root)
    things, item_end = m.parse_dat(dat)
    items = {t.client_id: t for t in things if t.category == 0}
    matching = [node for node in ET.fromstring(xml) if
                int(node.get('id', node.get('fromid', '0'))) <= sid <=
                int(node.get('toid', node.get('id', node.get('fromid', '0'))))]
    image = m.Image.open(args.image).convert('RGBA')
    if image.size != (32, 32):
        raise ValueError('Supply the final 32x32 PNG; no automatic resizing')
    pixels = list(image.getdata())
    if any(p[3] not in (0, 255) for p in pixels):
        raise ValueError('Legacy RGB SPR supports binary alpha only')
    # SPR discards invisible RGB channels; canonicalize those only.
    image.putdata([p if p[3] else (0, 0, 0, 0) for p in pixels])
    new_spr = m.append_sprite(spr, image)
    sprite_id, old_count = m.u16(new_spr, 4), m.u16(spr, 4)
    if m.sprite_image(new_spr, sprite_id).tobytes() != image.tobytes():
        raise ValueError('New SPR tile does not decode losslessly')
    if new_spr[6 + (old_count + 1) * 4:len(spr) + 4] != spr[6 + old_count * 4:]:
        raise ValueError('Existing SPR payloads changed')
    if args.mode == 'add':
        if sid in nodes or matching:
            raise ValueError('Server ID is occupied in OTB or XML')
        cid = m.u16(dat, 4) + 1
        if cid > 65535:
            raise ValueError('Legacy DAT item table is full')
        prototype_cid = m.u16(m.attributes(nodes[int(definition['prototype_dat_server_id'])])[0x11], 0)
        prototype, otb_prototype = items[prototype_cid], nodes[int(definition['prototype_otb_server_id'])]
    else:
        if sid not in nodes or len(matching) != 1:
            raise ValueError('Replacement requires an existing OTB and XML item')
        cid = m.u16(m.attributes(nodes[sid])[0x11], 0)
        prototype, otb_prototype = items[cid], nodes[sid]
    if 'client_id' in definition and int(definition['client_id']) != cid:
        raise ValueError('Expected client ID does not match current DAT/OTB')
    if prototype.size != (1, 1) or len(prototype.sprites) != 1:
        raise ValueError('Only static single-tile, single-sprite definitions are supported')
    record = dat[prototype.start:prototype.sprite_start] + struct.pack('<H', sprite_id)
    if args.mode == 'add':
        new_dat = dat[:4] + struct.pack('<H', cid) + dat[6:item_end] + record + dat[item_end:]
    else:
        new_dat = dat[:prototype.start] + record + dat[prototype.end:]
    parsed_new, _ = m.parse_dat(new_dat)
    if len(parsed_new) != len(things) + (args.mode == 'add'):
        raise ValueError('Unexpected DAT definition count')
    original = {(t.category, t.client_id): dat[t.start:t.end] for t in things}
    for thing in parsed_new:
        if thing.category == 0 and thing.client_id == cid:
            continue
        if original[(thing.category, thing.client_id)] != new_dat[thing.start:thing.end]:
            raise ValueError('An unrelated DAT definition changed')
    attrs = m.attributes(otb_prototype).copy()
    attrs[0x10], attrs[0x11], attrs[0x20] = struct.pack('<H', sid), struct.pack('<H', cid), m.editor_sprite_hash(image)
    props = otb_prototype.props[:4] + b''.join(
        bytes((key,)) + struct.pack('<H', len(value)) + value for key, value in attrs.items())
    target = m.Node(otb_prototype.kind, props, [])
    if args.mode == 'add':
        root.children.append(target)
    else:
        root.children[root.children.index(nodes[sid])] = target
    new_otb = otb[:4] + m.write_node(root)
    new_nodes = m.item_nodes(m.parse_otb(new_otb))
    if len(new_nodes) != len(nodes) + (args.mode == 'add') or m.u16(m.attributes(new_nodes[sid])[0x11], 0) != cid:
        raise ValueError('OTB count or SID to CID mapping failed')
    for existing_sid, node in nodes.items():
        if existing_sid == sid and args.mode == 'replace-art':
            continue
        if m.write_node(new_nodes[existing_sid]) != m.write_node(node):
            raise ValueError(f'Unrelated OTB item {existing_sid} changed')
    if args.mode == 'add':
        item = ET.Element('item', {'id': str(sid), 'article': definition['article'], 'name': definition['name']})
        for key, value in definition['attributes'].items():
            ET.SubElement(item, 'attribute', {'key': key, 'value': str(value)})
        ET.indent(item, space='\t', level=1)
        newline = b'\r\n' if b'\r\n' in xml else b'\n'
        block = (b'\t' + ET.tostring(item, encoding='utf-8') + b'\n').replace(b'\n', newline)
        if xml.count(b'</items>') != 1:
            raise ValueError('Unexpected XML closing root')
        new_xml = xml.replace(b'</items>', block + b'</items>')
    else:
        new_xml = xml
    ET.fromstring(new_xml)
    outputs = dict(zip(paths, (new_dat, new_spr, new_otb, new_xml)))
    manifest = {
        'mode': args.mode, 'name': definition.get('name', matching[0].get('name') if matching else None),
        'server_id': sid, 'client_id': cid, 'sprite_id': sprite_id, 'definition': definition,
        'image_sha256': hashlib.sha256(args.image.read_bytes()).hexdigest(),
        'source_files': {name: hashlib.sha256(path.read_bytes()).hexdigest() for name, path in paths.items()},
        'files': {name: hashlib.sha256(data).hexdigest() for name, data in outputs.items()},
        'validated_existing_sprites': old_count,
        'validated_existing_dat_records': len(things), 'validated_existing_otb_records': len(nodes),
    }
    for name, data in outputs.items():
        path = output / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(manifest, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--client', type=Path, required=True)
    parser.add_argument('--server', type=Path, required=True)
    parser.add_argument('--definition', type=Path, required=True)
    parser.add_argument('--image', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--mode', choices=['add', 'replace-art'], default='add')
    stage(parser.parse_args())
