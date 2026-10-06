-- Disposable native client probe. Root owns packaging, loopback fixture and launch.
-- Actual widget handlers + two network relogs; this does not claim OS drag input.
local mod, login, grabber, source, cooldownEvent, cooldownCleared
local cycle, destroys = 0, 0
local failed, done, intentional = false, false, false
local account = PASSIVES_ACTIONBAR_ACCOUNT or 'passivetest'
local character = PASSIVES_ACTIONBAR_CHARACTER or 'Passive Tester'
local originalVisible, originalLock, originalSettings
local phase, started = 'setup', g_clock.millis()
local accountLoginEvent, worldLoginEvent
local function diagnostic(event, detail)
  print('PASSIVES_ACTIONBAR_RELOGIN_' .. event .. ' cycle=' .. cycle ..
    ' elapsedMs=' .. (g_clock.millis() - started) .. ' phase=' .. phase ..
    ' online=' .. tostring(g_game.isOnline()) .. ' intentional=' .. tostring(intentional) ..
    (detail and (' ' .. detail) or ''))
end
local function clearLoginEvents()
  if accountLoginEvent then removeEvent(accountLoginEvent); accountLoginEvent = nil end
  if worldLoginEvent then removeEvent(worldLoginEvent); worldLoginEvent = nil end
