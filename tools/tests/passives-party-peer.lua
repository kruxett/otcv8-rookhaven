-- A real second client and native party invitation/join; no passive overlay.
local login,started,joining,done
local function later(ms,fn)scheduleEvent(function()if not done then local ok,err=pcall(fn);if not ok then print('PASSIVES_PARTY_PEER_FAILED '..tostring(err));done=true;g_app.exit()end end end,ms)end
local function joinLoop()
 if not g_game.isOnline()then return end
 local mod=modules.game_passives
 assert(not mod.getState().active,'peer must have no passive overlay')
 for _,c in ipairs(g_map.getSpectators(g_game.getLocalPlayer():getPosition(),false))do
  if c:getName()=='Passive Tester'then
   -- Join is accepted by the server only after a real invitation.
   if not joining then joining=true;g_game.partyJoin(c:getId());later(1800,function()joining=false end)end
  end
 end
 later(1200,joinLoop)
end
later(200,function()
 assert(LOCAL_PASSIVES_TEST and Services.updater=='' and g_resources.getLayout()=='retro')
 connect(g_game,{onGameStart=function()print('PASSIVES_PARTY_PEER_READY');EnterGame.hide();later(1000,joinLoop)end})
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 G.account='passivepeer';G.password='passivepeer'
 login=ProtocolLogin.create();_G.partyPeerLogin=login
 login.onLoginError=function(_,err)print('PASSIVES_PARTY_PEER_FAILED '..err);done=true;g_app.exit()end
 login.onCharacterList=function(_,chars)for _,c in ipairs(chars)do if c.name=='Passive Peer'then g_game.loginWorld(G.account,G.password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return end end end
 login:login('127.0.0.1',7174,G.account,G.password,'',false)
end)
scheduleEvent(function()
 if g_game.isOnline()then g_game.cancelAttack();g_game.safeLogout()end
 done=true;print('PASSIVES_PARTY_PEER_OK');scheduleEvent(function()g_app.exit()end,700)
end,180000)
