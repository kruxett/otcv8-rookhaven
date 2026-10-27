assert(configManager.getString(configKeys.SERVER_NAME)=='Rookhaven Batch Outfit Visual QA')
local login=CreatureEvent('BatchShopVisualQA')
function login.onLogin(p)
 if p:getName()~='Passive Tester'then return true end
 p:setGhostMode(true);p:setCapacity(100000);GameShop.setPoints(p,1000)
 assert(p:addItem(1988,1,false))
 for look=373,398 do p:removeOutfit(look)end
 print('BATCH_VISUAL_SERVER_READY')
 return true
end
login:register()
local light=GlobalEvent('BatchShopDaylight')
function light.onStartup()setWorldLight(215,215);return true end
light:type('startup');light:register()
