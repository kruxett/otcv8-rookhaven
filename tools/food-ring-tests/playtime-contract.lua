-- Execute the actual food-time response builder without changing any reserves.
local root=assert(arg[1])
local f=assert(io.open(root..'/data/creaturescripts/scripts/extendedopcode.lua','rb'))
local src=f:read('*a');f:close()
local chunk=assert(src:match('(local function handleCharacterPlaytime%(player%).-)local function handleBestiaryCategories'))
local checks,state,reply=0,{},nil
local function check(value,why)assert(value,why);checks=checks+1 end
local env=setmetatable({CONDITION_REGENERATION=1,CONDITIONID_DEFAULT=-1,CONDITIONID_RING=9,
    FOOD_RING_REGEN_SUBID=0x464F4F44,CONST_SLOT_RING=9,ITEM_ATTRIBUTE_DURATION=1}, {__index=_G})
env.db={storeQuery=function()return 1 end}
env.result={getNumber=function()return 100 end,free=function()end}
env.os={time=function()return 1000 end}
env.ItemType=function(id)return{getAbilities=function()return{foodSustain=id==12864}end}end
env.cyclopediaSendResponse=function(_,action,status,payload)
    check(action=='character.playtime' and status=='ok','response envelope changed');reply=payload
end
local p={getGuid=function()return 1 end,getLastLoginSaved=function()return 950 end}
function p:getCondition(_,id,sub)
    if id==-1 and state.food then
        return {getEndTime=function()return 1000000+state.food end,getTicks=function()return state.food end}
    end
    if id==9 and sub==0x464F4F44 and state.effect then return {} end
end
function p:getSlotItem(slot)
    check(slot==9,'wrong inventory slot used')
    if state.ring then return {getId=function()return state.ring end,getAttribute=function()return state.duration end} end
end
local loader=assert(loadstring(chunk..'\nreturn handleCharacterPlaytime'))
setfenv(loader,env);local run=loader()
for _,case in ipairs({
    {{},0},
    {{food=20000},20},
    {{effect=true,ring=12864,duration=7200000},7200},
    {{effect=true,ring=12864,duration=7200123},7201},
    {{food=20000,effect=true,ring=12864,duration=7200000},7200},
    {{ring=12863,duration=7200000},0},
    {{effect=true},0},
    {{effect=true,ring=2205,duration=7200000},0},
}) do
    state=case[1];reply=nil;local foodBefore=state.food
    run(p)
    check(reply=='150,'..case[2],'wrong food/ring time: '..tostring(reply))
    check(state.food==foodBefore,'reading food time changed the ordinary reserve')
end
print('FOOD_RING_PLAYTIME_CONTRACT_OK checks='..checks..' actualResponseBuilder=true')
