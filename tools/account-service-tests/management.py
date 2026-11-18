"""Account-management regressions in the runner's disposable native database."""
import base64,hashlib,hmac,json,socket,struct,time,concurrent.futures
from wire import Wire,string,u16

def code(secret):
    counter=struct.pack('>Q',int(time.time())//30)
    digest=hmac.new(base64.b32decode(secret),counter,hashlib.sha1).digest();offset=digest[-1]&15
    return f'{(int.from_bytes(digest[offset:offset+4],"big")&0x7fffffff)%1000000:06d}'

def run(pem,sql,check):
    account='managerqa';password='Manager fixture password';secret=None
    def create(action,name,pw,value,sex=1,token=''):
        w=Wire(pem,7187)
        try:
            if not token:return w.create(action,name,pw,value,sex)
            w.handshake(2);w.send(bytes([action])+string(name)+string(pw)+string(value)+(bytes([sex]) if action==2 else b'')+string(token)+string(''))
            reply=w.receive();assert reply.byte()==0x12;return w.result(reply)
        finally:w.close()
    def manage(action,value='',extra='',pw=None,token=None,name=account):
        w=Wire(pem,7187)
        try:return w.manage(action,name,password if pw is None else pw,value,code(secret) if token is None and secret else token or '',extra)
        finally:w.close()
    def login(token=''):
        w=Wire(pem,7187)
        try:return w.login(account,password,token)
        finally:w.close()
    def world(token=''):
        w=Wire(pem,7188)
        def exact(size):
            data=b''
            while len(data)<size:
                part=w.socket.recv(size-len(data))
                if not part:raise EOFError('short game challenge')
                data+=part
            return data
        challenge=exact(struct.unpack('<H',exact(2))[0])
        timestamp,random=struct.unpack('<IB',challenge[-5:])
        credentials=b'\0'+struct.pack('<4I',*w.key)+b'\0'+string(account)+string('Managed Hero')+string(password)+struct.pack('<IB',timestamp,random)+string('RH2')
        if token:credentials+=string('MFA1')+string(token)
        proof=hashlib.sha256(f'RH2|{"a"*64}|{"b"*64}|{timestamp}|{random}'.encode()).hexdigest()
        w.send(b'\x0a'+u16(10)+u16(860)+w.rsa(credentials)+w.rsa(b'\0\0'+string(proof)),False)
        for _ in range(10):
            reply=w.receive();raw=reply.data
            if raw.startswith(b'\x32\0\0\0'):raw=raw[4:]
            if raw and raw[0] in (0x0a,0x17):return w,True
            if raw and raw[0]==0x14:return w,False
        w.close();raise AssertionError('no game login response')
    w=Wire(pem,7187)
    try:policy=w.handshake(2)
    finally:w.close()
    check(policy['management'] and policy['twoFactor'] and not policy['emailVerification'] and not policy['passwordRecovery'],'RHA2 advertises management and disabled-by-default email/recovery')
    check(create(1,account,password,'manager@example.invalid')['success']==1,'management fixture registered using existing encrypted registration')
    check(create(2,account,password,'Managed Hero')['success']==1,'management fixture uses ordinary Unawakened character creation')
    aid=sql("SELECT id FROM accounts WHERE name='managerqa'");pid=sql("SELECT id FROM players WHERE name='Managed Hero'")
    overview=manage(3)
    check(overview['success']==1 and overview['data']['account']==account and len(overview['data']['characters'])==1,'account overview returns only authenticated account and its characters')
    check(manage(3,pw='wrong')['success']==0 and manage(3,name="' OR '1'='1")['success']==0,'overview refuses wrong credentials and SQL account injection')
    check(manage(11)['success']==0 and manage(13,value='manager@example.invalid',pw='')['success']==0,'disabled email features reject direct requests without queuing messages')
    stored=sql('SELECT password FROM accounts WHERE id='+aid)
    check(manage(4,value='New fixture password',extra='different')['success']==0 and sql('SELECT password FROM accounts WHERE id='+aid)==stored,'mismatched password confirmation preserves current password')
    check(manage(4,value='New fixture password',extra='New fixture password',pw='wrong')['success']==0,'password change requires current password')
    check(manage(4,value='New fixture password',extra='New fixture password')['success']==1,'authenticated password change commits a new native hash')
    check('error' in login() and sql('SELECT password FROM accounts WHERE id='+aid)!=stored,'previous password stops authenticating after change')
    password='New fixture password'
    check(len(login()['characters'])==1,'ordinary login works with changed password')
    setup=manage(6);secret=setup['data']['secret'];check(setup['success']==1 and len(secret)==32,'authenticator setup returns a fresh 160-bit manual key')
    check(not sql('SELECT COALESCE(secret,\'\') FROM accounts WHERE id='+aid),'pending authenticator does not lock out ordinary login')
    check(manage(7,value='bad',token='')['success']==0,'unverified authenticator cannot be enabled')
    enabled=manage(7,value=code(secret),token='');check(enabled['success']==1 and len(enabled['data']['recoveryCodes'])==10,'TOTP possession enables authenticator and returns recovery codes once')
    first=enabled['data']['recoveryCodes']
    check(manage(3,token='')['success']==0 and 'error' in login(),'2FA cannot be bypassed through account overview or ordinary character-list login')
    check(create(2,account,password,'Bypass Hero')['success']==0,'legacy character service cannot bypass enabled 2FA')
    check(manage(3,token='xxxxxx')['success']==0 and 'error' in login('xxxxxx'),'malformed or incorrect authenticator codes fail closed')
    check(len(login(code(secret))['characters'])==1,'ordinary character-list login accepts a current authenticator code')
    for token,label in [('', 'missing'),('xxxxxx','malformed')]:
        game,accepted=world(token)
        try:check(not accepted,'actual game-world login refuses '+label+' authenticator code')
        finally:game.close()
    game,accepted=world(code(secret))
    try:
        check(accepted,'actual RH2 game-world login accepts current authenticator code')
        check(manage(5,value='Managed Hero',extra='Managed Hero')['success']==0,'actual online character cannot be deleted through account management')
    finally:
        game.send(b'\x14') # ordinary game logout; disconnect alone has a grace period
        time.sleep(.3);game.close()
    time.sleep(1)
    check(create(2,account,password,'Factor Hero',token=code(secret))['success']==1,'RHA2 character creation accepts MFA and preserves the existing creation path')
    hashes=sql('SELECT code_hash FROM account_recovery_codes WHERE account_id='+aid).splitlines()
    check(len(hashes)==10 and all(len(x)==64 and x not in first for x in hashes),'only hashes of recovery codes are persisted')
    check(manage(6)['success']==0,'an enabled authenticator cannot silently be replaced by setup')
    replacement=manage(9);second=replacement['data']['recoveryCodes']
    check(replacement['success']==1 and len(second)==10 and not set(first)&set(second),'recovery-code regeneration invalidates the previous set')
    check(manage(10,token=first[0])['success']==0 and manage(10,token=second[0],pw='wrong')['success']==0,'lost-authenticator recovery requires an unused code and the account password')
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        recovered=list(pool.map(lambda _:manage(10,token=second[0]),range(2)))
    check(sum(x['success'] for x in recovered)==1,'concurrent recovery-code use commits exactly one authenticator recovery')
    secret=None
    check(sql('SELECT COUNT(*) FROM account_recovery_codes WHERE account_id='+aid)=='0' and manage(10,token=second[1])['success']==0,'recovered authenticator invalidates all old recovery codes')
    check(len(login()['characters'])==2,'account password remains usable after explicit authenticator recovery')
    check(manage(5,value='Managed Hero',extra='Wrong Name')['success']==0,'character deletion requires exact name confirmation')
    check(manage(5,value='Managed Hero',extra='Managed Hero',pw='wrong')['success']==0,'character deletion requires the account password')
    check(create(1,'foreignmanager',password,'foreign@example.invalid')['success']==1 and create(2,'foreignmanager',password,'Foreign Hero')['success']==1,'foreign ownership fixture created through ordinary services')
    check(manage(5,value='Foreign Hero',extra='Foreign Hero')['success']==0 and sql("SELECT deletion FROM players WHERE name='Foreign Hero'")=='0','account cannot delete another account\'s character')
    sql("INSERT INTO guilds(name,ownerid,creationdata,motd) VALUES ('Management Guard',"+pid+",UNIX_TIMESTAMP(),'')")
    check(manage(5,value='Managed Hero',extra='Managed Hero')['success']==0,'guild leadership blocks character deletion')
    sql("DELETE FROM guilds WHERE name='Management Guard'")
    house=sql('SELECT id FROM houses LIMIT 1')
    if house:
        owner=sql('SELECT owner FROM houses WHERE id='+house)
        sql('UPDATE houses SET owner='+pid+' WHERE id='+house)
        try:check(manage(5,value='Managed Hero',extra='Managed Hero')['success']==0,'house ownership blocks character deletion')
        finally:sql('UPDATE houses SET owner='+owner+' WHERE id='+house)
    sql('UPDATE players SET group_id=6 WHERE id='+pid)
    check(manage(5,value='Managed Hero',extra='Managed Hero')['success']==0,'staff character deletion fails closed')
    sql('UPDATE players SET group_id=1 WHERE id='+pid)
    sql('UPDATE players SET ps_mode=1 WHERE id='+pid)
    try:check(manage(5,value='Managed Hero',extra='Managed Hero')['success']==0,'offline Personal Store mode blocks deletion')
    finally:sql('UPDATE players SET ps_mode=0 WHERE id='+pid)
    sql('INSERT INTO personal_store_items(seller_guid,itemid,count,price,attributes) VALUES ('+pid+",2379,1,10,X'00')")
    try:check(manage(5,value='Managed Hero',extra='Managed Hero')['success']==0,'unsold Personal Store listings block deletion even without mode flag')
    finally:sql('DELETE FROM personal_store_items WHERE seller_guid='+pid)
    if house:
        bidder=sql('SELECT highest_bidder FROM houses WHERE id='+house)
        sql('UPDATE houses SET highest_bidder='+pid+' WHERE id='+house)
        try:check(manage(5,value='Managed Hero',extra='Managed Hero')['success']==0,'house auction participation blocks deletion')
        finally:sql('UPDATE houses SET highest_bidder='+bidder+' WHERE id='+house)
    # Simulate optional legacy website tables; no real website database is used.
    sql('CREATE TABLE IF NOT EXISTS web_house_pending_transfers(id INT PRIMARY KEY,from_player_id INT,to_player_id INT,status VARCHAR(32))')
    sql("INSERT INTO web_house_pending_transfers(id,house_id,to_player_id,status) VALUES (9999,"+house+","+pid+",'pending_server_save')")
    try:check(manage(5,value='Managed Hero',extra='Managed Hero')['success']==0,'pending paid house transfer blocks recipient deletion')
    finally:sql('DELETE FROM web_house_pending_transfers WHERE id=9999')
    sql('CREATE TABLE IF NOT EXISTS web_house_buy_offers(id INT PRIMARY KEY,buyer_player_id INT,status VARCHAR(32))')
    sql("INSERT INTO web_house_buy_offers(id,house_id,buyer_player_id,offer_amount,status) VALUES (9999,"+house+","+pid+",100,'active')")
    try:check(manage(5,value='Managed Hero',extra='Managed Hero')['success']==0,'reserved legacy house offer blocks character deletion')
    finally:sql('DELETE FROM web_house_buy_offers WHERE id=9999')
    sql('CREATE TABLE IF NOT EXISTS web_house_auto_bids(id INT PRIMARY KEY,player_id INT,reserved_amount INT)')
    sql('INSERT INTO web_house_auto_bids(id,house_id,player_id,max_bid_amount,reserved_amount) VALUES (9999,'+house+','+pid+',100,100)')
    try:check(manage(5,value='Managed Hero',extra='Managed Hero')['success']==0,'reserved auto-bid gold blocks character deletion')
    finally:sql('DELETE FROM web_house_auto_bids WHERE id=9999')
    deleted=manage(5,value='Managed Hero',extra='Managed Hero')
    check(deleted['success']==1 and sql('SELECT deletion FROM players WHERE id='+pid)!='0','owned offline character deletion is persisted without touching other characters: '+deleted['message'])
    check(len(login()['characters'])==1 and manage(3)['data']['characters'][0]['name']=='Factor Hero','ordinary login and account overview exclude deleted characters')
    sql("CREATE TRIGGER management_password_failure BEFORE UPDATE ON accounts FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='owned fixture failure'")
    before=sql('SELECT password FROM accounts WHERE id='+aid)
    try:check(manage(4,value='Transaction fixture password',extra='Transaction fixture password')['success']==0 and sql('SELECT password FROM accounts WHERE id='+aid)==before,'failed password transaction preserves existing authentication')
    finally:sql('DROP TRIGGER management_password_failure')
    check(len(login()['characters'])==1,'ordinary account login recovers after a failed management write')


def email_regressions(pem,sql,check,outbox):
    """Opt-in native code against a private owned queue, without a mail sender."""
    account='managerqa';password='New fixture password'
    aid=sql("SELECT id FROM accounts WHERE name='managerqa'")
    def manage(action,value='',token='',extra='',name=account,pw=password):
        w=Wire(pem,7187)
        try:return w.manage(action,name,pw,value,token,extra)
        finally:w.close()
    generic=manage(13,value='manager@example.invalid',pw='')
    unknown=manage(13,value='unknown@example.invalid',name='unknownmanager',pw='')
    check(generic==unknown and not list(outbox.glob('*.json')),'unknown and unverified email recovery return the same result without mail')
    check(manage(11)['success']==1,'explicitly enabled email verification queues a native job')
    jobs=list(outbox.glob('*.json'));assert len(jobs)==1
    job=json.loads(jobs[0].read_text());token=job['code']
    check(job['purpose']=='email_verification' and job['to']=='manager@example.invalid' and len(token)==64 and sql('SELECT token_hash FROM account_security_tokens WHERE account_id='+aid)==hashlib.sha256(token.encode()).hexdigest(),'committed email job matches hashed account-bound verification token')
    check(manage(11)['success']==0 and len(list(outbox.glob('*.json')))==1,'email request cooldown prevents repeated queue jobs')
    check(manage(12,value='0'*64)['success']==0 and manage(12,value=token)['success']==1 and manage(12,value=token)['success']==0,'verification requires exact unused code and consumes it once')
    sql('UPDATE account_security SET next_mail_at=0 WHERE account_id='+aid)
    check(manage(13,value='wrong@example.invalid',pw='')==generic and len(list(outbox.glob('*.json')))==1,'incorrect registered email does not expose account or issue a reset')
    check(manage(13,value='manager@example.invalid',pw='')==generic,'verified email recovery retains generic acknowledgement')
    reset=[json.loads(p.read_text()) for p in outbox.glob('*.json') if json.loads(p.read_text())['purpose']=='password_reset'];assert len(reset)==1
    new='Email fixture password'
    check(manage(14,value=new,token=reset[0]['code'],extra='mismatch',pw='')['success']==0,'reset password confirmation failure preserves token and password')
    setup=manage(6);secret=setup['data']['secret'];assert manage(7,value=code(secret))['success']==1
    check(manage(14,value=new,token=reset[0]['code'],extra=new,pw='')['success']==1 and sql('SELECT secret FROM accounts WHERE id='+aid)==secret,'verified email reset changes password while preserving authenticator protection')
    check(manage(14,value=new,token=reset[0]['code'],extra=new,pw='')['success']==0,'password reset token is single-use')
    w=Wire(pem,7187)
    try:check(len(w.login(account,new,code(secret))['characters'])==1,'normal MFA login works after email password reset')
    finally:w.close()


def house_live_regressions(pem,sql,check):
    account,password,name='housewalletqa','House wallet fixture password','House Wallet Hero'
    def create(action,value):
        w=Wire(pem,7187)
        try:return w.create(action,account,password,value)
        finally:w.close()
    check(create(1,'house-wallet@example.invalid')['success']==1 and create(2,name)['success']==1,'live house wallet fixture uses ordinary native registration and creation')
    guid=sql("SELECT id FROM players WHERE name='House Wallet Hero'")
    sql('CREATE TABLE owned_house_live_receipts(label VARCHAR(32) PRIMARY KEY) ENGINE=InnoDB')
    for label,balance,receipts in [('commit_unknown_before','1025','0'),('commit_unknown_after','925','1')]:
        game=Wire(pem,7188)
        try:
            check(game.game_login(account,name,password),'ordinary RH2 world login for live wallet fault '+label)
            game.send(b'\x96\x01'+string('/housewalletqa '+label))
            disconnected=False
            try:
                while True:game.receive()
            except (EOFError,ConnectionResetError):disconnected=True
            check(disconnected,'uncertain live wallet commit disconnects the stale player '+label)
        finally:game.close()
        check(sql('SELECT balance FROM players WHERE id='+guid)==balance and sql("SELECT COUNT(*) FROM owned_house_live_receipts WHERE label='"+label+"'")==receipts,'live bank and receipt preserve the authoritative commit outcome '+label)
        check(sql('SELECT COUNT(*) FROM player_items WHERE player_id='+guid+' AND itemtype=2148')=='0','bank deposit consumption is saved before an uncertain market commit '+label)
        game=Wire(pem,7188)
        try:
            check(game.game_login(account,name,password),'normal world reconnect works after wallet quarantine '+label)
            game.send(b'\x14');time.sleep(.3)
        finally:game.close()
        check(sql('SELECT balance FROM players WHERE id='+guid)==balance,'reconnect never overwrites or repeats the bank commit '+label)
