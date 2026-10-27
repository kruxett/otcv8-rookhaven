-- Only installed into a cold, loopback-only test runtime.
assert(configManager.getString(configKeys.SERVER_NAME) == 'Rookhaven Light Ring QA')
local login = CreatureEvent('LightRingOwnedQA')
local checks, failed = 0, false
local function check(value, message) assert(value, message); checks = checks + 1 end
local function later(ms, fn)
    addEvent(function()
        if failed then return end
        local ok, why = pcall(fn)
        if not ok then failed = true; print('LIGHT_RING_NATIVE_FAILED ' .. tostring(why)) end
    end, ms)
end
local function light(p, level, color)
    local actual, actualColor = p:getLight()
    check(actual == level and (not color or actualColor == color), 'unexpected player light: ' .. actual .. '/' .. actualColor)
end
local function ring(p) return assert(p:getSlotItem(CONST_SLOT_RING), 'missing equipped ring') end
local function duration(item) return item:getAttribute(ITEM_ATTRIBUTE_DURATION) end
local function run(p)
    p:setLight(0, 0)
    if p:getStorageValue(950610) == 2 then
        local active = ring(p)
        check(active:getId() == 12862, 'active ring did not survive relog')
        check(active:getCustomAttribute('light_ring_qa') == 'preserved', 'instance data did not survive relog')
        check(duration(active) > 0 and duration(active) < 7200000, 'remaining duration reset on relog')
        light(p, 7, 206)
        active:setAttribute(ITEM_ATTRIBUTE_DURATION, 1000)
        local deadline = os.time() + 22
        local function expired()
            local player = assert(Player(p:getId()))
            if not player:getSlotItem(CONST_SLOT_RING) then
                light(player, 0)
                check(player:getItemCount(12861) == 0 and player:getItemCount(12862) == 0, 'expired ring left a usable item')
                assert(player:save())
                print('LIGHT_RING_NATIVE_OK checks=' .. checks)
                return
            end
            check(os.time() < deadline, 'active ring did not expire')
            later(200, expired)
        end
        later(200, expired)
        return
    end
    check(p:getGroup():getId() == 1 and not p:hasFlag(PlayerFlag_HasInfiniteCapacity), 'ordinary player fixture required')
    p:setCapacity(10000)
    local backpack = assert(Game.createItem(1988, 1))
    check(p:addItemEx(backpack, false, CONST_SLOT_BACKPACK) == RETURNVALUE_NOERROR, 'backpack setup failed')
    -- Legacy rings can also be held in a hand. Occupy both hands so the
    -- native generic destination resolver exercises the finger slot.
    check(p:addItemEx(assert(Game.createItem(2050, 1)), false, CONST_SLOT_LEFT) == RETURNVALUE_NOERROR, 'left hand fixture failed')
    check(p:addItemEx(assert(Game.createItem(2554, 1)), false, CONST_SLOT_RIGHT) == RETURNVALUE_NOERROR, 'right hand fixture failed')
    local wedding = assert(Game.createItem(2121, 1))
    check(p:addItemEx(wedding, false, CONST_SLOT_RING) == RETURNVALUE_NOERROR, 'ordinary ring setup failed')
    light(p, 0)
    check(ItemType(12861):getClientId() == 11898 and ItemType(12862):getClientId() == 11899, 'native SID/CID mapping failed')
    check(ItemType(12862):getDuration() == 7200, 'native charge duration is not two hours')
    local category, offer
    for c, value in ipairs(GameShop.catalog) do
        for i, entry in ipairs(value.offers) do
            if entry.id == 4002 then category, offer = c, i; check(entry.cost == 10 and entry.grant.itemId == 12861, 'cheap ring offer changed') end
        end
    end
    assert(category and offer)
    local function buy()
        GameShop.handleClientOpcode(p, {action='buy', data={category=category, offer=offer, cost=0}})
    end
    GameShop.setPoints(p, 9); buy()
    check(p:getItemCount(12861) == 0 and GameShop.getPoints(p) == 9, 'insufficient-points purchase changed items/points')
    GameShop.setPoints(p, 50); p:setCapacity(0); buy()
    check(p:getItemCount(12861) == 0 and GameShop.getPoints(p) == 50, 'failed delivery consumed points')
    p:setCapacity(10000); buy()
    check(p:getItemCount(12861) == 1 and GameShop.getPoints(p) == 40, 'purchase did not grant one ring for10 points')
    local item = assert(p:getItemById(12861, true))
    -- With the finger slot occupied, normal legacy delivery may use ammo.
    -- Put this purchased item in the bag before testing normal auto-equip.
    assert(item:moveTo(backpack, 0))
    item:setCustomAttribute('light_ring_qa', 'preserved')
    light(p, 0)
    local invalid = assert(Game.createItem(12861, 1))
    check(p:addItemEx(invalid, false, CONST_SLOT_HEAD) ~= RETURNVALUE_NOERROR, 'ring allowed in head slot')
    -- Native addItemEx already deletes a prepared item after refused delivery.
    assert(wedding:moveTo(backpack, 0))
    assert(item:moveTo(p, 0))
    check(ring(p):getId() == 12862, 'equip did not select lit sprite state')
    check(duration(ring(p)) == 7200000, 'initial active charge is wrong')
    light(p, 7, 206)
    local playerId = p:getId()
    later(18000, function()
        local player = assert(Player(playerId)); local active = ring(player)
        local remaining = duration(active)
        check(remaining > 0 and remaining < 7200000, 'active charge did not decrease')
        check(active:getCustomAttribute('light_ring_qa') == 'preserved', 'equip transform lost instance data')
        assert(active:moveTo(backpack, 0))
        local inactive = assert(player:getItemById(12861, true))
        check(duration(inactive) == remaining, 'unequip reset the charge')
        light(player, 0)
        later(3000, function()
            check(duration(inactive) == remaining, 'inactive ring kept consuming charge')
            -- Ordinary torch regression, including fallback after ring removal.
            local torch = assert(Game.createItem(2051, 1))
            check(player:addItemEx(torch, false, CONST_SLOT_AMMO) == RETURNVALUE_NOERROR, 'torch equipment failed')
            light(player, 7, 206)
            assert(inactive:moveTo(player, 0)); light(player, 7, 206)
            assert(ring(player):moveTo(backpack, 0)); light(player, 7, 206)
            assert(torch:remove()); light(player, 0)
            -- A stronger independent light survives equip/unequip.
            player:setLight(215, 9)
            inactive = assert(player:getItemById(12861, true))
            assert(inactive:moveTo(player, 0)); light(player, 9, 215)
            assert(ring(player):moveTo(backpack, 0)); light(player, 9, 215)
            player:setLight(0, 0); light(player, 0)
            -- Existing timed ring still transforms and applies/removes speed.
            local speed = player:getSpeed()
            local oldRing = assert(Game.createItem(2169, 1))
            check(player:addItemEx(oldRing, false, CONST_SLOT_RING) == RETURNVALUE_NOERROR, 'time ring equip failed')
            check(ring(player):getId() == 2206 and player:getSpeed() == speed + 60, 'existing time ring equip regressed')
            assert(ring(player):moveTo(backpack, 0))
            check(oldRing:getId() == 2169 and player:getSpeed() == speed, 'existing time ring unequip regressed')
            assert(oldRing:remove())
            inactive = assert(player:getItemById(12861, true))
            check(duration(inactive) == remaining, 'equipment cycling refilled the Light Ring')
            assert(inactive:moveTo(player, 0)); light(player, 7, 206)
            player:setStorageValue(950610, 2); assert(player:save())
            print('LIGHT_RING_NATIVE_READY_RELOGIN checks=' .. checks)
        end)
    end)
end
function login.onLogin(player)
    if player:getName() == 'Passive Tester' then
        local id = player:getId()
        later(300, function() run(assert(Player(id))) end)
    end
    return true
end
login:register()
