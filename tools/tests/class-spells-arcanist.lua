-- Real ordinary-player regression: starter pulses and permanent Arcanist caps.
-- Requires Starter Arcanist (classarcanist/classarcanist), already chosen class,
-- empty ranks, 16 earned points and unused first free respec. No forced cap charge.
local mod, spells, metrics, login
local sequence, request = 0, 0
local results = {}
local failed, done, intentional = false, false, false
local onOnline, oldSession
local words = 'exori arcan pul'
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
local conduit,resonance
local openingDiscountWait=true
local foundation={minor_critical=4,minor_power=4,minor_recovery=4}
local function fail(reason)
  if failed or done then return end
  failed = true
  print('CLASS_SPELLS_ARCANIST_FAILED '..tostring(reason))
  if g_game.isOnline() then g_game.cancelAttack(); g_game.safeLogout() end
  scheduleEvent(function()g_app.exit()end,650)
end
local function later(ms,fn)
  scheduleEvent(function()
    if failed or done then return end
    local ok,reason=pcall(fn);if not ok then fail(reason)end
  end,ms)
end
local function wait(label,predicate,fn,timeout)
  local deadline=g_clock.millis()+(timeout or 10000)
  local function poll()
    if predicate()then fn();return end
    assert(g_clock.millis()<deadline,label..' timeout')
    later(60,poll)
  end
  later(70,poll)
end
local function state()return assert(mod.getState())end
local function qa(command,fn)
  local previous=sequence;local label=command:match('^%S+')
  g_game.talk('/classspellqa '..command)
  wait('fixture '..command,function()return sequence>previous and metrics.label==label end,function()fn(metrics)end)
end
local function spent(ranks)local total=0;for _,v in pairs(ranks or{})do total=total+v end;return total end
local function raw(message)
  message.v=1;request=request+1;message.requestId='arcanist-regression-'..request
  assert(g_game.getProtocolGame()):sendExtendedOpcode(103,json.encode(message))
  return message.requestId
end
local function equalRanks(a,b)
  for id,value in pairs(a or{})do if value~=(b[id]or 0)then return false end end
  for id,value in pairs(b or{})do if value~=(a[id]or 0)then return false end end
  return true
end
local function apply(ranks,fn)
  assert(spent(ranks)==16 and not mod.validateDraft(ranks),'Illegal29-node16-point Arcanist allocation')
  local before=state().revision
  local id=raw({action='apply',session=state().session,revision=before,ranks=ranks})
  wait('native allocation result',function()return results[id]~=nil end,function()
    assert(results[id].ok,'Allocation rejected: '..tostring(results[id].error))
    wait('native allocation snapshot',function()return state().revision>before and equalRanks(state().ranks,ranks)end,function()openingDiscountWait=true;fn()end)
  end)
end
local function freeRespec(fn)
  assert(state().respecCost==0 and state().respecCount==0,'First free respec fixture required')
  local revision=state().revision
  local id=raw({action='reset',session=state().session,revision=revision,
    quotedCost=state().respecCost,respecCount=state().respecCount})
  wait('native free respec result',function()return results[id]~=nil end,function()
    assert(results[id].ok,'Respec rejected: '..tostring(results[id].error))
    wait('native free respec',function()return state().revision>revision and spent(state().ranks)==0 end,function()
    assert(state().classId=='arcanist' and state().respecCount==1,'Respec changed class or failed to increment count')
    print('CLASS_SPELLS_ARCANIST_FREE_RESPEC_OK');fn()
    end)
  end)
end
local function targetMap(m)
  local map={};for _,t in ipairs(m.targets or{})do map[t.id]=t.hp end;return map
