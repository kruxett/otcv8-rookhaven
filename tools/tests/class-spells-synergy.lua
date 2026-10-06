-- Actual ordinary-party class starters and one chosen passive capstone.
-- Root launches the classreaver peer and resets only disposable healer GUID9011.
local cap = PASSIVES_PROBE_CAP
if cap~='renewal'and cap~='aegis'and cap~='concord'then cap='renewal'end
local mod, spells, player, login, metrics
local sequence, requestNo = 0, 0
local failed, done, intentional = false, false, false
local notices, results = {}, {}
local peerName='Starter Reaver'
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
local builds={}
local routes={renewal='path_broad_stroke',aegis='path_deliberate_cut',concord='path_blood_return'}
local foundation={minor_precision=4,minor_power=4,minor_recovery=4,minor_vitality=3,minor_resilience=1}
local function fail(reason)
 if failed or done then return end;failed=true;print('CLASS_SPELLS_SYNERGY_FAILED '..tostring(reason))
 if g_game.isOnline()then g_game.cancelAttack();g_game.talk('/classspellqa cleanup');g_game.talk('/classspellqa unparty');g_game.safeLogout()else g_game.cancelLogin()end
 scheduleEvent(function()g_app.exit()end,700)
end
local function later(ms,fn)
 scheduleEvent(function()if done or failed then return end;local ok,e=pcall(fn);if not ok then fail(e)end end,ms)
end
local function wait(label,predicate,fn,ms)
 local deadline=g_clock.millis()+(ms or 12000)
 local function poll()if predicate()then fn();return end;assert(g_clock.millis()<deadline,label..' timeout');later(70,poll)end
 later(100,poll)
end
local function qa(cmd,fn)
 local before=sequence;local label=cmd:match('^%S+');g_game.talk('/classspellqa '..cmd)
 wait('fixture '..cmd,function()return sequence>before and metrics.label==label end,function()fn(metrics)end)
end
local function catalog()return assert(spells.getState().catalog,'Learned spell catalog missing')end
local function entry(id)
 for _,s in ipairs(catalog().spells)do if s.id==id then return s end end
 error('Spell missing: '..id)
end
local function assertMendingBudget(actual, bonus, routeBonus, before, after)
 -- Independent L40/ML6 spell formula, then native foundation rounding and the
 -- separate route fractional ledger. Enumerate the real integer roll outcomes.
 local level, ml = player:getLevel(), player:getMagicLevel()
 assert(level==40 and ml==6,'Unexpected healing fixture level/magic level')
 local low=math.floor(level/5+ml*1.6+9+0.5)
 local high=math.floor(level/5+ml*2.0+11+0.5)
 local carry=before and before.runtime.routeHealingFraction or 0
 local matched=false
 for roll=low,high do
  local boosted=math.floor(roll*(1+(bonus or 0)/100)+0.5)
  local exact=boosted*(routeBonus or 0)/100+carry
  local extra=math.floor(exact+1e-9)
  if actual==boosted+extra then
   if before and after then
    assert(after.runtime.routeRawHealingBonus-before.runtime.routeRawHealingBonus==extra,'Route heal did not consume its exact bonus budget')
    assert(math.abs(after.runtime.routeHealingFraction-(exact-extra))<0.00001,'Route healing fractional carry changed')
   end
   matched=true;break
  end
 end
 assert(matched,'Actual Mending heal '..actual..' does not match the independent rounded/route budget')
end
local function sawNotice(after,needle)
 for n=after+1,#notices do if notices[n]:lower():find(needle,1,true)then return true end end
 return false
end
local function awaitReady(kind,fn)
 wait('real shared '..kind..' cooldown',function()return(spells.getState().shared[kind]or 0)<=g_clock.millis()end,fn)
end
local function setNamedTarget()
 assert(spells.show());spells.getWindow():getChildById('targetName'):setText(peerName)
end
local function assertPeer(m)
 assert(m.peer and m.peer.maxHP==735,'Expected ordinary base-HP Reaver peer')
