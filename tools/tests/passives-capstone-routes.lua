-- Live authoritative connected-path matrix. Disposable GUID9001 overlay only.
-- Every accepted route spends exactly the ordinary level-40 budget (16 points).
local classes={'reaver','blademaster','earthshaker','marksman','arcanist','lifekeeper'}
local mod,login,done,failed,finishing
local replies,serial={},0
local totals={accepted=0,rejected=0}
local function fail(e)
 if done or failed then return end;failed=true;print('PASSIVES_CAPSTONE_ROUTES_FAILED '..tostring(e))
 if g_game.isOnline()then g_game.cancelAttack();g_game.talk('/passiveqa quiesce Passive Tester');g_game.safeLogout()end
 scheduleEvent(function()g_app.exit()end,600)
end
local function later(ms,fn)scheduleEvent(function()if done or failed then return end;local ok,e=pcall(fn);if not ok then fail(e)end end,ms)end
local function wait(label,pred,fn)
 local deadline=g_clock.millis()+10000
 local function poll()if pred()then fn();return end;assert(g_clock.millis()<deadline,label..' timeout');later(40,poll)end
 later(60,poll)
end
local function s()return mod.getState()end
local function sum(r)local n=0;for _,v in pairs(r)do n=n+v end;return n end
local function copy(r)local n={};for id,v in pairs(r)do n[id]=v end;return n end
local function same(a,b)for id,v in pairs(a)do if v~=(b[id]or 0)then return false end end;for id,v in pairs(b)do if v~=(a[id]or 0)then return false end end;return true end
local function command(text,fn)g_game.talk(text);later(350,fn)end
local function node(id)for _,n in ipairs(s().tree.nodes)do if n.id==id then return n end end;error('Unknown node '..id)end
local function base(path)
 local r={[path.ownCoreId]=2,[path.secondaryCoreId]=1,[path.minorId]=2,[path.advancedId]=1}
 for _,g in ipairs(s().tree.branchGroups)do if(r[g.majorId]or 0)>0 then r[g.minorIds[1]]=3;r[g.minorIds[2]]=1 end end
 assert(sum(r)==14,'route lineage no longer fourteen points');return r
end
local function pad(r,total)
 r=copy(r);for _,id in ipairs(s().tree.topology.foundationMinorIds)do local add=math.min(5-(r[id]or 0),total-sum(r));if add>0 then r[id]=(r[id]or 0)+add end end
 assert(sum(r)==total,'cannot fill budget');return r
end
local function packet(label,r,legal,fn)
 local rev,session,saved=s().revision,s().session,copy(s().ranks)
 local err=mod.validateDraft(r);assert((err==nil)==legal,'Client expectation differs '..label..': '..tostring(err))
 serial=serial+1;local request='connected-routes:'..serial
 g_game.getProtocolGame():sendExtendedOpcode(103,json.encode({v=1,action='apply',session=session,revision=rev,requestId=request,ranks=r}))
 wait(label..' result',function()return replies[request]~=nil end,function()
  local result=replies[request];assert(result.ok==legal,'Native verdict differs '..label..': '..tostring(result.error))
  if legal then
   wait(label..' snapshot',function()return s().revision==rev+1 and same(r,s().ranks)end,function()
    assert(sum(s().ranks)==16,'normal first-capstone allocation not sixteen')
    totals.accepted=totals.accepted+1;print('PASSIVES_CONNECTED_ROUTE_ACCEPT_OK '..label);fn()
   end)
  else
   assert(s().revision==rev and s().session==session and same(saved,s().ranks),'Rejected packet changed authoritative ranks '..label)
   totals.rejected=totals.rejected+1;print('PASSIVES_CONNECTED_ROUTE_REJECT_OK '..label..' '..tostring(result.error));fn()
  end
 end)
