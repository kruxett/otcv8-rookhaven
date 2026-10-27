-- Installed ONLY into the runner's cold loopback database/runtime copy.
assert(configManager.getString(configKeys.SERVER_NAME) == 'Rookhaven Premium Scroll QA')
local login = CreatureEvent('PremiumScrollOwnedQA')
local faultFile = io.open('premium-scroll-fault.txt', 'r')
local faultMode
if faultFile then faultMode = faultFile:read('*a'); faultFile:close() end
local function sqlNumber(query)
    local row = assert(db.storeQuery(query), query)
    local number = result.getNumber(row, 'value'); result.free(row); return number
end
local function accountTime(p)
    return sqlNumber('SELECT premium_ends_at AS value FROM accounts WHERE id=' .. p:getAccountId())
end
local function savedCount(p, sid)
    return sqlNumber('SELECT COALESCE(SUM(count),0) AS value FROM player_items WHERE player_id=' .. p:getGuid() .. ' AND itemtype=' .. sid)
end
local function offer(id)
    for category, value in ipairs(GameShop.catalog) do
        for index, entry in ipairs(value.offers) do
            if entry.id == id then return category, index, entry end
        end
    end
    error('Missing offer ' .. id)
end
local function buy(p, id)
    local category, index = offer(id)
    GameShop.handleClientOpcode(p, {action='buy', data={category=category, offer=index, cost=0, item=2148}})
end
local checks = 0
local function check(value, message)
    assert(value, message); checks = checks + 1
