-- Actual legacy8.60 client + owned loopback native engine. No live registration.
-- Run through run-passives-probe.ps1 -Script quiver-native.lua
-- -Success QUIVER_NATIVE_CLIENT_OK -TimeoutSeconds330, with /quiverqa installed.
local failed,finished,reconnecting=false,false,false
local sid=QUIVER_PROBE_SID or 12830
local name='Passive Tester'
local receipts,receiptSequence={},{}
local mod,login,player
local evidence={sid=sid}
local phase='initial'
local onReconnect
local autoProbe
local doLogin
local function fail(reason)
 if failed or finished then return end;failed=true
 print('QUIVER_NATIVE_CLIENT_FAILED phase='..phase..' '..tostring(reason))
 if g_game.isOnline()then
  g_game.cancelAttack()
  if phase=='shop'then g_game.talk('/quiverqa shoprestore')else g_game.talk('/quiverqa restore')end
  scheduleEvent(function()g_game.safeLogout()end,700)
 end
 scheduleEvent(function()g_app.exit()end,1600)
end
local function later(ms,fn)
 scheduleEvent(function()if failed or finished then return end;local ok,e=pcall(fn);if not ok then fail(e)end end,ms)
end
local function wait(label,predicate,fn,timeout)
 local deadline=g_clock.millis()+(timeout or 12000)
 local function poll()
  if predicate()then later(80,fn);return end
  assert(g_clock.millis()<deadline,label..' timeout');later(100,poll)
 end
 later(1,poll)
end
local function command(words,label,fn,timeout)
 local before=receiptSequence[label]or 0
 g_game.talk(words)
 wait(label,function()return(receiptSequence[label]or 0)>before end,function()fn(receipts[label])end,timeout)
end
local function commands(list,fn)
 local function nextCommand(i)
  if i>#list then later(400,fn);return end
  g_game.talk(list[i]);later(200,function()nextCommand(i+1)end)
 end
 nextCommand(1)
end
local function measure(fn)
 command('/quiverqa metrics','METRICS',fn)
end
local function click(widget)
 assert(widget and widget:isVisible(),'Actual native action is not visible')
 signalcall(widget.onClick,widget)
end
local function rootMessage(title)
 for _,widget in ipairs(g_ui.getRootWidget():getChildren())do
  if widget:getText()==title and widget:isVisible()then return widget end
 end
end
local function messageButton(box,text)
 local holder=assert(box:getChildById('buttonHolder'),'Actual message buttons missing')
 for _,button in ipairs(holder:getChildren())do if button:getText()==text then return button end end
end
local function closeInfoBox()
 local box=rootMessage('Successful shop purchase')
 if box then click(assert(messageButton(box,'Ok'),'Shop success close action missing'))end
end
local function inside(widget,parent)
 local a,b=widget:getRect(),parent:getRect()
 return a.x>=b.x and a.y>=b.y and a.x+a.width<=b.x+b.width and a.y+a.height<=b.y+b.height
end
local function findOpenQuiver(cid)
 for _,container in pairs(g_game.getContainers())do
  local item=container:getContainerItem()
  if item and item:getId()==cid then return container end
 end
end
local function screenshotEquipment(data,fn)
 local item=assert(player:getInventoryItem(InventorySlotAmmo),'Quiver not in actual ammo slot')
 assert(item:getId()==data.clientId and item:isContainer(),'Actual client DAT/OTB quiver mapping/type missing')
 evidence.clientId=data.clientId
 local choice=mod.getClassChoice()
 local choiceWindow=choice and choice.getWindow()
 if choiceWindow and choiceWindow:isVisible()then
  click(assert(choiceWindow:recursiveGetChildById('cancelButton'),'Class dialog close action missing'))
 end
 if modules.game_inventory.inventoryWindow and not modules.game_inventory.inventoryWindow:isVisible()then modules.game_inventory.toggle()end
 g_game.open(item)
 wait('actual quiver container',function()return findOpenQuiver(data.clientId)~=nil end,function()
  local container=assert(findOpenQuiver(data.clientId))
  assert(container:getCapacity()==20 and container:getItemsCount()==3,'Actual20-slot quiver content grid disagrees with server')
  g_window.resize({width=1280,height=800})
  later(300,function()
   assert(container.window and container.window:isVisible(),'Native container window not rendered')
   g_app.doScreenshot('/quiver-native-equipped-1280x800.png')
   g_window.resize({width=800,height=640})
   later(300,function()
    assert(inside(container.window,g_ui.getRootWidget()),'Quiver container clipped at supported800x640')
    g_app.doScreenshot('/quiver-native-equipped-800x640.png')
    print('QUIVER_NATIVE_CLIENT_GRAPHICS_OK clientId='..data.clientId..' capacity20 sizes1280x800,800x640')
    g_window.resize({width=1280,height=800});later(200,fn)
   end)
  end)
 end)