end
local function loss(before,after)
  assert(#before.targets==3 and #after.targets==3,'Three stable live arena targets required')
  local hp=targetMap(before);local total,hits=0,0
  for _,t in ipairs(after.targets)do
    assert(hp[t.id],'Target identity changed during cast')
    local amount=hp[t.id]-t.hp;assert(amount>=0,'Measured target healed')
    total=total+amount;if amount>0 then hits=hits+1 end
  end
  assert(hits<=1,'A focused pulse/echo hit a secondary target')
  return total
end
local function ready(fn)
  wait('actual shared cooldown',function()
    return (spells.getState().shared.combat or 0)<=g_clock.millis()
  end,fn,12000)
end
-- Set a real target. Its immediate ordinary swing happens before the baseline;
-- stop the target promptly after the first spell pulse, before later autoattacks.
local function beginPulse(fn)
  ready(function()qa('focus',function()
    -- The ordinary opening swing may naturally crit. Let its real8-second
    -- prepared discount expire once per build. The equipped fixture weapon's
    --600-second attack interval then prevents another ordinary opening swing.
    -- Do not wait8.5seconds between later casts: Resonance readiness lasts12seconds.
    local settle=openingDiscountWait and 8500 or 250;openingDiscountWait=false
    later(settle,function()qa('state',function(before)
      assert(state().ranks.minor_efficiency==0 and state().ranks.mid_measured_breath==0,'Unexpected permanent spell discount')
      assert((before.runtime.routePreparedMs or 0)==0,'Unexpected prepared primary spell bonus')
      local castAt=g_clock.millis();g_game.talk(words)
      later(35,function()qa('stop',function(first)
        assert(g_clock.millis()-castAt<400,'First-pulse sample arrived after second pulse')
        assert(loss(before,first)>0,'First real spell pulse did not land')
        assert(first.runtime.pendingActions==1,'Pulse cast lacks one retained native action')
        local mana=before.mana-first.mana
        -- All earlier bills were integral18 mana; its fractional carry is zero.
        assert(mana==18,'First pulse did not pay exactly18 actual mana: '..mana)
        fn(before,first,castAt,mana)
      end)end)
    end)end)
  end)end)
end
local function sampleAt(castAt,offset,fn)
  later(math.max(25,castAt+offset-g_clock.millis()),function()qa('state',fn)end)
end
local function validatePulse(before,first,middle,last,mana)
  assert(loss(first,middle)>0 and loss(middle,last)>0,'Second or third real pulse missing')
  assert(before.mana-last.mana==mana,'A later pulse charged/refunded mana')
  assert(last.runtime.pendingActions==0,'Native pulse action retained after final callback')
  assert(last.ammo==before.ammo,'Wand spell consumed an ammunition item')
end
local doLogin, finish, testResonance, logoutProbe
finish=function()
  qa('cleanup',function()
    intentional=true;g_game.safeLogout()
    wait('final logout cleanup',function()return not g_game.isOnline()end,function()
      assert(not spells.getState().catalog and not spells.getWindow(),'Class spell UI survived logout')
      done=true;print('CLASS_SPELLS_ARCANIST_OK');g_app.exit()
    end)
  end)
end
logoutProbe=function()
  beginPulse(function(before,first,castAt,mana)
    -- A live offensive cast legitimately prevents safeLogout. Drop the real TCP
    -- connection, as in the existing permanent lifecycle probe; do not clear the
    -- server's fight condition or fabricate a successful logout.
    oldSession=state().session;intentional=true
    g_game.getProtocolGame():disconnect();g_game.forceLogout()
    wait('logout with pending spell',function()return not g_game.isOnline()end,function()
      assert(not spells.getState().catalog,'Pending logout retained catalog')
      later(6500,function()doLogin(function()
        assert(state().session~=oldSession,'Reconnect reused old class/action session')
        qa('state',function(after)
          assert(loss(first,after)==0,'Old delayed spell damaged its target after logout')
          assert(after.runtime.pendingActions==0 and after.runtime.progress==0,'Logout retained old pulse/cap state')
          print('CLASS_SPELLS_ARCANIST_PENDING_TCP_DETACH_OK');finish()
        end)
      end)end)
    end)
  end)
end
testResonance=function()
  qa('setup',function()
    freeRespec(function()apply(resonance,function()
      local count=0
      local function nextCast()
        count=count+1
        beginPulse(function(before,first,castAt,mana)
          local previousProc=before.runtime.capstoneProcCount
          sampleAt(castAt,650,function(middle)
            sampleAt(castAt,1220,function(last)
              validatePulse(before,first,middle,last,mana)
              assert(last.runtime.capstoneProcCount==previousProc,'Resonance echo fired before final-pulse budget settled')
              if count<4 then
                assert(last.runtime.progress==count,'Three pulses counted as several successful casts')
                if count==3 then assert(last.runtime.readyMs>0,'Third real cast failed to prepare Resonance')end
                print('CLASS_SPELLS_ARCANIST_RESONANCE_CAST_OK '..count)
                nextCast()
              else
                assert(last.runtime.progress==0 and last.runtime.readyMs==0,'Prepared echo was not consumed once')
                local totalBudget=loss(before,last)
                sampleAt(castAt,1780,function(after)
                  local echo=loss(last,after)
                  -- Fixture wand 2190/shield2512 has zero special crit; dummy has
                  -- zero armor/element resistance. Measured spell HP loss equals
                  -- native pre-critical accumulated budget, including4.5% core/foundation
                  -- power and the Focused Casting route Minor's1% primary bonus/carry.
                  assert(echo==math.floor(totalBudget*0.30),'Echo budget differs from 30% of all three pulses: '..echo..' / '..totalBudget)
                  assert(after.runtime.capstoneProcCount==previousProc+1 and after.runtime.lastCapstoneProc=='Resonance','Echo recursively/multiply triggered passives')
                  assert(after.runtime.pendingActions==0,'Completed echo retained cast action')
                  print('CLASS_SPELLS_ARCANIST_RESONANCE_TOTAL_BUDGET_OK '..totalBudget..' echo='..echo)
                  g_app.doScreenshot('/class-spells-arcanist-resonance-complete.png')
                  logoutProbe()
                end)
              end
            end)
          end)
        end)
      end
      later(11000,nextCast) -- Wait out the real teleport pacification.
    end)end)
  end)
end
local function initial()
  assert(state().active and state().mode=='permanent'and state().classId=='arcanist','Chosen permanent Arcanist fixture required')
  assert(spent(state().ranks)==0 and state().points>=16,'Empty 16-point fixture required')
  conduit=capstoneBuild(state().tree,'path_broad_stroke',foundation,'minor_power')
  resonance=capstoneBuild(state().tree,'path_deliberate_cut',foundation,'minor_power')
  assert(conduit.cap_conduit==1 and resonance.cap_resonance==1,'Catalog routes changed their capstone families')
  qa('setup',function()apply(conduit,function()
    later(11000,function()beginPulse(function(before,first,castAt,mana)
      local previousProc=before.runtime.capstoneProcCount
      sampleAt(castAt,650,function(middle)
        sampleAt(castAt,1220,function(last)
          validatePulse(before,first,middle,last,mana)
          assert(last.runtime.progress==1 and last.runtime.readyMs==0,'One pulsed cast prepared Conduit as if three casts')
          assert(last.runtime.capstoneProcCount==previousProc,'Conduit triggered from spell pulses')
          print('CLASS_SPELLS_ARCANIST_CONDUIT_ONE_CAST_OK')
          testResonance()
        end)
      end)
    end)end)
  end)end)
end
doLogin=function(fn)
  onOnline=fn;G.account='classarcanist';G.password=G.account
  login=ProtocolLogin.create();_G.classSpellsArcanistLogin=login
  login.onLoginError=function(_,error)fail(error)end
  login.onCharacterList=function(_,list)
    for _,entry in ipairs(list)do if entry.name=='Starter Arcanist'then
      g_game.loginWorld(G.account,G.password,entry.worldName,entry.worldIp,entry.worldPort,entry.name,'','');return
    end end
    fail('Starter Arcanist account fixture absent')
  end
  login:login('127.0.0.1',7174,G.account,G.password,'',false)
end
later(250,function()
  assert(LOCAL_PASSIVES_TEST==true and Services.updater==''and g_resources.getLayout()=='retro')
  mod=assert(modules.game_passives);spells=assert(mod.ClassSpells)
  ProtocolGame.registerExtendedJSONOpcode(103,function(_,_,data)
    if data.action=='result' and data.requestId then
      results[data.requestId]=data
      print('CLASS_SPELLS_ARCANIST_RESULT '..data.requestId..' ok='..tostring(data.ok)..' error='..tostring(data.error))
    end
  end)
  connect(g_game,{
    onTextMessage=function(_,message)
      if message:find('CLASS_SPELL_QA_FAILED',1,true)then fail(message);return end
      local raw=message:match('^CLASS_SPELL_QA (.+)$')
      if raw then metrics=json.decode(raw);sequence=sequence+1 end
      print('CLASS_SPELLS_ARCANIST_MESSAGE '..message)
    end,
    onGameStart=function()
      EnterGame.hide();intentional=false
      local fn=onOnline;onOnline=nil
      wait('permanent class handshake',function()return state().ready and state().active and spells.getState().catalog end,function()later(350,fn)end)
    end,
    onLoginError=function(error)fail(error)end,
    onConnectionError=function(error)if not intentional then fail(error)end end,
  })
  g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
  doLogin(initial)
end)
scheduleEvent(function()if not done then fail('180-second Arcanist regression deadline')end end,180000)