end
local function private(fn, wanted)
  local fallback
  for i = 1, 60 do
    local name, value = debug.getupvalue(fn, i)
    if not name then break end
    if name == wanted then return value end
    -- Client packaging strips LuaJIT debug names. Inspect the actual values;
    -- never assume a fixed upvalue index from an uncompiled source function.
    if wanted == 'mouseGrabberWidget' and type(value) == 'userdata' and
      value.onMouseRelease == mod.onDropActionButton then fallback = value
    elseif wanted == 'settings' and type(value) == 'table' and value.BLANK == nil then
      assert(not fallback, 'Ambiguous actual settings table'); fallback = value
    elseif wanted == 'actionBars' and type(value) == 'table' and
      (#value == 0 or type(value[1]) == 'userdata' and value[1]:getId() == 'actionbar.1') then
      assert(not fallback, 'Ambiguous actual actionBars table'); fallback = value
    elseif wanted == 'cachedSettings' and type(value) == 'table' and
      value.widget and value.id then fallback = value end
  end
  if fallback or wanted == 'cachedSettings' or wanted == 'mouseGrabberWidget' then return fallback end
  error('Missing actual actionbar upvalue ' .. wanted)
end
local function restoreOptions()
  if originalVisible ~= nil then g_settings.set('actionbar1', originalVisible) end
  if originalSettings then originalSettings['actionbar.1'] = originalLock end
end
local function fail(reason)
  if failed or done then return end
  failed = true
  diagnostic('FAILED', tostring(reason))
  local ok, cleanupError = pcall(function()
    clearLoginEvents()
    restoreOptions()
    if g_game.isOnline() then intentional = true; g_game.safeLogout() end
  end)
  if not ok then print('PASSIVES_ACTIONBAR_RELOGIN_CLEANUP_FAILED ' .. tostring(cleanupError)) end
  pcall(scheduleEvent, function() g_app.exit() end, 600)
end
local function guarded(event, callback)
  return function(...)
    diagnostic(event)
    local ok, reason = pcall(callback, ...)
    if not ok then fail(event .. ' callback: ' .. tostring(reason)) end
  end
end
local function later(ms, callback)
  scheduleEvent(function()
    if failed or done then return end
    local ok, reason = pcall(callback)
    if not ok then fail(reason) end
  end, ms)
end
local function wait(label, predicate, callback, timeout)
  local deadline = g_clock.millis() + (timeout or 10000)
  local function poll()
    if predicate() then callback(); return end
    assert(g_clock.millis() < deadline, label .. ' timeout')
    later(70, poll)
  end
  later(100, poll)
end
local function drag()
  assert(not grabber:isDestroyed(), 'Destroyed grabber after relog')
  assert(not g_ui.isMouseGrabbed(), 'Mouse still grabbed before drag')
  signalcall(source.item.onDragEnter, source.item)
  assert(g_ui.isMouseGrabbed(), 'Real actionbar handler failed to grab mouse')
  assert(private(mod.onDropActionButton, 'cachedSettings').widget == source,
    'Real actionbar handler did not retain source')
end
local doLogin, inspect
local function finish()
  phase = 'module_unload'
  diagnostic('UNLOAD_BEGIN')
  restoreOptions()
  local module = assert(g_modules.getModule('game_actionbar'))
  local oldTerminate = mod.terminate
  module:unload()
  assert(not module:isLoaded(), 'Actual actionbar module did not unload')
  assert(grabber:isDestroyed() and destroys == 1, 'Module unload did not destroy grabber exactly once')
  assert(cooldownCleared, 'Module unload retained a destroyed-button cooldown')
  assert(private(oldTerminate, 'mouseGrabberWidget') == nil, 'Module unload retained grabber')
  assert(not g_ui.isMouseGrabbed(), 'Module unload retained mouse grab')
  print('PASSIVES_ACTIONBAR_RELOGIN_UNLOAD_OK destroyCount=1')
  assert(module:load() and module:isLoaded(), 'Actual actionbar module did not reload')
  mod = assert(modules.game_actionbar)
  local fresh = private(mod.init, 'mouseGrabberWidget')
  assert(fresh and fresh ~= grabber and not fresh:isDestroyed(), 'Reload did not create a fresh grabber')
  intentional = true
  phase = 'final_logout'
  g_game.safeLogout()
  wait('final logout', function() return not g_game.isOnline() end, function()
    assert(not fresh:isDestroyed(), 'Fresh module grabber destroyed on logout')
    assert(not g_ui.isMouseGrabbed() and destroys == 1, 'Final logout leaked grab or repeated destruction')
    done = true
    print('PASSIVES_ACTIONBAR_RELOGIN_OK relogs=2 dragHandlers=6 canceledDrags=3 unloadDestroyCount=1')
    scheduleEvent(function() g_app.exit() end, 400)
  end)
end
inspect = function()
  phase = 'inspect'
  diagnostic('INSPECT_BEGIN')
  mod = assert(modules.game_actionbar)
  local actual = private(mod.init, 'mouseGrabberWidget')
  if not grabber then
    grabber = assert(actual)
    connect(grabber, { onDestroy = function() destroys = destroys + 1 end })
  end
  assert(actual == grabber and not grabber:isDestroyed() and destroys == 0,
    'Relog replaced/destroyed module-owned grabber')
  originalVisible = g_settings.getBoolean('actionbar1', false)
  local settings = private(mod.setupButton, 'settings')
  originalSettings = settings
  originalLock = settings['actionbar.1']
  settings['actionbar.1'] = nil
  g_settings.set('actionbar1', true)
  mod.show()
  local bars = private(mod.createActionBars, 'actionBars')
  assert(#bars == 9 and not bars[1].locked, 'Missing unlocked actual actionbar')
  source = assert(bars[1].tabBar:getChildById('1.1'))
  cooldownCleared = false
  connect(source, { onDestroy = function() cooldownCleared = source.cooldownEvent == nil end })
  drag()
  signalcall(grabber.onMouseRelease, grabber, { x = -10, y = -10 }, MouseLeftButton)
  assert(not g_ui.isMouseGrabbed() and private(mod.onDropActionButton, 'cachedSettings') == nil,
    'Real outside-drop callback retained mouse/source')
  assert(colortostring(source.item:getBorderTopColor()) == colortostring(tocolor('#00000000')),
    'Real outside-drop callback retained source highlight')
  drag()
  mod.startCooldown(source, 5000)
  cooldownEvent = assert(source.cooldownEvent, 'Actual cooldown did not schedule a callback')
  print('PASSIVES_ACTIONBAR_RELOGIN_DRAG_OK cycle=' .. cycle .. ' grabber=' .. grabber:getId())
  restoreOptions()
  if cycle == 2 then finish(); return end
  intentional = true
  phase = 'logout'
  g_game.safeLogout()
  wait('logout', function() return not g_game.isOnline() end, function()
    assert(not grabber:isDestroyed() and destroys == 0, 'Logout destroyed module grabber')
    assert(not g_ui.isMouseGrabbed() and private(mod.onDropActionButton, 'cachedSettings') == nil,
      'Logout retained drag/source/cursor')
    assert(source:isDestroyed() and #private(mod.createActionBars, 'actionBars') == 0,
      'Logout retained actionbar widgets')
    assert(cooldownCleared and (cooldownEvent:isCanceled() or cooldownEvent:isExecuted()),
      'Logout retained a scheduled destroyed-button cooldown')
    print('PASSIVES_ACTIONBAR_RELOGIN_OFFLINE_OK cycle=' .. cycle)
    cycle = cycle + 1
    -- Each login opens an account connection and a world connection. Leave the
    -- server's five-second burst window before beginning the next pair.
    later(6200, doLogin)
  end)
end
doLogin = function()
  clearLoginEvents()
  -- Intentional EOF is allowed only for the preceding logout. A failed NEW
  -- world connection must report its real error, not wait for global timeout.
  intentional = false
  phase = 'account_login'
  diagnostic('LOGIN')
  G.account, G.password = account, account
  login = ProtocolLogin.create()
  _G.actionbarReloginLogin = login
  login.onLoginError = guarded('ACCOUNT_ERROR', function(_, reason) fail('Account login: ' .. tostring(reason)) end)
  login.onCharacterList = guarded('CHARACTER_LIST', function(_, list)
    assert(type(list) == 'table', 'Invalid character list')
    diagnostic('CHARACTER_LIST_COUNT', 'count=' .. #list)
    if accountLoginEvent then removeEvent(accountLoginEvent); accountLoginEvent = nil end
    for _, entry in ipairs(list) do
      if entry.name == character then
        phase = 'world_login'
        diagnostic('WORLD_LOGIN_BEGIN', 'character=' .. entry.name .. ' port=' .. entry.worldPort)
        worldLoginEvent = scheduleEvent(function()
          worldLoginEvent = nil
          if not failed and not done then fail('World login15-second timeout') end
        end, 15000)
        g_game.loginWorld(account, account, entry.worldName, entry.worldIp, entry.worldPort, entry.name, '', '')
        diagnostic('WORLD_LOGIN_SENT')
        return
      end
    end
    fail('Disposable actionbar character absent')
  end)
  accountLoginEvent = scheduleEvent(function()
    accountLoginEvent = nil
    if not failed and not done then fail('Account login15-second timeout') end
  end, 15000)
  login:login('127.0.0.1', 7174, account, account, '', false)
end
later(200, function()
  assert(LOCAL_PASSIVES_TEST and Services.updater == '' and g_resources.getLayout() == 'retro')
  connect(g_game, {
    onGameStart = guarded('GAME_START', function()
      clearLoginEvents(); intentional = false; EnterGame.hide()
      phase = 'inspect_scheduled'; diagnostic('INSPECT_SCHEDULED'); later(500, inspect)
    end),
    onGameEnd = guarded('GAME_END', function() end),
    onEnterGame = guarded('ENTER_GAME', function() end),
    onLoginError = guarded('WORLD_ERROR', function(reason) fail('World login: ' .. tostring(reason)) end),
    onLoginWait = guarded('WORLD_WAIT', function(reason, seconds)
      fail('World login wait: ' .. tostring(reason) .. ' seconds=' .. tostring(seconds))
    end),
    onLoginToken = guarded('WORLD_TOKEN', function() fail('World login requested an unexpected token') end),
    onUpdateNeeded = guarded('WORLD_UPDATE', function() fail('World login requested an unexpected update') end),
    onConnectionError = guarded('CONNECTION_ERROR', function(reason, code)
      diagnostic('CONNECTION_DETAIL', 'code=' .. tostring(code) .. ' reason=' .. tostring(reason))
      if not intentional then fail('World connection: ' .. tostring(reason) .. ' code=' .. tostring(code)) end
    end)
  }, true)
  g_game.setClientVersion(860); g_game.setProtocolVersion(860); g_game.setRsa(OTSERV_RSA)
  doLogin()
end)
scheduleEvent(function() if not done then fail('Actionbar120-second timeout') end end, 120000)
