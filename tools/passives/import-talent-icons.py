"""Import or verify the approved native talent PNGs without changing spell art.

Without --write this only verifies tracked assets and the current pure-Lua catalog.
The PNG at each runtime path is also its canonical authoring source.
"""
from pathlib import Path
import argparse
import copy
import ctypes
import hashlib
import json
import os
import re
import shutil
from PIL import Image

CLIENT = Path(__file__).resolve().parents[2]
SERVER = CLIENT.parent / 'Rookhaven'
STUDY = CLIENT / 'out/passive-icon-study-20261028'
MANIFEST = CLIENT / 'assets/passives/talents-manifest.json'
LEGACY = CLIENT / 'assets/passives/manifest.json'
CATALOG = SERVER / 'data/lib/passives/test.lua'
SPELL_CONFIG = SERVER / 'data/lib/class_spells/config.lua'
TREES = ('reaver', 'blademaster', 'earthshaker', 'marksman', 'arcanist', 'lifekeeper')
OLD = b"icon='/images/game/passives/'..glyph"
NEW = b"icon='/images/game/passives/talent_'..treeId..'_'..id"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def png_properties(path):
    with Image.open(path) as image:
        assert image.format == 'PNG' and image.size == (32, 32), str(path)
        pixels = image.convert('RGBA')
    assert set(pixels.getchannel('A').get_flattened_data()) <= {0, 255}, str(path)
    for box in ((0,0,32,2), (0,30,32,32), (0,2,2,30), (30,2,32,30)):
        assert pixels.crop(box).getchannel('A').getbbox() is None, str(path)
    visible = bytes(channel for pixel in pixels.get_flattened_data()
                    for channel in (pixel if pixel[3] else (0,0,0,0)))
    colors = len({p[:3] for p in pixels.get_flattened_data() if p[3]})
    assert colors <= 50, (str(path), colors)
    return colors, hashlib.sha256(visible).hexdigest()


def catalog(dll_path):
    """Evaluate catalog/config tables only; no game objects, connections or DB."""
    previous = Path.cwd()
    try:
        os.chdir(SERVER)
        with os.add_dll_directory(str(dll_path.parent)):
            lua = ctypes.CDLL(str(dll_path))
            lua.luaL_newstate.restype = ctypes.c_void_p
            lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
            lua.luaL_loadstring.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
            lua.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
            lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
            lua.lua_tolstring.restype = ctypes.c_char_p
            lua.lua_close.argtypes = [ctypes.c_void_p]
            state = lua.luaL_newstate()
            assert state
            try:
                lua.luaL_openlibs(state)
                prefix = CATALOG.read_bytes().decode('utf-8').split('function P.state(player)', 1)[0]
                prefix = prefix.replace("dofile('data/lib/passives/class_choice.lua')", '-- unrelated class-choice loading excluded', 1)
                code = "dofile('data/lib/core/json.lua');\n" + prefix
                code += "\nreturn json.encode({trees=PassiveTest.trees,configs=PassiveTest.configs,order=PassiveTest.order,spells=dofile('data/lib/class_spells/config.lua')})"
                error = lua.luaL_loadstring(state, code.encode()) or lua.lua_pcall(state, 0, 1, 0)
                text = lua.lua_tolstring(state, -1, None).decode('utf-8')
                assert not error, text
                return json.loads(text)
            finally:
                lua.lua_close(state)
    finally:
        os.chdir(previous)


def legacy_snapshot():
    data = json.loads(LEGACY.read_text())
    assert len(data['icons']) == 108
    result = {}
    for row in data['icons']:
        path = CLIENT / row['runtime']
        assert sha(path) == row['sha256'], 'Legacy icon changed: ' + row['id']
        result[row['runtime']] = row['sha256']
    result['assets/passives/manifest.json'] = sha(LEGACY)
    result[str(SPELL_CONFIG)] = sha(SPELL_CONFIG)
    return result


def pilot_provenance(entry, source):
    slug = entry.get('approvedId', entry['id'].removeprefix('cap_'))
    round_dir = source.parent.parent
    if slug in ('aftershock', 'conduit', 'deadeye'):
        info = json.loads((round_dir / 'selection.json').read_text())
        row = next(x for x in info['proposals'] if x['id'] == slug)
        return {'jobId':row['jobId'], 'nativeSourceSha256':row['sourceSha256'],
                'generatedPixels':row.get('generatedPixels', info.get('generatedPixels'))}
    path = round_dir / ('fit-generation-manifest.json' if slug == 'bloodguard' else 'generation-manifest.json')
    row = next(x for x in json.loads(path.read_text())['submissions'] if x['id'] == slug)
    text = json.dumps(row['submission'])
    match = re.search(r'job_id:\s*([a-f0-9-]{36})', text) or re.search(r'"job_id":\s*"([a-f0-9-]{36})"', text)
    assert match, 'Missing pilot job: ' + slug
    raw = round_dir / 'generated-28' / (slug + '.png')
    return {'jobId':match.group(1), 'nativeSourceSha256':sha(raw), 'generatedPixels':[28,28]}


