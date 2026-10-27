"""Native redemption/purchase/use/reconnect checks on a cold loopback-only copy."""
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
parser.add_argument('--fault-mode', choices=('commit_unknown_before', 'commit_unknown_after', 'crash_after_commit'))
args = parser.parse_args()
run = args.output.resolve()
run.mkdir(parents=True, exist_ok=False)
runtime, database = run / 'runtime', run / 'database'
source_db = LOCAL / 'passives-db'
source_config = LOCAL / 'passives-runtime/config.lua'
db_bin = LOCAL / 'mariadb-11.4.9-winx64/bin'
NO_WINDOW = subprocess.CREATE_NO_WINDOW
processes, handles = [], []
frames, quotes = {}, []
last_ping = {}
report = {'status': 'FAIL', 'source_database_unchanged': False, 'owned_processes_stopped': False}


def digest_tree(root):
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in root.rglob('*') if p.is_file()}


def text():
    path = run / 'server-stdout.log'
    return path.read_text(errors='replace') if path.exists() else ''


def wait_marker(marker, connection=None, timeout=45):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        log = text()
        if 'BOAT_PASS_NATIVE_FAILED' in log or 'Lua Script Error:' in log:
            raise AssertionError(log[-8000:])
        if marker in log:
            return
        if connection:
            drain(connection)
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
    config = config.replace('mysqlPort = 33308', 'mysqlPort = 33312').replace('loginProtocolPort = 7174', 'loginProtocolPort = 7183').replace('statusProtocolPort = 7174', 'statusProtocolPort = 7183').replace('gameProtocolPort = 7175', 'gameProtocolPort = 7184').replace('Rookhaven Local Passives Test', 'Rookhaven Boat Pass QA')
    config += '\nonePlayerOnlinePerAccount = false\nfreePremium = false\nhouseRentPeriod = "never"\noptimizeDatabaseAtStartup = false\n'
    (runtime / 'config.lua').write_text(config)
    (runtime / 'data/client_integrity_expected.txt').write_text('a' * 64 + '\n' + 'b' * 64 + '\n')
    fixture = Path(__file__).with_name('native-fixture.lua')
    shutil.copyfile(fixture, runtime / 'data/scripts/boat-pass-owned-qa.lua')
    if args.fault_mode:
        (runtime / 'boat-pass-fault.txt').write_text(args.fault_mode)
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
    password_hash = hashlib.sha1(b'BoatPassLoopbackOnly').hexdigest()
    sql("UPDATE accounts SET name='boatpassqa',password='" + password_hash + "',type=1,premium_ends_at=0 WHERE id=9001;"
        "UPDATE players SET group_id=1,health=150,healthmax=150,mana=100,manamax=100,cap=10000,posx=32097,posy=32219,posz=7 WHERE id=9001;"
        "DELETE FROM player_items WHERE player_id=9001; DELETE FROM player_storage WHERE player_id=9001 AND `key`=950600;")
    # Additional ordinary characters are made only inside this cold copy.
    def clone(table, source_id, replacements):
        cols = [line.split('\t')[0] for line in sql('SHOW COLUMNS FROM ' + table).splitlines()]
        names = ','.join('`'+c+'`' for c in cols)
        values = ','.join(replacements.get(c, '`'+c+'`') for c in cols)
        sql('INSERT INTO '+table+' ('+names+') SELECT '+values+' FROM '+table+' WHERE id='+str(source_id))
    assert sql('SELECT COUNT(*) FROM players WHERE id IN (990001,990002)').strip() == '0'
    assert sql('SELECT COUNT(*) FROM accounts WHERE id=990002').strip() == '0'
    clone('accounts',9001,{'id':'990002','name':"'boatpassotherqa'"})
    clone('players',9001,{'id':'990001','name':"'Boat Account Mate'"})
    clone('players',9001,{'id':'990002','account_id':'990002','name':"'Boat Other Account'"})
    server_process = start(exe, [], 'server')
    wait_marker('Server Online!')
    spec = importlib.util.spec_from_file_location('wire', CLIENT / 'tools/tests/client-login-integrity.py')
    wire = importlib.util.module_from_spec(spec); spec.loader.exec_module(wire)
    rsa = load_pem_private_key((runtime / 'key.pem').read_bytes(), None).public_key().public_numbers()
    key = (0x18273645, 0x29384756, 0x38475619, 0x47561928)

    def rsa_block(value):
        return pow(int.from_bytes(value.ljust(128, b'\0'), 'big'), rsa.e, rsa.n).to_bytes(128, 'big')

    def login(name='Passive Tester', account='boatpassqa'):
        sock = socket.create_connection(('127.0.0.1', 7184), timeout=10)
        timestamp, random = struct.unpack('<IB', wire.receive(sock)[-5:])
        auth = b'\0' + struct.pack('<4I', *key) + b'\0' + wire.string(account) + wire.string(name) + wire.string('BoatPassLoopbackOnly')
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

    def drain(sock):
        if time.monotonic()-last_ping.get(sock,0)>2:
            try: send(sock,b'\x1e'); last_ping[sock]=time.monotonic()
            except OSError: return
        try: chunk=sock.recv(65536)
        except (socket.timeout,ConnectionResetError): return
        buf=frames.setdefault(sock,bytearray());buf.extend(chunk)
        while len(buf)>=2:
            size=struct.unpack_from('<H',buf)[0]
            if len(buf)<size+2:break
            packet=bytes(buf[2:size+2]);del buf[:size+2]
            clear=wire.decrypt(packet[4:],key)
            offset=0
            while True:
                offset=clear.find(b'\x32\x5c',offset)
                if offset<0 or offset+4>len(clear):break
                length=struct.unpack_from('<H',clear,offset+2)[0]
                try:
                    obj=json.loads(clear[offset+4:offset+4+length])
                    if 'destination' in obj and 'price' in obj: quotes.append(obj)
                except (ValueError,UnicodeDecodeError):pass
                offset+=2

    def station(sock,stage,expected):
        marker='BOAT_PASS_WIRE_STATION stage='+stage+' request='
        wait_marker(marker,sock)
        request=json.loads(text().split(marker)[-1].splitlines()[0])
        count=len(quotes)
        send(sock,b'\x82'+struct.pack('<HHBHBB',request['x'],request['y'],request['z'],request['cid'],request['stack'],0))
        end=time.monotonic()+12
        while len(quotes)==count:
            assert time.monotonic()<end, 'No actual boat quote for '+stage+'\n'+text()[-3000:]
            drain(sock)
        assert quotes[-1]['price']==expected,(stage,quotes[-1])
        if stage=='expired_quote':wait_marker('BOAT_PASS_EXPIRED_QUOTE_READY',sock)
        if stage=='paid':
            # The real protocol boundary rejects extra fare/account/route fields.
            forged=json.dumps({'response':'accept','price':0,'uid':0,'boat_pass_ends_at':4294967295})
            send(sock,b'\x32\x5c'+wire.string(forged))
            time.sleep(.4)
            (runtime/'boat-malformed-sent.txt').write_text('sent')
            wait_marker('BOAT_PASS_MALFORMED_REPLY_OK',sock)
        msg=json.dumps({'response':'accept'})
        send(sock,b'\x32\x5c'+wire.string(msg))
        if stage=='paid':send(sock,b'\x32\x5c'+wire.string(msg))

    if args.fault_mode:
        with login() as connection:
            wait_marker('BOAT_PASS_FAULT_PREPARED', connection)
            if args.fault_mode == 'crash_after_commit':
                assert server_process.wait(timeout=20) == 86, 'Injected crash did not stop after COMMIT'
                shutil.copyfile(run / 'server-stdout.log', run / 'server-crash-before-restart.log')
                server_process = start(exe, [], 'server')
                wait_marker('Server Online!')
            else:
                wait_marker('BOAT_PASS_FAULT_RETURN', connection)
                time.sleep(.4)
        expected_count = 1 if args.fault_mode == 'commit_unknown_before' else 0
        actual_count = int(sql('SELECT COALESCE(SUM(count),0) FROM player_items WHERE player_id=9001 AND itemtype=12866').strip())
        expiry = int(sql('SELECT boat_pass_ends_at FROM accounts WHERE id=9001').strip())
        assert actual_count == expected_count and (expiry > time.time()) == (expected_count == 0), 'COMMIT left account/inventory inconsistent'
        with login() as connection:
            wait_marker('BOAT_PASS_FAULT_RELOGIN_OK', connection)
            send(connection, b'\x14'); time.sleep(.4)
        report['fault_mode'] = args.fault_mode
        report['atomic_account_and_scroll_after_fault'] = True
    else:
        with login() as connection:
            wait_marker('BOAT_PASS_WIRE_READY', connection)
            send(connection, b'\x82' + struct.pack('<HHBHBB', 65535, 10, 0, 11903, 0, 0))
            wait_marker('BOAT_PASS_NATIVE_OK', connection)
            end_before = sql('SELECT boat_pass_ends_at FROM accounts WHERE id=9001').strip()
            send(connection, b'\x82' + struct.pack('<HHBHBB', 65535, 10, 0, 11903, 0, 0))
            time.sleep(.3)
            assert sql('SELECT boat_pass_ends_at FROM accounts WHERE id=9001').strip() == end_before, 'Repeated Use packet granted time twice'
            for name,account,marker in [('Boat Account Mate','boatpassqa','SAME_ACCOUNT'),('Boat Other Account','boatpassotherqa','OTHER_ACCOUNT')]:
                with login(name,account) as other:
                    wait_marker('BOAT_PASS_'+marker+'_OK',other)
                    send(other,b'\x14');time.sleep(.4)
                drain(connection)
            (runtime/'boat-start-rides.txt').write_text('start')
            for stage,price in [('paid',15),('free',0),('poor',15),('paid_failure',15),('free_failure',0),('expired_quote',0)]:
                station(connection,stage,price)
                wait_marker('BOAT_PASS_STAGE_OK stage='+stage,connection)
            wait_marker('BOAT_PASS_RIDES_OK',connection)
            report['actual_fare_popups']=quotes
            report['real_paid_and_free_rides']=True
            report['same_and_other_account_checks']=True
            send(connection, b'\x14')
            time.sleep(1)
        with login() as connection:
            wait_marker('BOAT_PASS_NATIVE_RELOGIN_OK', connection)
            send(connection, b'\x14'); time.sleep(.4)
        report['duplicate_use_did_not_grant_time'] = True
    report['schema_version'] = sql("SELECT value FROM server_config WHERE config='db_version'").strip()
    assert report['schema_version']=='34'
    report['native_checks'] = re.findall(r'BOAT_PASS_[^\r\n]*checks=\d+', text())
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
