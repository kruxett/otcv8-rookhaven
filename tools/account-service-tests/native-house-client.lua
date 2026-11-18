-- Only packaged by the owned loopback QA runner.
local done,failed,expectedLogout=false,false,false
local recipientLogin,recipientChecked=false,false
local previewAll,previewsVerified,previewsRunning=nil,false,false
local function fail(e)
  if failed then return end;failed=true;print('HOUSES_UI_FAILED '..tostring(e))
  local w=rootWidget:recursiveGetChildById('Cat5')
  print('HOUSE_DIAGNOSTIC window='..tostring(w)..' visible='..tostring(w and w:isVisible())..' status='..tostring(w and w:recursiveGetChildById('houseStatus'):getText()))
  g_app.doScreenshot('/accounts-houses-failure.png');scheduleEvent(function()g_app.exit()end,400)
end
local function later(ms,fn)scheduleEvent(function()if done or failed then return end;local ok,e=xpcall(fn,debug.traceback);if not ok then fail(e)end end,ms)end
local function wait(label,test,nextStep)
  local deadline=g_clock.millis()+15000
  local function poll()local value=test();if value then nextStep(value);return end;assert(g_clock.millis()<deadline,label..' timed out');later(100,poll)end
  later(100,poll)
end
local function win(id)local w=rootWidget:recursiveGetChildById(id);return w and w:isVisible()and w end
local function click(w)assert(w and w:isEnabled(),'button unavailable');signalcall(w.onClick,w)end
local function findButton(parent,text)
  for _,w in ipairs(parent:getChildren())do if w:isVisible()and w:getText()==text then return w end;local found=findButton(w,text);if found then return found end end
end
local function shot(name,nextStep)
  g_window.resize({width=800,height=640});later(300,function()g_app.doScreenshot('/accounts-houses-'..name..'-800.png')
    g_window.resize({width=1280,height=800});later(300,function()g_app.doScreenshot('/accounts-houses-'..name..'-1280.png');g_window.resize({width=800,height=640});nextStep()end)
  end)
end
local function ready()
  local w=win('Cat5');return w and w:recursiveGetChildById('houseRefresh'):isEnabled()and w
end
local function data()return modules.game_cyclopedia.HouseMarketUI.getData()end
local function settled()return ready() and not modules.game_cyclopedia.HouseMarketUI.isBusy() and data() and ready()end
local function option(text)
  click(ready().LateralBase:getChildById('houseMoreButton'))
  click(assert(findButton(rootWidget,text),'missing action '..text))
end
local function confirm()click(assert(findButton(rootWidget,'Confirm'),'missing confirmation'))end
local function dismissError()
  local button=findButton(rootWidget,'Ok')or findButton(rootWidget,'OK');assert(button,'missing error close');click(button)
end
local function ownerFlow(w,nextStep)
  option('List for sale')
  local panel=w.bidArea;local area=panel:getChildById('bidArea')
  area.textEdit:setText('5000000000');assert(not panel.bid:isEnabled(),'invalid gold accepted')
  area.textEdit:setText('800');assert(panel.bid:isEnabled(),'valid gold refused')
  click(panel.bid)
  g_game.talk('/accountsqa houserevision')
  later(600,function()
    modules.game_cyclopedia.HouseMarketUI.refresh()
    wait('refresh with existing confirmation',settled,function()
      confirm()
      wait('stale form refused',function()return ready() and w.houseStatus:getText():find('changed',1,true)end,function()
        assert(not data().listing,'stale quote created listing');dismissError();click(panel.cancel)
        option('List for sale');panel=w.bidArea;area=panel:getChildById('bidArea');area.textEdit:setText('800')
        shot('sale-form',function()
          click(panel.bid);confirm()
          wait('listing created',function()return settled()and data().listing end,function()
            option('Cancel listing');assert(w.cancelHouseTransferArea:isVisible(),'original cancellation form missing')
            shot('cancel-form',function()
              click(w.cancelHouseTransferArea.transfer);confirm()
              wait('listing cancelled',function()return settled()and not data().listing end,function()
                click(w.LateralBase:getChildById('transferButton'))
                assert(w.transferArea:isVisible(),'original transfer form missing')
                assert(not w.transferArea.transfer:isEnabled(),'empty recipient accepted')
                w.transferArea.owner:setText('Home Seller');w.transferArea.price:setText('0')
                assert(w.transferArea.transfer:isEnabled(),'valid gift refused')
                shot('transfer-form',function()
                  click(w.transferArea.cancel)
                  option('Start auction');w.transferArea.owner:setText('999');assert(not w.transferArea.transfer:isEnabled(),'excessive auction duration accepted')
                  w.transferArea.owner:setText('24');assert(w.transferArea.transfer:isEnabled(),'valid auction duration refused');click(w.transferArea.cancel)
                  click(w.LateralBase:getChildById('moveOutButton'));local leave=w.moveOutArea
                  leave.confirmation:setText('no');assert(not leave.move:isEnabled(),'leave accepted without exact text')
                  leave.confirmation:setText('LEAVE');assert(leave.move:isEnabled(),'leave confirmation refused')
                  shot('move-form',function()click(leave.cancel);nextStep()end)
                end)
              end)
            end)
          end)
        end)
      end)
    end)
  end)
