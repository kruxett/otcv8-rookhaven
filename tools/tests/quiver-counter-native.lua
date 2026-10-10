-- Actual 8.60 client + guarded owned loopback engine only. No production calls.
-- Wrapper success: QUIVER_COUNTER_NATIVE_OK; timeout90s. Fixture /quiverqa.
local failed,finished,reconnecting=false,false,false
local finalLogoutExpected=false
local name,sid='Passive Tester',12830
local receipts,sequences={},{}
local inventory,counter,player,login
local phase='initial'
local evidence={sid=sid,steps={},closedContainer=true}
local doLogin,onReconnect
local function fail(reason)
 if failed or finished then return end;failed=true
 print('QUIVER_COUNTER_NATIVE_FAILED phase='..phase..' '..tostring(reason))
 if g_game.isOnline()then
  g_game.cancelAttack();g_game.talk('/quiverqa restore')
  scheduleEvent(function()g_game.safeLogout()end,700)
 else print('QUIVER_COUNTER_NATIVE_PRESERVATION_RETAINED actorOffline=true')end
 scheduleEvent(function()g_app.exit()end,1800)
end
local function later(ms,fn)
 scheduleEvent(function()if failed or finished then return end;local ok,err=pcall(fn);if not ok then fail(err)end end,ms)
end
local function wait(label,predicate,fn,timeout)
 local deadline=g_clock.millis()+(timeout or 12000)
 local function inspect()
  if predicate()then later(80,fn);return end
  assert(g_clock.millis()<deadline,label..' timeout');later(50,inspect)
 end
 later(1,inspect)
end
local function command(words,label,fn)
 local before=sequences[label]or 0;g_game.talk(words)
 wait(label,function()return(sequences[label]or 0)>before end,function()fn(receipts[label])end)
end
local function slotWidget()
 return assert(inventory.inventoryPanel:getChildById('slot'..InventorySlotAmmo),'Actual ammo slot widget missing')
end
local function closedQuiver()
 for _,container in pairs(g_game.getContainers())do
  local item=container:getContainerItem();if item and item:getId()==11867 then return false end
 end
 return true
end
local function expected(arrows,bolts,required,equipped)
 local total=arrows+bolts
 return {arrows=arrows,bolts=bolts,total=total,requiredAmmo=required,launcherReady=required~='none',
  compatible=required=='arrow'and arrows or required=='bolt'and bolts or 0,equipped=equipped~=false}
end
local cases={
 [0]=expected(0,0,'arrow'),[1]=expected(1,0,'arrow'),[2]=expected(100,0,'arrow'),[3]=expected(101,0,'arrow'),
 [4]=expected(2000,0,'arrow'),[5]=expected(101,9,'arrow'),[6]=expected(101,9,'bolt'),[7]=expected(101,9,'none'),
 [8]=expected(100,9,'arrow'),[9]=expected(60,9,'arrow'),[10]=expected(100,9,'arrow'),[11]=expected(80,9,'arrow'),
 [12]=expected(100,9,'arrow'),[13]=expected(101,9,'arrow'),[14]=expected(0,0,'none',false),
 [15]=expected(101,9,'arrow'),[16]=expected(7,9,'arrow'),[17]=expected(7,9,'arrow'),[18]=expected(101,9,'arrow'),[19]=expected(100,9,'arrow')}
local function matches(value,wanted)
 if not value then return false end
 for key,number in pairs(wanted)do if value[key]~=number then return false end end
 return value.schema==1 and value.quiverCid==(wanted.equipped and 11867 or 0)
