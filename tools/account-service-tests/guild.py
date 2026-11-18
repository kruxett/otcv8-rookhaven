"""Focused native regressions for guild parity. Uses the house runner's actors."""
import json,time
from wire import Wire,string

def run(pem,sql,check,guild_id):
    clients=[]
    def connect(account,name):
        w=Wire(pem,7188);assert w.game_login(account,name,'HouseFixtureOnly');clients.append(w);return w
    def request(w,action,**fields):
        time.sleep(.25)
        w.send(b'\x32\x65'+string(json.dumps(dict(action=action,**fields))))
        deadline=time.monotonic()+8
        while time.monotonic()<deadline:
            data=w.receive().data;offset=0
            while True:
                i=data.find(b'\x32\x65',offset)
                if i<0:break
                offset=i+2
                try:value=json.loads(data[i+4:i+4+int.from_bytes(data[i+2:i+4],'little')])
                except (ValueError,UnicodeError):continue
                if value.get('type') in ('success','error'):return value
        raise AssertionError('guild action timed out '+action)
    before=sql('SELECT player_id,rank_id FROM guild_membership WHERE guild_id='+guild_id)
    try:
        leader=connect('homebuyer','Home Buyer');member=connect('homeseller','Home Seller')
        check(request(member,'rename',name='Stolen Guild')['type']=='error','non-member cannot rename another guild')
        check(request(leader,'rename',name='Bad\' Name')['type']=='error','invalid guild name preserves previous name')
        check(request(leader,'rename',name='Native Renamed Guild')['type']=='success','guild leader renames through native protocol')
        check(sql('SELECT name FROM guilds WHERE id='+guild_id)=='Native Renamed Guild' and sql('SELECT player_id,rank_id FROM guild_membership WHERE guild_id='+guild_id)==before,'guild rename preserves identity and memberships')
        check(request(leader,'set_motd',motd='Native public description')['type']=='success','existing MOTD also serves as public guild description')
        check(sql('SELECT motd FROM guilds WHERE id='+guild_id)=='Native public description','description stored in native guild record')
        check(request(leader,'invite',name='Home Seller')['type']=='success','existing guild invite still works')
        check(request(member,'revoke_invite',name='Home Seller')['type']=='error','non-member cannot withdraw invitation')
        check(sql('SELECT COUNT(*) FROM guild_invites WHERE guild_id='+guild_id)=='1','refused invitation withdrawal preserves pending invite')
        check(request(leader,'revoke_invite',name='Home Seller')['type']=='success','leader withdraws a pending invitation')
        check(sql('SELECT COUNT(*) FROM guild_invites WHERE guild_id='+guild_id)=='0','withdrawal removes only actual guild invitation')
        check(request(leader,'invite',name='Home Seller')['type']=='success','withdrawn invitation can be sent again')
        # Accept emits guild_data rather than success; send then let SQL readback
        # wait for the normal dispatcher path, without fabricating membership.
        member.send(b'\x32\x65'+string(json.dumps(dict(action='accept_invite',guild_id=int(guild_id)))))
        deadline=time.monotonic()+6
        while sql('SELECT COUNT(*) FROM guild_membership WHERE guild_id='+guild_id)!='2':
            assert time.monotonic()<deadline,'native invitation acceptance timed out';time.sleep(.1)
        check(True,'existing invitation acceptance still joins the guild')
        check(request(leader,'invite',name='Home Rival')['type']=='success','leader can invite a third character')
        check(request(member,'rename',name='Member Takeover')['type']=='error','ordinary member cannot rename guild')
        check(request(member,'revoke_invite',name='Home Rival')['type']=='error','ordinary member cannot withdraw invites without permission')
        check(request(leader,'revoke_invite',name='Home Rival')['type']=='success','leader can withdraw third-party invite after member refusal')
        check(sql('SELECT name FROM guilds WHERE id='+guild_id)=='Native Renamed Guild','refused member actions preserve guild name')
    finally:
        for w in clients:w.close()
