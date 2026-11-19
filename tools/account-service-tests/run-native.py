"""Run against a cold DB copy and owned loopback processes. Never changes DEV/PROD.

The supplied native server must be built from current sources. The optional QA
client is loopback-only; its archive is overlaid with the current UI and driver.
"""
from pathlib import Path
import argparse,concurrent.futures,hashlib,json,os,re,shutil,socket,subprocess,sys,time,zipfile,zlib
from wire import Wire,string,u16 as wire_u16
from management import run as management_regressions,email_regressions,house_live_regressions
import wire
import xml.etree.ElementTree as ET
wire.connect_spacing=1.05 # Keep legitimate regressions below the shared 60/min auth budget.

ROOT=Path(__file__).resolve().parents[2];SERVER=ROOT.parent/'Rookhaven';LOCAL=ROOT/'out/local-server'
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--engine',type=Path,required=True);p.add_argument('--management-only',action='store_true')
p.add_argument('--house-core',choices=['normal','balance_commit_unknown_before','balance_commit_unknown_after','balance_crash_after_commit','transfer_rollback','transfer_commit_unknown_before','transfer_commit_unknown_after','transfer_crash_after_commit'])
p.add_argument('--house-core-town',type=int,default=0)
p.add_argument('--house-market',action='store_true')
p.add_argument('--house-ui-only',action='store_true')
p.add_argument('--house-rent',action='store_true')
p.add_argument('--house-photos',action='store_true');p.add_argument('--house-photo-limit',type=int,default=10000)
p.add_argument('--shop-ui',action='store_true')
p.add_argument('--legacy-house-schema',action='store_true')
p.add_argument('--web-public',action='store_true')
p.add_argument('--guild-parity',action='store_true')
p.add_argument('--guild-scale',action='store_true')
p.add_argument('--guild-ui',action='store_true')
p.add_argument('--guild-ui-polish',action='store_true')
p.add_argument('--guild-directory',action='store_true')
p.add_argument('--dll-directory',type=Path,required=True);p.add_argument('--rsa-key',type=Path,required=True);p.add_argument('--encoder',type=Path);p.add_argument('--client',type=Path);p.add_argument('--ui-only',action='store_true');p.add_argument('--attack-only',action='store_true');p.add_argument('--ingress-only',action='store_true');args=p.parse_args()
assert not args.ui_only or args.client,'--ui-only requires --client'
assert not args.guild_ui or (args.guild_scale and args.client),'--guild-ui requires --guild-scale and --client'
assert not args.guild_ui_polish or (args.guild_parity and args.house_ui_only and args.client),'--guild-ui-polish requires the isolated guild fixture and --house-ui-only'
assert not args.guild_directory or (args.guild_parity and args.house_ui_only and args.client and not args.guild_scale and not args.guild_ui_polish),'--guild-directory requires its own guild fixture and QA client'
assert not args.house_ui_only or (args.house_market and args.client),'--house-ui-only requires --house-market and --client'
assert not args.house_photos or (args.house_ui_only and args.house_photo_limit>0),'--house-photos requires the isolated house UI fixture'
assert not args.shop_ui or (args.house_ui_only and not args.house_photos),'--shop-ui requires the ordinary house UI fixture'
run=args.output.resolve();run.mkdir(parents=True,exist_ok=False)
runtime=run/'runtime';database=run/'database';handles=[];processes=[];server=None
report={'status':'FAIL','scope':'owned loopback native account/login/UI and cold database copy','checks':[]}
profile=Path(os.environ['APPDATA'])/'Rookhaven Client/Rookhaven-LocalPassives-Probe'
def digest(path):return {p.relative_to(path).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in path.rglob('*') if p.is_file()}
def check(value,label):
    assert value,label
    report['checks'].append(label)
def start(exe,arguments,name,cwd):
    out,err=(run/(name+'-stdout.log')).open('wb'),(run/(name+'-stderr.log')).open('wb');handles.extend((out,err))
    si=subprocess.STARTUPINFO();si.dwFlags|=subprocess.STARTF_USESHOWWINDOW;si.wShowWindow=0
    child=subprocess.Popen([str(exe),*arguments],cwd=cwd,stdout=out,stderr=err,creationflags=subprocess.CREATE_NO_WINDOW,startupinfo=si)
    processes.append(child);return child
def log(name):
    f=run/(name+'-stdout.log');return f.read_text(errors='replace') if f.exists() else ''
def stop(child):
    if child and child.poll() is None:child.terminate();child.wait(timeout=15)
