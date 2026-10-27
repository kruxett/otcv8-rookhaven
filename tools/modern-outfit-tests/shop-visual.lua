-- Exercise the real shop/outfit window and temporary renderer regression probes.
local failed,finished=false,false
local checks=0
local player,store,initialOutfit,profileBefore,profileExisted
local changeCalls=0
local originalChange
local capture={shop={},regression={}}
local function check(ok,why)assert(ok,why);checks=checks+1 end
local function fail(why)
 if failed then return end;failed=true;print('SHOP_NATIVE_FAILED '..tostring(why))
 if originalChange then g_game.changeOutfit=originalChange end
 if g_game.isOnline()then g_game.safeLogout()end
 scheduleEvent(function()g_app.exit()end,400)
end
local function later(ms,fn)scheduleEvent(function()
 if failed or finished then return end
 local ok,e=pcall(fn);if not ok then fail(e)end
end,ms)end
local function wait(label,predicate,nextStep)
 local deadline=g_clock.millis()+18000
 local function poll()
  if predicate()then later(80,nextStep);return end
  assert(g_clock.millis()<deadline,label..' timed out');later(80,poll)
 end
 later(80,poll)
end
local function click(widget)check(widget~=nil,'Missing native control');signalcall(widget.onClick,widget)end
local function closeDialogs()
 for _,w in ipairs(g_ui.getRootWidget():getChildren())do if w:getClassName()=='UIMessageBox'then w:destroy()end end
 local choice=modules.game_passives and modules.game_passives.getClassChoice and modules.game_passives.getClassChoice()
 local dialog=choice and choice.getWindow()
 if dialog and dialog:isVisible()then local b=dialog:recursiveGetChildById('cancelButton');if b then signalcall(b.onClick,b)end end
end
local function appearance(o)
 return table.concat({o.type or 0,o.addons or 0,o.head or 0,o.body or 0,o.legs or 0,o.feet or 0},':')
end
local function points()return tonumber(store.shop.infoPanel.points:getText():match('(%d+)$'))end
local function category(index,count,nextStep)
 store.shop.categories:focusChild(store.shop.categories:getChildById('category_'..index))
 later(180,function()check(store.shop.offers:getChildCount()==count,'Category rows changed');nextStep()end)
end
local function noTrialSideEffects()
 check(changeCalls==0 and appearance(player:getOutfit())==initialOutfit,'Try On changed or sent the equipped outfit')
 check(points()==1000,'Try On charged points')
 check(g_resources.fileExists('/settings/outfit.json')==profileExisted,'Try On created profile settings')
 if profileExisted then check(g_resources.readFileContents('/settings/outfit.json')==profileBefore,'Try On saved over outfit preferences')end
end
local function layoutChecks()
 check(store.shop.offers:getChildCount()==4,'Expected four real outfit offers')
 for i=1,4 do
  local row=store.shop.offers:getChildById('offer_3_'..i)
  check(row and row.offerId==6000+i and row.creature:getOutfit().type==372+i,'Offer mapping changed')
  check(row.creature:isAnimating() and row.creature:isFixedCreatureSize(),'Native preview not animated at fixed scale')
  local r,t,b,d=row.creature:getRect(),row.title:getRect(),row.buyButton:getRect(),row.description:getRect()
  check(r.width==64 and r.height==64 and r.x+r.width<=t.x and t.x+t.width<=b.x,'Preview/text/buttons overlap')
  check(d.x+d.width<=b.x and d.y+d.height<=row:getY()+row:getHeight(),'Description overflows row')
  local ids={}
  for _,child in ipairs(row:getChildren())do local id=child:getId();check(not ids[id],'Duplicate inherited row child '..id);ids[id]=true end
 end
 check(store.shop.adPanel:getHeight()==0,'Implementation banner remains visible')
