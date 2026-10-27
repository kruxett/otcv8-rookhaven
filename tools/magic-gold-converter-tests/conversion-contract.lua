-- Real conversion library with an inventory model; native room/trade tests are separate.
local server=assert(arg[1]);local checks=0
local function check(v,why)assert(v,why);checks=checks+1 end
local env=setmetatable({}, {__index=_G})
env.CONST_SLOT_HEAD=1;env.CONST_SLOT_AMMO=10
local outputs,failCreate={},false
local function item(id,count,attributes)
    local i={id=id,count=count or 1,attributes=attributes or false,removed=false}
    function i:getId()return self.id end
    function i:getCount()return self.count end
    function i:isContainer()return false end
    function i:hasAttribute(mask)check(mask==4294967295,'Incomplete attribute protection mask');return self.attributes end
    function i:remove()self.removed=true end
    return i
end
env.Game={createItem=function(id,count)
    if failCreate then return nil end
    local value=item(id,count);outputs[#outputs+1]=value;return value
end}
env.InventoryTransactions={release=function(values)for _,value in ipairs(values)do value:remove()end end}
local chunk=assert(loadfile(server..'/data/lib/magic_gold_converter.lua'));setfenv(chunk,env);chunk()
local M=env.MagicGoldConverter
local p={}
function p:getIp()return self.ip end
function p:getHealth()return self.health end
function p:getPersonalStore()return {mode=self.store}end
function p:getSlotItem(slot)return self.roots[slot]end
function p:getItemCount(id)
    local sum=0
    local function scan(i)
        if i:isContainer()then for _,child in ipairs(i.items)do scan(child)end
        elseif not i.removed and i.id==id then sum=sum+i.count end
    end
    for _,i in pairs(self.roots)do scan(i)end
    return sum
end
function p:inventoryTransaction(removals,additions,gold,replacements)
    self.calls=self.calls+1
    check(gold==0 and #replacements==0,'Conversion attempted unrelated payment/replacement')
    if self.reject then return false,'native preflight refused' end
    local expected={}
    for _,r in ipairs(removals)do
        check(not r.item.attributes and (r.item.id==2148 or r.item.id==2152),'Conversion consumed protected or unrelated item')
        check(r.count>0 and r.count<=r.item.count,'Invalid exact removal')
        expected[r.item]=(expected[r.item]or 0)+r.count
    end
    for i,count in pairs(expected)do check(count<=i.count,'Removal double counted a stack');i.count=i.count-count;if i.count==0 then i.removed=true end end
    for _,i in ipairs(additions)do
        check((i.id==2152 or i.id==2160) and i.count>=1 and i.count<=100,'Invalid denomination/output stack')
        self.bag.items[#self.bag.items+1]=i
    end
    return true
end
local function bag(items)
    local b={items=items or {}}
    function b:isContainer()return true end
    function b:getSize()return #self.items end
    function b:getItem(index)return self.items[index+1]end
    return b
end
local function reset()
    outputs={};failCreate=false;p.ip=1;p.health=100;p.store=0;p.reject=false;p.calls=0
    p.bag=bag({item(12867)});p.roots={[3]=p.bag}
end
local function add(id,count,attributes,target)
    target=target or p.bag
    while count>0 do local n=math.min(count,100);target.items[#target.items+1]=item(id,n,attributes);count=count-n end
end
local function value()return p:getItemCount(2148)+100*p:getItemCount(2152)+10000*p:getItemCount(2160)end
for _,n in ipairs({0,1,99,100,101,199,200,9999,10000,10100,19999})do
    for _,platinum in ipairs({0,1,98,99,100,101,199})do
        reset();add(2148,n);add(2152,platinum);add(2160,7)
        local before=value();local changed=M.convert(p)
        check(changed==(n>=100 or platinum>=100),'Threshold conversion mismatch')
        check(value()==before,'Conversion changed total currency value')
        check(p:getItemCount(2148)==n%100,'Gold remainder wrong')
        check(p:getItemCount(2152)==(math.floor(n/100)+platinum)%100,'Platinum remainder wrong')
        check(p:getItemCount(2160)==7+math.floor((math.floor(n/100)+platinum)/100),'Crystal output wrong')
        local calls=p.calls;check(not M.convert(p) and p.calls==calls and value()==before,'Repeated idle tick mutated money')
        check(p:getItemCount(12867)==1,'Converter was consumed')
    end
end
reset();local nested=bag({item(12867),item(2148,60)});p.bag.items={item(2148,40),bag({nested})}
check(M.convert(p) and p:getItemCount(2152)==1,'Nested converter/split coin stacks failed')
reset();add(2148,100,true);add(2152,100,true);add(2148,99)
check(not M.convert(p) and value()==10199 and p.calls==0,'Tagged coins were included in conversion')
add(2148,1);check(M.convert(p) and p:getItemCount(2148)==100 and p:getItemCount(2152)==101,'Tagged coins were erased or changed')
reset();p.bag.items={};add(2148,100);check(not M.convert(p) and value()==100 and p.calls==0,'Missing converter activated')
for _,state in ipairs({'dead','offline','store'})do
    reset();add(2148,100)
    if state=='dead'then p.health=0 elseif state=='offline'then p.ip=0 else p.store=1 end
    check(not M.convert(p) and value()==100 and p.calls==0,'Inactive/store player was changed')
end
reset();add(2148,10100);p.reject=true
check(not M.convert(p) and value()==10100 and p:getItemCount(2160)==0,'Native refusal consumed coins')
check(#outputs==2 and outputs[1].removed and outputs[2].removed,'Rejected prepared outputs leaked')
reset();add(2148,100);failCreate=true
check(not M.convert(p) and value()==100 and p.calls==0,'Failed output creation consumed coins')
reset();add(2148,100);env.Game.getPlayers=function()return {p}end
M.tick();check(p:getItemCount(2152)==1,'Automatic tick did not run conversion')
-- Execute the registered action too, including a Tile without Player methods.
local action
env.MESSAGE_STATUS_SMALL=1
env.Action=function()
    local a={}
    function a:id(id)check(id==12867,'Wrong action SID')end
    function a:register()action=self end
    return a
end
function p:getId()return 1 end
function p:isPlayer()return true end
function p:sendCancelMessage(message)self.cancel=message end
function p:sendTextMessage(kind,message)self.message=message end
chunk=assert(loadfile(server..'/data/scripts/actions/others/magic_gold_converter.lua'));setfenv(chunk,env);chunk()
reset();add(2148,100)
check(action.onUse(p,{getTopParent=function()return {}end}) and p.cancel~=nil and value()==100,'Ground Tile action was not safely refused')
p.cancel=nil
check(action.onUse(p,{getTopParent=function()return nil end}) and p.cancel~=nil and value()==100,'Detached item action was not refused')
p.cancel=nil
check(action.onUse(p,{getTopParent=function()return {isPlayer=function()return true end,getId=function()return 2 end}end}) and p.cancel~=nil and value()==100,'Another player item action was accepted')
check(action.onUse(p,{getTopParent=function()return p end}) and p:getItemCount(2152)==1 and value()==100,'Owned action did not convert')
check(action.onUse(p,{getTopParent=function()return p end}) and value()==100 and p:getItemCount(12867)==1,'Repeated action created value or consumed converter')
print('MAGIC_GOLD_CONVERTER_CONTRACT_OK checks='..checks)
