-- Run the same build once with passiveTestEnabled=true (no overlays), once false.
-- Server registration/config/process ownership stays with the local test runner.
local failed, finished = false, false
local player, login, enabled, pending, minimumMana, lastMana, healed = nil, nil, nil, nil, nil, nil, false
local function fail(message)
  if failed or finished then return end
  failed=true;print('PASSIVES_BASELINE_FAILED '..tostring(message))
  if g_game.isOnline() then
    g_game.cancelAttack();g_game.talk('/passivebaseline cleanup')
    scheduleEvent(function()g_game.safeLogout()end,350)
  end
  scheduleEvent(function()g_app.exit()end,1300)
end
local function later(ms,fn)
  scheduleEvent(function()
    if failed or finished then return end
    local ok,err=pcall(fn);if not ok then fail(err)end
  end,ms)
end
local function wait(label,predicate,nextStep,timeout)
  local deadline=g_clock.millis()+(timeout or 8000)
  local function poll()
    if predicate()then nextStep();return end
    assert(g_clock.millis()<deadline,label..' timeout');later(50,poll)
  end
  later(50,poll)
end
local function command(action,nextStep)
  assert(not pending,'Overlapping baseline fixture request')
  pending={action=action,done=nextStep,deadline=g_clock.millis()+7000}
  g_game.talk('/passivebaseline '..action)
  later(7100,function()assert(not pending or pending.action~=action,'Fixture '..action..' timeout')end)
end
local function finish()
  command('cleanup',function()
    assert(not modules.game_passives.getState().active,'Unexpected overlay during baseline')
    g_game.safeLogout()
    wait('safe logout',function()return not g_game.isOnline()end,function()
      finished=true;print('PASSIVES_BASELINE_OK enabled='..tostring(enabled));g_app.exit()
    end,10000)
  end)
end
local function castHealing()
  lastMana=player:getMana();minimumMana=lastMana;healed=false
  g_game.talk('exura')
  wait('Light Healing payment and effective healing',function()return minimumMana<lastMana and healed end,function()
    assert(lastMana-minimumMana==20,'Light Healing mana differs from20: '..(lastMana-minimumMana))
    print('PASSIVES_BASELINE_LIGHT_HEALING_OK mana=20')
    finish()
  end)
end
local function castAxe()
  command('status',function(state)
    assert(state.leftEmpty and state.rightId==2428,'Wrong-hand fixture not established')
    local target=g_map.getCreatureById(state.targetId)
    assert(target,'Baseline target not visible')
    lastMana=player:getMana();minimumMana=lastMana
    g_game.attack(target);g_game.talk('exori sec')
    wait('Head Splitter ordinary payment',function()return minimumMana<lastMana end,function()
      assert(lastMana-minimumMana==20,'Head Splitter mana differs from20: '..(lastMana-minimumMana))
      print('PASSIVES_BASELINE_HEAD_SPLITTER_OK rightOnly=true mana=20')
      -- Same real spell while its4s cooldown is still active; no cost on rejection.
      g_game.talk('exori sec')
      later(500,function()
        assert(lastMana-minimumMana==20,'Rejected cooldown recast spent mana')
        print('PASSIVES_BASELINE_REJECTED_RECAST_OK')
        g_game.cancelAttack()
        command('quiet',function()later(400,castHealing)end)
      end)
    end)
  end)
end
local function online()
  EnterGame.hide();player=g_game.getLocalPlayer()
  connect(player,{
    onManaChange=function(_,mana)if minimumMana then minimumMana=math.min(minimumMana,mana)end end,
    onHealthChange=function(_,health,maximum,oldHealth)if oldHealth and health>oldHealth then healed=true end end
  })
  connect(g_game,{onTextMessage=function(_,text)
    print('PASSIVES_BASELINE_MESSAGE '..text)
    local encoded=text:match('^PASSIVES_BASELINE (.+)$');if not encoded then return end
    local ok,data=pcall(json.decode,encoded);if not ok then fail(data);return end
    if not data.ok then fail(data.error or data.action);return end
    if pending and pending.action==data.action then
      local nextStep=pending.done;pending=nil;later(100,function()nextStep(data)end)
    end
  end})
  command('status',function(state)
    enabled=state.enabled
    if PASSIVES_BASELINE_EXPECT_ENABLED~=nil then assert(enabled==PASSIVES_BASELINE_EXPECT_ENABLED,'Unexpected native config mode')end
    assert(not modules.game_passives.getState().active,'Baseline requires no active overlay')
    print('PASSIVES_BASELINE_MODE enabled='..tostring(enabled))
    command('fixed',function(fixed)
      assert(fixed.nativeDamage==37 and fixed.nativeHeal==17 and fixed.areaLoss==74 and fixed.areaTargets==3 and fixed.critRestored)
      assert(fixed.manaShieldHP==0 and fixed.manaShieldMana==37 and fixed.shieldRemoved,'Native mana shield regression')
      print('PASSIVES_BASELINE_FIXED_NATIVE_OK')
      print('PASSIVES_BASELINE_MANASHIELD_OK hpLoss=0 manaLoss=37')
      command('dot',function(dot)
        assert(dot.strongTicks==5000 and dot.coexist and dot.cureIsolated)
        print('PASSIVES_BASELINE_STANDARD_CONDITIONS_OK damage='..dot.damage)
        command('scheduler',function(scheduler)
          assert(scheduler.liveCallbackRan and not scheduler.canceledCallbackRan,'Existing Lua scheduler regression')
          print('PASSIVES_BASELINE_SCHEDULER_OK')
          command('equipright',function()
            command('quiet',function()
              -- Original login/teleport pacification and spell exhaustion still apply.
              later(11000,castAxe)
            end)
          end)
        end)
      end)
    end)
  end)
end
later(200,function()
  assert(LOCAL_PASSIVES_TEST and Services.updater=='' and g_resources.getLayout()=='retro')
  g_settings.set('window-maximized',false);g_window.resize({width=1280,height=800})
  connect(g_game,{onGameStart=function()later(300,online)end})
  g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
  G.account='passivetest';G.password='passivetest'
  login=ProtocolLogin.create();_G.passivesBaselineLogin=login
  login.onLoginError=function(_,err)fail(err)end
  login.onCharacterList=function(_,chars)
    for _,c in ipairs(chars)do
      if c.name=='Passive Tester'then g_game.loginWorld(G.account,G.password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return end
    end
    fail('Disposable Passive Tester character missing')
  end
  login:login('127.0.0.1',7174,G.account,G.password,'',false)
end)
scheduleEvent(function()if not finished then fail('120second hard limit')end end,118000)
