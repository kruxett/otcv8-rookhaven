-- Isolated native/client lifecycle gate; requires the disposable passiveqa fixture.
-- Fixture additions: arcanist_death=2188; learn Wand Soul Drain; quiet preserves dummies
-- and teleports the disposable caster to arena offset(-2,0), out of dummy melee.
-- restartconduit runs quiet/start/legal preset atomically via the same
-- native authorization and combat gates, preventing baseline pulse interleaving.
-- Real Soul Drain callbacks run for36s. No charge/proc is forced by this probe.
local mod, player, login, metrics, metricsSequence = nil,nil,nil,nil,0
local failed,done,finishing=false,false,false
local castAt,oldSession,freshSession,baselineHp,afterSwitchHp=0,nil,nil,nil,nil
local function fail(reason)
 if failed or done then return end
 failed=true;print('PASSIVES_DELAYED_FAILED '..tostring(reason))
 if g_game.isOnline()then g_game.cancelAttack();g_game.talk('/passiveqa quiesce Passive Tester');g_game.talk('/passivetest stop');g_game.safeLogout()end
 scheduleEvent(function()g_app.exit()end,700)
end
local function later(ms,fn)
 scheduleEvent(function()if failed or done then return end;local ok,err=pcall(fn);if not ok then fail(err)end end,ms)
end
local function wait(label,predicate,nextStep,timeout)
 local deadline=g_clock.millis()+(timeout or 6000)
 local function poll()
  if predicate()then nextStep();return end
  assert(g_clock.millis()<deadline,label..' timeout');later(70,poll)
 end
 later(80,poll)
end
local function state()return mod.getState()end
local function commands(list,nextStep)
 local function step(n)
  if n>#list then later(180,nextStep);return end
  g_game.talk(list[n]);later(250,function()step(n+1)end)
 end
 step(1)
end
local function measure(nextStep)
 local before=metricsSequence;g_game.talk('/passiveqa metrics Passive Tester')
 wait('native metrics',function()return metricsSequence>before end,function()nextStep(metrics)end)
end
local function endTest(m)
 assert(m.targetHP<afterSwitchHp,'old target took no later baseline pulse damage')
 print('PASSIVES_DELAYED_BASELINE_CONTINUED '..json.encode({oldSession=oldSession,freshSession=freshSession,targetHPBefore=afterSwitchHp,targetHPAfter=m.targetHP,elapsedMs=g_clock.millis()-castAt}))
 commands({'/passiveqa quiesce Passive Tester','/passivetest stop'},function()
  assert(not state().active,'final stop retained native overlay')
  assert(player:getMaxHealth()==735,'final stop retained derived max HP')
  finishing=true;g_game.safeLogout()
  wait('logout cleanup',function()return not g_game.isOnline()end,function()
   assert(not state().tree and not mod.getWindow(),'logout retained passive UI')
   done=true;print('PASSIVES_DELAYED_OK');scheduleEvent(function()g_app.exit()end,400)
  end)
 end)
end
local function monitorFresh()
 measure(function(m)
  assert(g_game.isOnline() and player:getHealth()>0,'fixture died or disconnected')
  assert(m.profile.active and m.profile.session==freshSession,'fresh native session changed')
  assert(m.progress==0 and m.capstoneProcCount==0 and m.readyMs==0,'old callback affected fresh passive state '..json.encode(m))
  if g_clock.millis()-castAt>=8500 then assert(m.pendingActions==0,'stale passive action retained after session stop')end
  if g_clock.millis()-castAt>=37500 then endTest(m);return end
  later(900,monitorFresh)
 end)
end
local function switchSession()
 g_game.talk('/passivetest stop')
 wait('stop old session',function()return not state().active end,function()
  commands({'/passiveqa restartconduit'},function()
   wait('fresh atomic session despite old scheduled callbacks',function()return state().active and state().session~=oldSession and state().ranks.cap_conduit==1 end,function()
    freshSession=state().session
    measure(function(m)
     assert(m.profile.session==freshSession and m.progress==0 and m.capstoneProcCount==0,'fresh overlay inherited action state')
     afterSwitchHp=m.targetHP
     print('PASSIVES_DELAYED_FRESH_SESSION '..json.encode(m))
     monitorFresh()
    end)
   end,3000)
  end)
 end,3000)
