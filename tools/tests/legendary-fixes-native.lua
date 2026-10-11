-- Connected native combat integration, using only loopback disposable GUID9001/9002.
-- The runtime-only server fixture drives real paid engine weapon attacks. Its
-- fixed diagnostic hits are explicitly not evidence of ordinary autoattacks.
local account = LEGENDARY_NATIVE_ACCOUNT or 'passivetest'
local password = LEGENDARY_NATIVE_PASSWORD or account
local characterName = 'Passive Tester'
local peerName = 'Passive Peer'
local done, failed, finishing, fixtureStarted = false, false, false, false
local peerReady, peerDone, peerForged, login = false, false, false, nil
local rows, effects, pvpRows = {}, {}, {}
local signatures = {'Swordguard', 'Sweeping Edge', 'Ground Ember', 'Frontal Sweep',
  'Stone Mend', 'Stormcall', 'Windstride', 'Ricochet', 'Living Bark', 'Soul Draw'}

local function fail(reason)
  if done or failed then return end
  failed = true
  print('LEGENDARY_WEAPONS_NATIVE_FAILED ' .. tostring(reason))
  if g_game.isOnline() then
    g_game.cancelAttack()
    if fixtureStarted then g_game.talk('/legendarynative cleanup') end
    scheduleEvent(function() if g_game.isOnline() then g_game.safeLogout() end end, 500)
  else g_game.cancelLogin() end
  scheduleEvent(function() g_app.exit() end, 1300)
end
local function guarded(fn)
  if done or failed then return end
  local ok, reason = pcall(fn)
  if not ok then fail(reason) end
end
local function later(ms, fn) scheduleEvent(function() guarded(fn) end, ms) end
local function wait(label, predicate, nextStep, timeout)
  local deadline = g_clock.millis() + (timeout or 15000)
  local function poll()
    if predicate() then nextStep(); return end
    assert(g_clock.millis() < deadline, label .. ' timeout')
    later(60, poll)
  end
  later(60, poll)
end
local function latest(label, after)
  for i = #rows, (after or 0) + 1, -1 do if rows[i].label == label then return rows[i] end end
end
local function command(verb, label, nextStep, timeout)
  local after = #rows
  g_game.talk('/legendarynative ' .. verb)
  wait(verb, function() return latest(label, after) end, function()
    local receipt = latest(label, after)
    -- Receipts can be emitted just before the fixture coroutine clears running.
    later(300, function() nextStep(receipt, after) end)
  end, timeout)
end
local function validateEffect(row)
  assert(row.item >= 12831 and row.item <= 12840 and
    row.signature == signatures[row.item - 12830], 'Unknown signature/item receipt')
  assert(row.paid == true and row.nonrecursive == true, 'Weapon provenance or recursion failed')
  assert(row.actualHP + row.actualMS > 0 and row.raw > 0, 'No actual paid damage')
  assert(row.cooldownAfterSwap > 0, 'Weapon swap erased the shared cooldown')
  if row.expectedExtraHP ~= nil then
    assert(row.extraHP == row.expectedExtraHP, 'Exact proc damage budget differs')
  end
end
local function finish()
  command('cleanup', 'cleanup', function(row)
    assert(row.ownedItemsAndMonstersOnly == true, 'Owned fixture cleanup was not confirmed')
    fixtureStarted = false
    wait('ordinary peer clean logout', function() return peerDone end, function()
      finishing = true
      g_game.safeLogout()
      wait('controller clean logout', function() return not g_game.isOnline() end, function()
        done = true
        print('LEGENDARY_WEAPONS_NATIVE_OK ' .. json.encode({
          realServer = true, effects = LEGENDARY_NATIVE_FOLLOWUP and 0 or 10,
          lastRound = not LEGENDARY_NATIVE_FOLLOWUP, primaryPvP = #pvpRows,
          cooldownRelog = true, nativeDeath = true, characterGroupAuth = not LEGENDARY_NATIVE_FOLLOWUP,
          ownedCleanup = true, secondaryCritLeechSuppressed = true,
          productionForge = true, exactInheritedAffixes = true, quoteReplayRejected = true,
          sourcePermissions = true, wardPartialManaShield = true,
          priorCombatEvidence = LEGENDARY_NATIVE_FOLLOWUP and 'attempt4/controller.log: 10 effects, last bolt and auth' or nil,
          unmeasured = 'enemy-player secondary legality; natural lottery frequency'
        }))
        scheduleEvent(function() g_app.exit() end, 400)
      end)
    end)
  end)
