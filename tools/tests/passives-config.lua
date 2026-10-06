-- Live config -> catalog -> native effects -> HUD regression.
-- Root supplies/restores runtime-only Reaver overrides; this script never edits config:
-- minorVitality=2, rageThreshold=40, minorPrecisionBps=25, majorCriticalReadyMs=16000.
-- Normal attacks are the only source of rage; diagnostic fixtures are setup only.
local mod, login, player, metrics
local sequence = 0
local failed, done, finishing = false, false, false
local successfulHits, previousRage = 0, 0
local selfName = 'Passive Tester'

local function fail(reason)
  if failed or done then return end
  failed = true
  print('PASSIVES_CONFIG_FAILED ' .. tostring(reason))
  if g_game.isOnline() then
    g_game.cancelAttack()
    g_game.talk('/passiveqa quiesce ' .. selfName)
    scheduleEvent(function() if g_game.isOnline() then g_game.talk('/passivetest stop') end end, 200)
    scheduleEvent(function() if g_game.isOnline() then g_game.safeLogout() end end, 500)
  end
  scheduleEvent(function() g_app.exit() end, 1000)
end

local function later(ms, fn)
  scheduleEvent(function()
    if failed or done then return end
    local ok, err = pcall(fn)
    if not ok then fail(err) end
  end, ms)
end

local function wait(label, predicate, nextStep, timeout)
  local deadline = g_clock.millis() + (timeout or 9000)
  local function poll()
    if predicate() then nextStep(); return end
    assert(g_clock.millis() < deadline, label .. ' timeout')
    later(70, poll)
  end
  later(100, poll)
end

local function state() return mod.getState() end

local function commands(list, nextStep)
  local function step(index)
    if index > #list then later(400, nextStep); return end
    g_game.talk(list[index])
    later(300, function() step(index + 1) end)
  end
  step(1)
end

local function measure(nextStep)
  local before = sequence
  g_game.talk('/passiveqa metrics ' .. selfName)
  wait('native config metrics', function()
    return sequence > before and metrics.player == selfName
  end, function() nextStep(metrics) end)
end

local function node(id)
  for _, candidate in ipairs(assert(state().tree).nodes) do
    if candidate.id == id then return candidate end
  end
  error('Missing catalog node ' .. id)
end

local function rankValue(id, rank)
  local text = assert(node(id).ranks[rank], 'Missing catalog rank')
  return tonumber(text:match('%+([%d%.]+)')), text
end

local function assertHud()
  local hud = mod.getStatusWindow and mod.getStatusWindow() or
    g_ui.getRootWidget():recursiveGetChildById('passivesStatus')
  assert(hud and hud:isVisible(), 'Combat HUD is missing or hidden')
  local bar = assert(hud:recursiveGetChildById('rageBar'), 'Rage bar missing')
  assert(bar:isVisible() and bar:getText():match('/%s*40$'),
    'HUD retained hardcoded rage maximum: ' .. tostring(bar:getText()))
end

local function finish(m)
  finishing = true
  g_game.cancelAttack()
  assert(successfulHits == 4, 'Berserk did not use four native successful hits')
  assert(m.maxHP == 808 and m.runtime.rageMax == 40, 'Native config diverged during combat')
  assert(m.lastProc == 'Berserker' and m.procCount == 1 and m.berserkMs > 0,
    'Native metrics did not confirm first natural Berserk')
  assertHud()
  mod.show(); mod.selectNode('cap_berserker')
  print('PASSIVES_CONFIG_NATURAL_OK successfulHits=4 ' .. json.encode(m))
  later(250, function()
    g_app.doScreenshot('/passives-config-natural.png')
    commands({'/passiveqa quiesce ' .. selfName, '/passivetest stop'}, function()
      wait('config overlay cleanup', function() return not state().active end, function()
        assert(player:getMaxHealth() == 735, 'Stop retained configured derived HP')
        g_game.safeLogout()
        wait('config logout', function() return not g_game.isOnline() end, function()
          assert(not state().tree and not mod.getWindow() and not mod.getStatusWindow(),
            'Logout retained passive state/windows')
          done = true
          print('PASSIVES_CONFIG_OK')
          scheduleEvent(function() g_app.exit() end, 400)
        end)
      end)
    end)
  end)
end

