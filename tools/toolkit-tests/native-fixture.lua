-- Disposable loopback world only. Every requested use is sent by the wire client.
assert(configManager.getString(configKeys.SERVER_NAME)=='Rookhaven Toolkit QA')
local event=CreatureEvent('ToolkitOwnedQA')
local checks,failed,sequence=0,false,0
local function check(value,why)assert(value,why);checks=checks+1 end
local function later(ms,fn)
    addEvent(function()
        if failed then return end
        local ok,why=pcall(fn)
        if not ok then failed=true;print('TOOLKIT_NATIVE_FAILED '..tostring(why)) end
    end,ms)
end
local function same(a,b)return a.x==b.x and a.y==b.y and a.z==b.z end
local function floorAt(pos,id)
    local tile=Tile(pos) or Game.createTile(pos,true)
    if tile:getGround() then tile:getGround():transform(id or 4526)
    else assert(Game.createItem(id or 4526,1,pos)) end
    return assert(Tile(pos))
end
local function patch(n,p)
    local center=Position(31000+n*4,31000,7)
    for dx=-1,1 do for dy=-1,1 do floorAt(Position(center.x+dx,center.y+dy,7)) end end
    assert(p:teleportTo(Position(center.x-1,center.y,7)))
    return center
end
local function run(p)
    p:setGhostMode(true)
    check(p:getGroup():getId()==1 and not p:hasFlag(PlayerFlag_HasInfiniteCapacity),'ordinary player required')
    local id=p:getId()
    local bag=p:getSlotItem(CONST_SLOT_BACKPACK)
    local function selectTool(sid)
        local current=p:getSlotItem(CONST_SLOT_RIGHT)
        if current and current:getId()==sid then return current end
        if current then assert(current:moveTo(bag,0)) end
        local tool=p:getItemById(sid,true) or assert(bag:addItem(sid,1))
        -- Shop delivery may already have used the ammo slot. moveTo(player)
        -- is a no-op for any item whose parent is already that player.
        assert(tool:moveTo(bag,0))
        assert(tool:moveTo(p,0))
        check(p:getSlotItem(CONST_SLOT_RIGHT)==tool,'tool did not reach hand')
        return tool
    end
    local cases={}
    local function add(label,setup,verify,tool,forge)cases[#cases+1]={label=label,setup=setup,verify=verify,tool=tool or 12865,forge=forge}end
    if p:getStorageValue(950612)==2 then
        check(bag and p:getItemCount(12865)==1,'Toolkit missing or duplicated on relog')
        local kit=assert(p:getItemById(12865,true))
        check(kit:getCustomAttribute('toolkit_qa')=='preserved','instance attributes lost on relog')
        add('use-after-relogin',function()
            local pos=patch(25,p);return assert(Game.createItem(2782,1,pos))
        end,function(target)check(target:getId()==2781,'relogged Toolkit stopped working')end)
    else
        p:setCapacity(10000)
        bag=assert(Game.createItem(1988,1))
        check(p:addItemEx(bag,false,CONST_SLOT_BACKPACK)==RETURNVALUE_NOERROR,'bag setup failed')
        check(p:addItemEx(assert(Game.createItem(2050,1)),false,CONST_SLOT_LEFT)==RETURNVALUE_NOERROR,'left hand setup failed')
        check(p:addItemEx(assert(Game.createItem(2420,1)),false,CONST_SLOT_RIGHT)==RETURNVALUE_NOERROR,'right hand setup failed')
        local kind=ItemType(12865)
        check(kind:getClientId()==11902 and kind:getWeight()==1000,'Toolkit native mapping/weight wrong')
        check(not kind:isContainer() and not kind:isStackable(),'Toolkit must be a single tool, not a container/stack')
        local category,offer
        for c,cat in ipairs(GameShop.catalog) do for i,entry in ipairs(cat.offers) do
            if entry.id==4004 then category,offer=c,i;check(entry.cost==50 and entry.grant.itemId==12865,'Toolkit offer wrong')end
        end end
        assert(category and offer)
        local function buy()GameShop.handleClientOpcode(p,{action='buy',data={category=category,offer=offer,cost=0}})end
        GameShop.setPoints(p,49);buy()
        check(p:getItemCount(12865)==0 and GameShop.getPoints(p)==49,'poor purchase changed state')
        GameShop.setPoints(p,100);p:setCapacity(0);buy()
        check(p:getItemCount(12865)==0 and GameShop.getPoints(p)==100,'failed delivery charged points')
        p:setCapacity(100000);buy()
        check(p:getItemCount(12865)==1 and GameShop.getPoints(p)==50,'purchase grant/charge failed')
        local kit=assert(p:getItemById(12865,true));kit:setCustomAttribute('toolkit_qa','preserved')
        -- Four ordinary tool actions, followed by equivalent original-tool probes.
        for _,tool in ipairs({12865,2120}) do
            add('rope-spot-'..tool,function(n)
                local pos=patch(n,p);floorAt(pos,384)
                floorAt(Position(pos.x,pos.y+1,pos.z-1));return Tile(pos):getGround()
            end,function(target,pos)check(same(p:getPosition(),Position(pos.x,pos.y+1,pos.z-1)),'rope climb failed')end,tool)
        end
        for _,tool in ipairs({12865,2554}) do
            add('shovel-hole-'..tool,function(n)
                local pos=patch(n,p);floorAt(pos,468);floorAt(Position(pos.x,pos.y,pos.z+1))
                return Tile(pos):getGround()
            end,function(target)check(target:getId()==469,'shovel did not open hole')end,tool)
        end
        for _,tool in ipairs({12865,2553}) do
            add('pick-floor-'..tool,function(n)
                local pos=patch(n,p);floorAt(pos,351);floorAt(Position(pos.x,pos.y,pos.z+1))
                local ground=Tile(pos):getGround();ground:setActionId(AID.Tile_PickfloorCave);return ground
            end,function(target)check(target:getId()==392,'pick did not open marked floor')end,tool)
        end
        for _,tool in ipairs({12865,2420}) do
            add('machete-grass-on-sand-'..tool,function(n)
                local pos=patch(n,p);floorAt(pos,231);return assert(Game.createItem(2782,1,pos))
            end,function(target)check(target:getId()==2781,'machete target was swallowed by ground/sand dispatch')end,tool)
        end
        add('machete-wheat',function(n)
            local pos=patch(n,p);return assert(Game.createItem(2739,1,pos))
        end,function(target,pos)
            check(target:getId()==2737 and Tile(pos):getItemById(2694),'wheat harvest failed')
        end)
        add('machete-wild-growth',function(n)
            local pos=patch(n,p);return assert(Game.createItem(1499,1,pos))
        end,function(_,pos)check(not Tile(pos):getItemById(1499),'wild growth not cut')end)
        for _,tool in ipairs({12865,2120}) do
            local coin
            add('rope-pull-item-'..tool,function(n)
                local pos=patch(n,p);floorAt(pos,369)
                local below=Position(pos.x,pos.y,pos.z+1);floorAt(below)
                coin=assert(Game.createItem(2148,1,below));return Tile(pos):getGround()
            end,function(_,pos)
                -- Moving a stackable item may replace its native Item object.
                -- Read the destination instead of retaining the pre-move handle.
                local destination=Position(pos.x,pos.y+1,pos.z)
                local moved=Tile(destination):getItemById(2148)
                check(moved and moved:getCount()==1 and not Tile(Position(pos.x,pos.y,pos.z+1)):getItemById(2148),'rope pull did not move one coin to the destination')
                assert(moved:remove())
            end,tool)
        end
        for _,tool in ipairs({12865,2120}) do
            for silo=1,2 do
                local creature
                add('silo-'..silo..'-'..tool,function()
                    local hole=silo==1 and Position(32069,32201,15) or Position(32126,32142,15)
                    local source=silo==1 and Position(32121,32138,10) or Position(32080,32142,10)
                    local target=assert(Tile(hole),'real silo hole missing'):getGround()
                    check(Tile(source)~=nil,'real silo source missing')
                    assert(p:teleportTo(Position(hole.x,hole.y-1,hole.z)))
                    creature=assert(Game.createMonster('Rat',source,true,true))
                    creature:changeSpeed(-creature:getSpeed())
                    return target
                end,function(_,pos)
                    check(same(creature:getPosition(),Position(pos.x,pos.y-1,pos.z)),'non-adjacent silo route failed')
                    assert(creature:remove())
                end,tool)
            end
        end
        for _,tool in ipairs({12865,2553}) do
            add('mining-training-denied-'..tool,function(n)
                p:setStorageValue(PS.Skill_ExcavationLearned,-1);p:setStorageValue(PS.Quest_ExcavationTrainingProgress,0)
                local pos=patch(n,p);floorAt(pos,231)
                local crystal=assert(Game.createItem(8637,1,pos));crystal:setActionId(AID.Mining_VarrTrainingCrystal);return crystal
            end,function(target)
                check(target:getId()==8637 and p:getStorageValue(PS.Quest_ExcavationTrainingProgress)==0,'mining quest gate bypassed')
            end,tool)
        end
        add('mining-training-success-on-sand',function(n)
            p:setStorageValue(PS.Quest_ExcavationTrainingProgress,2)
            local pos=patch(n,p);floorAt(pos,231)
            local crystal=assert(Game.createItem(8637,1,pos));crystal:setActionId(AID.Mining_VarrTrainingCrystal);return crystal
        end,function(target)
            check(target:getId()==8640 and p:getStorageValue(PS.Quest_ExcavationTrainingProgress)==3,'training pick behavior not preserved')
        end)
        local xp,fragments
        add('learned-mining-on-sand',function(n)
            p:setStorageValue(PS.Skill_ExcavationLearned,1);p:setStorageValue(PS.Skill_ExcavationLevel,1);p:setStorageValue(PS.Skill_ExcavationXP,0)
            xp=p:getStorageValue(PS.Skill_ExcavationXP);fragments=p:getItemCount(12788)
            local pos=patch(n,p);floorAt(pos,231);return assert(Game.createItem(8640,1,pos))
        end,function()
            check(p:getStorageValue(PS.Skill_ExcavationXP)>xp and p:getItemCount(12788)>fragments,'mining XP/fragments missing')
        end)
        add('wrong-floor-refusal',function(n)
            local pos=patch(n,p);pos.z=pos.z+1;floorAt(pos);return assert(Game.createItem(2782,1,pos))
        end,function(target)check(target:getId()==2782,'native floor restriction bypassed')end)
        add('wrong-client-id-refusal',function(n)
            local pos=patch(n,p);return assert(Game.createItem(2782,1,pos))
        end,function(target)check(target:getId()==2782,'wrong source client ID was accepted')end,12865,true)
    end
    local index=0
    local function nextCase()
        index=index+1;local case=cases[index]
        if not case then
            check(p:getItemCount(12865)==1,'Toolkit consumed or duplicated')
            if p:getStorageValue(950612)==2 then
                check(p:save(),'final save failed');print('TOOLKIT_NATIVE_OK checks='..checks);return
            end
            assert(selectTool(12865):moveTo(bag,0))
            assert(p:teleportTo(Position(32097,32219,7)))
            p:setStorageValue(950612,2);check(p:save(),'relog save failed')
            print('TOOLKIT_NATIVE_READY_RELOGIN checks='..checks);return
        end
        local tool=selectTool(case.tool)
        local target=case.setup(index);local pos=target:getPosition()
        sequence=sequence+1
        -- Item:getPosition() is the player's map position for inventory items;
        -- the native use-with packet needs the explicit inventory-slot address.
        local packet={sequence=sequence,label=case.label,from={65535,CONST_SLOT_RIGHT,0},
            item=ItemType(tool:getId()):getClientId()+(case.forge and 1 or 0),to={pos.x,pos.y,pos.z},
            target=ItemType(target:getId()):getClientId(),stack=Tile(pos):getThingIndex(target)}
        print('TOOLKIT_USE '..json.encode(packet))
        later(1250,function()
            check(Player(id)==p,'test player disappeared')
            case.verify(target,pos)
            check(p:getItemCount(12865)==1 and selectTool(case.tool):getId()==case.tool,'tool consumed/transformed/jammed')
            print('TOOLKIT_CASE_OK '..case.label)
            nextCase()
        end)
    end
    nextCase()
end
function event.onLogin(p)
    if p:getName()=='Passive Tester' then local id=p:getId();later(400,function()run(assert(Player(id)))end)end
    return true
end
event:register()
