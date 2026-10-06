-- Genuine second client for the local native combat/ownership probes.
-- This client never starts an attack or fabricates a server event.
local account = PASSIVES_PEER_ACCOUNT or 'passivepeer'
local password = PASSIVES_PEER_PASSWORD or 'passivepeer'
local characterName = PASSIVES_PEER_CHARACTER or 'Passive Peer'
local began = g_clock.millis()
local failed, finishing, completed = false, false, false
local passives, loginProtocol

local function fail(reason)
  if failed or completed then return end
  failed = true
  print('PASSIVES_PEER_FAILED ' .. tostring(reason))
  if g_game.isOnline() then g_game.safeLogout() end
  scheduleEvent(function() g_app.exit() end, 700)
end

local function guarded(fn)
  if failed or completed then return end
  local ok, reason = pcall(fn)
  if not ok then fail(reason) end
end

local function later(delay, fn)
  return scheduleEvent(function() guarded(fn) end, delay)
end

local function awaitCondition(label, predicate, nextStep, timeout)
  local deadline = g_clock.millis() + (timeout or 12000)
  local function poll()
    if failed or completed then return end
    local ok, ready = pcall(predicate)
    if not ok then fail(label .. ': ' .. tostring(ready)); return end
    if ready then guarded(nextStep); return end
    if g_clock.millis() >= deadline then fail(label .. ': timeout'); return end
    later(100, poll)
  end
  poll()
end

local function state()
  return assert(passives.getState(), 'peer module state missing')
end

local function cleanup()
  assert(finishing, 'unexpected peer logout')
  assert(not g_game.isOnline(), 'peer remained online after logout')
  assert(not state().active and state().session == nil, 'peer overlay survived onGameEnd')
  assert(passives.getWindow() == nil and passives.getStatusWindow() == nil,
    'peer windows survived onGameEnd')
  completed = true
  print('PASSIVES_PEER_OK')
  scheduleEvent(function() g_app.exit() end, 600)
end

local function ready()
  local current = state()
  assert(current.active and current.ready and current.ranks.cap_bloodletting == 1,
    'peer Bloodletting overlay missing')
  assert(current.tree and current.tree.id == 'reaver' and #current.tree.nodes == 29,
    'peer did not receive the real node catalog')
  assert(passives.getWindow(), 'peer tree UI missing')
  passives.selectNode('cap_bloodletting')
  -- Allow the actual rendered UI to finish a frame before the ready signal.
  later(500, function()
    g_app.doScreenshot('/passives-peer-ready.png')
    print('PASSIVES_PEER_READY')
    -- Root's master client/server commands control the arena. This client only
    -- keeps its real connection alive for at least 165 seconds after readiness.
    later(165000, function()
      assert(g_game.isOnline(), 'peer disconnected during its observation window')
      print('PASSIVES_PEER_OBSERVATION_COMPLETE')
    end)
    later(180000, function()
      finishing = true
      g_game.safeLogout()
      later(7000, function() assert(completed, 'peer logout did not produce onGameEnd') end)
    end)
  end)
end

local function online()
  EnterGame.hide()
  connect(g_game,{onTextMessage=function(_,text) print('PASSIVES_PEER_MESSAGE '..text) end})
  assert(g_game.getLocalPlayer():getName() == characterName, 'wrong peer character')
  awaitCondition('peer capabilities handshake', function() return state().ready end, function()
    g_game.talk('/passiveqa quiesce '..characterName)
    later(600,function()
    g_game.talk('/passivetest start reaver')
    awaitCondition('peer overlay start', function() return state().active and state().tree end, function()
      local beforeRevision = state().revision
      g_game.talk('/passivetest preset ' .. characterName .. ', bloodletting')
      awaitCondition('peer Bloodletting preset', function()
        return state().revision > beforeRevision and state().ranks.cap_bloodletting == 1
      end, ready)
    end)
    end)
  end)
end

local function initialise()
  assert(LOCAL_PASSIVES_TEST == true and Services.updater == '', 'peer requires local profile without updater')
  assert(DEFAULT_SERVER_ENDPOINT == '127.0.0.1:7174:860', 'peer has wrong server endpoint')
  assert(g_resources.getLayout() == 'retro', 'peer must use classic retro layout')
  passives = assert(modules.game_passives, 'peer passive module missing')
  g_settings.set('window-maximized', false)
  g_window.resize({width=1280,height=800})
  connect(g_game, {
    onGameStart=function() later(250, online) end,
    onGameEnd=function() if not failed then later(100, cleanup) end end,
    onConnectionError=function(err)
      if not finishing then fail('peer connection error: ' .. tostring(err)) end
    end,
  })
  EnterGame.hide()
  g_game.setClientVersion(860)
  g_game.setProtocolVersion(860)
  g_game.setRsa(OTSERV_RSA)
  G.account, G.password = account, password
  loginProtocol = ProtocolLogin.create()
  _G.passivesPeerLogin = loginProtocol
  loginProtocol.onLoginError=function(_, err) fail('peer login failed: ' .. tostring(err)) end
  loginProtocol.onCharacterList=function(_, characters)
    guarded(function()
      local selected
      for _, character in ipairs(characters) do
        if character.name == characterName then selected = character; break end
      end
      assert(selected, 'peer fixture character missing: ' .. characterName)
      g_game.loginWorld(account,password,selected.worldName,selected.worldIp,
        selected.worldPort,selected.name,'','')
    end)
  end
  loginProtocol:login('127.0.0.1',7174,account,password,'',false)
end

local function waitModules()
  if g_clock.millis() - began > 20000 then fail('peer module startup timeout'); return end
  local gameModule = g_modules.getModule('game_interface')
  local passiveModule = g_modules.getModule('game_passives')
  if not gameModule or not gameModule:isLoaded() or not passiveModule or not passiveModule:isLoaded() then
    later(100, waitModules); return
  end
  initialise()
end

later(100, waitModules)
scheduleEvent(function()
  if not completed and not failed then fail('peer absolute timeout') end
end, 225000)
