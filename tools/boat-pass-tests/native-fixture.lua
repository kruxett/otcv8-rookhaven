-- Installed only into the owned loopback runtime and cold database copy.
assert(configManager.getString(configKeys.SERVER_NAME) == 'Rookhaven Boat Pass QA')
local event = CreatureEvent('BoatPassOwnedQA')
local checks = 0
local function check(value, message) assert(value, message); checks = checks + 1 end
local function sqlNumber(query)
    local row = assert(db.storeQuery(query), query)
    local n = result.getNumber(row, 'value'); result.free(row); return n
end
local function accountTime(p)
    return sqlNumber('SELECT boat_pass_ends_at AS value FROM accounts WHERE id=' .. p:getAccountId())
end
local function setTime(p, value)
    assert(db.query('UPDATE accounts SET boat_pass_ends_at=' .. value .. ' WHERE id=' .. p:getAccountId()))
end
local function savedCount(p, sid)
    return sqlNumber('SELECT COALESCE(SUM(count),0) AS value FROM player_items WHERE player_id=' .. p:getGuid() .. ' AND itemtype=' .. sid)
end
local function offer()
    for category, value in ipairs(GameShop.catalog) do
        for index, entry in ipairs(value.offers) do
            if entry.id == 4005 then return category, index, entry end
        end
    end
    error('Missing Boat Pass shop offer')
end
local function buy(p)
    local category, index = offer()
    GameShop.handleClientOpcode(p, {action='buy',data={category=category,offer=index,cost=0,item=2148}})
end
local function guarded(fn)
    local ok, why = pcall(fn)
    if not ok then print('BOAT_PASS_NATIVE_FAILED ' .. tostring(why)) end
end
local function waitUntil(label, predicate, done, timeout)
    local deadline = os.time() + (timeout or 25)
    local function poll()
        guarded(function()
            if predicate() then done(); return end
            assert(os.time() < deadline, label .. ' timed out')
            addEvent(poll, 100)
        end)
    end
    addEvent(poll, 100)
end
local faultFile = io.open('boat-pass-fault.txt','r')
local faultMode
if faultFile then faultMode = faultFile:read('*a'); faultFile:close() end

