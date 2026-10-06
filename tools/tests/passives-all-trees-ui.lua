-- Offline native rendering gate; no server connection and no combat claims.
-- Inject this script and /passives-preview-tree.txt into a disposable local
-- probe package. It exercises the real module and both desktop window sizes.
assert(LOCAL_PASSIVES_TEST and Services.updater == '')
assert(g_resources.getLayout() == 'retro')
assert(not g_game.isOnline(), 'This preview must not use a live character.')

local failed = false
local passives

local function guarded(fn)
  if failed then return end
  local ok, reason = pcall(fn)
  if not ok then
    failed = true
    print('PASSIVES_PREVIEW_FAILED ' .. tostring(reason))
    scheduleEvent(function()
      g_app.doScreenshot('/passives-preview-failed.png')
      scheduleEvent(function()g_app.exit()end,200)
    end,250)
  end
end

local function later(delay, fn)
  scheduleEvent(function() guarded(fn) end, delay)
end

local function inside(inner, outer, label)
  local tolerance = 1
  assert(inner.width > 0 and inner.height > 0, label .. ': empty rectangle')
  assert(inner.x >= outer.x - tolerance and inner.y >= outer.y - tolerance and
    inner.x + inner.width <= outer.x + outer.width + tolerance and
    inner.y + inner.height <= outer.y + outer.height + tolerance,
    string.format('%s outside its parent: (%d,%d %dx%d), parent (%d,%d %dx%d)',
      label, inner.x, inner.y, inner.width, inner.height,
      outer.x, outer.y, outer.width, outer.height))
end

