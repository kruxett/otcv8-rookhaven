assert(configManager.getString(configKeys.SERVER_NAME)=='Rookhaven Converter QA')
local event=CreatureEvent('ConverterOwnedQA')
local M=MagicGoldConverter
local checks,sequence=0,0
local function check(v,why)assert(v,why);checks=checks+1 end
local function guarded(fn)
    local ok,why=pcall(fn)
    if not ok then print('CONVERTER_NATIVE_FAILED '..tostring(why))end
end
local function later(ms,fn)addEvent(function()guarded(fn)end,ms)end
local function wait(label,predicate,done)
    local deadline=os.time()+18
    local function poll()
        if predicate()then done();return end
        assert(os.time()<deadline,label..' timed out');later(100,poll)
    end
    later(100,poll)
end
local function sqlNumber(query)
    local row=assert(db.storeQuery(query));local n=result.getNumber(row,'value');result.free(row);return n
end
local function saved(p,id)
    return sqlNumber('SELECT COALESCE(SUM(count),0) AS value FROM player_items WHERE player_id='..p:getGuid()..' AND itemtype='..id)
end
local function clearCoins(p)
    for _,id in ipairs({2148,2152,2160})do
        while p:getItemCount(id)>0 do assert(p:getItemById(id,true):remove())end
    end
end
local function mint(p,id,count)
    while count>0 do local n=math.min(count,100);assert(p:addItem(id,n,false));count=count-n end
end
local function request(label,kind,values)
    sequence=sequence+1;values.label=label;values.kind=kind;values.sequence=sequence
    print('CONVERTER_WIRE '..json.encode(values))
end
local function groundRequest(p,item,label,to)
    local pos=item:getPosition()
    request(label,'move',{from={pos.x,pos.y,pos.z},item=ItemType(item:getId()):getClientId(),
        stack=Tile(pos):getThingIndex(item),to=to or {65535,3,0},count=item:getCount()})
end

local function trade(p)
    print('CONVERTER_PEER_LOGIN_READY')
    wait('peer',function()
        local peer=Player('Converter Peer')
        return peer and peer:getStorageValue(950702)==1
    end,function()
        local peer=assert(Player('Converter Peer'))
        local pos=p:getPosition();pos.x=pos.x+1;assert(peer:teleportTo(pos,true))
        clearCoins(p);clearCoins(peer);mint(peer,2148,100)
        assert(peer:getItemById(2148,true):moveTo(peer:getSlotItem(CONST_SLOT_BACKPACK)))
        local counter=assert(Game.createItem(2120,1))
        assert(peer:addItemEx(counter,false,CONST_SLOT_LEFT)==RETURNVALUE_NOERROR)
        local converter=assert(p:getSlotItem(CONST_SLOT_AMMO))
        check(converter:getId()==12867,'Trade source is not the actual converter')
        request('request-trade','trade',{from={65535,10,0},item=11904,stack=0,partner=peer:getId()})
        wait('trade lock',function()
            local ok,why=p:inventoryTransaction({},{},0,{})
            return not ok and why:find('trade',1,true)
        end,function()
            request('counter-offer','trade',{actor='peer',from={65535,6,0},
                item=ItemType(2120):getClientId(),stack=0,partner=p:getId()})
            mint(p,2148,100)
            later(1600,function()
                check(p:getItemCount(2148)==100 and p:getItemCount(2152)==0,'Automatic converter changed coins during trade')
                check(peer:getItemCount(2148)==100 and peer:getItemCount(12867)==0,'Converter affected another player before transfer')
                request('accept-trade','accept_trade',{})
                wait('trade ownership',function()return peer:getItemCount(12867)==1 end,function()
                    later(1500,function()
                        check(p:getItemCount(12867)==0 and p:getItemCount(2148)==100 and p:getItemCount(2152)==0,'Former owner kept converter effect')
                        check(peer:getItemCount(12867)==1 and peer:getItemCount(2148)==0 and peer:getItemCount(2152)==1,'New owner did not receive automatic conversion')
                        check(p:getItemCount(2120)==1 and peer:getItemCount(2120)==0,'Normal trade counter-offer did not transfer')
                        p:setStorageValue(950700,1);peer:setStorageValue(950701,1)
                        assert(p:save());assert(peer:save())
                        check(saved(p,2148)==100 and saved(p,12867)==0,'Sender trade state was not saved')
                        check(saved(peer,2152)==1 and saved(peer,12867)==1,'Receiver conversion state was not saved')
                        print('CONVERTER_NATIVE_READY_RELOGIN checks='..checks)
                    end)
                end)
            end)
        end)
    end)
