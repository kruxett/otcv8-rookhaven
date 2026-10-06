-- Disposable GUID9005 only. Runner corrupts/repairs its passive ledger offline.
local cold=PASSIVES_PROBE_CAP=='cold'
local manual=PASSIVES_PROBE_CAP=='manual'
local recovering=PASSIVES_PROBE_CAP=='repair'or cold or manual
local done,failed,disconnected=false,false,false
local mod,login
local function fail(e)
 if done or failed then return end;failed=true
 print('PASSIVES_PERMANENT_FAULT_FAILED '..tostring(e))
 if g_game.isOnline()then g_game.safeLogout()else g_game.cancelLogin()end
 scheduleEvent(function()g_app.exit()end,700)
end
local function later(ms,fn)
 scheduleEvent(function()if done or failed then return end;local ok,e=pcall(fn);if not ok then fail(e)end end,ms)
end
local function success()
 done=true
 print('PASSIVES_PERMANENT_FAULT_OK '..(manual and 'manual' or cold and 'cold' or recovering and 'repaired' or 'rejected'))
 if cold then g_game.talk('/passivepermanent clearstore')end
 if g_game.isOnline()then g_game.safeLogout()end
 scheduleEvent(function()g_app.exit()end,700)
end
local function awaitResult()
 local deadline=g_clock.millis()+16000
 local function poll()
  if recovering then
   local s=mod.getState()
   if g_game.isOnline()and s.ready and s.active then
    assert(s.mode=='permanent'and s.tree.id=='reaver'and s.points==((cold or manual)and 17 or 16),'Wrong repaired profile/point tuning')
    if cold then
     assert(s.respecCost==777 and s.respecCount==1,'Cold reconnect used fallback fees')
     assert(s.ranks.minor_vitality==5 and g_game.getLocalPlayer():getMaxHealth()==808,'Cold reconnect used fallback balance')
     print('PASSIVES_PERMANENT_COLD_TUNING_OK points=17 fee=777 maxHP=808')
    end
    assert(mod.getReopenButton(),'Repaired profile lacks ordinary UI')
    if manual then
     assert(s.ranks.cap_berserker==1 and s.respecCount==3 and s.respecCost==4000,'Manual fixture ledger not restored')
     assert(g_game.getLocalPlayer():getMaxHealth()==803,'Manual fixture derived HP not restored')
     g_window.resize({width=1280,height=800});mod.selectNode('cap_berserker')
     later(500,function()g_app.doScreenshot('/passives-permanent-manual-ready.png');success()end);return
    end
    success();return
   end
  elseif disconnected then
   assert(not g_game.isOnline()and not mod.getState().active,'Corrupt saved profile entered world')
   assert(not mod.getWindow()and not mod.getStatusWindow(),'Corrupt login retained passive UI')
   success();return
  end
  assert(g_clock.millis()<deadline,'Expected login rejection/recovery timeout')
  later(100,poll)
 end
 later(300,poll)
end
later(250,function()
 assert(LOCAL_PASSIVES_TEST and Services.updater=='' and g_resources.getLayout()=='retro')
 mod=assert(modules.game_passives)
 connect(g_game,{
  onGameStart=function()EnterGame.hide();if not recovering then fail('Corrupt profile emitted onGameStart')end end,
  onLoginError=function(e)print('PASSIVES_PERMANENT_FAULT_LOGIN_ERROR '..tostring(e));if recovering then fail(e)else disconnected=true end end,
  onConnectionError=function(e)print('PASSIVES_PERMANENT_FAULT_DISCONNECT '..tostring(e));if recovering then fail(e)else disconnected=true end end,
 })
 G.account,G.password=manual and 'passiveclass'or 'passivelegacy',manual and 'passiveclass'or 'passivelegacy'
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 login=ProtocolLogin.create();_G.permanentFaultLogin=login
 login.onLoginError=function(_,e)fail('Account login failed: '..tostring(e))end
 login.onCharacterList=function(_,list)
  for _,c in ipairs(list)do if c.name==(manual and 'Passive Initiate'or 'Passive Veteran')then
   g_game.loginWorld(G.account,G.password,c.worldName,c.worldIp,c.worldPort,c.name,'','')
   awaitResult();return
  end end
  fail('Fault fixture character absent')
 end
 login:login('127.0.0.1',7174,G.account,G.password,'',false)
end)
