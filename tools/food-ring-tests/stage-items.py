"""Stage both native timed states with the approved unchanged Food Ring sprite."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import subprocess
import sys
import os

ROOT = Path(__file__).resolve().parents[2]
SERVER = ROOT.parent / 'Rookhaven'
sys.path.insert(0, str(ROOT / 'tools'))
import item_assets as m


def install(source, destination):
    # A desktop diff may map the old file. Replace its directory entry rather
    # than truncate the mapped file, which Windows rejects with error1224.
    temporary = destination.with_name(destination.name + '.food-ring-install-tmp')
    assert not temporary.exists(), temporary
    shutil.copyfile(source, temporary)
    os.replace(temporary, destination)

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
    asset = ROOT / 'assets/items/food-ring' / state
    output = work / state
    result = subprocess.run([sys.executable, 'C:/Users/marcu/.codex/skills/rookhaven-items/scripts/stage_item.py',
        '--client', str(ROOT), '--server', str(SERVER), '--definition', str(asset / 'definition.json'),
        '--image', str(asset / 'sprite.png'), '--output', str(output), '--mode', 'add'], capture_output=True, text=True)
    assert result.returncode == 0, result.stdout + result.stderr
    manifest = json.loads((output / 'manifest.json').read_text())
    for key, path in paths.items():
        assert hashlib.sha256(path.read_bytes()).hexdigest() == manifest['source_files'][key], 'Source changed during staging: '+key
    for key, path in paths.items(): install(output / key, path)
    shutil.copyfile(output / 'manifest.json', asset / 'import-manifest.json')
    print(json.dumps({'state':state,'sid':manifest['server_id'],'cid':manifest['client_id'],'sprite':manifest['sprite_id']}))
