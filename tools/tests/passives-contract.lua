-- Real-client contract probe. Inject this file as test.lua into a disposable
-- LocalPassives probe package; do not run it against a public game server.
-- No mocked updater, synthetic server messages or forced combat events.
-- Requires the local normal-combat admin fixture (account passivetest).
local account = PASSIVES_CONTRACT_ACCOUNT or 'passivetest'
local password = PASSIVES_CONTRACT_PASSWORD or 'passivetest'
local characterName = PASSIVES_CONTRACT_CHARACTER or 'Passive Tester'
local opcode = 103
local startedAt = g_clock.millis()
local failed, finishing, completed, observedRegistered = false, false, false, false
local results, catalogs, snapshots = {}, 0, 0
local passives, playerName, originalLevel, originalSession
local loginProtocol

local function fail(reason)
  if failed or completed then return end
  failed = true
  print('PASSIVES_CONTRACT_FAILED ' .. tostring(reason))
  if g_game.isOnline() then g_game.safeLogout() end
  scheduleEvent(function() g_app.exit() end, 600)
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
  local deadline = g_clock.millis() + (timeout or 7000)
  local function poll()
    if failed or completed then return end
    local ok, ready = pcall(predicate)
    if not ok then fail(label .. ': ' .. tostring(ready)); return end
    if ready then guarded(nextStep); return end
    if g_clock.millis() >= deadline then fail(label .. ': timeout'); return end
    later(50, poll)
  end
  poll()
end

local function copy(ranks)
  local out = {}
  for id, rank in pairs(ranks or {}) do out[id] = rank end
  return out
end

local function count(values)
  local total = 0
  for _ in pairs(values or {}) do total = total + 1 end
  return total
end

local function spent(ranks)
  local total = 0
  for _, rank in pairs(ranks or {}) do total = total + rank end
  return total
end

local function sameRanks(a, b)
  for id, rank in pairs(a or {}) do if rank ~= (b[id] or 0) then return false end end
  for id, rank in pairs(b or {}) do if rank ~= (a[id] or 0) then return false end end
  return true
end

local function shoot(path, nextStep)
  later(250, function()
    g_app.doScreenshot('/' .. path .. '.png')
    later(250, nextStep)
  end)
end

local function raw(payload)
  assert(g_game.isOnline(), 'raw request requires live game connection')
  payload.v = 1
  local protocol = assert(g_game.getProtocolGame())
  protocol:sendExtendedOpcode(opcode, json.encode(payload))
end

local function state()
  return assert(passives.getState(), 'module state missing')
end

local function assertStable(expectedRevision, ranks)
  local current = state()
  assert(current.active and current.session == originalSession, 'test session changed unexpectedly')
  assert(current.revision == expectedRevision, 'rejected request changed revision')
  assert(sameRanks(current.ranks, ranks), 'rejected request changed applied ranks')
  assert(g_game.getLocalPlayer():getLevel() == originalLevel, 'tree changed level/progression')
end

local function rejectProbe(id, ranks, revision, expectedText, nextStep)
  local savedRevision, savedRanks = state().revision, copy(state().ranks)
  local beforeSnapshots = snapshots
  raw({action='apply', session=originalSession, revision=revision,
    requestId=id, ranks=ranks})
  awaitCondition(id, function()
    return results[id] ~= nil and snapshots > beforeSnapshots
  end, function()
    local reply = results[id]
    assert(reply.ok == false, id .. ': server accepted invalid request')
    assert(type(reply.error) == 'string' and reply.error:find(expectedText, 1, true),
      id .. ': wrong rejection: ' .. tostring(reply.error))
    assertStable(savedRevision, savedRanks)
    print('PASSIVES_REJECT_OK ' .. id .. ' ' .. reply.error)
    nextStep()
  end)
end

local function checkCleanup()
  assert(finishing, 'unexpected onGameEnd')
  assert(not g_game.isOnline(), 'game still online after logout')
  local ended = state()
  assert(not ended.active and ended.session == nil and ended.tree == nil, 'onGameEnd retained test session')
  assert(count(ended.ranks) == 0 and count(ended.draft) == 0 and count(ended.nodes) == 0,
    'onGameEnd retained nodes/ranks/draft')
  assert(passives.getWindow() == nil, 'onGameEnd retained tree window')
  assert(passives.getStatusWindow() == nil, 'onGameEnd retained runtime window')
  if observedRegistered then
    ProtocolGame.unregisterExtendedJSONOpcode(opcode)
    observedRegistered = false
  end
  completed = true
  print('PASSIVES_CONTRACT_OK')
  scheduleEvent(function() g_app.exit() end, 600)
end

local function finish()
  assert(g_game.getLocalPlayer():getLevel() == originalLevel, 'unexpected level change')
  finishing = true
  g_game.safeLogout()
  -- Success is emitted only by actual onGameEnd after the module cleanup.
  later(7000, function() assert(completed, 'safeLogout did not produce onGameEnd') end)
end

