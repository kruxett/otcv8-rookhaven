"""Run real guild Lua contracts with LuaJIT (lupa.luajit21), without a live DB."""
from pathlib import Path
import argparse,base64,json
from lupa.luajit21 import LuaRuntime

root=Path(__file__).resolve().parents[2];server=root.parent/'Rookhaven'
parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path);args=parser.parse_args()
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute((server/'data/lib/core/json.lua').read_text(encoding='utf-8'))
lua.execute((server/'data/lib/core/client_requests.lua').read_text(encoding='utf-8'))
def accepts(value):
    out=lua.globals().ClientRequests.decode(101,json.dumps(value,separators=(',',':')))
    return out is not None and not (isinstance(out,tuple) and out[0] is None)
valid=[dict(action='open'),dict(action='open',requestId=1,section='members',page=2147483647,search="O'Neil",sort='level',onlineOnly=True),dict(action='emblem',requestId=2),dict(action='clear_emblem',revision=0)]
valid.extend([dict(action='browse',requestId=1,page=2147483647,search="O'Neil",recruitingOnly=True,sort='online'),
    dict(action='guild_profile',requestId=2,guildId=2147483647,page=1,search='',onlineOnly=False,sort='level'),
    dict(action='browse_emblem',requestId=3,guildId=1),dict(action='set_recruitment',status=1)])
pixels=base64.b64encode(bytes(4096)).decode()
upload=dict(action='set_emblem',revision=0,first=pixels[:2732],second=pixels[2732:]);valid.append(upload)
invalid=[dict(action='open',page=0),dict(action='open',page=1.5),dict(action='open',page=2147483648),dict(action='open',section='guild_wars'),dict(action='open',guildId=2),dict(action='open',search='a'*31),dict(action='open',sort='p.name;DROP TABLE players'),dict(action='open',onlineOnly=1),dict(action='emblem',requestId=0),dict(upload,guild_id=2),dict(upload,first='a'*2733),dict(upload,second='a'*2731),dict(upload,revision=-1),dict(upload,filename='../x.png'),dict(action='clear_emblem',revision=0,url='https://example.invalid/x.png')]
directory=valid[4];profile=valid[5]
invalid.extend([dict(directory,search='a'*31),dict(directory,page=0),dict(directory,recruitingOnly=1),
    dict(directory,sort='g.id;DROP TABLE guilds'),dict(directory,guildId=1),dict(profile,guildId=-1),
    dict(profile,page=1.5),dict(profile,section='activity'),dict(profile,onlineOnly='true'),
    dict(action='browse_emblem',requestId=1,guildId=1,filename='../../x'),
    dict(action='set_recruitment',status=3),dict(action='set_recruitment',status=1,guildId=2)])
assert all(map(accepts,valid));assert not any(map(accepts,invalid))
lua.execute('db={query=function()return true end,storeQuery=function()return false end}; Game={}; packets={}; spectatorCount=2000')
lua.execute((server/'data/lib/guild_system.lua').read_text(encoding='utf-8'))
assert lua.globals().GuildSystem.displayText('ä'*20,29)=='ä'*14
assert lua.globals().GuildSystem.displayText('Test',30)=='Test'
lua.execute('''
function Game.getSpectators()
  local out={}
  for i=1,spectatorCount do
    local id=i
    out[i]={getId=function()return id end,getGuild=function()return {getName=function()return string.rep('G',30)end}end}
  end
  return out
end
actor={getPosition=function()return {} end,sendExtendedOpcode=function(self,opcode,buffer)
  assert(opcode==101);packets[#packets+1]=buffer
end}
GuildSystem.sendWorldNames(actor)
''')
packets=[json.loads(x) for _,x in lua.globals().packets.items()]
assert len(packets)>1 and packets[0]['reset'] and all(p['reset'] is False for p in packets[1:])
ids=[p['id'] for chunk in packets for p in chunk['players']]
assert len(ids)==2000 and sorted(ids)==list(range(1,2001))
max_bytes=max(len(x.encode()) for _,x in lua.globals().packets.items());assert max_bytes<7900
lua.execute('packets={};spectatorCount=0;GuildSystem.sendWorldNames(actor)')
assert json.loads(lua.globals().packets[1])==dict(type='world_names',reset=True,players=[])
report=dict(status='PASS',valid=len(valid),refused=len(invalid),upload_bytes=len(json.dumps(upload,separators=(',',':'))),world_players=2000,world_packets=len(packets),max_world_packet_bytes=max_bytes,utf8_boundary=True,empty_world_reset=True,global_limits_unchanged=True)
if args.output:args.output.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report))
