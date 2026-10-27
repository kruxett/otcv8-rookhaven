local failed,finished=false,false
local root,previewPanel
local variants={{373,'Rune Master - Female'},{374,'Rune Master - Male'},{375,'Lion of War - Female'},{376,'Lion of War - Male'}}
local function fail(why)
 if failed then return end;failed=true;print('MODERN_VISUAL_FAILED '..tostring(why))
 if g_game.isOnline()then g_game.safeLogout()end
 scheduleEvent(function()g_app.exit()end,500)
end
local function later(ms,fn)scheduleEvent(function()if failed or finished then return end;local ok,e=pcall(fn);if not ok then fail(e)end end,ms)end
local function wait(label,predicate,nextStep)
 local deadline=g_clock.millis()+14000
 local function poll()
  if predicate()then later(100,nextStep);return end
  assert(g_clock.millis()<deadline,label..' timed out');later(100,poll)
 end
 later(100,poll)
end
local function closeDialogs()
 for _,widget in ipairs(g_ui.getRootWidget():getChildren())do
  if widget:getClassName()=='UIMessageBox'then widget:destroy()end
 end
 local choice=modules.game_passives and modules.game_passives.getClassChoice and modules.game_passives.getClassChoice()
 local dialog=choice and choice.getWindow()
 if dialog and dialog:isVisible()then local b=dialog:recursiveGetChildById('cancelButton');if b then signalcall(b.onClick,b)end end
end
local function outfit(look,addons)
 return {type=look,head=58,body=49,legs=2,feet=58,addons=addons}
end
local function finishShop()
 if previewPanel then previewPanel:destroy()end
 local store=modules.game_shop;store.show();assert(store.shop:isVisible())
 local category=store.shop.categories:getChildById('category_3');assert(category and category.name:getText()=='Outfits')
 store.shop.categories:focusChild(category)
 later(600,function()
  assert(store.shop.offers:getChildCount()==4)
  for i,v in ipairs(variants)do
   local offer=store.shop.offers:getChildById('offer_3_'..i)
   assert(offer and offer.offerId==6000+i and offer.creature:getOutfit().type==v[1])
   assert(offer.title:getText():find('250 points',1,true))
  end
  g_app.doScreenshot('/modern-outfits-shop.png')
  later(500,function()
   print('MODERN_VISUAL_OK actualConnection=true purchasedAndEquipped=2 sourceVariantsNative=4 shopOffers=4 actualWalking=true')
   finished=true;g_game.safeLogout();scheduleEvent(function()g_app.exit()end,700)
  end)
 end)
end
local function board(addonStages,nextStep)
 if previewPanel then previewPanel:destroy()end
 previewPanel=g_ui.createWidget('UIWidget',root)
 previewPanel:setRect({x=70,y=60,width=1050,height=790});previewPanel:setBackgroundColor('#24272b');previewPanel:raise()
 local title=g_ui.createWidget('UILabel',previewPanel);title:setRect({x=85,y=70,width=1000,height=24})
 title:setText(addonStages and 'Original imported outfits - base / addon 1 / addon 2 / both' or 'Original imported outfits - all four directions, both addons')
 for row,v in ipairs(variants)do
  local y=105+(row-1)*184
  local label=g_ui.createWidget('UILabel',previewPanel);label:setRect({x=85,y=y,width=1000,height=22});label:setText(v[2])
  for column=0,3 do
   local x=85+column*252
   local caption=g_ui.createWidget('UILabel',previewPanel);caption:setRect({x=x,y=y+23,width=235,height=18})
   caption:setText((addonStages and {'Base','Addon 1','Addon 2','Both'} or {'North','East','South','West'})[column+1])
   local view=g_ui.createWidget('UICreature',previewPanel);view:setRect({x=x+15,y=y+42,width=200,height=136})
   view:setOutfit(outfit(v[1],addonStages and column or 3));view:setDirection(addonStages and 2 or column)
   view:setAnimate(false);assert(view:getOutfit().type==v[1])
  end
 end
 later(600,function()
  g_app.doScreenshot(addonStages and '/modern-outfits-addon-stages.png' or '/modern-outfits-directions.png')
  later(400,nextStep)
 end)
end
local function walkThenPhotograph()
 closeDialogs();local p=g_game.getLocalPlayer();assert(p:getOutfit().type==374)
 g_app.doScreenshot('/modern-outfits-world.png')
 local start=p:getPosition();local direction,returnDirection
 for dir,offset in ipairs({{0,-1},{1,0},{0,1},{-1,0}})do
  local tile=g_map.getTile({x=start.x+offset[1],y=start.y+offset[2],z=start.z})
  if tile and tile:isWalkable() and not tile:getTopCreature()then direction=dir-1;returnDirection=(direction+2)%4;break end
 end
 assert(direction,'No free adjacent walk tile')
 g_game.walk(direction)
 for i=1,8 do later(45+(i-1)*65,function()g_app.doScreenshot('/modern-outfit-walk-'..i..'.png')end)end
 later(650,function()
  local now=p:getPosition();assert(now.x~=start.x or now.y~=start.y,'Real walking did not move the player')
  g_game.walk(returnDirection)
  later(700,function()
   local back=p:getPosition();assert(back.x==start.x and back.y==start.y,'Walking did not return to start')
   g_game.changeOutfit(outfit(376,3))
   wait('Lion of War equipped',function()return p:getOutfit().type==376 end,function()
    g_app.doScreenshot('/modern-outfits-lion-equipped.png')
    later(400,function()board(false,function()board(true,finishShop)end)end)
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
   later(1500,function()
    closeDialogs();root=g_ui.getRootWidget();g_window.resize({width=1280,height=960})
    local protocol=g_game.getProtocolGame()
    protocol:sendExtendedOpcode(201,json.encode({action='buy',data={category=3,offer=2}}))
    later(500,function()
     closeDialogs();protocol:sendExtendedOpcode(201,json.encode({action='buy',data={category=3,offer=4}}))
     later(500,function()
      closeDialogs();g_game.changeOutfit(outfit(374,3))
      wait('Rune Master equipped',function()return g_game.getLocalPlayer():getOutfit().type==374 end,function()later(600,walkThenPhotograph)end)
     end)
    end)
   end)
  end,
 })
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 G.account,G.password='modernoutfitqa','ModernOutfitLoopbackOnly'
 g_game.loginWorld(G.account,G.password,'Local Modern Outfit QA','127.0.0.1',7186,'Passive Tester','','')
end)
scheduleEvent(function()if not finished then fail('overall timeout')end end,45000)
