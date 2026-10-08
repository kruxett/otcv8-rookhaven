-- Actual local administrator overlays. No ordinary character or live-server writes.
local classes={'reaver','blademaster','earthshaker','marksman','arcanist','lifekeeper'}
local mod,login,failed,done,intentional=false
local packets,wire,chunkedReports={},nil,0
local cases,effects=0,0
local function fail(reason)
 if failed or done then return end;failed=true
 print('CYCLOPEDIA_ALLOCATED_FAILED '..tostring(reason))
 if g_game.isOnline()then intentional=true;g_game.talk('/passivetest stop');g_game.safeLogout()end
 scheduleEvent(function()g_app.exit()end,700)
end
local function later(ms,fn)scheduleEvent(function()if failed or done then return end;local ok,e=pcall(fn);if not ok then fail(e)end end,ms)end
local function wait(label,predicate,fn)
 local deadline=g_clock.millis()+12000
 local function poll()if predicate()then fn();return end;assert(g_clock.millis()<deadline,label..' timeout');later(60,poll)end
 later(60,poll)
end
local function state()return mod.getState()end
local function sum(ranks)local n=0;for _,rank in pairs(ranks)do n=n+rank end;return n end
local function text(widget)
 local value=widget.getText and widget:getText()or''
 for _,child in ipairs(widget:getChildren())do value=value..'\n'..text(child)end;return value
end
local function selectPage(panel,id)
 local general=panel.OptionsBase:getChildByIndex(1)
 if not general.opened then signalcall(general.Button.onClick,general.Button)end
 for _,row in ipairs(general:getChildren())do if row.open==id then signalcall(row.Button.onClick,row.Button);assert(panel[id]:isVisible());return end end
 error('Category missing '..id)
end
local function request(fn)
 packets['character.passives']=nil
 g_game.getProtocolGame():sendExtendedOpcode(31,'cp|1|req|character.combatStats|')
 wait('fresh authoritative stats',function()return packets['character.passives']~=nil end,function()fn(json.decode(packets['character.passives']))end)
end
local function assertVisible(row,list,overview)
 local r,v=row:getRect(),list:getPaddingRect()
 assert(r.y>=v.y-1 and r.y+r.height<=v.y+v.height+1,'Selected row outside scroll viewport '..row:getId())
 if not overview then assert(row:isOn(),'Selected row lacks selection highlight')end
end
local function sourceWindow(panel,view)
 return view=='overview'and modules.game_cyclopedia.Cyclopedia.getCombatSourceWindow()or panel.SourceDetails
end
local function sourceRow(panel,view,entry)
 if view=='overview'then return modules.game_cyclopedia.Cyclopedia.getCombatStatRow(entry.id)end
 return panel.List:getChildById('talent_'..entry.id)
end
local function clickEntries(panel,view,entries,index,fn)
 local entry=entries[index];if not entry then fn();return end
 local row=sourceRow(panel,view,entry)
 if view=='overview'and(entry.id=='maxHealth'or not row)then
  assert(entry.id=='maxHealth'or tonumber(entry.value)==0,'Nonzero actual row absent '..entry.id)
  clickEntries(panel,view,entries,index+1,fn);return
 end
 assert(row,'Actual row absent '..entry.id)
 signalcall(row.onClick,row)
 later(90,function()
  assertVisible(row,view=='overview'and panel or panel.List,view=='overview')
  local detail=sourceWindow(panel,view)
  assert(detail:isVisible()and detail.Content.Title:getText()==entry.label,'Source title did not follow actual row click')
  if view=='talents'then
   assert(detail.Content.Rank.Value:getText()==tostring(entry.rank),'Applied rank detail differs')
   effects=effects+1
  end
  clickEntries(panel,view,entries,index+1,fn)
 end)
end
local function stableRefresh(panel,view,entry,fn)
 local row=assert(sourceRow(panel,view,entry))
 local list=view=='overview'and panel or panel.List
 local detail=sourceWindow(panel,view)
 signalcall(row.onClick,row)
 later(110,function()
  assertVisible(row,list,view=='overview')
  local title,offset=detail.Content.Title:getText(),list:getVirtualOffset().y
  request(function()
   later(110,function()
    assert(detail.Content.Title:getText()==title,'Real refresh reset source selection')
    assert(list:getVirtualOffset().y==offset,'Real refresh reset scroll position')
    assertVisible(assert(sourceRow(panel,view,entry)),list,view=='overview');fn()
   end)
  end)
 end)
