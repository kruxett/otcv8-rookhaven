-- Actual ordinary GUID9006 Bloodletting/Rend PvP integration. No RNG/proc forcing.
local mod,spells,login,metrics,nextOnline,build
local sequence,requestSerial,manaCarry=0,0,0
local done,failed,intentional=false,false,false
local replies,notices={},{}
local function fail(e)
 if done or failed then return end;failed=true;print('PASSIVES_PVP_FAILED '..tostring(e))
 if g_game.isOnline()then g_game.cancelAttack();g_game.talk('/passivepvpqa cleanup');g_game.safeLogout()else g_game.cancelLogin()end
 scheduleEvent(function()g_app.exit()end,700)
end
local function later(ms,fn)scheduleEvent(function()if done or failed then return end;local ok,e=pcall(fn);if not ok then fail(e)end end,ms)end
local function wait(label,pred,fn,timeout)
 local deadline=g_clock.millis()+(timeout or 18000)
 local function poll()if pred()then fn();return end;assert(g_clock.millis()<deadline,label..' timeout');later(80,poll)end
 later(80,poll)
end
local function qa(command,fn)
 local before=sequence;local label=command:match('^%S+');g_game.talk('/passivepvpqa '..command)
 wait('fixture '..command,function()return sequence>before and metrics.label==label end,function()fn(metrics)end)
end
local function sum(r)local total=0;for _,v in pairs(r or{})do total=total+v end;return total end
local function same(a,b)
 for k,v in pairs(a or{})do if v~=(b[k]or 0)then return false end end
 for k,v in pairs(b or{})do if v~=(a[k]or 0)then return false end end;return true
