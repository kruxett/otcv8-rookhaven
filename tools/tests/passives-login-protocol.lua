-- Run with LuaJIT from the server repository. Actual server protocol/library;
-- native persistence, rank authorization and combat are tested separately.
Game={configurePassiveClasses=function()return true end}
dofile('data/lib/core/json.lua')
dofile('data/lib/passives/test.lua')
ClassChoice.hello=function()end
local packets,cancels={},{}
local state={v=1,action='snapshot',schemaVersion=2,catalogVersion=2,nodeCount=29,
 session='first-login',revision=1,treeId='reaver',points=3,ranks={},
 mode='permanent',respecCost=0,respecCount=0,active=true,capable=false,classLocked=true}
local player={}
function player:passiveTest(action,value)
 if action=='available'then return true end
 if action=='testAvailable'then return false end
 if action=='hello'then state.capable=value;return true end
 if action=='snapshot'then return json.encode(state)end
 error('Unexpected native operation: '..tostring(action))
end
function player:getVocation()return {getId=function()return 3 end}end
function player:sendExtendedOpcode(opcode,buffer)
 assert(opcode==103);packets[#packets+1]=json.decode(buffer)
end
function player:sendCancelMessage(text)cancels[#cancels+1]=text end
ClassSpells={sendCatalog=function(target)
 target:sendExtendedOpcode(103,json.encode({action='class_spells'}))
end}
local function count(action)
 local n=0;for _,packet in ipairs(packets)do if packet.action==action then n=n+1 end end;return n
end
local function request(action)
 packets,cancels={},{}
 PassiveTest.handle(player,json.encode({v=1,action=action,schemaVersion=2,catalogVersion=2,nodeCount=29,classChoice=true}))
end
local function synchronized(context)
 assert(count('catalog')+count('catalog_part')>0,context..': catalog missing')
 assert(count('snapshot')==1 and count('class_spells')==1,context..': saved tree/spells missing')
 assert(state.revision==1 and state.respecCount==0 and not next(state.ranks),context..': synchronization mutated allocation/free Respec')
end
for attempt=1,2 do
 request('hello');synchronized('login'..attempt)
 assert(count('hello')==1 and count('open')==0 and #cancels==0,'Capable login automatically opens or emits errors')
end
for _,action in ipairs({'snapshot','status'})do
 request(action);synchronized(action)
 assert(count('open')==0 and #cancels==0,'Automatic '..action..' opens tree')
end
request('open');synchronized('explicit open');assert(count('open')==1,'Explicit Open does not open')
packets,cancels={},{};PassiveTest.playerCommand(player)
synchronized('player command');assert(count('open')==1,'!passives does not open')
state.active=false;state.classLocked=false
request('hello');assert(count('hello')==1 and count('open')==0 and count('snapshot')==0 and #cancels==0,'No-class login has unsolicited tree/error')
request('open');assert(count('open')==0 and #cancels==1,'Explicit Open missing no-class hint')
print('PASSIVES_LOGIN_PROTOCOL_OK actualServerLibrary=true transport=scripted loginSilent=true refreshSilent=true explicitOpen=true')