end
local function checkReport(report,id)
 local stats,p=report.stats,report.presentation
 assert(stats.classId==id and stats.active and stats.weaponActive and not stats.permanent,'Wrong overlay activation/class')
 assert(p.version==1 and p.header.className==stats.className and p.header.weaponActive,'Header lost actual class weapon')
 assert(stats.spent==sum(state().ranks)and stats.spent>=16,'Native allocation differs from selected overlay')
 assert(p.header.spent==stats.spent and p.header.points==24,'Point budget mismatch')
 for index,node in ipairs(state().tree.nodes)do assert((stats.ranks[index]or 0)==(state().ranks[node.id]or 0),'Native rank mismatch '..node.id)end
 local expectedHP=stats.baseMaxHealth+stats.appliedMaxHealthBonus+stats.otherMaxHealthBonus
 assert(expectedHP==stats.maxHealth and g_game.getLocalPlayer():getMaxHealth()==expectedHP,'Actual HP source composition failed')
 assert(stats.rankMaxHealthBonus==math.floor(stats.baseMaxHealth*stats.rankMaxHealthPercent/100),'Learned HP baseline rounding differs')
 assert(math.abs(stats.currentManaPerSecond-(stats.currentEffectManaPerSecond+(stats.manaPerSecond or 0)))<.000001,'Focus and ordinary regeneration composition failed')
 local extra=stats.passiveCriticalChance or 0
 assert(math.abs(stats.criticalChance-(stats.legacyCriticalChance+(100-stats.legacyCriticalChance)*extra/100))<.000001,'Critical rolls were added instead of sequenced')
 local chosen,entries={},{}
 for _,talent in ipairs(report.talents)do chosen[talent.name]=talent.rank end
 for _,group in ipairs({'statBonuses','conditionalEffects','specialEffects'})do for _,entry in ipairs(p.talents[group])do
  assert(chosen[entry.label]==entry.rank and entry.rank>0,'B displayed unchosen rank')
  assert(entry.status~='Inactive','Compatible weapon marked whole allocated effect inactive')
  entries[#entries+1]=entry
 end end
 assert(#entries>=6 and #p.talents.specialEffects>=1,'Allocated class lacks real selected effects/capstone')
 local model=modules.game_cyclopedia.Cyclopedia.getPresentationModel()
 assert(model.header.className==p.header.className and model.header.spent==stats.spent,'Actual transport parser lost presentation')
 return p,entries
end
local run
local function inspectSize(id,report,p,entries,size,index,nextStep)
 local module=modules.game_cyclopedia
 g_window.resize(size)
 later(260,function()
  local root=g_ui.getRootWidget():getRect();assert(root.width==size.width and root.height==size.height,'Stress viewport was not applied')
  local window=module.controllerCyclopedia.ui:getRect()
  assert(window.x>=0 and window.y>=0 and window.x+window.width<=root.width and window.y+window.height<=root.height,'Cyclopedia outside viewport')
  local panel=assert(module.contentContainer:getChildById('Cat6'))
  selectPage(panel,'CombatStats')
  later(220,function()
   local a=panel.CombatStats.Viewport;assert(a:isVisible()and a:getHeight()>300,'Original view collapsed')
   assert(a.Content.estDps:getHeight()==20,'Retro row height changed')
   clickEntries(a,'overview',p.overview,1,function()
    local selected;for _,entry in ipairs(p.overview)do if entry.id=='manaRegen'and modules.game_cyclopedia.Cyclopedia.getCombatStatRow(entry.id)then selected=entry end end
    if not selected then for _,entry in ipairs(p.overview)do if entry.id=='normalMaxHit'then selected=entry end end end
    stableRefresh(a,'overview',assert(selected),function()
     signalcall(panel.CombatSources.Close.onClick,panel.CombatSources.Close)
     a:setVirtualOffset({x=0,y=0})
     later(120,function()
     g_app.doScreenshot('/cyclopedia-allocated-'..id..'-stats-'..size.width..'x'..size.height..'.png')
     later(120,function()
     selectPage(panel,'PassiveStats')
     later(220,function()
      local b=panel.PassiveStats;assert(b.List:getHeight()>60,'B view collapsed')
      clickEntries(b,'talents',entries,1,function()
       local cap;for _,entry in ipairs(entries)do if entry.id:find('cap_',1,true)==1 then cap=entry end end
       stableRefresh(b,'talents',assert(cap,'Chosen capstone row missing'),function()
        g_app.doScreenshot('/cyclopedia-allocated-'..id..'-talents-'..size.width..'x'..size.height..'.png')
        print('CYCLOPEDIA_ALLOCATED_UI_OK class='..id..' size='..size.width..'x'..size.height..' applied='..report.stats.spent..' effects='..#entries..' rows='..#p.overview..' reportBytes='..#packets['character.passives']..' sourceClick=true selectedVisible=true refreshScrollStable=true')
        cases=cases+1;nextStep()
       end)
      end)
     end)
     end)
     end)
    end)
   end)
  end)
 end)
end
local function finish()
 g_game.talk('/passivetest stop')
 wait('overlay stopped',function()return not state().active end,function()
  assert(g_game.getLocalPlayer():getMaxHealth()==735,'Overlay HP leaked after stop')
  intentional=true;g_game.safeLogout()
  wait('safe logout',function()return not g_game.isOnline()end,function()
   assert(not state().tree,'Logout retained overlay catalog')
   assert(cases==12 and chunkedReports>=12,'Missing allocated size/chunk evidence')
   done=true;print('CYCLOPEDIA_ALLOCATED_COMPLETE classes=6 sizes=2 cases='..cases..' effectsClicked='..effects..' chunkedReports='..chunkedReports..' overlayStopped=true logout=true')
   scheduleEvent(function()g_app.exit()end,250)
  end)
 end)
end
run=function(index)
 local id=classes[index];if not id then finish();return end
 modules.game_cyclopedia.hide();mod.hide()
 g_game.talk('/passiveqa quiesce Passive Tester')
 later(260,function()
  g_game.talk('/passiveqa equip '..id)
  later(260,function()
   local session=state().session;g_game.talk('/passivetest start '..id..', Passive Tester')
   wait('fresh '..id..' overlay',function()return state().tree and state().tree.id==id and state().session~=session end,function()
    local revision,cap=state().revision,state().tree.topology.capstoneOrder[1]
    g_game.talk('/passivetest preset Passive Tester, '..cap:gsub('^cap_',''))
    wait('actual preset '..id,function()return state().revision>revision and state().ranks[cap]==1 end,function()
     mod.hide();modules.game_cyclopedia.show('character')
     later(240,function()request(function(report)
      local p,entries=checkReport(report,id)
      inspectSize(id,report,p,entries,{width=1280,height=800},1,function()
       inspectSize(id,report,p,entries,{width=800,height=600},2,function()run(index+1)end)
      end)
     end)end)
    end)
   end)
  end)
 end)
end
later(200,function()
 assert(LOCAL_PASSIVES_TEST and Services.updater==''and not g_game.isOnline(),'Owned offline-start local profile required')
 mod=assert(modules.game_passives);g_settings.set('window-maximized',false);g_window.setMinimumSize({width=800,height=600})
 print('CYCLOPEDIA_ALLOCATED_SCREENSHOT_DIRECTORY '..g_resources.getWriteDir())
 connect(ProtocolGame,{onExtendedOpcode=function(_,opcode,buffer)
  if opcode~=31 then return end;assert(#buffer<=8192,'Native frame exceeded addString limit')
  local id,index,total,part=buffer:match('^cp|1|chunk|(%d+)|(%d+)|(%d+)|(.*)$')
  if id then
   index,total=tonumber(index),tonumber(total);assert(#part<=7900 and total<=8 and total>=2,'Invalid actual chunk bounds')
   if index==1 then wire={id=id,total=total,next=1,bytes=0,parts={}}end
   assert(wire and wire.id==id and wire.total==total and wire.next==index,'Wire chunks out of order')
   wire.parts[index]=part;wire.bytes=wire.bytes+#part;wire.next=index+1;assert(wire.bytes<=32768,'Actual report exceeded limit')
   if index<total then return end;buffer=table.concat(wire.parts);wire=nil;chunkedReports=chunkedReports+1
  end
  local action,status,data=buffer:match('^cp|1|res|([^|]+)|([^|]+)|?(.*)$')
  if action and status=='ok'then packets[action]=data end
 end})
 connect(g_game,{onConnectionError=function(reason)if not intentional then fail(reason)end end})
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 G.account,G.password='passivetest','passivetest';login=ProtocolLogin.create();_G.cyclopediaAllocatedLogin=login
 login.onLoginError=function(_,reason)fail(reason)end
 login.onCharacterList=function(_,list)for _,c in ipairs(list)do if c.name=='Passive Tester'then g_game.loginWorld(G.account,G.password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return end end;fail('Disposable tester missing')end
 login:login('127.0.0.1',7174,G.account,G.password,'',false)
 wait('native local login',function()return g_game.isOnline()and state().ready end,function()EnterGame.hide();run(1)end)
end)
scheduleEvent(function()if not done then fail('Allocated UI deadline')end end,180000)
