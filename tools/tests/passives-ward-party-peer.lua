-- Real second client: joins a native party, then casts legacy Heal Friend.
local done,login,joining=false,nil,false
local function later(ms,fn)scheduleEvent(function()if not done then local ok,e=pcall(fn);if not ok then done=true;print('PASSIVES_WARD_PEER_FAILED '..tostring(e));g_app.exit()end end end,ms)end
local function joinLoop()
 if not g_game.isOnline()then return end
 for _,c in ipairs(g_map.getSpectators(g_game.getLocalPlayer():getPosition(),false))do
  if c:getName()=='Passive Tester'and not joining then joining=true;g_game.partyJoin(c:getId());later(1300,function()joining=false end)end
 end
 later(1000,joinLoop)
end
later(200,function()
 assert(LOCAL_PASSIVES_TEST and Services.updater==''and g_resources.getLayout()=='retro')
 connect(g_game,{onGameStart=function()
  EnterGame.hide();print('PASSIVES_WARD_PEER_READY');later(1000,joinLoop)
 end,onTextMessage=function(_,text)
  print('PASSIVES_WARD_PEER_MESSAGE '..text)
  local signal=text:match('^PASSIVEQA_WARD_SIGNAL (.+)$')
  if signal and signal:match('^heal:')then
   local state=modules.game_passives.getState()
   assert(state.tree and state.tree.id=='lifekeeper'and state.ranks.cap_aegis==1,'Peer must have native Aegis')
   g_game.talk('exura sio "Passive Tester"')
  elseif signal=='finish'then
   g_game.safeLogout();done=true;print('PASSIVES_WARD_PEER_OK');scheduleEvent(function()g_app.exit()end,800)
  end
 end})
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 G.account='passivepeer';G.password='passivepeer';login=ProtocolLogin.create();_G.wardPeerLogin=login
 login.onLoginError=function(_,err)done=true;print('PASSIVES_WARD_PEER_FAILED '..err);g_app.exit()end
 login.onCharacterList=function(_,chars)for _,c in ipairs(chars)do if c.name=='Passive Peer'then g_game.loginWorld(G.account,G.password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return end end end
 login:login('127.0.0.1',7174,G.account,G.password,'',false)
end)
scheduleEvent(function()if not done then done=true;print('PASSIVES_WARD_PEER_FAILED timeout');if g_game.isOnline()then g_game.safeLogout()end;scheduleEvent(function()g_app.exit()end,800)end end,230000)
