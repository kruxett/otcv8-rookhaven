assert(configManager.getString(configKeys.SERVER_NAME)=='Rookhaven Modern Outfit Visual QA')
local login=CreatureEvent('ModernOutfitVisualQA')
function login.onLogin(p)
 if p:getName()~='Passive Tester'then return true end
 p:setGhostMode(true);p:setCapacity(100000);GameShop.setPoints(p,1000)
 assert(p:addItem(1988,1,false))
 for look=373,376 do p:removeOutfit(look)end
 local position=p:getPosition()
 for _,v in ipairs({{'Rune Female',373,2},{'Lion Male',376,-2},{'Lion Female',375,4}})do
  local npc=Game.createNpc(v[1]..' Preview',Position(position.x+v[3],position.y,position.z),false,true)
  assert(npc,'Preview NPC failed: '..v[1]);npc:setDirection(DIRECTION_SOUTH)
  npc:setOutfit({lookType=v[2],lookHead=58,lookBody=49,lookLegs=2,lookFeet=58,lookAddons=3})
 end
 print('MODERN_VISUAL_SERVER_READY')
 return true
end
login:register()

local light=GlobalEvent('ModernShopVisualDaylight')
function light.onStartup()setWorldLight(215,215);return true end
light:type('startup');light:register()
