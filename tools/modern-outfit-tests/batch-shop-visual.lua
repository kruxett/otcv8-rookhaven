-- The real shop and existing native Try On window; no temporary preview board.
local failed,finished=false,false
local store,player,initialOutfit,profileBefore,profileExisted,originalChange
local checks,changeCalls=0,0
local families={'Rune Master','Lion of War','Afflicted','Arbalester','Arena Champion','Armoured Archer',
 'Discoverer','Entrepreneur','Formal Dress','Golden','Nordic Chieftain','Poltergeist','Veteran Paladin'}
local capture={cycles={},directions={},files={}}
local function check(ok,why)assert(ok,why);checks=checks+1 end
local function fail(why)
 if failed then return end;failed=true;print('BATCH_SHOP_NATIVE_FAILED '..tostring(why))
 if originalChange then g_game.changeOutfit=originalChange end
 if g_game.isOnline()then g_game.safeLogout()end
 scheduleEvent(function()g_app.exit()end,400)
end
local function later(ms,fn)scheduleEvent(function()
 if failed or finished then return end
 local ok,e=pcall(fn);if not ok then fail(e)end
end,ms)end
local function wait(label,predicate,nextStep)
 local deadline=g_clock.millis()+25000
 local function poll()
  if predicate()then later(80,nextStep);return end
  assert(g_clock.millis()<deadline,label..' timed out');later(80,poll)
 end
 later(80,poll)