end
local function capstoneBuild(tree)
 assert(tree.schemaVersion==2 and #tree.nodes==29,'29-node permanent catalog required')
 local ranks,nodes,path={},{},nil
 for _,n in ipairs(tree.nodes)do ranks[n.id]=0;nodes[n.id]=n end
 for _,r in ipairs(tree.topology.paths)do if r.advancedId=='path_battle_sustenance'then path=r;break end end
 assert(path and path.capstoneId=='cap_bloodletting')
 ranks[path.advancedId]=1;ranks[path.capstoneId]=1
 for _,r in ipairs(nodes[path.advancedId].requires.all)do ranks[r.id]=r.rank end
 for _,r in ipairs(nodes[path.minorId].requires.all)do ranks[r.id]=math.max(ranks[r.id],r.rank)end
 local foundation={minor_power=4,minor_recovery=4}
 for _,branch in ipairs(tree.branchGroups)do if ranks[branch.majorId]>0 then
  local n=0;for _,id in ipairs(branch.minorIds)do ranks[id]=foundation[id]or 0;n=n+ranks[id]end
  assert(n==branch.requiredMinorPoints,'Foundation gate changed')
 end end
 ranks.minor_power=ranks.minor_power+1
 assert(sum(ranks)==16 and ranks.mid_measured_breath==2 and ranks.minor_efficiency==0 and ranks.minor_focus==0,'Known legitimate Rend build changed')
 assert(not mod.validateDraft(ranks),'Native catalog rejected legal build');return ranks
end
local function ready(m)
 assert(m.source.profile.mode=='permanent'and m.source.profile.treeId=='reaver'and same(m.source.profile.ranks,build),'Class/ranks changed')
 assert(not m.source.exhaust and not m.source.pacified and m.source.mana>=12,'Spell-negative fixture was not otherwise ready')
 assert(m.peer.skull~=SkullBlack,'Exact ordinary PvP half requires a non-black target')
end
local function target(m)local c=g_map.getCreatureById(m.peer.id);assert(c,'Ordinary peer not visible');return c end
local function prepare(command,fn)
 g_game.cancelAttack();g_game.setSafeFight(false);g_game.setChaseMode(DontChase)
 qa(command,function()later(2700,function()qa('state',function(m)ready(m);fn(m)end)end)end)
end
local function cast(label,before,bonus,fn)
 g_game.attack(target(before))
 later(150,function()g_game.talk('exori sec vul');later(350,function()g_game.cancelAttack();qa('state',function(m)
  local o=assert(m.observation,'Actual Rend wrapper was never reached')
  assert(o.castResult and o.rolls==1 and o.actual>0 and o.actual==o.expected,'Real Rend roll differs from exact rounding then integer PvP half')
  assert(o.targetId==before.peer.id and o.targetSkull~=SkullBlack,'Rend damaged a different/black-skull target')
  assert((o.ownBefore>0)==bonus and o.factor==(bonus and 1.2 or 1),'Rend counted wrong own wound or unrelated PvE power')
  local independent=math.floor(math.floor(o.raw*(bonus and 1.2 or 1)+.5)/2)
  assert(o.actual==independent,'Independent raw/own-wound/PvP budget differs')
  local exact=12*.98+manaCarry;local bill=math.floor(exact+1e-9);manaCarry=exact-bill
  assert(before.source.mana-m.source.mana==bill,'Existing2% mana discount/fraction carry changed')
  print('PASSIVES_PVP_REND_OK '..label..' '..json.encode(o));fn(m)
 end)end)end)
end
local function pollState(label,pred,fn,timeout)
 local deadline=g_clock.millis()+(timeout or 18000)
 local function poll()qa('state',function(m)if pred(m)then fn(m);return end;assert(g_clock.millis()<deadline,label..' timeout');later(150,poll)end)end
 poll()
end
local function loginSource(fn)
 nextOnline=fn;G.account,G.password='classreaver','classreaver'
 login=ProtocolLogin.create();_G.passivesPvpLogin=login
 login.onLoginError=function(_,e)fail(e)end
 login.onCharacterList=function(_,list)
  for _,c in ipairs(list)do if c.name=='Starter Reaver'then
   assert(c.worldIp=='127.0.0.1'and c.worldPort==7175,'Non-loopback PvP source world')
   g_game.loginWorld(G.account,G.password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return
  end end;fail('Ordinary Reaver absent')
 end
 login:login('127.0.0.1',7174,G.account,G.password,'',false)
end
local function complete()
 qa('peercontrol finish',function()
  pollState('peer normal final logout',function(m)return not m.peerPresent end,function()
   qa('cleanup',function(m)
    assert(same(m.source.profile.ranks,build)and m.source.profile.respecCount==0,'Test mutated ranks/respec count')
    intentional=true;g_game.safeLogout();wait('source normal final logout',function()return not g_game.isOnline()end,function()
     done=true;print('PASSIVES_PVP_OK ordinaryPlayers=true sameObjectArenaRespawn=unmeasured');scheduleEvent(function()g_app.exit()end,350)
    end)
   end)
  end)
 end)
end
local function deathCheck()
 prepare('wound',function(m)
  assert(m.accepted and m.ownStacks==1,'Victim death requires real incoming special condition')
  local oldId=m.peer.id;local level=m.peer.level
  qa('peercontrol death',function()
   pollState('peer native death arm',function(s)return s.peerAck=='deatharmed'end,function()
    qa('death',function()
     pollState('victim death native reconnect',function(s)return s.peerPresent and s.peer.id~=oldId and s.peerAck=='relog'end,function(s)
      assert(s.allStacks==0 and s.peer.level==level,'Victim death/relogin retained wound or lost fixture level')
      print('PASSIVES_PVP_DEATH_OK actualNativeDeath=true incomingWounds=0 normalUnloadRelog=true sameObjectArenaRespawn=unmeasured');complete()
     end,32000)
    end)
   end)
  end)
 end)
end
local function ownerLogoutCheck()
 prepare('wound',function(m)
  assert(m.accepted and m.ownStacks==1,'Owner logout requires real pending wound')
  local peerId=m.peer.id
  qa('peercontrol sourcewatch',function()
   intentional=true;g_game.safeLogout()
   wait('actual source logout',function()return not g_game.isOnline()end,function()
    later(6000,function()loginSource(function()
     pollState('connected peer observed owner logout',function(s)return s.peerAck=='sourcegone'end,function(s)
      assert(s.peer.id==peerId and s.allStacks==0,'Owner logout retained wound or replaced recipient')
      print('PASSIVES_PVP_OWNER_LOGOUT_OK recipientStayedOnline=true allStacks=0');deathCheck()
     end)
    end)end)
   end)
  end)
 end)
end
local function victimLogoutCheck()
 prepare('wound',function(m)
  assert(m.accepted and m.ownStacks==1,'Recipient logout requires real pending wound')
  local oldId=m.peer.id
  qa('peercontrol logout',function()
   pollState('recipient logout',function(s)return not s.peerPresent end,function()
    pollState('recipient native relog',function(s)return s.peerPresent and s.peer.id~=oldId and s.peerAck=='relog'end,function(s)
     assert(s.allStacks==0,'Nonpersistent special wound reappeared on recipient login')
     print('PASSIVES_PVP_VICTIM_LOGOUT_OK savedSpecialWounds=0');ownerLogoutCheck()
    end,32000)
   end)
  end)
 end)
end
local function partyCheck()
 prepare('wound',function(m)
  assert(m.accepted and m.ownStacks==1);qa('party',function()cast('party-normal-engine-policy',m,true,function()
   qa('unparty',function()print('PASSIVES_PVP_PARTY_OK ordinaryEnginePermissionsPreserved=true');victimLogoutCheck()end)
  end)end)
 end)
end
local function pzTickCheck()
 prepare('wound',function(m)
  assert(m.accepted and m.ownStacks==1)
  qa('targetpz',function(entered)
   assert(entered.peer.zone==0,'PZ tick measurement did not enter a protection zone')
   local hp=entered.peer.hp
   pollState('PZ cancels actual wound',function(s)return s.allStacks==0 end,function(s)
    assert(s.peer.hp==hp,'New player wound damaged inside PZ');print('PASSIVES_PVP_PZ_TICK_OK damage=0 woundRemoved=true');partyCheck()
   end,6000)
  end)
 end)
end
local forbidden={'secure','nopvp','pztarget','pzcaster','self'}
local function forbiddenCase(index)
 local label=forbidden[index];if not label then pzTickCheck();return end
 prepare((label=='secure'or label=='self')and'reset'or label,function(before)
  -- Secure and self share the ordinary normal-zone preparation.
  if label=='secure'then g_game.setSafeFight(true)end
  later(120,function()qa('state',function(start)
   ready(start);assert(start.allStacks==0,'Forbidden attack starts with an old wound')
   local note=#notices
   g_game.attack(label=='self'and g_game.getLocalPlayer()or target(start))
   later(120,function()g_game.talk('exori sec vul');later(400,function()g_game.cancelAttack();qa(label=='self'and'blockedself'or'blockedprobe',function(after)
    assert(after.accepted==false and after.allStacks==0 and after.peer.hp==start.peer.hp and after.source.hp==start.source.hp and after.source.mana==start.source.mana,'Forbidden PvP action changed HP/mana/wounds')
    local noticesSeen=false;for n=note+1,#notices do if notices[n]:lower():find('exhaust',1,true)then error('Forbidden negative was only blocked by unrelated exhaustion')end;noticesSeen=true end
    assert(noticesSeen,'No ordinary denial from forbidden attack/cast')
    print('PASSIVES_PVP_FORBIDDEN_OK '..label..' unchangedHP=true unchangedMana=true noWounds=true')
    forbiddenCase(index+1)
   end)end)end)
  end)end)
 end)
end
local function cureCheck()
 prepare('wound',function(m)
  assert(m.accepted and m.ownStacks==1);qa('cure',function()
   pollState('normal bleeding dispel',function(s)return s.allStacks==0 end,function(s)
    assert(s.peer.poison,'Cure Bleeding removed unrelated poison');print('PASSIVES_PVP_CURE_OK woundRemoved=true poisonPreserved=true');forbiddenCase(1)
   end,5000)
  end)
 end)
end
local function budgetChecks()
 g_game.cancelAttack();g_game.setSafeFight(false)
 qa('cap',function(m)
  local r=assert(m.capResults);assert(#r==5 and r[1]and r[2]and r[3]and r[4]==false and r[5]and m.ownStacks==3 and m.allStacks==3,'Native three-wound/weak reject/strong replace failed')
  assert(m.peerOwnStacks==0,'Foreign owner counted recipient own wound')
  local hp=m.peer.hp
  later(6000,function()qa('state',function(s)
   assert(s.allStacks==0 and hp-s.peer.hp==21,'Native stronger replacement changed exact finite remaining budget')
   print('PASSIVES_PVP_CAP_BUDGET_OK syntheticPendingMarker=true maxOwn=3 weakerRejected=true strongerBudget=21 foreignSpecialOwnerIsolation=unmeasured')
   qa('expiry',function(e)
    assert(e.accepted and e.ownStacks==1);local before=e.peer.hp
    later(6000,function()qa('state',function(s2)
     assert(s2.allStacks==0 and before-s2.peer.hp==6,'Finite player wound did not spend exact budget once')
     print('PASSIVES_PVP_EXPIRY_OK syntheticPendingMarker=true budget=6 remaining=0');cureCheck()
    end)end)
   end)
  end)end)
 end)
end
local rendCases={{'reset',false,'no-wound'},{'wound',true,'own-wound'},{'legacyfinite',false,'foreign-legacy-finite'},{'legacyownfinite',false,'own-legacy-finite'},{'legacyinfinite',false,'legacy-infinite'}}
local function rendCase(index)
 local c=rendCases[index];if not c then budgetChecks();return end
 prepare(c[1],function(m)
  if c[1]~='reset'then assert(m.accepted,'Condition API scheduling probe rejected')end
  if c[1]=='legacyfinite'or c[1]=='legacyownfinite'or c[1]=='legacyinfinite'then assert(m.ownStacks==0 and m.allStacks==1,'Legacy condition became a Bloodletting wound')end
  cast(c[3],m,c[2],function()rendCase(index+1)end)
 end)
end
local function natural()
 prepare('natural',function(start)
  assert(start.ownStacks==0 and start.source.runtime.bloodHits==0,'Natural phase starts with old proc state')
  local previous=start.peer.hp;local positiveHits,lastHit=0,0
  local sourceHP=start.source.hp;local beforeProcs=start.source.runtime.procCount
  local deadline=g_clock.millis()+22000;g_game.attack(target(start))
  local function poll()qa('state',function(m)
   if m.peer.hp<previous then lastHit=previous-m.peer.hp;positiveHits=positiveHits+1;previous=m.peer.hp end
   assert(m.source.hp==sourceHP,'PvP hits enabled unrelated Recovery/route healing')
   if m.ownStacks>0 then
    assert(positiveHits==3 and m.ownStacks==1 and m.source.runtime.bloodHits==0,'Natural Bloodletting did not activate on exactly three successful ordinary hits')
    assert(m.source.runtime.procCount==beforeProcs+1,'Unrelated passive proc activated in PvP')
    local hp=m.peer.hp;local budget=math.max(1,math.floor(lastHit*.30));g_game.cancelAttack()
    qa('freeze',function()
     later(20500,function()qa('state',function(after)
      assert(after.allStacks==0 and hp-after.peer.hp==budget,'Natural wound budget was not30% of actual triggering PvP HP damage')
      local leechBudget=(start.peer.hp-hp)*(build.minor_recovery+build.major_recovery)*.2/100
      print('PASSIVES_PVP_NATURAL_OK successfulOrdinaryHits=3 triggerHP='..lastHit..' finiteBudget='..budget..' noOtherProcs=true observableHealing=0 hypotheticalLeechBudget='..leechBudget..' leechWholeUnitCovered='..tostring(leechBudget>=1));rendCase(1)
     end)end)
    end)
   else assert(g_clock.millis()<deadline,'Natural ordinary Bloodletting timeout');later(120,poll)end
  end)end
  poll()
 end)
end
local function begin()
 local s=mod.getState();assert(s.ready and s.mode=='permanent'and s.tree.id=='reaver'and s.points==16,'Known ordinary level40 Reaver required')
 build=capstoneBuild(s.tree);manaCarry=0
 local function setup()qa('setup',function(m)assert(m.peerPresent and m.sourcePresent);natural()end)end
 if same(s.ranks,build)then setup();return end
 assert(sum(s.ranks)==0,'Run the fresh ordinary class fixture; existing different ranks are not removed by this suite')
 requestSerial=requestSerial+1;local id='pvp-build:'..requestSerial;local revision=s.revision
 g_game.getProtocolGame():sendExtendedOpcode(103,json.encode({v=1,action='apply',session=s.session,revision=revision,requestId=id,ranks=build}))
 wait('server validated Bloodletting allocation',function()return replies[id]and mod.getState().revision>revision end,function()
  assert(replies[id].ok and same(mod.getState().ranks,build),'Native permanent allocation rejected');setup()
 end)
end
later(200,function()
 assert(LOCAL_PASSIVES_TEST and Services.updater==''and g_resources.getLayout()=='retro')
 mod=assert(modules.game_passives);spells=assert(mod.ClassSpells)
 ProtocolGame.registerExtendedJSONOpcode(103,function(_,_,data)if data.action=='result'and data.requestId then replies[data.requestId]=data end end)
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 connect(g_game,{
  onGameStart=function()
   EnterGame.hide();intentional=false;g_game.setSafeFight(false);g_game.setChaseMode(DontChase);g_game.setFightMode(FightOffensive)
   wait('permanent Reaver handshake',function()local s=mod.getState();return s.ready and s.active and spells.getState().catalog end,function()
    local fn=nextOnline;nextOnline=nil;later(11000,fn)
   end)
  end,
  onTextMessage=function(_,text)
   if text:find('PASSIVES_PVP_FIXTURE_FAILED',1,true)then fail(text);return end
   local raw=text:match('^PASSIVES_PVP_QA (.+)$');if raw then metrics=json.decode(raw);sequence=sequence+1 else notices[#notices+1]=text end
  end,
  onLoginError=function(e)fail(e)end,
  onConnectionError=function(e)if not intentional then fail(e)end end,
 })
 loginSource(begin)
end)
scheduleEvent(function()if not done then fail('ordinary native PvP suite overall timeout')end end,260000)
