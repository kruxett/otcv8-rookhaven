-- Disposable native HUD probe; root owns fixture, packaging and process launch.
-- Real server start/preset/stop commands and real widget handlers, no combat,
-- synthetic counters, database edits or OS-input claim.
local classes = {
  {id='reaver', cap='cap_berserker'},
  {id='blademaster', cap='cap_bladestorm', trigger='On critical hit'},
  {id='earthshaker', cap='cap_aftershock'},
  {id='marksman', cap='cap_deadeye'},
  {id='arcanist', cap='cap_resonance'},
  {id='lifekeeper', cap='cap_aegis', trigger='On effective healing'}
}
local account = PASSIVES_HUD_ACCOUNT or 'passivetest'
local password = PASSIVES_HUD_PASSWORD or account
local character = PASSIVES_HUD_CHARACTER or 'Passive Tester'
local mod, login, originalStatus
local failed, done, intentional = false, false, false
local states, barCases, inputCases, screenshots = 0, 0, 0, 0
local started = g_clock.millis()
local function fail(reason)
  if failed or done then return end
  failed = true
  print('PASSIVES_STATUS_HUD_FAILED ' .. tostring(reason))
  local ok, cleanupError = pcall(function()
    if mod and originalStatus ~= nil then mod.setStatusVisible(originalStatus) end
    if g_game.isOnline() then
      g_game.talk('/passivetest stop ' .. character)
      intentional = true; g_game.safeLogout()
    else g_game.cancelLogin() end
  end)
  if not ok then print('PASSIVES_STATUS_HUD_CLEANUP_FAILED ' .. tostring(cleanupError)) end
  pcall(scheduleEvent, function() g_app.exit() end, 600)
end
local function guarded(callback, ...)
  if failed or done then return end
  local ok, reason = pcall(callback, ...)
  if not ok then fail(reason) end
end
local function later(ms, callback)
  return scheduleEvent(function() guarded(callback) end, ms)
end
local function wait(label, predicate, callback, timeout)
  local deadline = g_clock.millis() + (timeout or 8000)
  local function poll()
    if predicate() then callback(); return end
    assert(g_clock.millis() < deadline, label .. ' timeout')
    later(70, poll)
  end
  later(100, poll)
end
local function state() return mod.getState() end
local function capstone()
  for _, node in ipairs(state().tree and state().tree.nodes or {}) do
    if node.type == 'capstone' and (state().ranks[node.id] or 0) > 0 then return node end
  end
end
local function widget(hud, id) return assert(hud:recursiveGetChildById(id), 'Missing actual HUD widget ' .. id) end
local function hud()
  mod.setStatusVisible(true)
  local window = assert(mod.getStatusWindow(), 'Missing actual status window')
  if window:isOn() then window:maximize(true) end
  assert(window:isVisible(), 'HUD not visible')
  return window
end
local function within(inner, outer)
  return inner.x >= outer.x and inner.y >= outer.y and
    inner.x + inner.width <= outer.x + outer.width and inner.y + inner.height <= outer.y + outer.height
end
local function checkNoCap(info, label)
  assert(state().active and state().mode == 'test' and state().tree.id == info.id and not capstone(), 'Wrong no-cap overlay')
  for _, rank in pairs(state().ranks) do assert(rank == 0, 'Fresh overlay retained ranks') end
  local window = hud()
  assert(window:getHeight() == 72 and window.maximizedHeight == 72, 'No-cap HUD not compact72')
  assert(widget(window, 'capstoneLabel'):isVisible() and widget(window, 'capstoneLabel'):getText() == 'No capstone selected',
    'No-cap title misleading or duplicated by weapon requirement')
  for _, id in ipairs({'rageBar','berserkLabel','wardLabel','bleedLabel'}) do
    assert(not widget(window, id):isVisible(), 'No-cap HUD retained fake mechanic ' .. id)
  end
  local button = widget(window, 'treeButton')
  assert(button:isVisible() and button:isEnabled() and button:getText() == 'Open tree', 'No-cap Open tree lost')
  assert(within(button:getRect(), window:getRect()), 'Compact HUD clips Open tree')
  assert(within(widget(window, 'capstoneLabel'):getRect(), window:getRect()), 'Compact HUD clips capstone title')
  states = states + 1
  print('PASSIVES_STATUS_HUD_STATE_OK ' .. info.id .. ' ' .. label .. ' height72 mechanicsHidden=4')
  return window