local function reopen()
  local window = assert(passives.getWindow())
  local closeButton = assert(window:recursiveGetChildById('closeButton'))
  signalcall(closeButton.onClick, closeButton)
  assert(not window:isVisible(), 'Close did not hide the tree')
  g_game.talk('/passivetest open ' .. playerName)
  awaitCondition('server open command', function()
    return passives.getWindow() and passives.getWindow():isVisible()
  end, function()
    assert(spent(state().ranks) == 0, 'reopen changed reset ranks')
    print('PASSIVES_REOPEN_OK')
    local beforeRevision, beforeSession=state().revision,state().session
    g_game.talk('/passivetest stop Definitely Missing Passive Player')
    later(500,function()
      assert(state().active and state().session==beforeSession and state().revision==beforeRevision,'missing target command affected the administrator')
      print('PASSIVES_MISSING_TARGET_OK')
      shoot('passives-contract-08-reopened', finish)
    end)
  end)
end

local function resetFromDialog()
  local beforeRevision = state().revision
  local resetButton = assert(passives.getWindow():recursiveGetChildById('resetButton'))
  signalcall(resetButton.onClick, resetButton)
  local box
  for _, child in ipairs(g_ui.getRootWidget():getChildren()) do
    if child:getText() == 'Reset test tree' then box = child; break end
  end
  assert(box, 'Reset confirmation dialog missing')
  local holder = assert(box:getChildById('buttonHolder'))
  local confirm
  for _, button in ipairs(holder:getChildren()) do
    if button:getText() == 'Reset' then confirm = button; break end
  end
  assert(confirm, 'Reset confirmation button missing')
  shoot('passives-contract-06-reset-confirm', function()
    signalcall(confirm.onClick, confirm)
    awaitCondition('confirmed reset', function()
      return state().revision > beforeRevision and not state().pending
    end, function()
      assert(spent(state().ranks) == 0 and spent(state().draft) == 0, 'reset retained allocated ranks')
      assert(state().points == 24, 'reset changed test point budget')
      print('PASSIVES_RESET_OK')
      shoot('passives-contract-07-reset', reopen)
    end)
  end)
end

local function preset()
  local beforeRevision = state().revision
  g_game.talk('/passivetest preset ' .. playerName .. ', bloodletting')
  awaitCondition('real server preset', function()
    return state().revision > beforeRevision and (state().ranks.cap_bloodletting or 0) == 1
  end, function()
    assert((state().ranks.cap_berserker or 0) == 0, 'preset retained old capstone')
    assert(spent(state().ranks) == 16, 'preset must use the level40 first-capstone budget')
    assert(passives.selectNode('cap_bloodletting'))
    print('PASSIVES_PRESET_OK')
    shoot('passives-contract-05-bloodletting-preset', resetFromDialog)
  end)
end

local function invalidPrerequisite()
  rejectProbe('contract-missing-prerequisite', {major_guard=1}, state().revision,
    'Core major requires', preset)
end

local function invalidCapstones()
  local invalid = copy(state().ranks)
  invalid.cap_bloodletting = 1
  rejectProbe('contract-two-capstones', invalid, state().revision,
    'one capstone', function()
      shoot('passives-contract-04-rejected-two-caps', invalidPrerequisite)
    end)
end

local function staleRevision()
  rejectProbe('contract-stale-revision', copy(state().ranks), state().revision - 1,
    'Stale', invalidCapstones)
end

local function applyDraft()
  local beforeRevision = state().revision
  local desired = copy(state().draft)
  assert(passives.apply(), 'Apply refused a legal draft')
  awaitCondition('legal draft server apply', function()
    return state().revision > beforeRevision and not state().pending
  end, function()
    assert(sameRanks(state().ranks, desired), 'server applied different ranks')
    assert(spent(state().ranks) == 16 and state().ranks.cap_berserker == 1,
      'legal Berserker build not applied')
    assertStable(beforeRevision + 1, desired)
    print('PASSIVES_APPLY_OK')
    shoot('passives-contract-03-berserker-applied', staleRevision)
  end)
end

local function draft()
  local order = {
    {'minor_precision',4}, {'minor_power',5},
    {'major_precision',1}, {'major_pressure',2},
    {'mid_sweeping_form',2}, {'path_broad_stroke',1}, {'cap_berserker',1},
  }
  local savedRevision = state().revision
  for _, purchase in ipairs(order) do
    assert(passives.getNodeWidget(purchase[1]), 'node widget missing: ' .. purchase[1])
    for _=1,purchase[2] do
      assert(passives.changeRank(1, purchase[1]), 'legal rank rejected: ' .. purchase[1])
    end
  end
  assert(state().revision == savedRevision and spent(state().ranks) == 0, 'draft changed authoritative ranks')
  assert(spent(state().draft) == 16, 'wrong draft budget')
  local expected = copy(state().draft)
  assert(not passives.changeRank(-1, 'minor_precision'), 'dependent prerequisite removal should be rejected')
  assert(sameRanks(state().draft, expected), 'rejected removal damaged the draft')
  assert(passives.selectNode('cap_berserker'))
  print('PASSIVES_DRAFT_OK')
  local beforeSnapshots = snapshots
  g_game.talk('/passivetest open')
  awaitCondition('reopen while draft is unsaved', function() return snapshots > beforeSnapshots end, function()
    assert(sameRanks(state().draft, expected), 'same-revision reopen discarded unsaved points')
    assert(state().revision == savedRevision and spent(state().ranks) == 0, 'reopen applied draft points')
    print('PASSIVES_DRAFT_PRESERVED_OK')
    shoot('passives-contract-02-legal-draft', applyDraft)
  end)
