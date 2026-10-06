-- Ordinary permanent 29-node route integration probe. Runtime-only QA commands
-- observe real rolls and HP; no counters, rolls or combat results are forced.
local tree=assert(PASSIVES_PROBE_TREE,'Choose one of the six ordinary class fixtures')
local names={reaver='Reaver',blademaster='Blademaster',earthshaker='Earthshaker',marksman='Marksman',arcanist='Arcanist',lifekeeper='Lifekeeper'}
local guids={reaver=9006,blademaster=9007,earthshaker=9008,marksman=9009,arcanist=9010,lifekeeper=9011}
local offensive={reaver='rend',blademaster='focused_thrust',earthshaker='crushing_blow',marksman='blitzshot',arcanist='arcane_surge',lifekeeper='essence_lash'}
local broad={reaver='cleaving_arc',blademaster='focused_thrust',earthshaker='rolling_thunder',marksman='blitzshot',arcanist='arcane_surge',lifekeeper='mending_thread'}
local mod,spells,player,login,co,metrics,cm,castObservation
local sequence,classSequence,castSequence,request=0,0,0,0
local done,failed,intentional=false,false,false
local evidence={}
local currentStage='startup'
-- Keep native creature-ID maps numeric for all actual comparisons. The client
-- JSON codec only accepts dense numeric arrays or dictionaries with string keys.
local function diagnosticValue(value,seen)
 if type(value)~='table'then return value end
 seen=seen or{};assert(not seen[value],'Diagnostic contains a cyclic table');seen[value]=true
 local count,maximum,array=0,0,true
 for key in pairs(value)do
  count=count+1
  if type(key)~='number'or key<1 or key~=math.floor(key)then array=false else maximum=math.max(maximum,key)end
 end
 array=array and maximum==count
 local out={}
 for key,entry in pairs(value)do
  assert(type(key)=='number'or type(key)=='string','Unsupported diagnostic key type')
  local encodedKey=array and key or tostring(key)
  assert(out[encodedKey]==nil,'Diagnostic key collision')
  out[encodedKey]=diagnosticValue(entry,seen)
 end
 seen[value]=nil;return out
end
local function diagnosticJSON(value)return json.encode(diagnosticValue(value))end
local function stage(label)
 currentStage=label;print('PASSIVES_ROUTE_EFFECTS_STAGE '..tree..' '..label)
end
local function fail(reason)
 if failed or done then return end;failed=true
 print('PASSIVES_ROUTE_EFFECTS_FAILED '..tree..' stage='..currentStage..' '..tostring(reason):sub(1,6000))
 pcall(function()if g_game.isOnline()then g_game.talk('/passiverouteqa cleanup');g_game.talk('/classspellqa cleanup');g_game.safeLogout()else g_game.cancelLogin()end end)
 scheduleEvent(function()g_app.exit()end,800)
end
local function sleep(ms)return coroutine.yield(ms)end
local function wait(label,predicate,timeout)
 local deadline=g_clock.millis()+(timeout or 10000)
 while not predicate()do assert(g_clock.millis()<deadline,label..' timeout');sleep(60)end
end
local function state()return assert(mod.getState())end
local function spent(r)local n=0;for _,v in pairs(r)do n=n+v end;return n end
local function approx(a,b,label,tolerance)assert(math.abs(a-b)<(tolerance or .00001),(label or'fraction')..' expected '..b..', actual '..a)end
local function round(v)return math.floor(v+.5)end
local function ranks(m)return m.snapshot.ranks end
local function rank(m,id)return ranks(m)[id]or 0 end
local function sayQA(prefix,command)
 local isRoute=prefix=='/passiverouteqa ';local before=isRoute and sequence or classSequence
 local label=command:match('^%S+');g_game.talk(prefix..command)
 wait('fixture '..prefix..command,function()local m=isRoute and metrics or cm;return(isRoute and sequence or classSequence)>before and m and m.label==label end)
 return isRoute and metrics or cm