end
local function checkCap(info, original)
  local cap = assert(capstone(), 'Preset did not allocate a capstone')
  assert(cap.id == info.cap and state().mode == 'test' and state().tree.id == info.id, 'Wrong actual preset')
  local window = hud()
  assert(window == original, 'Preset replaced HUD instead of restoring its mechanic rows')
  assert(window:getHeight() == 150 and window.maximizedHeight == 150, 'Cap HUD did not restore150')
  local title = widget(window, 'capstoneLabel')
  local expected = state().runtime.weaponActive == false and state().tree.weaponName .. ' required' or cap.name
  assert(title:isVisible() and title:getText() == expected, 'Cap HUD title disagrees with authoritative weapon/cap state')
  assert(title:getTextSize().width <= title:getWidth(), 'Cap HUD title clipped')
  for _, id in ipairs({'berserkLabel','wardLabel','bleedLabel'}) do
    assert(widget(window, id):isVisible(), 'Cap did not restore mechanic row ' .. id)
    assert(within(widget(window, id):getRect(), window:getRect()), 'Cap HUD clips mechanic row ' .. id)
  end
  local bar, first = widget(window, 'rageBar'), widget(window, 'berserkLabel')
  assert(bar:isVisible() == (info.trigger == nil), 'Reactive/non-reactive cap bar visibility wrong')
  if info.trigger then
    assert(first:getText() == info.trigger, 'Reactive trigger text missing')
    assert(first:getY() >= title:getY() + title:getHeight() and first:getY() <= title:getY() + title:getHeight() + 8,
      'Reactive cap retained hidden-bar blank gap')
  elseif info.id == 'reaver' then
    assert(bar:getText():find('Rage: ', 1, true) == 1 and first:getText() == 'Berserk: inactive', 'Reaver did not restore rage/berserk UI')
    assert(first:getY() >= bar:getY() + bar:getHeight(), 'Reaver status not anchored below restored rage bar')
  else
    assert(bar:getText() ~= '' and first:getText() ~= 'No capstone', 'Charging cap retained no-cap mechanics')
    assert(first:getY() >= bar:getY() + bar:getHeight(), 'Charging cap not anchored below restored bar')
  end
  states = states + 1; barCases = barCases + 1
  print('PASSIVES_STATUS_HUD_STATE_OK ' .. info.id .. ' cap height150 bar=' .. tostring(bar:isVisible()) .. ' name=' .. cap.name)
  return window
end
local function capture(info, kind, callback)
  mod.hide()
  later(250, function()
    assert(mod.getStatusWindow():isVisible(), 'Capture lost HUD')
    g_app.doScreenshot('/passives-status-hud-' .. info.id .. '-' .. kind .. '.png')
    screenshots = screenshots + 1
    print('PASSIVES_STATUS_HUD_CAPTURE ' .. info.id .. ' ' .. kind)
    later(150, callback)
  end)
end
local function stop(callback)
  if not state().active or state().mode ~= 'test' then later(150, callback); return end
  local session = state().session
  g_game.talk('/passivetest stop ' .. character)
  wait('overlay stop', function() return not state().active or state().mode ~= 'test' or state().session ~= session end,
    function() later(150, callback) end)
end
local function start(info, callback)
  local oldSession = state().session
  g_game.talk('/passivetest start ' .. info.id .. ', ' .. character)
  wait(info.id .. ' start', function()
    return state().active and state().mode == 'test' and state().tree and state().tree.id == info.id and state().session ~= oldSession
  end, function() later(200, callback) end)
end
local function waitCapRuntime(info, previousRuntime, requestedAt, callback)
  -- Preset sends catalog/ranks immediately; runtime follows Player::onThink
  -- (1000ms). The controller replaces this table only on a runtime packet.
  local suffix = info.cap:gsub('^cap_', '')
  local statuses = {
    ['Building: ' .. suffix] = true, ['Reactive: ' .. suffix] = true,
    ['Ready: ' .. suffix] = true, ['Cooldown: ' .. suffix] = true
  }
  wait(info.id .. ' authoritative runtime for ' .. suffix, function()
    local current, runtime = state(), state().runtime
    return current.active and current.mode == 'test' and current.tree and current.tree.id == info.id and
      (current.ranks[info.cap] or 0) == 1 and runtime ~= previousRuntime and type(runtime) == 'table' and
      statuses[runtime.status1] == true and type(runtime.progress) == 'number' and
      type(runtime.progressMax) == 'number' and runtime.progressMax >= 1
  end, function()
    print('PASSIVES_STATUS_HUD_RUNTIME_OK ' .. info.id .. ' waitedMs=' .. (g_clock.millis() - requestedAt) ..
      ' status=' .. state().runtime.status1)
    callback()
  end, 5000)