end
local function deathTest()
  command('armdeath', 'death', function(row, after)
    local observed = assert(latest('death_observed', after), 'Missing actual native death observation')
    assert(observed.actualNativeHP == 0 and observed.cooldownMs > 0,
      'Fixture death observation did not include native zero HP')
    assert(row.actualNativeHP == 0 and row.respawnHP > 0 and row.cooldownMs > 0 and row.clearedTemporaryEffects,
      'Native death did not preserve only the shared cooldown')
    assert(row.measuredBeforeExpiry and math.abs(row.cooldownMs - row.expectedCooldown) < 500,
      'Death reconnect missed an unexpired persisted cooldown')
    later(350, finish)
  end, 30000)
end
local function logoutTest()
  command('armlogout', 'logout_ready', function(row, after)
    assert(row.cooldownMs > 0, 'Logout was armed without cooldown')
    wait('safe logout reconnect receipt', function() return latest('reconnect', after) end, function()
      local receipt = latest('reconnect', after)
      assert(receipt.measuredBeforeExpiry and receipt.cooldownMs > 0 and
        receipt.respawnHP > 0 and receipt.clearedTemporaryEffects and
        math.abs(receipt.cooldownMs - receipt.expectedCooldown) < 500,
        'Safe logout reconnect reset or outlasted the cooldown')
      later(350, deathTest)
    end, 30000)
  end, 30000)
end
local function forgeTest()
  command('forge prepare deepwarden', 'forge_ready', function(row)
    assert(row.productionPreparation and row.subjectGuid == 9002 and row.ordinaryGroup == 1 and
      row.recipeKey == 'deepwarden' and row.outputId == 12831 and row.outputClientId == 11868,
      'Production forge preparation did not target the ordinary native subject')
    wait('ordinary peer production craft and equip', function() return peerForged end, function()
      command('forge verify', 'forge_verified', function(verified)
        assert(verified.recipeKey == 'deepwarden' and verified.subjectGuid == 9002 and
          verified.outputId == 12831 and verified.outputClientId == 11868 and
          verified.actualNativeDonorConsumed and verified.actualNativeOutput and verified.manuallyEquipped,
          'Actual native forge donor/output/equip verification failed')
        assert(verified.twoExactInheritedRolls and verified.affixes.count == 2 and
          verified.fixedSignature == 'Swordguard', 'Craft changed the exact Epic rolls or fixed signature')
        assert(#verified.costs > 0 and #verified.cores == 4 and verified.craftCount >= 1,
          'Forge costs/core regions or single craft storage were not verified')
        for _, cost in ipairs(verified.costs) do
          assert(cost.consumed > 0 and cost.before - cost.after == cost.consumed,
            'Native forge material consumption differs')
        end
        assert(verified.goldConsumed > 0 and verified.goldBefore - verified.goldAfter == verified.goldConsumed,
          'Native forge gold consumption differs')
        for _, core in ipairs(verified.cores) do
          assert(core.consumed == 13500000 and core.before - core.after == core.consumed,
            'Native personal core consumption differs')
        end
        later(350, logoutTest)
      end)
    end, 45000)
  end)
