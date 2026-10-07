-- Actual ordinary permanent player, native capstone actions and exact budgets.
local cap=PASSIVES_PROBE_CAP
local reaver=cap=='bloodguard';local account=reaver and'classreaver'or'classearthshaker'
local name=reaver and'Starter Reaver'or'Starter Earthshaker'
local mod,login,metrics;local serial=0;local failed,done,intentional=false,false,false
local builds={
 bloodguard={minor_resilience=4,minor_recovery=5,major_guard=1,major_recovery=2,mid_stout_heart=2,path_blood_return=1,cap_bloodguard=1},
 stonebond={minor_resilience=4,minor_recovery=5,major_guard=2,major_recovery=1,mid_stout_heart=2,path_blood_return=1,cap_stonebond=1},
 stoneguard={minor_efficiency=4,minor_resilience=4,minor_focus=1,major_guard=2,major_pressure=1,mid_measured_breath=2,path_battle_sustenance=1,cap_stoneguard=1},
}
local function fail(reason)
 if failed or done then return end;failed=true;print('PASSIVES_GUARD_BALANCE_FAILED '..cap..' '..tostring(reason))
 if g_game.isOnline()then g_game.cancelAttack();g_game.talk('/passiveguardbalanceqa cleanup '..cap);g_game.safeLogout()end
 scheduleEvent(function()g_app.exit()end,700)
end
local function later(ms,fn)scheduleEvent(function()if failed or done then return end;local ok,e=pcall(fn);if not ok then fail(e)end end,ms)end
local function wait(label,pred,fn)
 local deadline=g_clock.millis()+15000
 local function poll()if pred()then fn();return end;assert(g_clock.millis()<deadline,label..' timeout');later(70,poll)end
 later(100,poll)
end
local function setup()
 g_game.setFightMode(FightDefensive);local before=serial;g_game.talk('/passiveguardbalanceqa setup '..cap)
 wait('isolated guard setup',function()return serial>before and metrics.label=='setup'end,function()
  local s=mod.getState();assert(s.active and s.mode=='permanent'and s.tree.id==(reaver and'reaver'or'earthshaker'))
  local spent=0;for _,rank in pairs(builds[cap])do spent=spent+rank end
  assert(spent==16 and not mod.validateDraft(builds[cap]),'Legal ordinary16-point connected build required')
  for _,rank in pairs(s.ranks)do assert(rank==0,'Disposable guard ledger was not reset')end
  local revision=s.revision
  g_game.getProtocolGame():sendExtendedOpcode(103,json.encode({v=1,action='apply',session=s.session,revision=revision,requestId='ordinary-guard-budget',ranks=builds[cap]}))
  wait('actual native ordinary Apply',function()return mod.getState().revision==revision+1 and mod.getState().ranks['cap_'..cap]==1 end,function()
   assert(mod.getState().respecCount==0,'First allocation unexpectedly consumed Respec')
   g_game.talk('/passiveguardbalanceqa run '..cap)
  end)
 end)
end
later(200,function()
 assert(builds[cap]and LOCAL_PASSIVES_TEST and Services.updater==''and g_resources.getLayout()=='retro')
 mod=assert(modules.game_passives)
 connect(g_game,{onGameStart=function()
  EnterGame.hide();wait('permanent handshake',function()local s=mod.getState();return s.ready and s.active and s.mode=='permanent'and s.tree end,setup)
 end,onTextMessage=function(_,text)
  local payload=text:match('^PASSIVE_GUARD_BALANCE_QA (.+)$');if not payload then return end
  print(text);metrics=json.decode(payload);serial=serial+1
  if metrics.label=='failed'then fail(metrics.error)
  elseif metrics.label=='cast-ready'then
   assert(cap=='stoneguard'and metrics.charges>=1 and metrics.charges<=3,'Unexpected actual spell cue')
   later(100,function()g_game.talk('exori mal grav')end) -- Actual native instant spell path/payment/cooldown.
  elseif metrics.label=='done'then
   intentional=true;g_game.safeLogout()
   wait('ordinary logout',function()return not g_game.isOnline()end,function()
    done=true;print('PASSIVES_GUARD_BALANCE_OK '..cap..' actualOrdinaryPlayer=true actualNativeActions=true exactBudget=true');g_app.exit()
   end)
  end
 end,onLoginError=function(e)fail(e)end,onConnectionError=function(e)if not intentional then fail(e)end end})
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 G.account,G.password=account,account;login=ProtocolLogin.create();_G.guardBalanceLogin=login
 login.onLoginError=function(_,e)fail(e)end
 login.onCharacterList=function(_,chars)
  for _,c in ipairs(chars)do if c.name==name then g_game.loginWorld(G.account,G.password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return end end
  fail('Owned ordinary class fixture missing')
 end
 login:login('127.0.0.1',7174,G.account,G.password,'',false)
end)
scheduleEvent(function()if not done then fail('180-second guard balance timeout')end end,180000)
