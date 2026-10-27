assert(configManager.getString(configKeys.SERVER_NAME)=='Rookhaven Toolkit Visual QA')
local event=CreatureEvent('ToolkitVisualOwned')
function event.onLogin(p)
    if p:getName()=='Passive Tester' then
        local id=p:getId()
        addEvent(function()
            local player=assert(Player(id));player:setGhostMode(true)
            assert(player:getSlotItem(CONST_SLOT_RIGHT):getId()==12865)
            local pos=player:getPosition();pos.y=pos.y+1
            assert(Tile(pos));assert(Game.createItem(2782,1,pos))
            local deadline=os.time()+30
            local function used()
                local tile=assert(Tile(pos))
                if tile:getItemById(2781) and not tile:getItemById(2782) then
                    print('TOOLKIT_VISUAL_SERVER_USE_OK');return
                end
                assert(os.time()<deadline,'visual Toolkit use timed out')
                addEvent(used,200)
            end
            addEvent(used,200)
        end,400)
    end
    return true
end
event:register()
local daylight=GlobalEvent('ToolkitVisualDaylight')
function daylight.onStartup()setWorldLight(215,215);return true end
daylight:type('startup');daylight:register()
