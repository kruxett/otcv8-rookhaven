"""Real encrypted guild RPCs, large SQL fixture and durable emblem boundaries.

Only the account-service runner's disposable loopback database is accepted.
"""
import base64,hashlib,json,time
from wire import Wire,string


def run(pem,sql,check,guild_id,boot):
    assert sql('SELECT DATABASE()')=='rookhaven_accounts_qa'
    guild_id=int(guild_id);clients=[];sequence=0;largest=0
    def connect(account='homebuyer',name='Home Buyer'):
        w=Wire(pem,7188);assert w.game_login(account,name,'HouseFixtureOnly');clients.append(w);return w
    def request(w,action,**fields):
        nonlocal sequence,largest
        time.sleep(.22);sequence+=1
        # The real client answers game pings continuously. Keep both wire
        # actors alive while one of them walks a hundred pages.
        for peer in clients:
            try:peer.send(b'\x1e')
            except OSError:pass
        keyed=action in ('open','emblem')
        payload=dict(action=action,**fields)
        if keyed:payload['requestId']=sequence
        w.send(b'\x32\x65'+string(json.dumps(payload,separators=(',',':'))))
        deadline=time.monotonic()+7
        while time.monotonic()<deadline:
            data=w.receive().data;offset=0
            while True:
                i=data.find(b'\x32\x65',offset)
                if i<0:break
                offset=i+2
                if i+4>len(data):continue
                size=int.from_bytes(data[i+2:i+4],'little');raw=data[i+4:i+4+size]
                try:value=json.loads(raw)
                except (ValueError,UnicodeError):continue
                completed=value.get('type')=='guild_refresh' and action in ('leave','accept_invite','decline_invite','transfer_leadership','disband')
                if (keyed and value.get('requestId')==sequence) or value.get('type')=='error' or (not keyed and (value.get('type')=='success' or completed)):
                    largest=max(largest,size);assert size<7900,(action,size)
                    return value
        raise AssertionError('Guild RPC timed out: '+action)
    def opened(w,section='members',**fields):
        value=request(w,'open',section=section,**fields)
        assert value['type']=='guild_data',value
        return value
    def expect(w,action,ok=True,**fields):
        value=request(w,action,**fields)
        assert value['type'] in (('success','guild_refresh') if ok else ('error',)),(action,value)
        return value
    def letters(n):
        return ''.join(chr(97+(n//26**power)%26) for power in (3,2,1,0))
    def seed(prefix,count):
        account=sql("SELECT id FROM accounts WHERE name='homerival'")
        names=[prefix+' '+letters(n) for n in range(count)]
        for start in range(0,count,80):
            values=','.join("('%s',%s,%d)"%(name,account,100+start+i) for i,name in enumerate(names[start:start+80]))
            sql('INSERT INTO players(name,account_id,level) VALUES'+values)
        return names
    def upload(w,pixels,revision=0):
        text=base64.b64encode(pixels).decode()
        return request(w,'set_emblem',revision=revision,first=text[:2732],second=text[2732:])
    member_rank=int(sql(f'SELECT id FROM guild_ranks WHERE guild_id={guild_id} AND level=1 LIMIT 1'))
    names=seed('Scale Member',1000)
    sql(f"INSERT INTO guild_membership(player_id,guild_id,rank_id,nick) SELECT id,{guild_id},{member_rank},'' FROM players WHERE name LIKE 'Scale Member %'")
    guests=seed('Scale Guest',230)
    sql(f"INSERT INTO guild_invites(player_id,guild_id,created_at,expires_at) SELECT id,{guild_id},UNIX_TIMESTAMP(),UNIX_TIMESTAMP()+86400 FROM players WHERE name LIKE 'Scale Guest %'")
    for start in range(0,120,40):
        values=','.join(f"({guild_id},'Home Buyer','emblem_updated','{{}}',{int(time.time())+n})" for n in range(start,start+40))
        sql('INSERT INTO guild_activity_logs(guild_id,actor_name,event_key,payload_json,created_at) VALUES'+values)
    metrics={'seeded_members':1000,'seeded_invitations':230}
    try:
        leader=connect();member=connect('homeseller','Home Seller')
        total=int(sql(f'SELECT COUNT(*) FROM guild_membership WHERE guild_id={guild_id}'))
        first=opened(leader)
        check(first['memberCount']==total and total>1000,'native overview counts more than 1000 guild members')
        ids=[]
        for page in range(1,first['paging']['pages']+1):
            value=first if page==1 else opened(leader,page=page)
            assert len(value['members'])<=10
            ids.extend(x['id'] for x in value['members'])
        check(len(ids)==total and len(set(ids))==total,'every member is reachable exactly once across all native pages')
        check(opened(leader,page=2147483647)['paging']['page']==first['paging']['pages'],'out-of-range page clamps to the final page')
        found=opened(leader,search=names[-1])
        check(found['paging']['total']==1 and found['members'][0]['name']==names[-1],'search finds members outside the first 100 across the entire guild')
        check(opened(leader,sort='level')['members'][0]['level']==1099,'level ordering is global across all pages')
        online=opened(leader,onlineOnly=True)
        check(online['paging']['total']==2 and all(x['online'] for x in online['members']),'online-only filter is global and preserves authoritative presence')
        invite_ids=[];first_invites=opened(leader,'invites')
        for page in range(1,first_invites['paging']['pages']+1):
            value=first_invites if page==1 else opened(leader,'invites',page=page)
            invite_ids.extend(x['id'] for x in value['invites'])
        check(len(invite_ids)==230 and len(set(invite_ids))==230,'more than 100 invitations are fully reachable in bounded replies')
        activity=opened(leader,'activity',page=2)
        check(activity['paging']['total']>=120 and len(activity['activity'])==10,'activity history uses bounded database pages')
        # Existing management paths must work on people beyond the first page.
        expect(leader,'set_nick',name=names[-1],nick='Distant Scout')
        check(opened(leader,search='Distant Scout')['members'][0]['name']==names[-1],'setting a title works for a member beyond the first 100')
        expect(leader,'set_nick',name=names[-3],nick='T'*30)
        check(opened(leader,search=names[-3])['members'][0]['nick']=='T'*30,'migration supports the full 30-character title accepted by the client')
        expect(member,'kick',False,name=names[-1])
        expect(leader,'create_rank',rank_name='Scout')
        custom=int(sql(f"SELECT id FROM guild_ranks WHERE guild_id={guild_id} AND name='Scout'"))
        expect(leader,'set_rank',name=names[-1],rank_id=custom)
        expect(leader,'update_rank',rank_id=custom,rank_name='Pathfinder')
        perms=dict(canInvite=True,canKick=False,canSetMotd=False,canManageRanks=False,canSetTitle=True)
        expect(leader,'set_rank_permissions',rank_id=custom,permissions=perms)
        check(any(r['id']==custom and r['permissions']==perms for r in opened(leader,'ranks')['ranks']),'rank rename and explicit permissions still round-trip')
        expect(leader,'delete_rank',rank_id=custom)
        check(sql(f'SELECT COUNT(*) FROM guild_membership WHERE guild_id={guild_id}')==str(total),'deleting a rank preserves all large-guild memberships')
        expect(leader,'kick',name=names[-2])
        check(opened(leader,search=names[-2])['paging']['total']==0,'kick removes a member beyond page 100 and refreshes counts')
        expect(leader,'leave',False)
        expect(member,'disband',False)
        expect(leader,'transfer_leadership',name='Home Seller')
        check(opened(member,'info')['myLevel']==3 and opened(leader,'info')['myLevel']==2,'leadership transfer synchronizes both online roles')
        expect(leader,'rename',False,name='Former Leader Takeover')
        expect(member,'transfer_leadership',name='Home Buyer')
        check(opened(leader,'info')['myLevel']==3,'new leader can transfer leadership back')
        expect(member,'leave')
        sql("INSERT INTO guilds(name,ownerid,creationdata,motd) SELECT CONCAT('Inviting ',name),id,UNIX_TIMESTAMP(),'' FROM players WHERE name LIKE 'Scale Guest %' ORDER BY id LIMIT 130")
        recipient=sql("SELECT id FROM players WHERE name='Home Seller'")
        sql(f"INSERT INTO guild_invites(player_id,guild_id,created_at,expires_at) SELECT {recipient},id,UNIX_TIMESTAMP(),UNIX_TIMESTAMP()+86400 FROM guilds WHERE name LIKE 'Inviting %'")
        no_guild=request(member,'open',section='info',page=13)
        check(no_guild['type']=='no_guild' and no_guild['paging']['total']==130 and len(no_guild['invites'])==10,'guildless players can page through more than 100 invitations')
        expect(member,'create',False,name='Remote Founding')
        expect(leader,'invite',name='Home Seller')
        expect(member,'accept_invite',guild_id=guild_id)
        check(opened(member,'info')['memberCount']==total-1,'leaving and rejoining preserves the large guild and its roles')
        # A leader's cached runtime rank is never sufficient upload authority.
        pixels=bytes(c for y in range(32) for x in range(32) for c in ((0,0,0,0) if x<3 else (210,165,0,255) if (x+y)%5==0 else (0,70,110,255)))
        expect(member,'set_emblem',False,revision=0,first='A'*2732,second='A'*2730+'==')
        sql(f"UPDATE guilds SET ownerid=(SELECT id FROM players WHERE name='Home Seller') WHERE id={guild_id}")
        check(upload(leader,pixels)['type']=='error','database ownership recheck rejects a stale cached leader')
        sql(f"UPDATE guilds SET ownerid=(SELECT id FROM players WHERE name='Home Buyer') WHERE id={guild_id}")
        check(upload(leader,pixels)['type']=='success','leader uploads one canonical 32 x 32 RGBA emblem through native encrypted protocol')
        saved=sql(f'SELECT SHA2(pixels,256) FROM guild_emblems WHERE guild_id={guild_id}')
        check(saved==hashlib.sha256(pixels).hexdigest(),'only exact bounded raw pixels are stored')
        image=request(member,'emblem')
        check(image['revision']==1 and base64.b64decode(image['pixels'])==pixels,'another guild member receives every pixel, including binary zeros and transparency, independently from member pages')
        check(upload(leader,pixels,0)['type']=='error','stale emblem revision cannot overwrite a newer image')
        sql("CREATE TRIGGER guild_emblem_qa_fail BEFORE UPDATE ON guild_emblems FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='owned guild QA failure'")
        try:check(upload(leader,bytes([8])*4096,1)['type']=='error','database mutation failure is reported')
        finally:sql('DROP TRIGGER guild_emblem_qa_fail')
        check(sql(f'SELECT SHA2(pixels,256) FROM guild_emblems WHERE guild_id={guild_id}')==saved and sql(f'SELECT revision FROM guild_emblems WHERE guild_id={guild_id}')=='1','failed replacement keeps both old emblem and revision')
        bad=request(leader,'set_emblem',revision=1,first='!'*2732,second='A'*2730+'==')
        check(bad['type']=='error','invalid base64 is refused without touching stored pixels')
        expect(leader,'clear_emblem',revision=1)
        check(sql(f'SELECT CONCAT(revision,\':\',OCTET_LENGTH(pixels)) FROM guild_emblems WHERE guild_id={guild_id}')=='2:0','removal retains a revision tombstone without retaining an image')
        check(upload(leader,pixels,2)['type']=='success','replacement after removal uses the new revision')
        check(upload(leader,pixels,3)['type']=='error','fourth guild change on the same UTC day is refused')
        account=sql("SELECT id FROM accounts WHERE name='homebuyer'")
        while int(sql('SELECT attempts FROM guild_emblem_accounts WHERE account_id='+account))<10:
            request(leader,'set_emblem',revision=3,first='!'*2732,second='A'*2730+'==')
        leader.close();leader=connect()
        limited=upload(leader,pixels,3)
        check(limited['type']=='error' and 'attempts' in limited['message'],'invalid and stale attempts count against an account quota that survives reconnect')
        sql(f'UPDATE guild_emblem_accounts SET hour=hour-1 WHERE account_id={account}')
        sql(f'UPDATE guild_emblems SET day=day-1 WHERE guild_id={guild_id}')
        check(upload(leader,pixels,3)['type']=='success' and sql(f'SELECT changes FROM guild_emblems WHERE guild_id={guild_id}')=='1','expired hour/day windows renew without accumulating history rows')
        for w in clients:w.close()
        clients.clear();boot('\nclientGuildEmblemsEnabled = true\n')
        leader=connect();image=request(leader,'emblem')
        check(image['revision']==4 and base64.b64decode(image['pixels'])==pixels and sql(f'SELECT attempts FROM guild_emblem_accounts WHERE account_id={account}')=='1','emblem revision, pixels and account quota survive a real native restart')
        leader.close();clients.clear();boot('\nclientGuildEmblemsEnabled = false\n')
        leader=connect()
        check(not opened(leader,'info')['emblem']['enabled'] and upload(leader,pixels,4)['type']=='error','server feature flag disables reads and writes without deleting the emblem')
        check(sql(f'SELECT SHA2(pixels,256) FROM guild_emblems WHERE guild_id={guild_id}')==saved,'feature disable preserves the stored image')
        for w in clients:w.close()
        clients.clear();boot('\nclientGuildEmblemsEnabled = true\n')
        metrics.update(total_members=total-1,max_response_bytes=largest,pixel_sha256=saved)
        return metrics
    finally:
        for w in clients:w.close()


def finish_disband(pem,sql,check,guild_id):
    """After the optional UI run, verify the large-guild deletion boundary."""
    clients=[]
    def connect(account,name):
        w=Wire(pem,7188);assert w.game_login(account,name,'HouseFixtureOnly');clients.append(w);return w
    def rpc(w,action,request_id=800001):
        time.sleep(.25)
        w.send(b'\x32\x65'+string(json.dumps(dict(action=action,**({'requestId':request_id} if action=='open' else {})))))
        deadline=time.monotonic()+7
        while time.monotonic()<deadline:
            data=w.receive().data;offset=0
            while True:
                i=data.find(b'\x32\x65',offset)
                if i<0:break
                offset=i+2
                try:value=json.loads(data[i+4:i+4+int.from_bytes(data[i+2:i+4],'little')])
                except (ValueError,UnicodeError):continue
                if action=='open' and value.get('requestId')==request_id:return value
                if action!='open' and value.get('type') in ('error','guild_refresh'):return value
        raise AssertionError('Disband RPC timed out')
    try:
        leader=connect('homebuyer','Home Buyer');member=connect('homeseller','Home Seller')
        original=sql(f'SELECT COUNT(*) FROM guild_membership WHERE guild_id={guild_id}')
        sql("CREATE TRIGGER guild_delete_qa_fail BEFORE DELETE ON guilds FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='owned guild delete failure'")
        try:check(rpc(leader,'disband')['type']=='error','failed atomic guild deletion is reported')
        finally:sql('DROP TRIGGER guild_delete_qa_fail')
        check(sql(f'SELECT COUNT(*) FROM guild_membership WHERE guild_id={guild_id}')==original and rpc(member,'open')['type']=='guild_data','failed disband preserves database and live membership')
        check(rpc(leader,'disband')['type']=='guild_refresh','leader disbands a guild with over 1000 members')
        check(sql(f'SELECT COUNT(*) FROM guild_membership WHERE guild_id={guild_id}')=='0' and sql(f'SELECT COUNT(*) FROM guild_emblems WHERE guild_id={guild_id}')=='0','disband cascades every membership and the sole stored emblem')
        check(rpc(leader,'open')['type']=='no_guild' and rpc(member,'open',800002)['type']=='no_guild','disband clears both online members and refreshes their guildless view')
    finally:
        for w in clients:w.close()
