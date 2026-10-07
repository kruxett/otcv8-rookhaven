-- Actual ordinary GUID9007 client. Server controller is runtime-only/loopback.
local done,failed,intentional=false,false,false
local login,mode,sequence,metrics=nil,nil,0,nil
local deathObserved=false
local function fail(e)
 if done or failed then return end;failed=true;print('PASSIVES_PVP_PEER_FAILED '..tostring(e))
 if g_game.isOnline()then g_game.cancelAttack();g_game.safeLogout()end
 scheduleEvent(function()g_app.exit()end,600)
end
local function later(ms,fn)scheduleEvent(function()if done or failed then return end;local ok,e=pcall(fn);if not ok then fail(e)end end,ms)end
local function wait(label,pred,fn,timeout)
 local deadline=g_clock.millis()+(timeout or 16000)
 local function poll()if pred()then fn();return end;assert(g_clock.millis()<deadline,label..' timeout');later(100,poll)end
 later(100,poll)
end
local function loginPeer()
 G.account,G.password='classblademaster','classblademaster'
 login=ProtocolLogin.create();_G.passivesPvpPeerLogin=login
 login.onLoginError=function(_,e)fail(e)end
 login.onCharacterList=function(_,list)
  for _,c in ipairs(list)do if c.name=='Starter Blademaster'then
   assert(c.worldIp=='127.0.0.1'and c.worldPort==7175,'Non-loopback peer world')
   g_game.loginWorld(G.account,G.password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return
  end end;fail('Ordinary PvP peer absent')
 end
 login:login('127.0.0.1',7174,G.account,G.password,'',false)
end
local function disconnected()
 if failed or done then return end
 assert(intentional or mode=='death','Unexpected ordinary peer disconnect')
 if mode=='death'then assert(deathObserved,'Death reconnect began without an actual death event')end
 if mode=='finish'then done=true;print('PASSIVES_PVP_PEER_OK normalLogout=true');later(1,function()end);scheduleEvent(function()g_app.exit()end,400)
 else later(6000,loginPeer)end
end
local function observeDeath(event)
 if done or failed then return end
 local ok,e=pcall(function()
  assert(mode=='death','Unexpected peer death')
  if deathObserved then return end;deathObserved=true
  print('PASSIVES_PVP_PEER_NATIVE_DEATH_OK event='..event)
  intentional=true;later(1,function()if g_game.isOnline()then g_game.safeLogout()end end)
 end)
 if not ok then fail(e)end
end
local function sourceWatch()
 local before=sequence;g_game.talk('/passivepvpqa ack sourcewatch')
 wait('source logout observer',function()return sequence>before end,function()
  if metrics.sourcePresent then later(120,sourceWatch);return end
  assert(metrics.peerPresent and metrics.allStacks==0,'Source logout retained owned wounds on the connected peer')
  print('PASSIVES_PVP_PEER_SOURCE_LOGOUT_OK actualOwnerAbsent=true allStacks=0')
  g_game.talk('/passivepvpqa ack sourcegone')
 end)
end
later(200,function()
 assert(LOCAL_PASSIVES_TEST and Services.updater==''and g_resources.getLayout()=='retro')
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 connect(g_game,{
  onGameStart=function()
   EnterGame.hide();g_game.setSafeFight(true);g_game.setChaseMode(DontChase)
   intentional=false
   local m=assert(modules.game_passives)
   wait('ordinary peer class handshake',function()local s=m.getState();return s.ready and s.mode=='permanent'and s.tree and s.tree.id=='blademaster'end,function()
    if mode then
     if mode=='death'then assert(deathObserved,'Death relog lacks actual death evidence')end
     print('PASSIVES_PVP_PEER_RELOGIN_OK '..mode);g_game.talk('/passivepvpqa ack relog');mode=nil
    else print('PASSIVES_PVP_PEER_READY group=1 class=blademaster')end
   end)
  end,
  onGameEnd=function()local ok,e=pcall(disconnected);if not ok then fail(e)end end,
  onDeath=function()observeDeath('native')end,
  onTextMessage=function(_,text)
   -- With skill loss suppressed, native death immediately respawns this fixture
   -- and its real player-death event sends text instead of a relog-window packet.
   if text=='You are dead.'then observeDeath('server-text')end
   if text:find('PASSIVES_PVP_FIXTURE_FAILED',1,true)then fail(text);return end
   local raw=text:match('^PASSIVES_PVP_QA (.+)$');if raw then metrics=json.decode(raw);sequence=sequence+1 end
   local command=text:match('^PASSIVES_PVP_PEER_CONTROL (%S+)$')
   if command=='sourcewatch'then later(1,sourceWatch)
   elseif command=='death'then mode='death';deathObserved=false;g_game.talk('/passivepvpqa ack deatharmed')
   elseif command=='logout'or command=='finish'then
    mode=command;intentional=true;g_game.talk('/passivepvpqa ack '..command)
    later(100,function()g_game.safeLogout()end)
   elseif command then fail('Unsupported isolated peer control')end
  end,
  onLoginError=function(e)fail(e)end,
  onConnectionError=function(e)if not intentional and mode~='death'then fail(e)end end,
 })
 loginPeer()
end)
scheduleEvent(function()if not done then fail('ordinary PvP peer overall timeout')end end,330000)