try:
    for port in (33314,7187,7188):
        with socket.socket() as s:s.bind(('127.0.0.1',port))
    live=subprocess.run(['powershell.exe','-NoProfile','-Command',"Get-CimInstance Win32_Process | Where-Object { ($_.Name -eq 'mariadbd.exe' -and $_.CommandLine -like '*passives-db*') -or ($_.Name -eq 'RookhavenClient.exe' -and $_.CommandLine -like '*--local-passives*') } | Select-Object -ExpandProperty ProcessId"],capture_output=True,text=True,check=True,creationflags=subprocess.CREATE_NO_WINDOW)
    assert not live.stdout.strip(),'Source fixture/profile in use'
    original_db=digest(LOCAL/'passives-db');original_config=(LOCAL/'passives-runtime/config.lua').read_bytes()
    # The retained SQL seed is portable; never rely on copied InnoDB system files.
    shutil.copytree(SERVER/'data',runtime/'data')
    initialized=subprocess.run([str(LOCAL/'mariadb-11.4.9-winx64/bin/mariadb-install-db.exe'),'--datadir='+str(database)],capture_output=True,creationflags=subprocess.CREATE_NO_WINDOW)
    assert initialized.returncode==0,'Owned MariaDB initialization failed'
    if args.house_photos:shutil.copyfile(ROOT/'tools/house-photos/native-server.lua',runtime/'data/scripts/owned-house-photos.lua')
    obsolete=runtime/'data/scripts/quiver_weight_startup.lua'
    if obsolete.exists():obsolete.rename(obsolete.with_name('#quiver_weight_startup.lua'))
    for f in args.dll_directory.resolve().glob('*.dll'):shutil.copyfile(f,runtime/f.name)
    shutil.copyfile(args.engine.resolve(),runtime/'accounts-qa.exe')
    shutil.copyfile(args.rsa_key.resolve(),runtime/'key.pem');pem=(runtime/'key.pem').read_bytes()
    report['server_sha256']=hashlib.sha256((runtime/'accounts-qa.exe').read_bytes()).hexdigest()
    config=original_config.decode('utf-8-sig')
    for name,value in [('mysqlPort','33314'),('loginProtocolPort','7187'),('statusProtocolPort','7187'),('gameProtocolPort','7188'),('serverName','"Rookhaven Accounts QA"')]:
        config,n=re.subn(r'(?m)^'+name+r'\s*=.*$',name+' = '+value,config);assert n==1,name
    assert 'ip = "127.0.0.1"' in config
    own_password=os.urandom(24).hex()
    for name,value in [('mysqlUser','accounts_qa'),('mysqlPass',own_password),('mysqlDatabase','rookhaven_accounts_qa')]:
        config,n=re.subn(r'(?m)^'+name+r'\s*=.*$',name+' = "'+value+'"',config);assert n==1,name
    config+='\nfreePremium = false\nhouseRentPeriod = "never"\noptimizeDatabaseAtStartup = false\nclientAccountServicesEnabled = true\nclientAccountCreationEnabled = true\nclientCharacterCreationEnabled = true\nclientCharacterLimit = 3\nclientCharacterTownId = 1\nclientAccountIpLimitPerHour = 100\n'
    (runtime/'data/client_integrity_expected.txt').write_text('a'*64+'\n'+'b'*64+'\n')
    env=os.environ.copy();env['MYSQL_PWD']=re.search(r'mysqlPass\s*=\s*"([^"]+)"',config).group(1)
    user=re.search(r'mysqlUser\s*=\s*"([^"]+)"',config).group(1)
    def sql(query):
        result=subprocess.run([str(LOCAL/'mariadb-11.4.9-winx64/bin/mariadb.exe'),'--no-defaults','--host=127.0.0.1','--port=33314','--user='+user,'--database=rookhaven_accounts_qa','--batch','--skip-column-names','--execute='+query],env=env,capture_output=True,text=True,creationflags=subprocess.CREATE_NO_WINDOW)
        if result.returncode:raise RuntimeError('Fixture SQL failed: '+result.stderr[:300])
        return result.stdout.strip()
    db=start(LOCAL/'mariadb-11.4.9-winx64/bin/mariadbd.exe',['--no-defaults','--datadir='+str(database),'--bind-address=127.0.0.1','--port=33314','--skip-name-resolve','--console'],'database',runtime)
    deadline=time.monotonic()+30
    root_env=os.environ.copy();root_env.pop('MYSQL_PWD',None)
    root_cmd=[str(LOCAL/'mariadb-11.4.9-winx64/bin/mariadb.exe'),'--no-defaults','--host=127.0.0.1','--port=33314','--user=root']
    while True:
        ping=subprocess.run(root_cmd+['--execute=SELECT 1'],env=root_env,capture_output=True,creationflags=subprocess.CREATE_NO_WINDOW)
        if ping.returncode==0:break
        assert db.poll() is None and time.monotonic()<deadline;time.sleep(.2)
    bootstrap="CREATE DATABASE rookhaven_accounts_qa; CREATE USER 'accounts_qa'@'127.0.0.1' IDENTIFIED BY '"+own_password+"'; CREATE USER 'accounts_qa'@'localhost' IDENTIFIED BY '"+own_password+"'; GRANT ALL ON rookhaven_accounts_qa.* TO 'accounts_qa'@'127.0.0.1'; GRANT ALL ON rookhaven_accounts_qa.* TO 'accounts_qa'@'localhost';"
    assert subprocess.run(root_cmd+['--execute='+bootstrap],env=root_env,capture_output=True,creationflags=subprocess.CREATE_NO_WINDOW).returncode==0,'Fixture bootstrap failed'
    seeded=subprocess.run(root_cmd+['--database=rookhaven_accounts_qa'],input=(LOCAL/'passives-fixture-seed.sql').read_bytes(),env=root_env,capture_output=True,creationflags=subprocess.CREATE_NO_WINDOW)
    assert seeded.returncode==0,'Fixture seed failed'
    phase=0
    def boot(extra='',expect_stop=False):
        global server,phase
        stop(server);phase+=1
        (runtime/'config.lua').write_text(config+extra)
        server=start(runtime/'accounts-qa.exe',[],'server-'+str(phase),runtime)
        deadline=time.monotonic()+45
        if expect_stop:
            while server.poll() is None:
                assert time.monotonic()<deadline,'expected startup stop timed out';time.sleep(.2)
            check('Server Online!' not in log('server-'+str(phase)),'failed or interrupted transfer never opens game services')
            return
        while 'Server Online!' not in log('server-'+str(phase)):
            assert server.poll() is None,'exit='+hex(server.returncode & 0xffffffff)+' '+log('server-'+str(phase))[-4000:]
            assert time.monotonic()<deadline,'startup timed out';time.sleep(.2)
    def connection():return Wire(pem,7187)
    def create(action,account,password,value,sex=1,extra=b''):
        w=connection()
        try:return w.create(action,account,password,value,sex,extra)
        finally:w.close()
    def login(account,password):
        w=connection()
        try:return w.login(account,password)
        finally:w.close()
    def policy():
        w=connection()
        try:return w.handshake()
        finally:w.close()
    if args.legacy_house_schema:
        assert args.house_market,'Legacy housing schema uses the housing fixture'
        boot();stop(server)
        sql('ALTER TABLE web_house_sale_listings ADD UNIQUE KEY legacy_single_house(house_id)')
        sql("UPDATE server_config SET value='36' WHERE config='db_version'")
    if args.house_market:
        from housing import run as housing_regressions
        housing_regressions(pem,sql,check,boot,create,lambda:stop(server),runtime,args.house_ui_only or args.guild_scale,args.house_rent)
        if args.legacy_house_schema:
            check(sql("SELECT COUNT(*) FROM information_schema.statistics WHERE table_schema=DATABASE() AND table_name='web_house_sale_listings' AND index_name='legacy_single_house'")=='0','migration replaces legacy single-house listing uniqueness without dropping data')
    if args.house_core:
        probe=Path(__file__).with_name('house-core-server.lua').read_text().replace('__CASE__',args.house_core).replace('__HOUSE_CORE_TOWN__',str(args.house_core_town))
        (runtime/'data/scripts/owned-house-core.lua').write_text(probe)
        shutil.copyfile(Path(__file__).with_name('house-live-server.lua'),runtime/'data/scripts/owned-house-live.lua')
        crash='crash_after_commit' in args.house_core
        stopped=args.house_core.startswith('transfer_') or crash
        boot(expect_stop=stopped)
        check(('HOUSE_CORE_OK '+args.house_core) in log('server-1') or (crash and server.returncode==86) or (args.house_core.startswith('transfer_') and server.returncode==87),'native house-core probe completed expected path')
        after=args.house_core=='normal' or 'unknown_after' in args.house_core or crash
        transfer=args.house_core=='normal' or args.house_core.startswith('transfer_')
        seller_expected=1150 if args.house_core=='normal' else (1050 if transfer and after else (1100 if not transfer and after else 1000))
        buyer_expected=900 if args.house_core=='normal' or (not transfer and after) else 1000
        check(sql('SELECT balance FROM players WHERE id=880001')==str(seller_expected) and sql('SELECT balance FROM players WHERE id=880002')==str(buyer_expected),'market records and both bank balances have the same committed outcome')
        check(sql("SELECT CONCAT(vocation,':',health,':',healthmax,':',mana,':',manamax) FROM players WHERE id=880001")=='3:400:500:120:200' and sql("SELECT CONCAT(class_id,':',earned_points,':',respec_count,':',ranks) FROM player_passives WHERE player_id=880001")=='arcanist:3:0:1,'+','.join(['0']*28),'offline owner snapshot preserves base HP/mana and permanent class ledger')
        if args.house_core=='normal':check(sql('SELECT COUNT(*) FROM owned_house_core_receipts WHERE id IN (2,3,4,5)')=='0','insufficient funds, callback refusal, duplicate participants and NaN leave no market receipt')
        houseid=sql('SELECT house_id FROM owned_house_core_receipts WHERE id=0')
        if transfer:
            check(sql('SELECT soul FROM players WHERE id=880003')==('2' if after else '0'),'sleeping guest regeneration commits with bed and ownership, or rolls back with them')
            check(sql('SELECT owner FROM houses WHERE id='+houseid)==('880002' if after else '880001'),'persisted house ownership matches transfer commit outcome')
            count=sql('SELECT SUM(n) FROM (SELECT COUNT(*) n FROM player_depotitems WHERE player_id=880001 AND ((itemtype=2148 AND count=17) OR (itemtype=2152 AND count=3) OR itemtype=1987) UNION ALL SELECT COUNT(*) n FROM player_depotlockeritems WHERE player_id=880001 AND ((itemtype=2148 AND count=17) OR (itemtype=2152 AND count=3) OR itemtype=1987)) items')
            check(count==('3' if after else '0'),'old owner depot and house item snapshot commit together (rows='+count+')')
            check(sql('SELECT COUNT(*) FROM owned_house_core_receipts WHERE id=6')==('1' if after else '0'),'transfer receipt is atomic with ownership, depot and seller bank')
            if args.house_core_town and after:
                check(sql("SELECT COUNT(*) FROM player_depotlockeritems WHERE player_id=880001 AND pid="+str(args.house_core_town)+" AND (itemtype=2148 OR itemtype=1987)")=='2','house belongings reach the selected town depot')
        if stopped or args.house_core=='normal':
            (runtime/'data/scripts/owned-house-core.lua').rename(runtime/'data/scripts/#owned-house-core.lua')
            (runtime/'data/scripts/owned-house-readback.lua').write_text("local e=GlobalEvent('house-core-readback');function e.onStartup() local h=House("+houseid+");local n=0;for _,i in ipairs(h:getItems()) do if i:getId()==2148 then n=n+i:getCount() end end;local sleeping=false;for _,bed in ipairs(h:getBeds()) do if bed:getAttribute(ITEM_ATTRIBUTE_DESCRIPTION):find('House Core Guest',1,true) then sleeping=true end end;print('HOUSE_CORE_READBACK '..h:getOwnerGuid()..' floorGold='..n..' guestSleeping='..tostring(sleeping));return true end;e:register()")
            boot()
            expected='880002' if transfer and after else ('880001' if transfer else '0')
            check('HOUSE_CORE_READBACK '+expected in log('server-2'),'ordinary restart reloads the authoritative house state')
            if transfer:check('floorGold='+('0' if after else '17') in log('server-2'),'restart keeps belongings in exactly one of house or old owner depot')
            if transfer:check('guestSleeping='+('false' if after else 'true') in log('server-2'),'restart restores the bed guest consistently with the regeneration outcome')
            check(sql('SELECT balance FROM players WHERE id=880001')==str(seller_expected),'restart never repeats settlement credit')
        if args.house_core=='normal':house_live_regressions(pem,sql,check)
    if args.attack_only:
        boot();pw='AttackFixtureOnly'
        check(create(1,'attackqa',pw,"john.o'hara@example.invalid")['success']==1,'valid email punctuation safely persisted')
        check(sql("SELECT email FROM accounts WHERE name='attackqa'")=="john.o'hara@example.invalid",'SQL escaping preserves apostrophes without executing input')
        check(create(1,"a' OR '1'='1",pw,'injection@example.invalid')['success']==0,'registration SQL injection rejected')
        check(create(2,"' OR name='attackqa' -- ",pw,'Injected Hero')['success']==0,'authentication SQL injection cannot select another account')
        check(create(2,'attackqa',pw,"Hero');DROP TABLE players;--")['success']==0,'character SQL payload refused')
        check(create(2,'attackqa',pw,'God Pretender')['success']==0,'staff impersonation prefix refused')
        def refused(extra,label):
            try:create(2,'attackqa',pw,'Tampered Hero',1,extra);raise AssertionError(label+' accepted')
            except (EOFError,ConnectionResetError):check(True,label)
        refused(b'\x06\xff\xff','extra privilege and level fields fail closed')
        refused(b'x'*600,'oversized encrypted request fails closed')
        for version,block,label in [(3,b'\0'*256,'unknown handshake version refused'),(1,b'\0'*256,'RSA block without required magic refused')]:
            w=connection()
            try:
                w.send(bytes([3,version])+wire_u16(860)+block,False)
                try:w.receive();raise AssertionError(label+' accepted')
                except (EOFError,ConnectionResetError):check(True,label)
            finally:w.close()
        old_pem=(LOCAL/'passives-runtime/key.pem').read_bytes()
        w=Wire(old_pem,7187)
        try:
            try:w.handshake();raise AssertionError('previous default key accepted')
            except (EOFError,ConnectionResetError):check(True,'previous default RSA-1024 client is refused')
        finally:w.close()
        check(sql("SELECT COUNT(*) FROM players WHERE account_id=(SELECT id FROM accounts WHERE name='attackqa')")=='0','all refused attacks preserved account and character state')
        check(create(2,'attackqa',pw,'Unharmed Hero')['success']==1 and len(login('attackqa',pw)['characters'])==1,'ordinary creation and login work after malformed traffic')
    if args.ingress_only:
        boot()
        legacy=hashlib.sha1(b'passivetest').hexdigest()
        sql("INSERT INTO accounts(name,password,type,email) VALUES ('passivetest','"+legacy+"',1,'ingress@example.invalid') ON DUPLICATE KEY UPDATE password=VALUES(password)")
        check(create(2,'passivetest','passivetest','Passive Tester')['success']==1,'ordinary owned avatar provisioned for existing ingress probe')
        sql("UPDATE accounts SET password='"+legacy+"' WHERE name='passivetest'")
        result=subprocess.run([sys.executable,str(ROOT/'tools/tests/client-login-integrity.py'),'--runtime',str(runtime),'--output',str(run/'ingress'),'--game-port','7188','--ingress'],capture_output=True,creationflags=subprocess.CREATE_NO_WINDOW)
        (run/'ingress.log').write_bytes(result.stdout+result.stderr)
        check(result.returncode==0,'existing native RH2 login and malformed-ingress probe works with RSA-2048')
    if not args.ui_only and not args.attack_only and not args.ingress_only and not args.management_only and not args.house_core and not args.house_market:
        boot();policy1=policy();check(policy1['account']==1 and policy1['character']==1 and policy1['limit']==3 and policy1['town'],'encrypted policy handshake')
        pw='AccountsLoopbackOnly'
        for account,password,email in [('abc',pw,'one@example.invalid'),('validqa','short','one@example.invalid'),('validqa',pw,''),('validqa',pw,'bad@host'),('validqa',pw,'a..b@example.invalid'),('validqa',pw,'a@-host.invalid')]:
            check(create(1,account,password,email)['success']==0,'invalid registration rejected '+str(len(report['checks'])))
        check(sql("SELECT COUNT(*) FROM accounts WHERE name='validqa'")=='0','rejected registration made no account')
        check(create(1,'nativeaccounts',pw,'native+qa@example.invalid')['success']==1,'mandatory email registration succeeds')
        stored=sql("SELECT password FROM accounts WHERE name='nativeaccounts'")
        check(stored.startswith('$rh$scrypt$1$131072$8$1$') and len(stored)>40,'registration stores versioned slow hash')
        parts=stored.split('$');salt=bytes.fromhex(parts[-2]);expected=bytes.fromhex(parts[-1])
        check(hashlib.scrypt(pw.encode(),salt=salt,n=131072,r=8,p=1,maxmem=256*1024*1024,dklen=32)==expected,'native scrypt matches independent standard implementation')
        check(sql("SELECT CONCAT(type,':',premium_ends_at,':',email) FROM accounts WHERE name='nativeaccounts'")=='1:0:native+qa@example.invalid','ordinary account privileges and email persisted')
        check(create(1,'NATIVEACCOUNTS',pw,'another@example.invalid')['success']==0,'case insensitive duplicate account rejected')
        check(login('nativeaccounts',pw).get('characters')==[],'ordinary login supports zero characters')
        check('error' in login('nativeaccounts','wrong'),'ordinary wrong-password login unchanged')
        for name,sex in [('God Pretender',1),('Bad  Spaces',1),('bad-name',1),('Short',2),('Crestwick',1)]:
            check(create(2,'nativeaccounts',pw,name,sex)['success']==0,'invalid or reserved character rejected '+name)
        check(create(2,'nativeaccounts','wrong','No Auth')['success']==0,'character credentials authenticated')
        aid=sql("SELECT id FROM accounts WHERE name='nativeaccounts'")
        ban_issuer=sql('SELECT MIN(id) FROM players');assert ban_issuer.isdigit(),'Missing ban fixture issuer'
        sql("INSERT INTO account_bans(account_id,reason,banned_at,expires_at,banned_by) VALUES ("+aid+",'fixture',UNIX_TIMESTAMP(),0,"+ban_issuer+")")
        check(create(2,'nativeaccounts',pw,'Banned Create')['success']==0,'banned account creation rejected');sql('DELETE FROM account_bans WHERE account_id='+aid)
        check(create(2,'nativeaccounts',pw,'fIRST hERO',1)['name']=='First Hero','canonical character created')
        check(create(2,'nativeaccounts',pw,'first hero',0)['success']==0,'case insensitive character duplicate rejected')
        row=sql("SELECT CONCAT(group_id,':',level,':',vocation,':',health,':',healthmax,':',mana,':',manamax,':',cap,':',sex,':',looktype,':',lastlogin) FROM players WHERE name='First Hero'")
        check(row=='1:1:0:150:150:0:0:400:1:128:0','fresh character values with no progression or privilege copying')
        racing=[connection() for _ in range(4)]
        for w in racing:w.handshake()
        def race(pair):
            w,name=pair
            try:return w.submit(2,'nativeaccounts',pw,name,0)['success']
            finally:w.close()
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:answers=list(pool.map(race,zip(racing,['Second Hero','Third Hero','Fourth Hero','Fifth Hero'])))
        check(sum(answers)==2 and sql('SELECT COUNT(*) FROM players WHERE account_id='+aid)=='3','parallel requests preserve character cap')
        check(len(login('nativeaccounts',pw)['characters'])==3,'ordinary character list refresh matches persisted creations')
        for extra in (b'\0',b'\x02'+string('nativeaccounts')):
            try:create(2,'nativeaccounts',pw,'Malformed Hero',1,extra);raise AssertionError('malformed request accepted')
            except (EOFError,ConnectionResetError):pass
        check(sql("SELECT COUNT(*) FROM players WHERE name='Malformed Hero'")=='0','trailing and stacked requests fail closed without mutation')
        # A real SQL error containing private input must be redacted, then rollback/reconnect.
        sql("CREATE TRIGGER accounts_qa_fail BEFORE INSERT ON accounts FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='private-marker@example.invalid'")
        check(create(1,'failureqa',pw,'private-marker@example.invalid')['success']==0,'SQL failure refused registration')
        sql('DROP TRIGGER accounts_qa_fail')
        check(sql("SELECT COUNT(*) FROM accounts WHERE name='failureqa'")=='0','failed registration rolled back')
        check(create(1,'failureqa',pw,'recovered@example.invalid')['success']==1,'normal database operations recover after failed transaction')
        text=log('server-'+str(phase));check('Private account operation failed' in text and 'private-marker@example.invalid' not in text and hashlib.sha1(pw.encode()).hexdigest() not in text,'private SQL input redacted from native errors')
        sql("CREATE TRIGGER characters_qa_fail BEFORE INSERT ON players FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='private-character-marker'")
        check(create(2,'failureqa',pw,'Failed Hero')['success']==0,'SQL failure refused character')
        sql('DROP TRIGGER characters_qa_fail')
        check(sql("SELECT COUNT(*) FROM players WHERE name='Failed Hero'")=='0' and create(2,'failureqa',pw,'Recovered Hero',0)['success']==1,'failed character transaction leaves no partial state and can retry')
        check(sql("SELECT looktype FROM players WHERE name='Recovered Hero'")=='136','female starter outfit persisted')
        lost=connection();lost.handshake()
        lost.send(b'\x01'+string('lostreplyqa')+string(pw)+string('lost@example.invalid'));lost.close()
        deadline=time.monotonic()+4
        while sql("SELECT COUNT(*) FROM accounts WHERE name='lostreplyqa'")!='1':
            assert time.monotonic()<deadline,'Disconnected submission was not committed';time.sleep(.05)
        check(create(1,'lostreplyqa',pw,'lost@example.invalid')['success']==0 and login('lostreplyqa',pw).get('characters')==[],
              'lost creation reply can reconcile by normal login without duplicate account')
        sql("INSERT INTO accounts(name,password,type,email) VALUES ('legacyqa','"+hashlib.sha1(b'short').hexdigest()+"',1,'')")
        check('error' in login('legacyqa','wrong') and sql("SELECT LENGTH(password) FROM accounts WHERE name='legacyqa'")=='40','wrong legacy password cannot upgrade or authenticate')
        check(login('legacyqa','short').get('characters')==[] and sql("SELECT password FROM accounts WHERE name='legacyqa'").startswith('$rh$scrypt$'),'existing short-password account upgrades on ordinary login')
        check(create(2,'legacyqa','short','Legacy Hero')['success']==1,'legacy accounts retain existing password and email rules when adding a character')
        sql("INSERT INTO accounts(name,password,type,email) VALUES ('legacychar','"+hashlib.sha1(b'short').hexdigest()+"',1,'')")
        check(create(2,'legacychar','short','Legacy Creator')['success']==1 and sql("SELECT password FROM accounts WHERE name='legacychar'").startswith('$rh$scrypt$'),'character creation upgrades legacy authentication too')
        check(sql("SELECT password FROM accounts WHERE name='legacyqa'")!=sql("SELECT password FROM accounts WHERE name='legacychar'"),'same passwords receive independent random salts')
        legacy=hashlib.sha1(b'short').hexdigest()
        sql("INSERT INTO accounts(name,password,type,email) VALUES ('legacyrace','"+legacy+"',1,'')")
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            answers=list(pool.map(lambda _:login('legacyrace','short'),range(2)))
        check(all(x.get('characters')==[] for x in answers) and sql("SELECT password FROM accounts WHERE name='legacyrace'").startswith('$rh$scrypt$'),'concurrent first logins preserve the migrated password')
        sql("UPDATE accounts SET password='$rh$scrypt$1$999999999999$8$1$malformed' WHERE name='legacyrace'")
        check('error' in login('legacyrace','short'),'malformed or attacker-selected stored work parameters fail closed')
        sql("UPDATE players SET deletion=UNIX_TIMESTAMP() WHERE name='First Hero'")
        check(create(2,'nativeaccounts',pw,'Replacement Hero')['success']==1 and len(login('nativeaccounts',pw)['characters'])==3,'soft deleted characters do not consume live character slots')
        sql("INSERT INTO ip_bans(ip,reason,banned_at,expires_at,banned_by) VALUES (16777343,'fixture',UNIX_TIMESTAMP(),0,"+ban_issuer+"),(2130706433,'fixture',UNIX_TIMESTAMP(),0,"+ban_issuer+")")
        check(policy().get('success')==0,'IP bans refuse the pre-login service')
        sql('DELETE FROM ip_bans WHERE ip IN (16777343,2130706433)')
        boot('\nclientAccountServicesEnabled = false\n')
        check(policy()['account']==0 and policy()['character']==0,'master feature flag closes both creations')
        check(create(1,'closedqa',pw,'closed@example.invalid')['success']==0 and len(login('nativeaccounts',pw)['characters'])==3,'closed service leaves ordinary login working')
        boot('\nclientAccountCreationEnabled = false\nclientCharacterTownId = 999999\n')
        check(policy()['account']==0 and policy()['character']==0,'registration flag and missing start town fail closed')
        check(create(2,'failureqa',pw,'Missing Town')['success']==0,'invalid start town cannot create unplayable character')
        boot('\nclientCharacterCreationEnabled = false\n')
        check(policy()['account']==1 and policy()['character']==0 and create(2,'failureqa',pw,'Closed Character')['success']==0,'character creation can close independently of registration')
        boot('\nclientAccountIpLimitPerHour = 2\n')
        check(create(1,'quotaone',pw,'one@example.invalid')['success']==1 and create(1,'quotatwo',pw,'two@example.invalid')['success']==1 and create(1,'quotathree',pw,'three@example.invalid')['success']==0,'per IP registration quota enforced')
    if args.management_only or (not args.ui_only and not args.attack_only and not args.ingress_only and not args.house_core and not args.house_market):
        boot()
        management_regressions(pem,sql,check)
        boot('\nclientAccountManagementEnabled = false\n')
        w=connection()
        try:check(not w.handshake(2)['management'],'management feature flag is advertised closed')
        finally:w.close()
        w=connection()
        try:check(w.manage(3,'managerqa','New fixture password')['success']==0,'management feature flag rejects direct actions')
        finally:w.close()
        check(len(login('managerqa','New fixture password')['characters'])==1,'closing management preserves ordinary account login')
        outbox=run/'private-mail';outbox.mkdir()
        boot('\nclientEmailVerificationEnabled = true\nclientPasswordRecoveryEnabled = true\nclientAccountMailOutbox = "'+outbox.as_posix()+'"\n')
        email_regressions(pem,sql,check,outbox)
    if args.web_public or args.guild_parity or args.guild_scale:
        assert args.house_market,'Public native-schema fixture requires --house-market'
        stop(server)
        # Native fixtures seed three ordinary characters. The web gets its own
        # SELECT-only principal and cannot initialize schema or move any funds.
        sql("INSERT INTO guilds(name,ownerid,creationdata,motd) SELECT 'Native Public Guild',id,UNIX_TIMESTAMP(),'Public description' FROM players WHERE name='Home Buyer'")
        guild_id=sql("SELECT id FROM guilds WHERE name='Native Public Guild'")
        # Native guild creation trigger supplies the standard ranks.
        rank_id=sql('SELECT id FROM guild_ranks WHERE guild_id='+guild_id+' AND level=3 LIMIT 1')
        sql('INSERT INTO guild_membership(player_id,guild_id,rank_id,nick) SELECT id,'+guild_id+','+rank_id+",'' FROM players WHERE name='Home Buyer'")
        boot('\nclientHouseMarketEnabled = true\n')
    if args.guild_parity:
        from guild import run as guild_regressions
        guild_regressions(pem,sql,check,guild_id)
    if args.guild_directory:
        from guild_directory import run as directory_regressions
        report['guild_directory']=directory_regressions(pem,sql,check,guild_id,boot,lambda:stop(server))
    if args.guild_ui_polish:
        account=sql("SELECT id FROM accounts WHERE name='homerival'")
        rank=sql('SELECT id FROM guild_ranks WHERE guild_id='+guild_id+' AND level=1 LIMIT 1')
        values=','.join("('UI Guild Member %s',%s,50)"%(chr(97+i),account) for i in range(20))
        sql('INSERT INTO players(name,account_id,level) VALUES'+values)
        sql("INSERT INTO guild_membership(player_id,guild_id,rank_id,nick) SELECT id,"+guild_id+','+rank+",'' FROM players WHERE name LIKE 'UI Guild Member %'")
        pixels=bytes([40,95,140,255])*1024
        sql('INSERT INTO guild_emblems(guild_id,revision,pixels,day,changes) VALUES('+guild_id+",1,UNHEX('"+pixels.hex()+"'),0,0)")
        logs=','.join("(%s,'Home Buyer','motd_updated','{}',UNIX_TIMESTAMP()+%d)"%(guild_id,i) for i in range(30))
        sql('INSERT INTO guild_activity_logs(guild_id,actor_name,event_key,payload_json,created_at) VALUES'+logs)
    if args.guild_scale:
        from guild_scale import run as guild_scale_regressions
        report['guild_scale']=guild_scale_regressions(pem,sql,check,guild_id,boot)
    if args.web_public:
        read_password=os.urandom(24).hex()
        grant="CREATE USER 'web_public_qa'@'127.0.0.1' IDENTIFIED BY '"+read_password+"'; GRANT SELECT ON rookhaven_accounts_qa.* TO 'web_public_qa'@'127.0.0.1';"
        assert subprocess.run(root_cmd+['--execute='+grant],env=root_env,capture_output=True,creationflags=subprocess.CREATE_NO_WINDOW).returncode==0,'read-only public test principal'
        web_env=os.environ.copy()
        web_env['ROOKHAVEN_TEST_DATABASE']='Server=127.0.0.1;Port=33314;Database=rookhaven_accounts_qa;User=web_public_qa;Password='+read_password+';'
        web_env['ConnectionStrings__TibiaDatabase']=web_env['ROOKHAVEN_TEST_DATABASE']
        web_house=sql("SELECT MIN(id) FROM houses WHERE owner=(SELECT id FROM players WHERE name='Home Buyer')")
        web_env['ROOKHAVEN_TEST_HOUSE_ID']=web_house
        web_env['ROOKHAVEN_TEST_GUILD_ID']=guild_id
        before=sql('SELECT id,balance FROM players ORDER BY id')
        # A cancelled listing must not hide the latest active one. Private
        # pending terms/offers must not become public through the old web DTO.
        sql("INSERT INTO web_house_sale_listings(house_id,owner_player_id,sale_type,status,asking_price) SELECT "+web_house+",id,'direct','cancelled',123 FROM players WHERE name='Home Buyer'")
        web_listing=sql("INSERT INTO web_house_sale_listings(house_id,owner_player_id,sale_type,status,asking_price) SELECT "+web_house+",id,'direct','active',456 FROM players WHERE name='Home Buyer';SELECT LAST_INSERT_ID()")
        web_offer=sql("INSERT INTO web_house_buy_offers(house_id,buyer_player_id,offer_amount,status) SELECT "+web_house+",id,789,'active' FROM players WHERE name='Home Seller';SELECT LAST_INSERT_ID()")
        web_pending=sql("INSERT INTO web_house_pending_transfers(house_id,from_player_id,to_player_id,agreed_price,status,transfer_type) SELECT "+web_house+",(SELECT id FROM players WHERE name='Home Buyer'),id,987,'pending_server_save','native_offer' FROM players WHERE name='Home Seller';SELECT LAST_INSERT_ID()")
        dotnet=ROOT/'out/account-management-20261116/dotnet/dotnet.exe'
        result=subprocess.run([str(dotnet),'test','RookHavenWeb.Server.Tests.Integration','--filter','FullyQualifiedName~NativePublicReadTests','--verbosity','minimal'],cwd=ROOT.parent/'RookhavenWeb',env=web_env,capture_output=True,creationflags=subprocess.CREATE_NO_WINDOW)
        (run/'web-public.log').write_bytes(result.stdout+result.stderr)
        sql('DELETE FROM web_house_pending_transfers WHERE id='+web_pending)
        sql('DELETE FROM web_house_buy_offers WHERE id='+web_offer)
        sql('DELETE FROM web_house_sale_listings WHERE id='+web_listing)
        check(result.returncode==0,'public website reads native schema using SELECT-only credentials')
        check(sql('SELECT id,balance FROM players ORDER BY id')==before,'public website queries never change player banks')
    if args.client:
        if args.house_market and not args.house_ui_only and not args.guild_ui:
            stop(server)
            house_id=sql("SELECT COALESCE(MIN(CASE WHEN owner=(SELECT id FROM players WHERE name='Home Buyer') THEN id END),MIN(id)) FROM houses")
            sql("UPDATE houses SET owner=(SELECT id FROM players WHERE name='Home Buyer'),bid=0,bid_end=0,highest_bidder=0 WHERE id="+house_id)
            # The market expiry case intentionally removes seller premium. Reset only
            # these owned UI actors before exercising recipient acceptance.
            sql("UPDATE accounts SET premium_ends_at=UNIX_TIMESTAMP()+864000 WHERE name IN ('homeseller','homebuyer')")
        boot()
        before_profile=digest(profile)
        if profile.exists():shutil.copytree(profile,run/'profile-before')
        client=run/'client';shutil.copytree(args.client.resolve(),client)
        report['client_sha256']=hashlib.sha256((client/'RookhavenClient.exe').read_bytes()).hexdigest()
        with zipfile.ZipFile(client/'data.zip') as z:entries={n:z.read(n) for n in z.namelist()}
        # A retained owned QA package can already contain the wrapper from a
        # previous run. Preserve its original startup instead of nesting it.
        original_startup=entries.pop('init.luac')
        if 'startup_original.luac' not in entries:entries['startup_original.luac']=original_startup
        entries['init.lua']=b"function T() dofile('/accounts-probe.lua') end\nreturn dofile('/startup_original.lua')\n"
        driver='native-guild-directory.lua' if args.guild_directory else 'native-guild-polish.lua' if args.guild_ui_polish else 'native-guild-client.lua' if args.guild_ui else 'native-house-client.lua' if args.house_market else 'native-client.lua'
        entries['test.lua']=b'T()\n';entries['accounts-probe.lua']=Path(__file__).with_name(driver).read_bytes().replace(b'__GUILD_UI__',b'true' if args.guild_parity else b'false').replace(b'__RECIPIENT_UI__',b'false' if args.guild_parity else b'true')
        house_towns={h.attrib['houseid']:int(h.attrib['townid']) for h in ET.parse(runtime/'data/world/Untitled-1-house.xml').getroot()}
        entries['accounts-probe.lua']=entries['accounts-probe.lua'].replace(b'__HOUSE_TOWN_EXPECTATIONS__',json.dumps(house_towns).encode())
        photo_manifest=ROOT/'modules/game_cyclopedia/images/houses/rookhaven/manifest.json'
        entries['accounts-probe.lua']=entries['accounts-probe.lua'].replace(b'__HOUSE_PHOTO_MANIFEST__',photo_manifest.read_bytes() if photo_manifest.exists() else b'{"houses":[]}')
        entries['accounts-probe.lua']=entries['accounts-probe.lua'].replace(b'__SHOP_UI__',b'true' if args.shop_ui else b'false')
        if args.house_photos:
            entries['accounts-probe.lua']=(ROOT/'tools/house-photos/native-client.lua').read_bytes().replace(b'__PHOTO_CATALOGUE__',(runtime/'house-photo-catalogue.json').read_bytes()).replace(b'__PHOTO_LIMIT__',str(args.house_photo_limit).encode())
        for folder in ('client_entergame','gamelib','game_cyclopedia','game_guild','game_shop'):
            for f in (ROOT/'modules'/folder).rglob('*'):
                if not f.is_file():continue
                native_house_photo=f.is_relative_to(ROOT/'modules/game_cyclopedia/images/houses/rookhaven') and f.suffix in ('.png','.json')
                shop_image=f.is_relative_to(ROOT/'modules/game_shop/images') and f.suffix=='.png'
                if f.suffix not in ('.lua','.otui','.otmod') and not native_house_photo and not shop_image:continue
                n=f.relative_to(ROOT).as_posix();entries.pop(n[:-4]+'.luac',None) if n.endswith('.lua') else None;entries[n]=f.read_bytes()
        entries['layouts/retro/styles/40-entergame.otui']=(ROOT/'layouts/retro/styles/40-entergame.otui').read_bytes()
        if entries['startup_original.luac'].startswith(b'ENC3'):
            assert args.encoder,'Encrypted QA package requires --encoder for its owned test overlays'
            overlay=run/'encoded-overlays';overlay.mkdir()
            for folder in ('data','modules','layouts'):(overlay/folder).mkdir()
            entries['init.luac']=entries.pop('init.lua');mapping={}
            for name,content in entries.items():
                if content.startswith(b'ENC3'):continue
                relative=name if name=='init.luac' or name.split('/')[0] in ('data','modules','layouts') else 'data/__probe_root__/'+name
                target=overlay/relative;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(content);mapping[name]=target
            seed=re.search(r'set\(RUNTIME_DATA_ZIP_PASSWORD\s+"([^"]+)"',(ROOT/'CMakeLists.txt').read_text())[1]
            seed_file=run/'overlay-seed.u32';seed_file.write_text(str(zlib.adler32(seed.encode())&0xffffffff))
            encoder=[str(args.encoder.resolve())]
            if args.encoder.suffix=='.py':encoder.insert(0,sys.executable)
            encoded=subprocess.run(encoder+[str(overlay),str(seed_file)],capture_output=True,creationflags=subprocess.CREATE_NO_WINDOW)
            (run/'overlay-encoder.log').write_bytes(encoded.stdout+encoded.stderr);assert encoded.returncode==0,'QA overlay encryption failed'
            for name,target in mapping.items():
                content=target.read_bytes();assert content.startswith(b'ENC3'),name;entries[name]=content
        with zipfile.ZipFile(client/'data.zip','w',zipfile.ZIP_DEFLATED) as z:
            for n,b in entries.items():z.writestr(n,b)
        subprocess.run(['python',str(ROOT/'tools/passives/package-checksums.py'),str(client/'data.zip'),str(runtime/'data/checksum_expected.txt')],check=True,capture_output=True)
        shutil.copyfile(Path(__file__).with_name('native-server.lua'),runtime/'data/scripts/accounts-owned-qa.lua')
        boot('\nclientHouseMarketEnabled = true\n' if args.house_market else '')
        app=start(client/'RookhavenClient.exe',['--local-passives','--test'],'client',client)
        expected='GUILDS_DIRECTORY_NATIVE_OK' if args.guild_directory else 'GUILDS_POLISH_NATIVE_OK' if args.guild_ui_polish else 'GUILDS_UI_NATIVE_OK' if args.guild_ui else 'HOUSE_PHOTOS_OK' if args.house_photos else 'HOUSES_UI_NATIVE_OK' if args.house_market else 'ACCOUNTS_UI_NATIVE_OK'
        report['client_exit_code']=app.wait(timeout=600 if args.guild_ui else 300 if args.guild_directory else 270 if args.house_photos else 180)
        check(report['client_exit_code']==0 and expected in log('client'),'native public guild directory, foreign profiles and existing management' if args.guild_directory else 'native member/leader guild layout and actual scroll overflow' if args.guild_ui_polish else 'native large-guild and emblem UI' if args.guild_ui else 'native house framebuffer photographs' if args.house_photos else 'native housing UI' if args.house_market else 'native account and character UI with normal first login and reconnect')
        report['client_log_tail']=log('client')[-1200:]
        for f in profile.glob('accounts-*.png'):shutil.copyfile(f,run/f.name)
        if args.guild_directory:
            check(sql('SELECT COUNT(*) FROM guild_membership WHERE guild_id='+guild_id)=='152','directory UI preserves every guild membership')
            check(sql('SELECT revision FROM guild_emblems WHERE guild_id='+guild_id)=='1','directory UI preserves the saved emblem')
            check(sql('SELECT recruitment_status FROM guilds WHERE id='+guild_id)=='2','leader recruitment UI persists the selected status')
        elif args.guild_ui_polish:
            check(sql('SELECT COUNT(*) FROM guild_membership WHERE guild_id='+guild_id)=='22','UI review preserves every guild membership')
            check(sql('SELECT revision FROM guild_emblems WHERE guild_id='+guild_id)=='1','read-only member/leader review preserves the chosen emblem')
            check(sql('SELECT motd FROM guilds WHERE id='+guild_id)=='','leader can clear the description through the native UI')
        elif args.guild_ui:
            check(sql('SELECT name FROM guilds WHERE id='+guild_id)=='UI Renamed Guild','guild rename UI still persists')
            check(sql('SELECT revision FROM guild_emblems WHERE guild_id='+guild_id)=='5','native PNG chooser, preview and Save persist a new emblem revision')
        elif args.house_market and not args.house_photos:
            check(sql("SELECT COUNT(*) FROM house_lists h JOIN houses x ON x.id=h.house_id JOIN players p ON p.id=x.owner WHERE p.name='Home Buyer' AND h.list LIKE '%Home Seller%'")=='1','native access editor persisted guest list')
            if args.guild_parity:
                check(sql('SELECT name FROM guilds WHERE id='+guild_id)=='UI Renamed Guild','native guild rename UI persisted and refreshed')
                check(sql('SELECT COUNT(*) FROM guild_invites WHERE guild_id='+guild_id)=='0','native invitation withdrawal UI persisted')
        elif not args.house_photos:
            check(sql("SELECT COUNT(*) FROM players WHERE name='Ui New Hero' AND level=1 AND vocation=0 AND group_id=1 AND sex=0 AND looktype=136")=='1','UI character keeps the selected sex and ordinary starter outfit/progression')
            check(sql("SELECT COUNT(*) FROM guilds WHERE name='Accounts QA Guild'")=='1','in-game Guildmaster creation persisted')
    if args.guild_scale:
        from guild_scale import finish_disband
        finish_disband(pem,sql,check,guild_id)
    report['status']='PASS'
finally:
    for child in reversed(processes):stop(child)
    for h in handles:h.close()
    if 'before_profile' in globals():
        for f in profile.glob('accounts-*.png'):shutil.copyfile(f,run/f.name)
        for f in profile.rglob('*'):
            if f.is_file() and f.relative_to(profile).as_posix() not in before_profile:f.unlink()
        if (run/'profile-before').exists():shutil.copytree(run/'profile-before',profile,dirs_exist_ok=True)
        report['profile_restored']=digest(profile)==before_profile
    if 'original_db' in globals():report['cold_source_unchanged']=digest(LOCAL/'passives-db')==original_db and (LOCAL/'passives-runtime/config.lua').read_bytes()==original_config
    report['owned_processes_stopped']=all(x.poll() is not None for x in processes)
    (run/'result.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
