-- Offline native presentation regression using current source and real widgets.
-- Catalog packets use a scripted transport; no login, Apply or Respec is sent.
assert(LOCAL_PASSIVES_TEST and Services.updater == '' and g_resources.getLayout() == 'retro')
assert(not g_game.isOnline() and not g_game.isLogging(), 'Presentation gate must start offline')

local realUI, realGame = g_ui, g_game
local mod, trees, protocol
local failed, finished = false, false
local cases, caseIndex, requests = {}, 0, 0
local source = g_resources.readFileContents('/passives-presentation-source.txt')
local layout = g_resources.readFileContents('/passives-presentation-layout.txt')

local function fail(reason)
  if failed or finished then return end
  failed = true
  print('PASSIVES_PRESENTATION_FAILED ' .. tostring(reason))
  if mod then pcall(mod.terminate) end
  scheduleEvent(function() g_app.exit() end, 150)
end

local function later(ms, fn)
  scheduleEvent(function()
    if failed or finished then return end
    local ok, reason = pcall(fn)
    if not ok then fail(reason) end
  end, ms)
end

local function normalGuard()
  local touched = {}
  local function forbidden(name)
    return function() touched[#touched + 1] = name;error('Normal profile touched ' .. name) end
  end
  local env = {
    LOCAL_PASSIVES_TEST = false,
    ProtocolGame = {registerExtendedOpcode=forbidden('opcode register'),unregisterExtendedOpcode=forbidden('opcode unregister')},
    connect=forbidden('connect'),disconnect=forbidden('disconnect'),scheduleEvent=forbidden('scheduleEvent'),
    addEvent=forbidden('addEvent'),removeEvent=forbidden('removeEvent'),
    g_ui={getRootWidget=forbidden('UI root'),displayUI=forbidden('displayUI'),loadUI=forbidden('loadUI'),createWidget=forbidden('createWidget')},
    g_resources={getLayout=forbidden('layout')},
    g_game={isOnline=forbidden('isOnline'),getProtocolGame=forbidden('protocol')},
    g_keyboard={bindKeyDown=forbidden('bindKeyDown'),bindKeyPress=forbidden('bindKeyPress')},
    g_settings={set=forbidden('settings write')}
  }
  env._G=env;setmetatable(env,{__index=_G})
  local chunk=assert(loadstring(source,'@/passives-presentation-source.txt'))
  setfenv(chunk,env);chunk();env.init();env.terminate()
  assert(#touched==0 and env.getWindow()==nil and env.getStatusWindow()==nil,'Normal profile created passive UI')
  local state=env.getState()
  assert(not state.active and not state.ready and not state.tree,'Normal profile retained passive session')
  print('PASSIVES_PRESENTATION_NORMAL_GUARD_OK freshSource=true effects=0')
end

local function freshModule()
  mod=assert(modules.game_passives);mod.terminate()
  protocol={sendExtendedOpcode=function()
    requests=requests+1;error('Unexpected outgoing passive request in offline presentation gate')
  end}
  -- Scoped proxies leave the actual game offline and preserve other modules.
  mod.g_game=setmetatable({isOnline=function()return true end,getProtocolGame=function()return protocol end},{__index=realGame})
  mod.g_ui=setmetatable({displayUI=function(name,parent)
    if name=='passives' then return realUI.loadUIFromString(layout,parent or realUI.getRootWidget()) end
    return realUI.displayUI(name,parent)
  end},{__index=realUI})
  local chunk=assert(loadstring(source,'@/modules/game_passives/passives.lua'))
  setfenv(chunk,mod);chunk();mod.init();mod.getState().ready=true
end

local function packet(data)
  data.v=1;ProtocolGame.onExtendedOpcode(protocol,103,json.encode(data))
end

local function catalog(tree, token)
  local encoded=json.encode({v=1,action='catalog',session=token,tree=tree})
  local count=math.ceil(#encoded/3500)
  for index=1,count do
    packet({action='catalog_part',session=token,transfer=token,total=count,index=index,data=encoded:sub((index-1)*3500+1,index*3500)})
  end
  assert(mod.getState().session==token and mod.getState().tree.id==tree.id,'Catalog was rejected: '..tree.id)
end

local function snapshot(revision, ranks, points, cost)
  packet({action='snapshot',session=mod.getState().session,revision=revision,ranks=ranks or {},points=points or 24,
    active=true,mode='permanent',respecCost=cost or 0,respecCount=cost and cost>0 and 1 or 0,classLocked=true})
  assert(mod.getState().mode=='permanent' and mod.getState().active,'Permanent snapshot was rejected')
end

local function control(id)
  return assert(mod.getWindow():recursiveGetChildById(id),'Missing control '..id)
end

local function noDevelopmentCopy(widget, context)
  if not widget:isVisible() then return end
  local text=widget:getText() or ''
  local tip=widget:getTooltip() or ''
  local combined=(text..'\n'..tip):upper()
  assert(not combined:find('%f[%a]TEST%f[%A]') and not combined:find('DESIGN PREVIEW',1,true)
    and not combined:find('VISUAL PREVIEW',1,true) and not combined:find('NATIVE RETRO UI PREVIEW',1,true)
    and not combined:find('RESET (FREE)',1,true),context..': development copy visible on '..widget:getId()..': '..text)
  assert(not combined:find('SESSION:',1,true) and not combined:find('REVISION:',1,true),context..': protocol header visible')
  for _,child in ipairs(widget:getChildren())do noDevelopmentCopy(child,context)end
end

local function presentation(tree, context)
  local window=assert(mod.getWindow());assert(window:isVisible(),context..': window hidden')
  local root=realUI.getRootWidget():getRect();local rect=window:getRect()
  assert(rect.x>=root.x and rect.y>=root.y and rect.x+rect.width<=root.x+root.width and rect.y+rect.height<=root.y+root.height,context..': window outside root')
  noDevelopmentCopy(window,context)
  local canvas=control('canvas')
  for _,id in ipairs({'typeLegendMinor','typeLegendMajor','typeLegendCapstone','capstoneHint'})do
    assert(not canvas:recursiveGetChildById(id),context..': canvas legend retained '..id)
  end
  for _,child in ipairs(canvas:getChildren())do
    assert(child:getStyleName()~='PassiveLegendFrame',context..': anonymous legend sample retained')
  end
  assert(#tree.nodes==17 and #mod.getEdgeWidgets()==21,context..': original graph changed')
  for _,node in ipairs(tree.nodes)do
    assert(mod.selectNode(node.id))
    assert(control('nodeName'):getText()==node.name,context..': selected name incorrect')
    local rank=mod.getState().draft[node.id] or 0
    local tier=node.type=='capstone' and 'Capstone' or node.type=='major' and 'Major' or 'Minor'
    local header=control('nodeRank'):getText()
    assert(header:find(tier,1,true) and header:find(rank..'/'..node.maxRank,1,true),context..': selected type/rank missing '..node.id)
    assert(mod.getNodeWidget(node.id):getChildById('rank'):getText()==rank..'/'..node.maxRank,context..': canvas rank missing')
  end
  mod.selectNode('minor_precision')
  for _,id in ipairs({'addRank','removeRank','applyButton','discardButton','resetButton','closeButton'})do
    assert(control(id):isVisible(),context..': legitimate permanent control hidden '..id)
  end
  assert(not control('endButton'):isVisible(),context..': End test exposed')
  local horizontal=control('treeHorizontal')
  control('treeScroll'):updateScrollBars()
  assert(horizontal:getMaximum()==horizontal:getMinimum(),context..': unexpected horizontal overflow')
  assert(not horizontal:isVisible(),context..': empty horizontal scrollbar visible')
  assert(control('pointsLabel'):getText():find('24',1,true),context..': point budget missing')
end

local function editing(context)
  mod.selectNode('minor_precision')
  assert(control('addRank'):isEnabled() and not control('removeRank'):isEnabled(),'Empty permanent rank controls incorrect')
  assert(not control('applyButton'):isEnabled() and not control('discardButton'):isEnabled(),'Clean build has draft actions')
  signalcall(control('addRank').onClick,control('addRank'))
  assert(mod.getState().draft.minor_precision==1 and not next(mod.getState().ranks),'Add rank changed saved state')
  assert(control('applyButton'):isEnabled() and control('discardButton'):isEnabled() and control('removeRank'):isEnabled(),'Draft editing controls disabled')
  assert(control('nodeRank'):getText():find('1/5',1,true),'Draft selected rank missing')
  signalcall(control('removeRank').onClick,control('removeRank'))
  assert((mod.getState().draft.minor_precision or 0)==0 and not control('applyButton'):isEnabled(),'Undo rank did not restore clean build')
  snapshot(2,{minor_precision=1},24,0);mod.selectNode('minor_precision')
  assert(control('resetButton'):isEnabled() and control('resetButton'):getText():find('Respec',1,true),'Saved ranks lost Respec')
  assert(not control('removeRank'):isEnabled(),'Saved rank may be undone without Respec')
  signalcall(control('addRank').onClick,control('addRank'))
  assert(mod.getState().draft.minor_precision==2 and mod.getState().ranks.minor_precision==1,'Draft increase changed saved rank')
  assert(control('removeRank'):isEnabled() and control('applyButton'):isEnabled(),'New rank cannot be undone/applied')
  signalcall(control('removeRank').onClick,control('removeRank'))
  snapshot(3,{minor_precision=1},24,200)
  assert(control('resetButton'):getText():find('200',1,true),'Paid Respec price missing')
  snapshot(4,{minor_precision=1},1,200)
  assert(not control('addRank'):isEnabled(),'Zero available points still allows another rank')
  snapshot(5,{minor_precision=1},24,200)
  noDevelopmentCopy(mod.getWindow(),context..' editing')
  print('PASSIVES_PRESENTATION_EDITING_OK '..context..' outgoingRequests='..requests)
end

local function finish()
  assert(requests==0 and not realGame.isOnline() and not realGame.isLogging(),'Offline gate performed a network action')
  mod.terminate();finished=true
  print('PASSIVES_PRESENTATION_OK classes=6 viewports=2 permanent=true outgoingRequests=0 actualGameOnline=false resize=true hudCleanup=true')
  g_app.exit()
end

local function resizeRegression()
  freshModule();g_window.setMinimumSize({width=560,height=600});g_window.resize({width=1280,height=800})
  catalog(assert(trees.reaver),'presentation-resize');snapshot(1,{},24,0);assert(mod.show())
  local function verifyRange(expected,context)
    local horizontal=control('treeHorizontal')
    local overflow=horizontal:getMaximum()>horizontal:getMinimum()
    assert(overflow==expected,context..': scrollbar range disagrees with expected overflow')
    assert(horizontal:isExplicitlyVisible()==overflow,context..': horizontal visibility did not follow resize')
    print('PASSIVES_PRESENTATION_RESIZE_OK '..context..' overflow='..tostring(overflow))
  end
  later(180,function()
    verifyRange(false,'wide before resize');g_window.resize({width=640,height=600})
    later(180,function()
      assert(realUI.getRootWidget():getWidth()==640,'Narrow viewport did not settle')
      verifyRange(true,'narrow without reselection');g_window.resize({width=1280,height=800})
      later(180,function()verifyRange(false,'wide again without reselection');finish()end)
    end)
  end)
end

local runCase
runCase=function()
  caseIndex=caseIndex+1
  if caseIndex>#cases then
    resizeRegression();return
  end
  local item=cases[caseIndex];local tree=assert(trees[item.id]);local context=item.id..' '..item.width..'x'..item.height
  freshModule();g_window.resize({width=item.width,height=item.height})
  catalog(tree,'presentation-'..caseIndex);snapshot(1,{},24,0);assert(mod.show())
  later(180,function()
    local root=realUI.getRootWidget()
    assert(root:getWidth()==item.width and root:getHeight()==item.height,context..': actual viewport did not settle')
    presentation(tree,context);editing(context)
    mod.setStatusVisible(true)
    local hud=assert(mod.getStatusWindow(),context..': combat HUD was not constructed')
    assert(hud:isExplicitlyVisible(),context..': combat HUD did not open before refresh')
    catalog(tree,'presentation-refresh-'..caseIndex)
    later(100,function()
      local window=assert(mod.getWindow())
      if window:isVisible()then
        noDevelopmentCopy(window,context..' awaiting snapshot')
        for _,id in ipairs({'addRank','removeRank','applyButton','discardButton','resetButton','endButton'})do
          assert(not control(id):isVisible() or not control(id):isEnabled(),context..': editing action active while loading '..id)
        end
        assert(not control('endButton'):isVisible(),context..': test action visible while loading')
      end
      assert(not mod.getStatusWindow() or not mod.getStatusWindow():isExplicitlyVisible(),context..': combat HUD retained old session')
      print('PASSIVES_PRESENTATION_LOADING_OK '..context..' windowVisible='..tostring(window:isVisible())..' oldHUDHidden=true')
      mod.setStatusVisible(false)
      snapshot(1,{minor_precision=1},24,200)
      assert(mod.getWindow():isVisible(),context..': visible permanent window did not reopen after snapshot')
      later(100,function()
        presentation(tree,context..' restored')
        print('PASSIVES_PRESENTATION_CASE_OK '..context)
        if item.id=='reaver' then
          mod.selectNode('cap_berserker')
          later(100,function()g_app.doScreenshot('/passives-presentation-reaver-'..item.width..'x'..item.height..'.png');runCase()end)
        else runCase()end
      end)
    end)
  end)
end

later(1000,function()
  normalGuard()
  print('PASSIVES_PRESENTATION_SCREENSHOT_DIRECTORY '..g_resources.getWriteDir())
  trees=json.decode(g_resources.readFileContents('/passives-presentation-trees.txt'))
  for _,id in ipairs({'reaver','blademaster','earthshaker','marksman','arcanist','lifekeeper'})do
    cases[#cases+1]={id=id,width=1280,height=800};cases[#cases+1]={id=id,width=800,height=600}
  end
  g_settings.set('passivesTestShowStatus',false);g_settings.set('window-maximized',false)
  g_window.setMinimumSize({width=800,height=600})
  runCase()
end)
scheduleEvent(function()if not finished then fail('Presentation gate exceeded 40 seconds')end end,40000)
