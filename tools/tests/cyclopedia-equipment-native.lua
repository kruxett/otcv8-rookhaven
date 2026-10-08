-- Owned-loopback actual equipment absorption and rarity health-change probe.
local done,login=false
local function fail(reason)
 if done then return end;done=true;print('PASSIVES_EQUIPMENT_NATIVE_FAILED '..tostring(reason))
 if g_game.isOnline()then g_game.safeLogout()end;scheduleEvent(function()g_app.exit()end,500)
end
local function later(ms,fn)scheduleEvent(function()if not done then local ok,e=pcall(fn);if not ok then fail(e)end end end,ms)end
later(200,function()
 assert(LOCAL_PASSIVES_TEST and Services.updater=='')
 connect(g_game,{onGameStart=function()
  EnterGame.hide()
  connect(g_game,{onTextMessage=function(_,text)
   if text:find('PASSIVE_EQUIPMENT_STATS_FAILED',1,true)then fail(text)
   elseif text:find('PASSIVE_EQUIPMENT_STATS_OK',1,true)then
    print(text);g_game.safeLogout()
    later(700,function()assert(not g_game.isOnline());done=true;print('PASSIVES_EQUIPMENT_NATIVE_OK');g_app.exit()end)
   end
  end})
  later(600,function()g_game.talk('/passiveequipmentstats')end)
 end})
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 G.account='passivetest';G.password='passivetest';login=ProtocolLogin.create();_G.equipmentStatsLogin=login
 login.onLoginError=function(_,e)fail(e)end
 login.onCharacterList=function(_,chars)
  for _,c in ipairs(chars)do if c.name=='Passive Tester'then
   g_game.loginWorld(G.account,G.password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return
  end end;fail('Owned fixture absent')
 end
 login:login('127.0.0.1',7174,G.account,G.password,'',false)
end)
scheduleEvent(function()fail('Equipment probe timeout')end,20000)
