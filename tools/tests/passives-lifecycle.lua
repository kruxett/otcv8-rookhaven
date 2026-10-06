-- Real client lifecycle/persistence/HP-condition regression. Isolated GUID9001 only.
local mod,player,login,nextOnline,metrics
local seq=0
local failed,done,intentional=false,false,false
local deathSeen=false
local reproduce=PASSIVES_PROBE_CAP=='reproduce'
local function fail(e)
 if failed or done then return end;failed=true
 print('PASSIVES_LIFECYCLE_FAILED '..tostring(e))
 if g_game.isOnline() then g_game.talk('/passivelifecycle clearstore');g_game.talk('/passivelifecycle removebuff');g_game.talk('/passivetest stop');g_game.safeLogout() end
 scheduleEvent(function()g_app.exit()end,900)
end
local function later(ms,fn)
 scheduleEvent(function()if failed or done then return end;local ok,e=pcall(fn);if not ok then fail(e)end end,ms)
end
local function wait(label,pred,nextStep,ms)
 local deadline=g_clock.millis()+(ms or 9000)
 local function poll()if pred()then nextStep();return end;assert(g_clock.millis()<deadline,label..' timeout');later(60,poll)end
 later(100,poll)
end
local function cmds(list,nextStep)
 local function step(i)if i>#list then later(400,nextStep);return end;g_game.talk(list[i]);later(300,function()step(i+1)end)end
 step(1)
end
local function fixture(op,nextStep)
 local old=seq;g_game.talk('/passivelifecycle '..op)
 wait('fixture '..op,function()return seq>old and metrics.label==op end,function()nextStep(metrics)end)
end
local function uiBaseline()
 assert(not mod.getState().active and not mod.getWindow() and not mod.getStatusWindow(),'Inactive passive UI/state remained')
 assert(modules.game_interface.getRootPanel():isVisible(),'Game interface disappeared')
 assert(modules.game_inventory and modules.game_console and modules.client_options,'Existing client modules unavailable')
