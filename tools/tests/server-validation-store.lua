-- Connected loopback/native SQL probe. PASSIVES_PROBE_CAP selects crash phases
-- in the existing disposable probe runner; ordinary execution covers recovery.
local done,failed,expectedDisconnect=false,false,false
local stage=(PASSIVES_PROBE_CAP=='store_crash' and 'crash') or
 (PASSIVES_PROBE_CAP=='store_verify_crash' and 'verify_crash') or 'run'
local login,loginAttempts,loginGeneration,receipts=nil,0,0,{}
local reconnectScheduled=false
local function disableAutomaticReconnect()
 g_settings.set('autoReconnect',false)
 local button=g_ui.getRootWidget():recursiveGetChildById('autoReconnect')
 if button then button:setOn(false) end
end
local function fail(reason)
 if done or failed then return end;failed=true
 print('STORE_VALIDATION_NATIVE_FAILED '..tostring(reason))
 if g_game.isOnline() then g_game.safeLogout() end
 scheduleEvent(function()g_app.exit()end,500)
end
local function later(ms,fn)
 scheduleEvent(function()if done or failed then return end
  local ok,why=xpcall(fn,debug.traceback);if not ok then fail(why)end
 end,ms)
end
local function wait(label,predicate,nextStep)
 local deadline=g_clock.millis()+10000
 local function poll()
  local value=predicate();if value then nextStep(value);return end
  assert(g_clock.millis()<deadline,label..' timeout');later(70,poll)
 end
 later(70,poll)
end
local function uiFlow(fixture)
 local player=assert(g_game.getLocalPlayer());g_game.use(assert(player:getInventoryItem(3)))
 wait('native carried bag',function()for _,bag in pairs(g_game.getContainers())do
  for _,i in ipairs(bag:getItems())do if i:getId()==fixture.arrowClientId then return i end end
 end end,function(arrow)
  modules.game_personalstore.requestPersonalStore(g_game.getCharacterName())
  wait('native store window',function()
   local panel=g_ui.getRootWidget():recursiveGetChildById('itemsFlatPanel')
   return panel and panel:isVisible() and panel
  end,function(panel)
   modules.game_personalstore.requestPersonalStore(g_game.getCharacterName(),true)
   later(250,function()
    assert(panel:isVisible(),'Silent snapshot hid the active store')
    panel.onDrop(panel,{getItem=function()return arrow end},{x=0,y=0})
   end)
   wait('native selection response',function()
    local editor=g_ui.getRootWidget():recursiveGetChildById('itemEditPanel')
    return editor and editor:isVisible() and editor
   end,function(editor)
    editor:getChildById('count'):setValue(4)
    editor:getChildById('price'):getChildById('value'):setText('12')
    local confirm=editor:getChildById('confirm');confirm.onClick();confirm.onClick()
    wait('single native deposit',function()
     for _,slot in ipairs(panel:getChildren())do if slot.itemInfo and slot.itemInfo.revision==1 and slot.itemInfo.count==4 then return slot end end
    end,function(slot)
     modules.game_personalstore.showEditItemPanel(slot.itemInfo)
     editor:getChildById('count'):setValue(2);editor:getChildById('price'):getChildById('value'):setText('15')
     confirm.onClick();confirm.onClick()
     wait('single native edit',function()
      for _,s in ipairs(panel:getChildren())do if s.itemInfo and s.itemInfo.revision==2 and s.itemInfo.count==2 then return s end end
     end,function(s)
      modules.game_personalstore.enableEditionModeOrOfflineMode()
      local remove=s:getChildById('remove');remove.onClick()
      wait('native withdraw refresh',function()
       for _,v in ipairs(panel:getChildren())do if v.itemInfo and v.itemInfo.revision then return false end end
       return true
      end,function()later(250,function()g_game.talk('/validationstore ui_verify')end)end)
     end)
    end)
   end)
  end)
 end)
end
local function finish(marker,row)
 done=true;print(marker..' '..json.encode(row or {}))
 if g_game.isOnline() then g_game.safeLogout() end
 scheduleEvent(function()g_app.exit()end,500)
end
local connectWorld
local function disconnected()
 if not expectedDisconnect or reconnectScheduled or failed or done or g_game.isOnline() then return end
 reconnectScheduled=true;print('STORE_VALIDATION_RECONNECT stage='..stage)
 if stage=='crash'then finish('STORE_VALIDATION_CRASH_READY',{phase=stage})
 else later(2500,connectWorld)end
