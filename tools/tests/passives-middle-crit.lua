-- Native callback integration under the runner's TEMPORARY runtime tuning:
-- old minor/core critical chance0, new mid_true_aim10000bps/rank (100%).
-- Real Apply requests and ordinary attacks only. No forced RNG/counters.
-- This does not measure the shipped20bps probability or combat balance.
local mod,login,player
local metrics,targets,metricsSequence,targetsSequence=nil,nil,0,0
local replies={}
local failed,done,finishing=false,false,false
local positiveEvidence,negativeEvidence
local function fail(reason)
 if failed or done then return end
 failed=true;print('PASSIVES_MIDDLE_CRIT_FAILED '..tostring(reason))
 if g_game.isOnline()then
  g_game.cancelAttack();g_game.talk('/passiveqa quiesce Passive Tester');g_game.talk('/passivetest stop');g_game.safeLogout()
 end
 scheduleEvent(function()g_app.exit()end,700)
end
local function later(ms,fn)
 scheduleEvent(function()
  if failed or done then return end
  local ok,errorMessage=pcall(fn);if not ok then fail(errorMessage)end
 end,ms)
end
local function wait(label,predicate,nextStep,timeout)
 local deadline=g_clock.millis()+(timeout or 8000)
 local function poll()
  if predicate()then nextStep();return end
  assert(g_clock.millis()<deadline,label..' timeout');later(70,poll)
 end
 later(80,poll)
end
local function commands(list,nextStep)
 local function step(index)
  if index>#list then later(350,nextStep);return end
  g_game.talk(list[index]);later(300,function()step(index+1)end)
 end
 step(1)
end
local function state()return mod.getState()end
local function sum(ranks)local value=0;for _,rank in pairs(ranks)do value=value+rank end;return value end
local function copy(ranks)local out={};for id,rank in pairs(ranks)do out[id]=rank end;return out end
local function same(a,b)
 for id,rank in pairs(a)do if rank~=(b[id]or 0)then return false end end
 for id,rank in pairs(b)do if rank~=(a[id]or 0)then return false end end
 return true
