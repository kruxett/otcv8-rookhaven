-- Real server encoder, shop responses and client extended-JSON reassembly.
local serverRoot,clientRoot=assert(arg[1]),assert(arg[2])
local checks=0
local function check(ok,why)assert(ok,why);checks=checks+1 end
local function loadActual(path,env)
 local chunk=assert(loadfile(path));setfenv(chunk,env);return chunk()
end
local server=setmetatable({}, {__index=_G})
server.Opcodes={GameShop=201}
server.ItemType=function(id)return {getClientId=function()return id-963 end,getName=function()return 'magic quiver'end}end
server.dofile=function(path)return loadActual(serverRoot..'/'..path,server)end
server.dofile('data/lib/core/json.lua')
server.dofile('data/lib/core/game_shop.lua')
local shop=server.GameShop
local lastSerialized
local realEncode=server.json.encode
server.json.encode=function(value)
 lastSerialized=realEncode(value)
 return lastSerialized
end

local client=setmetatable({ProtocolGame={}}, {__index=_G})
loadActual(clientRoot..'/modules/corelib/json.lua',client)
loadActual(clientRoot..'/modules/gamelib/protocolgame.lua',client)
local receiver=setmetatable({}, {__index=client.ProtocolGame})
local decoded={}
client.ProtocolGame.registerExtendedJSONOpcode(201,function(_,opcode,value)
 check(opcode==201,'Reassembly changed opcode')
 decoded[#decoded+1]=value
end)

local player={storage={[910500]=1000},packets={},deliveries=0,guid=7001}
function player:getGuid()return self.guid end
function player:getStorageValue(key)return self.storage[key] or -1 end
function player:setStorageValue(key,value)self.storage[key]=value end
function player:addItem()self.deliveries=self.deliveries+1;return {}end
function player:sendExtendedOpcode(opcode,buffer)
 check(opcode==201 and type(buffer)=='string' and #buffer>0 and #buffer<=8192,
  'Response exceeded native addString limit or changed opcode')
 self.packets[#self.packets+1]=buffer
 if self.failAt==#self.packets then return false end
 local previous=#decoded
 receiver:onExtendedOpcode(opcode,buffer)
 if buffer:sub(1,1)=='S' or buffer:sub(1,1)=='P' then
  check(#decoded==previous,'Client decoded an incomplete JSON message')
 end
 return true
end
local function reset()
 player.packets={};player.failAt=nil;decoded={}
end
local function sendPayloadClosure()
 for index=1,100 do
  local name,value=debug.getupvalue(shop.pushStatus,index)
  if name=='sendPayload'then return value end
  if not name then break end
 end
 error('Actual sendPayload closure unavailable')
end
local sendPayload=sendPayloadClosure()
check(sendPayload(nil,'message',{})==false,'Missing player accepted')
check(sendPayload({},'message',{})==false,'Player without transport accepted')

for _,size in ipairs({100,8191,8192,8193,16000,16001,24001})do
 reset()
 local data={text=''};local status={points=850}
 local overhead=#realEncode({action='boundary',data=data,status=status})
 data.text=string.rep('x',size-overhead)
 check(sendPayload(player,'boundary',data,status)==true,'Valid response send failed')
 check(#lastSerialized==size,'Boundary fixture has wrong byte count')
 check(#decoded==1 and decoded[1].action=='boundary' and decoded[1].data.text==data.text
  and decoded[1].status.points==850,'Client did not recover the complete boundary response')
 if size<=8192 then
  check(#player.packets==1 and player.packets[1]==lastSerialized,'Small response framing changed')
 else
  local joined={}
  for i,packet in ipairs(player.packets)do
   local expected=i==1 and 'S' or (i==#player.packets and 'E' or 'P')
   check(packet:sub(1,1)==expected,'Chunk marker/order mismatch')
   joined[#joined+1]=packet:sub(2)
  end
  check(table.concat(joined)==lastSerialized,'Chunking lost or duplicated encoded bytes')
  if size>16000 then check(#player.packets>=3,'Middle P chunk was not exercised')end
 end
end

-- Splitting in the middle of UTF-8 is safe only if the original bytes are
-- joined before decoding. Exercise real non-ASCII JSON and escaped quotes.
reset()
local unicode=string.rep('Rök" \\ åäö 日本語 ',1400)
check(sendPayload(player,'message',{msg=unicode},{points=850})==true,'Unicode response failed')
check(#player.packets>2 and #decoded==1 and decoded[1].data.msg==unicode,'Unicode/escaped data changed during reassembly')

for _,failure in ipairs({{100,1},{20000,1},{20000,2},{20000,3}})do
 reset();player.failAt=failure[2]
 local data={text=string.rep('x',failure[1])}
 check(sendPayload(player,'failure',data)==false,'Failed native send reported success')
 check(#player.packets==failure[2] and #decoded==0,'Failure sent later chunks or decoded incomplete data')
 -- A new raw response must discard any incomplete earlier S/P sequence.
 player.failAt=nil
 check(sendPayload(player,'message',{msg='Recovered'})==true,'Recovery response failed')
 check(#decoded==1 and decoded[1].data.msg=='Recovered','Client retained a failed partial response')
end

reset()
shop.handleClientOpcode(player,{action='init'})
local catalogBytes=#lastSerialized
check(catalogBytes>8192 and #player.packets>=2,'Actual expanded catalog did not exercise large transport')
check(#decoded==1 and decoded[1].action=='categories' and decoded[1].status.points==1000,'Actual catalog/status lost')
local offers=0
for _,category in ipairs(decoded[1].data)do
 for _,offer in ipairs(category.offers)do
  offers=offers+1;check(offer.grant==nil,'Transport leaked private grant details')
 end
end
check(offers==36 and #decoded[1].data[3].offers==26,'Catalog was truncated or repeated during transport')
check(decoded[1].data[3].offers[1].id==6001 and decoded[1].data[3].offers[26].id==6026,'First/last cosmetic lost')

reset()
shop.handleClientOpcode(player,{action='buy',data={category=2,offer=1,cost=0}})
check(#player.packets==1 and #decoded==1 and decoded[1].action=='message','Purchase reply framing changed')
check(player.deliveries==1 and player.storage[910500]==850 and decoded[1].status.points==850,
 'Transport change damaged existing purchase/points behavior')

reset()
shop.handleClientOpcode(player,{action='history'})
check(#player.packets==1 and #decoded==1 and decoded[1].action=='history' and #decoded[1].data==1
 and decoded[1].data[1].id==4001 and decoded[1].data[1].item==11867,'Existing purchase history reply changed')

reset()
shop.handleClientOpcode(player,{action='buy',data={category=999,offer=1}})
check(#player.packets==1 and #decoded==1 and decoded[1].action=='message'
 and decoded[1].data.title=='Shop Error' and decoded[1].status.points==850
 and player.deliveries==1,'Existing error/status reply changed')

reset()
shop.pushStatus(player)
check(#player.packets>=2 and #decoded==1 and decoded[1].action=='categories'
 and decoded[1].status.points==850,'Updated balance/full catalog status refresh failed')

print('SHOP_JSON_TRANSPORT_CONTRACT_OK checks='..checks..' catalogBytes='..catalogBytes..' realCodec=true actualClientReassembly=true native=false')
