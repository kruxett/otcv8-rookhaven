-- Ordinary group1 party recipient. Only the disposable Starter Reaver account.
local done,login=false,nil
local function fail(e)
 print('CLASS_SPELL_PEER_FAILED '..tostring(e));scheduleEvent(function()g_app.exit()end,500)
end
scheduleEvent(function()
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 connect(g_game,{onGameStart=function()
  EnterGame.hide();print('CLASS_SPELL_PEER_READY')
  scheduleEvent(function()done=true;g_game.safeLogout();scheduleEvent(function()print('CLASS_SPELL_PEER_OK');g_app.exit()end,1000)end,150000)
 end,onConnectionError=function(e)if not done then fail(e)end end})
 G.account,G.password='classreaver','classreaver';login=ProtocolLogin.create();_G.classSpellPeerLogin=login
 login.onLoginError=function(_,e)fail(e)end
 login.onCharacterList=function(_,chars)
  for _,c in ipairs(chars)do if c.name=='Starter Reaver'then g_game.loginWorld(G.account,G.password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return end end
  fail('Peer fixture missing')
 end
 login:login('127.0.0.1',7174,G.account,G.password,'',false)
end,200)
