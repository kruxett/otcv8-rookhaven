-- Registered temporarily by the local test runner, never by production talkactions.xml.
dofile('data/spells/scripts/attack/sure_shot.lua')
local castSureShot = onCastSpell

function onSay(player, words, param)
  if configManager.getString(configKeys.SERVER_NAME) ~= 'Rookhaven Local Item Test'
      or player:getAccountType() < ACCOUNT_TYPE_GOD then return false end
  if param == 'guildclear' then
    player:setGuild(nil)
    return false
  end
  local ok, errorMessage = pcall(function()
    local pos = player:getPosition()
    local center = Position(pos.x + 2, pos.y, pos.z)
    local adjacent = Position(pos.x + 2, pos.y + 1, pos.z)
    local outside = Position(pos.x + 4, pos.y + 1, pos.z)
    local monsters = {}
    local equipment = {}
    local function cleanup()
      for _, monster in ipairs(monsters) do monster:remove() end
      for _, slot in ipairs({CONST_SLOT_LEFT, CONST_SLOT_RIGHT, CONST_SLOT_AMMO}) do
        local item = player:getSlotItem(slot)
        if item then item:remove() end
        if equipment[slot] then
          local result = player:addItemEx(equipment[slot], false, slot)
          assert(result == RETURNVALUE_NOERROR, 'fixture equipment restoration failed')
        end
      end
    end
    for _, slot in ipairs({CONST_SLOT_LEFT, CONST_SLOT_RIGHT, CONST_SLOT_AMMO}) do
      local item = player:getSlotItem(slot)
      if item then
        equipment[slot] = item:clone()
        item:remove()
      end
    end
    local success, reason = pcall(function()
      assert(player:addItemEx(Game.createItem(2456, 1), false, CONST_SLOT_LEFT) == RETURNVALUE_NOERROR)
      assert(player:addItemEx(Game.createItem(2546, 10), false, CONST_SLOT_AMMO) == RETURNVALUE_NOERROR)
      for _, position in ipairs({center, adjacent, outside}) do
        local monster = assert(Game.createMonster('Rat', position, false, true), 'fixture monster spawn failed')
        monster:setMaxHealth(10000)
        monster:setHealth(10000)
        monsters[#monsters+1] = monster
      end
      local ammo = player:getSlotItem(CONST_SLOT_AMMO)
      local count = ammo:getCount()
      assert(castSureShot(player, Variant(monsters[1]:getId())), 'native burst cast failed')
      assert(monsters[1]:getHealth() < 10000, 'center did not take burst damage')
      assert(monsters[2]:getHealth() < 10000, 'adjacent did not take burst damage')
      assert(monsters[3]:getHealth() == 10000, 'burst hit outside 3x3')
      assert(ammo:getCount() == count - 1, 'burst consumed incorrect ammo count')
      ammo:remove()
      for _, monster in ipairs(monsters) do monster:setHealth(10000) end
      assert(player:addItemEx(Game.createItem(2544, 10), false, CONST_SLOT_AMMO) == RETURNVALUE_NOERROR)
      assert(castSureShot(player, Variant(monsters[1]:getId())), 'native normal cast failed')
      assert(monsters[1]:getHealth() < 10000, 'normal arrow missed center')
      assert(monsters[2]:getHealth() == 10000 and monsters[3]:getHealth() == 10000, 'normal arrow acquired AoE')
      assert(player:getSlotItem(CONST_SLOT_AMMO):getCount() == 9, 'normal arrow consumed incorrect ammo count')
    end)
    cleanup()
    assert(success, reason)
  end)
  player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
    ok and 'FEATURE_NATIVE_COMBAT_OK' or ('FEATURE_NATIVE_COMBAT_FAILED '..tostring(errorMessage)))
  return false
end
