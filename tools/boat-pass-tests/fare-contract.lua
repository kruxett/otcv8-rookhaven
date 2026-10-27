-- Actual route, quote, pending and boarding source; physics is tested natively.
local root=assert(arg[1]); local checks=0; local now=100000
local function check(v,why) assert(v,why);checks=checks+1 end
local env=setmetatable({}, {__index=_G})
env.os=setmetatable({time=function()return now end},{__index=os})
env.Position=function(x,y,z) if type(x)=='table' then return {x=x.x,y=x.y,z=x.z} end;return {x=x,y=y,z=z} end
env.MESSAGE_EVENT_ADVANCE=1
local function actual(path)
    local f=assert(loadfile(root..'/'..path));setfenv(f,env);return f()
end
env.dofile=actual
actual('data/lib/core/storages.lua')
actual('data/lib/boat_pass.lua');actual('data/lib/boat_fare_registry.lua')
local p={guid=1,id=1,login=100,ip=1,health=100,pos={x=20,y=20,z=7}}
function p:getGuid()return self.guid end
function p:getId()return self.id end
function p:getLastLoginSaved()return self.login end
function p:getIp()return self.ip end
function p:getHealth()return self.health end
function p:getPosition()return self.pos end
function p:getBoatPassEndsAt()return self.expiry end
function p:getMoney()return self.money end
function p:removeMoney(n)if self.debitFail then return false end;self.money=self.money-n;return true end
function p:addMoney(n)self.money=self.money+n;return true end
function p:getStorageValue(key)
    if self.storage[key]~=nil then return self.storage[key] end
    if not self.access then return -1 end
    if key==env.PS.Quest_RepairFlokisBoatToStillshoreProgress then return 2 end
    if key==env.PS.Quest_Gravefall_Access then return 8 end
    return 1
