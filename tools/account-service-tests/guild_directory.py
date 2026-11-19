"""Public guild discovery through the real native protocol, in the owned DB."""
import base64,json,time
from wire import Wire,string

def run(pem,sql,check,guild_id,boot,stop):
    assert sql('SELECT DATABASE()')=='rookhaven_accounts_qa'
    guild_id=int(guild_id);peers=[];sequence=0;largest=0
    pixels=bytes([40,95,140,255])*1024
    sql(f"INSERT INTO guild_emblems(guild_id,revision,pixels,day,changes) VALUES({guild_id},1,UNHEX('{pixels.hex()}'),0,0)")
    before=sql(f'SELECT player_id,rank_id FROM guild_membership WHERE guild_id={guild_id} ORDER BY player_id')
    # Recreate the pre-directory schema in this disposable database only.
    # Existing guild membership, description and emblem must survive upgrading.
    stop();sql('ALTER TABLE guilds DROP COLUMN recruitment_status')
    sql("UPDATE server_config SET value='38' WHERE config='db_version'");boot()
    check(sql("SELECT value FROM server_config WHERE config='db_version'")=='39' and sql(f'SELECT recruitment_status FROM guilds WHERE id={guild_id}')=='0','schema 38 upgrades to 39 with unspecified recruitment by default')
    check(sql(f'SELECT player_id,rank_id FROM guild_membership WHERE guild_id={guild_id} ORDER BY player_id')==before and sql(f'SELECT motd FROM guilds WHERE id={guild_id}')=='Native public description' and sql(f'SELECT revision FROM guild_emblems WHERE guild_id={guild_id}')=='1','directory migration preserves existing membership, description and emblem')
    sql("INSERT INTO accounts(name,password,email) SELECT 'directoryfixtures',password,'directory@example.invalid' FROM accounts WHERE name='homerival'")
    account=sql("SELECT id FROM accounts WHERE name='directoryfixtures'")
    rank=sql(f'SELECT id FROM guild_ranks WHERE guild_id={guild_id} AND level=1 LIMIT 1')
    for start in range(0,150,50):
        values=','.join("('Directory Member %s',%s,%d)"%(chr(97+i//26)+chr(97+i%26),account,100+i)for i in range(start,start+50))
        sql('INSERT INTO players(name,account_id,level) VALUES'+values)
    sql(f"INSERT INTO guild_membership(player_id,guild_id,rank_id,nick) SELECT id,{guild_id},{rank},'' FROM players WHERE name LIKE 'Directory Member %'")
    sql("UPDATE players SET vocation=3 WHERE name='Directory Member ft'")
    sql("INSERT INTO player_passives(player_id,class_id) SELECT id,'arcanist' FROM players WHERE name='Directory Member ft'")
    for i in range(13):
        name='Directory Founder '+chr(97+i)
        sql("INSERT INTO players(name,account_id) VALUES('%s',%s)"%(name,account))
        owner=sql("SELECT id FROM players WHERE name='%s'"%name)
        sql("INSERT INTO guilds(name,ownerid,creationdata,motd,recruitment_status) VALUES('Directory Guild %s',%s,UNIX_TIMESTAMP(),'Hunting and helping new players.',%d)"%(chr(97+i),owner,i%3))
        foreign=sql("SELECT id FROM guilds WHERE ownerid="+owner)
        foreign_rank=sql('SELECT id FROM guild_ranks WHERE guild_id='+foreign+' AND level=3 LIMIT 1')
        sql(f"INSERT INTO guild_membership(player_id,guild_id,rank_id,nick) VALUES({owner},{foreign},{foreign_rank},'')")
        foreign_pixels=bytes([130+i*5,50,60,255])*1024
        sql(f"INSERT INTO guild_emblems(guild_id,revision,pixels,day,changes) VALUES({foreign},1,UNHEX('{foreign_pixels.hex()}'),0,0)")
    def connect(account,name):
        w=Wire(pem,7188);assert w.game_login(account,name,'HouseFixtureOnly');peers.append(w);return w
    def request(w,action,**fields):
        nonlocal sequence,largest
        time.sleep(.23);sequence+=1
        keyed=action in ('browse','guild_profile','browse_emblem','open','emblem')
        message=dict(action=action,**fields)
        if keyed:message['requestId']=sequence
        for peer in peers:
            try:peer.send(b'\x1e')
            except OSError:pass
        w.send(b'\x32\x65'+string(json.dumps(message,separators=(',',':'))))
        deadline=time.monotonic()+8
        while time.monotonic()<deadline:
            data=w.receive().data;offset=0
            while True:
                at=data.find(b'\x32\x65',offset)
                if at<0:break
                offset=at+2
                if at+4>len(data):continue
                n=int.from_bytes(data[at+2:at+4],'little')
                try:value=json.loads(data[at+4:at+4+n])
                except (ValueError,UnicodeError):continue
                if value.get('type')=='error' or (keyed and value.get('requestId')==sequence) or (not keyed and value.get('type')=='success'):
                    largest=max(largest,n);assert n<7900
                    return value
        raise AssertionError('directory RPC timed out: '+action)
    def browse(w,**fields):return request(w,'browse',**dict(dict(page=1,search='',sort='name',recruitingOnly=False),**fields))
    def profile(w,**fields):return request(w,'guild_profile',**dict(dict(guildId=guild_id,page=1,search='',sort='rank',onlineOnly=False),**fields))
    try:
        leader=connect('homebuyer','Home Buyer');member=connect('homeseller','Home Seller');outsider=connect('homerival','Home Rival')
        first=browse(outsider);ids=[]
        check(first['type']=='guild_directory' and first['paging']['total']==14,'guildless character browses all guilds in bounded pages')
        for page in range(1,first['paging']['pages']+1):ids.extend(g['id']for g in browse(outsider,page=page)['guilds'])
        check(len(ids)==14 and len(set(ids))==14,'every guild is reachable once across public pages')
        check(browse(member,sort='members')['guilds'][0]['id']==guild_id,'guilded members can browse with global membership ordering')
        check(browse(outsider,sort='online')['guilds'][0]['onlineCount']==2,'public online counts and ordering use real connected guild members')
        found=browse(outsider,search='Native Renamed Guild')
        check(found['paging']['total']==1 and found['guilds'][0]['id']==guild_id,'guild search finds results outside the first page')
        check(browse(outsider,search="%' OR 1=1 --")['paging']['total']==0,'public search treats SQL metacharacters as literal text')
        check(browse(outsider,page=2147483647)['paging']['page']==2,'public directory clamps a huge page')
        value=profile(outsider)
        check(value['info']['memberCount']==152 and value['info']['onlineCount']==2 and len(value['members'])==10,'foreign profile counts more than 100 members without loading the entire roster')
        forbidden={'permissions','activity','invites','ranks','myLevel','accountId'}
        check(not forbidden.intersection(value) and all(not {'lastSeen','accountId','permissions'}.intersection(m)for m in value['members']),'public profile contains no management, account or private activity data')
        check(profile(outsider,search='Directory Member ft')['members'][0]['name']=='Directory Member ft','public member search reaches past the first 100 members')
        highest=profile(outsider,sort='level')['members'][0]
        check(highest['level']==249 and highest['classId']=='arcanist' and highest['vocation']==3,'public roster ordering and actual permanent class are authoritative')
        online=profile(outsider,onlineOnly=True)
        check(online['paging']['total']==2 and all(m['online']for m in online['members']),'public online-only filter covers the entire roster')
        check(profile(outsider,page=2147483647)['paging']['page']==16,'foreign roster clamps a huge page')
        emblem=request(outsider,'browse_emblem',guildId=guild_id)
        check(base64.b64decode(emblem['pixels'])==pixels and emblem['revision']==1,'guildless browser reads the canonical chosen emblem')
        check(request(outsider,'emblem')['type']=='error','public emblems do not grant private guild-emblem access')
        check(request(member,'set_recruitment',status=2)['type']=='error' and sql(f'SELECT recruitment_status FROM guilds WHERE id={guild_id}')=='0','ordinary member cannot change recruitment')
        check(request(outsider,'rename',name='Stolen Guild')['type']=='error','browsing a guild grants no guild management authority')
        check(request(leader,'set_recruitment',status=1)['type']=='success','actual guild leader can publish recruitment status')
        recruiting=browse(outsider,recruitingOnly=True)
        check(any(g['id']==guild_id for g in recruiting['guilds']) and all(g['recruitmentStatus']==1 for g in recruiting['guilds']),'recruiting filter uses authoritative persisted settings')
        own=request(member,'open',section='info')
        check(own['info']['id']==guild_id and own['myLevel']==1,'foreign browsing preserves the character own guild and permissions')
        check(profile(outsider,guildId=2147483647)['type']=='directory_error' and request(outsider,'browse_emblem',guildId=2147483647)['type']=='directory_error','missing or disbanded public guild fails without exposing another guild')
        for peer in peers:peer.close()
        peers=[];boot();outsider=connect('homerival','Home Rival')
        check(profile(outsider)['info']['recruitmentStatus']==1,'recruitment survives normal server restart')
        check(browse(outsider,sort='online')['guilds'][0]['onlineCount']==0 and profile(outsider,sort='online')['info']['onlineCount']==0,'all-offline guilds remain browsable and sortable')
        for peer in peers:peer.close()
        peers=[];boot('\nclientGuildEmblemsEnabled = false\n');outsider=connect('homerival','Home Rival')
        check(all(not g['emblem']['enabled'] and not g['emblem']['present']for g in browse(outsider)['guilds']) and request(outsider,'browse_emblem',guildId=guild_id)['type']=='directory_error','emblem disable flag also applies to public reads')
    finally:
        for peer in peers:peer.close()
        boot()
    check(sql(f'SELECT COUNT(*) FROM guild_membership WHERE guild_id={guild_id}')=='152' and sql(f'SELECT revision FROM guild_emblems WHERE guild_id={guild_id}')=='1','public browsing and refused mutations preserve memberships and emblem')
    return dict(guilds=14,members=152,maxReplyBytes=largest,databaseVersion=sql("SELECT value FROM server_config WHERE config='db_version'"))
