-- Real ordinary-player/Nameless/permanent persistence integration. Local GUID9003-5 only.
local mod,player,login,nextOnline,metrics
local seq,requestNo=0,0
local failed,done,intentional=false,false,false
local deathSeen=false
local results,npcMessages={},{}
local phase=PASSIVES_PROBE_CAP or 'berserker'
local legacy=phase=='legacy' or phase=='magic'
local account=phase=='legacy' and 'passivelegacy' or phase=='magic' and 'passivemagic' or 'passiveclass'
local character=phase=='legacy' and 'Passive Veteran' or phase=='magic' and 'Passive Mystic' or 'Passive Initiate'
local tree=legacy and PASSIVES_PROBE_TREE or 'reaver'
local focus=phase=='magic' and 5 or 2
local starters={reaver={'Cleaving Arc','Rend'},blademaster={'Focused Thrust','Flurry'},
 earthshaker={'Crushing Blow','Rolling Thunder'},marksman={'Blitzshot','Scattershot'},
 arcanist={'Resonant Burst','Arcane Surge'},lifekeeper={'Mending Thread','Essence Lash'}}
local function checkLearning(m,selected,label)
 assert(m.group==1 and type(m.learned)=='table'and type(m.savedSpells)=='table','Missing ordinary live/DB spell evidence')
 assert(m.learned['Light Healing']==true and (m.savedSpells['Light Healing']or 0)>=1,'Legacy Light Healing lost at '..label)
 local count=0
 for class,names in pairs(starters)do for _,name in ipairs(names)do
  local expected=selected and class==tree or false
  assert(m.learned[name]==expected,'Live class learning mismatch at '..label..': '..name)
  assert((m.savedSpells[name]or 0)==(expected and 1 or 0),'Saved class learning mismatch/duplicate at '..label..': '..name)
  if m.learned[name]then count=count+1 end
 end end
 assert(count==(selected and 2 or 0),'Wrong starter count at '..label)
 print('PASSIVES_PERMANENT_LEARNING_OK '..label..' class='..tree..' starters='..count..' legacy=Light Healing')
end
local function fail(e)
 if failed or done then return end;failed=true;print('PASSIVES_PERMANENT_FAILED '..tostring(e))
 if g_game.isOnline()then g_game.talk('/passivepermanent calm');g_game.talk('/passivepermanent clearstore');g_game.safeLogout()end
 scheduleEvent(function()g_app.exit()end,700)
end
local function later(ms,fn)
 scheduleEvent(function()if failed or done then return end;local ok,e=pcall(fn);if not ok then fail(e)end end,ms)
end
local function wait(label,pred,nextStep,ms)
 local deadline=g_clock.millis()+(ms or 10000)
 local function poll()if pred()then nextStep();return end;assert(g_clock.millis()<deadline,label..' timeout');later(70,poll)end
 later(120,poll)
end
local function s()return mod.getState()end
local function copy(t)local r={};for k,v in pairs(t or{})do r[k]=v end;return r end
local function spent(t)local n=0;for _,v in pairs(t or{})do n=n+v end;return n end
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
local function bloodguardBuild()
 local ranks=capstoneBuild(s().tree,'path_blood_return',{minor_vitality=3,minor_resilience=1,minor_recovery=4},'minor_focus')
 assert(ranks.cap_bloodguard==1 and ranks.minor_vitality==3 and ranks.major_guard==1 and ranks.mid_stout_heart==2,'Saved Vitality/Bloodguard lineage changed')
 return ranks
end
local function purchaseBuild(ranks)
 for _,tier in ipairs({'foundationMinorIds','coreMajorIds','midMinorIds','advancedMajorIds','capstoneIds'})do
  for _,id in ipairs(s().tree.topology[tier])do
   assert((s().draft[id]or 0)<=ranks[id],'Purchase would remove an existing saved rank: '..id)
   for _=(s().draft[id]or 0)+1,ranks[id]do assert(mod.changeRank(1,id),'Legal catalog purchase rejected '..id)end
  end
 end
 assert(spent(s().draft)==16 and not mod.validateDraft(s().draft),'UI did not assemble the legal16-point closure')
end
local function fixture(op,fn)
 local before=seq;g_game.talk('/passivepermanent '..op)
 wait('fixture '..op,function()return seq>before and metrics.label==op end,function()fn(metrics)end)