end
local function finish()
  if not previewsVerified and g_resources.fileExists('/game_cyclopedia/images/houses/rookhaven/manifest.json')then
    if not previewsRunning then previewsRunning=true;previewAll(finish)end
    return
  end
  done=true;print('HOUSES_UI_NATIVE_OK browse=true owner=true listing=true cancellation=true leaveConfirmation=true accessEditor=true reopen=true originalSevenPanels='..tostring(recipientChecked)..' recipientAcceptance='..tostring(recipientChecked)..' guildParity=__GUILD_UI__');g_app.exit()
end
local function guildUi()
  if not __GUILD_UI__ then finish();return end
  modules.game_cyclopedia.HouseMarketUI.hide();modules.game_guild.toggle()
  wait('guild leader view',function()local w=win('guildWindow');return w and w:recursiveGetChildById('renameGuildBtn'):isVisible()and w end,function(w)
    click(w:recursiveGetChildById('infoTab'));click(w:recursiveGetChildById('renameGuildBtn'))
    local d=assert(win('guildInputWindow'));d:recursiveGetChildById('inputField'):setText('UI Renamed Guild');click(d:recursiveGetChildById('okBtn'))
    wait('guild rename refresh',function()return w:recursiveGetChildById('infoGuildName'):getText()=='UI Renamed Guild'end,function()
      shot('guild-info',function()
        click(w:recursiveGetChildById('membersTab'));w:recursiveGetChildById('inviteNameField'):setText('Home Rival');click(w:recursiveGetChildById('inviteBtn'))
        later(800,function()
          click(w:recursiveGetChildById('invitesTab'))
          wait('withdraw invitation button',function()return w:recursiveGetChildById('withdrawInviteBtn')end,function(withdraw)
            shot('guild-invitation',function()
              click(withdraw)
              wait('withdrawn invite refresh',function()return not w:recursiveGetChildById('withdrawInviteBtn')end,function()
                click(w:recursiveGetChildById('infoTab'));click(w:recursiveGetChildById('renameGuildBtn'))
                assert(win('guildInputWindow'),'guild input did not open')
                expectedLogout=true;g_game.safeLogout()
                wait('logout closes guild input',function()return not g_game.isOnline()end,function()
                  assert(not win('guildInputWindow'),'guild input survived into another login context')
                  finish()
                end)
              end)
            end)
          end)
        end)
      end)
    end)
  end)
