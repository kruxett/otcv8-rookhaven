if configManager.getString(configKeys.SERVER_NAME) ~= "Rookhaven Local Item Test" then return end
local proof = GlobalEvent("LocalItemProof")
function proof.onStartup()
  local item = ItemType(12829)
  assert(item:getClientId() == 11866, "OTB client mapping failed")
  assert(item:getName() == "rookhaven duskblade", "XML name failed")
  assert(item:getAttack() == 52 and item:getDefense() == 32 and item:getExtraDefense() == 3, "XML stats failed")
  assert(item:getWeaponType() == WEAPON_SWORD, "Weapon type failed")
  local instance = assert(Game.createItem(12829, 1))
  assert(instance:getId() == 12829)
  instance:remove()
  print("ITEM_SERVER_NATIVE_OK SID=12829 CID=11866 Atk=52 Def=32+3")
  return true
end
proof:register()
