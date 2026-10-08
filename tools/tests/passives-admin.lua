-- Actual native client/server admin API probe, disposable loopback GUID9001 only.
local mode=PASSIVES_PROBE_CAP or 'off'
local login,failed,finished,finishing,registeredStatus,deathIssued=false,false,false,false,false,false
local characterRole,characterHelp,characterStatus,characterRoleCases=nil,false,false,0
local function fail(reason)
 if failed or finished then return end;failed=true;print('PASSIVES_ADMIN_FAILED '..tostring(reason))
 if g_game.isOnline()then g_game.safeLogout()end
 scheduleEvent(function()g_app.exit()end,400)
end
local function later(ms,fn)scheduleEvent(function()if failed or finished then return end;local ok,e=pcall(fn);if not ok then fail(e)end end,ms)end
local function wait(label,predicate,nextStep)
 local deadline=g_clock.millis()+15000
 local function poll()if predicate()then nextStep();return end;assert(g_clock.millis()<deadline,label..' timed out');later(70,poll)end
 later(120,poll)
end
later(200,function()
 assert(LOCAL_PASSIVES_TEST and Services.updater==''and g_resources.getLayout()=='retro')
 connect(g_game,{onGameStart=function()
  EnterGame.hide();wait('passive handshake',function()return modules.game_passives.getState().ready end,function()
   later(500,function()
    assert(not modules.game_passives.getWindow()or not modules.game_passives.getWindow():isVisible(),'Login opened full passive tree')
    if mode=='persist'then
     local s=modules.game_passives.getState();assert(s.active and s.points==7 and s.ranks.minor_vitality==2 and s.respecCount==1,'Actual reconnect lost saved QA profile')
    end
    local function audit()deathIssued=mode=='death';g_game.talk('/passiveadminqa '..mode..(mode=='cleanup'and' 3'or''))end
    if mode=='exercise'then
     g_game.talk('/passiveadmin status')
     wait('registered /passiveadmin status',function()return registeredStatus end,audit)
    else audit()end
   end)
  end)
 end,onTextMessage=function(_,text)
  local beginning=text:match('^PASSIVE_ADMIN_CHARACTER_ROLE_BEGIN group=(%d+) account=1$')
  if beginning then characterRole=beginning;characterHelp=false;characterStatus=false end
  if characterRole and text:find('^DEV QA: /passiveadmin status')then characterHelp=true end
  if characterRole and text:find('^QA status:')then characterStatus=true end
  local ending=text:match('^PASSIVE_ADMIN_CHARACTER_ROLE_END group=(%d+) account=1$')
  if ending then
   if ending~=characterRole or not characterHelp or not characterStatus then fail('Character-role help/status denied');return end
   characterRoleCases=characterRoleCases+1;print('PASSIVES_ADMIN_CHARACTER_CHAT_OK group='..ending..' account=1 actualHelp=true actualStatus=true')
   characterRole=nil
  end
  if text:find('^QA status:')then registeredStatus=true;print('PASSIVES_ADMIN_REGISTERED_TALKACTION_OK')end
  if text:find('^PASSIVE_ADMIN_')then print(text)end
  if text:find('PASSIVE_ADMIN_QA_FAILED',1,true)then fail(text);return end
  if text=='PASSIVE_ADMIN_QA_OK '..mode then
   if mode=='exercise'and characterRoleCases~=2 then fail('Admin and God character-role chat checks missing');return end
   if mode=='death'then print('PASSIVES_ADMIN_DEATH_CONNECTION_ENDED serverMessageReceived=true')end
   print('PASSIVES_ADMIN_CASE_OK '..mode);finishing=true;g_game.safeLogout()
   wait('clean logout',function()return not g_game.isOnline()end,function()
    finished=true;print('PASSIVES_ADMIN_OK mode='..mode..' actualNativeClient=true actualServerApi=true');g_app.exit()
   end)
  end
 end,onLoginError=function(e)fail(e)end,onConnectionError=function(e)
  if mode=='death'and deathIssued and not failed and not finished then
   finished=true;print('PASSIVES_ADMIN_DEATH_CONNECTION_ENDED expectedNativeDeathDisconnect=true serverGuardEvidenceRequired=true');g_app.exit()
  elseif not finishing and not finished then fail(e)end
 end})
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 G.account,G.password='passivetest','passivetest'
 login=ProtocolLogin.create();_G.passiveAdminAuditLogin=login
 login.onLoginError=function(_,e)fail(e)end
 login.onCharacterList=function(_,characters)
  for _,c in ipairs(characters)do if c.name=='Passive Tester'then g_game.loginWorld(G.account,G.password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return end end
  fail('Owned Passive Tester absent')
 end
 login:login('127.0.0.1',7174,G.account,G.password,'',false)
end)
scheduleEvent(function()if not finished then fail('Admin audit45s timeout')end end,45000)
