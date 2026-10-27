-- Real inventory rendering and use-with from an opened bag, no custom overlay.
local failed,finished=false,false
local function fail(why)
    if failed then return end;failed=true;print('TOOLKIT_VISUAL_FAILED '..tostring(why))
    if g_game.isOnline() then g_game.safeLogout() end
    scheduleEvent(function()g_app.exit()end,500)
end
local function later(ms,fn)
    scheduleEvent(function()if failed or finished then return end;local ok,e=pcall(fn);if not ok then fail(e)end end,ms)
end
local function wait(label,predicate,nextStep)
    local deadline=g_clock.millis()+12000
    local function poll()
        local value=predicate()
        if value then later(100,function()nextStep(value)end);return end
        assert(g_clock.millis()<deadline,label..' timed out');later(100,poll)
    end
    later(100,poll)
end
later(300,function()
    assert(LOCAL_PASSIVES_TEST and Services.updater=='' and g_resources.getLayout()=='retro')
    connect(g_game,{
        onLoginError=fail,onConnectionError=function(e)if not finished then fail(e)end end,
        onGameStart=function()
            EnterGame.hide()
            later(1500,function()
                local p=assert(g_game.getLocalPlayer())
                local tool=assert(p:getInventoryItem(InventorySlotRight))
                assert(tool:getId()==11902 and tool:isMultiUse() and not tool:isContainer() and not tool:isStackable(),'actual native Toolkit flags failed')
                local choice=modules.game_passives and modules.game_passives.getClassChoice and modules.game_passives.getClassChoice()
                local dialog=choice and choice.getWindow()
                if dialog and dialog:isVisible() then
                    local cancel=dialog:recursiveGetChildById('cancelButton');if cancel then signalcall(cancel.onClick,cancel)end
                end
                local inv=modules.game_inventory
                if not inv.inventoryWindow:isVisible() then inv.toggle()end
                g_window.resize({width=1280,height=800})
                g_game.open(assert(p:getInventoryItem(InventorySlotBack)))
                wait('backpack',function()for _,bag in pairs(g_game.getContainers())do return bag end end,function(bag)
                    g_game.move(tool,bag:getSlotPosition(0),1)
                    wait('Toolkit in bag',function()
                        for _,item in ipairs(bag:getItems())do if item:getId()==11902 then return item end end
                    end,function(kit)
                        local pos=p:getPosition();pos.y=pos.y+1
                        local function grass(cid)
                            local tile=g_map.getTile(pos);if not tile then return end
                            for _,item in ipairs(tile:getItems())do if item:getId()==cid then return item end end
                        end
                        wait('grass target',function()return grass(3696)end,function(target)
                            g_game.useWith(kit,target)
                            wait('actual machete result',function()return grass(3695)end,function()
                                g_game.look(kit)
                                later(900,function()
                                    g_app.doScreenshot('/toolkit-ingame-inventory.png')
                                    later(600,function()
                                        print('TOOLKIT_VISUAL_OK actualConnection=true normalBagMove=true normalUseWith=true')
                                        finished=true;g_game.safeLogout();scheduleEvent(function()g_app.exit()end,700)
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
    G.account,G.password='toolkitqa','ToolkitLoopbackOnly'
    g_game.loginWorld(G.account,G.password,'Local Toolkit QA','127.0.0.1',7186,'Passive Tester','','')
end)
scheduleEvent(function()if not finished then fail('overall timeout')end end,40000)