end
local function click(widget)check(widget~=nil,'Missing native control');signalcall(widget.onClick,widget)end
local function shot(name)
 local file='/shop-batch-'..name..'.png';capture.files[#capture.files+1]=file;g_app.doScreenshot(file)
 return file
end
local function closeDialogs()
 for _,w in ipairs(g_ui.getRootWidget():getChildren())do if w:getClassName()=='UIMessageBox'then w:destroy()end end
 local choice=modules.game_passives and modules.game_passives.getClassChoice and modules.game_passives.getClassChoice()
 local dialog=choice and choice.getWindow()
 if dialog and dialog:isVisible()then local b=dialog:recursiveGetChildById('cancelButton');if b then signalcall(b.onClick,b)end end
end
local function appearance(o)return table.concat({o.type or 0,o.addons or 0,o.head or 0,o.body or 0,o.legs or 0,o.feet or 0},':')end
local function points()return tonumber(store.shop.infoPanel.points:getText():match('(%d+)$'))end
local function category(index,count,nextStep)
 store.shop.categories:focusChild(store.shop.categories:getChildById('category_'..index))
 later(180,function()check(store.shop.offers:getChildCount()==count,'Category rows changed');nextStep()end)
end
local function within(widget)
 local r=widget:getRect();local a=store.shop.offers:getPaddingRect()
 return r.x>=a.x and r.y>=a.y and r.x+r.width<=a.x+a.width and r.y+r.height<=a.y+a.height
end
local function noTrialSideEffects()
 check(changeCalls==0 and appearance(player:getOutfit())==initialOutfit,'Try On changed/sent equipped outfit')
 check(points()==1000,'Try On charged points')
 check(g_resources.fileExists('/settings/outfit.json')==profileExisted,'Try On created settings')
 if profileExisted then check(g_resources.readFileContents('/settings/outfit.json')==profileBefore,'Try On changed preferences')end
end
local function layoutChecks()
 check(store.shop.offers:getChildCount()==26,'Expected all 26 outfit rows')
 for index=1,26 do
  local row=store.shop.offers:getChildById('offer_3_'..index)
  check(row and row.offerId==6000+index and row.creature:getOutfit().type==372+index,'Offer mapping changed')
  check(row.creature:isAnimating() and row.creature:isFixedCreatureSize() and row:getHeight()==88,'Outfit preview style changed')
  check(row.creature:getCreature():getAnimationPhases()==9,'Full standing/eight-frame walking data missing')
  local r,t,b,d=row.creature:getRect(),row.title:getRect(),row.buyButton:getRect(),row.description:getRect()
  check(r.width==64 and r.height==64 and r.x+r.width<=t.x and t.x+t.width<=b.x,'Preview/title/button overlap')
  check(d.x+d.width<=b.x and d.y+d.height<=row:getY()+row:getHeight(),'Description overflow')
 end
 check(store.shop.adPanel:getHeight()==0,'Implementation banner shown')
end
local function samplePair(index,nextStep)
 if index>#families then nextStep();return end
 local first=store.shop.offers:getChildByIndex(index*2-1);local last=store.shop.offers:getChildByIndex(index*2)
 store.shop.offers:ensureChildVisible(last)
 later(150,function()
  check(within(first.creature) and within(last.creature) and within(last.buyButton) and within(last.tryOnButton),'Family pair not visibly scrollable: '..families[index])
  if index==3 then shot('first-new-afflicted')elseif index==8 then shot('middle-entrepreneur')elseif index==13 then
   check(store.shop.offersScrollBar:getValue()==store.shop.offersScrollBar:getMaximum(),'Scrollbar did not reach bottom')
   shot('bottom-veteran-paladin')
  end
  local group={family=families[index],widgets={},frames=16,delay=90}
  for _,row in ipairs({first,last})do
   row.creature:setAutoRotating(false);row.creature:setDirection(2)
   group.widgets[#group.widgets+1]={look=row.creature:getOutfit().type,rect=row.creature:getRect()}
  end
  capture.cycles[#capture.cycles+1]=group
  local frame=0
  local function nextFrame()
   frame=frame+1;shot('cycle-'..index..'-'..frame)
   if frame<group.frames then later(group.delay,nextFrame)else
    for _,row in ipairs({first,last})do row.creature:setAutoRotating(true)end
    later(120,function()samplePair(index+1,nextStep)end)
   end
  end
  nextFrame()
 end)
end
local function finish()
 store.show();category(3,26,function()
  local last=store.shop.offers:getChildByIndex(26);store.shop.offers:ensureChildVisible(last)
  later(180,function()
   check(within(last.buyButton) and within(last.tryOnButton),'Bottom controls inaccessible after reopening')
   shot('final-bottom')
   wait('native PNG writers',function()
    for _,file in ipairs(capture.files)do
     if not g_resources.fileExists(file)or g_resources.readFileContents(file):sub(-8,-5)~='IEND'then return false end
    end
    return true
   end,function()
    print('BATCH_SHOP_CAPTURE '..json.encode(capture))
    print('BATCH_SHOP_NATIVE_OK checks='..checks..' newVariants=22 totalVariants=26 nativeAnimation=true allTryOnsReadOnly=true bottomAccessible=true existingPurchases=true')
    finished=true;g_game.safeLogout();scheduleEvent(function()g_app.exit()end,700)
   end)
  end)
 end)
end
local function buyVisible(row,expected,nextStep)
 store.shop.offers:ensureChildVisible(row)
 later(100,function()
  check(within(row.buyButton),'Purchase control not visible')
  click(row.buyButton);later(100,function()
   store.buyConfirmed();wait('points '..expected,function()return points()==expected end,function()closeDialogs();nextStep()end)
  end)
 end)
end
local function purchases()
 g_game.changeOutfit=originalChange;originalChange=nil
 category(2,7,function()
  local quiver=store.shop.offers:getChildByIndex(1)
  check(quiver.item and quiver:getHeight()==56,'Existing item row changed')
  click(quiver.buyButton);later(120,function()
   store.buyCanceled();check(points()==1000,'Cancelled purchase charged')
   buyVisible(quiver,850,function()
    buyVisible(store.shop.offers:getChildByIndex(7),600,function()
     category(3,26,function()
      local wrong=store.shop.offers:getChildByIndex(25);store.shop.offers:ensureChildVisible(wrong)
      later(100,function()
       check(within(wrong.buyButton),'Wrong-sex bottom control not visible');click(wrong.buyButton)
       later(100,function()
        store.buyConfirmed();later(600,function()
         check(points()==600,'Wrong-sex purchase charged');closeDialogs()
         local last=store.shop.offers:getChildByIndex(26)
         buyVisible(last,350,function()
          click(last.buyButton);later(100,function()
           store.buyConfirmed();later(600,function()
            check(points()==350,'Duplicate bottom outfit charged');closeDialogs();store.showHistory(true)
            wait('purchase history',function()return store.shop.offers:getChildCount()==3 end,function()
             local outfitRows=0
             for _,row in ipairs(store.shop.offers:getChildren())do
              check(not row.buyButton:isVisible(),'History contains BUY button')
              if row.creature then outfitRows=outfitRows+1;check(row.creature:isAnimating(),'History outfit is static')end
             end
             check(outfitRows==1,'Purchased bottom outfit missing in history');finish()
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
local function trials(index)
 if index>26 then purchases();return end
 local row=store.shop.offers:getChildByIndex(index);store.shop.offers:ensureChildVisible(row)
 later(100,function()
  check(within(row.tryOnButton),'Try On control not visibly reachable: '..index)
  click(row.tryOnButton);later(150,function()
   local module=modules.game_outfit;local w=module.getPreviewWindow()
   check(w and not store.shop:isVisible(),'Try On did not open native dialog')
   local view=w.preview.panel.creature
   check(view:getOutfit().type==372+index and view:isAnimating(),'Wrong/static Try On')
   w.configure.addon1.check:setChecked(false);check(view:getOutfit().addons==2,'Addon 2 alone failed')
   w.configure.addon2.check:setChecked(false);check(view:getOutfit().addons==0,'Base only failed')
   w.configure.addon1.check:setChecked(true);check(view:getOutfit().addons==1,'Addon 1 alone failed')
   w.configure.addon2.check:setChecked(true);check(view:getOutfit().addons==3,'Both addons failed')
   click(w.appearance.colorMode.primary);click(w.appearance.colorBoxPanel.colorBox22)
   check(view:getOutfit().body==22,'Colour selection failed')
   w.preview.panel.movement:setChecked(false);check(not view:isAnimating(),'Movement pause failed')
   w.preview.panel.movement:setChecked(true);check(view:isAnimating(),'Movement resume failed')
   local direction=0
   local function nextDirection()
    view:setDirection(direction);check(view:getDirection()==direction,'Native direction failed')
    later(80,function()
     local file=shot('tryon-'..index..'-direction-'..direction)
     capture.directions[#capture.directions+1]={look=372+index,direction=direction,file=file,rect=view:getRect()}
     direction=direction+1
     if direction<4 then nextDirection()else
      noTrialSideEffects()
      if index%2==0 then module.accept()else module.destroy()end
      later(100,function()
       check(not module.getPreviewWindow() and store.shop:isVisible(),'Closing trial lost shop')
       noTrialSideEffects();trials(index+1)
      end)
     end
    end)
   end
   nextDirection()
  end)
 end)
end
local function begin()
 closeDialogs();player=g_game.getLocalPlayer();store=modules.game_shop
 initialOutfit=appearance(player:getOutfit());profileExisted=g_resources.fileExists('/settings/outfit.json')
 if profileExisted then profileBefore=g_resources.readFileContents('/settings/outfit.json')end
 originalChange=g_game.changeOutfit;g_game.changeOutfit=function(...)changeCalls=changeCalls+1;return originalChange(...)end
 store.show()
 category(1,3,function()category(2,7,function()category(3,26,function()
  layoutChecks();store.hide();store.show();layoutChecks();capture.window=store.shop:getRect()
  samplePair(1,function()trials(1)end)
 end)end)end)
end
later(300,function()
 check(LOCAL_PASSIVES_TEST and Services.updater=='' and g_resources.getLayout()=='retro','Expected isolated retro QA client')
 connect(g_game,{onLoginError=fail,onConnectionError=function(e)if not finished then fail(e)end end,
  onGameStart=function()EnterGame.hide();later(1600,function()g_window.resize({width=1280,height=800});later(300,begin)end)end})
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 G.account,G.password='modernoutfitqa','ModernOutfitLoopbackOnly'
 g_game.loginWorld(G.account,G.password,'Local Batch Shop QA','127.0.0.1',7186,'Passive Tester','','')
end)
scheduleEvent(function()if not finished then fail('overall timeout')end end,170000)