local function runRides(p, redeemedExpiry)
    local uid = UID.Boat_Fare_Spider_Island
    local station = assert(Item(uid), 'Actual Spider Island fare station is absent')
    dofile('data/actions/scripts/quests/spider_island_boat_travel.lua')
    local config = assert(BoatFareRegistry.get(uid))
    local realRideConfig = config.rideConfig
    local rideCalls, quoteCalls = 0, 0
    local startRide, setPending = BoatTravel.startRide, BoatFareRegistry.setPending
    -- Observe calls while executing the actual unchanged movement/fare functions.
    BoatTravel.startRide = function(player, rideConfig)
        if player == p then rideCalls = rideCalls + 1 end
        return startRide(player, rideConfig)
    end
    BoatFareRegistry.setPending = function(player, ...)
        if player == p then quoteCalls = quoteCalls + 1 end
        return setPending(player, ...)
    end
    local stages = {'paid','free','poor','paid_failure','free_failure','expired_quote'}
    local function prepare(index)
        local stage = stages[index]
        if not stage then
            config.rideConfig = realRideConfig
            BoatTravel.startRide, BoatFareRegistry.setPending = startRide, setPending
            setTime(p, redeemedExpiry); p:setStorageValue(950600,1); assert(p:save())
            print('BOAT_PASS_RIDES_OK checks=' .. checks)
            return
        end
        assert(p:getStorageValue(PS.Player_Boat_Ride_Active) ~= 1)
        config.rideConfig = realRideConfig
        if stage == 'paid_failure' or stage == 'free_failure' then config.rideConfig = nil end
        local free = stage == 'free' or stage == 'free_failure' or stage == 'expired_quote'
        setTime(p, stage == 'expired_quote' and os.time()+2 or (free and redeemedExpiry or 0))
        assert(p:removeMoney(p:getMoney()))
        if stage ~= 'free' and stage ~= 'poor' then assert(p:addMoney(50)) end
        assert(p:teleportTo(station:getPosition(),true))
        BoatFareRegistry.clearPending(p:getGuid())
        local callsBefore, quotesBefore = rideCalls, quoteCalls
        if stage == 'paid' then
            waitUntil('malformed response check', function()
                local f=io.open('boat-malformed-sent.txt','r'); if f then f:close();return true end
            end,function()
                check(rideCalls==callsBefore and p:getMoney()==50 and BoatFarePending[p:getGuid()]~=nil,
                    'Malformed boat reply bypassed the protocol admission checks')
                print('BOAT_PASS_MALFORMED_REPLY_OK')
            end)
        end
        local pos = station:getPosition()
        print('BOAT_PASS_WIRE_STATION stage=' .. stage .. ' request=' .. json.encode({
            x=pos.x,y=pos.y,z=pos.z,cid=ItemType(station:getId()):getClientId(),
            stack=Tile(pos):getThingIndex(station),uid=uid,
        }))
        local function completed()
            if stage == 'paid' or stage == 'free' then
                check(rideCalls == callsBefore+1, 'Replay started/charged another ride')
                local actual, expected = p:getPosition(), realRideConfig.endPosition
                check(actual.x==expected.x and actual.y==expected.y and actual.z==expected.z, stage .. ' boat did not reach its real destination')
                check(p:getMoney() == (stage=='paid' and 35 or 0), stage .. ' boat charged the wrong fare')
            elseif stage == 'poor' or stage == 'expired_quote' then
                check(rideCalls == callsBefore, stage .. ' boarded without a valid confirmed fare')
                check(p:getMoney() == (stage=='poor' and 0 or 50), stage .. ' changed gold')
            else
                check(rideCalls == callsBefore+1, 'Failure did not execute the actual ride validation')
                check(p:getMoney() == 50, stage .. ' refund lost or created money')
            end
            print('BOAT_PASS_STAGE_OK stage=' .. stage .. ' checks=' .. checks)
            addEvent(function() guarded(function() prepare(index+1) end) end,1100)
        end
        if stage == 'expired_quote' then
            waitUntil('free quote', function() return quoteCalls>quotesBefore end, function()
                check(BoatFarePending[p:getGuid()].quotedPrice == 0, 'Expected a real free pending quote')
                addEvent(function() guarded(function()
                    check(p:getBoatPassEndsAt()<=os.time(), 'Expiry fixture is still active')
                    print('BOAT_PASS_EXPIRED_QUOTE_READY')
                end) end,3100)
            end)
        end
        waitUntil(stage, function()
            return quoteCalls > quotesBefore and BoatFarePending[p:getGuid()]==nil
                and p:getStorageValue(PS.Player_Boat_Ride_Active)~=1
        end, completed, 35)
    end
    prepare(1)
end

