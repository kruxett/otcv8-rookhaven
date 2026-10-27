"""Import the eleven approved 2026-10-27 outfit families without repainting art.

Only appends legacy DAT records / SPR payloads and registered outfit XML rows.
The earlier four-outfit importer remains independent and unchanged.
"""
from pathlib import Path
from functools import lru_cache
from PIL import Image
import argparse
import bisect
import hashlib
import importlib.util
import io
import json
import lzma
import shutil
import struct
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
SERVER = ROOT.parent / 'Rookhaven'
ASSET = ROOT / 'assets/outfits/modern-shop-20261027'
CATALOGUE = ROOT / 'assets/outfits/missing-modern-catalog-20261026'
FAMILIES = [
    ('Afflicted', 431, 430),
    ('Arbalester', 1450, 1449),
    ('Arena Champion', 885, 884),
    ('Armoured Archer', 1619, 1618),
    ('Discoverer', 1095, 1094),
    ('Entrepreneur', 471, 472),
    ('Formal Dress', 1461, 1460),
    ('Golden', 1211, 1210),
    ('Nordic Chieftain', 1501, 1500),
    ('Poltergeist', 1271, 1270),
    ('Veteran Paladin', 1205, 1204),
]
PICKS = [(name, look, sex) for name, female, male in FAMILIES
         for look, sex in [(female, 0), (male, 1)]]
SIZES = [(32,32),(32,64),(64,32),(64,64),(32,96),(32,128),(32,192),(32,384),
         (64,96),(64,128),(64,192),(64,384),(96,32),(96,64),(96,96),(96,128),(96,192),(96,384),
         (128,32),(128,64),(128,96),(128,128),(128,192),(128,384),(192,32),(192,64),(192,96),(192,128),(192,192),(192,384),
         (384,32),(384,64),(384,96),(384,128),(384,192),(384,384)]
REVERSE_FLAGS = {'north': 52, 'east': 49, 'south': 51, 'west': 50}
sys.path.insert(0, str(ROOT / 'tools'))
import item_assets as M
spec = importlib.util.spec_from_file_location(
    'modern_reference', ROOT / 'assets/outfits/reference-review-20261026/build_tibia_atlas.py')
T = importlib.util.module_from_spec(spec)
spec.loader.exec_module(T)


def sha(data):
    return hashlib.sha256(data).hexdigest()


