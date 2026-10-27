"""Use the standard static importer, adding light only to the new active record."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import struct
import subprocess
import sys
import base64

ROOT = Path(__file__).resolve().parents[2]
SERVER = ROOT.parent / 'Rookhaven'
sys.path.insert(0, str(ROOT / 'tools'))
import item_assets as m


def install(source, destination):
    if sys.platform != 'win32':
        shutil.copyfile(source, destination)
        return
    # PowerShell handles replacing a file currently mapped by the desktop diff
    # viewer; Python's truncate/resize path fails with Windows error1224.
    src, dst = str(source).replace("'", "''"), str(destination).replace("'", "''")
    command = "$ErrorActionPreference='Stop'; Copy-Item -LiteralPath '" + src + "' -Destination '" + dst + "' -Force"
    encoded = base64.b64encode(command.encode('utf-16le')).decode('ascii')
    subprocess.run(['powershell.exe', '-NoProfile', '-EncodedCommand', encoded], check=True, capture_output=True)

parser = argparse.ArgumentParser()
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
work = args.output.resolve(); work.mkdir(parents=True, exist_ok=False)
paths = {'client/data/things/860/Tibia.dat': ROOT / 'data/things/860/Tibia.dat',
         'client/data/things/860/Tibia.spr': ROOT / 'data/things/860/Tibia.spr',
         'server/data/items/items.otb': SERVER / 'data/items/items.otb',
         'server/data/items/items.xml': SERVER / 'data/items/items.xml'}
for key, path in paths.items():
    dest = work / 'originals' / key; dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(path, dest)

for state in ('unequipped', 'equipped'):
    asset = ROOT / 'assets/items/light-ring' / state
    output = work / state
    result = subprocess.run([sys.executable, 'C:/Users/marcu/.codex/skills/rookhaven-items/scripts/stage_item.py',
        '--client', str(ROOT), '--server', str(SERVER), '--definition', str(asset / 'definition.json'),
        '--image', str(asset / 'sprite.png'), '--output', str(output), '--mode', 'add'], capture_output=True, text=True)
    assert result.returncode == 0, result.stdout + result.stderr
    manifest = json.loads((output / 'manifest.json').read_text())
    if state == 'equipped':
        dat_path = output / 'client/data/things/860/Tibia.dat'
        otb_path = output / 'server/data/items/items.otb'
        dat, otb = dat_path.read_bytes(), otb_path.read_bytes()
        things, _ = m.parse_dat(dat)
        target = next(t for t in things if t.category == 0 and t.client_id == manifest['client_id'])
        assert dat[target.start:target.sprite_start] == bytes([16,255,1,1,1,1,1,1,1])
        # Native torch SID2051 uses level7, colour206. A static sprite needs
        # neither its animation flag nor extra frames.
        lit = dat[:target.start+1] + bytes([21,7,0,206,0]) + dat[target.start+1:]
        lit_things, _ = m.parse_dat(lit)
        before = {(t.category,t.client_id):dat[t.start:t.end] for t in things}
        for t in lit_things:
            if (t.category,t.client_id) != (0,manifest['client_id']):
                assert before[t.category,t.client_id] == lit[t.start:t.end]
        tree = m.parse_otb(otb); nodes = m.item_nodes(tree); node = nodes[manifest['server_id']]
        attrs = m.attributes(node); assert 0x2a not in attrs
        torch = m.attributes(nodes[2051])[0x2a]; assert torch == struct.pack('<HH',7,206)
        node.props += bytes([0x2a]) + struct.pack('<H',len(torch)) + torch
        lit_otb = otb[:4] + m.write_node(tree)
        new_nodes = m.item_nodes(m.parse_otb(lit_otb))
        original_nodes = m.item_nodes(m.parse_otb(otb))
        for sid, old in original_nodes.items():
            if sid != manifest['server_id']: assert m.write_node(old) == m.write_node(new_nodes[sid])
        dat_path.write_bytes(lit); otb_path.write_bytes(lit_otb)
        manifest['light'] = {'level':7,'color':206,'reference_sid':2051,'static_sprite':True}
        for key in ('client/data/things/860/Tibia.dat','server/data/items/items.otb'):
            manifest['files'][key] = hashlib.sha256((output / key).read_bytes()).hexdigest()
        (output / 'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    for key, path in paths.items():
        assert hashlib.sha256(path.read_bytes()).hexdigest() == manifest['source_files'][key], 'Source changed during staging: '+key
    for key, path in paths.items(): install(output / key, path)
    shutil.copyfile(output / 'manifest.json', asset / 'import-manifest.json')
    print(json.dumps({'state':state,'sid':manifest['server_id'],'cid':manifest['client_id'],'sprite':manifest['sprite_id'],'light':manifest.get('light')}))
