"""Current native shop animation and Try On verification in a disposable loopback runtime.

Requires a fresh current QA client and the current source-matched server engine.
No public service, source database or user profile is kept modified.
"""
from pathlib import Path
import argparse
import base64
import hashlib
import json
import os
import re
import shutil
import socket
import subprocess
import time
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[2]
SERVER = ROOT.parent / 'Rookhaven'
LOCAL = ROOT / 'out/local-server'
parser = argparse.ArgumentParser()
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--client-package', type=Path, required=True)
parser.add_argument('--engine-package', type=Path, required=True)
args = parser.parse_args()
run = args.output.resolve(); run.mkdir(parents=True, exist_ok=False)
runtime, database, client = run / 'runtime', run / 'database', run / 'client'
source_db, source_config = LOCAL / 'passives-db', LOCAL / 'passives-runtime/config.lua'
db_bin = LOCAL / 'mariadb-11.4.9-winx64/bin'
profile = Path(os.environ['APPDATA']) / 'Rookhaven Client/Rookhaven-LocalPassives-Probe'
processes, handles = [], []
report = {'status':'FAIL','scope':'Fresh current QA client, current source-matched server, actual native shop and outfit controls'}


def digest(path):
    return {str(p.relative_to(path)):hashlib.sha256(p.read_bytes()).hexdigest() for p in path.rglob('*') if p.is_file()}


def start(exe, arguments, name, cwd):
    out, err = (run / (name+'-stdout.log')).open('wb'), (run / (name+'-stderr.log')).open('wb')
    handles.extend((out,err))
    startup = subprocess.STARTUPINFO(); startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW; startup.wShowWindow = 0
    p = subprocess.Popen([str(exe),*arguments],cwd=cwd,stdout=out,stderr=err,
                         creationflags=subprocess.CREATE_NO_WINDOW,startupinfo=startup)
    processes.append(p); return p


def log(name):
    p = run / (name+'-stdout.log')
    return p.read_text(errors='replace') if p.exists() else ''