end
local function measure(nextStep)
 local beforeMetrics=metricsSequence
 g_game.talk('/passiveqa metrics Passive Tester')
 wait('actual native metrics',function()return metricsSequence>beforeMetrics and metrics.player=='Passive Tester'end,function()
  local measuredMetrics=metrics;local beforeTargets=targetsSequence
  g_game.talk('/passiveqa targets')
  wait('actual arena target health',function()return targetsSequence>beforeTargets end,function()
   assert(g_game.isOnline()and player:getHealth()>0,'Subject disconnected or died')
   assert(measuredMetrics.profile.active and measuredMetrics.profile.mode=='test'and measuredMetrics.profile.treeId=='blademaster','Wrong native overlay')
   assert(#targets==3,'Arena must have exactly three actual monsters')
   local hp={};for _,target in ipairs(targets)do hp[target.id]=target.hp end
   -- /passiveqa targets preserves arena owned[] order: entry1 is the primary.
   -- metrics.targetId is overwritten by runtime's selected target (0 while idle).
   local primaryId=targets[1].id
   assert(hp[primaryId],'Primary arena target missing')
   -- The two existing native fixture commands are separate dispatcher reads.
   -- Resample if a real hit landed between them; never join old counters to new HP.
   if hp[primaryId]~=measuredMetrics.targetHP then later(80,function()measure(nextStep)end);return end
   nextStep({metrics=measuredMetrics,targets=targets,hp=hp,primaryId=primaryId})
  end)
 end)
end
local function untouchedArena(before)
 assert(before.metrics.attackedId==0,'A target was selected before the combat baseline')
 assert((tonumber(before.metrics.pressureHits)or 0)==0,'An ordinary hit occurred before the combat baseline')
 assert((tonumber(before.metrics.pendingActions)or 0)==0,'Combat action pending before the baseline')
 assert(before.metrics.weaponActive==true,'Matching sword must be active')
 for _,target in ipairs(before.targets)do assert(target.hp==1000000,'Arena monster was damaged before the baseline')end
end
local function apply(ranks,label,nextStep)
 assert(not mod.validateDraft(ranks),'Illegal '..label..' draft')
 local revision,session=state().revision,state().session;local request='middle-crit-'..label
 g_game.getProtocolGame():sendExtendedOpcode(103,json.encode({v=1,action='apply',session=session,revision=revision,requestId=request,ranks=ranks}))
 wait(label..' authoritative apply',function()return replies[request]~=nil end,function()
  assert(replies[request].ok==true,'Native rejected '..label..': '..tostring(replies[request].error))
  wait(label..' matching snapshot',function()return state().session==session and state().revision>revision and same(state().ranks,ranks)end,nextStep)
 end)
end
local function attackPrimary(id)
 local selected
 for _,creature in ipairs(g_map.getSpectators(player:getPosition(),false))do
  if creature:getId()==id and creature:getName()=='Passive Test Dummy'then selected=creature;break end
 end
 assert(selected,'Actual primary arena dummy is not visible')
 mod.hide();g_game.setFightMode(FightOffensive);g_game.attack(selected)
end
local function secondaryLoss(before,after)
 local rows={};local total=0
 for id,hp in pairs(before.hp)do
  assert(after.hp[id]~=nil,'Actual target disappeared')
  if id~=before.primaryId then
   local loss=hp-after.hp[id];rows[#rows+1]={id=id,beforeHP=hp,afterHP=after.hp[id],loss=loss};total=total+loss
  end
 end
 return total,rows
end
local function finish()
 commands({'/passiveqa quiesce Passive Tester','/passivetest stop'},function()
  wait('native Stop cleanup',function()return not state().active end,function()
   assert(player:getMaxHealth()==735,'Overlay health remained after Stop')
   finishing=true;g_game.safeLogout()
   wait('logout cleanup',function()return not g_game.isOnline()end,function()
    assert(not state().tree and not mod.getWindow(),'Logout retained passive tree UI')
    done=true
    print('PASSIVES_MIDDLE_CRIT_OK '..json.encode({temporaryTuning={minorPrecisionBps=0,majorPrecisionBps=0,midPrecisionBps=10000},positive=positiveEvidence,removed=negativeEvidence,
     scope='Real native callback and removal gates under temporary100% chance; shipped20bps probability and balance are unmeasured.'}))
    scheduleEvent(function()g_app.exit()end,400)
   end)
  end)
 end)
end
local function negativeCombat(before)
 untouchedArena(before)
 local baseCap=tonumber(before.metrics.capstoneProcCount)or 0
 local deadline=g_clock.millis()+12000;local previousHP=before.hp[before.primaryId];local hitSteps=0
 assert((before.metrics.profile.ranks.mid_true_aim or 0)==0 and sum(before.metrics.profile.ranks)==22,'Removed-minor build is not22 points')
 attackPrimary(before.primaryId)
 local function poll()
  measure(function(after)
   assert(after.primaryId==before.primaryId,'Primary target changed')
   local currentHP=after.hp[before.primaryId]
   if currentHP<previousHP then
    hitSteps=hitSteps+1;previousHP=currentHP
    assert(after.metrics.attackedId==before.primaryId,'Ordinary attack did not use the explicit arena primary')
    assert(after.metrics.pressureHits==hitSteps,'Unobserved ordinary hit would contaminate the removal proof')
   end
   assert((tonumber(after.metrics.capstoneProcCount)or 0)==baseCap,'Blade Storm triggered after removing the only critical chance')
   local total,rows=secondaryLoss(before,after)
   assert(total==0,'Secondary monsters lost HP with zero critical chance')
   if hitSteps==2 then
    g_game.cancelAttack()
    negativeEvidence={buildPoints=22,normalHitSteps=hitSteps,capstoneProcBefore=baseCap,capstoneProcAfter=after.metrics.capstoneProcCount,
     primaryLoss=before.hp[before.primaryId]-currentHP,secondaryLoss=total,secondary=rows,before=before.metrics,after=after.metrics}
    print('PASSIVES_MIDDLE_CRIT_REMOVED_OK '..json.encode(negativeEvidence));finish();return
   end
   assert(g_clock.millis()<deadline,'Two real ordinary primary HP drops were not observed')
   later(120,poll)
  end)
 end
 poll()
end
local function removeMinor()
 commands({'/passiveqa quiesce Passive Tester'},function()
  local ranks=copy(state().ranks);assert(ranks.mid_true_aim==1,'Middle crit minor was not applied')
  ranks.mid_true_aim=0;assert(sum(ranks)==22,'Removing one middle rank must leave22 points')
  apply(ranks,'remove',function()
   commands({'/passiveqa arena','/passiveqa join Passive Tester,1'},function()
    -- Preserve real teleport/login pacification; never remove it in the fixture.
    later(11000,function()measure(negativeCombat)end)
   end)
  end)
 end)
end
local function positiveCombat(before)
 untouchedArena(before)
 assert((tonumber(before.metrics.capstoneProcCount)or 0)==0,'Fresh overlay already has a capstone proc')
 assert(before.metrics.profile.ranks.mid_true_aim==1 and sum(before.metrics.profile.ranks)==23,'Guaranteed new-minor build is not23 points')
 local deadline=g_clock.millis()+12000
 local previousHP=before.hp[before.primaryId];local hitSteps=0;local tinyBudgetSkips={}
 attackPrimary(before.primaryId)
 local function poll()
  measure(function(after)
   assert(after.primaryId==before.primaryId,'Primary target changed')
   local currentHP=after.hp[before.primaryId]
   local primaryLoss=before.hp[before.primaryId]-currentHP
   if currentHP<previousHP then
    local hitLoss=previousHP-currentHP;previousHP=currentHP;hitSteps=hitSteps+1
    assert(after.metrics.attackedId==before.primaryId,'Ordinary attack did not use the explicit arena primary')
    assert(after.metrics.pressureHits==hitSteps,'Unobserved ordinary hit would contaminate the critical callback proof')
    assert(hitSteps<5,'The fifth-hit Pressure effect would contaminate secondary damage')
    local total,rows=secondaryLoss(before,after)
    local capCount=tonumber(after.metrics.capstoneProcCount)or 0
    if capCount==0 and total==0 and hitLoss<=4 then
     -- Blade Storm floors 40% of PRE-critical raw damage. Native raw1/2
     -- can double to only2/4 primary HP loss while its secondary budget is0.
     -- Permit at most3 tiny actual hits, then require a real positive-budget proc.
     assert(hitSteps<=3,'No positive Blade Storm budget within four bounded ordinary hits')
     for _,row in ipairs(rows)do assert(row.loss==0,'Tiny-budget retry already damaged a secondary')end
     tinyBudgetSkips[#tinyBudgetSkips+1]={hit=hitSteps,primaryLoss=hitLoss}
     assert(g_clock.millis()<deadline,'No positive-budget ordinary critical hit observed')
     later(120,poll);return
    end
    g_game.cancelAttack()
    assert(capCount==1,'The first positive-budget ordinary hit did not trigger exactly one Blade Storm')
    assert(total>0,'Blade Storm counter changed without actual secondary monster HP damage')
    for _,row in ipairs(rows)do assert(row.loss>0,'Blade Storm did not damage both adjacent actual monsters')end
    positiveEvidence={buildPoints=23,normalHitSteps=hitSteps,tinyBudgetSkips=tinyBudgetSkips,primaryLoss=primaryLoss,capstoneProcBefore=0,capstoneProcAfter=after.metrics.capstoneProcCount,
     secondaryLoss=total,secondary=rows,before=before.metrics,after=after.metrics}
    print('PASSIVES_MIDDLE_CRIT_FIRST_BUDGET_HIT_OK '..json.encode(positiveEvidence));removeMinor();return
   end
   assert((tonumber(after.metrics.capstoneProcCount)or 0)==0,'Capstone proc appeared without an actual ordinary primary hit')
   assert(g_clock.millis()<deadline,'No actual ordinary primary hit with guaranteed middle critical chance')
   later(120,poll)
  end)
 end
 poll()
end
local function prepareDraft()
 local current=state();assert(current.tree and current.tree.id=='blademaster'and #current.tree.nodes==29,'Wrong29-node catalog')
 assert(current.mode=='test'and current.ranks.cap_bladestorm==1 and sum(current.ranks)==16,'Blade Storm preset must spend16 points')
 assert(current.ranks.major_pressure==2 and current.ranks.major_precision==1 and(current.ranks.major_recovery or 0)==0,'Unexpected preset core route')
 assert((current.ranks.minor_recovery or 0)==0 and(current.ranks.minor_focus or 0)==0 and(current.ranks.mid_true_aim or 0)==0,'Preset already includes added Recovery path')
 local middle=assert(current.nodes.mid_true_aim,'New middle crit talent missing')
 assert(middle.role=='routeMinor'and middle.maxRank==5 and #middle.requires.all==1 and middle.requires.all[1].id=='major_recovery'and middle.requires.all[1].rank==2,'mid_true_aim must require Second Wind2')
 assert(current.nodes.major_recovery.name=='Second Wind','Wrong own-core class identity')
 assert(middle.benefits[1]:match('^%+100 percentage points'),'Runner did not install temporary100% new-minor tuning')
 assert(current.nodes.minor_precision.benefits[1]:match('^%+0 percentage points')and current.nodes.major_precision.benefits[1]:match('^%+0 percentage points'),'Old critical chance was not zeroed in runtime catalog')
 local ranks=copy(current.ranks);ranks.minor_recovery=4;ranks.major_recovery=2;ranks.mid_true_aim=1
 assert(sum(ranks)==23,'Legal new-middle route must add exactly7 points')
 apply(ranks,'add',function()
  commands({'/passiveqa arena','/passiveqa join Passive Tester,1'},function()
   later(11000,function()measure(positiveCombat)end)
  end)
 end)
end
local function setup()
 commands({'/passiveqa quiesce Passive Tester','/passivetest stop','/passiveqa equip blademaster','/passiveqa learn','/passiveqa heal Passive Tester','/passivetest start blademaster','/passivetest preset Passive Tester,bladestorm'},function()
  wait('native Blade Storm preset',function()return state().active and state().tree and state().tree.id=='blademaster'and state().ranks.cap_bladestorm==1 end,prepareDraft)
 end)
end
local function online()
 EnterGame.hide();player=g_game.getLocalPlayer()
 connect(g_game,{onTextMessage=function(_,text)
  print('PASSIVES_MIDDLE_CRIT_MESSAGE '..text)
  local payload=text:match('^PASSIVEQA_METRICS (.+)$')
  if payload then metrics=json.decode(payload);metricsSequence=metricsSequence+1 end
  payload=text:match('^PASSIVEQA_TARGETS (.+)$')
  if payload then targets=json.decode(payload);targetsSequence=targetsSequence+1 end
 end})
 wait('handshake',function()return state().ready end,setup)
end
later(200,function()
 assert(LOCAL_PASSIVES_TEST and Services.updater==''and g_resources.getLayout()=='retro','Local retro probe required')
 mod=assert(modules.game_passives)
 ProtocolGame.registerExtendedJSONOpcode(103,function(_,_,data)if data.action=='result'and data.requestId then replies[data.requestId]=data end end)
 mod.setStatusVisible(true)
 connect(g_game,{onGameStart=function()later(250,online)end,onConnectionError=function(errorMessage)if not finishing then fail(errorMessage)end end})
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 G.account='passivetest';G.password='passivetest'
 login=ProtocolLogin.create();_G.middleCritLogin=login
 login.onLoginError=function(_,errorMessage)fail(errorMessage)end
 login.onCharacterList=function(_,characters)
  for _,character in ipairs(characters)do if character.name=='Passive Tester'then
   g_game.loginWorld(G.account,G.password,character.worldName,character.worldIp,character.worldPort,character.name,'','');return
  end end
  fail('Disposable Passive Tester character missing')
 end
 login:login('127.0.0.1',7174,G.account,G.password,'',false)
end)
scheduleEvent(function()if not done then fail('80-second middle crit timeout')end end,80000)
