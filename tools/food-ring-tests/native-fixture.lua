-- Installed only into an owned cold loopback copy, never into the game data.
assert(configManager.getString(configKeys.SERVER_NAME) == 'Rookhaven Food Ring QA')
local event = CreatureEvent('FoodRingOwnedQA')
local checks, failed, safePz = 0, false, nil
local function check(value, why) assert(value, why); checks = checks + 1 end
local function later(ms, fn)
    addEvent(function()
        if failed then return end
        local ok, why = pcall(fn)
        if not ok then failed = true; print('FOOD_RING_NATIVE_FAILED ' .. tostring(why)) end
    end, ms)
end
local function food(p) return p:getCondition(CONDITION_REGENERATION, CONDITIONID_DEFAULT) end
local function effect(p) return p:getCondition(CONDITION_REGENERATION, CONDITIONID_RING, FOOD_RING_REGEN_SUBID) end
local function ring(p) return assert(p:getSlotItem(CONST_SLOT_RING), 'ring slot empty') end
local function duration(item) return item:getAttribute(ITEM_ATTRIBUTE_DURATION) end
local function rates(p, hp, mana)
    local stats = p:getPassiveCharacterStats()
    check(math.abs(stats.currentEffectHealthPerSecond - hp) < .00001, 'wrong displayed health regeneration: '..stats.currentEffectHealthPerSecond)
    check(math.abs(stats.currentEffectManaPerSecond - mana) < .00001, 'wrong displayed mana regeneration: '..stats.currentEffectManaPerSecond)
end
local function pools(p)
    -- addHealth(negative) is combat damage. Clamp the owned fixture's pool
    -- directly so pool setup cannot engage combat or alter resting regen.
    local maximum=p:getMaxHealth();p:setMaxHealth(100);p:setMaxHealth(maximum)
    local maximumMana=p:getMaxMana();p:setMaxMana(10);p:setMaxMana(maximumMana)
    check(p:getHealth()==100 and p:getMana()==10,'owned pool setup failed')
end
local function outside(p)
    if not safePz and p:getTile():hasFlag(TILESTATE_PROTECTIONZONE) then safePz = p:getPosition() end
    local pos = p:getPosition()
    for radius=0,30 do
        for x=pos.x-radius,pos.x+radius do
            for y=pos.y-radius,pos.y+radius do
                if math.abs(x-pos.x)==radius or math.abs(y-pos.y)==radius then
                    local tile=Tile(x,y,pos.z)
                    if tile and tile:getGround() and not tile:hasFlag(TILESTATE_PROTECTIONZONE)
                        and tile:queryAdd(p)==RETURNVALUE_NOERROR then
                        assert(p:teleportTo(Position(x,y,pos.z)));return
                    end
                end
            end
        end
    end
    error('no accessible non-protection tile for regeneration test')
end
local foodEnv = setmetatable({}, {__index=_G})
local foodChunk = assert(loadfile('data/actions/scripts/other/food.lua'))
setfenv(foodChunk,foodEnv);foodChunk()
local function eat(p, bag)
    local apple=assert(bag:addItem(2674,1));local count=p:getItemCount(2674)
    check(foodEnv.onUse(p,apple,apple:getPosition(),nil,p:getPosition(),false)==true,'ordinary food action failed')
    return count
