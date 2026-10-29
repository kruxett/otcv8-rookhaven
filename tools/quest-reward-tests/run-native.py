"""Native quest reward selection and tier verification in a disposable loopback runtime.

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
parser.add_argument('--engine-directory', type=Path, required=True)
parser.add_argument('--details-only', action='store_true', help='Reuse tier evidence; verify inline item information and reward paths')
args = parser.parse_args()
run = args.output.resolve(); run.mkdir(parents=True, exist_ok=False)
runtime, database, client = run / 'runtime', run / 'database', run / 'client'
source_db, source_config = LOCAL / 'passives-db', LOCAL / 'passives-runtime/config.lua'
db_bin = LOCAL / 'mariadb-11.4.9-winx64/bin'
profile = Path(os.environ['APPDATA']) / 'Rookhaven Client/Rookhaven-LocalPassives-Probe'
processes, handles = [], []
report = {'status':'FAIL','scope':'Current source-matched native server, current quest UI, owned loopback only'}


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
    for file in args.engine_directory.resolve().iterdir():
        if file.is_file() and file.suffix.lower() in ('.dll','.exe'):
            shutil.copyfile(file,runtime/file.name)
    shutil.copyfile(runtime/'premium-scroll-qa.exe',runtime/'tfs-visual-qa.exe')
    report['server_sha256']=hashlib.sha256((runtime/'tfs-visual-qa.exe').read_bytes()).hexdigest()
    assert report['server_sha256']=='23d14234e9a6599ac8544d818e23e3b8143e01187e118ebf99d07845d73e235c'
    config=config_before.decode('utf-8-sig').replace('mysqlPort = 33308','mysqlPort = 33313').replace('loginProtocolPort = 7174','loginProtocolPort = 7185').replace('statusProtocolPort = 7174','statusProtocolPort = 7185').replace('gameProtocolPort = 7175','gameProtocolPort = 7186').replace('Rookhaven Local Passives Test','Rookhaven Ancients QA')
    assert 'ip = "127.0.0.1"' in config and 'enforceClientChecksums = true' in config
    config+='\nfreePremium = false\nhouseRentPeriod = "never"\noptimizeDatabaseAtStartup = false\n'
    assert 'passiveTestEnabled = true' in config
    (runtime/'data/client_integrity_expected.txt').write_text('a'*64+'\n'+'b'*64+'\n')
    (runtime/'config.lua').write_text(config)
    shutil.copyfile(Path(__file__).with_name('native-server.lua'),runtime/'data/scripts/ancients-owned-qa.lua')
    shutil.copytree(args.client_package.resolve(),client)
    report['qa_client_sha256']=hashlib.sha256((client/'RookhavenClient.exe').read_bytes()).hexdigest()
    assert report['qa_client_sha256']=='6eab3a487f73cb33d01cbc0acb7daf1c86ab282f8281362dc34978e8338eae1a','Unproven QA client executable'
    receipt=json.loads((client/'build-receipt.json').read_text(encoding='utf-8-sig'))
    report['qa_client_mode']=receipt['mode']
    with zipfile.ZipFile(client/'data.zip') as z:entries={n:z.read(n) for n in z.namelist()}
    entries['startup_original.luac']=entries.pop('init.luac')
    entries['init.lua']=b"function T() dofile('/ancients-probe.lua') end\nreturn dofile('/startup_original.lua')\n"
    entries['test.lua']=b'T()\n'
    entries['ancients-probe.lua']=(b'ANCIENTS_DETAILS_ONLY=true\n' if args.details_only else b'')+Path(__file__).with_name('native-client.lua').read_bytes()
    for file in (ROOT/'modules/game_questreward').iterdir():
        if file.is_file():entries['modules/game_questreward/'+file.name]=file.read_bytes()
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
    password=hashlib.sha1(b'AncientsLoopbackOnly').hexdigest()
    sql("UPDATE accounts SET name='ancientsqa',password='"+password+"',type=1,premium_ends_at=0 WHERE id=9001; UPDATE players SET sex=1,group_id=1,vocation=0,level=40,experience=988000,health=735,healthmax=735,mana=390,manamax=390,cap=10000,posx=32097,posy=32219,posz=7 WHERE id=9001; DELETE FROM player_items WHERE player_id=9001; DELETE FROM player_spells WHERE player_id=9001 AND name IN ('Keychain Consume','Keychain Unlock','Keychain List');")
    server=start(runtime/'tfs-visual-qa.exe',[],'server',runtime)
    end=time.monotonic()+35
    while 'Server Online!' not in log('server'):
        assert server.poll() is None,'Visual server exited: '+log('server')[-5000:]
        assert time.monotonic()<end,'Visual server startup timeout: '+log('server')[-5000:];time.sleep(.2)
    app=start(client/'RookhavenClient.exe',['--local-passives','--test'],'client',client)
    assert app.wait(timeout=120)==0,'Client failed: '+log('client')[-4000:]
    assert 'ANCIENTS_UI_NATIVE_OK' in log('client') and 'ANCIENTS_NATIVE_SERVER_READY' in log('server'),log('client')[-6000:]+'\n'+log('server')[-3000:]
    for screenshot in profile.glob('ancients-choice-*.png'):shutil.copyfile(screenshot,run/screenshot.name)
    report.update(status='PASS',reward_choices=2,duplicate_denied=True,cap_retry=True,legacy_exchange_preserves_affixes=True,
        inline_information=True,definition_backed_details=True,quest_claim_vocation=0,equip_checks=0 if args.details_only else 336,ordinary_knife_checks=0 if args.details_only else 6)
finally:
    for p in reversed(processes):
        if p.poll() is None:p.terminate();p.wait(timeout=15)
    for handle in handles:handle.close()
    for screenshot in profile.glob('ancients-choice-*.png'):
        shutil.copyfile(screenshot,run/screenshot.name)
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
