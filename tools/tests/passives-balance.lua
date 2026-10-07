-- Run only after root registers the disposable /passivebalanceqa server fixture.
local done,login=false,nil
local function finish(ok,reason)
 if done then return end;done=true
 print(ok and 'PASSIVES_BALANCE_OK' or 'PASSIVES_BALANCE_FAILED '..tostring(reason))
 if g_game.isOnline()then g_game.cancelAttack();g_game.safeLogout()end
 scheduleEvent(function()g_app.exit()end,1000)
end
scheduleEvent(function()
 assert(LOCAL_PASSIVES_TEST and Services.updater=='','Disposable local client required')
 connect(g_game,{onGameStart=function()
  EnterGame.hide()
  scheduleEvent(function()g_game.talk('/passivebalanceqa run')end,1700)
 end,onTextMessage=function(_,text)
  if text:find('PASSIVE_BALANCE_QA_EVIDENCE',1,true)then print(text)
  elseif text:find('PASSIVE_BALANCE_QA_OK',1,true)then finish(true)
  elseif text:find('PASSIVE_BALANCE_QA_FAILED',1,true)then finish(false,text)end
 end})
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 G.account='passivetest';G.password='passivetest';login=ProtocolLogin.create();_G.passivesBalanceLogin=login
 login.onLoginError=function(_,err)finish(false,err)end
 login.onCharacterList=function(_,chars)
  for _,c in ipairs(chars)do if c.name=='Passive Tester'then g_game.loginWorld(G.account,G.password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return end end
  finish(false,'Disposable tester missing')
 end
 login:login('127.0.0.1',7174,G.account,G.password,'',false)
end,200)
scheduleEvent(function()if not done then finish(false,'timeout')end end,220000)