try:
    for port in (33313,7185,7186):
        with socket.socket() as s:s.bind(('127.0.0.1',port))
    check = subprocess.run(['powershell.exe','-NoProfile','-Command',
        "Get-CimInstance Win32_Process | Where-Object { ($_.Name -eq 'mariadbd.exe' -and $_.CommandLine -like '*passives-db*') -or ($_.Name -eq 'RookhavenClient.exe' -and $_.CommandLine -like '*--local-passives*') } | Select-Object -ExpandProperty ProcessId"],
        capture_output=True,text=True,check=True,creationflags=subprocess.CREATE_NO_WINDOW)
    assert not check.stdout.strip(),'Owned source DB/profile is in use'
    db_before, config_before = digest(source_db), source_config.read_bytes()
    profile_before = digest(profile); shutil.copytree(profile,run/'profile-before')
    shutil.copytree(source_db,database)
    shutil.copytree(SERVER/'data',runtime/'data')
    native_hashes=json.loads((ROOT/'assets/items/boat-pass/native-source-hashes.json').read_text())
    for path,want in native_hashes.items():assert hashlib.sha256((SERVER/path).read_bytes()).hexdigest()==want,path
    report['native_server_source_files_matched']=len(native_hashes)
    # This old runtime includes an unrelated historical startup assertion for
    # its original server name. Disable that fixture only in this private copy.
    obsolete=runtime/'data/scripts/quiver_weight_startup.lua'
    if obsolete.exists():obsolete.rename(obsolete.with_name('#quiver_weight_startup.lua'))
    shutil.copyfile(LOCAL/'passives-runtime/key.pem',runtime/'key.pem')
    with zipfile.ZipFile(args.engine_package) as z:z.extractall(runtime)
    shutil.copyfile(runtime/'premium-scroll-qa.exe',runtime/'tfs-visual-qa.exe')
    report['visual_engine_sha256']=hashlib.sha256((runtime/'tfs-visual-qa.exe').read_bytes()).hexdigest()
    # Keep runtime assets and all shop handlers identical to the current source.
    for relative in ['data/XML/outfits.xml','data/lib/game_shop_config.lua','data/lib/core/game_shop.lua','data/items/items.otb']:
        shutil.copyfile(SERVER/relative,runtime/relative)
    for name,look in [('Rune Female',373),('Lion Male',376),('Lion Female',375)]:
        (runtime/('data/npc/'+name+' Preview.xml')).write_text(f'<npc name="{name}" speed="0" walkinterval="0" walkradius="0"><health now="100" max="100"/><look type="{look}" head="58" body="49" legs="2" feet="58" addons="3"/></npc>')
    config=config_before.decode('utf-8-sig').replace('mysqlPort = 33308','mysqlPort = 33313').replace('loginProtocolPort = 7174','loginProtocolPort = 7185').replace('statusProtocolPort = 7174','statusProtocolPort = 7185').replace('gameProtocolPort = 7175','gameProtocolPort = 7186').replace('Rookhaven Local Passives Test','Rookhaven Modern Outfit Visual QA')
    assert 'ip = "127.0.0.1"' in config and 'enforceClientChecksums = true' in config
    config+='\nfreePremium = false\nhouseRentPeriod = "never"\noptimizeDatabaseAtStartup = false\n'
    assert 'passiveTestEnabled = true' in config
    (runtime/'data/client_integrity_expected.txt').write_text('a'*64+'\n'+'b'*64+'\n')
    (runtime/'config.lua').write_text(config)
    shutil.copyfile(Path(__file__).with_name('shop-server.lua'),runtime/'data/scripts/modern-outfits-visual-owned.lua')
    shutil.copytree(args.client_package.resolve(),client)
    report['qa_client_sha256']=hashlib.sha256((client/'RookhavenClient.exe').read_bytes()).hexdigest()
    encrypt=client/'encrypt';encrypt.mkdir();(encrypt/'data/things/860').mkdir(parents=True)
    for binary in client.iterdir():
        if binary.is_file() and binary.suffix.lower() in ('.exe','.dll'):shutil.copyfile(binary,encrypt/binary.name)
    for module in ('game_shop','game_outfit'):shutil.copytree(ROOT/'modules'/module,encrypt/'modules'/module)
    for name in ('Tibia.dat','Tibia.spr'):shutil.copyfile(ROOT/'data/things/860'/name,encrypt/'data/things/860'/name)
    (encrypt/'data/test.lua').write_text('T()\n')
    shutil.copyfile(Path(__file__).with_name('shop-visual.lua'),encrypt/'data/shop-visual.lua')
    subprocess.run([str(encrypt/'RookhavenClient.exe'),'--encrypt-data'],cwd=encrypt,
                   capture_output=True,check=True,creationflags=subprocess.CREATE_NO_WINDOW,timeout=35)
    with zipfile.ZipFile(client/'data.zip') as z:entries={n:z.read(n) for n in z.namelist()}
    original='init.luac' if 'init.luac' in entries else 'init.lua'
    entries['startup_original'+Path(original).suffix]=entries.pop(original)
    entries['init.lua']=b"function T() dofile('/shop-visual.lua') end\nreturn dofile('/startup_original.lua')\n"
    entries['test.lua']=(encrypt/'data/test.lua').read_bytes()
    entries['shop-visual.lua']=(encrypt/'data/shop-visual.lua').read_bytes()
    for name in ('Tibia.dat','Tibia.spr'):entries['data/things/860/'+name]=(encrypt/'data/things/860'/name).read_bytes()
    for module in ('game_shop','game_outfit'):
        prefix='modules/'+module+'/'
        entries={name:value for name,value in entries.items() if not name.startswith(prefix)}
        for file in (encrypt/'modules'/module).rglob('*'):
            if file.is_file():entries[file.relative_to(encrypt).as_posix()]=file.read_bytes()
    report['current_module_sources_overlaid']=['game_shop','game_outfit']
    with zipfile.ZipFile(client/'data.zip','w',zipfile.ZIP_DEFLATED) as z:
        for n,b in entries.items():z.writestr(n,b)
    subprocess.run(['python',str(ROOT/'tools/passives/package-checksums.py'),str(client/'data.zip'),str(runtime/'data/checksum_expected.txt')],check=True,capture_output=True)
    env=os.environ.copy();env['MYSQL_PWD']=re.search(r'mysqlPass\s*=\s*"([^"]+)"',config).group(1)
    user=re.search(r'mysqlUser\s*=\s*"([^"]+)"',config).group(1)
    def sql(query):
        return subprocess.run([str(db_bin/'mariadb.exe'),'--no-defaults','--host=127.0.0.1','--port=33313','--user='+user,'--database=rookhaven_passives_test','--batch','--skip-column-names','--execute='+query],env=env,capture_output=True,text=True,check=True,creationflags=subprocess.CREATE_NO_WINDOW).stdout
    db=start(db_bin/'mariadbd.exe',['--no-defaults','--datadir='+str(database),'--bind-address=127.0.0.1','--port=33313','--skip-name-resolve','--console'],'database',runtime)
    end=time.monotonic()+25
    while True:
        assert db.poll() is None,'Owned DB exited'
        try:sql('SELECT 1');break
        except subprocess.CalledProcessError:assert time.monotonic()<end;time.sleep(.2)
    password=hashlib.sha1(b'ModernOutfitLoopbackOnly').hexdigest()
    sql("UPDATE accounts SET name='modernoutfitqa',password='"+password+"',type=1,premium_ends_at=0 WHERE id=9001; UPDATE players SET sex=1,group_id=1,health=150,healthmax=150,mana=100,manamax=100,cap=10000,posx=32097,posy=32219,posz=7 WHERE id=9001; DELETE FROM player_items WHERE player_id=9001; DELETE FROM player_spells WHERE player_id=9001 AND name IN ('Keychain Consume','Keychain Unlock','Keychain List');")
    server=start(runtime/'tfs-visual-qa.exe',[],'server',runtime)
    end=time.monotonic()+35
    while 'Server Online!' not in log('server'):
        assert server.poll() is None,'Visual server exited: '+log('server')[-5000:]
        assert time.monotonic()<end,'Visual server startup timeout: '+log('server')[-5000:];time.sleep(.2)
    app=start(client/'RookhavenClient.exe',['--local-passives','--test'],'client',client)
    assert app.wait(timeout=100)==0,'Client failed: '+log('client')[-4000:]
    assert 'SHOP_NATIVE_OK' in log('client') and 'MODERN_VISUAL_SERVER_READY' in log('server'),log('client')[-6000:]+'\n'+log('server')[-3000:]
    for screenshot in profile.glob('shop-native-*.png'):shutil.copyfile(screenshot,run/screenshot.name)
    report.update(status='PASS',shop_offers=4,native_animated_widgets=True,try_on_read_only=True,categories_reopened=True)
finally:
    for p in reversed(processes):
        if p.poll() is None:p.terminate();p.wait(timeout=15)
    for handle in handles:handle.close()
    if 'profile_before' in globals():
        for p in profile.rglob('*'):
            if p.is_file() and str(p.relative_to(profile)) not in profile_before:p.unlink()
        for p in (run/'profile-before').rglob('*'):
            if p.is_file():
                target=profile/p.relative_to(run/'profile-before');target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,target)
        report['profile_restored']=digest(profile)==profile_before
    if 'db_before' in globals():report['source_database_and_config_unchanged']=digest(source_db)==db_before and source_config.read_bytes()==config_before
    report['owned_processes_stopped']=all(p.poll() is not None for p in processes)
    (run/'result.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
assert report['profile_restored'] and report['source_database_and_config_unchanged']
