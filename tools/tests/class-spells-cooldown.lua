-- Actual shared-exhaustion replay after rebuilding the learned-spell UI.
-- Ordinary local Starter Reaver GUID9006: chosen Reaver, empty ranks,
-- both starters and the existing Head Splitter already learned. No SQL here.
local mod, spells, login, metrics
local sequence, catalogSequence, cooldownSequence = 0, 0, 0
local done, failed, intentional = false, false, false
local lastCooldown
local function fail(reason)
  if failed or done then return end
  failed = true; print('CLASS_SPELLS_COOLDOWN_FAILED '..tostring(reason))
  if g_game.isOnline() then
    g_game.cancelAttack(); g_game.talk('/classspellqa cleanup'); g_game.safeLogout()
  else g_game.cancelLogin() end
  scheduleEvent(function() g_app.exit() end, 700)
end
local function later(ms, fn)
  scheduleEvent(function()
    if done or failed then return end
    local ok, reason = pcall(fn); if not ok then fail(reason) end
  end, ms)
end
local function wait(label, predicate, fn, timeout)
  local deadline = g_clock.millis() + (timeout or 8000)
  local function poll()
    if predicate() then fn(); return end
    assert(g_clock.millis() < deadline, label..' timeout'); later(50, poll)
  end
  later(60, poll)
end
local function qa(command, fn)
  local before = sequence; local label = command:match('^%S+')
  g_game.talk('/classspellqa '..command)
  wait('fixture '..command, function()
    return sequence > before and metrics.label == label
  end, function() fn(metrics) end)
