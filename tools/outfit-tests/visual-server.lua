assert(configManager.getString(configKeys.SERVER_NAME)=='Rookhaven Acolyte Visual QA')
local login=CreatureEvent('AcolyteVisualOwned')
function login.onLogin(p)
 if p:getName()=='Passive Tester'then
  p:setGhostMode(true);p:setCapacity(100000);GameShop.setPoints(p,1000)
  p:removeOutfit(373);p:removeOutfit(374)
  local pos=p:getPosition();pos.x=pos.x+1
  local npc=assert(Game.createNpc('Acolyte Preview',pos,false,true))
  npc:setDirection(DIRECTION_SOUTH)
  print('ACOLYTE_VISUAL_SERVER_READY')
 end
 return true
end
login:register()
local light=GlobalEvent('AcolyteVisualDaylight')
function light.onStartup()setWorldLight(215,215);return true end
light:type('startup');light:register()

