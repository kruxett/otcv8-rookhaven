-- Owned loopback fixture. The PNG chooser is exercised with the visible OS UI;
-- each GUILD_IMPORT_WAIT names the generated test file the operator selects.
local done,failed=false,false
local function fail(e)
  if failed then return end;failed=true;print('GUILDS_UI_FAILED '..tostring(e))
  g_app.doScreenshot('/accounts-guild-failure.png');scheduleEvent(function()g_app.exit()end,400)
end
local function later(ms,fn)scheduleEvent(function()if done or failed then return end;local ok,e=xpcall(fn,debug.traceback);if not ok then fail(e)end end,ms)end
local function wait(label,test,nextStep,timeout)
  local deadline=g_clock.millis()+(timeout or 15000)
  local function poll()local value=test();if value then nextStep(value);return end;assert(g_clock.millis()<deadline,label..' timed out');later(100,poll)end
  later(100,poll)
end
local function win(id)local w=rootWidget:recursiveGetChildById(id);return w and w:isVisible()and w end
local function click(w)assert(w and w:isEnabled(),'button unavailable');signalcall(w.onClick,w)end
local function shot(name,nextStep)
  g_window.resize({width=800,height=640});later(250,function()g_app.doScreenshot('/accounts-guild-'..name..'-800.png')
    g_window.resize({width=1280,height=800});later(250,function()g_app.doScreenshot('/accounts-guild-'..name..'-1280.png');g_window.resize({width=800,height=640});nextStep()end)
  end)