end
function p:setStorageValue(key,value)self.storage[key]=value end
function p:sendCancelMessage(msg)self.cancel=msg end
function p:sendTextMessage(kind,msg)self.message=msg end
function p:sendExtendedOpcode(opcode,body)check(opcode==92,'Wrong fare opcode');return not self.networkFail end
env.Player=function(id)if id==p.id and p.online then return p end end
env.TradepackSystem={hasPack=function(player)return player.pack end}
local encoded,stations
env.json={encode=function(v)encoded=v;return '{}' end}
env.Item=function(uid)return stations[uid] end
env.BoatTravel={startRide=function(player,config)player.rides=player.rides+1;player.ride=config;return not player.rideFail end}
actual('data/actions/scripts/boat_fare_station.lua');local use=env.onUse
local file=assert(io.open(root..'/data/actions/scripts/boat_fare_station.lua'));local stationSource=file:read('*a');file:close()
local scripts={}
for path in stationSource:gmatch("'([%w_/]+%.lua)'")do scripts[#scripts+1]=path;actual(path)end
check(#scripts==11,'Boat route registry coverage changed; audit the new route')
file=assert(io.open(root..'/data/creaturescripts/scripts/extendedopcode.lua'));local source=file:read('*a');file:close()
local body=assert(source:match('elseif opcode == OPCODE_BOATFARE then(.-)\n\telseif opcode =='))
local chunk=assert(loadstring('return function(player,decoded)'..body..' end'));setfenv(chunk,env);local response=chunk()
local routes={}
for uid,cfg in pairs(env.BoatFareRegistry._routes)do routes[#routes+1]={uid=uid,config=cfg}end
table.sort(routes,function(a,b)return a.uid<b.uid end)
check(#routes==11,'Missing registered routes')
local current,station
local function reset(route)
    current=route or routes[1]
    p.expiry=0;p.money=500;p.rides=0;p.access=true;p.pack=false;p.storage={};p.networkFail=false;p.debitFail=false;p.rideFail=false
    p.id=1;p.login=100;p.ip=1;p.health=100;p.online=true;p.cancel=nil;p.message=nil;p.pos={x=20,y=20,z=7}
    encoded=nil;stations={};env.BoatFarePending={}
    station={pos={x=20,y=20,z=7},uid=current.uid}
    function station:getUniqueId()return self.uid end
    function station:getPosition()return self.pos end
    stations[current.uid]=station
end
local function quote()use(p,station,nil,nil,nil,false)end
local function accept()response(p,{response='accept',price=0,uid=99999})end
for _,route in ipairs(routes)do
    local cfg=route.config
    reset(route);quote();check(encoded and encoded.price==cfg.price,'Ordinary fare changed: '..route.uid)
    accept();check(p.money==500-cfg.price and p.rides==1 and p.ride==cfg.rideConfig,'Ordinary fare/route was controlled by reply')
    if route.uid==env.UID.Boat_Fare_Station_Underground_Second then
        check(p:getStorageValue(env.PS.Quest_Gravefall_Access)==9,'Ordinary ride lost Gravefall quest progress')
    end
    accept();check(p.money==500-cfg.price and p.rides==1,'Pending response replay was accepted')
    reset(route);p.expiry=now+30*86400;p.money=0;quote()
    check(encoded and encoded.price==0,'Active pass was not quoted free: '..route.uid)
    accept();check(p.money==0 and p.rides==1,'Pass required gold or changed route')
    if route.uid==env.UID.Boat_Fare_Station_Underground_Second then
        check(p:getStorageValue(env.PS.Quest_Gravefall_Access)==9,'Pass ride lost Gravefall quest progress')
    end
    reset(route);p.expiry=now-1;quote();check(encoded.price==cfg.price,'Expired pass waived a fare')
    reset(route);p.rideFail=true;quote();accept();check(p.money==500 and p.rides==1,'Failed paid ride refund changed balance')
    reset(route);p.expiry=now+100;p.rideFail=true;quote();accept();check(p.money==500 and p.rides==1,'Failed free ride minted a refund')
    reset(route);p.expiry=now+100;p.pack=true;quote()
    check((encoded~=nil)==(cfg.allowTradepacks==true),'Pass bypassed existing tradepack restriction')
    reset(route);p.expiry=now+100;p.access=false
    local allowed=not cfg.accessCheck or cfg.accessCheck(p)
    quote();check((encoded~=nil)==allowed,'Pass changed existing quest access: '..route.uid)
end
-- Select a paid, unrestricted route for admission failure cases.
local chosen
for _,route in ipairs(routes)do
    reset(route);p.access=false
    if route.config.price>0 and (not route.config.accessCheck or route.config.accessCheck(p))then chosen=route;break end
end
assert(chosen)
local mutations={
    function()now=now+31 end,
    function()now=now-1 end,
    function()p.login=p.login+1 end,
    function()p.online=false end,
    function()p.ip=0 end,
    function()p.health=0 end,
    function()p.pos.z=p.pos.z+1 end,
    function()p.pos.x=p.pos.x+2 end,
    function()stations[current.uid]=nil end,
    function()station.uid=0 end,
    function()station.pos.x=21 end,
    function()p.pack=true end,
}
for i,mutate in ipairs(mutations)do
    reset(chosen);quote();mutate();accept()
    check(p.money==500 and p.rides==0 and env.BoatFarePending[p.guid]==nil,'Invalid pending quote accepted: '..i)
    now=100000
end
reset(chosen);accept();check(p.money==500 and p.rides==0,'Unsolicited reply boarded')
reset(chosen);quote();response(p,{response='decline'});accept();check(p.rides==0 and p.money==500,'Declined quote was reusable')
reset(chosen);p.expiry=now+1;quote();p.expiry=now;accept()
check(p.rides==0 and p.money==500 and p.cancel:find('fare changed',1,true),'Expired free quote silently charged a fare')
reset(chosen);quote();p.expiry=now+100;accept();check(p.rides==1 and p.money==500,'Newly activated pass did not lower pending fare')
reset(chosen);p.expiry=nil;quote();check(encoded==nil and p.cancel~=nil,'Unavailable pass lookup produced a paid/free quote')
reset(chosen);quote();p.expiry=nil;accept();check(p.rides==0 and p.money==500,'Unavailable pass lookup charged/boarded')
reset(chosen);p.money=0;quote();accept();check(p.rides==0 and p.money==0,'Poor ordinary rider boarded')
reset(chosen);p.debitFail=true;quote();accept();check(p.rides==0 and p.money==500,'Failed gold removal boarded')
reset(chosen);p.networkFail=true;quote();check(env.BoatFarePending[p.guid]==nil,'Unsent fare quote remained usable')
reset(chosen);quote();local cfg=env.BoatFareRegistry._routes[current.uid];env.BoatFareRegistry._routes[current.uid]=nil
accept();check(p.rides==0 and p.money==500,'Removed route remained boardable');env.BoatFareRegistry._routes[current.uid]=cfg
reset(chosen);local oldAccess=cfg.accessCheck;cfg.accessCheck=function()return p.access end
quote();p.access=false;accept();check(p.rides==0 and p.money==500,'Access revoked after quote was ignored');cfg.accessCheck=oldAccess
check(env.BoatPass.getFare(p,0)==0,'Existing free boat acquired a pass dependency')
check(env.BoatPass.getFare(p,-1)==nil and env.BoatPass.getFare(p,1.5)==nil,'Invalid route fare accepted')
print('BOAT_PASS_FARE_CONTRACT_OK routes='..#routes..' checks='..checks)