end

local function wireCases(p,bag)
    clearCoins(p)
    local converter=assert(p:getItemById(12867,true));assert(converter:remove())
    converter=assert(Game.createItem(12867,1));assert(p:addItemEx(converter,false,CONST_SLOT_AMMO)==RETURNVALUE_NOERROR)
    -- A normal client Use packet must reach the registered action; the worker
    -- remains enabled, and the observing wrapper calls the real function.
    local realConvert,manualUses=M.convert,0
    M.convert=function(player)
        local source=debug.getinfo(2,'S').source:gsub('\\','/')
        if source:find('/actions/others/magic_gold_converter.lua',1,true)then manualUses=manualUses+1 end
        return realConvert(player)
    end
    request('use-owned','use',{from={65535,10,0},item=11904,stack=0})
    wait('native Use action',function()return manualUses==1 end,function()
        M.convert=realConvert
        check(p:getItemCount(12867)==1 and p:getMoney()==0,'Use consumed converter or created money')
        local pos=p:getPosition();pos.y=pos.y+1
        assert(converter:moveTo(pos))
        local cancel,groundUses=Player.sendCancelMessage,0
        Player.sendCancelMessage=function(player,message)
            if player:getGuid()==p:getGuid() and message=='Carry your Magic Gold Converter to use it.' then groundUses=groundUses+1 end
            return cancel(player,message)
        end
        later(1100,function()
            local ground=converter:getPosition()
            request('use-ground','use',{from={ground.x,ground.y,ground.z},item=11904,stack=Tile(ground):getThingIndex(converter)})
        end)
        wait('unowned Use refusal',function()return groundUses==1 end,function()
            Player.sendCancelMessage=cancel
            check(p:getItemCount(12867)==0 and p:getMoney()==0,'Ground Use activated or created money')
            local gold=assert(Game.createItem(2148,100,pos))
            groundRequest(p,gold,'pickup-without-converter')
            wait('gold pickup',function()return p:getItemCount(2148)==100 end,function()
            later(1500,function()
                check(p:getItemCount(2148)==100 and p:getItemCount(2152)==0,'A converter on the ground activated')
                groundRequest(p,converter,'pickup-converter',{65535,10,0})
                wait('automatic acquired-converter conversion',function()return p:getItemCount(2152)==1 end,function()
                    check(p:getItemCount(2148)==0 and p:getItemCount(12867)==1 and p:getMoney()==100,'Acquiring converter changed money value')
                    mint(p,2148,99)
                    local one=assert(Game.createItem(2148,1,pos))
                    groundRequest(p,one,'pickup-last-gold')
                    wait('automatic merged-stack conversion',function()return p:getItemCount(2152)==2 end,function()
                        check(p:getItemCount(2148)==0 and p:getMoney()==200,'Merged loot stack did not convert exactly once')
                        trade(p)
                    end)
                end)
            end)
            end)
        end)
    end)
end