end
local function armDisconnect()
 expectedDisconnect=true;reconnectScheduled=false
 local function observe()
  if not expectedDisconnect or done or failed then return end
  disconnected();if not reconnectScheduled then later(100,observe)end
 end
 later(100,observe)
end
connectWorld=function()
 loginAttempts=loginAttempts+1;assert(loginAttempts<=8,'Recovery did not allow a fresh login')
 loginGeneration=loginGeneration+1;local generation=loginGeneration
 print('STORE_VALIDATION_LOGIN stage='..stage..' attempt='..loginAttempts)
 login=ProtocolLogin.create();_G.storeValidationLogin=login
 login.onLoginError=function(_,why)
  if expectedDisconnect and loginAttempts<8 then later(1500,connectWorld)else fail(why)end
 end
 login.onCharacterList=function(_,list)
  print('STORE_VALIDATION_CHARACTERS stage='..stage)
  for _,c in ipairs(list)do if c.name=='Passive Tester'then
   assert(c.worldIp=='127.0.0.1' and c.worldPort==7175,'Non-loopback game world')
   g_game.loginWorld('passivetest','passivetest',c.worldName,c.worldIp,c.worldPort,c.name,'','');return
  end end
  fail('Disposable actor9001 missing')
 end
 login:login('127.0.0.1',7174,'passivetest','passivetest','',false)
 later(8000,function()
  if generation==loginGeneration and expectedDisconnect and not g_game.isOnline() then
   print('STORE_VALIDATION_LOGIN_RETRY stage='..stage)
   login:disconnect();g_game.cancelLogin();connectWorld()
  end
 end)
end
later(200,function()
 assert(LOCAL_PASSIVES_TEST and Services.updater=='' and g_resources.getLayout()=='retro','Owned local retro client required')
 assert(modules.game_personalstore,'Native Personal Store client module missing')
 disableAutomaticReconnect()
 connect(g_game,{
  onGameStart=function()later(350,function()
   EnterGame.hide();disableAutomaticReconnect();loginAttempts=0
   if expectedDisconnect then
    expectedDisconnect=false;stage='verify_'..stage
   end
   print('STORE_VALIDATION_ENTERED stage='..stage)
   if stage=='unknown_before' or stage=='unknown_after' or stage=='crash' then armDisconnect() end;g_game.talk('/validationstore '..stage)
  end)end,
  onTextMessage=function(_,text)
   local raw=text:match('^STORE_VALIDATION_NATIVE (.+)$');if not raw then return end
   local ok,why=xpcall(function()
    local row=json.decode(raw);print(text);receipts[row.label]=row
    if row.label=='FAILED'then error(row.error)end
    if row.label=='complete'then
     assert(row.checks>=8 and row.nativeSQL and row.nativeInventory,'Incomplete native service checks')
     later(250,function()g_game.talk('/validationstore ui_prepare')end)
    elseif row.label=='ui_prepared'then uiFlow(row)
    elseif row.label=='ui_complete'then
     stage='unknown_before';later(250,function()armDisconnect();g_game.talk('/validationstore '..stage)end)
    elseif row.label=='fault_armed'then -- armed locally before the command
    elseif row.label=='verified'then
     assert(row.freshLogin and row.phase==stage:sub(8),'Recovery phase mismatch')
     if stage=='verify_unknown_before'then
      assert(not row.committed,'Pre-COMMIT failure was committed');stage='unknown_after'
      later(250,function()armDisconnect();g_game.talk('/validationstore '..stage)end)
     elseif stage=='verify_unknown_after'then
      assert(row.committed,'Post-COMMIT failure was rolled back')
      finish('STORE_VALIDATION_NATIVE_OK',{normal=receipts.complete,unknownBefore=true,unknownAfter=true})
     elseif stage=='verify_crash'then
      assert(row.committed,'Crash-after-COMMIT lost committed inventory')
      finish('STORE_VALIDATION_CRASH_RECOVERY_OK',row)
     end
    end
   end,debug.traceback);if not ok then fail(why)end
  end,
  onGameEnd=function()
   disconnected()
  end,
  onConnectionError=function(reason)
   if not expectedDisconnect and not done then fail(reason)end
  end,
  onLoginError=function(reason)
   if expectedDisconnect then later(1500,connectWorld)else fail(reason)end
  end,
 })
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 connectWorld()
end)
scheduleEvent(function()if not done then fail('native Personal Store probe timeout')end end,100000)