class Source:
    def __init__(self):
        self.manifest = json.loads((CATALOGUE / 'render-manifest.json').read_text())
        self.path = Path(self.manifest['source'])
        raw = (self.path / 'catalog-content.json').read_bytes()
        assert sha(raw) == self.manifest['catalogHash'], 'Reviewed source catalogue changed'
        self.catalog_data = raw
        catalog = json.loads(raw)
        self.appearance_file = next(x['file'] for x in catalog if x['type'] == 'appearances')
        assert self.appearance_file == self.manifest['appearanceFile']
        self.data = (self.path / self.appearance_file).read_bytes()
        assert sha(self.data) == self.manifest['appearanceHash'], 'Reviewed appearances changed'
        self.sheets = sorted((r for r in catalog if r['type'] == 'sprite'),
                             key=lambda r: r['firstspriteid'])
        self.first = [s['firstspriteid'] for s in self.sheets]
        self.sheet_hashes = {}
        self.additional_idle_sheet_hashes = {}
        self.models = {}
        reviewed = {r['name']: r for r in json.loads((CATALOGUE / 'catalog.json').read_text())['outfits']}
        for name, look, sex in PICKS:
            assert reviewed[name]['female' if sex == 0 else 'male']['looktype'] == look
        for raw in T.fields(self.data)[2]:
            o = T.fields(raw)
            look = T.one(o, 1)
            if look not in {x[1] for x in PICKS}:
                continue
            flags = T.fields(T.one(o, 3, b''))
            reverse = {d: bool(T.one(flags, n, 0)) for d, n in REVERSE_FLAGS.items()}
            assert not any(reverse.values()), f'{look}: reverse addons need a native renderer contract'
            assert set(flags) <= {23, 26}, f'{look}: unsupported rendering flags {set(flags)}'
            shift = T.fields(T.one(flags, 26, b''))
            light = T.fields(T.one(flags, 23, b''))
            model = {'raw': raw, 'shift': (T.one(shift, 1), T.one(shift, 2)),
                     'light': (T.one(light, 1), T.one(light, 2)) if 23 in flags else None,
                     'reverse_addons': reverse, 'groups': {}}
            for gb in o[2]:
                g = T.fields(gb)
                s = T.fields(T.one(g, 3, b''))
                ids = []
                for value in s[5]:
                    if isinstance(value, int):
                        ids.append(value)
                    else:
                        pos = 0
                        while pos < len(value):
                            value_id, pos = T.varint(value, pos)
                            ids.append(value_id)
                nx, ny, nz, layers = [T.one(s, k, 1) for k in [1, 2, 3, 4]]
                assert (nx, ny, layers) == (4, 3, 2), (look, nx, ny, layers)
                assert nz in (1, 2) and len(ids) % (nx * ny * nz * layers) == 0
                nf = len(ids) // (nx * ny * nz * layers)
                animation = T.fields(T.one(s, 6, b''))
                assert max(1, len(animation[6])) == nf
                model['groups'][T.one(g, 1)] = {
                    'nz': nz, 'ids': ids, 'frames': nf, 'bounds': T.one(s, 7, 64),
                    'animation_pb_hex': T.one(s, 6, b'').hex(),
                }
            assert set(model['groups']) == {0, 1}, (look, model['groups'].keys())
            assert model['groups'][1]['frames'] == 8
            self.models[look] = model
        assert len(self.models) == len(PICKS)

    @lru_cache(maxsize=48)
    def sheet(self, i):
        s = self.sheets[i]
        raw = (self.path / s['file']).read_bytes()
        digest = sha(raw)
        expected = self.manifest['sheetHashes'].get(s['file'])
        if expected is not None:
            assert digest == expected, 'Reviewed source sheet changed'
        else:
            # The catalogue uses idle frame 0. Retaining every other original idle
            # frame can load sheets the preview never read; pin and recheck them too.
            self.additional_idle_sheet_hashes[s['file']] = digest
        self.sheet_hashes[s['file']] = digest
        p = raw[32]
        decoder = lzma.LZMADecompressor(format=lzma.FORMAT_RAW, filters=[{
            'id': lzma.FILTER_LZMA1, 'dict_size': int.from_bytes(raw[33:37], 'little'),
            'lc': p % 9, 'lp': (p // 9) % 5, 'pb': p // 45,
        }])
        im = Image.open(io.BytesIO(decoder.decompress(raw[45:]))).convert('RGBA')
        assert im.size == (384, 384)
        im.putdata([(0, 0, 0, 0) if v[:3] == (255, 0, 255) or not v[3] else v
                    for v in im.get_flattened_data()])
        return im

    @lru_cache(maxsize=6000)
    def sprite(self, sid):
        if not sid:
            return Image.new('RGBA', (64, 64))
        i = bisect.bisect_right(self.first, sid) - 1
        s = self.sheets[i]
        assert s['firstspriteid'] <= sid <= s['lastspriteid']
        w, h = SIZES[s['spritetype']]
        assert w <= 64 and h <= 64, 'Unsupported source canvas; never resize or crop it'
        offset = sid - s['firstspriteid']
        x, y = (offset % (384 // w)) * w, (offset // (384 // w)) * h
        tile = self.sheet(i).crop((x, y, x + w, y + h))
        assert {v[3] for v in tile.get_flattened_data()} <= {0, 255}
        im = Image.new('RGBA', (64, 64))
        im.paste(tile, (64 - w, 64 - h))
        return im

    def source_layer(self, look, group, frame, direction, addon, layer):
        g = self.models[look]['groups'][group]
        assert frame < g['frames']
        index = ((((frame * g['nz']) * 3 + addon) * 4 + direction) * 2 + layer)
        return self.sprite(g['ids'][index])

    def layer(self, look, phase, direction, addon, layer):
        group, frame = (0, 0) if phase == 0 else (1, phase - 1)
        g = self.models[look]['groups'][group]
        sid = g['ids'][((((frame * g['nz']) * 3 + addon) * 4 + direction) * 2 + layer)]
        if sid:
            sheet = self.sheets[bisect.bisect_right(self.first, sid) - 1]
            assert sheet['file'] in self.manifest['sheetHashes'], 'A runtime frame was not in the reviewed catalogue'
        return self.source_layer(look, group, frame, direction, addon, layer)

    def verify_unchanged(self):
        assert (self.path / 'catalog-content.json').read_bytes() == self.catalog_data
        assert (self.path / self.appearance_file).read_bytes() == self.data
        for file, digest in self.sheet_hashes.items():
            assert sha((self.path / file).read_bytes()) == digest, 'Concurrent source asset change'


def run(output, apply):
    # All validation precedes runtime mutation. Existing staging folders are never overwritten.
    source = Source()
    output = output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    assert not (ASSET / 'import-manifest.json').exists(), 'This batch already has an import manifest'
    ASSET.mkdir(parents=True, exist_ok=True)
    paths = [ROOT / 'data/things/860/Tibia.dat', ROOT / 'data/things/860/Tibia.spr',
             SERVER / 'data/XML/outfits.xml']
    before = {p: p.read_bytes() for p in paths}
    dat, spr, xml = [before[p] for p in paths]
    rels = {p: (Path('server/data/XML/outfits.xml') if p == paths[2]
                else Path('client/data/things/860') / p.name) for p in paths}
    for p, b in before.items():
        dest = output / 'originals' / rels[p]
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(b)
    things, _ = M.parse_dat(dat)
    old_count, last = M.u16(spr, 4), M.u16(dat, 6)
    assert last == 376 == max(t.client_id for t in things if t.category == 1), 'Unexpected current DAT; re-review allocation'
    current = ET.fromstring(xml)
    registered = {int(n.get('looktype')) for n in current}
    assert not any(n.get('name') in {x[0] for x in PICKS} for n in current), 'Batch already registered'
    targets = list(range(last + 1, last + len(PICKS) + 1))
    assert not registered.intersection(targets)
    tiles, records, definitions = [], [], []
    tile_ids = {bytes(4096): 0}
    source_layers_exported = 0
    for (name, look, sex), target in zip(PICKS, targets):
        model = source.models[look]
        ids = []
        folder = ASSET / 'source' / str(look)
        folder.mkdir(parents=True, exist_ok=False)
        (folder / 'appearance.pb').write_bytes(model['raw'])
        for group, g in model['groups'].items():
            for frame in range(g['frames']):
                for addon in range(3):
                    for direction in range(4):
                        for layer in range(2):
                            source.source_layer(look, group, frame, direction, addon, layer).save(
                                folder / f'g{group}-f{frame}-d{direction}-addon{addon}-layer{layer}.png')
                            source_layers_exported += 1
        # Legacy getSpriteIndex: phase,z,y,x,layer,tileY,tileX. Never flatten addons or masks.
        for phase in range(9):
            for addon in range(3):
                for direction in range(4):
                    for layer in range(2):
                        im = source.layer(look, phase, direction, addon, layer)
                        for h in range(2):
                            for w in range(2):
                                tile = im.crop(((1-w)*32, (1-h)*32, (2-w)*32, (2-h)*32))
                                pixels = tile.tobytes()
                                if pixels not in tile_ids:
                                    tile_ids[pixels] = old_count + len(tiles) + 1
                                    tiles.append(tile)
                                ids.append(tile_ids[pixels])
        attrs = b''
        if model['light'] is not None:
            attrs += b'\x15' + struct.pack('<HH', *model['light'])
        attrs += b'\x18' + struct.pack('<HH', *model['shift']) + b'\xff'
        exact = max(g['bounds'] for g in model['groups'].values())
        assert 0 < exact <= 64
        definitions.append(attrs + bytes([2, 2, exact, 2, 4, 3, 1, 9])
                           + struct.pack(f'<{len(ids)}H', *ids))
        records.append({'name': name, 'source_id': look, 'looktype': target, 'sex': sex,
                        'offer_id': 6005 + len(records), 'addons': 3,
                        'shift': model['shift'], 'light': model['light'],
                        'reverse_addons': model['reverse_addons'], 'exact_size': exact,
                        'layout': [2, 4, 3, 1, 9], 'sprite_slots': len(ids),
                        'source_idle_frames': model['groups'][0]['frames'],
                        'source_walk_frames': model['groups'][1]['frames'],
                        'source_appearance_sha256': sha(model['raw'])})
    assert old_count + len(tiles) <= 65535, 'Legacy 16-bit sprite IDs exhausted'
    delta, old_table = len(tiles) * 4, 6 + old_count * 4
    old_payload = spr[old_table:]
    pointers = [M.u32(spr, 6 + i * 4) for i in range(old_count)]
    shifted = [p + delta if p else 0 for p in pointers]
    payloads = [M.encode_sprite(im) for im in tiles]
    pos, new_pointers = len(spr) + delta, []
    for payload in payloads:
        new_pointers.append(pos)
        pos += len(payload)
    new_spr = (spr[:4] + struct.pack('<H', old_count + len(tiles))
               + struct.pack(f'<{old_count + len(tiles)}I', *(shifted + new_pointers))
               + old_payload + b''.join(payloads))
    assert new_spr[old_table + delta:old_table + delta + len(old_payload)] == old_payload
    for i, old_pointer in enumerate(pointers):
        assert M.u32(new_spr, 6 + i * 4) == (old_pointer + delta if old_pointer else 0)
    end = next(t.end for t in things if t.category == 1 and t.client_id == last)
    new_dat = bytearray(dat[:end] + b''.join(definitions) + dat[end:])
    struct.pack_into('<H', new_dat, 6, last + len(PICKS))
    new_dat = bytes(new_dat)
    parsed, _ = M.parse_dat(new_dat)
    old = {(t.category, t.client_id): dat[t.start:t.end] for t in things}
    for t in parsed:
        if (t.category, t.client_id) in old:
            assert new_dat[t.start:t.end] == old[t.category, t.client_id]
    assert len(parsed) == len(things) + len(PICKS)
    compared = 0
    for record in records:
        t = next(t for t in parsed if t.category == 1 and t.client_id == record['looktype'])
        index = 0
        for phase in range(9):
            for addon in range(3):
                for direction in range(4):
                    for layer in range(2):
                        image = Image.new('RGBA', (64, 64))
                        for h in range(2):
                            for w in range(2):
                                tile = M.sprite_image(new_spr, t.sprites[index])
                                index += 1
                                image.paste(tile, ((1-w)*32, (1-h)*32))
                                compared += 1
                        assert image.tobytes() == source.layer(
                            record['source_id'], phase, direction, addon, layer).tobytes()
        assert index == len(t.sprites)
    newline = b'\r\n' if b'\r\n' in xml else b'\n'
    new_xml = xml
    for sex, marker in [(0, b'\t<!-- Female outfits -->'), (1, b'\t<!-- Male outfits -->')]:
        assert xml.count(marker) == 1
        lines = [f'\t<outfit type="{sex}" looktype="{r["looktype"]}" name="{r["name"]}" premium="no" unlocked="no" enabled="yes" />'.encode()
                 for r in records if r['sex'] == sex]
        new_xml = new_xml.replace(marker, marker + newline + newline.join(lines))
    assert [n.attrib for n in ET.fromstring(new_xml) if int(n.get('looktype')) not in targets] == [n.attrib for n in current]
    outputs = dict(zip(paths, [new_dat, new_spr, new_xml]))
    for p, b in outputs.items():
        dest = output / 'staged' / rels[p]
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(b)
    source.verify_unchanged()
    manifest = {
        'status': 'staged', 'outfits': records, 'source_version': source.manifest['sourceVersion'],
        'original_sprites': old_count, 'added_sprites': len(tiles),
        'source_tile_slots_compared': compared, 'source_layers_exported': source_layers_exported,
        'unrelated_DAT_records_byte_exact': len(old), 'all_original_SPR_payload_bytes_preserved': True,
        'all_original_SPR_sprite_pointer_targets_preserved': True,
        'source_catalog_sha256': sha(source.catalog_data), 'source_appearance_sha256': sha(source.data),
        'source_sheet_sha256': source.sheet_hashes,
        'additional_source_idle_sheet_sha256': source.additional_idle_sheet_hashes,
        'legacy_animation': 'Idle source group 0 phase 0; all eight original unmounted walk frames. All original idle/walk source layers are retained as PNGs; modern idle animation, source timing and mounted patterns are not imported into legacy DAT.',
        'input_sha256': {str(p): sha(b) for p, b in before.items()},
        'output_sha256': {str(p): sha(b) for p, b in outputs.items()},
        'output_directory': str(output),
    }
    manifest_path = output / 'manifest.json'
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
    if apply:
        for p, b in before.items():
            assert p.read_bytes() == b, f'Concurrent runtime source modification: {p}'
        for p in paths:
            # Recheck each destination as well; a concurrent edit never gets silently overwritten.
            assert p.read_bytes() == before[p], f'Concurrent runtime source modification: {p}'
            p.write_bytes(outputs[p])
        for p, b in outputs.items():
            assert p.read_bytes() == b
        manifest['status'] = 'Applied locally; native rendering, gameplay and package checks pending'
        manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
    shutil.copyfile(manifest_path, ASSET / 'import-manifest.json')
    print(json.dumps({k: manifest[k] for k in ['status', 'outfits', 'added_sprites',
                                             'source_tile_slots_compared', 'unrelated_DAT_records_byte_exact']}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    run(args.output, args.apply)