end
local run
local function finish()
  stop(function()
    assert(states == 18 and inputCases == 6 and barCases == 6 and screenshots == 12, 'Incomplete HUD matrix')
    mod.setStatusVisible(originalStatus)
    intentional = true; g_game.safeLogout()
    wait('final logout', function() return not g_game.isOnline() end, function()
      assert(not mod.getStatusWindow(), 'Logout retained HUD widget')
      done = true
      print('PASSIVES_STATUS_HUD_OK classes=6 states=18 inputHandlers=6 barCases=6 screenshots=12 cases=30')
      scheduleEvent(function() g_app.exit() end, 400)
    end)
  end)
end
run = function(index)
  if index > #classes then finish(); return end
  local info = classes[index]
  start(info, function()
    local baseline = checkNoCap(info, 'baseline')
    local button = widget(baseline, 'treeButton')
    signalcall(button.onClick, button)
    assert(mod.getWindow() and mod.getWindow():isVisible(), 'Actual Open tree callback did not reopen the talent window')
    assert(mod.getStatusWindow() == baseline and baseline:isVisible(), 'Open tree callback replaced or hid HUD')
    inputCases = inputCases + 1
    capture(info, 'no-cap', function()
      local revision = state().revision
      local previousRuntime, requestedAt = state().runtime, g_clock.millis()
      g_game.talk('/passivetest preset ' .. character .. ',' .. info.cap:gsub('^cap_', ''))
      wait(info.id .. ' preset', function()
        return state().revision > revision and (state().ranks[info.cap] or 0) == 1
      end, function()
        waitCapRuntime(info, previousRuntime, requestedAt, function()
          local expanded = checkCap(info, baseline)
          capture(info, 'cap', function()
            stop(function()
              assert(expanded:isDestroyed(), 'Stopped overlay retained old HUD')
              start(info, function()
                local restored = checkNoCap(info, 'restart')
                assert(restored ~= expanded, 'Restart reused destroyed HUD')
                stop(function() run(index + 1) end)
              end)
            end)
          end)
        end)
      end)
    end)
  end)
end
later(200, function()
  assert(LOCAL_PASSIVES_TEST and Services.updater == '' and g_resources.getLayout() == 'retro')
  mod = assert(modules.game_passives)
  originalStatus = g_settings.getBoolean('passivesTestShowStatus', true)
  g_window.resize({width=1280,height=800})
  connect(g_game, {
    onGameStart = function()
      guarded(function()
        EnterGame.hide()
        wait('passive handshake', function() return state().ready end, function()
          stop(function() run(1) end)
        end, 15000)
      end)
    end,
    onLoginError = function(reason) fail('World login: ' .. tostring(reason)) end,
    onConnectionError = function(reason, code) if not intentional then fail('World connection: ' .. tostring(reason) .. ' code=' .. tostring(code)) end end
  }, true)
  login = ProtocolLogin.create(); _G.passivesStatusHUDLogin = login
  login.onLoginError = function(_, reason) fail('Account login: ' .. tostring(reason)) end
  login.onCharacterList = function(_, list)
    guarded(function()
      for _, entry in ipairs(list) do if entry.name == character then
        g_game.loginWorld(account, password, entry.worldName, entry.worldIp, entry.worldPort, entry.name, '', '')
        return
      end end
      error('Disposable HUD fixture absent')
    end)
  end
  g_game.setClientVersion(860); g_game.setProtocolVersion(860); g_game.setRsa(OTSERV_RSA)
  G.account, G.password = account, password
  login:login('127.0.0.1', 7174, account, password, '', false)
end)
scheduleEvent(function() if not done then fail('HUD90-second timeout elapsed=' .. (g_clock.millis() - started)) end end, 90000)