local function run(p)
    if p:getName() ~= 'Passive Tester' then
        if p:getName() == 'Boat Account Mate' then
            local main = assert(Player('Passive Tester'))
            check(p:getAccountId()==main:getAccountId() and p:getBoatPassEndsAt()==main:getBoatPassEndsAt(), 'Same-account character missed committed pass')
            check(BoatPass.getFare(p,15)==0 and p:getPremiumTime()==0, 'Same-account free fare or separate Premium failed')
            local owned = assert(p:addItem(12866,1,false))
            local before = accountTime(p)
            check(not main:redeemBoatPass(owned) and accountTime(p)==before and p:getItemCount(12866)==1, 'Another character redeemed an unowned pass')
            assert(owned:remove()); assert(p:save())
            print('BOAT_PASS_SAME_ACCOUNT_OK checks='..checks)
        elseif p:getName() == 'Boat Other Account' then
            check(p:getBoatPassEndsAt()==0 and BoatPass.getFare(p,15)==15 and p:getPremiumTime()==0, 'Pass leaked to another account')
            print('BOAT_PASS_OTHER_ACCOUNT_OK checks='..checks)
        end
        return
    end
    if faultMode then
        local expectedConsumed = faultMode ~= 'commit_unknown_before'
        if p:getStorageValue(950600)==2 then
            check(p:getBoatPassEndsAt()==accountTime(p), 'Fault recovery loaded inconsistent account time')
            check((p:getBoatPassEndsAt()>os.time()+29*86400)==expectedConsumed, 'Fault recovery applied wrong expiry')
            check(p:getItemCount(12866)==(expectedConsumed and 0 or 1), 'Fault recovery duplicated or lost the pass')
            check(p:getPremiumTime()==0, 'Boat fault recovery granted Premium')
            assert(p:save()); check(savedCount(p,12866)==p:getItemCount(12866), 'Recovery save overwrote durable inventory')
            print('BOAT_PASS_FAULT_RELOGIN_OK mode='..faultMode..' checks='..checks)
            return
        end
        p:setCapacity(100000); assert(p:addItem(1988,1,false))
        setTime(p,0); p:setPremiumEndsAt(0); p:setStorageValue(950600,2)
        local item=assert(p:addItem(12866,1,false)); assert(p:save())
        print('BOAT_PASS_FAULT_PREPARED mode='..faultMode)
        check(not p:redeemBoatPass(item,faultMode), 'Uncertain commit reported success')
        print('BOAT_PASS_FAULT_RETURN mode='..faultMode)
        return
    end
    if p:getStorageValue(950600)==1 then
        check(p:getBoatPassEndsAt()==accountTime(p) and p:getBoatPassEndsAt()>os.time()+29*86400, 'Pass expiry did not survive reconnect')
        check(p:getSlotItem(CONST_SLOT_AMMO)==nil and p:getItemCount(12866)==0, 'Consumed pass returned after reconnect')
        check(p:getPremiumTime()==0 and p:getItemCount(2554)>0, 'Premium changed or ordinary item save regressed')
        print('BOAT_PASS_NATIVE_RELOGIN_OK checks='..checks)
        return
    end
    check(p:getGroup():getId()==1 and not p:hasFlag(PlayerFlag_HasInfiniteCapacity), 'Fixture bypasses ordinary-player capacity')
    p:setGhostMode(true); p:setCapacity(100000); p:setPremiumEndsAt(0)
    local bag = assert(p:addItem(1988,1,false)); local shovel=assert(p:addItem(2554,1,false)); assert(shovel:moveTo(bag))
    assert(p:save()); check(savedCount(p,2554)==1, 'Ordinary item save failed')
    local t=ItemType(12866)
    check(t:getClientId()==11903 and t:getName()=='boat pass (30 days)', 'Native SID/CID/name mismatch')
    check(not t:isStackable() and not t:isContainer() and t:getWeight()==100, 'Native pass flags/weight failed')
    local _,_,entry=offer()
    setTime(p,0); GameShop.setPoints(p,entry.cost-1); buy(p)
    check(p:getItemCount(12866)==0 and GameShop.getPoints(p)==99, 'Poor purchase changed balance/inventory')
    GameShop.setPoints(p,1000); p:setCapacity(0); buy(p)
    check(p:getItemCount(12866)==0 and GameShop.getPoints(p)==1000, 'Failed delivery charged points or granted pass')
    p:setCapacity(100000); buy(p)
    check(p:getItemCount(12866)==1 and GameShop.getPoints(p)==900, 'Shop purchase/debit failed')
    check(p:getBoatPassEndsAt()==0 and p:getPremiumTime()==0, 'Buying activated the pass or Premium')
    local item=assert(p:getItemById(12866,true)); local now=os.time()
    local ok,days=p:redeemBoatPass(item)
    check(ok and days==30 and p:getBoatPassEndsAt()>=now+30*86400 and p:getBoatPassEndsAt()<=os.time()+30*86400, 'Fresh activation duration failed')
    check(p:getItemCount(12866)==0 and savedCount(p,12866)==0 and p:getBoatPassEndsAt()==accountTime(p), 'Consumption/account time was not durable')
    check(sqlNumber('SELECT value FROM player_storage WHERE player_id='..p:getGuid()..' AND `key`=910500')==900, 'Redemption failed to persist shop debit')
    check(p:getPremiumTime()==0 and BoatPass.getFare(p,15)==0, 'Boat Pass granted Premium or failed to waive fare')
    local expiry=accountTime(p)
    item=assert(p:addItem(12866,1,false)); check(p:redeemBoatPass(item), 'Extension refused')
    check(accountTime(p)==expiry+30*86400, 'Extension lost or rounded remaining time')
    setTime(p,os.time()-86400); item=assert(p:addItem(12866,1,false)); now=os.time()
    check(p:redeemBoatPass(item) and accountTime(p)>=now+30*86400, 'Expired pass did not start from now')
    p:setPremiumEndsAt(os.time()+3*86400); local premium=p:getPremiumEndsAt()
    item=assert(p:addItem(12866,1,false)); check(p:redeemBoatPass(item) and p:getPremiumEndsAt()==premium, 'Boat redemption changed existing Premium')
    p:setPremiumEndsAt(0)
    local before=accountTime(p)
    local scroll=assert(p:addItem(12858,1,false))
    check(not p:redeemBoatPass(scroll) and accountTime(p)==before and p:getItemCount(12858)==1, 'Wrong item granted Boat Pass')
    assert(scroll:remove())
    local ground=assert(Game.createItem(12866,1,p:getPosition()))
    check(not p:redeemBoatPass(ground) and accountTime(p)==before, 'Ground pass was redeemed')
    assert(ground:remove())
    item=assert(p:addItem(12866,1,false))
    check(not p:redeemPremiumScroll(item) and p:getPremiumTime()==0 and p:getItemCount(12866)==1, 'Boat item granted Premium')
    setTime(p,4294967290)
    check(not p:redeemBoatPass(item) and p:getBoatPassEndsAt()==4294967290 and p:getItemCount(12866)==1, 'Overflow consumed pass or wrapped expiry')
    setTime(p,before)
    assert(db.query("CREATE TRIGGER boat_pass_save_failure BEFORE UPDATE ON players FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='owned boat save failure'"))
    ok=p:redeemBoatPass(item)
    assert(db.query('DROP TRIGGER boat_pass_save_failure'))
    check(not ok and p:getItemCount(12866)==1 and accountTime(p)==before, 'Save failure granted time or consumed pass')
    assert(db.query("CREATE TRIGGER boat_pass_account_failure BEFORE UPDATE ON accounts FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='owned boat account rollback'"))
    ok=p:redeemBoatPass(item)
    assert(db.query('DROP TRIGGER boat_pass_account_failure'))
    check(not ok and p:getItemCount(12866)==1 and savedCount(p,12866)==1 and accountTime(p)==before, 'Failed account UPDATE did not roll back inventory')
    assert(db.query('ALTER TABLE accounts RENAME COLUMN boat_pass_ends_at TO boat_pass_qa_missing'))
    local fare,reason=BoatPass.getFare(p,15)
    ok=p:redeemBoatPass(item)
    assert(db.query('ALTER TABLE accounts RENAME COLUMN boat_pass_qa_missing TO boat_pass_ends_at'))
    check(fare==nil and type(reason)=='string' and not ok and p:getItemCount(12866)==1 and accountTime(p)==before, 'Unavailable entitlement query charged/granted/consumed')
    assert(item:remove())
    local old=p:getSlotItem(CONST_SLOT_AMMO); if old then assert(old:moveTo(bag)) end
    local pass=assert(Game.createItem(12866,1))
    check(p:addItemEx(pass,false,CONST_SLOT_AMMO)==RETURNVALUE_NOERROR, 'Could not prepare actual native Use item')
    setTime(p,0); assert(p:save())
    print('BOAT_PASS_WIRE_READY checks='..checks)
    waitUntil('real Use packet',function() return accountTime(p)>os.time() end,function()
        check(p:getSlotItem(CONST_SLOT_AMMO)==nil and savedCount(p,12866)==0, 'Native action did not consume the used pass')
        check(p:getBoatPassEndsAt()>os.time()+29*86400 and p:getPremiumTime()==0, 'Native action granted wrong entitlement')
        local redeemedExpiry=accountTime(p); assert(p:save())
        print('BOAT_PASS_NATIVE_OK checks='..checks)
        waitUntil('ride phase signal',function()
            local f=io.open('boat-start-rides.txt','r'); if f then f:close();return true end
        end,function() runRides(p,redeemedExpiry) end)
    end)
end
function event.onLogin(p)
    if p:getName()=='Passive Tester' or p:getName()=='Boat Account Mate' or p:getName()=='Boat Other Account' then
        addEvent(function(id) guarded(function() run(assert(Player(id))) end) end,300,p:getId())
    end
    return true
end
event:register()
