local failed,finished=false,false
local function fail(why)
 if failed then return end;failed=true;print('ACOLYTE_VISUAL_FAILED '..tostring(why))
 if g_game.isOnline()then g_game.safeLogout()end
 scheduleEvent(function()g_app.exit()end,500)
end
local function later(ms,fn)scheduleEvent(function()if failed or finished then return end;local ok,e=pcall(fn);if not ok then fail(e)end end,ms)end
local function wait(label,predicate,nextStep)
 local deadline=g_clock.millis()+14000
 local function poll()
  local value=predicate()
  if value then later(100,function()nextStep(value)end);return end
  assert(g_clock.millis()<deadline,label..' timed out');later(100,poll)
 end
 later(100,poll)
end
local function closeDialogs()
 local root=g_ui.getRootWidget()
 for _,widget in ipairs(root:getChildren())do
  if widget:getClassName()=='UIMessageBox'then widget:destroy()end
 end
 local choice=modules.game_passives and modules.game_passives.getClassChoice and modules.game_passives.getClassChoice()
 local dialog=choice and choice.getWindow()
 if dialog and dialog:isVisible()then local b=dialog:recursiveGetChildById('cancelButton');if b then signalcall(b.onClick,b)end end
end
local function photograph()
 closeDialogs()
 local p=g_game.getLocalPlayer()
 assert(p:getOutfit().type==374 and p:getOutfit().addons==3)
 g_app.doScreenshot('/acolyte-ingame-world.png')
 later(500,function()
  local root=g_ui.getRootWidget();local panel=g_ui.createWidget('UIWidget',root)
  panel:setRect({x=80,y=110,width=720,height=430});panel:setBackgroundColor('#24272b');panel:raise()
  local title=g_ui.createWidget('UILabel',panel);title:setRect({x=95,y=120,width=680,height=30})
  title:setText('Acolyte - Female (OTSP20) / Male (OTSP21) - native rendering')
  for row,look in ipairs({373,374})do
   for direction=0,3 do
    local x=95+direction*172;local y=160+(row-1)*184
    local label=g_ui.createWidget('UILabel',panel);label:setRect({x=x,y=y,width=160,height=22})
    label:setText((row==1 and 'Female' or 'Male')..' - '..({'North','East','South','West'})[direction+1])
    local view=g_ui.createWidget('UICreature',panel);view:setRect({x=x+10,y=y+26,width=136,height=136})
    view:setOutfit({type=look,head=58,body=49,legs=2,feet=58,addons=3});view:setDirection(direction);view:setAnimate(true)
    assert(view:getOutfit().type==look)
   end
  end
  later(1200,function()
   g_app.doScreenshot('/acolyte-native-directions.png')
   later(500,function()
    panel:destroy()
    local store=modules.game_shop
    store.show()
    assert(store.shop:isVisible(),'shop not visible')
    local category=store.shop.categories:getChildById('category_3')
    assert(category and category.name:getText()=='Outfits')
    store.shop.categories:focusChild(category)
    later(700,function()
     assert(store.shop.offers:getChildCount()==2)
     for i,look in ipairs({373,374})do
      local offer=store.shop.offers:getChildById('offer_3_'..i)
      assert(offer and offer.offerId==6000+i)
      assert(offer.creature:getOutfit().type==look)
      assert(offer.title:getText():find('250 points',1,true))
     end
     g_app.doScreenshot('/acolyte-shop.png')
     later(500,function()
      print('ACOLYTE_VISUAL_OK actualConnection=true malePlayer=374 femaleNPC=373 sourceFramesNative=true shopOffers=2')
      finished=true;g_game.safeLogout();scheduleEvent(function()g_app.exit()end,700)
     end)
    end)
   end)
  end)
 end)
end
later(300,function()
 assert(LOCAL_PASSIVES_TEST and Services.updater=='' and g_resources.getLayout()=='retro')
 connect(g_game,{
  onLoginError=fail,onConnectionError=function(e)if not finished then fail(e)end end,
  onGameStart=function()
   EnterGame.hide()
   later(1600,function()
    closeDialogs();g_window.resize({width=1280,height=800})
    g_game.getProtocolGame():sendExtendedOpcode(201,json.encode({action='buy',data={category=3,offer=2}}))
    later(900,function()
     closeDialogs();g_game.changeOutfit({type=374,head=58,body=49,legs=2,feet=58,addons=3})
     wait('male outfit applied',function()return g_game.getLocalPlayer():getOutfit().type==374 end,function()
      later(800,photograph)
     end)
    end)
   end)
  end,
 })
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 G.account,G.password='acolyteqa','AcolyteLoopbackOnly'
 g_game.loginWorld(G.account,G.password,'Local Acolyte QA','127.0.0.1',7186,'Passive Tester','','')
end)
scheduleEvent(function()if not finished then fail('overall timeout')end end,45000)