end
local function qa(command)return sayQA('/passiverouteqa ',command)end
local function classQA(command)return sayQA('/classspellqa ',command)end
local function emit(label,data)
 data=data or{};data.tree=tree;data.label=label;evidence[#evidence+1]=data
 print('PASSIVES_ROUTE_EFFECTS_EVIDENCE '..diagnosticJSON(data))
end
local function entry(id)
 for _,s in ipairs(assert(spells.getState().catalog).spells)do if s.id==id then return s end end;error('Missing learned starter '..id)
end
local function mapTargets(m)local out={};for _,v in ipairs(m.targets)do out[v.id]=v.hp end;return out end
local function losses(before,after)
 local initial=mapTargets(before);local out,total={},0
 for _,v in ipairs(after.targets)do assert(initial[v.id],'Target identity changed');local d=initial[v.id]-v.hp;assert(d>=0,'Dummy unexpectedly recovered HP');out[v.id]=d;total=total+d end
 return out,total
end
local function packet(action,build)
 local old=state();local revision=old.revision;request=request+1
 local payload={v=1,action=action,session=old.session,revision=old.revision,requestId='route-effects-'..tree..'-'..request}
 if action=='reset'then assert(old.respecCost==0,'Root must apply ONLY disposable runtime respecCosts={0}');payload.quotedCost=0;payload.respecCount=old.respecCount else payload.ranks=build end
 g_game.getProtocolGame():sendExtendedOpcode(103,json.encode(payload))
 wait('native '..action,function()return state().revision>revision and not state().pending end)
 if action=='reset'then assert(spent(state().ranks)==0,'Reset retained ranks')else for id,v in pairs(build)do assert((state().ranks[id]or 0)==v,'Native rank mismatch '..id)end end
end
local function buildFor(path,advancedRank)
 local out={};for _,n in ipairs(state().tree.nodes)do out[n.id]=0 end
 for _,core in ipairs({path.ownCoreId,path.secondaryCoreId})do
  local branch;for _,b in ipairs(state().tree.branchGroups)do if b.majorId==core then branch=b;break end end
  assert(branch,'Missing authoritative core branch')
  out[branch.minorIds[1]]=branch.id=='precision'and 0 or 3;out[branch.minorIds[2]]=branch.id=='precision'and 4 or 1
 end
 out[path.ownCoreId]=2;out[path.secondaryCoreId]=1;out[path.minorId]=2;out[path.advancedId]=advancedRank
 assert(spent(out)==13+advancedRank,'Wrong legal route closure size')
 assert(not mod.validateDraft(out),'Catalog rejects its own connected route closure')
 return out
end
local function expectedHP(m)
 local c=m.config
 return 735+math.floor(735*(rank(m,'minor_vitality')*c.minorVitality+rank(m,'major_guard')*c.majorGuardHp+rank(m,'mid_stout_heart')*c.midHpPercent)/100)
end
local function setupArena()
 classQA('setup');if tree=='arcanist'then classQA('line')end
 qa('pause');qa('observe on');sleep(11000) -- Preserve actual teleport/login pacification.
end
local function cleanArena()qa('stop');classQA('cleanup')end
local function isolate(path,advancedRank)
 cleanArena();if spent(state().ranks)>0 then packet('reset')end
 local before=qa('state');local build=buildFor(path,advancedRank);packet('apply',build);local after=qa('state')
 assert(after.hp==before.hp,'Allocation healed the subject')
 assert(after.maxHP==expectedHP(after),'Middle/core HP composition mismatch')
 setupArena();return qa('state')
end
local function upgrade(path)
 cleanArena();packet('apply',buildFor(path,3));setupArena();return qa('state')
end
local function focus()
 classQA('focus');qa('pause');return qa('state')
end
local function oneHit()
 local before=qa('state');assert(#before.targets==3,'Fresh stationary three-target arena required')
 qa('normal 1');local deadline=g_clock.millis()+17000;local after
 repeat
  after=qa('state');local loss=losses(before,after)
  if(loss[before.targets[1].id]or 0)>0 then break end
  assert(g_clock.millis()<deadline,'Ordinary actual HP hit did not occur');sleep(65)
 until false
 qa('pause');after=qa('state');local loss,total=losses(before,after);local primary=assert(loss[before.targets[1].id])
 assert(primary>0,'Natural hit produced no primary HP damage')
 return before,after,primary,total
end
local function cast(id)
 stage('actual-cast '..id)
 qa('clear');qa('refill') -- Actual self-deficit is prepared separately for healing below.
 if id=='mending_thread'then qa('hurt 200')end
 local before=qa('state');local previous=castSequence;local s=entry(id)
 g_game.talk(s.words)
 wait('observed real '..s.name,function()return castSequence>previous and castObservation and castObservation.name==s.name end)
 assert(castObservation.ok and castObservation.castResult==true,'Actual cast rejected '..json.encode(castObservation))
 local observation=castObservation
 wait('real deferred action completion',function()local m=qa('state');return m.runtime.pendingActions==0 end,7000)
 local after=qa('state');return before,after,observation,s
end
local function castKeptHP(id)
 stage('actual-full-HP-cast '..id)
 qa('clear');local before=qa('state');local previous=castSequence;local s=entry(id);g_game.talk(s.words)
 wait('observed real '..s.name,function()return castSequence>previous and castObservation.name==s.name end)
 assert(castObservation.ok and castObservation.castResult==true,'Actual cast rejected '..s.name)
 local observation=castObservation
 wait('completed cast',function()return qa('state').runtime.pendingActions==0 end,7000)
 return before,qa('state'),observation,s
end
local function verifyCast(before,after,observation,id,prepared,rhythm)
 local c=before.config;local r=ranks(before);local rolls={};for _,v in ipairs(observation.rolls)do rolls[#rolls+1]=v.value end
 assert(#rolls>=1,'Actual RNG observer omitted base roll')
 local primary=before.targetId~=0 and before.targetId or before.targets[1].id
 local expected={};for _,t in ipairs(before.targets)do expected[t.id]=0 end
 local f=before.runtime.routeDamageFractionPrimary;local bonuses=0
 local function damage(target,value)
  local base=round(value*(1+((r.minor_power or 0)*c.minorPower+(r.major_pressure or 0)*c.majorPressurePower)/100))
  local pct=0
  if target==primary then
   pct=(r.mid_focused_edge or 0)*c.midPrimaryPercent+(prepared and(r.path_deliberate_cut or 0)*c.routePreparedPercent or 0)
   if tree=='blademaster'then pct=pct+(r.path_broad_stroke or 0)*c.routeBroadPercent+(r.mid_sweeping_form or 0)*c.midBroadPercent end
  elseif tree~='lifekeeper'and tree~='blademaster'and(tree~='reaver'or id=='cleaving_arc')then
   pct=(r.path_broad_stroke or 0)*c.routeBroadPercent+(r.mid_sweeping_form or 0)*c.midBroadPercent
  end
  if pct>0 then local whole=math.floor(base*pct/100+f+1e-9);f=base*pct/100+f-whole;bonuses=bonuses+whole;base=base+whole end
  expected[target]=expected[target]+base
 end
 if id=='mending_thread'then
  local power=(r.minor_precision or 0)*c.minorHealing+(r.minor_critical or 0)*c.minorHealingExtra+(r.major_precision or 0)*c.majorHealing
  local base=round(rolls[1]*(1+power/100))
  local pct=(r.path_broad_stroke or 0)*c.routeBroadPercent+(r.mid_sweeping_form or 0)*c.midBroadPercent+(r.mid_true_aim or 0)*c.midHealingPercent+(r.mid_focused_edge or 0)*c.midPrimaryPercent+(prepared and(r.path_deliberate_cut or 0)*c.routePreparedPercent or 0)+(rhythm and(r.path_hewing_rhythm or 0)*c.routeRhythmPercent or 0)
  local exact=base*pct/100+before.runtime.routeHealingFraction;local bonus=math.floor(exact+1e-9)
  assert(after.runtime.routeRawHealingBonus-before.runtime.routeRawHealingBonus==bonus,'Direct healing route budget mismatch')
  approx(after.runtime.routeHealingFraction,exact-bonus,'Healing fraction')
  assert(after.hp-before.hp==math.min(base+bonus,before.maxHP-before.hp),'Actual direct friendly healing mismatch')
  return{base=base,bonus=bonus,actualHP=after.hp-before.hp,roll=rolls[1],percent=pct}
 end
 if id=='cleaving_arc'or id=='arcane_surge'then for _,t in ipairs(before.targets)do damage(t.id,rolls[1])end
 elseif id=='rolling_thunder'then damage(primary,rolls[1]);assert(rolls[2],'Actual delayed pulse roll missing');for _,t in ipairs(before.targets)do damage(t.id,rolls[2])end
 elseif id=='blitzshot'then damage(primary,rolls[1]);assert(rolls[2],'Actual secondary shot roll missing');local second;for _,t in ipairs(before.targets)do if t.id~=primary then second=t.id;break end end;damage(second,rolls[2])
 else damage(primary,rolls[1])end
 local actual,total=losses(before,after)
 for target,loss in pairs(expected)do assert(actual[target]==loss,'Actual starter target HP mismatch '..diagnosticJSON({id=id,target=target,expected=expected,actual=actual,rolls=rolls,fractionBefore=before.runtime.routeDamageFractionPrimary,fractionAfter=after.runtime.routeDamageFractionPrimary,rawBonusDelta=after.runtime.routeRawBonus-before.runtime.routeRawBonus}))end
 assert(after.runtime.routeRawBonus-before.runtime.routeRawBonus==bonuses,'New direct raw bonus mismatch')
 approx(after.runtime.routeDamageFractionPrimary,f,'Direct damage fraction')
 assert(after.runtime.capstoneProcCount==before.runtime.capstoneProcCount,'Route unexpectedly activated a capstone')
 return{rolls=rolls,targetLosses=actual,totalHP=total,rawBonus=bonuses}
end
local function timer(m,key,configured)assert(m.runtime[key]>configured-1200 and m.runtime[key]<=configured,key..' wrong configured lifetime')end
local function runBroad(path)
 isolate(path,0);focus();local a,b,o=cast(broad[tree]);emit('middle23',verifyCast(a,b,o,broad[tree],false,false))
 upgrade(path);focus();a,b,o=cast(broad[tree]);emit('advanced17+middle23',verifyCast(a,b,o,broad[tree],false,false))
end
local function runPrepared(path)
 isolate(path,0);focus();local id=tree=='lifekeeper'and'mending_thread'or offensive[tree]
 local a,b,o=cast(id);emit('middle25',verifyCast(a,b,o,id,false,false))
 upgrade(path);oneHit();local _,ready=oneHit();timer(ready,'routePreparedMs',ready.config.routeReadyMs);assert(ready.runtime.routeSetupHits==0,'Prepared source counter did not reset')
 a,b,o=cast(id);emit('advanced18+middle25',verifyCast(a,b,o,id,true,false));assert(b.runtime.routePreparedMs==0,'Successful prepared action retained charge')
 oneHit();local _,again=oneHit();assert(again.runtime.routePreparedMs>0,'Second natural setup failed')
 local switched=qa('switchtarget 2');assert(switched.runtime.routePreparedMs==0 and switched.runtime.routeSetupHits==0,'Selected target switch retained setup')
 local back=qa('switchtarget 1');assert(back.runtime.routePreparedMs==0,'Switch-back revived charge');emit('advanced18-immediate-switch-clear',{prepared=back.runtime.routePreparedMs})
end
local function ordinaryHealEnvelope(before,after,damage,newHeal)
 local c=before.config;local leech=rank(before,'minor_recovery')*c.minorRecovery+rank(before,'major_recovery')*c.majorRecovery
 local old=after.hp-before.hp-newHeal
 assert(old>=math.floor(damage*leech/100)and old<=math.ceil(damage*leech/100),'Actual HP gain not attributable to new heal plus old fractional leech')
end
local function runReturn(path)
 local mid=isolate(path,0);assert(mid.maxHP==expectedHP(mid),'Middle27 maxHP wrong');emit('middle27',{maxHP=mid.maxHP,base=735,allocationDidNotHeal=true})
 upgrade(path);qa('refill');local initial=qa('state');local got=qa('incoming energy 100');local loss=initial.hp-got.hp;assert(loss==100,'Controlled energy HP loss wrong')
 local budget=math.min(loss*3*got.config.routeReturnPercent/100,got.maxHP*3*got.config.routeReturnCapPercent/100)
 approx(got.runtime.routeReturnBudget,budget,'Received-hit recovery budget');timer(got,'routeReturnMs',got.config.routeReadyMs);timer(got,'routeReturnCooldownMs',got.config.routeCooldownMs)
 local again=qa('incoming energy 1');approx(again.runtime.routeReturnBudget,budget,'Pending hit must not replace/stack budget');assert(again.runtime.routeReturnMs<=got.runtime.routeReturnMs,'Pending hit refreshed readiness')
 local before,after,damage=oneHit();local exact=budget+before.runtime.routeReturnFraction;local whole=math.floor(exact+1e-9)
 assert(after.runtime.routeReturnHealed-before.runtime.routeReturnHealed==whole,'Recovery actual selfheal wrong');approx(after.runtime.routeReturnFraction,exact-whole,'Recovery fraction')
 assert(after.runtime.routeReturnMs==0 and after.runtime.routeReturnBudget==0,'Recovery charge not consumed')
 ordinaryHealEnvelope(before,after,damage,whole);emit('advanced19+middle27',{received=loss,budget=budget,routeActualHeal=whole,actualSelfHP=after.hp-before.hp,maxHP=after.maxHP})
 before,after=oneHit();assert(after.runtime.routeReturnHealed==before.runtime.routeReturnHealed,'Recovery repeated without new grant')
 if tree=='reaver'then
  -- The common mechanic receives additional cap and sub-unit coverage once,
  -- using real cooldown expiry and direct monster HP loss rather than forcing it.
  for _,amount in ipairs({500,1})do
   wait('Actual Return grant cooldown expiry',function()return qa('state').runtime.routeReturnCooldownMs==0 end,12000)
   qa('refill');local start=qa('state');local pending=qa('incoming energy '..amount);local actualLoss=start.hp-pending.hp
   assert(actualLoss==amount,'Deep Return controlled HP loss mismatch')
   local uncapped=actualLoss*3*pending.config.routeReturnPercent/100;local cap=pending.maxHP*3*pending.config.routeReturnCapPercent/100
   local expected=math.min(uncapped,cap);approx(pending.runtime.routeReturnBudget,expected,'Deep Return capped/fractional pending budget')
   timer(pending,'routeReturnMs',pending.config.routeReadyMs);timer(pending,'routeReturnCooldownMs',pending.config.routeCooldownMs)
   if amount==500 then assert(uncapped>cap,'Cap fixture did not exceed the HP ceiling')else assert(expected>0 and expected<1,'Tiny fixture did not create a sub-unit budget');qa('hurt 200')end
   local a,b,d=oneHit();local exact=expected+a.runtime.routeReturnFraction;local healed=math.floor(exact+1e-9)
   assert(b.runtime.routeReturnHealed-a.runtime.routeReturnHealed==healed,'Deep Return actual healing mismatch')
   approx(b.runtime.routeReturnFraction,exact-healed,'Deep Return retained fraction');assert(b.runtime.routeReturnMs==0 and b.runtime.routeReturnBudget==0,'Deep Return charge retained after one actual hit')
   ordinaryHealEnvelope(a,b,d,healed)
   emit(amount==500 and'advanced19-HP-cap'or'advanced19-sub-unit',{received=actualLoss,uncapped=uncapped,cap=cap,budget=expected,fractionBefore=a.runtime.routeReturnFraction,actualRouteHeal=healed,fractionAfter=b.runtime.routeReturnFraction,actualSelfHP=b.hp-a.hp})
   local noRepeatBefore,noRepeatAfter=oneHit();assert(noRepeatAfter.runtime.routeReturnHealed==noRepeatBefore.runtime.routeReturnHealed,'Deep Return healed a second time without a grant')
  end
  wait('Actual Return full-HP grant cooldown expiry',function()return qa('state').runtime.routeReturnCooldownMs==0 end,12000)
  qa('refill');local beforeGrant=qa('state');local grant=qa('incoming energy 100');local grantLoss=beforeGrant.hp-grant.hp
  assert(grantLoss==100,'Full-HP Return setup did not lose actual monster HP')
  local fullBudget=math.min(grantLoss*3*grant.config.routeReturnPercent/100,grant.maxHP*3*grant.config.routeReturnCapPercent/100)
  approx(grant.runtime.routeReturnBudget,fullBudget,'Full-HP Return grant budget');qa('refill')
  local a,b,d=oneHit();assert(a.hp==a.maxHP and b.hp==b.maxHP,'Full-HP Return altered actual self HP')
  local exact=fullBudget+a.runtime.routeReturnFraction;approx(b.runtime.routeReturnFraction,exact-math.floor(exact+1e-9),'Full-HP Return raw carry')
  assert(b.runtime.routeReturnHealed==a.runtime.routeReturnHealed and b.runtime.routeReturnMs==0 and b.runtime.routeReturnBudget==0,'Full-HP Return must consume the charge with zero actual healing')
  emit('advanced19-full-HP-consumption',{budget=fullBudget,actualPrimaryHP=d,actualRouteHeal=0,actualSelfHP=0,fractionAfter=b.runtime.routeReturnFraction})
 end
end
local function runRhythm(path)
 isolate(path,0)
 if tree=='lifekeeper'then local a,b,o=cast('mending_thread');emit('middle24-healing',verifyCast(a,b,o,'mending_thread',false,false))
 else assert(qa('state').config.midPrecisionBps==20,'Shipped new critical chance changed');emit('middle24-chance-config',{perRankBps=20,rank=2,activationProof='separate deterministic runtime configuration gate'})end
 upgrade(path)
 if tree=='lifekeeper'then
  for i=1,3 do local a,b,o=cast('mending_thread');local ev=verifyCast(a,b,o,'mending_thread',false,i==3);assert(b.runtime.routeRhythmHits==(i==3 and 0 or i),'Effective healing cadence wrong');ev.cast=i;emit('advanced20+middle24',ev)end
  qa('refill');local a,b,o=castKeptHP('mending_thread');verifyCast(a,b,o,'mending_thread',false,false);assert(b.hp==a.hp and b.runtime.routeRhythmHits==a.runtime.routeRhythmHits,'Full-HP healing advanced cadence');emit('advanced20-overheal-rejected',{effectiveHP=0,counter=b.runtime.routeRhythmHits})
 else
  for i=1,3 do
   local a,b,d=oneHit();local bonus=b.runtime.routeRawBonus-a.runtime.routeRawBonus
   if i<3 then assert(bonus==0 and b.runtime.routeRhythmHits==i,'Early ordinary hit boosted or wrong setup counter')
   else
    assert(b.runtime.routeRhythmHits==0 and b.runtime.routeRhythmMs==0,'Empowered hit rebuilt its own sequence')
    local pct=3*a.config.routeRhythmPercent;local crit=1+(a.config.passiveCritBaseBonus+rank(a,'minor_critical')*a.config.minorCritical)/100;local candidates={}
    for base=1,d do local exact=base*pct/100+a.runtime.routeDamageFractionPrimary;local n=math.floor(exact+1e-9);if n==bonus and(d==base+n or d==round((base+n)*crit))and math.abs(b.runtime.routeDamageFractionPrimary-(exact-n))<.00001 then candidates[#candidates+1]=base end end
    assert(#candidates>0,'Actual empowered ordinary HP cannot be explained by exact raw bonus/fraction and ordinary critical multiplier')
   end
   emit('advanced20-ordinary',{hit=i,actualPrimaryHP=d,rawBonus=bonus,counter=b.runtime.routeRhythmHits,fraction=b.runtime.routeDamageFractionPrimary})
  end
 end
end
local function runSustain(path)
 isolate(path,0);focus();local id=tree=='lifekeeper'and'mending_thread'or offensive[tree];local count,cost,elapsed=12,0,0;local first;local samples={}
 for i=1,count do
  local a,b,o,s=cast(id);first=first or a;verifyCast(a,b,o,id,false,false);cost=cost+a.mana-b.mana;elapsed=elapsed+b.timeMs-a.timeMs
  samples[i]={beforeTime=a.timeMs,afterTime=b.timeMs,billed=a.mana-b.mana,effectiveHealing=b.hp-a.hp}
 end
 local c=first.config;local base=entry(id).mana;local prior=rank(first,'minor_efficiency')*c.minorEfficiency+rank(first,'major_tactical')*c.majorTacticalMana
 local discount=rank(first,'mid_measured_breath')*c.midManaPercent;local exact,withoutMiddle=0,0
 for index,sample in ipairs(samples)do
  local existingReadyDiscount=0
  if tree=='lifekeeper'and rank(first,'major_precision')>0 and index>1 then
   -- Isolate's actual allocation clears old readiness. Each effective direct
   -- heal then re-arms existing Precision; its new discountVersion preserves
   -- that grant through post-cast payment for the following timely heal.
   local previous=samples[index-1]
   assert(previous.effectiveHealing>0,'Existing healing Precision was not armed by actual healing')
   assert(sample.beforeTime-previous.beforeTime<c.majorCriticalReadyMs,'Existing healing Precision expired between mana samples')
   existingReadyDiscount=rank(first,'major_precision')*c.majorCriticalMana
  end
  local old=prior+existingReadyDiscount
  sample.existingReadyDiscount=existingReadyDiscount
  sample.exactBudget=base*(1-math.min(c.manaDiscountCapPercent,old+discount)/100)
  exact=exact+sample.exactBudget;withoutMiddle=withoutMiddle+base*(1-math.min(c.manaDiscountCapPercent,old)/100)
 end
 local regenBound=math.ceil(elapsed/1000*rank(first,'minor_focus')*c.minorFocus)
 assert(cost>=math.floor(exact)-regenBound and cost<=math.ceil(exact),'Actual mana billing diverged from fractional carry bounds')
 assert(cost<math.floor(withoutMiddle)-regenBound,'Samples cannot distinguish new middle mana discount')
 emit('middle26-mana',{casts=count,base=base,extraDiscount=discount,actualBilled=cost,exactBudget=exact,withoutMiddleBudget=withoutMiddle,focusCarryBound=regenBound,samples=samples,scope='Actual existing healing-Precision readiness modeled per cast; unexposed initial native billing fraction contributes less than one mana'})
 upgrade(path);focus();qa('hurt 200');local a,b,o=cast(id);verifyCast(a,b,o,id,false,false);timer(b,'routeSustainMs',b.config.routeReadyMs);timer(b,'routeSustainCooldownMs',b.config.routeCooldownMs)
 local charged=b;local _,again=cast(id);assert(again.runtime.routeSustainMs<=charged.runtime.routeSustainMs and again.runtime.routeSustainCooldownMs<=charged.runtime.routeSustainCooldownMs,'Repeated actual cast refreshed pending sustain charge')
 qa('hurt 200');local before,after,d=oneHit();local exact=d*3*before.config.routeSustainPercent/100+before.runtime.routeSustainFraction;local whole=math.floor(exact+1e-9)
 assert(after.runtime.routeSustainHealed-before.runtime.routeSustainHealed==whole,'Actual primary-only sustain selfheal mismatch');approx(after.runtime.routeSustainFraction,exact-whole,'Sustain fraction');assert(after.runtime.routeSustainMs==0,'Sustain charge not consumed')
 ordinaryHealEnvelope(before,after,d,whole);emit('advanced21+middle26',{actualPrimaryHP=d,routeActualSelfheal=whole,actualSelfHP=after.hp-before.hp,fraction=after.runtime.routeSustainFraction})
 before,after=oneHit();assert(after.runtime.routeSustainHealed==before.runtime.routeSustainHealed,'Sustain repeated without another charge')
 if tree=='reaver'then
  wait('Actual Sustain full-HP grant cooldown expiry',function()return qa('state').runtime.routeSustainCooldownMs==0 end,12000)
  local a,b,o=cast(id);verifyCast(a,b,o,id,false,false);timer(b,'routeSustainMs',b.config.routeReadyMs);qa('refill')
  local fullBefore,fullAfter,primaryHP=oneHit();assert(fullBefore.hp==fullBefore.maxHP and fullAfter.hp==fullAfter.maxHP,'Full-HP Sustain altered actual self HP')
  local exact=primaryHP*3*fullBefore.config.routeSustainPercent/100+fullBefore.runtime.routeSustainFraction
  approx(fullAfter.runtime.routeSustainFraction,exact-math.floor(exact+1e-9),'Full-HP Sustain raw carry')
  assert(fullAfter.runtime.routeSustainHealed==fullBefore.runtime.routeSustainHealed and fullAfter.runtime.routeSustainMs==0,'Full-HP Sustain must consume the charge with zero actual healing')
  emit('advanced21-full-HP-consumption',{actualPrimaryHP=primaryHP,actualRouteHeal=0,actualSelfHP=0,fractionAfter=fullAfter.runtime.routeSustainFraction})
 end
end
local function physical(before,brace,guard,amount)
 local c=before.config;local old=rank(before,'minor_resilience')*c.minorResilience+(guard and rank(before,'major_guard')*c.majorGuardReduction or 0)
 local base=round(amount*(1-math.min(100,old)/100));local pct=rank(before,'mid_braced_guard')*c.midReductionPercent+(brace and rank(before,'path_iron_rhythm')*c.routeBracePercent or 0)
 local exact=base*pct/100+before.runtime.routeReductionFractionPrimary;local reduced=math.min(base,math.floor(exact+1e-9));local after=qa('incoming physical '..amount)
 assert(before.hp-after.hp==base-reduced,'Actual physical HP loss mismatch after old reduction and new fraction');assert(after.runtime.routeReduced-before.runtime.routeReduced==reduced,'New actual physical reduction counter mismatch');approx(after.runtime.routeReductionFractionPrimary,exact-reduced,'Physical reduction fraction')
 return after,{raw=amount,afterOld=base,newReduction=reduced,actualHP=before.hp-after.hp,newPercent=pct}
end
local function runBrace(path)
 isolate(path,0);local a=qa('state');local b,ev=physical(a,false,false,100);emit('middle28-static',ev)
 upgrade(path);focus();local before,after,o=cast(offensive[tree]);verifyCast(before,after,o,offensive[tree],false,false);timer(after,'routeBraceMs',after.config.routeReadyMs);timer(after,'routeBraceCooldownMs',after.config.routeCooldownMs)
 local pending=after;local _,again=cast(offensive[tree]);assert(again.runtime.routeBraceMs<=pending.runtime.routeBraceMs and again.runtime.routeBraceCooldownMs<=pending.runtime.routeBraceCooldownMs,'Second actual cast refreshed brace')
 local energy=qa('incoming energy 1');assert(energy.runtime.routeBraceMs>0 and energy.runtime.routeBraceMs<=again.runtime.routeBraceMs,'Elemental hit consumed/refreshed physical brace')
 -- Existing Guard is armed by an actual direct monster HP hit, including
 -- elemental damage. Each successful physical hit consumes then re-arms it
 -- in dealt(); its protection therefore remains on the following hit.
 assert(again.hp-energy.hp==1,'Controlled elemental hit did not arm existing Guard')
 local oldGuard=rank(energy,'major_guard')>0
 b,ev=physical(energy,true,oldGuard,100);assert(b.runtime.routeBraceMs==0,'Physical charge not consumed once');ev.oldGuardArmed=oldGuard;emit('advanced22+middle28',ev)
 local c; c,ev=physical(b,false,oldGuard and b.hp<energy.hp,100);assert(c.runtime.routeBraceMs==0,'Brace repeated without another cast');ev.oldGuardRearmed=oldGuard;emit('advanced22-consumed-static-remains',ev)
end
local function main()
 stage('validate-and-login')
 assert(names[tree]and LOCAL_PASSIVES_TEST and Services.updater==''and g_resources.getLayout()=='retro','Owned local retro probe only')
 mod=assert(modules.game_passives);spells=assert(mod.ClassSpells)
 connect(g_game,{onTextMessage=function(_,text)
  local ok,errorMessage=pcall(function()
   if text:find('QA_FAILED',1,true)then error(text)end
   local r=text:match('^PASSIVE_ROUTES_QA (.+)$');if r then
    local data=json.decode(r);assert(type(data)=='table'and data.guid==guids[tree],'Route fixture payload belongs to another subject')
    if data.label=='cast'then
     assert(type(data.observation)=='table'and type(data.observation.name)=='string'and type(data.observation.rolls)=='table','Malformed actual cast observation')
     castObservation=data.observation;castSequence=castSequence+1
    else
     assert(type(data.label)=='string'and type(data.snapshot)=='table'and data.snapshot.mode=='permanent'and data.snapshot.treeId==tree and data.snapshot.nodeCount==29,'Malformed permanent route snapshot')
     assert(type(data.runtime)=='table'and type(data.config)=='table'and type(data.targets)=='table','Missing authoritative route metrics')
     metrics=data;sequence=sequence+1
    end
   end
   local c=text:match('^CLASS_SPELL_QA (.+)$');if c then cm=json.decode(c);assert(type(cm)=='table'and type(cm.label)=='string','Malformed class fixture payload');classSequence=classSequence+1 end
  end)
  if not ok then fail(errorMessage)end
 end,onConnectionError=function(e)if not intentional then fail(e)end end})
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 G.account='class'..tree;G.password=G.account;login=ProtocolLogin.create();_G.routeEffectsLogin=login
 login.onLoginError=function(_,e)fail(e)end
 login.onCharacterList=function(_,chars)for _,v in ipairs(chars)do if v.name=='Starter '..names[tree]then g_game.loginWorld(G.account,G.password,v.worldName,v.worldIp,v.worldPort,v.name,'','');return end end;fail('Missing ordinary permanent fixture')end
 login:login('127.0.0.1',7174,G.account,G.password,'',false)
 wait('world login',function()return g_game.isOnline()end,16000);EnterGame.hide();player=assert(g_game.getLocalPlayer())
 stage('received-permanent-catalog')
 wait('real permanent catalog/learning',function()return state().ready and state().tree and spells.getState().catalog end)
 assert(state().mode=='permanent'and state().tree.id==tree and #state().tree.nodes==29,'Wrong ordinary connected class')
 local m=qa('state');assert(m.guid==guids[tree]and m.snapshot.respecCost==0,'Wrong disposable ordinary fixture/config');assert(m.runtime.nodeCount==29,'Wrong native diagnostic contract')
 assert(spells.getState().catalog.classId==tree,'Learned spell catalog belongs to another class')
 local paths=state().tree.topology.paths;assert(#paths==6,'Missing six independent routes')
 for index,path in ipairs(paths)do assert(path.advancedId==state().tree.topology.advancedMajorIds[index],'Changed authoritative advanced route ordering')end
 -- Prime exactly one real normal attack before pausing; native lastAttack=0 can
 -- otherwise schedule an immediate first auto even with a long weapon speed.
 stage('prime-one-real-normal');cleanArena();setupArena();oneHit();cleanArena()
 local tests={runBroad,runPrepared,runReturn,runRhythm,runSustain,runBrace}
 for i,test in ipairs(tests)do stage('route '..i..' '..paths[i].advancedId);test(paths[i]);emit('route-complete',{route=i,advanced=paths[i].advancedId,middle=paths[i].minorId})end
 stage('permanent-native-screenshot')
 assert(state().mode=='permanent'and spent(state().ranks)==16,'Permanent screenshot requires the actual tested16-point allocation')
 g_window.resize({width=1280,height=800});mod.show();mod.selectNode(paths[6].advancedId);mod.setDetailTab('talent');sleep(300)
 local window=assert(mod.getWindow());assert(window:isVisible(),'Permanent passive window did not open')
 assert(not window:getText():find('LOCAL TEST',1,true),'Local test title leaked into permanent UI')
 assert(not window:recursiveGetChildById('testLabel'):getText():find('TEST',1,true),'Test header leaked into permanent UI')
 assert(not window:recursiveGetChildById('endButton'):isVisible(),'End test control leaked into permanent UI')
 window:recursiveGetChildById('treeScroll'):setVirtualOffset({x=0,y=0});sleep(250)
 local screenshot='/passives-connected-permanent-'..tree..'.png';g_app.doScreenshot(screenshot)
 emit('permanent-native-screenshot',{path=screenshot,mode=state().mode,spent=spent(state().ranks),selected=state().selected,size={width=1280,height=800},endTestHidden=true})
 stage('final-cleanup')
 cleanArena();if spent(state().ranks)>0 then packet('reset')end;qa('cleanup')
 intentional=true;g_game.safeLogout();wait('real logout cleanup',function()return not g_game.isOnline()end)
 assert(not state().tree and not mod.getWindow(),'Logout retained passive UI');done=true
 print('PASSIVES_ROUTE_EFFECTS_OK '..tree..' '..json.encode({addedNodes=12,routes=6,evidence=#evidence,critChanceScope=tree=='lifekeeper'and'actual direct healing'or'separate deterministic critical gate required'}));g_app.exit()
end
local function resume()
 if failed or done then return end
 local ok,delay=coroutine.resume(co);if not ok then fail(debug and debug.traceback and debug.traceback(co,tostring(delay))or tostring(delay));return end
 if coroutine.status(co)~='dead'then scheduleEvent(resume,delay or 0)end
end
co=coroutine.create(main);scheduleEvent(resume,200)
scheduleEvent(function()if not done then fail('360-second per-class deadline')end end,360000)