local function run(p)
    if p:getName()=='Converter Peer' then
        p:setGhostMode(true);p:setCapacity(1000000)
        if p:getStorageValue(950701)==1 then
            check(p:getItemCount(12867)==1 and p:getItemCount(2152)==1 and p:getItemCount(2148)==0,'Receiver inventory did not survive reconnect')
            print('CONVERTER_PEER_RELOGIN_OK checks='..checks)
        else
            assert(p:addItem(1988,1,false));clearCoins(p);p:setStorageValue(950702,1);print('CONVERTER_PEER_ONLINE')
        end
        return
    end
    if p:getStorageValue(950700)==1 then
        check(p:getItemCount(12867)==0 and p:getItemCount(2148)==100 and p:getItemCount(2152)==0,'Sender state did not survive reconnect')
        check(p:getBankBalance()==800 and p:getItemCount(2554)==1,'Bank balance or ordinary saved item regressed')
        print('CONVERTER_MAIN_RELOGIN_OK checks='..checks);return
    end
    check(p:getGroup():getId()==1 and not p:hasFlag(PlayerFlag_HasInfiniteCapacity),'Fixture bypasses normal capacity')
    p:setGhostMode(true);p:setCapacity(1000000)
    local t=ItemType(12867)
    check(t:getClientId()==11904 and t:getName()=='magic gold converter','Native SID/CID/name mismatch')
    check(t:getWeight()==100 and not t:isStackable() and not t:isContainer(),'Native item flags/weight mismatch')
    local converter=assert(Game.createItem(12867,1));assert(p:addItemEx(converter,false,CONST_SLOT_AMMO)==RETURNVALUE_NOERROR)
    local gold=assert(Game.createItem(2148,100));assert(p:addItemEx(gold,false,CONST_SLOT_LEFT)==RETURNVALUE_NOERROR)
    check(not M.convert(p) and p:getItemCount(2148)==100 and p:getItemCount(12867)==1,'No-bag refusal consumed coins/converter')
    local bag=assert(p:addItem(1988,1,false))
    check(M.convert(p) and p:getItemCount(2152)==1 and p:getItemCount(2148)==0,'Conversion into a carried bag failed')
    assert(converter:remove());clearCoins(p)
    local category,index,entry
    for ci,c in ipairs(GameShop.catalog)do for oi,o in ipairs(c.offers)do if o.id==4006 then category,index,entry=ci,oi,o end end end
    assert(entry)
    local function buy()GameShop.handleClientOpcode(p,{action='buy',data={category=category,offer=index,cost=0,item=2148}})end
    GameShop.setPoints(p,99);buy()
    check(p:getItemCount(12867)==0 and GameShop.getPoints(p)==99,'Poor purchase mutated state')
    GameShop.setPoints(p,1000);p:setCapacity(0);buy()
    check(p:getItemCount(12867)==0 and GameShop.getPoints(p)==1000,'Failed delivery charged points or granted item')
    p:setCapacity(1000000);buy();converter=assert(p:getItemById(12867,true));assert(converter:moveTo(bag))
    check(p:getItemCount(12867)==1 and GameShop.getPoints(p)==900,'Shop grant/debit failed')
    local shovel=assert(p:addItem(2554,1,false));assert(shovel:moveTo(bag))
    for _,case in ipairs({{99,0,99,0,0},{100,0,0,1,0},{199,0,99,1,0},{100,99,0,0,1},{250,199,50,1,2},{0,100,0,0,1}})do
        clearCoins(p);mint(p,2148,case[1]);mint(p,2152,case[2]);local before=p:getMoney()
        M.convert(p)
        check(p:getItemCount(2148)==case[3] and p:getItemCount(2152)==case[4] and p:getItemCount(2160)==case[5],'Native boundary/cascade result wrong')
        check(p:getMoney()==before and not M.convert(p) and p:getItemCount(12867)==1,'Value, repeat conversion or permanent item failed')
    end
    clearCoins(p);local nested=assert(bag:addItem(1988,1));assert(converter:moveTo(nested))
    assert(bag:addItem(2148,60));assert(nested:addItem(2148,40));check(M.convert(p) and p:getItemCount(2152)==1,'Nested converter/split stacks failed')
    assert(converter:moveTo(bag));assert(nested:remove())
    clearCoins(p);local tagged=assert(bag:addItem(2148,100));tagged:setCustomAttribute('converter_qa_tag','quest')
    local marked=assert(bag:addItem(2152,100));marked:setActionId(60001)
    check(not M.convert(p) and tagged:getCount()==100 and marked:getCount()==100,'Tagged currency was converted')
    mint(p,2148,100);check(M.convert(p) and tagged:getCustomAttribute('converter_qa_tag')=='quest' and marked:getActionId()==60001,'Conversion altered protected instances')
    clearCoins(p)
    local externalGold=assert(Game.createItem(2148,100))
    assert(p:addItemEx(externalGold,false,CONST_SLOT_LEFT)==RETURNVALUE_NOERROR)
    local fillers={};while bag:getSize()<bag:getCapacity()do fillers[#fillers+1]=assert(bag:addItem(2376,1))end
    local size=bag:getSize()
    check(not M.convert(p) and p:getItemCount(2148)==100 and bag:getSize()==size,'Full bag/no output slot consumed money')
    assert(table.remove(fillers,1):remove());assert(externalGold:moveTo(bag))
    check(M.convert(p) and bag:getSize()==size and p:getItemCount(2152)==1,'Full bag did not reuse the consumed stack slot')
    for _,filler in ipairs(fillers)do assert(filler:remove())end
    clearCoins(p);mint(p,2148,100);p:setCapacity(0)
    check(M.convert(p) and p:getMoney()==100,'Weight-reducing conversion failed while overloaded');p:setCapacity(1000000)
    clearCoins(p);mint(p,2148,100);local bankBefore=1000;p:setBankBalance(bankBefore)
    local depot=assert(p:getDepotChest(99,true));assert(converter:moveTo(depot));local depotGold=assert(depot:addItem(2148,100))
    check(not M.convert(p) and p:getItemCount(2148)==100 and depotGold:getCount()==100,'Depot converter activated or depot currency changed')
    -- getDepotChest creates a detached chest until its real depot is opened;
    -- such items cannot be moved back through Item:moveTo. Use a new owned QA
    -- converter for the remaining cases; the depot one stays out of scope.
    converter=assert(p:addItem(12867,1,false));assert(converter:moveTo(bag))
    check(p:getItemCount(12867)==1 and M.convert(p) and p:getBankBalance()==bankBefore and depotGold:getCount()==100,'Carried conversion touched bank/depot money')
    clearCoins(p);mint(p,2148,100);p:setPersonalStore({mode=1,name='Converter QA'})
    local changed=M.convert(p);p:setPersonalStore({mode=0,name=''})
    check(not changed and p:getItemCount(2148)==100,'Personal-store seller inventory was changed')
    clearCoins(p);mint(p,2160,1);assert(p:removeMoney(15))
    check(p:getMoney()==9985 and not M.convert(p),'Ordinary payment/change with crystal coins regressed')
    assert(p:addMoney(15));M.convert(p)
    check(p:getMoney()==10000 and p:getItemCount(2160)==1,'Payment refund/cascade changed value')
    clearCoins(p);mint(p,2148,100);assert(M.convert(p));p:setBankBalance(1000)
    assert(p:depositMoney(37));check(p:getBankBalance()==1037 and p:getMoney()==63,'Bank deposit/change regressed')
    assert(p:withdrawMoney(237));assert(M.convert(p))
    check(p:getBankBalance()==800 and p:getMoney()==300 and p:getItemCount(2152)==3,'Bank withdrawal/automatic change regressed')
    clearCoins(p)
    for i=1,6 do assert(bag:addItem(1988,1))end
    mint(p,2148,10100)
    local create=Game.createItem;local made=0
    Game.createItem=function(id,count,...)made=made+1;if made==2 then return nil end;return create(id,count,...)end
    local failed,why=M.convert(p);Game.createItem=create
    check(not failed and why and p:getMoney()==10100 and p:getItemCount(2160)==0,'Partial output creation failure consumed input')
    check(M.convert(p) and p:getItemCount(2160)==1 and p:getItemCount(2152)==1 and p:getMoney()==10100,'Large inventory/cascade failed')
    clearCoins(p);mint(p,2148,100);assert(p:save())
    assert(db.query("CREATE TRIGGER converter_save_failure BEFORE UPDATE ON players FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='owned converter save failure'"))
    check(M.convert(p),'Conversion unexpectedly depends on SQL availability')
    local savedOk=p:save();assert(db.query('DROP TRIGGER converter_save_failure'))
    check(not savedOk and saved(p,2148)==100 and saved(p,2152)==0 and p:getItemCount(2152)==1,'Failed save left a partial durable currency state')
    assert(p:save());check(saved(p,2148)==0 and saved(p,2152)==1 and saved(p,12867)==1,'Converted inventory failed to save atomically')
    print('CONVERTER_SYNC_OK checks='..checks)
    wireCases(p,bag)
end
function event.onLogin(p)
    if p:getName()=='Passive Tester' or p:getName()=='Converter Peer'then
        local id=p:getId();later(300,function()run(assert(Player(id)))end)
    end
    return true
end
event:register()