end
local function sample(prefix,widgets,count,delay,nextStep)
 local rows={}
 for _,w in ipairs(widgets)do rows[#rows+1]={look=w:getOutfit().type,rect=w:getRect()}end
 capture[prefix]={widgets=rows,frames=count,delay=delay}
 local i=0
 local function frame()
  i=i+1;g_app.doScreenshot('/shop-native-'..prefix..'-'..i..'.png')
  if i<count then later(delay,frame)else later(250,nextStep)end
 end
 later(200,frame)
end
local function finalRegressions()
 store.hide()
 local root=g_ui.getRootWidget();local panel=g_ui.createWidget('UIWidget',root)
 panel:setRect({x=200,y=150,width=650,height=100});panel:setBackgroundColor('#606060')
 local widgets={}
 for index,look in ipairs({126,128,10,17,26})do
  local view=g_ui.createWidget('UICreature',panel)
  view:setRect({x=215+(index-1)*125,y=165,width=64,height=64});view:setOutfit({type=look,head=58,body=49,legs=2,feet=58,addons=3})
  view:setAnimate(true);view:setFixedCreatureSize(true);view:setDirection(2);widgets[#widgets+1]=view
 end
 sample('regression',widgets,36,105,function()
  panel:destroy();store.show()
  category(3,4,function()
   g_app.doScreenshot('/shop-native-final.png')
   -- Screenshots are encoded by the asynchronous dispatcher. Keep the client
   -- alive until every requested PNG has its final IEND chunk.
   wait('native screenshot writers',function()
    local files={'/shop-native-final.png','/shop-native-tryon.png'}
    for _,prefix in ipairs({'cycle','shop','regression'})do
     for i=1,capture[prefix].frames do files[#files+1]='/shop-native-'..prefix..'-'..i..'.png'end
    end
    for _,file in ipairs(files)do
     if not g_resources.fileExists(file)then return false end
     if g_resources.readFileContents(file):sub(-8,-5)~='IEND'then return false end
    end
    return true
   end,function()
    print('SHOP_CAPTURE '..json.encode(capture))
    print('SHOP_NATIVE_OK checks='..checks..' currentClient=true sourceModules=true nativeAnimation=true tryOnReadOnly=true existingPurchases=true')
    finished=true;g_game.safeLogout();scheduleEvent(function()g_app.exit()end,700)
   end)
  end)
 end)
end
local function buyRow(index,expected,nextStep)
 click(store.shop.offers:getChildByIndex(index).buyButton)
 later(120,function()
  store.buyConfirmed()
  wait('purchase balance '..expected,function()return points()==expected end,function()closeDialogs();nextStep()end)
 end)
end
local function purchaseRegressions()
 category(2,7,function()
  local row=store.shop.offers:getChildById('offer_2_1')
  check(row.item~=nil and row:getHeight()==56,'Existing item row style changed')
  click(row.buyButton)
  later(120,function()
   store.buyCanceled();check(points()==1000,'Cancelled purchase charged')
   buyRow(1,850,function()
    buyRow(7,600,function()
     category(3,4,function()
      click(store.shop.offers:getChildByIndex(1).buyButton)
      later(120,function()
       store.buyConfirmed()
       later(600,function()
        check(points()==600,'Wrong-sex purchase charged');closeDialogs()
        buyRow(2,350,function()
         click(store.shop.offers:getChildByIndex(2).buyButton)
         later(120,function()
          store.buyConfirmed()
          later(600,function()
           check(points()==350,'Duplicate outfit charged');closeDialogs()
           store.showHistory(true)
           wait('purchase history',function()return store.shop.offers:getChildCount()==3 end,function()
            local outfitRows=0
            for _,entry in ipairs(store.shop.offers:getChildren())do
             check(not entry.buyButton:isVisible(),'History has a buy button')
             if entry.creature then outfitRows=outfitRows+1;check(entry.creature:isAnimating(),'History outfit is static')end
            end
            check(outfitRows==1,'Outfit history missing');finalRegressions()
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
local function trials()
 local module=modules.game_outfit
 click(store.shop.offers:getChildByIndex(1).tryOnButton)
 later(250,function()
  local w=module.getPreviewWindow();check(w and not store.shop:isVisible(),'Try On did not open native outfit window')
  local view=w.preview.panel.creature
  check(view:getOutfit().type==373 and view:isAnimating(),'Wrong or static trial')
  w.configure.addon1.check:setChecked(false);check(view:getOutfit().addons==2,'Addon 1 trial toggle failed')
  w.configure.addon2.check:setChecked(false);check(view:getOutfit().addons==0,'Base trial toggle failed')
  w.configure.addon1.check:setChecked(true);check(view:getOutfit().addons==1,'Addon 1 alone failed')
  w.configure.addon2.check:setChecked(true);check(view:getOutfit().addons==3,'Both trial addons failed')
  click(w.appearance.colorMode.primary);click(w.appearance.colorBoxPanel.colorBox22)
  check(view:getOutfit().body==22,'Native colour selection failed')
  local before=view:getDirection();module.rotate(1);check(view:getDirection()==(before+1)%4,'Native direction rotation failed')
  w.preview.panel.movement:setChecked(false);check(not view:isAnimating(),'Movement toggle failed')
  w.preview.panel.movement:setChecked(true);check(view:isAnimating(),'Movement resume failed')
  g_app.doScreenshot('/shop-native-tryon.png')
  noTrialSideEffects();module.accept()
  later(200,function()
   check(not module.getPreviewWindow() and store.shop:isVisible(),'Preview accept did not return to shop')
   noTrialSideEffects()
   click(store.shop.offers:getChildByIndex(4).tryOnButton)
   later(150,function()
    check(module.getPreviewWindow().preview.panel.creature:getOutfit().type==376,'Second trial wrong outfit')
    module.destroy()
    later(150,function()
     noTrialSideEffects();check(store.shop:isVisible(),'Repeated trial lost shop')
     g_game.changeOutfit=originalChange;originalChange=nil
     purchaseRegressions()
    end)
   end)
  end)
 end)
end
local function begin()
 closeDialogs();player=g_game.getLocalPlayer();store=modules.game_shop
 initialOutfit=appearance(player:getOutfit());profileExisted=g_resources.fileExists('/settings/outfit.json')
 if profileExisted then profileBefore=g_resources.readFileContents('/settings/outfit.json')end
 originalChange=g_game.changeOutfit
 g_game.changeOutfit=function(...)changeCalls=changeCalls+1;return originalChange(...)end
 store.show()
 category(1,3,function()category(2,7,function()category(3,4,function()
  layoutChecks();store.hide();store.show();layoutChecks()
  capture.window=store.shop:getRect()
  local views={}
  for _,entry in ipairs(store.shop.offers:getChildren())do entry.creature:setAutoRotating(false);entry.creature:setDirection(2);views[#views+1]=entry.creature end
  sample('cycle',views,24,90,function()
   for _,view in ipairs(views)do view:setAutoRotating(true)end
   sample('shop',views,36,115,trials)
  end)
 end)end)end)
end
later(300,function()
 check(LOCAL_PASSIVES_TEST and Services.updater=='' and g_resources.getLayout()=='retro','Expected isolated retro QA client')
 connect(g_game,{onLoginError=fail,onConnectionError=function(e)if not finished then fail(e)end end,
  onGameStart=function()EnterGame.hide();later(1600,function()g_window.resize({width=1280,height=800});later(300,begin)end)end})
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 G.account,G.password='modernoutfitqa','ModernOutfitLoopbackOnly'
 g_game.loginWorld(G.account,G.password,'Local Shop QA','127.0.0.1',7186,'Passive Tester','','')
end)
scheduleEvent(function()if not finished then fail('overall timeout')end end,90000)
