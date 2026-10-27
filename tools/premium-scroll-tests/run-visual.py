"""Offline native art check with an existing pre-integrity QA renderer only."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import zipfile
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--renderer', type=Path, required=True, help='Existing pre-integrity QA package directory')
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
run = args.output.resolve(); run.mkdir(parents=True, exist_ok=False)
for p in args.renderer.iterdir():
    if p.is_file(): shutil.copyfile(p, run / p.name)
encrypt = run / 'encrypt'; encrypt.mkdir()
for name in ('RookhavenClient.exe', 'libEGL.dll', 'libGLESv2.dll', 'd3dcompiler_47.dll'):
    shutil.copyfile(run / name, encrypt / name)
folder = encrypt / 'data/things/860'; folder.mkdir(parents=True)
for name in ('Tibia.dat', 'Tibia.spr'): shutil.copyfile(ROOT / 'data/things/860' / name, folder / name)
(encrypt / 'data/test.lua').write_text('return true\n')
r = subprocess.run([str(encrypt / 'RookhavenClient.exe'), '--encrypt-data'], cwd=encrypt,
                   capture_output=True, creationflags=subprocess.CREATE_NO_WINDOW, timeout=30)
assert r.returncode == 0
with zipfile.ZipFile(run / 'data.zip') as z:
    entries = {n: z.read(n) for n in z.namelist() if n not in ('init.lua', 'init.luac', 'test.lua', 'test.luac')}
entries['init.lua'] = Path(__file__).with_name('native-visual.lua').read_bytes()
entries['test.lua'] = (encrypt / 'data/test.lua').read_bytes()
for name in ('Tibia.dat', 'Tibia.spr'):
    data = (folder / name).read_bytes(); assert data.startswith(b'ENC3')
    entries['data/things/860/' + name] = data
with zipfile.ZipFile(run / 'data.zip', 'w', zipfile.ZIP_DEFLATED) as z:
    for name, data in entries.items(): z.writestr(name, data)
profile = Path(os.environ['APPDATA']) / 'Rookhaven Client/Rookhaven-LocalPassives-Probe'
assert profile.is_dir()
busy = subprocess.run(['powershell.exe', '-NoProfile', '-Command',
    "Get-CimInstance Win32_Process -Filter \"Name='RookhavenClient.exe'\" | Where-Object { $_.CommandLine -match '--local-passives' } | Select-Object -ExpandProperty ProcessId"],
    capture_output=True, text=True, creationflags=subprocess.CREATE_NO_WINDOW, check=True)
assert not busy.stdout.strip(), 'Shared probe profile is in use'
backup = run / 'profile-before'; shutil.copytree(profile, backup)


def digest(path):
    return {str(p.relative_to(path)): hashlib.sha256(p.read_bytes()).hexdigest() for p in path.rglob('*') if p.is_file()}


before = digest(profile)
report = {'status': 'FAIL', 'scope': 'Offline pre-integrity QA renderer; does not certify a distributed client package'}
try:
    with (run / 'stdout.log').open('wb') as out, (run / 'stderr.log').open('wb') as err:
        r = subprocess.run([str(run / 'RookhavenClient.exe'), '--local-passives', '--test'], cwd=run,
                           stdout=out, stderr=err, creationflags=subprocess.CREATE_NO_WINDOW, timeout=20)
    log = (run / 'stdout.log').read_text(errors='replace') + (run / 'stderr.log').read_text(errors='replace')
    print(log[-3000:])
    assert r.returncode == 0 and 'PREMIUM_SCROLL_RENDER_OK' in log
    shutil.copyfile(profile / 'premium-scroll-owned-render.png', run / 'native-render.png')
    Image.open(run / 'native-render.png').crop((12, 12, 208, 76)).save(run / 'native-client-cutout.png')
    report['status'] = 'PASS'
finally:
    # Restore exactly the named probe profile; originals stay in the owned output.
    for p in profile.rglob('*'):
        if p.is_file() and str(p.relative_to(profile)) not in before: p.unlink()
    for p in backup.rglob('*'):
        if p.is_file(): shutil.copyfile(p, profile / p.relative_to(backup))
    report['profile_restored'] = before == digest(profile)
    (run / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report))
assert report['profile_restored']
