"""Native outfit shop, sex, protocol and persistence checks in a cold owned copy."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import os
import re
import shutil
import socket
import struct
import subprocess
import time
import zipfile
import zlib
from cryptography.hazmat.primitives.serialization import load_pem_private_key

CLIENT = Path(__file__).resolve().parents[2]
SERVER = CLIENT.parent / 'Rookhaven'
LOCAL = CLIENT / 'out/local-server'
parser = argparse.ArgumentParser()
parser.add_argument('--engine-package', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
run = args.output.resolve()
run.mkdir(parents=True, exist_ok=False)
runtime, database = run / 'runtime', run / 'database'
source_db = LOCAL / 'passives-db'
source_config = LOCAL / 'passives-runtime/config.lua'
db_bin = LOCAL / 'mariadb-11.4.9-winx64/bin'
NO_WINDOW = subprocess.CREATE_NO_WINDOW
processes, handles = [], []
sent_requests = {}
connections, last_ping = {}, {}
report = {'status': 'FAIL', 'source_database_unchanged': False, 'owned_processes_stopped': False}


def digest_tree(root):
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in root.rglob('*') if p.is_file()}


def text():
    path = run / 'server-stdout.log'
    return path.read_text(errors='replace') if path.exists() else ''


def wait_marker(marker, connection=None, timeout=45):
    deadline = time.monotonic() + timeout
    heartbeat = time.monotonic()
    while time.monotonic() < deadline:
        log = text()
        if 'ACOLYTE_NATIVE_FAILED' in log or 'Lua Script Error:' in log:
            raise AssertionError(log[-8000:])
        if connection:
            if 'ACOLYTE_PEER_LOGIN_READY' in log and 'ACOLYTE_NATIVE_READY_RELOGIN' not in log and 'peer' not in connections:
                connections['peer']=login('Acolyte Female')
            for match in re.finditer(r'^ACOLYTE_WIRE (\{.*\})$',log,re.MULTILINE):
                request=json.loads(match.group(1));seq=request['sequence']
                if seq in sent_requests:continue
                kind=request['kind']
                if kind=='buy':
                    payload=b'\x32\xc9'+wire.string(json.dumps({'action':'buy','data':{'category':request['category'],'offer':request['offer'],'cost':0}},separators=(',',':')))
                elif kind=='set_outfit':
                    payload=b'\xd3'+struct.pack('<H5B',request['look'],58,49,2,58,request['addons'])
                else:raise AssertionError('Unknown outfit wire request '+kind)
                send(connections[request['actor']] if request.get('actor') else connection,payload)
                sent_requests[seq]={'label':request['label'],'kind':kind}
        if marker in log:
            return
        if connection:
            for sock in [connection,*connections.values()]:
                if time.monotonic()-last_ping.get(sock,0)>=2:
                    send(sock,b'\x1e');last_ping[sock]=time.monotonic()
                try:assert sock.recv(65536),'Native client disconnected while awaiting '+marker
                except socket.timeout:pass
        else:
            time.sleep(.15)
    raise TimeoutError(marker + '\n' + text()[-6000:])


def start(exe, arguments, name):
    stdout = (run / (name + '-stdout.log')).open('wb')
    stderr = (run / (name + '-stderr.log')).open('wb')
    handles.extend((stdout, stderr))
    p = subprocess.Popen([str(exe), *arguments], cwd=runtime, stdout=stdout, stderr=stderr,
                         creationflags=NO_WINDOW)
    processes.append(p)
    return p


try:
    for port in (33312, 7183, 7184):
        with socket.socket() as sock:
            sock.bind(('127.0.0.1', port))
    # Refuse a hot source; only the cold copy below is ever started or written.
    check = subprocess.run(['powershell.exe', '-NoProfile', '-Command',
        "Get-CimInstance Win32_Process -Filter \"Name='mariadbd.exe'\" | Where-Object { $_.CommandLine -like '*passives-db*' } | Select-Object -ExpandProperty ProcessId"],
        capture_output=True, text=True, creationflags=NO_WINDOW, check=True)
    assert not check.stdout.strip(), 'Source database is running; cold-copy test refused'
    cpp=json.loads((CLIENT/'assets/items/boat-pass/native-source-hashes.json').read_text(encoding='utf-8'))
    for path,digest in cpp.items():assert hashlib.sha256((SERVER/path).read_bytes()).hexdigest()==digest,path
    report['current_native_source_files_matched']=len(cpp)
    before = digest_tree(source_db)
    config_before = source_config.read_bytes()
    shutil.copytree(source_db, database)
    shutil.copytree(SERVER / 'data', runtime / 'data')
    shutil.copyfile(LOCAL / 'passives-runtime/key.pem', runtime / 'key.pem')
    with zipfile.ZipFile(args.engine_package) as archive:
        archive.extractall(runtime)
    exe = runtime / 'premium-scroll-qa.exe'
    report['server_sha256'] = hashlib.sha256(exe.read_bytes()).hexdigest()
    config = config_before.decode('utf-8-sig')
    assert 'mysqlPort = 33308' in config and 'ip = "127.0.0.1"' in config and 'bindOnlyGlobalAddress = true' in config
    config = config.replace('mysqlPort = 33308', 'mysqlPort = 33312').replace('loginProtocolPort = 7174', 'loginProtocolPort = 7183').replace('statusProtocolPort = 7174', 'statusProtocolPort = 7183').replace('gameProtocolPort = 7175', 'gameProtocolPort = 7184').replace('Rookhaven Local Passives Test', 'Rookhaven Acolyte QA')
    config += '\nonePlayerOnlinePerAccount = false\nfreePremium = false\nhouseRentPeriod = "never"\noptimizeDatabaseAtStartup = false\n'
    (runtime / 'config.lua').write_text(config)
    (runtime / 'data/client_integrity_expected.txt').write_text('a' * 64 + '\n' + 'b' * 64 + '\n')
    fixture = Path(__file__).with_name('native-fixture.lua')
    shutil.copyfile(fixture, runtime / 'data/scripts/magic-gold-acolyte-owned-qa.lua')
    env = os.environ.copy()
    env['MYSQL_PWD'] = re.search(r'mysqlPass\s*=\s*"([^"]+)"', config).group(1)
    user = re.search(r'mysqlUser\s*=\s*"([^"]+)"', config).group(1)

    def sql(query):
        return subprocess.run([str(db_bin / 'mariadb.exe'), '--no-defaults', '--host=127.0.0.1', '--port=33312',
            '--user=' + user, '--database=rookhaven_passives_test', '--batch', '--skip-column-names', '--execute=' + query],
            env=env, capture_output=True, text=True, check=True, creationflags=NO_WINDOW).stdout

    db_process = start(db_bin / 'mariadbd.exe', ['--no-defaults', '--datadir=' + str(database),
        '--bind-address=127.0.0.1', '--port=33312', '--skip-name-resolve', '--console'], 'database')
    deadline = time.monotonic() + 25
    while True:
        assert db_process.poll() is None, 'Owned database exited'
        try:
            sql('SELECT 1'); break
        except subprocess.CalledProcessError:
            assert time.monotonic() < deadline, 'Database startup timed out'
            time.sleep(.2)
    password_hash = hashlib.sha1(b'PremiumScrollLoopbackOnly').hexdigest()
    sql("UPDATE accounts SET name='premiumscrollqa',password='" + password_hash + "',type=1,premium_ends_at=0 WHERE id=9001;"
        "UPDATE players SET group_id=1,health=150,healthmax=150,mana=100,manamax=100,cap=10000,posx=32097,posy=32219,posz=7 WHERE id=9001;"
        "DELETE FROM player_items WHERE player_id=9001; DELETE FROM player_storage WHERE player_id=9001 AND (`key` IN (950800,950801,910500) OR `key` BETWEEN 10000000 AND 10001000);")
    cols=[line.split('\t')[0] for line in sql('SHOW COLUMNS FROM players').splitlines()]
    assert sql('SELECT COUNT(*) FROM players WHERE id=990001').strip()=='0'
    names=','.join('`'+c+'`' for c in cols)
    values=','.join({'id':'990001','name':"'Acolyte Female'",'sex':'0'}.get(c,'`'+c+'`') for c in cols)
    sql('INSERT INTO players ('+names+') SELECT '+values+' FROM players WHERE id=9001')
    sql('DELETE FROM player_storage WHERE player_id=990001; UPDATE players SET sex=1 WHERE id=9001; UPDATE players SET sex=0 WHERE id=990001')
    server_process = start(exe, [], 'server')
    wait_marker('Server Online!')
    spec = importlib.util.spec_from_file_location('wire', CLIENT / 'tools/tests/client-login-integrity.py')
    wire = importlib.util.module_from_spec(spec); spec.loader.exec_module(wire)
    rsa = load_pem_private_key((runtime / 'key.pem').read_bytes(), None).public_key().public_numbers()
    key = (0x18273645, 0x29384756, 0x38475619, 0x47561928)

    def rsa_block(value):
        return pow(int.from_bytes(value.ljust(128, b'\0'), 'big'), rsa.e, rsa.n).to_bytes(128, 'big')

    def login(name='Passive Tester'):
        sock = socket.create_connection(('127.0.0.1', 7184), timeout=10)
        timestamp, random = struct.unpack('<IB', wire.receive(sock)[-5:])
        auth = b'\0' + struct.pack('<4I', *key) + b'\0' + wire.string('premiumscrollqa') + wire.string(name) + wire.string('PremiumScrollLoopbackOnly')
        auth += struct.pack('<IB', timestamp, random) + wire.string('RH2')
        proof = hashlib.sha256(f'RH2|{"a" * 64}|{"b" * 64}|{timestamp}|{random}'.encode()).hexdigest()
        body = b'\x0a' + struct.pack('<HH', 10, 860) + rsa_block(auth) + rsa_block(b'\0\0' + wire.string(proof))
        packet = struct.pack('<I', zlib.adler32(body)) + body
        sock.sendall(struct.pack('<H', len(packet)) + packet)
        accepted = False
        for _ in range(15):
            clear = wire.decrypt(wire.receive(sock)[4:], key)
            if clear.startswith(b'\x32\0\0\0'): clear = clear[4:]
            if clear and clear[0] in (0x0a, 0x17): accepted = True; break
            if clear and clear[0] == 0x14: raise AssertionError('Native login refused: ' + repr(clear))
        assert accepted, 'Native login was not accepted'
        sock.settimeout(.2)
        return sock

    def send(sock, payload):
        clear = struct.pack('<H', len(payload)) + payload
        encrypted = wire.encrypt(clear + b'\0' * (-len(clear) % 8), key)
        packet = struct.pack('<I', zlib.adler32(encrypted)) + encrypted
        sock.sendall(struct.pack('<H', len(packet)) + packet)

    with login() as connection:
        wait_marker('ACOLYTE_NATIVE_READY_RELOGIN',connection,timeout=110)
        send(connections['peer'],b'\x14');time.sleep(.5)
        connections['peer'].close();connections.clear()
        send(connection,b'\x14');time.sleep(1)
    with login() as connection:
        wait_marker('ACOLYTE_MAIN_RELOGIN_OK',connection)
        # Do not dispatch already-completed wire requests during reconnect.
        with login('Acolyte Female') as peer:
            wait_marker('ACOLYTE_PEER_RELOGIN_OK',peer)
            send(peer,b'\x14');time.sleep(.4)
        send(connection,b'\x14');time.sleep(.4)
    report['wire_requests']=sent_requests
    assert len(sent_requests)==10,'Not all outfit buy/wear packets completed'
    report['native_checks']=re.findall(r'ACOLYTE_[^\r\n]*checks=\d+',text())
    report['status'] = 'PASS'
finally:
    # These Popen handles refer only to the processes started in this runner.
    for p in reversed(processes):
        if p.poll() is None:
            p.terminate(); p.wait(timeout=15)
    for handle in handles: handle.close()
    report['owned_processes_stopped'] = all(p.poll() is not None for p in processes)
    if 'before' in globals():
        report['source_database_unchanged'] = before == digest_tree(source_db) and config_before == source_config.read_bytes()
    (run / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report), flush=True)

assert report['status'] == 'PASS' and report['source_database_unchanged'] and report['owned_processes_stopped']
