-- Run two real clients concurrently. The existing -Peer option isolates profile.
local peer=PASSIVES_PROBE_CAP=='store_compete_peer'
local name,account,password='Passive Tester','passivetest','passivetest'
if peer then name,account,password='Store Buyer','storebuyer','storebuyer' end
local done,failed,attempts=false,false,0
local login,loginAttempts,loginGeneration=nil,0,0
local entered,retryScheduled=false,false
local function fail(why)
 if done or failed then return end;failed=true;print('STORE_VALIDATION_COMPETITION_FAILED '..tostring(why))
 if g_game.isOnline()then g_game.safeLogout()end;scheduleEvent(function()g_app.exit()end,300)
end
local function request()
 attempts=attempts+1;if attempts>40 then fail('First buyer did not prepare');return end
 g_game.talk('/validationstore '..(peer and 'compete_ready' or 'compete_prepare'))
end
local function disableAutomaticReconnect()
 g_settings.set('autoReconnect',false)
 local button=g_ui.getRootWidget():recursiveGetChildById('autoReconnect')
 if button then button:setOn(false)end
end
local connectWorld
local function retryLogin(why)
 if done or failed or retryScheduled then return end
 if entered then fail(why);return end
 if loginAttempts>=8 then fail('Login attempts exhausted: '..tostring(why));return end
 retryScheduled=true;loginGeneration=loginGeneration+1
 print('STORE_VALIDATION_COMPETITION_LOGIN_RETRY role='..(peer and 'peer' or 'primary')..' reason='..tostring(why))
 if login then login:disconnect()end;g_game.cancelLogin()
 scheduleEvent(function()
  if done or failed then return end;retryScheduled=false;connectWorld()
 end,1600)
end
connectWorld=function()
 if done or failed or entered then return end
 loginAttempts=loginAttempts+1;loginGeneration=loginGeneration+1
 local generation=loginGeneration
 print('STORE_VALIDATION_COMPETITION_LOGIN role='..(peer and 'peer' or 'primary')..' attempt='..loginAttempts)
 login=ProtocolLogin.create();_G.storeCompetitionLogin=login
 login.onLoginError=function(_,why)retryLogin(why)end
 login.onCharacterList=function(_,characters)
  if generation~=loginGeneration or done or failed then return end
  for _,c in ipairs(characters)do if c.name==name then
   if c.worldIp~='127.0.0.1' or c.worldPort~=7175 then fail('Non-loopback game world');return end
   g_game.loginWorld(account,password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return
  end end
  fail('Owned competition character missing')
 end
 login:login('127.0.0.1',7174,account,password,'',false)
 scheduleEvent(function()
  if generation==loginGeneration and not entered and not done and not failed then retryLogin('login watchdog')end
 end,6000)
end
scheduleEvent(function()
 assert(LOCAL_PASSIVES_TEST and Services.updater=='' and g_resources.getLayout()=='retro')
 disableAutomaticReconnect()
 connect(g_game,{
  onGameStart=function()
   entered=true;loginGeneration=loginGeneration+1
   print('STORE_VALIDATION_COMPETITION_ENTERED role='..(peer and 'peer' or 'primary'))
   scheduleEvent(function()EnterGame.hide();disableAutomaticReconnect();request()end,350)
  end,
  onTextMessage=function(_,text)
   local raw=text:match('^STORE_VALIDATION_NATIVE (.+)$');if not raw then return end
   local ok,why=xpcall(function()
    local row=json.decode(raw);print(text)
    if row.label=='FAILED'then error(row.error)
    elseif row.label=='competition_pending' and peer then scheduleEvent(request,500)
    elseif row.label=='competition_complete'then
     assert(row.realDistinctSessions and row.firstItems==1 and row.secondItems==0 and row.firstDebit==100 and row.secondDebit==0 and row.sellerNet==90)
     done=true;print('STORE_VALIDATION_COMPETITION_OK role='..(peer and 'peer' or 'primary'))
     g_game.safeLogout();scheduleEvent(function()g_app.exit()end,500)
    end
   end,debug.traceback);if not ok then fail(why)end
  end,
  onLoginError=retryLogin,onConnectionError=retryLogin,
 })
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 connectWorld()
end,peer and 1800 or 200)
scheduleEvent(function()if not done then fail('Two-client competition timed out')end end,45000)
