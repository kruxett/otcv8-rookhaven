-- Actual normal DEV client against the owned local server, with QA overlays off.
-- Only the runner's disposable copy scripts the updater response.
local mod,login,phase,step,request= nil,nil,PASSIVES_PROBE_CAP,0,0
local done,failed,intentional=false,false,false
local results,messages={},{}
local function fail(reason)
 if done or failed then return end;failed=true
 print('PASSIVES_DEV_ONLINE_FAILED '..tostring(reason))
 if g_game.isOnline()then g_game.safeLogout()else g_game.cancelLogin()end
 scheduleEvent(function()g_app.exit()end,400)
end
local function later(ms,fn)
 scheduleEvent(function()if done or failed then return end;local ok,e=pcall(fn);if not ok then fail(e)end end,ms)
end
local function wait(label,predicate,fn)
 local deadline=g_clock.millis()+16000
 local function poll()if predicate()then fn();return end;assert(g_clock.millis()<deadline,label..' timeout');later(60,poll)end
 later(100,poll)
end
local function state()return mod.getState()end
local function packet(action,fn,extra)
 request=request+1;local id='dev-online:'..request
 local data={v=1,action=action,session=state().session,revision=state().revision,requestId=id}
 if extra then for k,v in pairs(extra)do data[k]=v end end
 if action=='reset'then data.quotedCost=state().respecCost;data.respecCount=state().respecCount end
 g_game.getProtocolGame():sendExtendedOpcode(103,json.encode(data))
 wait(id,function()return results[id]~=nil end,function()fn(results[id])end)
end
local function finish()
 intentional=true;g_game.safeLogout()
 wait('offline',function()return not g_game.isOnline()end,function()
  assert(not state().ready and not state().active,'Logout retained feature access')
  done=true;print('PASSIVES_DEV_ONLINE_OK phase='..phase..' normalDev=true testOverlays=false')
  scheduleEvent(function()g_app.exit()end,300)
 end)
end
local function loginWorld()
 local admin=phase=='admin';local account=admin and 'passivetest'or 'passivemagic'
 local character=admin and 'Passive Tester'or 'Passive Mystic'
 G.account,G.password=account,account
 login=ProtocolLogin.create();_G.devOnlineLogin=login
 login.onLoginError=function(_,e)fail(e)end
 login.onCharacterList=function(_,chars)
  for _,c in ipairs(chars)do if c.name==character then g_game.loginWorld(account,account,c.worldName,c.worldIp,c.worldPort,c.name,'','');return end end
  fail('Owned disposable character missing')
 end
 login:login('127.0.0.1',7174,account,account,'',false)
end
local function applyOne(fn)
 assert(mod.changeRank(1,'minor_power'),'Ordinary rank purchase rejected')
 local revision=state().revision;mod.apply()
 wait('ordinary Apply',function()return state().revision>revision and not state().pending end,function()
  assert(state().ranks.minor_power==1 and state().mode=='permanent','Native save missing');fn()
 end)
end
local function enabled()
 assert(state().mode=='permanent' and state().classId=='lifekeeper' and state().classLocked,'Ordinary class restore missing')
 assert(state().points==16 and #state().tree.nodes==29,'Wrong level40 catalog/budget')
 assert(state().respecCount==0 and state().respecCost==0,'Expected fresh disposable ledger')
 assert(mod.ClassSpells.getState().catalog.classId=='lifekeeper' and #mod.ClassSpells.getState().catalog.spells==2,'Missing learned starter catalog')
 local ranks={};for k,v in pairs(state().ranks)do assert(v==0,'Expected zero disposable ranks');ranks[k]=v end
 -- Invalid and stale requests must not mutate the authoritative saved build.
 ranks.cap_aegis=1
 packet('apply',function(reply)
  assert(reply.ok==false and state().ranks.cap_aegis==0,'Orphan capstone accepted')
  applyOne(function()
   mod.show();g_app.doScreenshot('/passives-dev-normal-player.png')
   intentional=true;g_game.safeLogout()
   wait('first offline',function()return not g_game.isOnline()end,function()
    step=1;later(1700,loginWorld)
   end)
  end)
 end,{ranks=ranks})
end
local function restored()
 assert(state().ranks.minor_power==1 and state().classId=='lifekeeper' and state().respecCount==0,'Ordinary relog lost chosen class/rank')
 packet('reset',function(reply)
  assert(reply.ok and state().ranks.minor_power==0 and state().respecCount==1 and state().respecCost==1000,'First free respec failed')
  applyOne(function()
   packet('reset',function(paid)
    assert(paid.ok and state().ranks.minor_power==0 and state().respecCount==2 and state().respecCost==2000,'Paid respec failed')
    assert(state().classId=='lifekeeper' and #mod.ClassSpells.getState().catalog.spells==2,'Respec changed class/learning')
    finish()
   end)
  end)
 end)
end
local function online()
 EnterGame.hide();intentional=false
 if phase=='disabled'then
  later(1500,function()assert(not state().ready and not state().active and not mod.getWindow() and not mod.ClassSpells.getButton(),'Disabled server exposed feature');finish()end)
 elseif phase=='admin'then
  wait('enabled ack without class',function()return state().ready end,function()
   assert(not state().active,'Admin unexpectedly has a test overlay')
   local before=#messages;g_game.talk('/passivetest start reaver')
   wait('local QA rejection',function()return #messages>before end,function()
    local found=false;for i=before+1,#messages do if messages[i]:lower():find('local',1,true)then found=true end end
    assert(found and not state().active,'Test overlay leaked onto ordinary DEV');finish()
   end)
  end)
 else
  wait('ordinary handshake/catalog',function()return state().ready and state().active and state().tree and mod.ClassSpells.getState().catalog end,function()
   if step==0 then enabled()else restored()end
  end)
 end
end
later(200,function()
 assert(not LOCAL_PASSIVES_TEST and UPDATER_CHANNEL=='dev' and APP_VERSION==10085,'Expected normal DEV release identity')
 assert(Services.updater=='http://updater2.rookhaven-ot.com/api/updater' and Servers.Default=='testserver2.rookhaven-ot.com:7173:860','Release endpoints changed')
 assert(g_resources.getLayout()=='retro','Retro layout required')
 wait('DEV startup modules',function()return modules.game_passives and ProtocolGame end,function()
 mod=assert(modules.game_passives);g_window.resize({width=1280,height=800})
 ProtocolGame.registerExtendedJSONOpcode(103,function(_,_,data)if data.action=='result' and data.requestId then results[data.requestId]=data end end)
 connect(g_game,{onGameStart=online,onTextMessage=function(_,text)messages[#messages+1]=text;print('PASSIVES_DEV_ONLINE_MESSAGE '..text)end,
  onLoginError=fail,onConnectionError=function(e)if not intentional then fail(e)end end})
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA);loginWorld()
 end)
end)
scheduleEvent(function()if not done then fail('Bounded90second timeout')end end,88000)
