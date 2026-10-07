-- Owned group1 native casts, ordinary stopEvent and orderly pending shutdown.
local mod,login,fixture,spellMetric;local fixtureSerial,spellSerial=0,0
local done,failed,expectShutdown=false,false,false
local function fail(e)
 if failed or done then return end;failed=true;print('PASSIVES_SHUTDOWN_FAILED '..tostring(e))
 if g_game.isOnline()then g_game.cancelAttack();g_game.talk('/passiveshutdownqa cleanup');g_game.talk('/classspellqa cleanup');g_game.safeLogout()end
 scheduleEvent(function()g_app.exit()end,600)
end
local function later(ms,fn)scheduleEvent(function()if failed or done then return end;local ok,e=pcall(fn);if not ok then fail(e)end end,ms)end
local function wait(label,pred,fn)
 local deadline=g_clock.millis()+15000
 local function poll()if pred()then fn();return end;assert(g_clock.millis()<deadline,label..' timeout');later(60,poll)end
 later(100,poll)
end
local function qa(command,label,fn)
 local before=fixtureSerial;g_game.talk('/passiveshutdownqa '..command)
 wait('shutdown fixture '..command,function()return fixtureSerial>before and fixture.label==label end,function()fn(fixture)end)
end
local function classQA(command,fn)
 local before=spellSerial;g_game.talk('/classspellqa '..command)
 wait('class fixture '..command,function()return spellSerial>before and spellMetric.label==command end,function()fn(spellMetric)end)
end
local function begin()
 local state=mod.getState();assert(state.active and state.mode=='permanent'and state.tree.id=='earthshaker')
 for _,rank in pairs(state.ranks)do assert(rank==0,'Shutdown fixture requires the empty owned starter ledger')end
 classQA('setup',function()later(11000,function()classQA('focus',function()
  qa('cancel','armed',function()
   local before=fixtureSerial;g_game.talk('exevo mal ton')
   wait('actual cancellation cast',function()return fixtureSerial>before and fixture.label=='cancel-cast'end,function()
    assert(fixture.stopEvent and fixture.pendingActions>=1)
    later(1100,function()qa('state','cancel-state',function(m)
     assert(m.delayedExecuted and m.stopEventReleased and m.pendingActions==0)
     print('PASSIVES_SHUTDOWN_DELAYED_CANCEL_OK actualRollingThunder=true actualStopEvent=true pendingActions=0')
     later(3500,function()qa('shutdown','armed',function()
      expectShutdown=true;g_game.talk('exevo mal ton')
     end)end)
    end)end)
   end)
  end)
 end)end)end)
end
later(200,function()
 assert(LOCAL_PASSIVES_TEST and Services.updater==''and g_resources.getLayout()=='retro');mod=assert(modules.game_passives)
 connect(g_game,{onGameStart=function()
  EnterGame.hide();wait('permanent handshake',function()local s=mod.getState();return s.ready and s.active and s.tree end,begin)
 end,onTextMessage=function(_,text)
  local payload=text:match('^CLASS_SPELL_QA (.+)$')
  if payload then spellMetric=json.decode(payload);spellSerial=spellSerial+1;return end
  payload=text:match('^PASSIVE_SHUTDOWN_QA (.+)$');if not payload then return end
  print(text);fixture=json.decode(payload);fixtureSerial=fixtureSerial+1
  if fixture.label=='failed'or fixture.label:match('^unexpected')then fail(fixture.error or fixture.label)
  elseif fixture.label=='shutdown-cast'then
   assert(expectShutdown and fixture.pendingActions>=1 and fixture.realManagedTimer)
   -- Kicking the player can discard the final server text packet. The runner
   -- independently requires its fresh shutdown marker and native exit code.
   wait('ordinary shutdown disconnect',function()return not g_game.isOnline()end,function()
    done=true;print('PASSIVES_SHUTDOWN_CLIENT_OK ordinaryPlayer=true delayedCast=true stopEvent=true realPendingTimer=true');g_app.exit()
   end)
  end
 end,onConnectionError=function(e)if not expectShutdown then fail(e)end end,onLoginError=function(e)fail(e)end})
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 G.account,G.password='classearthshaker','classearthshaker';login=ProtocolLogin.create();_G.shutdownProbeLogin=login
 login.onLoginError=function(_,e)fail(e)end
 login.onCharacterList=function(_,chars)
  for _,c in ipairs(chars)do if c.name=='Starter Earthshaker'then g_game.loginWorld(G.account,G.password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return end end
  fail('Owned Earthshaker missing')
 end
 login:login('127.0.0.1',7174,G.account,G.password,'',false)
end)
scheduleEvent(function()if not done then fail('90-second shutdown probe timeout')end end,90000)