end
local function healthDamage(before,after)
 local total,changed=0,0
 assert(#before.targetHP==#after.targetHP,'Owned target count changed')
 for i,hp in ipairs(before.targetHP)do
  assert(after.targetHP[i]<=hp,'Fixture target healed unexpectedly')
  local delta=hp-after.targetHP[i];total=total+delta;if delta>0 then changed=changed+1 end
 end
 return total,changed
end
local function ordinaryRoundBaseline(fn)
 local deadline=g_clock.millis()+12000
 local function inspect()
  measure(function(before)
   if before.arrows==10 then
    assert(g_clock.millis()<deadline,'First ordinary shot was not observed')
    later(150,inspect);return
   end
   assert(before.arrows==9,'Unexpected automatic-shot baseline before Sure Shot')
   fn(before)
  end)
 end
 inspect()
end
local function cleanLogout()
 phase='finish';finished=true;g_game.cancelAttack();g_game.safeLogout()
 scheduleEvent(function()
  if g_game.isOnline()then finished=false;fail('Final normal logout failed');return end
  print('QUIVER_NATIVE_CLIENT_OK '..json.encode(evidence))
  print('QUIVER_NATIVE_CLIENT_SCREENSHOT_DIRECTORY '..g_resources.getWriteDir())
  g_app.exit()
 end,900)
end
local function shopProbe()
 phase='shop'
 command('/quiverqa shopbegin '..sid,'SHOP_READY',function(initial)
  assert(initial.points==1000 and initial.cost==150 and initial.offer==4001,'Unexpected shop fixture economics')
  local shopModule=assert(modules.game_shop)
  shopModule.check();shopModule.show()
  wait('real Utility category',function()
   local ui=shopModule.shop
   if not ui or not ui:isVisible()then return false end
   for _,row in ipairs(ui.categories:getChildren())do
    local label=row:getChildById('name');if label and label:getText()=='Utility'then return true end
   end
  end,function()
   local ui=shopModule.shop;local utility
   for _,row in ipairs(ui.categories:getChildren())do local label=row:getChildById('name');if label and label:getText()=='Utility'then utility=row;break end end
   ui.categories:focusChild(assert(utility))
   wait('actual Magic Quiver offer',function()
    for _,row in ipairs(ui.offers:getChildren())do if row.offerId==4001 then return true end end
   end,function()
    local offer
    for _,row in ipairs(ui.offers:getChildren())do if row.offerId==4001 then offer=row;break end end
    assert(offer.item:getItemId()==initial.clientId and initial.clientId==11867,'Actual shop icon CID differs from Magic Quiver mapping')
    assert(offer.title:getText()=='Magic Quiver (150 points)','Shop title/price presentation missing')
    assert(offer.description:getText():find('20 ammo stacks',1,true),'Shop description does not explain capacity')
    later(300,function()
     g_app.doScreenshot('/quiver-native-shop-offer.png')
     click(offer.buyButton)
     wait('actual shop confirmation',function()return rootMessage('Buying from shop')~=nil end,function()
      local box=assert(rootMessage('Buying from shop'))
      g_app.doScreenshot('/quiver-native-shop-confirmation.png')
      click(assert(messageButton(box,'Yes'),'Actual buyConfirmed Yes action missing'))
      wait('successful native shop purchase',function()return rootMessage('Successful shop purchase')~=nil end,function()
       command('/quiverqa shopstatus','SHOP_OK',function(receipt)
        assert(receipt.points==850 and receipt.spent==150 and receipt.offer==4001,'Actual shop payment/history failed')
        assert(receipt.afterCount==receipt.beforeCount+1 and receipt.purchasedUid>=65000,'Actual shop grant identity missing')
        evidence.shop=receipt
        g_app.doScreenshot('/quiver-native-shop-purchased.png');closeInfoBox();shopModule.hide()
        command('/quiverqa shoprestore','SHOP_RESTORED',function(restored)
         assert(restored.restored and restored.historyRestored and restored.removedUid==receipt.purchasedUid,'Shop state/granted item restoration failed')
         evidence.shopRestored=restored;cleanLogout()
        end)
       end)
      end)
     end)
    end)
   end)
  end)
 end)
end
local function persistProbe()
 phase='persistence'
 command('/quiverqa persist '..sid,'READY',function(ready)
  assert(ready.mode=='persist'and ready.initial.arrows==10 and ready.initial.bolts==5 and ready.initial.selectedCount==1,'Persistence setup missing real separate stacks')
  local original=ready.initial;evidence.persistenceBefore=original
  measure(function(before)
   assert(before.arrows==10 and before.bolts==5,'Persistence setup changed before normal logout')
   reconnecting=true
   onReconnect=function()
    measure(function(after)
     assert(after.sid==before.sid and after.clientId==before.clientId and after.arrows==10 and after.bolts==5 and after.slots==3,'Saved equipped quiver or its separate contents lost on relog')
     assert(after.selected==2544 and after.selectedCount==1 and after.weight==before.weight,'Saved selection/order/weight changed')
     evidence.persistenceAfter=after
     g_app.doScreenshot('/quiver-native-after-relogin.png')
     command('/quiverqa restore','RESTORED',function(restored)
      assert(restored.restored,'Original equipment not restored on new online actor')
      evidence.persistenceRestored=true;shopProbe()
     end)
    end)
   end
   g_game.safeLogout()
   wait('normal persistence logout',function()return not g_game.isOnline()end,function()
    assert(next(g_game.getContainers())==nil,'Container state leaked through logout')
    later(6000,doLogin)
   end)
  end)
 end)
end
local function spellProbe()
 phase='legacy spells'
 command('/quiverqa spell '..sid,'READY',function(ready)
  assert(ready.mode=='spell'and #ready.initial.targetIds==3,'Owned three-target spell setup missing')
  local cid=ready.initial.clientId
  screenshotEquipment(ready.initial,function()
   local targetId=ready.initial.targetIds[1]
   wait('actual target visible',function()return g_map.getCreatureById(targetId)~=nil end,function()
    -- First ordinary shot may occur immediately when targeting despite the
    -- fixture's long interval. Observe it before the spell billing baseline.
    local target=assert(g_map.getCreatureById(targetId))
    g_game.attack(target);ordinaryRoundBaseline(function(before)
      g_game.talk('exevo sagitta')
      later(450,function()measure(function(after)
       local damage,changed=healthDamage(before,after)
       assert(before.arrows-after.arrows==1 and before.mana-after.mana==8,'Actual Sure Shot did not pay exactly1 round/8mana')
       assert(changed==1 and damage>0 and after.bolts==5,'Quiver Sure Shot did not remain a single target')
       evidence.sureShot={ammo=1,mana=8,actualDamage=damage,targets=changed}
       g_game.cancelAttack()
       command('/quiverqa spellreload','RELOADED',function(reloaded)
        assert(reloaded.arrows==10 and reloaded.selectedCount==1,'Volley boundary setup must retain1+9 separate arrow stacks')
        later(3300,function()measure(function(volleyBefore)
         assert(volleyBefore.arrows==10 and volleyBefore.selectedCount==1,'Unobserved attack consumed Volley boundary setup')
         g_game.talk('exevo gran sagitta')
         later(650,function()measure(function(volleyAfter)
          local volleyDamage,recipients=healthDamage(volleyBefore,volleyAfter)
          assert(volleyBefore.arrows-volleyAfter.arrows==3 and volleyBefore.mana-volleyAfter.mana==40,'Actual Volley did not pay3 finite rounds/40mana across stacks')
          assert(volleyAfter.bolts==5 and volleyAfter.selectedCount==7 and recipients==3 and volleyDamage>0,'Volley recipient selection/next stack/bolt exclusion failed')
          evidence.volley={ammo=3,mana=40,actualDamage=volleyDamage,targets=recipients,stackBoundary=true}
          g_game.talk('exevo gran sagitta')
          later(500,function()measure(function(rejected)
           local extra,extraTargets=healthDamage(volleyAfter,rejected)
           assert(extra==0 and extraTargets==0 and rejected.arrows==volleyAfter.arrows and rejected.mana==volleyAfter.mana,'Cooldown rejection replayed damage or payment')
           evidence.volleyCooldownRejected=true
           g_app.doScreenshot('/quiver-native-legacy-spells.png')
           command('/quiverqa restore','RESTORED',function(restored)
            assert(restored.restored,'Spell fixture did not restore original equipment/resources');autoProbe()
           end)
          end)end)
         end)end)
        end)end)
       end)
      end)end)
    end)
   end)
  end)
 end)
end
autoProbe=function()
 phase='101 ordinary shots'
 command('/quiverqa auto '..sid,'READY',function(ready)
  assert(ready.mode=='auto'and ready.initial.arrows==101 and ready.initial.bolts==5 and ready.initial.stats.attackSpeed==2000,'Actual101-round normal-interval setup missing')
  evidence.clientId=ready.initial.clientId
  print('QUIVER_NATIVE_CLIENT_AUTO_STARTED rounds101 normalInterval2000ms observe204000ms')
  local startSequence=receiptSequence.AUTO_OK or 0
  wait('101 actual ordinary shots',function()return(receiptSequence.AUTO_OK or 0)>startSequence end,function()
   local receipt=receipts.AUTO_OK
   assert(receipt.consumed==101 and receipt.actualDamage>0 and receipt.incompatibleBoltsPreserved==5 and receipt.intervalMilliseconds==2000 and receipt.restored,'Actual finite ordinary attack proof incomplete')
   assert(receipt.restoration and receipt.restoration.itemsRestored and receipt.restoration.resourcesRestored and receipt.restoration.stableStatsRestored,'Actual ordinary-shot restoration evidence incomplete')
   evidence.auto=receipt;persistProbe()
  end,220000)
 end)
end
local function firstProbe()
 if QUIVER_PROBE_RESUME=='shop'then shopProbe();return end
 if QUIVER_PROBE_PERSIST_BEFORE then
  phase='persistence'
  local before=QUIVER_PROBE_PERSIST_BEFORE
  measure(function(after)
   assert(after.sid==before.sid and after.clientId==before.clientId and after.arrows==before.arrows and after.bolts==before.bolts and after.slots==before.slots,'Saved equipped quiver or contents lost on fresh login')
   assert(after.selected==before.selected and after.selectedCount==before.selectedCount and after.weight==before.weight,'Saved selection/order/weight changed')
   evidence.persistenceBefore=before;evidence.persistenceAfter=after;evidence.resumedPersistence=true
   g_app.doScreenshot('/quiver-native-after-relogin.png')
   command('/quiverqa restore','RESTORED',function(restored)
    assert(restored.restored,'Original equipment not restored on new online actor')
    evidence.persistenceRestored=true;shopProbe()
   end)
  end)
  return
 end
 phase='contract'
 commands({'/passiveqa quiesce '..name,'/passivetest stop '..name,'/passiveqa learn '..name},function()
  command('/quiverqa contract '..sid,'CONTRACT_OK',function(result)
   assert(result.sid==sid and result.maximumArrows==2000 and result.capacity==20 and result.overflowRejected and result.restored,'Actual container/type/capacity proof failed')
   evidence.contract=result;spellProbe()
  end)
 end)
end
local function online()
 EnterGame.hide();player=assert(g_game.getLocalPlayer());assert(player:getName()==name)
 g_game.setChaseMode(DontChase);g_game.cancelAttack()
 wait('ordinary passive handshake',function()return mod.getState().ready end,function()
  if reconnecting then reconnecting=false;assert(onReconnect)();onReconnect=nil else firstProbe()end
 end)
end
doLogin=function()
 -- A completed ProtocolLogin retains XTEA; a new handshake needs a new object.
 login=ProtocolLogin.create();_G.quiverNativeLogin=login
 login.onLoginError=function(_,err)fail(err)end
 login.onCharacterList=function(_,chars)
  for _,c in ipairs(chars)do if c.name==name then g_game.loginWorld(G.account,G.password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return end end
  fail('Owned disposable test character absent')
 end
 login:login('127.0.0.1',7174,G.account,G.password,'',false)
end
local function begin()
 assert(LOCAL_PASSIVES_TEST and Services.updater=='' and g_resources.getLayout()=='retro','Owned local native probe only')
 mod=assert(modules.game_passives);g_window.resize({width=1280,height=800})
 connect(g_game,{onGameStart=function()later(400,online)end,onConnectionError=function(err)if not reconnecting then fail(err)end end,
  onTextMessage=function(_,text)
   local label,payload=text:match('^QUIVER_NATIVE_(%u[%u_]*) (.+)$')
   if label then
    print(text)
    if label=='FAILED'then fail(text);return end
    local ok,data=pcall(json.decode,payload);if not ok then fail('Malformed native fixture receipt '..label);return end
    receipts[label]=data;receiptSequence[label]=(receiptSequence[label]or 0)+1
   else print('QUIVER_NATIVE_NOTICE '..text)
   end
  end})
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 G.account='passivetest';G.password='passivetest';doLogin()
end
later(250,begin)
scheduleEvent(function()if not finished then fail('310second native quiver probe timeout')end end,310000)