end
local function firstHit()
 measure(function(m)
  assert(m.profile.session==oldSession,'initial session changed')
  assert(m.progress==1 and m.pendingActions>0,'Soul Drain first real hit did not count exactly one cast with pending callbacks '..json.encode(m))
  assert(m.capstoneProcCount==0,'one cast unexpectedly activated Conduit')
  baselineHp=m.targetHP
  print('PASSIVES_DELAYED_FIRST_HIT '..json.encode(m))
  later(math.max(100,castAt+4500-g_clock.millis()),function()
   measure(function(second)
    assert(second.targetHP<baselineHp,'second real Soul Drain pulse did not damage target')
    assert(second.progress==1 and second.pendingActions>0 and second.capstoneProcCount==0,'delayed pulse counted as another cast '..json.encode(second))
    print('PASSIVES_DELAYED_SECOND_PULSE_ONCE '..json.encode(second))
    switchSession()
   end)
  end)
 end)
end
local function cast()
 local target
 for _,c in ipairs(g_map.getSpectators(player:getPosition(),false))do
  if c:getName()=='Passive Test Dummy' and (not target or c:getId()<target:getId())then target=c end
 end
 assert(target,'arena target missing')
 -- Target is required by the existing spell. Cancel ordinary fire immediately
 -- after the first pulse; native fixture quiet also clears the actual server target
 -- and moves outside stationary dummy melee. Later damage must come from callbacks.
 g_game.attack(target)
 later(120,function()
  castAt=g_clock.millis();g_game.talk('exori gran mort')
  later(120,function()g_game.cancelAttack();commands({'/passiveqa quiet Passive Tester'},firstHit)end)
 end)
end
local function setup()
 commands({'/passiveqa quiesce Passive Tester','/passivetest stop','/passiveqa equip arcanist_death','/passiveqa learn','/passiveqa heal Passive Tester','/passivetest start arcanist','/passivetest preset Passive Tester,conduit','/passivetest trace Passive Tester,on','/passiveqa arena','/passiveqa join Passive Tester,1'},function()
  assert(state().active and state().tree.id=='arcanist' and state().ranks.cap_conduit==1,'initial legal native profile missing')
  oldSession=state().session
  -- Respect the normal login/teleport pacification interval.
  later(11000,cast)
 end)
end
local function online()
 EnterGame.hide();player=g_game.getLocalPlayer()
 connect(g_game,{onTextMessage=function(_,text)
  print('PASSIVES_DELAYED_MESSAGE '..text)
  local payload=text:match('^PASSIVEQA_METRICS (.+)$')
  if payload then metrics=json.decode(payload);metricsSequence=metricsSequence+1 end
 end})
 wait('handshake',function()return state().ready end,setup)
end
later(200,function()
 assert(LOCAL_PASSIVES_TEST and Services.updater=='' and g_resources.getLayout()=='retro')
 mod=assert(modules.game_passives)
 connect(g_game,{onGameStart=function()later(250,online)end,onConnectionError=function(err)if not finishing then fail(err)end end})
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 G.account='passivetest';G.password='passivetest'
 login=ProtocolLogin.create();_G.delayedPassiveLogin=login
 login.onLoginError=function(_,err)fail(err)end
 login.onCharacterList=function(_,chars)
  for _,c in ipairs(chars)do if c.name=='Passive Tester'then g_game.loginWorld(G.account,G.password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return end end
  fail('fixture missing')
 end
 login:login('127.0.0.1',7174,G.account,G.password,'',false)
end)
scheduleEvent(function()if not done then fail('65-second delayed lifecycle timeout')end end,65000)