end
local function packet(action,ranks,fn,revision)
 requestNo=requestNo+1;local id='permanent:'..requestNo
 local payload={v=1,action=action,ranks=ranks,session=s().session,revision=revision or s().revision,requestId=id}
 if action=='reset'and s().mode=='permanent'then payload.quotedCost=s().respecCost;payload.respecCount=s().respecCount end
 g_game.getProtocolGame():sendExtendedOpcode(103,json.encode(payload))
 wait('request '..id,function()return results[id]~=nil end,function()fn(results[id])end)
end
local function click(id)
 local w=assert(mod.getWindow()):recursiveGetChildById(id);assert(w and w:isEnabled(),id..' disabled');signalcall(w.onClick,w)
end
local function uiApply(fn)
 local rev=s().revision;click('applyButton')
 wait('UI apply saved',function()return s().revision>rev and not s().pending end,fn)
end
local function dialog()
 for _,w in ipairs(g_ui.getRootWidget():getChildren())do
  local title=w:getText():lower()
  if w:getChildById('buttonHolder')and(title:find('reset',1,true)or title:find('respec',1,true))then return w end
 end
end
local function uiReset(accept,fn)
 local rev=s().revision;click('resetButton');local box=assert(dialog(),'Respec confirmation missing')
 local holder=box:getChildById('buttonHolder');local buttons=holder:getChildren();assert(#buttons>=2)
 local button=buttons[accept and 1 or 2]
 assert(button:getText()==(accept and 'Respec'or 'Cancel'),'Unexpected respec dialog button order')
 signalcall(button.onClick,button)
 print('PASSIVES_PERMANENT_UI_RESET accept='..tostring(accept)..' pending='..tostring(s().pending)..' quote='..tostring(s().respecCost)..' revision='..s().revision)
 if accept then wait('UI respec saved',function()return s().revision>rev and not s().pending end,fn)
 else later(250,function()assert(s().revision==rev);fn()end)end
end
local function doLogin(fn)
 print('PASSIVES_PERMANENT_LOGIN_BEGIN '..character)
 nextOnline=fn;G.account,G.password=account,account
 login=ProtocolLogin.create();_G.permanentLogin=login
 login.onLoginError=function(_,e)fail(e)end
 login.onCharacterList=function(_,list)
  print('PASSIVES_PERMANENT_LOGIN_LIST '..#list)
  for _,c in ipairs(list)do if c.name==character then print('PASSIVES_PERMANENT_LOGIN_WORLD '..c.name);g_game.loginWorld(account,account,c.worldName,c.worldIp,c.worldPort,c.name,'','');return end end
  fail('Fixture character absent')
 end
 login:login('127.0.0.1',7174,account,account,'',false)
 wait('world login',function()return g_game.isOnline()end,function()end,15000)
end
local function relog(fn,drop)
 intentional=true
 if drop then g_game.getProtocolGame():disconnect();g_game.forceLogout()else g_game.safeLogout()end
 wait('offline',function()return not g_game.isOnline()end,function()
  assert(not mod.getWindow()and not mod.getStatusWindow()and not mod.getReopenButton(),'Logout retained passive windows/button')
  -- Login and game sockets share the ordinary IP connection throttle.
  -- Allow its five-second window to expire between deliberate reconnects.
  later(6000,function()doLogin(fn)end)
 end)
end
local function npcSay(text,needle,fn)
 local before=#npcMessages
 g_game.talkChannel(MessageModes.NpcTo,0,text)
 if not needle then later(1200,fn);return end
 wait('NPC '..text..' -> '..needle,function()
  for i=before+1,#npcMessages do if npcMessages[i]:lower():find(needle:lower(),1,true)then return true end end
 end,fn,25000)
end
local function checkPermanent(expectedPoints)
 assert(s().active and s().mode=='permanent'and s().tree.id==tree,'Wrong permanent class/profile')
 assert(s().points==expectedPoints,'Wrong earned budget: '..tostring(s().points))
 -- Each login is checked separately before this explicit inspection opens UI.
 assert(mod.show(),'Permanent tree cannot be explicitly opened')
 assert(mod.getWindow()and not mod.getWindow():getText():find('TEST',1,true),'Permanent window still labelled TEST')
 assert(not mod.getWindow():recursiveGetChildById('endButton'):isVisible(),'Permanent class exposes End Test')
 assert(s().classLocked and mod.getReopenButton()and mod.getReopenButton():isVisible(),'Permanent class lacks ordinary retro reopen button')
end
local function reopenViaButton(fn)
 local button=assert(mod.getReopenButton(),'Ordinary passive button missing')
 assert(button:isVisible()and button:isEnabled(),'Ordinary passive button unusable')
 click('closeButton')
 assert(not mod.getWindow():isVisible()and not button:isOn(),'Close did not clear button state')
 -- Existing topmenu buttons invoke their callback from mouse release, not onClick.
 local pos=button:getPosition()
 signalcall(button.onMouseRelease,button,{x=pos.x+math.floor(button:getWidth()/2),y=pos.y+math.floor(button:getHeight()/2)},MouseLeftButton)
 wait('ordinary topmenu reopen',function()return mod.getWindow()and mod.getWindow():isVisible()and button:isOn()end,function()
  print('PASSIVES_PERMANENT_TOPMENU_REOPEN_OK');fn()
 end)
end
local function finish()
 reopenViaButton(function()
  mod.selectNode('cap_bloodguard')
  g_window.resize({width=800,height=640})
  later(400,function()
   local rootRect=g_ui.getRootWidget():getRect();local rect=mod.getWindow():getRect()
   assert(rect.x>=rootRect.x and rect.y>=rootRect.y and rect.x+rect.width<=rootRect.x+rootRect.width and rect.y+rect.height<=rootRect.y+rootRect.height,'Permanent window outside 800x640 viewport')
   for _,id in ipairs({'applyButton','resetButton','closeButton'})do
    local w=mod.getWindow():recursiveGetChildById(id);local r=w:getRect()
    assert(w:isVisible()and r.x>=rect.x and r.y>=rect.y and r.x+r.width<=rect.x+rect.width and r.y+r.height<=rect.y+rect.height,'Permanent control clipped: '..id)
   end
   g_app.doScreenshot('/passives-permanent-small.png')
   g_window.resize({width=1280,height=800})
   later(400,function()
    g_app.doScreenshot('/passives-permanent-ready.png')
    print('PASSIVES_PERMANENT_READY class='..tree..' points='..s().points..' spent='..spent(s().ranks))
    intentional=true;g_game.safeLogout()
    wait('final offline',function()return not g_game.isOnline()end,function()
     assert(not mod.getWindow()and not mod.getStatusWindow()and not mod.getReopenButton(),'Final logout retained passive UI/button')
     done=true;print('PASSIVES_PERMANENT_OK');scheduleEvent(function()g_app.exit()end,400)
    end)
   end)
  end)
 end)
end
local function finalBuild()
 purchaseBuild(bloodguardBuild())
 uiApply(function()
  assert(s().ranks.cap_bloodguard==1 and s().ranks.minor_vitality==3 and spent(s().ranks)==16 and s().points==17,'Final saved Bloodguard build/budget changed')
  finish()
 end)
end
local function growth()
 fixture('lower',function(m)
  assert(m.level==30);wait('earned points survive loss',function()return s().points==16 end,function()
   fixture('nextpoint',function(m)
    assert(m.level==43);wait('new milestone earns once',function()return s().points==17 end,function()
     fixture('state',function(m)
      assert(m.saved.points==17 and m.saved.respecCount==2,'Earned/respec persistence wrong')
      print('PASSIVES_PERMANENT_LEVEL_LOSS_MILESTONE_OK')
      -- Preserve the test player's full chosen build for manual inspection.
      -- Reset here costs 2000: give the fixture that amount, then exercise UI.
      fixture('fund',function()uiReset(true,function()
       assert(spent(s().ranks)==0 and s().respecCount==3);finalBuild()
      end)end)
     end)
    end)
   end)
  end)
 end)
end
local function tcp()
 fixture('armdetach',function()relog(function()
  checkPermanent(16);assert(s().ranks.minor_vitality==5,'TCP lost saved ranks')
  fixture('state',function(m)
   local o=assert(m.observed.detach);assert(o.onlineEntity and o.sameEntity and o.ip==0 and o.maxHP==735,'Detached object retained derived HP')
   assert(m.saved.maxHP==735,'TCP persisted passive maxHP');print('PASSIVES_PERMANENT_TCP_OK');growth()
  end)
 end,true)end)
end
local function store()
 fixture('armstore',function()relog(function()
  checkPermanent(16);fixture('state',function(m)
   local o=assert(m.observed.store);assert(o.onlineEntity and o.sameEntity and o.ip==0 and o.maxHP==735,'Store retained derived HP')
   assert(m.saved.maxHP==735 and s().ranks.minor_vitality==5,'Store lost/contaminated persistence')
   print('PASSIVES_PERMANENT_STORE_OK');fixture('clearstore',function()tcp()end)
  end)
 end)end)
end
local function death()
 local session=s().session;g_game.talk('/passivepermanent death')
 -- Ordinary PvE death removes the creature, even when fixture skill loss is disabled.
 wait('real death clears active build',function()return deathSeen and not s().active end,function()
  relog(function()
   checkPermanent(16)
   assert(s().session~=session and s().ranks.minor_vitality==5,'Death lost saved ranks/session')
   assert((s().runtime.rage or 0)==0 and (s().runtime.guardHits or 0)==0 and (s().runtime.ward or 0)==0 and (s().runtime.wardMs or 0)==0 and (s().runtime.routeReturnBudget or 0)==0,'Death retained combat/ward/return charges')
   print('PASSIVES_PERMANENT_DEATH_OK');store()
  end)
 end,12000)
end
local function paid()
 fixture('emptybank',function()
  assert(mod.changeRank(1,'minor_vitality'));uiApply(function()
   local rev=s().revision
   packet('reset',nil,function(r)
    assert(not r.ok and s().revision==rev and s().ranks.minor_vitality==1,'Unfunded respec changed saved ranks')
    fixture('state',function(m)
     assert(m.bank==0 and m.saved.respecCount==1,'Rejected respec charged/count changed')
     fixture('fund',function()uiReset(true,function()
      fixture('state',function(m)
       assert(m.bank==1000 and m.saved.respecCount==2 and spent(s().ranks)==0,'Paid respec amount/count wrong')
       assert(s().respecCost==2000 and s().tree.id==tree,'Next fee/class wrong')
       print('PASSIVES_PERMANENT_FREE_PAID_UNFUNDED_RESPEC_OK')
       for _=1,5 do assert(mod.changeRank(1,'minor_vitality'))end
       uiApply(function()relog(function()checkPermanent(16);death()end)end)
      end)
     end)end)
    end)
   end)
  end)
 end)
end
local function resetChecks()
 fixture('gates',function(m)
  assert(m.observed.classRejected and m.observed.startRejected and m.saved.classId==tree)
  fixture('combat',function()
   local rev=s().revision
   packet('reset',nil,function(r)
    assert(not r.ok and s().revision==rev,'Combat reset accepted')
    fixture('calm',function()uiReset(false,function()
     assert(spent(s().ranks)==16 and s().respecCount==0,'Cancel consumed free reset')
     uiReset(true,function()assert(spent(s().ranks)==0 and s().respecCount==1 and s().respecCost==1000);paid()end)
    end)end)
   end)
  end)
 end)
end
local function invalids()
 fixture('calm',function()
 local rev=s().revision
 packet('apply',{},function(r)
  assert(not r.ok and r.error:lower():find('respec',1,true) and s().revision==rev and s().ranks.cap_bloodguard==1 and s().ranks.minor_vitality==3,'Rank-removal bypass accepted/wrong saved-rank guard')
  local excess=copy(s().ranks);excess.minor_vitality=4
  packet('apply',excess,function(r)
   assert(not r.ok and r.error:find('budget',1,true) and s().revision==rev,'Overspend accepted/wrong guard')
   packet('apply',copy(s().ranks),function(r)
    assert(not r.ok and s().revision==rev,'Stale revision accepted')
    print('PASSIVES_PERMANENT_PROTOCOL_GATES_OK');resetChecks()
   end,rev-1)
  end)
 end)
 end)
end
local function capstone()
 fixture('advance',function()
  wait('level40=16points',function()return s().points==16 end,function()
   assert(s().ranks.minor_vitality==3,'Initial saved3Vitality must be retained')
   purchaseBuild(bloodguardBuild())
   assert(spent(s().draft)==16 and not mod.changeRank(-1,'minor_vitality'),'Saved rank removal allowed')
   uiApply(function()
    checkPermanent(16);mod.selectNode('cap_bloodguard');g_app.doScreenshot('/passives-permanent-capstone.png')
    relog(function()
     checkPermanent(16)
     assert(s().ranks.cap_bloodguard==1 and s().ranks.minor_vitality==3 and s().ranks.mid_stout_heart==2,'Saved Bloodguard lineage lost on reconnect')
     --3% Vitality +2% Guard +1% Stout Heart, all applied to base735 once.
     assert(player:getMaxHealth()==735+math.floor(735*.06),'Bloodguard mid-Minor maxHP composition changed')
     fixture('state',function(m)assert(m.saved.maxHP==735,'Bloodguard derived maxHP leaked into persistence');print('PASSIVES_PERMANENT_CAPSTONE_RELOGIN_OK bloodguard');invalids()end)
    end)
   end)
  end)
 end)
end
local function firstBuild()
 checkPermanent(3)
 fixture('state',function(m)
  assert(m.group==1 and m.vocation==3 and m.focus==2 and m.quest==8 and m.level==1,'Ascension/focus/quest did not persist')
  checkLearning(m,true,'third-ascension')
  print('PASSIVES_PERMANENT_THIRD_ASCENSION_OK')
  fixture('equip',function()
   local firstRevision=s().revision
   local baseHP=player:getMaxHealth()
   assert(s().respecCount==0 and s().respecCost==0 and spent(s().ranks)==0,'First allocation fixture already consumed its free respec')
   assert(mod.changeRank(1,'minor_vitality') and mod.changeRank(-1,'minor_vitality'),'Unsaved first rank cannot be freely undone')
   assert(spent(s().draft)==0 and spent(s().ranks)==0 and s().revision==firstRevision and player:getMaxHealth()==baseHP,'First draft changed active ranks/HP/revision')
   for _=1,3 do assert(mod.changeRank(1,'minor_vitality'))end
   assert(player:getMaxHealth()==baseHP and spent(s().ranks)==0,'Unapplied first draft activates effects')
   uiApply(function()
    local savedRevision=s().revision
    assert(s().ranks.minor_vitality==3 and s().respecCount==0 and s().respecCost==0,'First Apply did not save ranks or consumed free respec')
    assert(not mod.changeRank(-1,'minor_vitality'),'First saved rank could be removed through UI without Respec')
    packet('apply',{minor_vitality=2},function(rejected)
     assert(not rejected.ok and rejected.error:lower():find('respec',1,true) and s().revision==savedRevision and s().ranks.minor_vitality==3,'First saved rank bypassed native Respec guard')
     packet('apply',{minor_vitality=2},function(stale)
      assert(not stale.ok and stale.error:find('Stale',1,true) and s().revision==savedRevision and s().ranks.minor_vitality==3,'Revision0 bypassed first-allocation guard')
      fixture('save',function(m)
    assert(m.saved.classId==tree and m.saved.maxHP==150 and m.saved.points==3,'First build/baseHP not persisted')
    assert(m.saved.respecCount==0,'Rejected first-rank changes consumed the free Respec')
    print('PASSIVES_PERMANENT_FIRST_APPLY_LOCK_OK draftUndoFree=true savedDecreaseRejected=true staleRevision0Rejected=true respecCount=0')
    checkLearning(m,true,'ordinary-save')
    relog(function()
     checkPermanent(3);assert(s().ranks.minor_vitality==3 and player:getMaxHealth()==154,'First build failed login restore')
     fixture('state',function(m)checkLearning(m,true,'third-ascension-relogin');capstone()end)
    end)
      end)
     end,0)
    end)
   end)
  end)
 end)
end
local function choose()
 fixture('npc',function()
  -- Wait for the LAST greeting line: earlier lines mention discipline before
  -- queued class options finish. Both third ascension and legacy end with Which.
  npcSay('hi','which',function()
   npcSay(tree,'certain',function()
    npcSay('no','reconsider',function()
     fixture('state',function(m)assert(not m.saved.classId,'Declined class was persisted');checkLearning(m,false,'declined-choice')
      npcSay(tree,'certain',function()
       if legacy then
        npcSay('yes',nil,function()
         wait('legacy choice activates tree',function()return s().active and s().mode=='permanent'and s().tree.id==tree end,function()
          checkPermanent(16);fixture('state',function(m)
           assert(m.focus==focus and m.level==40 and m.group==1,'Legacy class changed focus/level/access')
           checkLearning(m,true,'legacy-choice')
           reopenViaButton(function()
            g_app.doScreenshot('/passives-permanent-'..tree..'.png')
            relog(function()
             checkPermanent(16)
             fixture('state',function(m)
              checkLearning(m,true,'legacy-relogin');print('PASSIVES_PERMANENT_LEGACY_FOCUS_OK '..tree)
              intentional=true;g_game.safeLogout();later(800,function()done=true;print('PASSIVES_PERMANENT_OK');g_app.exit()end)
             end)
            end)
           end)
          end)
         end)
        end)
       else
        intentional=true;g_game.talkChannel(MessageModes.NpcTo,0,'yes')
        wait('third ascension kick',function()return not g_game.isOnline()end,function()later(2000,function()doLogin(firstBuild)end)end)
       end
      end)
     end)
    end)
   end)
  end)
 end)
end
local function initial()
 if phase=='resume'then
  checkPermanent(16);assert(s().ranks.cap_bloodguard==1 and s().ranks.minor_vitality==3,'Resume requires the saved29-node Bloodguard fixture')
  relog(function()checkPermanent(16);assert(s().ranks.cap_bloodguard==1 and s().ranks.minor_vitality==3);print('PASSIVES_PERMANENT_CAPSTONE_RELOGIN_OK bloodguard');invalids()end);return
 end
 assert(not s().active,'Fixture started with class already selected')
 fixture('state',function(m)
  assert(m.group==1 and not m.saved.classId,'Fixture is not a fresh ordinary player')
  checkLearning(m,false,'before-choice')
  if legacy then
   fixture('stone',function(m)
    local originalLevel,originalMana=player:getLevel(),player:getMana()
    g_game.talk('arcanis exevo infus')
    wait('real Oracle Stone revisit',function()return player:getPosition().z==4 end,function()
     assert(player:getLevel()==originalLevel and player:getMana()==originalMana,'Revisit consumed progression/mana')
     fixture('state',function(m)
      assert(m.focus==focus and not m.saved.classId,'Oracle revisit changed focus/class')
      print('PASSIVES_PERMANENT_ORACLE_REVISIT_OK');choose()
     end)
    end)
   end)
  else fixture('gates',function(m)assert(m.observed.classRejected);choose()end)end
 end)
end
later(200,function()
 assert(LOCAL_PASSIVES_TEST and Services.updater==''and g_resources.getLayout()=='retro')
 g_window.resize({width=1280,height=800});mod=assert(modules.game_passives)
 ProtocolGame.registerExtendedJSONOpcode(103,function(_,_,data)
  if data.action=='end'or data.action=='refresh'or data.action=='catalog'or data.action=='snapshot'then print('PASSIVES_PERMANENT_PACKET '..data.action..' session='..tostring(data.session)..' active='..tostring(data.active))end
  if data.action=='result'and data.requestId then results[data.requestId]=data;print('PASSIVES_PERMANENT_RESULT '..data.requestId..' ok='..tostring(data.ok)..' error='..tostring(data.error))end
 end)
 connect(g_game,{onTalk=function(name,level,mode,text)if name=='The Nameless'then npcMessages[#npcMessages+1]=text;print('PASSIVES_PERMANENT_NPC '..text)end end,
  onTextMessage=function(_,text)
   print('PASSIVES_PERMANENT_MESSAGE '..text)
   if text=='You are dead.'then deathSeen=true end
   if text:find('PASSIVES_PERMANENT_FIXTURE_FAILED',1,true)then fail(text)end
   local raw=text:match('^PASSIVE_PERMANENT_STATE (.+)$');if raw then metrics=json.decode(raw);seq=seq+1 end
  end,
  onGameStart=function()print('PASSIVES_PERMANENT_GAME_START');EnterGame.hide();player=assert(g_game.getLocalPlayer());intentional=false;local fn=nextOnline;nextOnline=nil
   wait('handshake',function()return s().ready and(not s().classId or s().classId==''or s().active)end,function()later(400,function()
    assert(not mod.getWindow()or not mod.getWindow():isVisible(),'Login automatically opened the full passive tree')
    if s().active then
     assert(mod.getReopenButton()and mod.getReopenButton():isVisible(),'Silent login did not restore the ordinary passive reopen button')
     print('PASSIVES_PERMANENT_LOGIN_CLOSED_OK class='..s().tree.id)
    end
    fn()
   end)end,12000)
  end,
  onLoginError=function(e)fail('World login rejected: '..tostring(e))end,
  onConnectionError=function(e)if not intentional then fail(e)end end})
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA);doLogin(initial)
end)
scheduleEvent(function()if not done then fail('Permanent integration timeout')end end,300000)