end
local function relog(nextStep,drop)
 intentional=true
 if drop then
  -- Close TCP first: the subsequent local reset cannot transmit a Logout packet.
  g_game.getProtocolGame():disconnect();g_game.forceLogout()
 else g_game.safeLogout() end
 wait('client offline',function()return not g_game.isOnline()end,function()
  assert(not mod.getState().tree and not mod.getWindow() and not mod.getStatusWindow(),'Logout left passive UI')
  later(2400,function()
   nextOnline=nextStep
   G.account,G.password='passivetest','passivetest'
   login=ProtocolLogin.create();_G.lifecycleLogin=login
   login.onLoginError=function(_,e)fail(e)end
   login.onCharacterList=function(_,list)
    for _,c in ipairs(list)do if c.name=='Passive Tester'then g_game.loginWorld(G.account,G.password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return end end
    fail('Fixture character absent')
   end
   login:login('127.0.0.1',7174,G.account,G.password,'',false)
  end)
 end)
end
local function start(nextStep)
 cmds({'/passiveqa quiesce Passive Tester','/passiveqa equip reaver','/passivetest start reaver','/passivetest preset Passive Tester,berserker'},function()
  local current=mod.getState()
  assert(current.active and current.ranks.cap_berserker==1,'Overlay start/preset rejected')
  -- The new 16-point capstone preset has no HP ranks. This is a separate
  -- 21-point HP-composition fixture within the 24-point admin budget, not a
  -- level-40 natural-capstone build. Keep every existing 5% HP assertion.
  local ranks,points={},0
  for id,rank in pairs(current.ranks)do ranks[id]=rank end
  ranks.minor_vitality=5
  for _,rank in pairs(ranks)do points=points+rank end
  assert(points==21 and current.points==24,'Unexpected HP fixture/admin budget')
  assert(not mod.validateDraft(ranks),'HP-composition draft is not legal')
  local session,revision=current.session,current.revision
  local protocol=assert(g_game.getProtocolGame(),'Missing online protocol')
  protocol:sendExtendedOpcode(103,json.encode({v=1,action='apply',
   requestId='lifecycle-hp-'..g_clock.millis(),session=session,revision=revision,ranks=ranks}))
  wait('authoritative HP-composition Apply',function()
   local saved=mod.getState()
   if not saved.active or saved.session~=session or saved.revision<=revision then return false end
   for id,rank in pairs(ranks)do if saved.ranks[id]~=rank then return false end end
   for id,rank in pairs(saved.ranks)do if ranks[id]~=rank then return false end end
   return true
  end,function()
   print('PASSIVES_LIFECYCLE_HP_FIXTURE_APPLIED points21 vitality5')
   nextStep()
  end)
 end)
end
local function finish()
 fixture('clearstore',function()fixture('removebuff',function()
  cmds({'/passiveqa quiesce Passive Tester','/passivetest stop'},function()
   assert(player:getMaxHealth()==735 and player:getLevel()==40,'Fixture base stats altered')
   uiBaseline();g_app.doScreenshot('/passives-regression-clean.png')
   intentional=true;g_game.safeLogout()
   wait('final logout',function()return not g_game.isOnline()end,function()
    assert(not mod.getWindow() and not mod.getStatusWindow())
    done=true;print(reproduce and 'PASSIVES_LIFECYCLE_REPRO_OK' or 'PASSIVES_LIFECYCLE_OK')
    scheduleEvent(function()g_app.exit()end,400)
   end)
  end)
 end)end)
end
local function deathTest()
 start(function()
  assert(player:getMaxHealth()==771,'Death overlay HP missing')
  print('PASSIVES_LIFECYCLE_DEATH_START')
  g_game.talk('/passivelifecycle death')
  wait('real death discards overlay',function()return deathSeen and not mod.getState().active end,function()
   assert(deathSeen,'Native death event was not observed')
   relog(function()
    assert(player:getMaxHealth()==735 and player:getLevel()==40 and not mod.getState().active,'Death retained overlay/stats or altered fixture progression')
    print('PASSIVES_LIFECYCLE_DEATH_OK');finish()
   end)
  end,12000)
 end)
end
local function detachTest()
 start(function()
  assert(player:getMaxHealth()==771)
  fixture('armdetach',function()
   relog(function()
    fixture('state',function(m)
     local o=assert(m.observed.detach,'Offline detach observer missing')
     assert(o.onlineEntity and o.sameEntity and o.ip==0,'TCP fixture did not leave the existing player object offline')
     assert(o.maxHP==735 and m.maxHP==735 and not m.active,'TCP detach retained or revived overlay HP/profile')
     uiBaseline();print('PASSIVES_LIFECYCLE_TCP_DETACH_OK '..json.encode(o));deathTest()
    end)
   end,true)
  end)
 end)
end
local function storeTest()
 start(function()
  assert(player:getMaxHealth()==771)
  fixture('armstore',function(m)
   assert(m.store==1)
   relog(function()
    fixture('state',function(m)
     local o=assert(m.observed.store,'Offline store observer missing')
     assert(o.onlineEntity and o.sameEntity and o.ip==0 and o.store==1,'Store fixture did not exercise real vendor soft logout')
     assert(o.maxHP==735 and m.maxHP==735 and not m.active,'Soft logout retained or revived overlay HP/profile')
     assert(m.saved.maxHP==735 and m.saved.hp<=735,'Soft logout persisted temporary HP')
     uiBaseline();print('PASSIVES_LIFECYCLE_STORE_OK '..json.encode(o))
     fixture('clearstore',function()detachTest()end)
    end)
   end)
  end)
 end)
end
local function persistence()
 start(function()
  fixture('buff',function(m)
   assert(m.maxHP==918,'HP-percent buff after overlay retained passive multiplier: '..m.maxHP)
   fixture('fill',function()fixture('save',function(m)
    assert(m.saved.maxHP==735 and m.saved.hp==882,'Save persisted temporary HP bonus: '..json.encode(m.saved))
    relog(function()
     fixture('state',function(m)
      assert(m.maxHP==882 and m.hp==882 and m.buff and not m.active,'Relog lost regular buff or restored passive HP')
      uiBaseline();print('PASSIVES_LIFECYCLE_SAVE_RELOGIN_OK '..json.encode(m.saved))
      fixture('removebuff',function(m)assert(m.maxHP==735);storeTest()end)
     end)
    end)
   end)end)
  end)
 end)
end
local function buffBefore()
 fixture('buff',function(m)
  assert(m.maxHP==882,'Baseline120%HP condition wrong')
  start(function()
   assert(player:getMaxHealth()==918,'Buff-before-overlay HP differs from buff-after')
   cmds({'/passiveqa equip blademaster'},function()
    fixture('state',function(m)
     assert(m.maxHP==882 and m.active,'Wrong weapon did not remove only passive HP')
     cmds({'/passivetest stop'},function()
      fixture('removebuff',function(m)assert(m.maxHP==735);print('PASSIVES_LIFECYCLE_HP_COMPOSITION_OK');persistence()end)
     end)
    end)
   end)
  end)
 end)
end
local function initial()
 fixture('clearstore',function()fixture('removebuff',function()
  cmds({'/passiveqa quiesce Passive Tester','/passivetest stop'},function()
   fixture('gate',function(m)
    assert(m.observed.gateRejected and not m.active,'Non-admin gate test failed')
    uiBaseline();print('PASSIVES_LIFECYCLE_NORMAL_PLAYER_GATE_OK')
    start(function()
     assert(player:getMaxHealth()==771,'Unexpected baseHP/5%overlay')
     fixture('buff',function(m)
      if reproduce then
       assert(m.maxHP==925,'Old binary did not reproduce expected multiplier: '..m.maxHP)
       cmds({'/passivetest stop'},function()
        fixture('state',function(m)
         assert(m.maxHP==889,'Expected retained HP889 not reproduced')
         print('PASSIVES_LIFECYCLE_REPRO_HP_RESIDUE actual889 expected882')
         fixture('removebuff',function(m)assert(m.maxHP==735);finish()end)
        end)
       end)
      else
       assert(m.maxHP==918,'Buff-after overlay expected918 got'..m.maxHP)
       cmds({'/passivetest stop'},function()
        fixture('state',function(m)
         assert(m.maxHP==882,'Stop retained passive-derived HP')
         fixture('removebuff',function(m)assert(m.maxHP==735);buffBefore()end)
        end)
       end)
      end
     end)
    end)
   end)
  end)
 end)end)
end
later(200,function()
 assert(LOCAL_PASSIVES_TEST and Services.updater=='' and g_resources.getLayout()=='retro')
 mod=assert(modules.game_passives)
 connect(g_game,{onDeath=function()deathSeen=true;print('PASSIVES_LIFECYCLE_NATIVE_DEATH_EVENT')end,onTextMessage=function(_,text)
  print('PASSIVES_LIFECYCLE_MESSAGE '..text)
  -- With fixture skill loss disabled, native death respawns immediately instead of sending the relog window.
  if text=='You are dead.' then deathSeen=true;print('PASSIVES_LIFECYCLE_SERVER_DEATH_EVENT')end
  if text:find('PASSIVES_LIFECYCLE_FIXTURE_FAILED',1,true)then fail(text)end
  local raw=text:match('^PASSIVE_LIFECYCLE_STATE (.+)$');if raw then metrics=json.decode(raw);seq=seq+1 end
 end,onGameStart=function()
  EnterGame.hide();player=assert(g_game.getLocalPlayer());intentional=false
  local fn=nextOnline;nextOnline=nil
  wait('passive handshake',function()return mod.getState().ready end,function()later(300,fn)end,12000)
 end,onConnectionError=function(e)if not intentional then fail(e)end end})
 nextOnline=initial;G.account,G.password='passivetest','passivetest'
 login=ProtocolLogin.create();_G.lifecycleLogin=login
 login.onLoginError=function(_,e)fail(e)end
 login.onCharacterList=function(_,list)for _,c in ipairs(list)do if c.name=='Passive Tester'then g_game.loginWorld(G.account,G.password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return end end;fail('Missing fixture character')end
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 login:login('127.0.0.1',7174,G.account,G.password,'',false)
end)
scheduleEvent(function()if not done then fail('Lifecycle120-second timeout')end end,120000)