end
local function guildUI()
  if modules.game_outfit.destroy then modules.game_outfit.destroy(true,true)end
  modules.game_guild.toggle()
  wait('large guild overview',function()
    local w=win('guildWindow')
    return w and w:recursiveGetChildById('infoMemberCount'):getText():find('1001',1,true) and
      w:recursiveGetChildById('guildCrest'):getImageTextureWidth()==32 and w
  end,function(w)
    local function W(id)return w:recursiveGetChildById(id)end
    assert(w:getWidth()==720 and w:getHeight()==500,'compact retro window changed')
    assert(W('chooseEmblemBtn'):isEnabled()and not W('saveEmblemBtn'):isEnabled(),'emblem controls have wrong initial state')
    assert(not W('guildCrest'):setGuildEmblemPixels('bad') and W('guildCrest'):getImageTextureWidth()==32,'malformed raster replaced the displayed crest')
    click(W('renameGuildBtn'))
    local input=assert(win('guildInputWindow'));input:recursiveGetChildById('inputField'):setText('UI Renamed Guild');click(input:recursiveGetChildById('okBtn'))
    wait('rename UI refresh',function()return W('infoGuildName'):getText()=='UI Renamed Guild'end,function()
      shot('overview',function()
        click(W('membersTab'))
        wait('member page one',function()return W('guildPageLabel'):getText():find('1001 members',1,true)and W('guildNextBtn'):isEnabled()end,function()
          local first=W('membersListPanel'):getFirstChild():recursiveGetChildById('memberName'):getText()
          click(W('guildNextBtn'))
          wait('member page two',function()return W('guildPageLabel'):getText():find('Page 2 /',1,true)and W('guildPreviousBtn'):isEnabled()end,function()
            assert(W('membersListPanel'):getFirstChild():recursiveGetChildById('memberName'):getText()~=first,'next page repeated old members')
            shot('members-page-two',function()
              W('memberSearchField'):setText('Distant Scout')
              wait('global search',function()return W('guildPageLabel'):getText():find('1 member',1,true)and #W('membersListPanel'):getChildren()==1 end,function()
                assert(W('membersListPanel'):getFirstChild():recursiveGetChildById('memberName'):getText():find('Distant Scout',1,true),'search only filtered the current page')
                shot('search',function()
                  W('memberSearchField'):setText('')
                  later(500,function()
                    click(W('invitesTab'))
                    wait('invitation page',function()return W('guildPageLabel'):getText():find('230 invitations',1,true)and W('guildNextBtn'):isEnabled()end,function()
                      click(W('guildNextBtn'))
                      wait('invitation page two',function()return W('guildPageLabel'):getText():find('Page 2 /',1,true)end,function()
                        shot('invites',function()
                          click(W('ranksTab'));later(400,function()
                            assert(W('addRankBtn'):isVisible(),'rank management disappeared')
                            shot('ranks',function()
                              click(W('activityTab'))
                              wait('activity page',function()return W('guildNextBtn'):isVisible()and W('guildNextBtn'):isEnabled()end,function()
                                click(W('guildNextBtn'))
                                wait('activity page two',function()return W('guildPageLabel'):getText():find('Page 2 /',1,true)end,function()
                                  shot('activity',function()
                                    -- Closing while a read is in flight must not resurrect the window.
                                    click(W('refreshBtn'));modules.game_guild.hide()
                                    later(500,function()
                                      assert(not win('guildWindow'),'late reply reopened a closed window')
                                      modules.game_guild.toggle()
                                      wait('reopened guild',function()return win('guildWindow')end,function(newWindow)
                                        w=newWindow;click(W('infoTab'))
                                        wait('reopened overview',function()return W('chooseEmblemBtn'):isVisible()and W('chooseEmblemBtn'):isEnabled()end,function()
                                          local cases={'wrong-size.png','oversize.png','animated.png','damaged.png','valid.png'}
                                          local function choose(index)
                                            local file=cases[index]
                                            if not file then
                                              shot('saved-emblem',function()
                                                done=true;print('GUILDS_UI_NATIVE_OK pages=true globalSearch=true ranks=true activity=true rename=true staleClose=true importValidation=true previewSave=true');g_app.exit()
                                              end)
                                              return
                                            end
                                            click(W('chooseEmblemBtn'));print('GUILD_IMPORT_WAIT '..file)
                                            wait('PNG chooser '..file,function()return W('chooseEmblemBtn'):isEnabled()and W('emblemStatus'):getText()~='Choosing an image...'end,function()
                                              if file~='valid.png' then
                                                assert(not W('saveEmblemBtn'):isEnabled(),'invalid file became uploadable: '..file)
                                                print('GUILD_IMPORT_REFUSED '..file..' '..W('emblemStatus'):getText());choose(index+1)
                                              else
                                                assert(W('saveEmblemBtn'):isEnabled(),'valid PNG did not produce a preview')
                                                shot('preview',function()
                                                  click(W('saveEmblemBtn'))
                                                  wait('saved emblem refresh',function()return W('chooseEmblemBtn'):isEnabled()and not W('saveEmblemBtn'):isEnabled()and W('emblemStatus'):getText()=='Your guild emblem.'and W('guildCrest'):getImageTextureWidth()==32 and W('emblemPreview'):getImageTextureWidth()==32 end,function()choose(index+1)end)
                                                end)
                                              end
                                            end,120000)
                                          end
                                          choose(1)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
                    end)
                  end)
                end)
              end)
            end)
          end)
        end)
      end)
    end)
  end)
end
later(400,function()
  assert(LOCAL_PASSIVES_TEST and Services.updater==''and g_resources.getLayout()=='retro')
  connect(g_game,{onLoginError=fail,onConnectionError=fail,onGameStart=function()EnterGame.hide();later(700,guildUI)end})
  Servers.Default='127.0.0.1:7187:860';EnterGame.onServerChange()
  rootWidget:recursiveGetChildById('rememberPasswordBox'):setChecked(false)
  EnterGame.doLogin('homebuyer','HouseFixtureOnly','','127.0.0.1:7187:860')
  wait('character list',CharacterList.isVisible,function()CharacterList.doLogin()end)
end)
scheduleEvent(function()if not done then fail('native guild UI timeout')end end,570000)