end
local function modifierTest()
  command('modifiers', 'modifiers', function(row)
    assert(row.item == 12832 and row.raw > 0 and row.ordinaryHP == row.raw * 2,
      'Native ordinary critical damage was not measured')
    assert(row.expectedExtraHP == math.min(30, math.floor(row.raw * .5)) and
      row.extraHP == row.expectedExtraHP and row.critSuppressed,
      'Generated secondary inherited critical damage or used a post-critical budget')
    assert(row.expectedOrdinaryLeech == row.ordinaryHP and row.actualHeal == row.ordinaryHP and
      row.actualMana == row.ordinaryHP and row.leechSuppressed,
      'Generated secondary granted additional life or mana leech')
    assert(row.conditionHits == 1 and row.lotteries == 1 and row.eligible == 1 and
      row.nonrecursive and row.modifiersRestored,
      'Generated secondary recursively entered a paid action or retained test modifiers')
    forgeTest()
  end, 30000)
end
local function pvpTest()
  local after = #rows
  g_game.talk('/legendarynative pvp')
  wait('four paid primary PvP/HP/MS cases', function() return #pvpRows == 4 end, function()
    local expected = {{12831,false}, {12839,true}, {12840,true}, {12840,false}}
    for i, row in ipairs(pvpRows) do
      assert(row.item == expected[i][1] and row.fullManaShield == expected[i][2], 'Wrong PvP fixture order')
      assert(row.paidNativeAttack and row.actorRestored, 'PvP attack was unpaid or actor not restored')
      if row.fullManaShield then
        assert(row.ordinaryHP == 0 and row.ordinaryMS > 0 and row.actualHP == 0,
          'Full mana shield did not receive the actual native hit')
        assert(row.actualMS == row.ordinaryMS + row.expectedHalfProc and row.extraHP == 0,
          'Mana shield proc was not halved once')
        if row.item == 12840 then assert(row.healed == 0, 'MS-only Soul Draw healed') end
      else
        assert(row.ordinaryHP > 0 and row.actualHP == row.ordinaryHP + row.expectedHalfProc and
          row.extraHP == row.expectedHalfProc, 'Primary PvP HP proc budget differs')
      end
      if row.item == 12831 then assert(row.incomingHP == 12, 'Swordguard PvP cap differs') end
      if row.item == 12839 then assert(row.incomingHP == 7, 'Living Bark PvP cap differs') end
    end
    assert(latest('pvp', after), 'Missing server PvP receipt')
    later(400, modifierTest)
  end, 130000)
end
local function reviewPermissions()
 local cases={{'pz',1,true,false},{'disabled',4,false,false},{'ignore',5,true,true}}
 local function nextCase(index)
  if index>#cases then command('wardedges','ward_edges',function(row) assert(row.realPaidActivation and row.partialShieldHP==1 and row.expiry,'Ward edge cases incomplete');pvpTest()end,45000);return end
  local case=cases[index]
  command('reviewpz '..case[1],'review_pz',function(row)
   assert(row.realPaidProc and row.ordinaryGroup==case[2] and row.sourceInPZ==case[3] and row.targetOutsidePZ,'Native permission case wrong')
   assert(row.delayedHP==row.procHP,'Delayed receipt mismatch')
   if case[4]then assert(row.delayedHP>0,'IgnoreProtectionZone exception was lost')
   else assert(row.delayedHP==0,'Delayed Legendary damage bypassed source combat permissions')end
   print('LEGENDARY_SOURCE_PERMISSION_OK '..json.encode(row))
   nextCase(index+1)
  end,30000)
 end
 nextCase(1)
end
local function lastRound()
  command('lastammo', 'effect', function(row)
    validateEffect(row)
    assert(row.item == 12838 and row.lastAmmo == true, 'Last bolt provenance not confirmed')
    reviewPermissions()
  end, 30000)