end
local function run(p)
    -- Keep unrelated world monsters from changing measured HP/combat state.
    p:setGhostMode(true)
    local id = p:getId()
    local function player() return assert(Player(id)) end
    local phase=p:getStorageValue(950611)
    check(p:getGroup():getId()==1 and not p:hasFlag(PlayerFlag_HasInfiniteCapacity),'ordinary player fixture required')
    if phase==2 then
        check(ring(p):getId()==12864 and effect(p),'equipped ring/effect not restored on login')
        check(not food(p),'equipped relog manufactured ordinary food')
        check(duration(ring(p))>0 and duration(ring(p))<7200000,'charge reset on equipped relog')
        check(ring(p):getCustomAttribute('food_ring_qa')=='preserved','instance state lost on relog')
        rates(p,2/6,1/6)
        ring(p):setAttribute(ITEM_ATTRIBUTE_DURATION,1000)
        local deadline=os.time()+22
        local function expired()
            local q=player()
            if not q:getSlotItem(CONST_SLOT_RING) then
                check(not effect(q) and not food(q),'expiry left effective or ordinary food behind')
                rates(q,0,0)
                check(q:getItemCount(12863)==0 and q:getItemCount(12864)==0,'expired ring remained usable')
                check(q:save(),'final save failed')
                print('FOOD_RING_NATIVE_OK checks='..checks);return
            end
            assert(os.time()<deadline,'ring did not expire');later(200,expired)
        end
        later(200,expired);return
    end
    if phase~=1 then
        p:setVocation(0);p:removeCondition(CONDITION_REGENERATION,CONDITIONID_DEFAULT)
        outside(p);p:setCapacity(10000)
        local bag=assert(Game.createItem(1988,1))
        check(p:addItemEx(bag,false,CONST_SLOT_BACKPACK)==RETURNVALUE_NOERROR,'backpack setup failed')
        for _,entry in ipairs({{2050,CONST_SLOT_LEFT},{2554,CONST_SLOT_RIGHT},{2121,CONST_SLOT_RING}}) do
            check(p:addItemEx(assert(Game.createItem(entry[1],1)),false,entry[2])==RETURNVALUE_NOERROR,'slot setup failed')
        end
        check(ItemType(12863):getClientId()==11900 and ItemType(12864):getClientId()==11901,'native SID/CID failed')
        check(ItemType(12864):getDuration()==7200 and ItemType(12864):getAbilities().foodSustain,'native duration/food ability wrong')
        local category,offer
        for c,value in ipairs(GameShop.catalog) do for i,entry in ipairs(value.offers) do
            if entry.id==4003 then category,offer=c,i;check(entry.cost==10 and entry.grant.itemId==12863,'shop offer wrong') end
        end end
        assert(category and offer)
        local function buy() GameShop.handleClientOpcode(p,{action='buy',data={category=category,offer=offer,cost=0}}) end
        GameShop.setPoints(p,9);buy()
        check(p:getItemCount(12863)==0 and GameShop.getPoints(p)==9,'poor purchase charged or granted')
        GameShop.setPoints(p,50);p:setCapacity(0);buy()
        check(p:getItemCount(12863)==0 and GameShop.getPoints(p)==50,'failed delivery charged points')
        p:setCapacity(10000);buy()
        check(p:getItemCount(12863)==1 and GameShop.getPoints(p)==40,'purchase must grant one ring for10 points')
        local item=assert(p:getItemById(12863,true));assert(item:moveTo(bag,0))
        item:setCustomAttribute('food_ring_qa','preserved')
        local invalid=assert(Game.createItem(12863,1))
        check(p:addItemEx(invalid,false,CONST_SLOT_HEAD)~=RETURNVALUE_NOERROR,'ring allowed in head slot')
        assert(ring(p):moveTo(bag,0));assert(item:moveTo(p,0))
        check(ring(p):getId()==12864 and effect(p),'native equip/food condition failed')
        check(not food(p),'equipping hungry created ordinary food')
        check(effect(p):getTicks()==-1 and effect(p):getId()==CONDITIONID_RING,'effect is not equipment-owned')
        rates(p,2/6,1/6)
        later(1000,function()
            local q=player();local active=ring(q);local remaining=duration(active)
            assert(active:moveTo(bag,0))
            check(not effect(q) and not food(q),'one-second exploit: food/effect survived removal')
            rates(q,0,0)
            for i=1,20 do
                local off=assert(q:getItemById(12863,true));assert(off:moveTo(q,0))
                check(not food(q),'equip cycling created ordinary food')
                check(duration(ring(q))<=remaining,'equip cycling refilled charge')
                assert(ring(q):moveTo(bag,0))
                check(not effect(q) and not food(q),'equip cycling retained food')
            end
            q:setStorageValue(950611,1);check(q:save(),'bag relog save failed')
            print('FOOD_RING_NATIVE_READY_RELOGIN_1 checks='..checks)
        end)
        return
    end
    local bag=assert(p:getSlotItem(CONST_SLOT_BACKPACK))
    check(not food(p) and not effect(p),'bag relog revived temporary food')
    local off=assert(p:getItemById(12863,true))
    local paused=duration(off)
    local steps,index={},0
    local function step(ms,fn) steps[#steps+1]={ms,fn} end
    step(2000,function()
        check(duration(off)==paused,'unequipped time kept draining')
        p:feed(15);check(food(p) and food(p):getTicks()<=15000,'ordinary feeding failed')
        local before=food(p):getTicks();assert(off:moveTo(p,0))
        check(food(p):getTicks()<=before,'equipping extended existing food')
        rates(p,2/6,1/6);pools(p)
    end)
    step(6600,function()
        check(p:getHealth()==102 and p:getMana()==11,'food plus Food Ring doubled or lost regeneration')
        check(food(p):getTicks()>0 and food(p):getTicks()<15000,'ordinary reserve did not count down normally')
        food(p):setTicks(1000)
    end)
    -- Condition removal runs on the next 1s creature bucket after its deadline.
    step(3000,function()
        check(not food(p) and effect(p),'ring did not take over after ordinary food expired')
        rates(p,2/6,1/6);pools(p)
    end)
    step(6600,function()
        check(p:getHealth()==102 and p:getMana()==11,'hungry ring did not provide normal food regeneration')
        check(not food(p),'ring regeneration manufactured ordinary reserve')
        local count=eat(p,bag)
        check(p:getItemCount(2674)==count-1 and food(p),'actual food use while wearing ring failed')
        rates(p,2/6,1/6)
        local ticks=food(p):getTicks();assert(ring(p):moveTo(bag,0))
        check(not effect(p) and food(p):getTicks()<=ticks,'unequip removed or refilled eaten food')
        rates(p,2/6,1/6)
        food(p):setTicks(1200000);count=eat(p,bag)
        check(p:getItemCount(2674)==count,'full-food refusal consumed food')
        p:removeCondition(CONDITION_REGENERATION,CONDITIONID_DEFAULT)
        off=assert(p:getItemById(12863,true));assert(off:moveTo(p,0))
        check(duration(ring(p))<7200000,'equipped charge did not decrease')
        assert(p:getSlotItem(CONST_SLOT_LEFT):moveTo(bag,0))
        local wand=assert(Game.createItem(2190,1));wand:setAttribute(ITEM_ATTRIBUTE_DESCRIPTION,'[Mana Regen: +3]')
        check(p:addItemEx(wand,false,CONST_SLOT_LEFT)==RETURNVALUE_NOERROR,'wand setup failed')
    end)
    step(200,function()
        check(p:getWandManaBonus()==3 and effect(p):getParameter(CONDITION_PARAM_MANAGAIN)==4,'equipment mana bonus missing from ring')
        rates(p,2/6,4/6)
        assert(p:getSlotItem(CONST_SLOT_LEFT):remove())
        check(p:addItemEx(assert(Game.createItem(2050,1)),false,CONST_SLOT_LEFT)==RETURNVALUE_NOERROR,'hand restore failed')
        rates(p,2/6,1/6)
        p:setVocation(2);rates(p,4/6,2/4)
        check(effect(p):getParameter(CONDITION_PARAM_MANATICKS)==4000,'vocation change left stale ring rate')
        p:setVocation(0);rates(p,2/6,1/6)
        -- Actual native mana drain enters combat and updates food rates.
        p:addMana(-1,true);check(p:getCondition(CONDITION_INFIGHT,CONDITIONID_DEFAULT),'combat setup failed')
        rates(p,1/6,1/6)
        p:feed(10);rates(p,1/6,1/6)
        check(food(p):getParameter(CONDITION_PARAM_HEALTHGAIN)==1,'ordinary combat food rate changed')
        p:removeCondition(CONDITION_INFIGHT,CONDITIONID_DEFAULT);rates(p,2/6,1/6)
        p:removeCondition(CONDITION_REGENERATION,CONDITIONID_DEFAULT)
        assert(safePz,'protection-zone fixture missing');assert(p:teleportTo(safePz))
        check(p:getTile():hasFlag(TILESTATE_PROTECTIONZONE),'PZ fixture failed');rates(p,0,0);pools(p)
    end)
    step(6600,function()
        check(p:getHealth()==100 and p:getMana()==10,'Food Ring regenerated in protection zone')
        outside(p);assert(ring(p):moveTo(bag,0))
        local life=assert(Game.createItem(2168,1))
        check(p:addItemEx(life,false,CONST_SLOT_RING)==RETURNVALUE_NOERROR,'life ring equip failed')
        check(ring(p):getId()==2205 and p:getCondition(CONDITION_REGENERATION,CONDITIONID_RING),'existing life ring failed')
        p:feed(30);rates(p,4/6,9/6);pools(p)
        print('FOOD_RING_LIFE_BASELINE hp='..p:getHealth()..' food='..food(p):getParameter(CONDITION_PARAM_HEALTHGAIN)..' life='..p:getCondition(CONDITION_REGENERATION,CONDITIONID_RING):getParameter(CONDITION_PARAM_HEALTHGAIN)..' fight='..tostring(p:getCondition(CONDITION_INFIGHT,CONDITIONID_DEFAULT)~=nil))
    end)
    step(6600,function()
        check(p:getHealth()==104 and p:getMana()==19,'ordinary food/life-ring stacking regressed: hp='..p:getHealth()..' mana='..p:getMana()..' foodGain='..food(p):getParameter(CONDITION_PARAM_HEALTHGAIN)..' lifeGain='..p:getCondition(CONDITION_REGENERATION,CONDITIONID_RING):getParameter(CONDITION_PARAM_HEALTHGAIN)..' fight='..tostring(p:getCondition(CONDITION_INFIGHT,CONDITIONID_DEFAULT)~=nil))
        assert(ring(p):remove());p:removeCondition(CONDITION_REGENERATION,CONDITIONID_DEFAULT)
        rates(p,0,0)
        local light=assert(Game.createItem(12861,1))
        check(p:addItemEx(light,false,CONST_SLOT_RING)==RETURNVALUE_NOERROR,'Light Ring equip regressed')
        local level,color=p:getLight();check(ring(p):getId()==12862 and level==7 and color==206,'Light Ring torchlight regressed')
        assert(ring(p):remove())
        off=assert(p:getItemById(12863,true));local remaining=duration(off)
        assert(off:moveTo(p,0));check(duration(ring(p))==remaining,'re-equip refilled Food Ring charge')
        check(not food(p) and effect(p),'final ring equip manufactured food')
        p:setStorageValue(950611,2);check(p:save(),'equipped relog save failed')
        print('FOOD_RING_NATIVE_READY_RELOGIN_2 checks='..checks)
    end)
    local function nextStep()
        index=index+1;local value=steps[index]
        if value then later(value[1],function()value[2]();nextStep()end) end
    end
    nextStep()
end
function event.onLogin(p)
    if p:getName()=='Passive Tester' then local id=p:getId();later(300,function()run(assert(Player(id)))end) end
    return true
end
event:register()