local function verify(label)
  local root = g_ui.getRootWidget()
  local window = assert(passives.getWindow(), 'tree window missing')
  assert(window:isVisible(), 'tree window is hidden')
  inside(window:getRect(), root:getRect(), label .. ': tree window')

  local state = passives.getDebugState()
  assert(#state.tree.nodes == 17, 'catalog must contain 17 nodes')
  local canvas = assert(window:recursiveGetChildById('canvas'))
  local selected=state.selected
  local rectangles = {}
  for _, node in ipairs(state.tree.nodes) do
    local widget = assert(passives.getNodeWidget(node.id), 'missing node ' .. node.id)
    local width = node.type == 'major' and 104 or node.type == 'capstone' and 64 or 44
    local height = node.type == 'major' and 52 or node.type == 'capstone' and 64 or 44
    assert(widget:getWidth() == width and widget:getHeight() == height, 'wrong tier frame size: ' .. node.id)
    inside(widget:getRect(), canvas:getRect(), label .. ': ' .. node.id)
    rectangles[#rectangles + 1] = widget:getRect()
    local glyph = assert(widget:getChildById('glyph'), 'node glyph missing: ' .. node.id)
    assert(glyph:getWidth() == 32 and glyph:getHeight() == 32, 'glyph is not native 32px: ' .. node.id)
    inside(glyph:getRect(), widget:getRect(), label .. ': glyph ' .. node.id)
    local rank=assert(widget:getChildById('rank'))
    inside(rank:getRect(),widget:getRect(),label..': rank footer')
    assert(glyph:getY()+glyph:getHeight()<=rank:getY(),'glyph overlaps rank footer')
    assert((widget:getChildById('majorInset')~=nil)==(node.type=='capstone'),'ornate capstone frame missing')
    local nameLabel=assert(canvas:getChildById('nodeCaption_'..node.id),'talent caption missing')
    assert(nameLabel:getTextAlign()==AlignCenter,'talent lettering is not actually centered: '..node.name)
    assert(nameLabel:getTextSize().width<=nameLabel:getWidth()-2,'talent name clipped: '..node.name)
    assert(nameLabel:getTextSize().height<=nameLabel:getHeight()-2,'talent name clipped vertically: '..node.name)
    assert(nameLabel:getHeight()==30,'unequal talent name bands')
    assert(nameLabel:getText()==(node.shortName or node.name):gsub(' ','\n'),'talent name omitted or broken inconsistently')
    assert(nameLabel:getY()==widget:getY()+widget:getHeight(),'nameplate detached from talent frame')
    assert(math.abs(nameLabel:getX()+nameLabel:getWidth()/2-widget:getX()-widget:getWidth()/2)<=1,'caption not centered')
    signalcall(nameLabel.onClick,nameLabel)
    assert(state.selected==node.id,'clicking a talent name selects the wrong talent')
    assert(not widget:getChildById('marker'),'unexplained M/C/x marker retained')
    if node.type == 'capstone' then
      assert(not widget:getChildById('capstoneTier'),'capstone text retained on top of icon')
      local link = assert(canvas:getChildById('capstoneLink_' .. node.id), 'capstone connection missing: ' .. node.id)
      assert(link:isVisible(),'capstone connection is hidden')
    end
  end
  local captions={}
  for _,child in ipairs(canvas:getChildren())do
    if child:getId():find('^nodeCaption_')then
      inside(child:getRect(),canvas:getRect(),label..': talent caption')
      local rect=child:getRect();rect.label=child:getId();captions[#captions+1]=rect
    end
  end
  assert(#captions==17,'talent captions missing')
  for _,group in ipairs(state.tree.branchGroups)do
    local pane=assert(passives.getBranchWidget(group.id),'branch pane missing')
    assert(pane.label:getText():find(group.name,1,true),'branch label does not identify its group')
    assert(pane.required==group.unlockPoints,'branch requirement differs from server')
    local rect=pane.label:getRect();rect.label='branch '..group.id;captions[#captions+1]=rect
  end
  assert(passives.selectNode(selected),'could not restore selection after nameplate clicks')
  local routes=passives.getEdgeWidgets()
  assert(#routes==#state.tree.edges and #routes==21,'server graph connections missing')
  for index,first in ipairs(routes)do if first.capstone then
    for other=index+1,#routes do local second=routes[other]
      if second.capstone then
        for _,a in ipairs(first.segments)do if a.height==2 and a.width>2 then
          for _,b in ipairs(second.segments)do if b.height==2 and b.width>2 and a.y==b.y then
            assert(math.min(a.x+a.width,b.x+b.width)-math.max(a.x,b.x)<=2,
              'capstone alternatives share an ambiguous horizontal track: '..first.to..' / '..second.to)
          end end
        end end
      end
    end
  end end
  local expected={}
  for _,edge in ipairs(state.tree.edges)do expected[edge.from..'>'..edge.to]=true end
  local function onBoundary(point,nodeId)
    local rect=passives.getNodeWidget(nodeId):getRect()
    local cx,cy=canvas:getX(),canvas:getY()
    local x,y=cx+point[1],cy+point[2]
    return x>=rect.x-1 and x<=rect.x+rect.width+1 and y>=rect.y-1 and y<=rect.y+rect.height+1 and
      (math.abs(x-rect.x)<=1 or math.abs(x-rect.x-rect.width)<=1 or
       math.abs(y-rect.y)<=1 or math.abs(y-rect.y-rect.height)<=1)
  end
  for _,route in ipairs(routes)do
    local key=route.from..'>'..route.to
    assert(expected[key],'duplicate/invented connector: '..key);expected[key]=nil
    assert(#route.widgets>0 and #route.points>=2,'connection has no visible segments: '..key)
    assert(onBoundary(route.points[1],route.from),'connector detached from source: '..key)
    assert(onBoundary(route.points[#route.points],route.to),'connector detached from destination: '..key)
  end
  for _, child in ipairs(canvas:getChildren()) do
    if child:getId():find('^passiveLink_') then
      local link = child:getRect()
      inside(link, canvas:getRect(), label .. ': connector')
      for _, card in ipairs(rectangles) do
        assert(link.x + link.width <= card.x + 1 or link.x >= card.x + card.width - 1 or
          link.y + link.height <= card.y + 1 or link.y >= card.y + card.height - 1,
          'connector crosses a node card')
      end
      for _,caption in ipairs(captions)do
        assert(link.x+link.width<=caption.x or link.x>=caption.x+caption.width or
          link.y+link.height<=caption.y or link.y>=caption.y+caption.height,
          string.format('connector %s (%d,%d %dx%d) crosses %s (%d,%d %dx%d)',child:getId(),link.x,link.y,link.width,link.height,
            caption.label,caption.x,caption.y,caption.width,caption.height))
      end
    end
  end
  for i, a in ipairs(rectangles) do
    for j = i + 1, #rectangles do
      local b = rectangles[j]
      assert(a.x + a.width <= b.x or b.x + b.width <= a.x or
        a.y + a.height <= b.y or b.y + b.height <= a.y, 'node frames overlap')
    end
  end
  assert(passives.getNodeWidget('minor_precision'):getY() > passives.getNodeWidget('major_precision'):getY() and
    passives.getNodeWidget('major_precision'):getY() > passives.getNodeWidget('major_tactical'):getY() and
    passives.getNodeWidget('major_tactical'):getY() > passives.getNodeWidget(state.tree.nodes[15].id):getY(), 'tree must grow upwards')
  for _, id in ipairs({ 'treeVertical', 'treeHorizontal' }) do
    local bar = assert(window:recursiveGetChildById(id))
    bar:setValue(bar:getMaximum())
    assert(bar:getValue() == bar:getMaximum(), 'cannot scroll tree to the end')
    bar:setValue(bar:getMinimum())
  end

  for _, id in ipairs({ 'applyButton', 'closeButton', 'resetButton', 'endButton' }) do
    local button = assert(window:recursiveGetChildById(id), 'missing control ' .. id)
    assert(button:isVisible(), 'hidden control ' .. id)
    inside(button:getRect(), window:getRect(), label .. ': ' .. id)
  end
  local details = assert(window:recursiveGetChildById('details'))
  local scroll = assert(window:recursiveGetChildById('detailScroll'))
  assert(scroll:getHeight() > 80, 'node details viewport is too short')
  inside(scroll:getRect(), details:getRect(), label .. ': details scroll')
  local text = assert(window:recursiveGetChildById('nodeDescription'))
  assert(#text:getText() > 0, 'node description missing')

  -- Exercise the real scrollbar endpoints rather than only checking its size.
  local bar = assert(window:recursiveGetChildById('detailVertical'))
  bar:setValue(bar:getMinimum())
  assert(bar:getValue() == bar:getMinimum(), 'cannot scroll details to the beginning')
  bar:setValue(bar:getMaximum())
  assert(bar:getValue() == bar:getMaximum(), 'cannot scroll details to the end')
  bar:setValue(bar:getMinimum())
  print(string.format('PASSIVES_UI_SIZE_OK %s root=%dx%d window=%dx%d details=%d',
    label, root:getWidth(), root:getHeight(), window:getWidth(), window:getHeight(), scroll:getHeight()))
end

guarded(function()
  g_settings.set('window-maximized', false)
  g_settings.set('passivesTestShowStatus', false)
  g_window.resize({ width = 1280, height = 800 })
end)

local order={'reaver','blademaster','earthshaker','marksman','arcanist','lifekeeper'}
local trees
local function render(index)
  if index>#order then
    print('PASSIVES_ALL_TREES_UI_OK')
    print('PASSIVES_NATIVE_PREVIEW_OK')
    g_app.exit()
    return
  end
  passives=assert(modules.game_passives)
  passives.terminate();passives.init()
  local id=order[index]
  local tree=assert(trees[id], 'missing catalog '..id)
  local state=passives.getDebugState()
  state.tree,state.nodes=tree,{}
  for _,node in ipairs(tree.nodes)do state.nodes[node.id]=node end
  state.active,state.ready,state.points=true,true,24
  state.session,state.revision='all-trees-preview-no-server',1
  assert(passives.show())
  passives.selectNode('minor_precision')
  verify(id..' connections with minor selected')
  assert(passives.selectNode(tree.nodes[16].id))
  passives.getWindow():recursiveGetChildById('testLabel'):setText('NATIVE RETRO UI PREVIEW - these images do not demonstrate combat')
  later(650,function()
    verify(id..' 1280x800')
    g_app.doScreenshot('/passives-'..id..'-retro.png')
    later(400,function()
      g_window.resize({width=800,height=640})
      later(800,function()
        verify(id..' 800x640')
        g_app.doScreenshot('/passives-'..id..'-small-retro.png')
        later(400,function()
          g_window.resize({width=1280,height=800})
          later(800,function()render(index+1)end)
        end)
      end)
    end)
  end)
end
local startupDeadline=g_clock.millis()+12000
local function awaitRoot()
  local root=g_ui.getRootWidget()
  if root:getWidth()==1280 and root:getHeight()==800 then
    trees=json.decode(g_resources.readFileContents('/passives-preview-trees.txt'))
    render(1)
  else
    assert(g_clock.millis()<startupDeadline,'Native root did not reach requested 1280x800 viewport')
    later(100,awaitRoot)
  end
end
later(1000,awaitRoot)