end
local function verify(step,receipt,fn)
 local wanted=assert(cases[step]);phase='counterstep'..step
 assert(receipt.step==step and receipt.mode=='counter','Actual fixture step receipt differs')
 wait('authoritative snapshot'..step,function()return matches(counter.getState(),wanted)end,function()
  assert(closedQuiver(),'Counter probe opened the quiver; closed-container case unmeasured')
  local state=counter.getState();local widget=slotWidget();local badge=widget:getChildById('quiverAmmoCount')
  local item=assert(player:getInventoryItem(InventorySlotAmmo))
  if wanted.equipped then
   assert(item:getId()==11867 and item:isContainer()and item:getCount()==1,'Quiver native identity/subtype changed')
   local amount=wanted.launcherReady and wanted.compatible or wanted.total
   assert(badge and badge:isVisible()and badge:getText()==tostring(amount),'Actual rendered badge differs from accepted snapshot')
   assert(receipt.arrows==wanted.arrows and receipt.bolts==wanted.bolts and receipt.total==wanted.total,'Actual server contents differ from wire counts')
   local tooltip=assert(widget:getTooltip())
   assert(tooltip:find('Total ammunition: '..wanted.total,1,true)and tooltip:find('Arrows: '..wanted.arrows,1,true)and tooltip:find('Bolts: '..wanted.bolts,1,true),'Actual item tooltip breakdown incomplete')
   assert((tooltip:find('The quiver is empty.',1,true)~=nil)==(wanted.total==0),'Empty text disagrees with actual total')
   evidence.steps[#evidence.steps+1]={step=step,badge=amount,snapshot=state,closed=true,slots=receipt.slots}
  else
   assert(item:getId()==receipt.clientId and item:getCount()==99 and not item:isContainer(),'Ordinary direct-arrow99 behavior changed')
   assert(not badge or not badge:isVisible(),'Quiver badge leaked onto ordinary ammunition')
   assert(not(widget:getTooltip()or''):find('Magic Quiver',1,true),'Quiver tooltip leaked onto ordinary ammunition')
   evidence.ordinaryArrow99=true
  end
  fn(receipt)
 end)
end
local function closeClassChoice()
 local passives=modules.game_passives
 local choice=passives and passives.getClassChoice and passives.getClassChoice()
 local window=choice and choice.getWindow()
 if window and window:isVisible()then
  local button=assert(window:recursiveGetChildById('cancelButton'),'Actual class-choice Cancel missing')
  signalcall(button.onClick,button);return true
 end
 return false
end
local function screenshots(label,fn)
 local widget=slotWidget();local badge=assert(widget:getChildById('quiverAmmoCount'))
 local function take(width,height,suffix,thenDo)
  closeClassChoice()
  g_window.resize({width=width,height=height})
  later(220,function()
   closeClassChoice()
   local a,b=badge:getRect(),g_ui.getRootWidget():getRect()
   assert(a.x>=b.x and a.y>=b.y and a.x+a.width<=b.x+b.width and a.y+a.height<=b.y+b.height,'Native ammo badge clipped at '..width)
   assert(badge:isVisible(),'Badge disappeared after native resize')
   g_tooltip.display(assert(widget:getTooltip()))
   local function frame(attempt)
    -- A normal class prompt can arrive after onGameStart. Close its actual
    -- Cancel action and allow a rendered frame before capturing the badge.
    if closeClassChoice()then
     assert(attempt<3,'Class-choice prompt kept reopening during native screenshot')
     later(100,function()frame(attempt+1)end);return
    end
    g_app.doScreenshot('/quiver-counter-'..label..'-'..suffix..'.png');g_tooltip.hide();thenDo()
   end
   later(160,function()frame(0)end)
  end)
 end
 take(1280,800,'1280x800',function()take(800,640,'800x640',function()
  g_window.resize({width=1280,height=800});later(150,fn)
 end)end)
end
local function finish()
 phase='restore'
 command('/quiverqa restore','RESTORED',function(restored)
  assert(restored.restored and restored.itemsRestored and restored.resourcesRestored and restored.stableStatsRestored,'Original owned fixture equipment/resources not restored')
  evidence.restoration=restored;phase='final logout';finalLogoutExpected=true
  g_game.cancelAttack();g_game.safeLogout()
  wait('final safe logout',function()return not g_game.isOnline()end,function()
   assert(counter.getState()==nil,'Quiver snapshot leaked across offline reset')
   finished=true;print('QUIVER_COUNTER_NATIVE_OK '..json.encode(evidence))
   print('QUIVER_COUNTER_NATIVE_SCREENSHOT_DIRECTORY '..g_resources.getWriteDir());g_app.exit()
  end)
 end)
end
local function runStep(step)
 command('/quiverqa counterstep '..step,'COUNTER_STEP',function(receipt)
  verify(step,receipt,function()
   if step==4 or step==5 then screenshots(step==4 and '2000'or'101',function()runStep(step+1)end)
   elseif step==18 then
    evidence.persistenceBefore=receipt;phase='relogin';reconnecting=true
    local priorGameProtocol=g_game.getProtocolGame()
    onReconnect=function()
     assert(g_game.getProtocolGame()~=priorGameProtocol,'World relog reused the earlier ProtocolGame')
     command('/quiverqa countermetrics','COUNTER_METRICS',function(after)
      verify(18,after,function()
       assert(after.sid==receipt.sid and after.clientId==receipt.clientId and after.slots==3 and after.weight==receipt.weight,'Native quiver identity/content order/weight lost on relog')
       assert(after.selected==2544 and after.selectedCount==1,'Saved first compatible stack changed on relog')
       evidence.persistenceAfter=after;runStep(19)
      end)
     end)
    end
    g_game.safeLogout()
    wait('normal save/logout',function()return not g_game.isOnline()end,function()
     assert(counter.getState()==nil,'Old accepted snapshot retained after logout');later(6000,doLogin)
    end)
   elseif step==19 then
    assert(receipt.shot and receipt.shot.consumed==1 and receipt.shot.intervalMilliseconds==2000 and receipt.shot.actualDamage>0 and receipt.shot.stopped,'Actual one ordinary shot receipt incomplete')
    evidence.ordinaryShot=receipt.shot;finish()
   else runStep(step+1)end
  end)
 end)
end
local function online()
 EnterGame.hide();player=assert(g_game.getLocalPlayer());assert(player:getName()==name)
 g_game.setChaseMode(DontChase);g_game.cancelAttack()
 closeClassChoice()
 if not inventory.inventoryWindow:isVisible()then inventory.toggle()end
 if reconnecting then reconnecting=false;local continuation=assert(onReconnect);onReconnect=nil;continuation()
 else command('/quiverqa counterbegin '..sid,'COUNTER_READY',function(receipt)verify(0,receipt,function()runStep(1)end)end)end
end
doLogin=function()
 -- Each relog gets a fresh ProtocolLogin/XTEA handshake.
 local previousLogin=login;login=ProtocolLogin.create();assert(login~=previousLogin,'Relog reused the earlier ProtocolLogin');_G.quiverCounterNativeLogin=login
 login.onLoginError=function(_,err)fail(err)end
 login.onCharacterList=function(_,characters)
  for _,character in ipairs(characters)do if character.name==name then
   g_game.loginWorld(G.account,G.password,character.worldName,character.worldIp,character.worldPort,character.name,'','');return
  end end
  fail('Owned disposable fixture character missing')
 end
 login:login('127.0.0.1',7174,G.account,G.password,'',false)
end
local function begin()
 assert(LOCAL_PASSIVES_TEST and Services.updater==''and g_resources.getLayout()=='retro','Owned loopback native counter probe only')
 inventory=assert(modules.game_inventory);counter=assert(inventory.QuiverAmmo);g_window.resize({width=1280,height=800})
 connect(g_game,{onGameStart=function()later(400,online)end,onConnectionError=function(err,code)
   -- Native safeLogout closes the socket with asio EOF (2). Accept it only
   -- after an explicit owned logout; connection failures remain test failures.
   if (reconnecting or finalLogoutExpected)and err=='End of file'and code==2 then
    print('QUIVER_COUNTER_NATIVE_EXPECTED_LOGOUT_EOF phase='..phase)
   else fail(err)end
  end,
  onTextMessage=function(_,text)
   local label,payload=text:match('^QUIVER_NATIVE_(%u[%u_]*) (.+)$')
   if label then
    print(text);if label=='FAILED'then fail(text);return end
    local ok,value=pcall(json.decode,payload);if not ok then fail('Malformed guarded counter receipt');return end
    receipts[label]=value;sequences[label]=(sequences[label]or 0)+1
   end
  end})
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 G.account='passivetest';G.password='passivetest';doLogin()
end
later(250,begin)
scheduleEvent(function()if not finished then fail('80 second bounded counter probe timeout')end end,80000)