def selections(directory):
    records, inputs = [], {}
    for tree in TREES:
        selection_file = directory / tree / 'selection.json'
        selection = json.loads(selection_file.read_text())
        assert len(selection['icons']) == 29
        for row in selection['icons']:
            source = Path(row['output']).resolve()
            assert source.is_relative_to(CLIENT)
            assert row['tree'] == tree and sha(source) == row['outputSha256']
            identifier = row['id']
            assert re.fullmatch('[a-z_]+', identifier)
            runtime = 'data/images/game/passives/talent_' + tree + '_' + identifier + '.png'
            colors, visible = png_properties(source)
            assert not (CLIENT / runtime).exists() or sha(CLIENT / runtime) == row['outputSha256'], 'Unrelated target file exists: ' + runtime
            provenance = {'provider':'PixelLab', 'jobId':row.get('jobId'),
                          'nativeSourceSha256':row.get('sourceSha256'), 'generatedPixels':row.get('generatedPixels')}
            if not provenance['jobId']: provenance.update(pilot_provenance(row, source))
            assert provenance['jobId']
            records.append({'key':tree + '/' + identifier, 'tree':tree, 'nodeId':identifier,
                            'name':row['name'], 'runtime':runtime, 'authoringSource':runtime,
                            'sha256':row['outputSha256'], 'visiblePixelsSha256':visible,
                            'size':[32,32], 'opaqueColors':colors, 'provenance':provenance})
            inputs[runtime] = source
    assert len(records) == len({r['key'] for r in records}) == 174
    assert len({r['visiblePixelsSha256'] for r in records}) == 174
    return records, inputs


def check_catalog(data, records):
    expected = {row['key']:row for row in records}
    paths = []
    for tree in TREES:
        nodes = data['trees'][tree]['nodes']
        assert len(nodes) == 29
        for node in nodes:
            row = expected[tree + '/' + node['id']]
            path = '/images/game/passives/' + Path(row['runtime']).stem
            assert node['icon'] == path and re.fullmatch('/images/game/passives/[a-z_]+', path)
            assert sha(CLIENT / row['runtime']) == row['sha256']
            assert node['name'] == row['name']
            paths.append(path)
    assert len(paths) == len(set(paths)) == 174


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true', help='Import explicitly approved selections and update only catalog icon paths.')
    parser.add_argument('--selections', type=Path, default=STUDY/'unique-01')
    parser.add_argument('--lua-dll', type=Path, default=CLIENT/'out/boat-pass-20261025/ingame-01/runtime/lua51.dll')
    parser.add_argument('--receipt', type=Path)
    args = parser.parse_args()
    dll = args.lua_dll.resolve()
    assert dll.is_file(), 'Supply an existing standalone Lua51 DLL with --lua-dll.'
    preserved = legacy_snapshot()
    before = catalog(dll)
    if args.write:
        assert not MANIFEST.exists(), 'Use verification for an existing import; preserve its approval manifest.'
        records, inputs = selections(args.selections.resolve())
        original = CATALOG.read_bytes()
        assert original.count(OLD) == 1 and NEW not in original
        for row in records: shutil.copyfile(inputs[row['runtime']], CLIENT/row['runtime'])
        CATALOG.write_bytes(original.replace(OLD, NEW, 1))
        after = catalog(dll)
        old_copy, new_copy = copy.deepcopy(before), copy.deepcopy(after)
        changes = []
        for tree in TREES:
            for old, new in zip(old_copy['trees'][tree]['nodes'], new_copy['trees'][tree]['nodes']):
                assert old['id'] == new['id'] and old['icon'] != new['icon']
                changes.append({'tree':tree, 'nodeId':old['id'], 'before':old.pop('icon'), 'after':new.pop('icon')})
        assert old_copy == new_copy and len(changes) == 174, 'Unexpected catalog gameplay/metadata change.'
        manifest = {'version':1, 'description':'Approved unique PixelLab art for all six passive talent catalogs.',
                    'iconCount':174, 'nodesPerTree':29, 'nativePixels':[32,32], 'safeBorderPixels':2,
                    'binaryAlpha':True, 'canonicalAuthoringSource':'Each tracked runtime PNG; no regeneration or duplicate source copy.',
                    'legacyManifest':'assets/passives/manifest.json', 'legacyManifestSha256':sha(LEGACY),
                    'classSpellConfigSha256':sha(SPELL_CONFIG), 'icons':records}
        MANIFEST.write_text(json.dumps(manifest, indent=2, ensure_ascii=False)+'\n', encoding='utf-8')
    else:
        manifest = json.loads(MANIFEST.read_text())
        records = manifest['icons']
        assert len(records) == manifest['iconCount'] == 174
        assert sha(LEGACY) == manifest['legacyManifestSha256'] and sha(SPELL_CONFIG) == manifest['classSpellConfigSha256']
        after, changes = before, []
    for row in records:
        colors, visible = png_properties(CLIENT/row['runtime'])
        assert colors == row['opaqueColors'] and visible == row['visiblePixelsSha256']
    check_catalog(after, records)
    assert legacy_snapshot() == preserved, 'Legacy spell source or art changed.'
    spell_paths = {row['icon'] for row in after['spells']['spells']}
    assert len(after['spells']['spells']) == 12 and len(spell_paths) == 11
    receipt = {'status':'PASS', 'mode':'import' if args.write else 'verify', 'nodeIcons':174,
               'uniqueVisibleDesigns':len({r['visiblePixelsSha256'] for r in records}),
               'legacyPngsPreserved':108, 'classSpellCatalogUnchanged':before['spells']==after['spells'],
               'legacySpellPaths':sorted(spell_paths), 'catalogChangesOnlyNodeIcon':True if args.write else None,
               'changedNodeIconCount':len(changes), 'mappingChanges':changes,
               'preservedLegacyHashes':preserved, 'manifestSha256':sha(MANIFEST),
               'catalogSourceSha256':sha(CATALOG), 'nativeGameOrServicesStarted':False}
    if args.receipt:
        assert args.receipt.resolve().is_relative_to(CLIENT/'out')
        args.receipt.parent.mkdir(parents=True, exist_ok=True)
        assert not args.receipt.exists(), 'Preserve previous evidence.'
        args.receipt.write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:v for k,v in receipt.items() if k not in ('mappingChanges','preservedLegacyHashes')},indent=2))


if __name__ == '__main__':
    main()