end
local function catalog() return spells.getState().catalog end
local function groupDeadline() return spells.getState().shared.combat or 0 end
local function bothCards(enabled)
  assert(spells.show(), 'Class Spells window did not open')
  local c = assert(catalog(), 'Missing replayed catalog')
  assert(c.classId == 'reaver' and #c.spells == 2, 'Wrong replayed class')
  for _, entry in ipairs(c.spells) do
    assert(entry.kind == 'combat', 'Unexpected Reaver exhaustion group')
    local button = assert(spells.getCard(entry.id)):getChildById('cast')
    assert(button:isEnabled() == enabled, 'Incorrect shared button state: '..entry.id)
  end
end
local function finish()
  qa('cleanup', function(m)
    assert(#m.targets == 0, 'Cleanup retained owned dummy monsters')
    intentional = true; g_game.safeLogout()
    wait('final logout', function() return not g_game.isOnline() end, function()
      assert(not spells.getWindow() and not spells.getButton() and not catalog(),
        'Logout retained learned-spell UI')
      done = true; print('CLASS_SPELLS_COOLDOWN_OK'); g_app.exit()
    end)
  end)
end
local legacyCast
local function replay(label, original, castAt, duration, nextStep)
  later(math.max(1, castAt + 350 - g_clock.millis()), function()
    assert(groupDeadline() == original and original > g_clock.millis(),
      label..' original authoritative cooldown disappeared before reset')
    local beforeCatalog, beforeCooldown = catalogSequence, cooldownSequence
    local session = mod.getState().session
    spells.reset()
    assert(not catalog() and groupDeadline() == 0, 'UI reset did not clear cached cooldown')
    local protocol = assert(g_game.getProtocolGame())
    protocol:sendExtendedOpcode(103, json.encode({v=1, action='open', session=session}))
    wait(label..' catalog plus remaining exhaustion', function()
      return catalogSequence > beforeCatalog and cooldownSequence > beforeCooldown
        and catalog() ~= nil and groupDeadline() > g_clock.millis()
    end, function()
      assert(mod.getState().session == session, 'Open unexpectedly replaced permanent session')
      assert(lastCooldown and lastCooldown.id == '' and lastCooldown.kind == 'combat',
        label..' did not replay the actual existing-condition remaining time')
      local restored = groupDeadline()
      assert(math.abs(restored-original) <= 500,
        label..' restarted or shortened cooldown: original='..original..' replay='..restored)
      assert(restored-g_clock.millis() < duration-100,
        label..' replay appears to restart a full cooldown')
      bothCards(false)
      print('CLASS_SPELLS_COOLDOWN_REPLAY_OK '..label..' deltaMs='..(restored-original))
      g_app.doScreenshot('/class-spells-cooldown-'..label..'-reopened.png')
      wait(label..' real expiry', function()
        local now = g_clock.millis()
        local first = spells.getCard('cleaving_arc')
        local second = spells.getCard('rend')
        return groupDeadline() <= now and first and second
          and first:getChildById('cast'):isEnabled() and second:getChildById('cast'):isEnabled()
      end, function() bothCards(true); nextStep() end, duration+2500)
    end, 2000)
  end)
end
local function cast(words, id, mana, duration, label, nextStep)
  qa('focus', function()
    later(250, function()
      qa('state', function(before)
        assert(before.profile.mode == 'permanent' and before.profile.treeId == 'reaver'
          and before.profile.spent == 0, 'Expected ordinary permanent Reaver with no passive discounts')
        assert(before.mana >= mana, 'Fixture lacks mana for '..label)
        local castAt = g_clock.millis(); local eventBefore = cooldownSequence
        if id then assert(spells.cast(id), 'Starter UI rejected ready cast')
        else g_game.talk(words) end
        later(120, function()
          qa('stop', function(after)
            assert(before.mana-after.mana == mana,
              label..' did not pay its actual base cost '..mana..' (Head Splitter must be learned)')
            assert(cooldownSequence > eventBefore and groupDeadline() > g_clock.millis(),
              label..' did not publish actual shared exhaustion')
            assert(lastCooldown and lastCooldown.kind == 'combat'
              and lastCooldown.id == (id or ''), label..' has wrong original cooldown identity')
            local original = groupDeadline()
            assert(math.abs(original-castAt-duration) <= 500, label..' original exhaustion differs from expected duration')
            bothCards(false)
            print('CLASS_SPELLS_COOLDOWN_CAST_OK '..label..' mana='..(before.mana-after.mana))
            replay(label, original, castAt, duration, nextStep)
          end)
        end)
      end)
    end)
  end)
end
legacyCast = function() cast('exori sec', nil, 20, 4000, 'legacy-head-splitter', finish) end
local function begin()
  wait('permanent learned metadata', function()
    local s = mod.getState()
    return s.ready and s.active and s.mode == 'permanent' and s.tree and s.tree.id == 'reaver' and catalog()
  end, function()
    qa('setup', function(m)
      assert(#m.targets == 3 and m.learned['Cleaving Arc'] and m.learned.Rend,
        'Missing real starter entitlement or arena')
      mod.hide(); spells.show()
      local starter
      for _,entry in ipairs(catalog().spells)do if entry.id=='cleaving_arc'then starter=entry end end
      assert(starter and starter.mana==18 and starter.cooldown==4000,'Revised Cleaving Arc metadata missing')
      qa('learnlegacy',function()
        later(11000, function() cast(nil, starter.id, starter.mana, starter.cooldown, 'starter-cleaving-arc', legacyCast) end)
      end)
    end)
  end)
end
later(250, function()
  assert(LOCAL_PASSIVES_TEST and Services.updater == '' and g_resources.getLayout() == 'retro')
  mod = assert(modules.game_passives); spells = assert(mod.ClassSpells)
  g_settings.set('window-maximized', false); g_window.resize({width=1280,height=800})
  ProtocolGame.registerExtendedJSONOpcode(103, function(_, _, data)
    if data.action == 'class_spells' then catalogSequence = catalogSequence + 1 end
    if data.action == 'class_spell_cooldown' and data.kind == 'combat' then
      cooldownSequence = cooldownSequence + 1; lastCooldown = data
    end
  end)
  connect(g_game, {
    onTextMessage=function(_, message)
      print('CLASS_SPELLS_COOLDOWN_MESSAGE '..message)
      if message:find('CLASS_SPELL_QA_FAILED', 1, true) then fail(message); return end
      local raw = message:match('^CLASS_SPELL_QA (.+)$')
      if raw then metrics = json.decode(raw); sequence = sequence + 1 end
    end,
    onGameStart=function() EnterGame.hide(); later(300, begin) end,
    onLoginError=function(e) fail(e) end,
    onConnectionError=function(e) if not intentional then fail(e) end end,
  })
  g_game.setClientVersion(860); g_game.setProtocolVersion(860); g_game.setRsa(OTSERV_RSA)
  G.account, G.password = 'classreaver', 'classreaver'
  login = ProtocolLogin.create(); _G.classCooldownLogin = login
  login.onLoginError=function(_, e) fail(e) end
  login.onCharacterList=function(_, list)
    for _, entry in ipairs(list) do
      if entry.name == 'Starter Reaver' then
        g_game.loginWorld(G.account, G.password, entry.worldName, entry.worldIp, entry.worldPort, entry.name, '', '')
        return
      end
    end
    fail('Ordinary Starter Reaver fixture missing')
  end
  login:login('127.0.0.1',7174,G.account,G.password,'',false)
end)
scheduleEvent(function() if not done then fail('100-second cooldown replay timeout') end end, 100000)