end
local function runAll()
  if LEGENDARY_NATIVE_FOLLOWUP then reviewPermissions();return end
  command('all', 'all_complete', function(row, after)
    assert(row.effects == 10 and #effects == 10, 'Missing one of the ten native signature cases')
    local auth = assert(latest('auth', after), 'Missing actual native character group authorization test')
    assert(auth.group5NormalAccountAllowed and auth.group4AccessDenied and auth.ordinaryDenied,
      'Admin/God character-only authorization regressed')
    local seen = {}
    for _, effect in ipairs(effects) do
      validateEffect(effect)
      assert(not seen[effect.item] and not effect.lastAmmo, 'Repeated/misclassified base signature case')
      seen[effect.item] = true
    end
    lastRound()
  end, 240000)
end
local function online()
  assert(g_game.getLocalPlayer():getName() == characterName, 'Wrong controller identity')
  EnterGame.hide()
  wait('actual ordinary peer online', function() return peerReady end, function()
    g_game.talkPrivate(MessageModes.PrivateTo, peerName, 'LEGENDARY_NATIVE_CONTROLLER_READY')
    local after=#rows
    g_game.talk('/forgottennative '..peerName)
    wait('actual net inventory transactions',function()return latest('transaction_all_complete',after)end,function()
      local receipt=assert(latest('transaction_all_complete',after))
      assert(receipt.checks==7 and receipt.actualNativeInventory and receipt.capacityRestored and receipt.onlyOwnedFixtureItems,'Native transaction checks incomplete')
      command('setup ' .. peerName, 'setup', function(row)
        fixtureStarted = true
        assert(row.subjectGuid == 9002 and row.ordinaryGroup == 1 and row.account == 1 and
          row.level >= 35 and row.ranksSpent == 0, 'Ordinary fixture setup was not isolated')
        runAll()
      end)
    end,30000)
  end, 60000)
end
local function initialise()
  assert(LOCAL_PASSIVES_TEST == true and Services.updater == '' and
    DEFAULT_SERVER_ENDPOINT == '127.0.0.1:7174:860', 'Requires isolated loopback local profile')
  assert(g_resources.getLayout() == 'retro', 'Requires existing retro client')
  connect(g_game, {
    onGameStart = function() later(250, online) end,
    onGameEnd = function() if not finishing and not failed then fail('Unexpected controller logout') end end,
    onConnectionError = function(e) if not finishing then fail(e) end end,
    onLoginError = function(e) fail(e) end,
    onTalk = function(name, _, mode, text)
      if name ~= peerName or mode ~= MessageModes.PrivateFrom then return end
      if text == 'LEGENDARY_NATIVE_PEER_READY' then peerReady = true
      elseif text == 'LEGENDARY_NATIVE_PEER_FORGED' then peerForged = true
      elseif text == 'LEGENDARY_NATIVE_PEER_CLEAN' then peerDone = true end
    end,
    onTextMessage = function(_, text) guarded(function()
      local transaction=text:match('^FORGOTTEN_TRANSACTION_NATIVE (.+)$')
      local raw = transaction or text:match('^LEGENDARY_NATIVE_QA (.+)$')
      if not raw then return end
      local row = json.decode(raw)
      print(text)
      if row.label == 'FAILED' then error(row.error or 'Server fixture failure') end
      if transaction then row.label='transaction_'..row.label end
      rows[#rows + 1] = row
      if row.label == 'effect' then effects[#effects + 1] = row end
      if row.label == 'pvp' then pvpRows[#pvpRows + 1] = row end
    end) end,
  })
  g_game.setClientVersion(860); g_game.setProtocolVersion(860); g_game.setRsa(OTSERV_RSA)
  G.account, G.password = account, password
  login = ProtocolLogin.create(); _G.legendaryNativeLogin = login
  login.onLoginError = function(_, e) fail(e) end
  login.onCharacterList = function(_, list) guarded(function()
    for _, c in ipairs(list) do if c.name == characterName then
      assert(c.worldIp == '127.0.0.1' and c.worldPort == 7175, 'Non-loopback game world')
      g_game.loginWorld(account, password, c.worldName, c.worldIp, c.worldPort, c.name, '', '')
      return
    end end
    error('Disposable issuer character absent')
  end) end
  login:login('127.0.0.1', 7174, account, password, '', false)
end
later(300, initialise)
scheduleEvent(function() if not done then fail('500-second controller timeout') end end, 500000)
