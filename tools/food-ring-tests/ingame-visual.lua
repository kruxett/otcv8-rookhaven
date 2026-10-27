-- Real client connection, server inventory state, map and ordinary move packets.
local failed, finished = false, false
local function fail(why)
    if failed then return end; failed = true
    print('FOOD_RING_VISUAL_FAILED ' .. tostring(why))
    if g_game.isOnline() then g_game.safeLogout() end
    scheduleEvent(function()g_app.exit()end,500)
end
local function later(ms, fn)
    scheduleEvent(function()if failed or finished then return end;local ok,e=pcall(fn);if not ok then fail(e)end end,ms)
end
local function wait(label, predicate, nextStep)
    local endTime = g_clock.millis()+12000
    local function poll()
        local value=predicate()
        if value then later(150,function()nextStep(value)end);return end
        assert(g_clock.millis()<endTime,label..' timed out');later(100,poll)
    end
    later(100,poll)
end
later(300,function()
    assert(LOCAL_PASSIVES_TEST and Services.updater=='' and g_resources.getLayout()=='retro')
    connect(g_game,{
        onLoginError=fail,
        onConnectionError=function(e)if not finished then fail(e)end end,
        onGameStart=function()
            EnterGame.hide()
            later(1500,function()
                local p=assert(g_game.getLocalPlayer())
                assert(p:getInventoryItem(InventorySlotFinger):getId()==11901,'equipped CID missing')
                local class = modules.game_passives and modules.game_passives.getClassChoice and modules.game_passives.getClassChoice()
                local dialog = class and class.getWindow()
                if dialog and dialog:isVisible() then
                    local cancel=dialog:recursiveGetChildById('cancelButton');if cancel then signalcall(cancel.onClick,cancel) end
                end
                local inv=modules.game_inventory
                if not inv.inventoryWindow:isVisible() then inv.toggle() end
                g_window.resize({width=1280,height=800})
                g_game.open(assert(p:getInventoryItem(InventorySlotBack)))
                wait('actual backpack',function()
                    for _,c in pairs(g_game.getContainers()) do return c end
                end,function(bag)
                    later(700,function()
                        local slot=assert(inv.inventoryPanel:getChildById('slot9'))
                        assert(slot:getItemId()==11901,'actual ring slot does not show equipped sprite')
                        g_app.doScreenshot('/food-ring-ingame-equipped.png')
                        later(600,function()
                            g_game.move(p:getInventoryItem(InventorySlotFinger),bag:getSlotPosition(0),1)
                            wait('unequipped state',function()
                                if p:getInventoryItem(InventorySlotFinger) then return end
                                for _,item in ipairs(bag:getItems()) do if item:getId()==11900 then return item end end
                            end,function(unlit)
                                later(600,function()
                                    g_app.doScreenshot('/food-ring-ingame-unequipped.png')
                                    later(600,function()
                                        g_game.move(unlit,{x=65535,y=9,z=0},1)
                                        wait('reequipped state',function()
                                            local item=p:getInventoryItem(InventorySlotFinger);return item and item:getId()==11901
                                        end,function()
                                            later(700,function()
                                                print('FOOD_RING_VISUAL_OK actualConnection=true normalMoves=true writeDir='..g_resources.getWriteDir())
                                                finished=true;g_game.safeLogout();scheduleEvent(function()g_app.exit()end,700)
                                            end)
                                        end)
                                    end)
                                end)
                            end)
                        end)
                    end)
                end)
            end)
        end,
    })
    g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
    G.account,G.password='foodringqa','FoodRingLoopbackOnly'
    g_game.loginWorld(G.account,G.password,'Local Ring QA','127.0.0.1',7186,'Passive Tester','','')
end)
scheduleEvent(function()if not finished then fail('overall timeout')end end,40000)