end
local function verifyTownFilters(complete)
  local H=modules.game_cyclopedia.HouseMarketUI;local C=modules.game_cyclopedia.Cyclopedia
  local expected=json.decode([==[__HOUSE_TOWN_EXPECTATIONS__]==])
  local towns=C.House.towns;local total=0
  local function townAt(index)
    local town=towns[index]
    if not town then
      assert(total==57,'town coverage differs from world')
      print('HOUSE_TOWN_FILTERS_NATIVE_OK towns='..#towns..' houses='..total..' imagesMatch=true');complete();return
    end
    local wanted=0;for _,id in pairs(expected)do if id==town.id then wanted=wanted+1 end end
    local w=ready();w.TopBase.CityOption:setCurrentOptionByData(town.id)
    local seen={};local found=0
    local function inspectPage()
      wait('town filter '..town.name,function()
        return ready()and not H.isBusy()and H.getFilters().townId==town.id and C.House.total==wanted and (wanted==0 or data())
      end,function()
        local option=w.TopBase.CityOption:getCurrentOption()
        assert(option.data==town.id and option.text==town.name,'town label/ID mismatch')
        local rows=w.ListBase.AuctionList:getChildren()
        for _,row in ipairs(rows)do
          assert(expected[tostring(row.data.id)]==town.id and row.data.townName==town.name,'house shown in wrong town')
          assert(not seen[row.data.id],'town pagination repeated a house');seen[row.data.id]=true;found=found+1
        end
        if wanted==0 then assert(#rows==0 and not w.LateralBase.MapViewbase.houseImage:isVisible(),'empty town kept old house/image')
        else assert(w.LateralBase.MapViewbase.houseImage:isVisible(),'town selection lost house image')end
        local function advance()
          if w.houseNext:isEnabled()then click(w.houseNext);inspectPage()
          else
            assert(found==wanted,'town filter omitted houses');total=total+found
            print('HOUSE_TOWN_NATIVE '..json.encode({id=town.id,name=town.name,houses=found}))
            later(300,function()townAt(index+1)end)
          end
        end
        if C.House.page==1 then shot('city-'..town.name:gsub('[^%w]','-'),function()later(300,advance)end)
        else later(300,advance)end
      end)
    end
    inspectPage()
  end
  townAt(1)
end
previewAll=function(complete)
  local C=modules.game_cyclopedia.Cyclopedia;local H=modules.game_cyclopedia.HouseMarketUI
  local catalogue=json.decode([==[__HOUSE_PHOTO_MANIFEST__]==])
  local expected={};for _,entry in ipairs(catalogue.houses)do expected[entry.id]=entry end
  local seen={};local count=0
  local representatives={[1]=true,[7]=true,[9]=true,[13]=true,[24]=true,[52]=true,[57]=true}
  local function page(number)
    H.list({page=number,townId=0,filter='all',status=0,sort='name',search=''})
    wait('photo catalogue page '..number,settled,function(w)
      local rows=w.ListBase.AuctionList:getChildren()
      local function item(index)
        local row=rows[index]
        if not row then
          if number*15<C.House.total then later(300,function()page(number+1)end)
          else
            assert(count==#catalogue.houses and count==C.House.total,'native preview coverage differs from map')
            previewsVerified=true;print('HOUSE_PREVIEWS_NATIVE_OK houses='..count..' originalImageFrame=true missing=false');verifyTownFilters(complete)
          end
          return
        end
        local id=row.data.id;local info=assert(expected[id],'unexpected house id')
        w.ListBase.AuctionList:ensureChildVisible(row);click(row)
        wait('selected photo '..id,function()return settled()and data().id==id end,function()
          local frame=w.LateralBase.MapViewbase
          assert(frame.houseImage:isVisible()and not frame.noHouse:isVisible(),'missing native preview '..id)
          assert(g_resources.fileExists('/game_cyclopedia/images/houses/rookhaven/previews/'..id..'.png'),'missing photograph resource '..id)
          assert(not seen[id]and data().name==info.name,'wrong or duplicate preview identity')
          seen[id]=true;count=count+1
          local function advance()later(300,function()item(index+1)end)end
          if representatives[id]then
            print('HOUSE_PREVIEW_NATIVE '..json.encode({id=id,rect=frame.houseImage:getRect()}))
            shot('photo-house-'..id,advance)
          else advance()end
        end)
      end
      later(300,function()item(1)end)
    end)
  end
  page(1)
end
local function recipientForms()
  local w=ready();local ownerName=data().name
  click(w.LateralBase:getChildById('transferButton'))
  w.transferArea.owner:setText('Home Seller');w.transferArea.price:setText('0');click(w.transferArea.transfer);confirm()
  wait('private gift created',function()return settled() and data().listing and data().listing.type=='private'end,function()
    expectedLogout=true;recipientLogin=true;g_game.safeLogout()
    wait('owner logout',function()return not g_game.isOnline()end,function()
      CharacterList.hide()
      EnterGame.doLogin('homeseller','HouseFixtureOnly','','127.0.0.1:7187:860')
      wait('recipient character list',function()return CharacterList.isVisible()and G.characters and G.characters[1]and G.characters[1].name=='Home Seller'end,function()
        CharacterList.doLogin()
        wait('recipient capability',function()return g_game.isOnline()and modules.game_cyclopedia.HouseMarketUI.isEnabled()end,function()
          EnterGame.hide();if modules.game_outfit.destroy then modules.game_outfit.destroy(true,true)end
          modules.game_cyclopedia.HouseMarketUI.show()
          wait('recipient browse',settled,function(w2)
            -- This character owns no house and can inspect the original auction form.
            click(w2.LateralBase:getChildById('bidButton'))
            local area=w2.bidArea:getChildById('bidArea')
            assert(area.automatic:isVisible()and area.automatic:isChecked(),'proxy option missing in original bid form')
            area.automatic:setChecked(false)
            shot('bid-form',function()
              click(w2.bidArea.cancel);w2.TopBase.CityOption:setCurrentOptionByData('mine')
              wait('incoming gift in own houses',function()return settled()and data().name==ownerName and data().listing and data().listing.canBuy end,function()
                click(w2.LateralBase:getChildById('rejectTransfer'))
                assert(w2.rejectTransferHouse:isVisible(),'original rejection panel missing')
                shot('reject-form',function()
                  click(w2.rejectTransferHouse.cancel)
                  click(w2.LateralBase:getChildById('acceptTransfer'))
                  assert(w2.acceptTransferHouse:isVisible()and w2.acceptTransferHouse.transferPrice:getText()=='0','original acceptance panel has wrong gift price')
                  shot('accept-form',function()
                    click(w2.acceptTransferHouse.transfer);confirm()
                    wait('gift accepted without owner change before restart',function()return settled()and data().pending and not data().isOwner end,function()
                      assert(data().pending.recipientName=='Home Seller'and data().pending.price==0,'pending gift details incorrect')
                      recipientChecked=true;later(600,finish)
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
  assert(modules.game_cyclopedia.HouseMarketUI,'existing house module did not load')
  connect(g_game,{onLoginError=fail,onConnectionError=function(e)if not expectedLogout then fail(e)end end,onGameStart=function()
    if recipientLogin then EnterGame.hide();return end
    EnterGame.hide()
    later(600,function()
      if modules.game_outfit.destroy then modules.game_outfit.destroy(true,true)end
      g_window.resize({width=800,height=640})
      local tabs={'bestiary','map','character'}
      local function inspect(index)
        local name=tabs[index];if not name then return end
        modules.game_cyclopedia.show(name)
        later(200,function()
          local ui=modules.game_cyclopedia.controllerCyclopedia.ui
          local selected=ui:recursiveGetChildById(name)
          assert(selected:getWidth()==150 and selected:getHeight()==34,name..' active tab differs from the shared expanded button')
          assert(ui:recursiveGetChildById('houses'):getWidth()==34,'inactive house button expanded beside '..name)
          print('CYCLOPEDIA_TAB_NATIVE '..name..' active=150x34 houseInactive=34x34')
          g_app.doScreenshot('/accounts-houses-tab-'..name..'-800.png')
          later(100,function()inspect(index+1)end)
        end)
      end
      inspect(1)
    end)
    later(1800,function()
      if modules.game_outfit.destroy then modules.game_outfit.destroy(true,true)end
      assert(modules.game_cyclopedia.HouseMarketUI.isEnabled(),'house capability did not enable existing tab')
      -- Existing navigation must retain a complete, non-overlapping icon.
      for _,name in ipairs({'bestiary','map','character'})do modules.game_cyclopedia.show(name)end
      local ui=modules.game_cyclopedia.controllerCyclopedia.ui
      local houseTab=ui:recursiveGetChildById('houses');local characterTab=ui:recursiveGetChildById('character')
      assert(houseTab:getWidth()==34,'inactive house button must use the complete compact icon')
      assert(characterTab:getPosition().x>=houseTab:getPosition().x+houseTab:getWidth(),'house and character buttons overlap')
      modules.game_cyclopedia.HouseMarketUI.show()
      wait('house catalogue',settled,function(w)
        assert(houseTab:getWidth()==150 and houseTab:getHeight()==34,'active house button differs from the other tabs')
        print('CYCLOPEDIA_TAB_NATIVE houses active=150x34 matchesOtherTabs=true')
        assert(#w.ListBase.AuctionList:getChildren()>0,'original house list empty')
        shot('browse',function()
          w.TopBase.CityOption:setCurrentOptionByData('mine')
          wait('owned house details',function()return settled()and data().isOwner and #w.ListBase.AuctionList:getChildren()==1 end,function()
            shot('owner',function()
              ownerFlow(w,function()
                option('Edit guests')
                wait('native guest editor',function()return win('textWindow')end,function(editor)
                  editor:getChildById('text'):setText('Home Seller\n')
                  shot('guest-editor',function()
                    click(editor:getChildById('okButton'))
                    later(1000,function()
                      option('Buy offers')
                      shot('offers',function()
                        option('Back to houses')
                        wait('back to original list',settled,function()
                          modules.game_cyclopedia.HouseMarketUI.hide();modules.game_cyclopedia.HouseMarketUI.show()
                          wait('reopened original view',settled,function()
                            g_game.talk('/accountsqa housesave');later(1500,function()if __RECIPIENT_UI__ then recipientForms()else guildUi()end end)
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
  end})
  Servers.Default='127.0.0.1:7187:860';EnterGame.onServerChange()
  rootWidget:recursiveGetChildById('rememberPasswordBox'):setChecked(false)
  EnterGame.doLogin('homebuyer','HouseFixtureOnly','','127.0.0.1:7187:860')
  wait('character list',CharacterList.isVisible,function()CharacterList.doLogin()end)
end)
scheduleEvent(function()if not done then fail('native house UI timeout')end end,170000)
