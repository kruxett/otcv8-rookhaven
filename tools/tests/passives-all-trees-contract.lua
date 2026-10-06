-- Live six-catalog/18-preset/weapon-gating contract; no synthetic combat claims.
local ids={'reaver','blademaster','earthshaker','marksman','arcanist','lifekeeper'}
local caps={reaver={'berserker','bloodletting','bloodguard'},blademaster={'duelist','riposte','bladestorm'},earthshaker={'aftershock','stoneguard','stonebond'},marksman={'deadeye','skirmisher','quarry'},arcanist={'conduit','resonance','spellweaver'},lifekeeper={'renewal','aegis','concord'}}
local mod,login,failed,done,finishing
local replies={}
local function fail(reason)
 if failed or done then return end
 failed=true;print('PASSIVES_ALL_TREES_FAILED '..tostring(reason))
 if g_game.isOnline()then g_game.cancelAttack();g_game.talk('/passiveqa quiesce Passive Tester');g_game.safeLogout()end
 scheduleEvent(function()g_app.exit()end,700)
end
local function later(ms,fn)
 scheduleEvent(function()if failed or done then return end;local ok,err=pcall(fn);if not ok then fail(err)end end,ms)
end
local function wait(label,predicate,nextStep)
 local deadline=g_clock.millis()+8000
 local function poll()
  if predicate()then nextStep();return end
  assert(g_clock.millis()<deadline,label..' timeout');later(60,poll)
 end
 later(80,poll)
end
local function state()return mod.getState()end
local function sum(ranks)local n=0;for _,r in pairs(ranks)do n=n+r end;return n end
local function command(text,nextStep)
 g_game.talk(text);later(350,nextStep)
end
local function copy(ranks)local out={};for id,r in pairs(ranks or {})do out[id]=r end;return out end
local function same(a,b)
 for id,r in pairs(a)do if r~=(b[id]or 0)then return false end end
 for id,r in pairs(b)do if r~=(a[id]or 0)then return false end end
 return true
end
local function rejectRanks(label,ranks,nextStep)
 local revision,session,saved=state().revision,state().session,copy(state().ranks)
 local request='branch-gate-'..label
 g_game.getProtocolGame():sendExtendedOpcode(103,json.encode({v=1,action='apply',
  session=session,revision=revision,requestId=request,ranks=ranks}))
 wait(label..' authoritative rejection',function()return replies[request]~=nil end,function()
  local reply=replies[request]
  assert(reply.ok==false and reply.error:find('Core major requires',1,true),label..' accepted an invalid branch allocation')
  assert(state().revision==revision and state().session==session and same(saved,state().ranks),label..' rejection mutated saved ranks')
  print('PASSIVES_BRANCH_SERVER_REJECT_OK '..label)
  nextStep()
 end)
