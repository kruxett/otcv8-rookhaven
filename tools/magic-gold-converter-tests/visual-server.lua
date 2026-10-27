-- Older matched engine is used solely for inventory rendering/look.
assert(configManager.getString(configKeys.SERVER_NAME)=='Rookhaven Converter Visual QA')
local event=CreatureEvent('ConverterVisualOwned')
function event.onLogin(p)
    if p:getName()=='Passive Tester' then
        p:setGhostMode(true)
        assert(p:getSlotItem(CONST_SLOT_RIGHT):getId()==12867)
        assert(ItemType(12867):getClientId()==11904)
        print('CONVERTER_VISUAL_SERVER_READY')
    end
    return true
end
event:register()
local daylight=GlobalEvent('ConverterVisualDaylight')
function daylight.onStartup()setWorldLight(215,215);return true end
daylight:type('startup');daylight:register()
