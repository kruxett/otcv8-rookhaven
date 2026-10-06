-- Native retro UI preview only: the catalog comes from the server registry,
-- but this probe does not establish a game connection or prove combat effects.
assert(LOCAL_PASSIVES_TEST and Services.updater == '')
assert(g_resources.getLayout() == 'retro')
g_settings.set('window-maximized', false)
g_window.resize({width=1280,height=800})
scheduleEvent(function()
  local ok, reason = pcall(function()
    assert(modules.game_passives, 'passive module missing')
    local tree = json.decode(g_resources.readFileContents('/passives-preview-tree.txt'))
    local state = modules.game_passives.getDebugState()
    state.tree, state.nodes = tree, {}
    for _, node in ipairs(tree.nodes) do state.nodes[node.id] = node end
    state.active, state.ready, state.points = true, true, 24
    state.session, state.revision = 'preview-no-server', 1
    assert(modules.game_passives.show(), 'could not render tree')
    modules.game_passives.selectNode('cap_bloodletting')
    local window = assert(modules.game_passives.getWindow())
    window:recursiveGetChildById('testLabel'):setText('NATIVE RETRO UI PREVIEW - combat has not been tested in this image')
    assert(modules.game_passives.getNodeWidget('cap_bloodguard'))
  end)
  if not ok then print('PASSIVES_PREVIEW_FAILED '..tostring(reason)); g_app.exit(); return end
  scheduleEvent(function()
    g_app.doScreenshot('/passives-preview-retro.png')
    scheduleEvent(function() print('PASSIVES_NATIVE_PREVIEW_OK'); g_app.exit() end, 1200)
  end, 1200)
end, 1000)
