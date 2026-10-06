-- Offline native probe of the normal-profile guard in the packaged module.
-- The runner uses the disposable local-passives archive with its updater off;
-- only the separately loaded module chunk sees LOCAL_PASSIVES_TEST = false.
local function probe()
  assert(LOCAL_PASSIVES_TEST == true, 'expected the disposable local-passives runner')
  assert(Services and Services.updater == '', 'updater must be disabled before this probe starts')
  assert(g_resources.isLoadedFromArchive(), 'probe must read the packaged archive')
  assert(not g_game.isOnline() and not g_game.isLogging(), 'probe must remain offline')

  for _, name in ipairs({ 'client_entergame', 'game_interface', 'game_inventory',
      'game_console', 'game_passives' }) do
    local module = g_modules.getModule(name)
    assert(module and module:isLoaded(), 'existing module did not load: ' .. name)
  end

  local root = assert(g_ui.getRootWidget(), 'UI root missing')
  for _, id in ipairs({ 'enterGame', 'gameRootPanel', 'inventoryWindow', 'consolePanel' }) do
    assert(root:recursiveGetChildById(id), 'existing UI missing: ' .. id)
  end
  assert(not root:recursiveGetChildById('passivesWindow'), 'passive tree opened while offline')
  assert(not root:recursiveGetChildById('passivesStatus'), 'passive status opened while offline')

  local path = '/modules/game_passives/passives.lua'
  local packagedPath = g_resources.guessFilePath(path, 'lua')
  assert(g_resources.fileExists(packagedPath), 'packaged passive module missing')
  -- Native loadfile uses LuaInterface::loadScript, including the .luac fallback
  -- and ResourceManager's decryption. Lua's readFileContents binding returns
  -- raw archive bytes and cannot load an encrypted packaged script directly.
  local chunk = assert(loadfile(path), 'cannot load packaged passive module')

  local touched = {}
  local function forbidden(name)
    return function()
      touched[#touched + 1] = name
      error('normal-profile init called ' .. name, 2)
    end
  end

  -- The chunk receives its own globals. Its real init/terminate functions run
  -- against spies, so a regression cannot register handlers or create widgets.
  local env = {
    LOCAL_PASSIVES_TEST = false,
    ProtocolGame = {
      registerExtendedOpcode = forbidden('ProtocolGame.registerExtendedOpcode'),
      unregisterExtendedOpcode = forbidden('ProtocolGame.unregisterExtendedOpcode'),
      registerExtendedJSONOpcode = forbidden('ProtocolGame.registerExtendedJSONOpcode')
    },
    connect = forbidden('connect'),
    disconnect = forbidden('disconnect'),
    scheduleEvent = forbidden('scheduleEvent'),
    addEvent = forbidden('addEvent'),
    removeEvent = forbidden('removeEvent'),
    g_ui = {
      getRootWidget = forbidden('g_ui.getRootWidget'),
      displayUI = forbidden('g_ui.displayUI'),
      loadUI = forbidden('g_ui.loadUI'),
      createWidget = forbidden('g_ui.createWidget')
    },
    g_resources = { getLayout = forbidden('g_resources.getLayout') },
    g_game = {
      isOnline = forbidden('g_game.isOnline'),
      getProtocolGame = forbidden('g_game.getProtocolGame')
    },
    g_keyboard = {
      bindKeyDown = forbidden('g_keyboard.bindKeyDown'),
      bindKeyPress = forbidden('g_keyboard.bindKeyPress')
    },
    g_settings = { set = forbidden('g_settings.set') }
  }
  env._G = env
  setmetatable(env, { __index = _G })
  setfenv(chunk, env)
  chunk()
  assert(type(rawget(env, 'init')) == 'function', 'packaged module did not define init')
  assert(type(rawget(env, 'terminate')) == 'function', 'packaged module did not define terminate')
  env.init()
  env.terminate()
  assert(#touched == 0, 'normal-profile guard reached a side-effect API')
  assert(env.getWindow() == nil and env.getStatusWindow() == nil,
    'normal-profile guard created passive UI state')
  local state = env.getState()
  assert(state and state.tree == nil and state.active == false and state.ready == false,
    'normal-profile guard left an active passive session')
end

scheduleEvent(function()
  local ok, reason = pcall(probe)
  if ok then
    print('PASSIVES_NORMAL_GUARD_OK')
  else
    print('PASSIVES_NORMAL_GUARD_FAILED ' .. tostring(reason))
  end
  g_app.exit()
end, 300)
