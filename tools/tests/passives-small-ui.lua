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
    g_app.exit()
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
    assert(not widget:getChildById('marker'),'unexplained marker retained')
    if node.type=='minor'then
      local nameLabel=assert(canvas:getChildById('nodeCaption_'..node.id))
      assert(nameLabel:getTextAlign()==AlignCenter,'minor lettering is not centered')
      assert(nameLabel:getTextSize().width<=nameLabel:getWidth()-2,'minor name clipped: '..node.name)
      assert(nameLabel:getTextSize().height<=nameLabel:getHeight()-2,'minor name clipped vertically: '..node.name)
    end
    if node.type == 'capstone' then
      assert(not widget:getChildById('capstoneTier'),'capstone text overlaps glyph')
      local link = assert(canvas:getChildById('capstoneLink_' .. node.id), 'capstone connection missing: ' .. node.id)
      assert(link:isVisible(),'capstone connection is hidden')
    end
  end
  local captions={}
  for _,child in ipairs(canvas:getChildren())do
    if child:getId():find('^nodeCaption_')then
      inside(child:getRect(),canvas:getRect(),label..': major caption')
      captions[#captions+1]=child:getRect()
    end
  end
  assert(#captions==17,'talent captions missing')
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
          'connector crosses a major name')
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
    passives.getNodeWidget('major_tactical'):getY() > passives.getNodeWidget('cap_berserker'):getY(), 'tree must grow upwards')
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

later(1000, function()
  passives = assert(modules.game_passives, 'passive module missing')
  local tree = json.decode(g_resources.readFileContents('/passives-preview-tree.txt'))
  local state = passives.getDebugState()
  state.tree, state.nodes = tree, {}
  for _, node in ipairs(tree.nodes) do state.nodes[node.id] = node end
  state.active, state.ready, state.points = true, true, 24
  state.session, state.revision = 'small-preview-no-server', 1
  assert(passives.show(), 'could not open the native tree')
  passives.selectNode('minor_precision')
  verify('capstone connections with minor selected')
  assert(passives.selectNode('cap_bloodletting'), 'could not select the capstone')
  passives.getWindow():recursiveGetChildById('testLabel'):setText('NATIVE RETRO UI PREVIEW - combat has not been tested in these images')

  later(900, function()
    verify('1280x800')
    g_app.doScreenshot('/passives-large-retro.png')
    later(500, function()
      g_window.resize({ width = 800, height = 640 })
      later(900, function()
        verify('800x640')
        g_app.doScreenshot('/passives-small-retro.png')
        later(900, function()
          print('PASSIVES_SMALL_UI_OK')
          print('PASSIVES_NATIVE_PREVIEW_OK')
          g_app.exit()
        end)
      end)
    end)
  end)
end)