end
local function prerequisites(tree,nextStep)
 local groups=assert(state().tree.branchGroups,'branch grouping metadata missing')
 assert(#groups==4,'four stable branches required')
 local expected={'precision','pressure','sustain','guard'}
 local build={}
 for index,group in ipairs(groups)do
  assert(group.id==expected[index] and #group.minorIds==2,'branch IDs/order are incorrect')
  assert(group.unlockPoints==4,'UI-only polish unexpectedly changed core-major balance')
  if tree=='lifekeeper'and group.id=='precision'then assert(group.name=='Healing','healer branch must describe healing')end
  local low={[group.minorIds[1]]=3,[group.majorId]=1}
  assert(mod.validateDraft(low),'UI accepted three minor ranks for '..group.id)
  low[group.minorIds[2]]=1
  assert(not mod.validateDraft(low),'UI rejected a legal3+1 split for '..group.id)
  build[group.minorIds[1]],build[group.minorIds[2]],build[group.majorId]=3,1,1
 end
 local guard,sustain=groups[4],groups[3]
 local pane=assert(mod.getBranchWidget('guard'))
 assert(pane.points==0 and pane.required==4 and pane.label:getText()==guard.name,'fresh branch progress incorrect')
 for _=1,3 do assert(mod.changeRank(1,guard.minorIds[1]))end
 assert(mod.selectNode(guard.majorId))
 local guardNode=mod.getNodeWidget(guard.majorId)
 assert(pane.points==3 and pane.required==4 and pane.label:getTooltip():find('3 minor ranks',1,true),'branch progress failed to update')
 assert(guardNode.locked and guardNode:getChildById('nodeLock'):isVisible(),'missing prerequisite lock')
 local requirements=assert(mod.getWindow():recursiveGetChildById('nodeRequirements'))
 local text='';local function collect(w)text=text..w:getText()..'\n';for _,child in ipairs(w:getChildren())do collect(child)end end;collect(requirements)
 assert(text:find('Combined: 3/4',1,true) and text:find(state().nodes[guard.minorIds[1]].name,1,true) and text:find(state().nodes[guard.minorIds[2]].name,1,true),'details do not explain missing Guard points')
 assert(not mod.getWindow():recursiveGetChildById('addRank'):isEnabled(),'locked major Add button enabled')
 later(300,function()
 g_app.doScreenshot('/passives-branch-lock-'..tree..'.png')
 assert(mod.changeRank(1,guard.minorIds[2]))
 assert(pane.points==4 and not guardNode.locked and not guardNode:getChildById('nodeLock'):isVisible(),'major failed to unlock at four correct minor points')
 assert(mod.getWindow():recursiveGetChildById('addRank'):isEnabled(),'unlocked major Add button disabled selected='..tostring(state().selected)..' status='..mod.getWindow():recursiveGetChildById('addRank'):getTooltip()..' draft='..json.encode(state().draft)..' active='..tostring(state().active)..' pending='..tostring(state().pending))
 mod.discard()
 assert(pane.points==0 and sum(state().draft)==0 and guardNode.locked,'Undo draft failed to restore locks/progress')
 print('PASSIVES_BRANCH_UI_PROGRESS_OK '..tree..' 0/4 ->3/4 locked ->4/4 unlocked ->Undo0/4')
 local wrong={[sustain.minorIds[1]]=5,[guard.majorId]=1}
 assert(mod.validateDraft(wrong),'points from Sustain must not unlock Guard')
 assert(mod.selectNode(guard.majorId))
 assert(not mod.changeRank(1,guard.majorId),'locked Guard major was clickable')
 rejectRanks(tree..'-wrong-area',wrong,function()
  local low={[guard.minorIds[1]]=3,[guard.majorId]=1}
  rejectRanks(tree..'-below-threshold',low,function()
   for _,group in ipairs(groups)do
    for _,id in ipairs(group.minorIds)do for _=1,build[id]do assert(mod.changeRank(1,id))end end
    assert(mod.changeRank(1,group.majorId),'legal branch major could not be drafted')
   end
   local before=copy(state().draft)
   assert(not mod.changeRank(-1,guard.minorIds[2]),'removing a needed prerequisite was accepted')
   assert(same(before,state().draft),'rejected prerequisite removal corrupted draft')
   local revision=state().revision
   assert(mod.apply(),'complete legal branch draft rejected')
   wait(tree..' branch draft apply',function()return state().revision>revision and not state().pending end,function()
    assert(same(build,state().ranks),'authoritative branch allocation differs from draft')
    local broken=copy(build);broken[guard.minorIds[2]]=0
    rejectRanks(tree..'-dependent-removal',broken,function()
     g_app.doScreenshot('/passives-live-branches-'..tree..'.png')
     print('PASSIVES_BRANCH_GATES_OK '..tree..' legal3+1; wrong-area/below-threshold/dependent-removal rejected')
     local rev=state().revision
     g_game.talk('/passivetest reset')
     wait(tree..' branch reset',function()return state().revision>rev and sum(state().ranks)==0 end,nextStep)
    end)
   end)
  end)
 end)
 end)
end
local function finish()
 g_game.talk('/passivetest stop')
 wait('end test cleanup',function()return not state().active end,function()
  assert(g_game.getLocalPlayer():getMaxHealth()==735,'derived max HP not restored')
  finishing=true;g_game.safeLogout()
  wait('logout cleanup',function()return not g_game.isOnline()end,function()
   assert(not state().tree and not mod.getWindow(),'logout retained tree UI')
   done=true;print('PASSIVES_ALL_TREES_CONTRACT_OK');scheduleEvent(function()g_app.exit()end,400)
  end)
 end)
end
local runTree
local function presets(tree,index,nextStep)
 if index>3 then nextStep();return end
 local cap=caps[tree][index]
 local revision=state().revision
 g_game.talk('/passivetest preset Passive Tester, '..cap)
 wait(tree..' preset '..cap,function()return state().revision>revision and state().ranks['cap_'..cap]==1 end,function()
  assert(sum(state().ranks)==16,'preset did not spend16 first-capstone points')
  local count=0;for _,id in ipairs(caps[tree])do count=count+(state().ranks['cap_'..id]or 0)end
  assert(count==1,'preset retained another capstone')
  assert(not mod.validateDraft(state().ranks),'server preset rejected by UI prerequisite validator')
  assert(mod.selectNode('cap_'..cap))
  print('PASSIVES_ALL_PRESET_OK '..tree..' '..cap)
  if index==2 then
   g_app.doScreenshot('/passives-live-'..tree..'.png')
  end
  later(200,function()presets(tree,index+1,nextStep)end)
 end)
end
runTree=function(index)
 if index>#ids then finish();return end
 local id=ids[index]
 command('/passiveqa quiesce Passive Tester',function()
  command('/passiveqa equip '..id,function()
   local oldSession=state().session
   g_game.talk('/passivetest start '..id..', Passive Tester')
   wait('fresh catalog '..id,function()return state().active and state().tree and state().tree.id==id and state().session~=oldSession end,function()
    assert(sum(state().ranks)==0 and state().points==24,'new tree inherited ranks/budget')
    assert(#state().tree.nodes==29,'catalog node count')
    for _,node in ipairs(state().tree.nodes)do
     local widget=assert(mod.getNodeWidget(node.id),'missing widget '..node.id)
     assert(widget:getChildById('glyph'):getWidth()==32,'nonnative glyph')
    end
    wait('matching weapon active '..id,function()return state().runtime.weaponActive==true end,function()
     print('PASSIVES_ALL_CATALOG_OK '..id..' session='..state().session)
     prerequisites(id,function()presets(id,1,function()
      local p=g_game.getLocalPlayer()
      local presetRanks=state().ranks
      local expectedMax=735+math.floor(735*((presetRanks.minor_vitality or 0)+2*(presetRanks.major_guard or 0)+.5*(presetRanks.mid_stout_heart or 0))/100)
      assert(p:getMaxHealth()==expectedMax,'matching weapon derived health does not match the exact preset ranks')
      local wrong=id=='reaver'and'blademaster'or'reaver'
      command('/passiveqa equip '..wrong,function()
       wait('wrong weapon inactive '..id,function()return state().runtime.weaponActive==false end,function()
        assert(p:getMaxHealth()==735,'wrong weapon retained derived health')
        local hp=p:getHealth()
        command('/passiveqa equip '..id,function()
         wait('matching weapon restored '..id,function()return state().runtime.weaponActive==true and p:getMaxHealth()==expectedMax end,function()
          assert(p:getHealth()==hp,'weapon swap healed the fixture')
          print('PASSIVES_WEAPON_GATE_OK '..id)
          local rev=state().revision
          g_game.talk('/passivetest reset')
          wait('reset '..id,function()return state().revision>rev and sum(state().ranks)==0 end,function()
           assert(p:getMaxHealth()==735,'reset retained derived health')
           runTree(index+1)
          end)
         end)
        end)
       end)
      end)
     end)end)
    end)
   end)
  end)
 end)
end
local function online()
 EnterGame.hide()
 connect(g_game,{onTextMessage=function(_,text)print('PASSIVES_ALL_MESSAGE '..text) end})
 wait('handshake',function()return state().ready end,function()
  command('/passiveqa learn',function()runTree(1)end)
 end)
end
later(200,function()
 assert(LOCAL_PASSIVES_TEST and Services.updater=='' and g_resources.getLayout()=='retro')
 mod=assert(modules.game_passives)
 ProtocolGame.registerExtendedJSONOpcode(103,function(_,_,data)
  if data.action=='result'and data.requestId then replies[data.requestId]=data end
 end)
 g_settings.set('window-maximized',false);g_window.resize({width=1280,height=800})
 mod.setStatusVisible(true)
 connect(g_game,{onGameStart=function()later(250,online)end,onConnectionError=function(err)if not finishing then fail(err)end end})
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 G.account='passivetest';G.password='passivetest'
 login=ProtocolLogin.create();_G.allTreeContractLogin=login
 login.onLoginError=function(_,err)fail(err)end
 login.onCharacterList=function(_,chars)
  for _,c in ipairs(chars)do if c.name=='Passive Tester'then g_game.loginWorld(G.account,G.password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return end end
  fail('fixture character missing')
 end
 login:login('127.0.0.1',7174,G.account,G.password,'',false)
end)
scheduleEvent(function()if not done then fail('all-tree contract timeout')end end,110000)