end

local function catalog()
  local current = state()
  assert(current.active and current.ready and current.session and current.session ~= '', 'live handshake/session missing')
  assert(catalogs > 0 and snapshots > 0, 'catalog/snapshot were not received over opcode 103')
  assert(current.tree.id == 'reaver' and #current.tree.nodes == 29 and count(current.nodes) == 29,
    'server catalog does not contain 29 unique nodes')
  assert(current.points == 24 and spent(current.ranks) == 0, 'fresh overlay is not empty')
  local counts = {minor=0,major=0,capstone=0}
  for _, node in ipairs(current.tree.nodes) do
    counts[node.type] = counts[node.type] + 1
    assert(passives.getNodeWidget(node.id), 'catalog node not rendered: ' .. node.id)
  end
  assert(counts.minor == 14 and counts.major == 12 and counts.capstone == 3, 'node tier counts differ')
  assert(passives.getWindow():isVisible(), 'server open did not show the tree')
  originalSession = current.session
  print('PASSIVES_REAL_CATALOG_OK')
  shoot('passives-contract-01-empty-tree', draft)
end

local function online()
  playerName = assert(g_game.getLocalPlayer()):getName()
  originalLevel = g_game.getLocalPlayer():getLevel()
  EnterGame.hide()
  connect(g_game, {onTextMessage=function(_, text) print('PASSIVES_CONTRACT_MESSAGE '..text) end})
  awaitCondition('real server capabilities handshake', function() return state().ready end, function()
    print('PASSIVES_HANDSHAKE_OK')
    g_game.talk('/passivetest start reaver, ' .. playerName)
    awaitCondition('real catalog and open', function()
      return state().active and state().tree and passives.getWindow() and passives.getWindow():isVisible()
    end, catalog)
  end, 12000)
end

local function initialise()
  assert(LOCAL_PASSIVES_TEST == true, 'requires native --local-passives profile')
  assert(Services.updater == '', 'local profile contacted an updater')
  assert(DEFAULT_SERVER_ENDPOINT == '127.0.0.1:7174:860', 'wrong local server endpoint')
  assert(g_resources.getLayout() == 'retro', 'requires classic retro layout')
  passives = assert(modules.game_passives, 'game_passives module missing')
  assert(type(passives.getState) == 'function' and type(passives.changeRank) == 'function', 'inspection contract missing')
  g_settings.set('window-maximized', false)
  g_window.resize({width=1280,height=800})
  -- A second observer receives real decoded packets after the module's raw
  -- callback. The module remains registered and handles the actual messages.
  ProtocolGame.registerExtendedJSONOpcode(opcode, function(_, receivedOpcode, data)
    guarded(function()
      assert(receivedOpcode == opcode, 'opcode observer received wrong opcode')
      assert(type(data) == 'table', 'opcode observer received invalid decoded payload')
      if data.v ~= 1 then return end
      if data.action == 'catalog' or data.action == 'catalog_part' then catalogs = catalogs + 1 end
      if data.action == 'snapshot' then snapshots = snapshots + 1 end
      if data.action == 'result' and data.requestId then results[data.requestId] = data end
    end)
  end)
  observedRegistered = true
  connect(g_game, {
    onGameStart=function() later(250, online) end,
    onGameEnd=function()
      if failed then return end
      later(100, checkCleanup)
    end,
    onConnectionError=function(err) if not finishing then fail('connection error: ' .. tostring(err)) end end,
  })
  EnterGame.hide()
  g_game.setClientVersion(860)
  g_game.setProtocolVersion(860)
  g_game.setRsa(OTSERV_RSA)
  G.account, G.password = account, password
  loginProtocol = ProtocolLogin.create()
  _G.passivesContractLogin = loginProtocol
  loginProtocol.onLoginError=function(_, err) fail('login failed: ' .. tostring(err)) end
  loginProtocol.onCharacterList=function(_, characters)
    guarded(function()
      local selected
      for _, character in ipairs(characters) do
        if character.name == characterName then selected = character; break end
      end
      assert(selected, 'local fixture character missing: ' .. characterName)
      g_game.loginWorld(account, password, selected.worldName, selected.worldIp,
        selected.worldPort, selected.name, '', '')
    end)
  end
  loginProtocol:login('127.0.0.1',7174,account,password,'',false)
end

local function waitModules()
  if g_clock.millis() - startedAt > 20000 then fail('module startup timeout'); return end
  local gameModule = g_modules.getModule('game_interface')
  local passiveModule = g_modules.getModule('game_passives')
  if not gameModule or not gameModule:isLoaded() or not passiveModule or not passiveModule:isLoaded() then
    later(100, waitModules); return
  end
  initialise()
end

later(100, waitModules)
scheduleEvent(function() if not completed and not failed then fail('90 second contract timeout') end end, 90000)
