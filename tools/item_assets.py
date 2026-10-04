"""Read and extend Rookhaven's legacy 8.60 DAT/SPR/OTB assets.

Existing definitions and compressed sprite payloads are preserved verbatim.
Pillow is only used at the PNG / 32-pixel sprite boundary.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import struct
from dataclasses import dataclass
from pathlib import Path
import xml.etree.ElementTree as ET

from PIL import Image, ImageDraw


def u16(data, offset):
    return struct.unpack_from('<H', data, offset)[0]


def u32(data, offset):
    return struct.unpack_from('<I', data, offset)[0]


@dataclass
class Thing:
    client_id: int
    category: int
    start: int
    end: int
    sprite_start: int
    size: tuple[int, int]
    layout: tuple[int, int, int, int, int]
    sprites: list[int]


def parse_dat(data: bytes) -> tuple[list[Thing], int]:
    """8.60: 16-bit sprite IDs, no enhanced animations or frame groups."""
    offset = 12
    things = []
    item_end = None
    sizes = {0: 2, 8: 2, 9: 2, 21: 4, 24: 4, 25: 2,
             28: 2, 29: 2, 32: 2, 34: 2, 38: 16}
    for category, maximum in enumerate(struct.unpack_from('<4H', data, 4)):
        for client_id in range(100 if category == 0 else 1, maximum + 1):
            start = offset
            for _ in range(256):
                attr = data[offset]
                offset += 1
                if attr == 255:
                    break
                if attr == 33:
                    offset += 6
                    length = u16(data, offset)
                    offset += 2 + length + 4
                elif attr <= 38:
                    offset += sizes.get(attr, 0)
                else:
                    raise ValueError(f'Unsupported DAT attribute {attr} at {client_id}')
            else:
                raise ValueError('Unterminated DAT attributes')
            width, height = data[offset:offset + 2]
            offset += 2
            if width > 1 or height > 1:
                offset += 1
            layout = tuple(data[offset:offset + 5])
            offset += 5
            count = width * height
            for factor in layout:
                count *= factor
            if not 0 < count <= 4096:
                raise ValueError(f'Invalid sprite count {count} for {client_id}')
            sprite_start = offset
            sprites = list(struct.unpack_from(f'<{count}H', data, offset))
            offset += count * 2
            things.append(Thing(client_id, category, start, offset, sprite_start,
                                (width, height), layout, sprites))
        if category == 0:
            item_end = offset
    if offset != len(data):
        raise ValueError(f'DAT was not consumed exactly: {offset}/{len(data)}')
    return things, item_end


@dataclass
class Node:
    kind: int
    props: bytes
    children: list['Node']


def parse_otb(data: bytes) -> Node:
    if data[:4] not in (b'\0' * 4, b'OTBI'):
        raise ValueError('Unknown OTB identifier')
    stack = []
    root = None
    offset = 4
    while offset < len(data):
        value = data[offset]
        offset += 1
        if value == 0xFD:
            stack[-1][1].append(data[offset])
            offset += 1
        elif value == 0xFE:
            node = Node(data[offset], b'', [])
            offset += 1
            if stack:
                stack[-1][0].children.append(node)
            elif root is None:
                root = node
            else:
                raise ValueError('Multiple OTB roots')
            stack.append((node, bytearray()))
        elif value == 0xFF:
            node, props = stack.pop()
            node.props = bytes(props)
        else:
            stack[-1][1].append(value)
    if stack or root is None:
        raise ValueError('Unclosed OTB tree')
    return root


def escape(data: bytes) -> bytes:
    return b''.join(bytes((0xFD, byte)) if byte >= 0xFD else bytes((byte,)) for byte in data)


def write_node(node: Node) -> bytes:
    return bytes((0xFE, node.kind)) + escape(node.props) + b''.join(
        write_node(child) for child in node.children) + b'\xFF'


def attributes(node: Node) -> dict[int, bytes]:
    result = {}
    offset = 4
    while offset < len(node.props):
        kind = node.props[offset]
        length = u16(node.props, offset + 1)
        offset += 3
        value = node.props[offset:offset + length]
        if len(value) != length or kind in result:
            raise ValueError('Invalid or duplicate OTB attribute')
        result[kind] = value
        offset += length
    return result


def item_nodes(root: Node) -> dict[int, Node]:
    nodes = {}
    for node in root.children:
        attrs = attributes(node)
        server_id = u16(attrs[0x10], 0)
        if server_id in nodes:
            raise ValueError(f'Duplicate server ID {server_id}')
        nodes[server_id] = node
    return nodes


def sprite_image(spr: bytes, sprite_id: int) -> Image.Image:
    image = Image.new('RGBA', (32, 32))
    if sprite_id == 0:
        return image
    if sprite_id > u16(spr, 4):
        raise ValueError('Sprite ID outside archive')
    offset = u32(spr, 6 + (sprite_id - 1) * 4)
    if offset == 0:
        return image
    size = u16(spr, offset + 3)
    offset += 5
    end = offset + size
    pixels = image.load()
    cursor = 0
    while offset < end:
        transparent, colored = struct.unpack_from('<2H', spr, offset)
        offset += 4
        cursor += transparent
        if cursor + colored > 1024:
            raise ValueError('SPR pixel data exceeds tile')
        for _ in range(colored):
            pixels[cursor % 32, cursor // 32] = (*spr[offset:offset + 3], 255)
            offset += 3
            cursor += 1
    if offset != end:
        raise ValueError('Bad SPR payload boundary')
    return image


def encode_sprite(image: Image.Image) -> bytes:
    if image.size != (32, 32):
        raise ValueError('SPR tile must be 32x32')
    pixels = list(image.convert('RGBA').getdata())
    data = bytearray()
    index = 0
    while index < len(pixels):
        transparent = 0
        while index < len(pixels) and pixels[index][3] == 0:
            transparent += 1
            index += 1
        colored = []
        while index < len(pixels) and pixels[index][3] != 0:
            if pixels[index][3] != 255:
                raise ValueError('8.60 SPR requires opaque or fully transparent pixels')
            colored.extend(pixels[index][:3])
            index += 1
        data.extend(struct.pack('<2H', transparent, len(colored) // 3))
        data.extend(colored)
    return b'\xFF\0\xFF' + struct.pack('<H', len(data)) + data


def append_sprite(spr: bytes, image: Image.Image) -> bytes:
    count = u16(spr, 4)
    if count >= 65535:
        raise ValueError('16-bit SPR is full')
    old_table_end = 6 + count * 4
    pointers = [u32(spr, 6 + index * 4) for index in range(count)]
    pointers = [pointer + 4 if pointer else 0 for pointer in pointers]
    pointers.append(len(spr) + 4)
    return (spr[:4] + struct.pack('<H', count + 1) +
            struct.pack(f'<{count + 1}I', *pointers) +
            spr[old_table_end:] + encode_sprite(image))


def editor_sprite_hash(image: Image.Image) -> bytes:
    # ItemEditor's getRGBAData is bottom-up BGRX, transparent RGB=0x11,
    # and its fourth byte is zero for every pixel (not an alpha value).
    pixels = image.convert('RGBA').load()
    data = bytearray()
    for y in range(31, -1, -1):
        for x in range(32):
            r, g, b, a = pixels[x, y]
            data.extend((b, g, r, 0) if a else (17, 17, 17, 0))
    return hashlib.md5(data).digest()


def export_references(client: Path, server: Path, output: Path):
    dat = (client / 'data/things/860/Tibia.dat').read_bytes()
    spr = (client / 'data/things/860/Tibia.spr').read_bytes()
    nodes = item_nodes(parse_otb((server / 'data/items/items.otb').read_bytes()))
    things, _ = parse_dat(dat)
    items = {thing.client_id: thing for thing in things if thing.category == 0}
    sword_ids = [2376, 2392, 2400, 2407, 2412, 2393]
    output.mkdir(parents=True, exist_ok=True)
    sheet = Image.new('RGBA', (len(sword_ids) * 128, 164), '#353535')
    draw = ImageDraw.Draw(sheet)
    for index, sid in enumerate(sword_ids):
        cid = u16(attributes(nodes[sid])[0x11], 0)
        thing = items[cid]
        if thing.size != (1, 1):
            raise ValueError(f'Reference sword {sid} is not a simple tile')
        image = sprite_image(spr, thing.sprites[0])
        image.save(output / f'sword-{sid}.png')
        large = image.resize((128, 128), Image.Resampling.NEAREST)
        sheet.alpha_composite(large, (index * 128, 0))
        draw.text((index * 128 + 8, 137), f'SID {sid}', fill='white')
    sheet.save(output / 'reference-swords.png')
    print(json.dumps({'references': str(output / 'reference-swords.png'),
                      'prototype_sid': 2400, 'prototype_cid': u16(attributes(nodes[2400])[0x11], 0)}))


def stage_item(client: Path, server: Path, image_path: Path, output: Path):
    dat = (client / 'data/things/860/Tibia.dat').read_bytes()
    spr = (client / 'data/things/860/Tibia.spr').read_bytes()
    otb = (server / 'data/items/items.otb').read_bytes()
    root = parse_otb(otb)
    if otb[:4] + write_node(root) != otb:
        raise ValueError('OTB round trip did not preserve every byte')
    nodes = item_nodes(root)
    server_id, client_id = 12829, 11866
    if server_id in nodes or u16(dat, 4) + 1 != client_id:
        raise ValueError('Reserved proof item IDs are already occupied or DAT changed')
    xml_path = server / 'data/items/items.xml'
    xml = xml_path.read_bytes()
    xml_root = ET.fromstring(xml)
    for item in xml_root:
        low = int(item.get('id', item.get('fromid', '0')))
        high = int(item.get('toid', str(low)))
        if low <= server_id <= high:
            raise ValueError('Server ID already exists in items.xml')
    image = Image.open(image_path).convert('RGBA')
    if image.size != (32, 32):
        raise ValueError('The production PNG must already be exactly 32x32')
    new_spr = append_sprite(spr, image)
    sprite_id = u16(new_spr, 4)
    if sprite_image(new_spr, sprite_id).tobytes() != image.tobytes():
        raise ValueError('New sprite failed lossless decode validation')
    old_sprite_count = u16(spr, 4)
    if new_spr[6 + (old_sprite_count + 1) * 4:len(spr) + 4] != spr[6 + old_sprite_count * 4:]:
        raise ValueError('Existing sprite payload changed')
    things, item_end = parse_dat(dat)
    prototype_cid = u16(attributes(nodes[2376])[0x11], 0)
    prototype = next(t for t in things if t.category == 0 and t.client_id == prototype_cid)
    if prototype.size != (1, 1) or len(prototype.sprites) != 1:
        raise ValueError('Prototype is not a single-sprite sword')
    entry = dat[prototype.start:prototype.sprite_start] + struct.pack('<H', sprite_id)
    header = dat[:4] + struct.pack('<H', client_id) + dat[6:12]
    new_dat = header + dat[12:item_end] + entry + dat[item_end:]
    new_things, _ = parse_dat(new_dat)
    old_records = {(t.category, t.client_id): dat[t.start:t.end] for t in things}
    for thing in new_things:
        if thing.category == 0 and thing.client_id == client_id:
            continue
        if old_records[(thing.category, thing.client_id)] != new_dat[thing.start:thing.end]:
            raise ValueError('An existing DAT definition changed')
    attrs = attributes(nodes[2400]).copy()
    attrs[0x10] = struct.pack('<H', server_id)
    attrs[0x11] = struct.pack('<H', client_id)
    attrs[0x20] = editor_sprite_hash(image)
    props = nodes[2400].props[:4] + b''.join(
        bytes((key,)) + struct.pack('<H', len(value)) + value for key, value in attrs.items())
    root.children.append(Node(nodes[2400].kind, props, []))
    new_otb = otb[:4] + write_node(root)
    new_nodes = item_nodes(parse_otb(new_otb))
    if len(new_nodes) != len(nodes) + 1 or u16(attributes(new_nodes[server_id])[0x11], 0) != client_id:
        raise ValueError('New OTB mapping is invalid')
    for sid, node in nodes.items():
        if write_node(new_nodes[sid]) != write_node(node):
            raise ValueError(f'Existing OTB item {sid} changed')
    newline = b'\r\n' if b'\r\n' in xml else b'\n'
    block = '''\t<!-- Proof item: SID 12829 / CID 11866. No production loot entry. -->
\t<item id="12829" article="a" name="rookhaven duskblade">
\t\t<attribute key="description" value="A proof blade forged from twilight steel." />
\t\t<attribute key="weight" value="4200" />
\t\t<attribute key="defense" value="32" />
\t\t<attribute key="attack" value="52" />
\t\t<attribute key="weaponType" value="sword" />
\t\t<attribute key="extradef" value="3" />
\t</item>
'''.encode().replace(b'\n', newline)
    if xml.count(b'</items>') != 1:
        raise ValueError('Unexpected XML structure')
    new_xml = xml.replace(b'</items>', block + b'</items>')
    ET.fromstring(new_xml)
    files = {'client/data/things/860/Tibia.dat': new_dat,
             'client/data/things/860/Tibia.spr': new_spr,
             'server/data/items/items.otb': new_otb,
             'server/data/items/items.xml': new_xml}
    for name, contents in files.items():
        target = output / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(contents)
    manifest = {'name': 'rookhaven duskblade', 'server_id': server_id,
                'client_id': client_id, 'sprite_id': sprite_id,
                'prototype_server_id': 2400,
                'prototype_dat_server_id': 2376,
                'validated_existing_sprites': old_sprite_count,
                'validated_existing_dat_records': len(old_records),
                'validated_existing_otb_records': len(nodes),
                'files': {name: hashlib.sha256(contents).hexdigest() for name, contents in files.items()}}
    output.mkdir(parents=True, exist_ok=True)
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps(manifest, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['references', 'stage'])
    parser.add_argument('--client', type=Path, required=True)
    parser.add_argument('--server', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--image', type=Path)
    args = parser.parse_args()
    if args.command == 'references':
        export_references(args.client, args.server, args.output)
    elif args.image:
        stage_item(args.client, args.server, args.image, args.output)
    else:
        parser.error('stage requires --image')


if __name__ == '__main__':
    main()
