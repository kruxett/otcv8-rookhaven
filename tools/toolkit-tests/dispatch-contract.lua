-- Execute the actual shared action library and the registered Toolkit wrapper.
local root=assert(arg[1]);local checks=0
local function check(value,why)assert(value,why);checks=checks+1 end
local env=setmetatable({}, {__index=_G})
env.AID={Tile_PickfloorCave=100,Tile_SandHole=101,Mining_VarrTrainingCrystal=102,Mining_VarrSampleCrystal=103}
env.PS=setmetatable({}, {__index=function(t,k)local v=#k;t[k]=v;return v end})
env.table=setmetatable({contains=function(t,w)for _,v in pairs(t)do if v==w then return true end end;return false end},{__index=table})
env.Position=function(p,y,z)
    if type(p)=='number' then return{x=p,y=y,z=z}end
    return{x=p.x,y=p.y,z=p.z}
end
local function loadActual(path)
    local fn=assert(loadfile(root..'/'..path));setfenv(fn,env);return fn()
end
env.dofile=loadActual
loadActual('data/actions/lib/actions.lua')
local actualRope,actualRookhavenRope=env.onUseRope,env.onUseRookhavenRope
local calls,returns={},{}
for _,tool in ipairs({'RookhavenRope','Shovel','Pick','Machete'})do
    env['onUse'..tool]=function(_,_,_,_,pos)
        check(pos.x==100 and pos.y==200 and pos.z==7,'a previous tool mutated a later tool position')
        calls[#calls+1]=tool;pos.x=999;pos.z=15
        return returns[tool] or false
    end
end
loadActual('data/actions/scripts/tools/toolkit.lua')
local function use(id,aid,isItem)
    calls={};local pos={x=100,y=200,z=7}
    local target={getId=function()return id end,getActionId=function()return aid or 0 end,isItem=function()return isItem~=false end}
    local value=env.onUse({}, {}, {}, target, pos, false)
    check(pos.x==100 and pos.y==200 and pos.z==7,'Toolkit mutated caller position')
    return value
end
for _,id in ipairs({2782,3985,1499,11099,2739})do
    returns={Machete=true};check(use(id),'machete action not handled')
    check(#calls==1 and calls[1]=='Machete','clicked vegetation must precede ground and nearby crystals')
end
local resources=loadActual('data/lib/excavation.lua')
for id in pairs(resources.crystalTiers)do
    returns={Pick=true};check(use(id),'crystal tier not handled')
    check(#calls==1 and calls[1]=='Pick','clicked crystal must precede sand')
end
for _,aid in ipairs({102,103})do
    returns={Pick=true};check(use(9999,aid),'quest crystal AID not routed')
    check(#calls==1 and calls[1]=='Pick','quest crystal must use normal mining gate')
end
for index,tool in ipairs({'RookhavenRope','Shovel','Pick','Machete'})do
    returns={[tool]=true};check(use(4526),'fallback tool not handled')
    check(#calls==index and calls[index]==tool,'fallback did not stop after handled action')
end
returns={};check(use(4526)==false and #calls==4,'unsupported target must fall through four tools')
check(use(0,0,false)==false and #calls==0,'creature target reached tool handlers')
-- The ordinary rope wrapper still invokes the same silo-aware helper, while
-- its shared native rope path retains the original PZ-lock refusal.
env.onUseRookhavenRope=actualRookhavenRope;env.onUseRope=actualRope
env.ropeSpots={384};env.TILESTATE_PROTECTIONZONE=1;env.RETURNVALUE_PLAYERISPZLOCKED=2
local cancelled,teleported=false,false
env.Tile=function(pos)
    if pos.z==7 then return{getGround=function()return{getId=function()return 384 end}end}end
    return{hasFlag=function()return true end}
end
env.Position=function(p)
    return setmetatable({x=p.x,y=p.y,z=p.z},{__index={moveUpstairs=function(self)self.z=self.z-1;return self end}})
end
loadActual('data/actions/scripts/tools/rope.lua')
local player={isPzLocked=function()return true end,sendCancelMessage=function(_,v)cancelled=v==2 end,
    teleportTo=function()teleported=true end}
check(env.onUse(player,{}, {}, {},env.Position({x=100,y=200,z=7}),false)==true,'PZ refusal was not handled')
check(cancelled and not teleported,'ordinary rope PZ-lock protection regressed')
print('TOOLKIT_DISPATCH_CONTRACT_OK checks='..checks..' actualHandlers=true')
