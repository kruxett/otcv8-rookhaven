-- Actual spell payment and passive regeneration, without forced proc counters.
local failed,finished=false,false
local mod,login,player,lowestMana,beforeMana
local function later(ms,fn)
  scheduleEvent(function()
    if failed or finished then return end
    local ok,err=pcall(fn)
    if not ok then failed=true;print('PASSIVES_RESOURCES_FAILED '..tostring(err));g_game.cancelAttack();g_game.talk('/passiveqa quiesce Passive Tester');scheduleEvent(function()g_app.exit()end,600) end
  end,ms)
end
local function wait(label,predicate,nextStep)
  local deadline=g_clock.millis()+10000
  local function poll()
    if predicate() then nextStep();return end
    assert(g_clock.millis()<deadline,label..' timeout');later(50,poll)
  end
  later(100,poll)
end
local function commands(list,nextStep)
  local function step(n)
    if n>#list then later(500,nextStep);return end
    g_game.talk(list[n]);later(250,function()step(n+1)end)
  end
  step(1)
end
local function finish()
  g_app.doScreenshot('/passives-resources-mana.png')
  commands({'/passivetest stop'},function()
    assert(not mod.getState().active and player:getMaxHealth()==735)
    finished=true;g_game.safeLogout();scheduleEvent(function() print('PASSIVES_RESOURCES_OK');g_app.exit()end,1000)
  end)
end
local function cast()
  local target
  for _,c in ipairs(g_map.getSpectators(player:getPosition(),false))do
    if c:getName()=='Passive Test Dummy' and (not target or c:getId()<target:getId())then target=c end
  end
  assert(target,'dummy not visible');g_game.attack(target)
  beforeMana=player:getMana();lowestMana=beforeMana
  connect(player,{onManaChange=function(_,mana)lowestMana=math.min(lowestMana,mana)end})
  g_game.talk('exori sec')
  wait('real Head Splitter payment',function()return lowestMana<beforeMana end,function()
    assert(beforeMana-lowestMana==19,'20-mana spell did not pay exactly19 with5% discount: '..(beforeMana-lowestMana))
    print('PASSIVES_REAL_MANA_PAYMENT_OK before='..beforeMana..' minimum='..lowestMana)
    g_game.cancelAttack()
    commands({'/passiveqa quiesce Passive Tester'},function()
      local mana=player:getMana()
      -- Measurement requires quiesce to remove food regeneration and monsters.
      -- The fixture's regeneration cleanup is supplied by the server owner. Rank5
      -- Focus now accumulates 0.125 mana/sec: one whole mana per eight seconds.
      -- Observe two successive windows without resetting the fractional ledger.
      later(9000,function()
        local first=player:getMana()-mana
        assert(first>=1 and first<=2,'First9s fractional recovery incorrect: '..first)
        local midpoint=player:getMana()
        later(9000,function()
          local second=player:getMana()-midpoint
          local delta=player:getMana()-mana
          assert(second>=1 and second<=2,'Second9s fractional recovery incorrect: '..second)
          assert(delta>=2 and delta<=3,'Rank5 Focus18s recovery incorrect: '..delta)
          print('PASSIVES_REAL_MANA_RECOVERY_OK eighteen_seconds='..delta..' first9='..first..' second9='..second)
          finish()
        end)
      end)
    end)
  end)
end
local function allocate()
  mod.setStatusVisible(true)
  local s=mod.getState()
  s.draft={minor_efficiency=5,minor_focus=5,minor_vitality=5,minor_recovery=5,minor_power=4}
  local revision=s.revision
  assert(mod.apply(),'legal resource build rejected by UI')
  wait('resource build apply',function()return mod.getState().revision>revision end,function()
    assert(player:getMaxHealth()==771,'derived vitality incorrect')
    commands({'/passiveqa arena','/passiveqa join Passive Tester,1','/passiveqa heal Passive Tester'},function()
      mod.hide()
      -- Respect the ordinary pacified/exhaustion window after login/teleport.
      later(11000,cast)
    end)
  end)
end
local function online()
  EnterGame.hide();player=g_game.getLocalPlayer()
  connect(g_game,{onTextMessage=function(_,text)print('PASSIVES_RESOURCES_MESSAGE '..text)end})
  wait('handshake',function()return mod.getState().ready end,function()
    commands({'/passiveqa quiesce Passive Tester','/passiveqa equip reaver','/passivetest start reaver','/passivetest trace Passive Tester,on'},function()
      wait('resource overlay',function()return mod.getState().active and mod.getState().tree end,allocate)
    end)
  end)
end
later(200,function()
  assert(LOCAL_PASSIVES_TEST and Services.updater=='' and g_resources.getLayout()=='retro')
  mod=assert(modules.game_passives)
  g_settings.set('window-maximized',false);g_window.resize({width=1280,height=800})
  connect(g_game,{onGameStart=function()later(250,online)end})
  g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
  G.account='passivetest';G.password='passivetest'
  login=ProtocolLogin.create();_G.passivesResourcesLogin=login
  login.onLoginError=function(_,err)failed=true;print('PASSIVES_RESOURCES_FAILED '..err);g_app.exit()end
  login.onCharacterList=function(_,chars)
    for _,c in ipairs(chars)do if c.name=='Passive Tester'then g_game.loginWorld(G.account,G.password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return end end
  end
  login:login('127.0.0.1',7174,G.account,G.password,'',false)
end)
scheduleEvent(function()if not finished then print('PASSIVES_RESOURCES_FAILED timeout');g_app.exit()end end,70000)