end
local function run(p)
    if faultMode then
        local expectedConsumed = faultMode ~= 'commit_unknown_before'
        if p:getStorageValue(950600) == 2 then
            check(p:getPremiumEndsAt() == accountTime(p), 'fault recovery loaded inconsistent premium')
            check((p:getPremiumTime() > 29 * 86400) == expectedConsumed, 'fault recovery applied wrong account state')
            check(p:getItemCount(12858) == (expectedConsumed and 0 or 1), 'fault recovery duplicated or lost the scroll')
            assert(p:save())
            check(savedCount(p, 12858) == p:getItemCount(12858), 'post-recovery save overwrote durable inventory')
            print('PREMIUM_SCROLL_FAULT_RELOGIN_OK mode=' .. faultMode .. ' checks=' .. checks)
            return
        end
        p:setCapacity(10000)
        if not p:getSlotItem(CONST_SLOT_BACKPACK) then assert(p:addItem(1988, 1, false)) end
        p:setPremiumEndsAt(0); p:setStorageValue(950600, 2)
        local item = assert(p:addItem(12858, 1, false))
        assert(p:save())
        print('PREMIUM_SCROLL_FAULT_PREPARED mode=' .. faultMode)
        local accepted = p:redeemPremiumScroll(item, faultMode)
        check(not accepted, 'uncertain commit unexpectedly reported success')
        print('PREMIUM_SCROLL_FAULT_RETURN mode=' .. faultMode)
        return
    end
    if p:getStorageValue(950600) == 1 then
        check(p:getPremiumEndsAt() == accountTime(p), 'premium expiry did not reload from the account')
        check(p:getPremiumTime() > 29 * 86400, 'premium time did not survive reconnect')
        check(p:getSlotItem(CONST_SLOT_AMMO) == nil, 'consumed scroll returned after reconnect')
        check(p:getItemCount(2554) > 0, 'ordinary saved item did not survive reconnect')
        print('PREMIUM_SCROLL_NATIVE_RELOGIN_OK checks=' .. checks)
        return
    end
    check(p:getGroup():getId() == 1, 'fixture must use an ordinary player')
    check(not p:hasFlag(PlayerFlag_HasInfiniteCapacity), 'fixture bypasses native capacity')
    p:setCapacity(10000)
    if not p:getSlotItem(CONST_SLOT_BACKPACK) then p:addItem(1988, 1, false) end
    assert(p:addItem(2554, 1, false))
    assert(p:save())
    check(savedCount(p, 2554) > 0, 'ordinary save path failed')
    for index, days in ipairs({30, 60, 90}) do
        local sid, cid = 12857 + index, 11894 + index
        local t = ItemType(sid)
        check(t:getClientId() == cid and t:getName() == 'premium scroll (' .. days .. ' days)', 'native item mapping/name failed')
        check(not t:isStackable() and not t:isContainer() and t:getWeight() == 100, 'native item flags/weight failed')
        p:setPremiumEndsAt(os.time() - 86400)
        local baseCount = p:getItemCount(sid)
        local premiumBefore = p:getPremiumEndsAt()
        local _, _, entry = offer(5000 + index)
        GameShop.setPoints(p, entry.cost - 1)
        buy(p, 5000 + index)
        check(p:getItemCount(sid) == baseCount and GameShop.getPoints(p) == entry.cost - 1, 'poor purchase mutated inventory/balance')
        GameShop.setPoints(p, 1000); p:setCapacity(0)
        buy(p, 5000 + index)
        check(p:getItemCount(sid) == baseCount and GameShop.getPoints(p) == 1000, 'failed native delivery charged or granted')
        p:setCapacity(10000)
        buy(p, 5000 + index)
        check(p:getItemCount(sid) == baseCount + 1 and GameShop.getPoints(p) == 1000 - entry.cost, 'native shop purchase/debit failed')
        check(p:getPremiumEndsAt() == premiumBefore, 'buying activated premium instead of giving a scroll')
        local item = assert(p:getItemById(sid, true))
        local now = os.time()
        local ok, resultDays = p:redeemPremiumScroll(item)
        check(ok and resultDays == days, 'native redemption refused the scroll')
        check(p:getItemCount(sid) == baseCount and savedCount(p, sid) == baseCount, 'scroll consumption was not durable/exact')
        check(p:getPremiumEndsAt() >= now + days * 86400 and p:getPremiumEndsAt() <= os.time() + days * 86400, 'expired premium gained incorrect time')
        check(accountTime(p) == p:getPremiumEndsAt(), 'account premium not committed')
        check(sqlNumber('SELECT value FROM player_storage WHERE player_id=' .. p:getGuid() .. ' AND `key`=910500') == 1000 - entry.cost, 'shop debit was not persisted before redemption')
    end
    p:setPremiumEndsAt(os.time() + 7 * 86400)
    local base = p:getPremiumEndsAt()
    for index, days in ipairs({30, 60, 90}) do
        local sid = 12857 + index
        local item = assert(p:addItem(sid, 1, false))
        check(p:redeemPremiumScroll(item), 'active-premium redemption failed')
        base = base + days * 86400
        check(p:getPremiumEndsAt() == base and accountTime(p) == base, 'active premium was reset or rounded')
    end
    local ordinary = assert(p:addItem(2148, 1, false))
    local goldBefore, timeBefore = p:getItemCount(2148), p:getPremiumEndsAt()
    check(not p:redeemPremiumScroll(ordinary), 'ordinary item redeemed as premium')
    check(p:getItemCount(2148) == goldBefore and p:getPremiumEndsAt() == timeBefore, 'invalid item changed inventory/premium')
    local ground = assert(Game.createItem(12858, 1, p:getPosition()))
    check(not p:redeemPremiumScroll(ground) and p:getPremiumEndsAt() == timeBefore, 'ground scroll granted premium')
    assert(ground:remove())
    -- Force only the premium UPDATE to fail, after the snapshot was written.
    assert(db.query("CREATE TRIGGER premium_scroll_qa_failure BEFORE UPDATE ON accounts FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='owned premium scroll rollback fixture'"))
    local refused = assert(p:addItem(12858, 1, false))
    local countBefore = p:getItemCount(12858)
    local ok = p:redeemPremiumScroll(refused)
    assert(db.query('DROP TRIGGER premium_scroll_qa_failure'))
    check(not ok and p:getItemCount(12858) == countBefore and savedCount(p, 12858) == countBefore, 'failed premium UPDATE consumed the scroll')
    check(p:getPremiumEndsAt() == timeBefore and accountTime(p) == timeBefore, 'failed premium UPDATE changed premium time')
    assert(refused:remove())
    GameShop.setPoints(p, 1000)
    local quiverBefore = p:getItemCount(12830)
    buy(p, 4001)
    check(p:getItemCount(12830) == quiverBefore + 1 and GameShop.getPoints(p) == 850, 'existing quiver purchase regressed')
    local quiver = assert(p:getItemById(12830, true))
    check(quiver:isContainer() and quiver:getCapacity() == 20, 'existing quiver definition regressed')
    for _, spell in ipairs({'Keychain Consume', 'Keychain Unlock', 'Keychain List'}) do p:forgetSpell(spell) end
    GameShop.setPoints(p, 1000); buy(p, 1001)
    check(GameShop.getPoints(p) == 750 and p:hasLearnedSpell('Keychain Consume') and p:hasLearnedSpell('Keychain Unlock') and p:hasLearnedSpell('Keychain List'), 'existing Keyring purchase regressed')
    buy(p, 1001)
    check(GameShop.getPoints(p) == 750, 'known Keyring spells charged twice')
    -- Unchanged premium API is still usable by existing consumers.
    base = p:getPremiumEndsAt(); assert(p:addPremiumDays(1)); assert(p:removePremiumDays(1))
    check(math.abs(p:getPremiumEndsAt() - base) <= 1, 'existing premium add/remove API regressed')
    local old = p:getSlotItem(CONST_SLOT_AMMO); if old then assert(old:remove()) end
    local wireScroll = assert(Game.createItem(12858, 1))
    check(p:addItemEx(wireScroll, false, CONST_SLOT_AMMO) == RETURNVALUE_NOERROR, 'could not prepare actual native Use item')
    p:setPremiumEndsAt(0); p:setStorageValue(950600, 1); assert(p:save())
    print('PREMIUM_SCROLL_WIRE_READY checks=' .. checks)
    local id, expiry = p:getId(), os.time() + 20
    local function awaitUse()
        local player = Player(id); if not player then return end
        if player:getPremiumEndsAt() > os.time() then
            check(player:getSlotItem(CONST_SLOT_AMMO) == nil, 'native action did not consume exactly the used scroll')
            check(player:getPremiumTime() > 29 * 86400 and accountTime(player) == player:getPremiumEndsAt(), 'native action did not grant 30 days')
            assert(player:save())
            print('PREMIUM_SCROLL_NATIVE_OK checks=' .. checks)
            return
        end
        assert(os.time() < expiry, 'timed out waiting for real Use packet')
        addEvent(awaitUse, 100)
    end
    addEvent(awaitUse, 100)
end
function login.onLogin(player)
    if player:getName() == 'Passive Tester' then
        addEvent(function(id)
            local ok, why = pcall(run, assert(Player(id)))
            if not ok then print('PREMIUM_SCROLL_NATIVE_FAILED ' .. tostring(why)) end
        end, 300, player:getId())
    end
    return true
end
login:register()