local function combat()
  mod.hide()
  g_game.setFightMode(FightOffensive)
  local target
  for _, creature in ipairs(g_map.getSpectators(player:getPosition(), false)) do
    if creature:getName() == 'Passive Test Dummy' and
      (not target or creature:getId() < target:getId()) then target = creature end
  end
  assert(target, 'Natural arena target missing')
  assert(state().runtime.rage == 0, 'Setup retained rage')
  g_game.attack(target)
  local deadline = g_clock.millis() + 40000
  local function poll()
    assert(g_game.isOnline() and player:getHealth() > 0, 'Fixture disconnected or died')
    local runtime = state().runtime
    assert(runtime.rageMax == 40, 'Native rage maximum changed or was omitted')
    if (runtime.berserkUntil or 0) > g_clock.millis() then
      -- The fourth successful ordinary hit consumes the three previously seen
      -- ten-rage increments. No attack timer or forced counter substitutes for them.
      assert(previousRage == 30 and successfulHits == 3 and runtime.rage == 0,
        'Berserk triggered without native rage sequence 10,20,30')
      successfulHits = successfulHits + 1
      g_game.cancelAttack()
      measure(finish)
      return
    end
    local rage = runtime.rage or 0
    if rage ~= previousRage then
      assert(rage == previousRage + 10 and rage < 40, 'Unexpected native rage increment')
      previousRage, successfulHits = rage, successfulHits + 1
      assert(successfulHits <= 3, 'Fourth hit did not activate configured Berserk')
      print('PASSIVES_CONFIG_NATIVE_HIT ' .. successfulHits .. ' rage=' .. rage)
      assertHud()
    end
    assert(g_clock.millis() < deadline, 'Configured four-hit Berserk did not activate')
    later(70, poll)
  end
  later(100, poll)
end

local function reaver()
  commands({'/passivetest stop', '/passiveqa equip reaver', '/passiveqa heal ' .. selfName,
    '/passivetest start reaver', '/passivetest preset ' .. selfName .. ',berserker',
    '/passivetest trace ' .. selfName .. ',on'}, function()
    assert(state().tree.id == 'reaver' and state().ranks.cap_berserker == 1, 'Reaver preset missing')
    assert(state().ranks.minor_vitality == 5 and state().ranks.major_guard == 0,
      'Fixture preset changed the expected derived HP calculation')
    assert(rankValue('minor_vitality', 5) == 10, 'Reaver catalog did not reflect +10% HP')
    assert(rankValue('minor_precision', 1) == .25, 'Catalog rounded configured 0.25 critical chance')
    assert(node('major_precision').description:match('16%s*seconds'),
      'Precision description did not reflect configured 16-second discount readiness')
    assert(player:getMaxHealth() == 808, 'Native did not apply 735 + floor(735 * 10%) HP')
    mod.setStatusVisible(true)
    wait('configured rage HUD', function() return state().runtime.rageMax == 40 end, function()
      assertHud()
      print('PASSIVES_CONFIG_CATALOG_OK reaver HP=808 Precision=0.25 readiness=16 rageMax=40')
      measure(function(m)
        assert(m.maxHP == 808 and m.runtime.rageMax == 40 and m.rage == 0 and m.procCount == 0,
          'Native pre-combat config/profile mismatch')
        commands({'/passiveqa arena', '/passiveqa join ' .. selfName .. ',1'}, function()
          -- Preserve the existing login/teleport pacification, as the natural campaign does.
          later(11000, combat)
        end)
      end)
    end)
  end)
end

local function setup()
  commands({'/passiveqa quiesce ' .. selfName, '/passivetest stop', '/passiveqa equip blademaster',
    '/passivetest start blademaster'}, function()
    assert(state().tree.id == 'blademaster', 'Isolation catalog missing')
    assert(rankValue('minor_vitality', 5) == 5, 'Reaver override leaked into Blademaster catalog')
    print('PASSIVES_CONFIG_ISOLATION_OK blademaster Vitality5=5%')
    reaver()
  end)
end

local function online()
  EnterGame.hide(); player = assert(g_game.getLocalPlayer())
  connect(g_game, {onTextMessage = function(_, text)
    print('PASSIVES_CONFIG_MESSAGE ' .. text)
    local payload = text:match('^PASSIVEQA_METRICS (.+)$')
    if payload then
      local ok, result = pcall(json.decode, payload)
      if ok then metrics, sequence = result, sequence + 1 end
    end
  end})
  wait('config handshake', function() return state().ready end, setup, 12000)
end

later(200, function()
  assert(LOCAL_PASSIVES_TEST and Services.updater == '' and g_resources.getLayout() == 'retro')
  mod = assert(modules.game_passives)
  mod.setStatusVisible(true)
  g_settings.set('window-maximized', false); g_window.resize({width = 1280, height = 800})
  connect(g_game, {
    onGameStart = function() later(250, online) end,
    onConnectionError = function(err) if not finishing then fail(err) end end
  })
  g_game.setClientVersion(860); g_game.setProtocolVersion(860); g_game.setRsa(OTSERV_RSA)
  G.account, G.password = 'passivetest', 'passivetest'
  login = ProtocolLogin.create(); _G.passivesConfigLogin = login
  login.onLoginError = function(_, err) fail(err) end
  login.onCharacterList = function(_, characters)
    for _, character in ipairs(characters) do
      if character.name == selfName then
        g_game.loginWorld(G.account, G.password, character.worldName, character.worldIp,
          character.worldPort, character.name, '', '')
        return
      end
    end
    fail('Config fixture character missing')
  end
  login:login('127.0.0.1', 7174, G.account, G.password, '', false)
end)
scheduleEvent(function() if not done then fail('120-second config probe timeout') end end, 120000)
