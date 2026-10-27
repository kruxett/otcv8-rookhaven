-- Older matched engine is used solely for inventory rendering/look.
assert(configManager.getString(configKeys.SERVER_NAME)=='Rookhaven Boat Pass Visual QA')
local event=CreatureEvent('BoatPassVisualOwned')
function event.onLogin(p)
    if p:getName()=='Passive Tester' then
        p:setGhostMode(true)
        assert(p:getSlotItem(CONST_SLOT_RIGHT):getId()==12866)
        assert(ItemType(12866):getClientId()==11903)
        print('BOAT_PASS_VISUAL_SERVER_READY')
    end
    return true
end
event:register()
local daylight=GlobalEvent('BoatPassVisualDaylight')
function daylight.onStartup()setWorldLight(215,215);return true end
daylight:type('startup');daylight:register()
