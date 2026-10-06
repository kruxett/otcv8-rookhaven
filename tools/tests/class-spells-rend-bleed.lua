-- Real ordinary GUID9006 Rend casts. Runtime observer delegates every real roll.
-- Requires an empty or identical legitimate16-point Bloodletting ledger.
local mod,spells,login,metrics
local seq,requests=0,0
local done,failed,intentional=false,false,false
local replies={}
-- Close the chosen route from the received v2 catalog, keeping every stable ID.
local function capstoneBuild(tree, advancedId, foundation, electiveId)
 assert(tree.schemaVersion==2 and tree.catalogVersion==2 and #tree.nodes==29,'29-node catalog required')
 local ranks,nodes,path={},{},nil
 for _,node in ipairs(tree.nodes)do ranks[node.id]=0;nodes[node.id]=node end
 for _,route in ipairs(tree.topology.paths)do if route.advancedId==advancedId then path=route;break end end
 assert(path,'Chosen advanced route missing')
 ranks[advancedId]=1;ranks[path.capstoneId]=1
 for _,required in ipairs(assert(nodes[advancedId].requires.all))do ranks[required.id]=required.rank end
 for _,required in ipairs(assert(nodes[path.minorId].requires.all))do ranks[required.id]=math.max(ranks[required.id],required.rank)end
 assert(ranks[path.minorId]==2 and ranks[path.ownCoreId]==2 and ranks[path.secondaryCoreId]==1,'Route gate contract changed')
 for _,branch in ipairs(tree.branchGroups)do if ranks[branch.majorId]>0 then
  local total=0
  for _,id in ipairs(branch.minorIds)do ranks[id]=foundation[id]or 0;total=total+ranks[id]end
  assert(total==branch.requiredMinorPoints,'Foundation allocation does not close '..branch.majorId)
 end end
 assert(nodes[electiveId].role=='foundationMinor','Elective must remain a foundation rank')
 ranks[electiveId]=ranks[electiveId]+1;assert(ranks[electiveId]<=nodes[electiveId].maxRank,'Elective exceeds rank cap')
 local total=0;for _,rank in pairs(ranks)do total=total+rank end
 assert(total==16 and not mod.validateDraft(ranks),'Chosen catalog closure is not a legal16-point build')
 return ranks
end
local build
local manaCarry=0
local function state()return mod.getState()end
local function sum(r)local n=0;for _,v in pairs(r or{})do n=n+v end;return n end
local function same(a,b)
 for id,rank in pairs(a or{})do if rank~=(b[id]or 0)then return false end end
 for id,rank in pairs(b or{})do if rank~=(a[id]or 0)then return false end end;return true
end
local function fail(e)
 if done or failed then return end;failed=true;print('CLASS_SPELLS_REND_BLEED_FAILED '..tostring(e))
 if g_game.isOnline()then g_game.cancelAttack();g_game.talk('/classspellqa rend cleanup');g_game.safeLogout()else g_game.cancelLogin()end
 scheduleEvent(function()g_app.exit()end,700)
end
local function later(ms,fn)scheduleEvent(function()if done or failed then return end;local ok,e=pcall(fn);if not ok then fail(e)end end,ms)end
local function wait(label,pred,fn)
 local deadline=g_clock.millis()+12000
 local function poll()if pred()then fn();return end;assert(g_clock.millis()<deadline,label..' timeout');later(60,poll)end
 later(100,poll)
end
local function qa(op,fn)
 local before=seq;g_game.talk('/classspellqa rend '..op)
 wait('Rend fixture '..op,function()return seq>before end,function()fn(metrics)end)
end
local function cast(case,prepared,fn)
 local mana=prepared.mana
 g_game.talk('exori sec vul')
 later(250,function()qa('state',function(m)
  local observed=assert(m.observation,'No actual Rend cast was observed')
  assert(observed.castResult==true and observed.actual>0,'Rend did not physically damage the target')
  assert(observed.actual==observed.expected,'Actual Rend damage differs from the genuine roll and eligible wound bonus')
  local bonus=case=='wound'
  assert(observed.ownStacksBefore==(bonus and 1 or 0),'Rend used the wrong active own-wound count')
  -- Power5 at0.5% and Pressure1 at1%; this route has no primary spell bonus.
  local factor=(1+(build.minor_power*.5+build.major_pressure)/100)*(bonus and 1.2 or 1)
  assert(math.abs(observed.factor-factor)<0.000001,'Wrong direct-damage or bleed-bonus factor')
  assert(observed.actual==math.floor(observed.raw*factor+.5),'Genuine roll does not match the independent Rend budget')
  -- Measured Breath2 gives2% discount. Resets/refills do not erase this ledger.
  local exact=12*.98+manaCarry;local cost=math.floor(exact+1e-9);manaCarry=exact-cost
  assert(mana-m.mana==cost,'Rend mana differs from the exact2%-discount fractional bill: '..cost)
  if case=='immune'then assert(m.accepted==false and m.ownStacks==0 and m.allStacks==0,'Bleed immune target retained a counted condition')end
  if case=='generator'then assert(m.generatorTicks>0 and m.allStacks==1 and m.ownStacks==0,'Completed generator was counted before its extended expiry')end
  print('CLASS_SPELLS_REND_BLEED_CASE_OK '..case..' '..json.encode(observed));fn()
 end)end)
end
local cases={'normal','immune','wound','generator'}
local runCase
runCase=function(index)
 local case=cases[index]
 if not case then
  -- Cleanup sends the ordinary fixture's status, not REND_BLEED_QA.
  intentional=true;g_game.talk('/classspellqa rend cleanup');g_game.talk('/classspellqa cleanup')
  later(350,function()g_game.safeLogout();wait('final logout',function()return not g_game.isOnline()end,function()
   done=true;print('CLASS_SPELLS_REND_BLEED_OK actual normal/immune/valid wound/finished generator Rend');scheduleEvent(function()g_app.exit()end,350)
  end)end);return
 end
 qa(case,function(m)
  assert(m.case==case and m.hp==1000000,'Fresh quiet diagnostic target required')
  if case=='immune'then assert(m.accepted==false and m.ownStacks==0 and m.allStacks==0,'Immune wound grant accepted')end
  if case=='wound'then assert(m.accepted==true and m.ownStacks==1,'Nonimmune player-owned wound not active')end
  -- Fixture arena teleports invoke the existing two-second stair pacification.
  if case~='generator'then later(2600,function()cast(case,m,function()runCase(index+1)end)end);return end
  assert(m.accepted and m.ownStacks==1 and m.allStacks==1 and m.generatorTicks>0,'Finite generator wound did not start')
  local deadline=g_clock.millis()+5000
  local function poll()
   qa('state',function(current)
    assert(current.hp>=999999,'Generator delivered more than its one-point budget')
    if current.hp==999999 then
     assert(current.generatorTicks>0 and current.allStacks==1,'Generator expired instead of exercising an empty pending list')
     assert(current.ownStacks==0,'Finished generator is a phantom active wound')
     cast(case,current,function()runCase(index+1)end)
    else assert(g_clock.millis()<deadline,'Generator tick did not occur');later(100,poll)end
   end)
  end
  later(2600,poll)
 end)
end
local function initial()
 local s=state();assert(s.mode=='permanent'and s.tree.id=='reaver'and s.points==16,'Expected ordinary level40 Reaver ledger')
 local c=spells.getState().catalog;assert(c and c.classId=='reaver'and #c.spells==2,'Two genuine learned starter spells required')
 build=capstoneBuild(s.tree,'path_battle_sustenance',{minor_power=4,minor_recovery=4},'minor_power')
 assert(build.cap_bloodletting==1 and build.minor_power==5 and build.major_pressure==1 and build.mid_measured_breath==2,'Independent Rend numeric fixture changed')
 manaCarry=0 -- Fresh native profile after ordinary login; no earlier casts.
 if same(s.ranks,build)then runCase(1);return end
 assert(sum(s.ranks)==0,'Requires empty or identical Bloodletting fixture; never removes existing permanent ranks')
 requests=requests+1;local request='rend-bleed:'..requests;local revision=s.revision
 assert(not mod.validateDraft(build),'UI rejected legal16-point Bloodletting build')
 g_game.getProtocolGame():sendExtendedOpcode(103,json.encode({v=1,action='apply',session=s.session,revision=revision,requestId=request,ranks=build}))
 wait('saved16 Bloodletting build',function()return replies[request]and state().revision>revision end,function()
  assert(replies[request].ok and same(state().ranks,build),'Native server rejected/mutated the legitimate allocation');runCase(1)
 end)
end
later(250,function()
 assert(LOCAL_PASSIVES_TEST and Services.updater==''and g_resources.getLayout()=='retro')
 mod=assert(modules.game_passives);spells=assert(mod.ClassSpells)
 ProtocolGame.registerExtendedJSONOpcode(103,function(_,_,data)if data.action=='result'and data.requestId then replies[data.requestId]=data end end)
 connect(g_game,{
  onGameStart=function()
   EnterGame.hide()
   wait('permanent handshake',function()local s=state();return s.ready and s.active and spells.getState().catalog end,function()
    -- Keep the existing ten-second login pacification in force.
    later(11000,initial)
   end)
  end,
  onTextMessage=function(_,text)
   print('CLASS_SPELLS_REND_MESSAGE '..text)
   if text:find('CLASS_SPELL_QA_FAILED',1,true)then fail(text)end
   local raw=text:match('^REND_BLEED_QA (.+)$');if raw then metrics=json.decode(raw);seq=seq+1 end
  end,
  onLoginError=function(e)fail(e)end,onConnectionError=function(e)if not intentional then fail(e)end end,
 })
 G.account,G.password='classreaver','classreaver'
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 login=ProtocolLogin.create();_G.rendBleedLogin=login
 login.onLoginError=function(_,e)fail(e)end
 login.onCharacterList=function(_,list)
  for _,c in ipairs(list)do if c.name=='Starter Reaver'then g_game.loginWorld(G.account,G.password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return end end;fail('Ordinary Reaver fixture missing')
 end
 login:login('127.0.0.1',7174,G.account,G.password,'',false)
end)
scheduleEvent(function()if not done then fail('ordinary Rend bleed regression timeout')end end,60000)