end
local runClass,runPath
runPath=function(index,fn)
 local path=s().tree.topology.paths[index];if not path then fn();return end
 local label=s().tree.id..'/'..path.advancedId
 local lineage=base(path);local valid=pad(lineage,15);valid[path.capstoneId]=1
 local rejected={}
 local function add(name,r)rejected[#rejected+1]={name=name,ranks=r}end
 local r=copy(valid);r[path.minorId]=1;add('middle-rank-one',r)
 r=copy(valid);r[path.ownCoreId]=1;add('own-core-rank-one',r)
 r=copy(valid);r[path.secondaryCoreId]=0;add('no-supporting-core',r)
 r=copy(valid);r[path.advancedId]=0;add('capstone-bypass',r)
 r=copy(lineage);r[path.capstoneId]=1;add('only-fifteen-points',r)
 r=copy(valid);r[path.advancedId]=4;add('major-over-rank',r)
 r=copy(valid);r[path.minorId]=6;add('minor-over-rank',r)
 r=copy(valid);r[path.minorId]=1.5;add('fractional-rank',r)
 r=copy(valid);r.unknown_node=1;add('unknown-node',r)
 r=copy(valid);r[path.minorId]=-1;add('negative-rank',r)
 r=pad(valid,25);add('maximum-budget-exceeded',r)
 r=copy(valid);for _,id in ipairs(s().tree.topology.capstoneIds)do if id~=path.capstoneId then r[id]=1;break end end;add('two-capstones',r)
 r=copy(valid);r[path.capstoneId]=0;for _,id in ipairs(s().tree.topology.capstoneIds)do if id~=path.capstoneId then r[id]=1;break end end;add('wrong-capstone-lineage',r)
 local function rejection(i)
  local case=rejected[i];if not case then runPath(index+1,fn);return end
  packet(label..'/'..case.name,case.ranks,false,function()rejection(i+1)end)
 end
 packet(label..'/sixteen',valid,true,function()
  assert(mod.selectNode(path.advancedId),'advanced selection failed')
  if index==1 then g_app.doScreenshot('/passives-connected-'..s().tree.id..'.png')end
  rejection(1)
 end)
end
local function finish()
 assert(totals.accepted==36 and totals.rejected==468,'Incomplete connected route matrix')
 g_game.talk('/passivetest stop')
 wait('stop cleanup',function()return not s().active end,function()
  assert(g_game.getLocalPlayer():getMaxHealth()==735,'stop retained derived HP')
  finishing=true;g_game.safeLogout();wait('logout',function()return not g_game.isOnline()end,function()
   assert(not mod.getWindow()and not s().tree,'logout retained tree')
   done=true;print('PASSIVES_CAPSTONE_ROUTES_OK accepted='..totals.accepted..' rejected='..totals.rejected..' ordinaryBudget=16');scheduleEvent(function()g_app.exit()end,300)
  end)
 end)
end
runClass=function(index)
 local id=classes[index];if not id then finish();return end
 command('/passiveqa quiesce Passive Tester',function()command('/passiveqa equip '..id,function()
  local old=s().session;g_game.talk('/passivetest start '..id..', Passive Tester')
  wait('new catalog '..id,function()return s().active and s().tree and s().tree.id==id and s().session~=old end,function()
   assert(s().tree.schemaVersion==2 and #s().tree.nodes==29 and #s().tree.edges==36,'Wrong native catalog contract')
   assert(s().points==24,'Test budget changed')
   runPath(1,function()runClass(index+1)end)
  end)
 end)end)
end
later(200,function()
 assert(LOCAL_PASSIVES_TEST and Services.updater==''and g_resources.getLayout()=='retro')
 mod=assert(modules.game_passives)
 ProtocolGame.registerExtendedJSONOpcode(103,function(_,_,data)if data.action=='result'and data.requestId then replies[data.requestId]=data end end)
 g_settings.set('window-maximized',false);g_window.resize({width=1280,height=800})
 connect(g_game,{onGameStart=function()EnterGame.hide();wait('handshake',function()return s().ready end,function()runClass(1)end)end,onConnectionError=function(e)if not finishing then fail(e)end end})
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 G.account,G.password='passivetest','passivetest';login=ProtocolLogin.create();_G.connectedRoutesLogin=login
 login.onLoginError=function(_,e)fail(e)end
 login.onCharacterList=function(_,chars)for _,c in ipairs(chars)do if c.name=='Passive Tester'then g_game.loginWorld(G.account,G.password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return end end;fail('Fixture missing')end
 login:login('127.0.0.1',7174,G.account,G.password,'',false)
end)
scheduleEvent(function()if not done then fail('connected route matrix timeout')end end,120000)