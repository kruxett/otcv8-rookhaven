-- Ordinary GUID9007 only; offline runner seeds the ledger and checks saved gold.
local phase=PASSIVES_PROBE_CAP
local mod,spells,login,nextOnline,metrics
local seq,logins=0,0
local done,failed,intentional,rejected=false,false,false,false
local function fail(e)
 if done or failed then return end;failed=true;print('PASSIVES_ROUTE_REFUND_FAILED '..tostring(e))
 if g_game.isOnline()then g_game.safeLogout()else g_game.cancelLogin()end
 scheduleEvent(function()g_app.exit()end,600)
end
local function later(ms,fn)scheduleEvent(function()if done or failed then return end;local ok,e=pcall(fn);if not ok then fail(e)end end,ms)end
local function wait(label,pred,fn)
 local deadline=g_clock.millis()+16000
 local function poll()if pred()then fn();return end;assert(g_clock.millis()<deadline,label..' timeout');later(70,poll)end
 later(100,poll)
end
local function finish()
 intentional=true;if g_game.isOnline()then g_game.safeLogout()end
 wait('final offline',function()return not g_game.isOnline()end,function()
  done=true;print('PASSIVES_ROUTE_REFUND_OK '..phase..' logins='..logins);scheduleEvent(function()g_app.exit()end,350)
 end)
end
local function inspect(fn)
 local before=seq;g_game.talk('/classspellqa state')
 wait('ordinary fixture state',function()return seq>before and metrics.label=='state'end,function()
  local state=mod.getState();assert(metrics.profile.treeId=='blademaster'and state.mode=='permanent'and state.classLocked,'refund changed class')
  assert(state.points==16 and state.respecCount==2 and state.respecCost==2000,'refund changed points or price/counter')
  local expected={}
  if phase=='normalize'then expected={minor_precision=3,minor_critical=1,major_precision=2}
  elseif phase=='retain'then
   local path;for _,p in ipairs(state.tree.topology.paths)do if p.capstoneId=='cap_bladestorm'then path=p;break end end;assert(path,'Blade Storm route absent')
   expected={[path.ownCoreId]=2,[path.secondaryCoreId]=1,[path.minorId]=2,[path.advancedId]=1,cap_bladestorm=1}
   for _,g in ipairs(state.tree.branchGroups)do if(expected[g.majorId]or 0)>0 then expected[g.minorIds[1]]=3;expected[g.minorIds[2]]=1 end end
   local id=state.tree.topology.foundationMinorIds[1];expected[id]=(expected[id]or 0)+1
  end
  assert(state.tree.schemaVersion==2 and #state.tree.nodes==29,'Migration received an old catalog')
  for _,node in ipairs(state.tree.nodes)do assert((state.ranks[node.id]or 0)==(expected[node.id]or 0),'incorrect saved refund/retain ranks: '..node.id)end
  assert(not mod.validateDraft(state.ranks),'restored native ranks rejected by client')
  assert(metrics.learned['Focused Thrust']and metrics.learned.Flurry,'refund removed two learned starters')
  local c=spells.getState().catalog;assert(c and c.classId=='blademaster'and #c.spells==2,'missing retained starter catalog')
  print('PASSIVES_ROUTE_REFUND_LOGIN_OK phase='..phase..' login='..logins..' ranks='..json.encode(state.ranks))
  fn()
 end)
end
local function doLogin(fn)
 nextOnline=fn;G.account,G.password='classblademaster','classblademaster'
 login=ProtocolLogin.create();_G.routeRefundLogin=login
 login.onLoginError=function(_,e)fail('account login '..tostring(e))end
 login.onCharacterList=function(_,chars)
  for _,c in ipairs(chars)do if c.name=='Starter Blademaster'then
   g_game.loginWorld(G.account,G.password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return
  end end;fail('fixed ordinary fixture missing')
 end
 login:login('127.0.0.1',7174,G.account,G.password,'',false)
end
local function first()
 inspect(function()
  intentional=true;g_game.safeLogout()
  wait('first offline',function()return not g_game.isOnline()end,function()
   assert(not mod.getWindow(),'logout retained tree')
   later(6000,function()doLogin(function()inspect(finish)end)end)
  end)
 end)
end
later(200,function()
 assert(LOCAL_PASSIVES_TEST and Services.updater==''and g_resources.getLayout()=='retro')
 assert(phase=='refund'or phase=='refund_current'or phase=='normalize'or phase=='retain'or phase:find('^corrupt')~=nil or phase=='corrupt_new','unknown route-refund probe mode')
 mod=assert(modules.game_passives);spells=assert(mod.ClassSpells)
 connect(g_game,{
  onTextMessage=function(_,text)
   print('PASSIVES_ROUTE_REFUND_MESSAGE '..text)
   if text:find('CLASS_SPELL_QA_FAILED',1,true)then fail(text)end
   local raw=text:match('^CLASS_SPELL_QA (.+)$');if raw then metrics=json.decode(raw);seq=seq+1 end
  end,
  onGameStart=function()
   if phase:find('^corrupt')~=nil then fail('corrupt ledger entered world');return end
   EnterGame.hide();logins=logins+1;intentional=false
   local fn=nextOnline;nextOnline=nil
   wait('permanent handshake',function()local s=mod.getState();return s.ready and s.active and spells.getState().catalog end,fn)
  end,
  onLoginError=function(e)
   print('PASSIVES_ROUTE_REFUND_LOGIN_ERROR '..tostring(e))
   if phase:find('^corrupt')~=nil then rejected=true else fail(e)end
  end,
  onConnectionError=function(e)
   print('PASSIVES_ROUTE_REFUND_CONNECTION_ERROR '..tostring(e))
   if phase:find('^corrupt')~=nil then rejected=true elseif not intentional then fail(e)end
  end,
 })
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 doLogin(first)
 if phase:find('^corrupt')~=nil then wait('corrupt rejection',function()return rejected end,function()
  assert(not g_game.isOnline()and not mod.getState().active and not mod.getWindow(),'corrupt rejection activated passive UI');finish()
 end)end
end)
scheduleEvent(function()if not done then fail('route refund timeout')end end,50000)