end
local function assertTargetsUnchanged(before,after)
 local hp={};for _,t in ipairs(before.targets)do hp[t.id]=t.hp end
 assert(#before.targets==3 and #after.targets==3,'Expected the same three dummy targets')
 for _,t in ipairs(after.targets)do assert(t.hp==hp[t.id],'Healing damaged a dummy')end
end
local function finish()
 qa('cleanup',function()qa('unparty',function()
  intentional=true;g_game.safeLogout();wait('final logout',function()return not g_game.isOnline()end,function()
   assert(not spells.getWindow()and not spells.getButton()and not spells.getState().catalog,'Logout retained class-spell UI')
   done=true;print('CLASS_SPELLS_SYNERGY_OK '..cap);g_app.exit()
  end)
 end)end)
end
local function synergyHeal()
 awaitReady('healing',function()qa('reset',function()qa('peerhurt',function(before)
  assertPeer(before);assert(before.party and before.peer.party,'No real shared party')
  local proc=before.runtime.capstoneProcCount;setNamedTarget();assert(spells.cast('mending_thread'))
  later(250,function()qa('state',function(after)
   local direct=after.peer.hp-before.peer.hp
   assert(entry('mending_thread').mana==22 and before.mana-after.mana==22,'First capstone heal did not pay its independent22-mana base cost')
   assert(after.hp==before.hp,'Named heal changed caster HP')
   assertTargetsUnchanged(before,after)
   assert(after.runtime.capstoneProcCount==proc+1 and after.runtime.lastCapstoneProc==(cap=='renewal'and'Renewal'or'Aegis'),'Capstone did not activate once')
   if cap=='renewal'then
    assertMendingBudget(direct,3.5,2,before,after)
    local hot=math.floor(direct*.20)
    assert(after.runtime.hotRemaining==hot and after.runtime.hotHealed==before.runtime.hotHealed,'Renewal first snapshot does not match its budget')
    g_app.doScreenshot('/class-spells-renewal-party-direct.png')
    later(6600,function()qa('state',function(last)
     assert(last.peer.hp-after.peer.hp==hot,'Real party HoT differs from allocated budget')
     assert(last.runtime.hotRemaining==0 and last.runtime.hotHealed-before.runtime.hotHealed==hot,'HoT did not consume exact native budget')
     assert(last.runtime.capstoneProcCount==proc+1,'HoT recursively created more Renewal activations')
     print('CLASS_SPELLS_RENEWAL_PARTY_ONCE_OK direct='..direct..' hot='..hot)
     g_app.doScreenshot('/class-spells-renewal-party-complete.png');finish()
    end)end)
   else
    assert((before.runtime.routePreparedMs or 0)==0,'Aegis fixture unexpectedly prepared Mending Sequence')
    assertMendingBudget(direct,4.5,1,before,after)
    assert(after.runtime.wardRecipients==1,'Aegis did not shield exactly the healed party receiver')
    assert(after.runtime.ward==0,'Named-party Aegis shield was applied to the caster')
    print('CLASS_SPELLS_AEGIS_PARTY_ONCE_OK direct='..direct)
    g_app.doScreenshot('/class-spells-aegis-party.png');finish()
   end
  end)end)
 end)end)end)
end
local function concord()
 qa('reset',function()qa('peerhurt',function()qa('focus',function()
  later(250,function()qa('state',function(before)
   assertPeer(before);assert(before.party and before.peer.party,'Concord party absent')
   assert(before.peer.hp*before.maxHP<before.hp*before.peer.maxHP,'Peer is not the lowest-HP party candidate')
   local hp={};for _,t in ipairs(before.targets)do hp[t.id]=t.hp end
   local proc=before.runtime.capstoneProcCount
   assert(spells.cast('essence_lash'))
   later(120,function()qa('stop',function()later(120,function()qa('state',function(after)
    local actual,hits=0,0
    for _,t in ipairs(after.targets)do local loss=assert(hp[t.id])-t.hp;if loss>0 then actual=actual+loss;hits=hits+1 end end
    assert(hits==1 and actual>0,'Essence Lash did not cause one real monster hit')
    local heal=math.min(math.floor(actual*.40),math.floor(before.peer.maxHP*.02))
    assert(heal>0 and after.peer.hp-before.peer.hp==heal,'Concord party heal does not match actual spell damage/cap')
    assert(entry('essence_lash').mana==12 and before.mana-after.mana==12,'Concord attack did not pay its independent12-mana cost')
    assert(after.runtime.capstoneProcCount==proc+1 and after.runtime.lastCapstoneProc=='Concord','Essence Lash generated duplicate or missing Concord proc')
    print('CLASS_SPELLS_CONCORD_ESSENCE_PARTY_ONCE_OK damage='..actual..' heal='..heal)
    g_app.doScreenshot('/class-spells-concord-essence-party.png');finish()
   end)end)end)end)
  end)end)
 end)end)end)
end
local function applyBuild()
 qa('setup',function()qa('party',function()
  -- Actual additive purchase through the normal revision-validated Apply packet.
  builds[cap]=capstoneBuild(mod.getState().tree,routes[cap],foundation,cap=='concord'and'minor_power'or'minor_precision')
  local ranks={};local total=0
  for id in pairs(mod.getState().nodes)do ranks[id]=builds[cap][id]or 0;total=total+ranks[id]end
  assert(ranks['cap_'..cap]==1,'Route does not reach the requested class capstone')
  assert(total==16 and not mod.validateDraft(ranks),'Chosen legal capstone build is invalid')
  requestNo=requestNo+1;local id='class-synergy:'..requestNo
  local s=mod.getState();local revision=s.revision
  g_game.getProtocolGame():sendExtendedOpcode(103,json.encode({v=1,action='apply',session=s.session,revision=revision,requestId=id,ranks=ranks}))
  wait('ordinary capstone allocation',function()return results[id]~=nil and mod.getState().revision>revision end,function()
   assert(results[id].ok and mod.getState().ranks['cap_'..cap]==1,'Server rejected ordinary capstone purchase')
   mod.setStatusVisible(true)
   print('CLASS_SPELLS_CAP_ALLOCATED_OK '..cap)
   if cap=='concord'then later(11000,concord)else synergyHeal()end
  end)
 end)end)
end
local function rejectedNamed(label,fn)
 qa('reset',function()qa('state',function(before)
  local note=#notices;g_game.talk(entry('mending_thread').words..' "'..peerName..'"')
  later(250,function()qa('state',function(after)
   assert(before.mana==after.mana and before.hp==after.hp and before.peer.hp==after.peer.hp,label..' altered mana or HP')
   assertTargetsUnchanged(before,after)
   assert(sawNotice(note,'party member'),'Named rejected heal lacked its actual party/range feedback')
   print('CLASS_SPELLS_MENDING_REJECT_OK '..label);fn()
  end)end)
 end)end)
end
local function partyGates()
 qa('unparty',function(m)
  assert(not m.party and not m.peer.party,'Fixture did not remove party')
  rejectedNamed('nonparty',function()qa('party',function()qa('partyfar',function(m)
   assert(m.party and m.peer.party,'Out-of-range test lost its party')
   rejectedNamed('outside-heal-friend-7x5',applyBuild)
  end)end)end)
 end)
end
local function namedBaseline()
 qa('setup',function()qa('party',function(m)
  assertPeer(m);assert(m.party and m.peer.party,'Native party creation failed')
  qa('peerhurt',function(before)
   assertPeer(before);setNamedTarget();assert(spells.cast('mending_thread'))
   later(250,function()qa('state',function(after)
    local healed=after.peer.hp-before.peer.hp
    assert(before.mana-after.mana==entry('mending_thread').mana,'Named base Mending actual cost differs from catalog')
    assertMendingBudget(healed,0)
    assert(after.hp==before.hp,'Named party heal accidentally healed caster')
    assertTargetsUnchanged(before,after)
    assert(after.runtime.capstoneProcCount==before.runtime.capstoneProcCount,'Empty tree emitted a passive capstone proc')
    print('CLASS_SPELLS_MENDING_PARTY_OK heal='..healed)
    g_app.doScreenshot('/class-spells-mending-real-party.png')
    awaitReady('healing',partyGates)
   end)end)
  end)
 end)end)
end
later(250,function()
 assert(LOCAL_PASSIVES_TEST and Services.updater==''and g_resources.getLayout()=='retro')
 mod=assert(modules.game_passives);spells=assert(mod.ClassSpells)
 g_settings.set('window-maximized',false);g_window.resize({width=1280,height=800})
 ProtocolGame.registerExtendedJSONOpcode(103,function(_,_,data)if data.action=='result'and data.requestId then results[data.requestId]=data end end)
 connect(g_game,{
  onTextMessage=function(_,message)
   print('CLASS_SPELLS_SYNERGY_MESSAGE '..message)
   if message:find('CLASS_SPELL_QA_FAILED',1,true)then fail(message);return end
   local raw=message:match('^CLASS_SPELL_QA (.+)$');if raw then metrics=json.decode(raw);sequence=sequence+1 else notices[#notices+1]=message end
  end,
  onGameStart=function()
   EnterGame.hide();player=assert(g_game.getLocalPlayer())
   wait('permanent Lifekeeper with two learned spells',function()
    local s=mod.getState();return s.ready and s.active and s.mode=='permanent'and s.tree.id=='lifekeeper'and spells.getState().catalog~=nil
   end,function()
    local spent=0;for _,rank in pairs(mod.getState().ranks)do spent=spent+rank end
    assert(spent==0 and mod.getState().points>=16,'Runner must seed a learned Lifekeeper with empty ranks and16points')
    namedBaseline()
   end)
  end,
  onLoginError=function(e)fail(e)end,
  onConnectionError=function(e)if not intentional and not done then fail(e)end end,
 })
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 G.account,G.password='classlifekeeper','classlifekeeper'
 login=ProtocolLogin.create();_G.classSynergyLogin=login
 login.onLoginError=function(_,e)fail(e)end
 login.onCharacterList=function(_,list)
  for _,c in ipairs(list)do if c.name=='Starter Lifekeeper'then g_game.loginWorld(G.account,G.password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return end end
  fail('Ordinary Lifekeeper fixture missing')
 end
 login:login('127.0.0.1',7174,G.account,G.password,'',false)
end)
scheduleEvent(function()if not done then fail('120-second party synergy timeout')end end,120000)
