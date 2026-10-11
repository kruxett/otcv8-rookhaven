-- Genuine ordinary GUID9002 connection. Lifecycle controls are server text;
-- no manufactured damage, inventory packets, protocol events, or privilege changes.
local account = LEGENDARY_NATIVE_PEER_ACCOUNT or 'passivepeer'
local password = LEGENDARY_NATIVE_PEER_PASSWORD or account
local done, failed, intentional = false, false, false
local login, mode, deathObserved, acknowledged = nil, nil, false, false
local logins, logoutCycles, deathCycles = 0, 0, 0
local observedItems = {}
local forgeRows, forgeActive, originalOpcodeHandler = {}, false, nil
local forgeDonorCaptured = false
local function fail(reason)
  if done or failed then return end
  failed = true
  print('LEGENDARY_WEAPONS_PEER_FAILED ' .. tostring(reason))
  if g_game.isOnline() then g_game.cancelAttack(); g_game.safeLogout() else g_game.cancelLogin() end
  scheduleEvent(function() g_app.exit() end, 700)
end
local function guarded(fn)
  if done or failed then return end
  local ok, reason = pcall(fn); if not ok then fail(reason) end
end
local function later(ms, fn) scheduleEvent(function() guarded(fn) end, ms) end
local function wait(label, predicate, nextStep, timeout)
  local deadline = g_clock.millis() + (timeout or 15000)
  local function poll()
    if predicate() then nextStep(); return end
    assert(g_clock.millis() < deadline, label .. ' timeout'); later(80, poll)
  end
  later(80, poll)
end
local function announce()
  if acknowledged then return end
  if g_game.isOnline() then
    g_game.talkPrivate(MessageModes.PrivateTo, 'Passive Tester', 'LEGENDARY_NATIVE_PEER_READY')
  end
  later(1500, announce)
end
local function loginPeer()
  G.account, G.password = account, password
  -- A fresh XTEA/login protocol is necessary for every real reconnect.
  login = ProtocolLogin.create(); _G.legendaryNativePeerLogin = login
  login.onLoginError = function(_, e) fail(e) end
  login.onCharacterList = function(_, list) guarded(function()
    for _, c in ipairs(list) do if c.name == 'Passive Peer' then
      assert(c.worldIp == '127.0.0.1' and c.worldPort == 7175, 'Non-loopback peer game world')
      g_game.loginWorld(account, password, c.worldName, c.worldIp, c.worldPort, c.name, '', '')
      return
    end end
    error('Disposable ordinary peer character absent')
  end) end
  login:login('127.0.0.1', 7174, account, password, '', false)
end
local function click(widget)
  assert(widget and widget:isVisible(), 'Production forge control is not visible')
  signalcall(widget.onClick, widget)
end
local function forgeReceipt(action, after)
  for i = #forgeRows, (after or 0) + 1, -1 do
    if forgeRows[i].action == action then return forgeRows[i] end
  end
end
local function actualThing(position, clientId)
  if position.x == 65535 then
    local item = g_game.getLocalPlayer():getInventoryItem(position.y)
    if item and item:getId() == clientId then return item end
    return nil
  end
  local tile = g_map.getTile(position)
  if tile then
    for _, item in ipairs(tile:getItems()) do if item:getId() == clientId then return item end end
  end
end
local function containerItem(clientId)
  for _, container in pairs(g_game.getContainers()) do
    for index, item in ipairs(container:getItems()) do
      if item:getId() == clientId then
        return item, container, container.itemsPanel and container.itemsPanel:getChildById('item' .. (index - 1))
      end
    end
  end
end
local function findBox(title)
  for _, child in ipairs(g_ui.getRootWidget():getChildren()) do
    if child:isVisible() and child:getText() == title then return child end
  end
end
local function restoreForgeObserver()
  if originalOpcodeHandler then
    ProtocolGame.onExtendedOpcode = originalOpcodeHandler
    originalOpcodeHandler = nil
  end
  forgeActive = false
end
local function captureEquipped(nextStep)
  local inventory = assert(modules.game_inventory)
  inventory.inventoryWindow:open()
  local parent = assert(inventory.inventoryPanel:getChildById('slot' .. InventorySlotLeft))
  wait('actual visible equipped output cosmetic', function()
    return parent:isVisible() and parent:getChildById('legendaryInventoryOverlay')
  end, function()
    local overlay = parent:getChildById('legendaryInventoryOverlay')
    local first = overlay:getImageClip().x
    assert(overlay:isPhantom() and parent.onDragEnter and parent.onDrop,
      'Actual cosmetic changed native inventory input')
    g_window.resize({width=1280,height=800})
    later(350, function()
      g_app.doScreenshot('/legendary-connected-inventory-1280x800.png')
      wait('actual connected 500ms cosmetic timer', function()
        return overlay:getImageClip().x ~= first
      end, function()
        later(200, function()
          g_window.resize({width=800,height=640})
          later(350, function()
            assert(parent:isVisible(), 'Actual native inventory disappeared at 800x640')
            g_app.doScreenshot('/legendary-connected-inventory-800x640.png')
            later(200, function()
              g_window.resize({width=1280,height=800})
              print('LEGENDARY_WEAPONS_PEER_INVENTORY_OK actualOnline=true timerAdvanced=true sizes=1280x800,800x640')
              nextStep()
            end)
          end)
        end)
      end, 1800)
    end)
  end)
end
local function runForge(control)
  assert(not forgeActive and mode == nil, 'Overlapping production forge/lifecycle test')
  assert(control.recipeKey == 'deepwarden' and control.outputClientId == 11868,
    'Unexpected production forge fixture design')
  assert(type(control.forgePos) == 'table' and type(control.bagPos) == 'table',
    'Production forge/supply bag positions missing')
  forgeActive = true; forgeRows = {}; forgeDonorCaptured = false
  originalOpcodeHandler = ProtocolGame.onExtendedOpcode
  ProtocolGame.onExtendedOpcode = function(protocol, opcode, buffer)
    -- Production module retains its existing registration and receives the
    -- original bytes. This disposable observer only records real server replies.
    originalOpcodeHandler(protocol, opcode, buffer)
    if forgeActive and opcode == 98 and protocol == g_game.getProtocolGame() then
      guarded(function()
        local row = json.decode(buffer)
        forgeRows[#forgeRows + 1] = row
        print('LEGENDARY_WEAPONS_PEER_FORGE_REPLY ' .. json.encode(row))
      end)
    end
  end
  wait('actual physical QA supply bag', function()
    return actualThing(control.bagPos, control.bagClientId)
  end, function()
    g_game.open(assert(actualThing(control.bagPos, control.bagClientId)))
    wait('actual Epic donor container packet', function()
      local item, _, widget = containerItem(control.donorClientId)
      return item and widget
    end, function()
      assert(not containerItem(control.outputClientId), 'A fixture output existed before crafting')
      wait('server capture of actual native donor container', function() return forgeDonorCaptured end, function()
      wait('actual AID50053 forge tile', function()
        return actualThing(control.forgePos, control.forgeClientId)
      end, function()
        local before = #forgeRows
        g_game.use(assert(actualThing(control.forgePos, control.forgeClientId)))
        wait('production forge open reply', function() return forgeReceipt('open', before) end, function()
          local window = assert(g_ui.getRootWidget():recursiveGetChildById('lavaSmeltWindow'))
          local snapshotBefore = #forgeRows
          click(window:recursiveGetChildById('forgottenTab'))
          wait('production discovered catalog', function()
            return forgeReceipt('forgotten_snapshot', snapshotBefore)
          end, function()
            local snapshot = assert(forgeReceipt('forgotten_snapshot', snapshotBefore))
            assert(snapshot.success and snapshot.unlocked, 'Ordinary prepared character cannot access its forge')
            local selected
            for _, row in ipairs(window:recursiveGetChildById('forgottenRecipes'):getChildren()) do
              if row.recipeKey == control.recipeKey then selected = row; break end
            end
            assert(selected, 'Discovered Deepwarden missing from actual production catalog')
            click(selected)
            local item, _, sourceWidget = containerItem(control.donorClientId)
            assert(item and sourceWidget and item:getPosition().x == 65535,
              'Epic donor has no native client container address')
            local previewBefore = #forgeRows
            local drop = assert(window:recursiveGetChildById('forgottenDonor'))
            assert(drop.onDrop(drop, sourceWidget) == true, 'Production donor drop rejected the real matching CID')
            wait('production craftable donor preview', function()
              local receipt = forgeReceipt('forgotten_preview', previewBefore)
              return receipt and receipt.canCraft == true and receipt.donor
            end, function()
              local preview = forgeReceipt('forgotten_preview', previewBefore)
              assert(preview.donor.valid and #preview.donor.affixes >= 1 and #preview.donor.affixes <= 2,
                'Production Epic donor lost its displayed affixes')
              assert(preview.resultStats and preview.resultStats.level==35 and preview.resultStats.hands==1 and preview.resultStats.attack>=25 and type(preview.resultStats.summary)=='string' and #preview.resultStats.inheritedAffixes>=1,'Authoritative resulting weapon stats missing')
              print('LEGENDARY_FORGE_AUTHORITATIVE_PREVIEW '..json.encode(preview))
              g_app.doScreenshot('/legendary-forge-authoritative-preview-1280x800.png')
              local quoteBefore = #forgeRows
              click(window:recursiveGetChildById('forgottenCraftButton'))
              wait('real one-use production quote', function()
                return forgeReceipt('forgotten_quote', quoteBefore)
              end, function()
                local quote = forgeReceipt('forgotten_quote', quoteBefore)
                assert(quote.success and type(quote.token) == 'string' and #quote.token > 0,
                  'Production forge refused to quote the prepared donor')
                local box = assert(findBox('Confirm Forgotten Work'))
                local confirm
                for _, button in ipairs(box:getChildById('buttonHolder'):getChildren()) do
                  if button:getText() == 'Forge' then confirm = button; break end
                end
                local resultBefore = #forgeRows
                click(assert(confirm))
                wait('actual paid production craft', function()
                  return forgeReceipt('forgotten_result', resultBefore)
                end, function()
                  local result = forgeReceipt('forgotten_result', resultBefore)
                  assert(result.success and result.clientId == control.outputClientId,
                    'Production forge did not create the expected Legendary')
                  wait('native crafted output container update', function()
                    return containerItem(control.outputClientId)
                  end, function()
                    local replayBefore = #forgeRows
                    assert(g_game.getProtocolGame()):sendExtendedOpcode(98,
                      json.encode({action='forgotten_confirm',token=quote.token,clientSession=result.clientSession,requestId=(function()local id=0;for _,receipt in ipairs(forgeRows)do id=math.max(id,receipt.requestId or 0)end;return id+1 end)()}))
                    wait('production quote replay rejection', function()
                      return forgeReceipt('forgotten_result', replayBefore)
                    end, function()
                      assert(forgeReceipt('forgotten_result', replayBefore).success == false and forgeReceipt('forgotten_result', replayBefore).message:find('expired',1,true),
                        'Production forge accepted the already consumed token')
                      local output = assert(containerItem(control.outputClientId))
                      g_game.move(output, {x=65535,y=InventorySlotLeft,z=0}, 1)
                      wait('native manually equipped crafted Legendary', function()
                        local held = g_game.getLocalPlayer():getInventoryItem(InventorySlotLeft)
                        return held and held:getId() == control.outputClientId
                      end, function()
                        assert(not containerItem(control.donorClientId), 'Epic donor survived the real craft')
                        modules.game_lava_smelt.close()
                        restoreForgeObserver()
                        captureEquipped(function()
                        print('LEGENDARY_WEAPONS_PEER_FORGE_OK realProductionOpcode=true replayRejected=true manuallyEquipped=true')
                        g_game.talkPrivate(MessageModes.PrivateTo, 'Passive Tester', 'LEGENDARY_NATIVE_PEER_FORGED')
                        end)
                      end)
                    end)
                  end)
                end)
              end)
            end)
          end)
        end)
      end)
      end)
    end)
  end)
end
local function observeDeath(source)
  assert(mode == 'death', 'Unexpected subject death')
  if deathObserved then return end
  deathObserved = true
  print('LEGENDARY_WEAPONS_PEER_DEATH_OBSERVED ' .. source)
  intentional = true
  later(30, function() if g_game.isOnline() then g_game.safeLogout() end end)
end
local function disconnected()
  assert(intentional, 'Unexpected ordinary subject disconnect')
  local inventory = modules.game_inventory
  if inventory and inventory.inventoryPanel then
    for _, slot in ipairs({InventorySlotLeft, InventorySlotRight}) do
      assert(not inventory.inventoryPanel:getChildById('slot' .. slot):getChildById('legendaryInventoryOverlay'),
        'Inventory cosmetic survived actual logout')
    end
  end
  if mode == 'finish' then
    assert(logoutCycles == 1 and deathCycles == 1 and logins == 3, 'Both real lifecycle cycles were not completed')
    local count = 0; for _ in pairs(observedItems) do count = count + 1 end
    if LEGENDARY_NATIVE_FOLLOWUP then
      for _,id in ipairs({11868,11869,11870,11876,11877})do
        assert(observedItems[id], 'Follow-up server did not send expected native inventory ID '..id)
      end
      assert(count==5,'Unexpected follow-up native item scope')
    else assert(count == 10, 'Server did not send all ten Legendary native inventory IDs')end
    done = true
    print('LEGENDARY_WEAPONS_PEER_OK ' .. json.encode({actualConnections=logins,
      nativeDeath=deathObserved, safeLogout=true, nativeClientItems=count, cosmeticCleanup=true,
      followupScope=LEGENDARY_NATIVE_FOLLOWUP or false}))
    scheduleEvent(function() g_app.exit() end, 400)
  else
    assert(mode == 'logout' or (mode == 'death' and deathObserved), 'Unarmed lifecycle reconnect')
    later(1100, loginPeer)
  end
end
local function inventoryChanged(player, slot, item)
  if player ~= g_game.getLocalPlayer() or slot ~= InventorySlotLeft or not item then return end
  local id = item:getId()
  if id < 11868 or id > 11877 then return end
  observedItems[id] = true
  later(50, function()
    local current = g_game.getLocalPlayer()
    local held = current and current:getInventoryItem(slot)
    if not held or held:getId() ~= id then return end -- A quick server swap already superseded this item.
    local inventory = assert(modules.game_inventory)
    local parent = assert(inventory.inventoryPanel:getChildById('slot' .. slot))
    local overlay = assert(parent:getChildById('legendaryInventoryOverlay'), 'Real equipped Legendary has no cosmetic')
    assert(overlay:isPhantom() and not overlay:isFocusable() and overlay:getSize().width == 32,
      'Cosmetic intercepts native inventory input or uses wrong native size')
    assert(parent:getItem():getId() == id and parent.onDragEnter and parent.onDrop,
      'Native inventory item/drop handler changed')
  end)
end
later(300, function()
  assert(LOCAL_PASSIVES_TEST == true and Services.updater == '' and
    DEFAULT_SERVER_ENDPOINT == '127.0.0.1:7174:860' and g_resources.getLayout() == 'retro',
    'Requires isolated loopback retro peer profile')
  g_game.setClientVersion(860); g_game.setProtocolVersion(860); g_game.setRsa(OTSERV_RSA)
  connect(LocalPlayer, {onInventoryChange=function(player, slot, item)
    guarded(function() inventoryChanged(player, slot, item) end)
  end})
  connect(g_game, {
    onGameStart = function() guarded(function()
      assert(g_game.getLocalPlayer():getName() == 'Passive Peer', 'Wrong ordinary subject identity')
      EnterGame.hide(); intentional = false; logins = logins + 1
      if mode == 'logout' then logoutCycles = logoutCycles + 1; mode = nil
      elseif mode == 'death' then assert(deathObserved); deathCycles = deathCycles + 1; mode = nil end
      print('LEGENDARY_WEAPONS_PEER_CONNECTED ' .. logins)
      if logins == 1 then announce() end
    end) end,
    onGameEnd = function() guarded(disconnected) end,
    onDeath = function() guarded(function() observeDeath('native-onDeath') end) end,
    onTextMessage = function(_, text) guarded(function()
      if text == 'You are dead.' then observeDeath('native-server-death-text'); return end
      local raw = text:match('^LEGENDARY_NATIVE_PEER_QA (.+)$')
      if not raw then return end
      local row = json.decode(raw); print(text)
      if row.label == 'logout_ready' then
        assert(mode == nil and logoutCycles == 0, 'Repeated or overlapping logout request')
        mode = 'logout'; intentional = true
        later(60, function() g_game.safeLogout() end)
      elseif row.label == 'death_ready' then
        assert(mode == nil and deathCycles == 0, 'Repeated or overlapping native death request')
        mode = 'death'; deathObserved = false
      elseif row.label == 'forge_ready' then
        runForge(row)
      elseif row.label == 'forge_donor' then
        assert(forgeActive and row.actualNativeContainer and row.subjectGuid == 9002 and
          row.donor.pos.x == 65535 and row.donor.pos.y >= 64,
          'Server did not capture the actual opened donor container')
        forgeDonorCaptured = true
      elseif row.label == 'death_observed' then
        -- This is emitted by the actual native Lua onDeath callback at HP=0.
        -- The no-skill-loss fixture respawns without a client death window.
        assert(row.actualNativeHP == 0 and row.cooldownMs > 0,
          'Server death receipt lacks actual native zero HP and shared cooldown')
        observeDeath('native-server-onDeath-receipt')
      elseif row.label == 'cleanup' then
        assert(mode == nil, 'Cleanup overlapped a lifecycle cycle')
        mode = 'finish'; intentional = true
        g_game.talkPrivate(MessageModes.PrivateTo, 'Passive Tester', 'LEGENDARY_NATIVE_PEER_CLEAN')
        later(250, function() g_game.safeLogout() end)
      end
    end) end,
    onTalk = function(name, _, modeValue, text)
      if name == 'Passive Tester' and (modeValue == MessageModes.PrivateFrom or
        modeValue == MessageModes.GamemasterPrivateFrom) and
        text == 'LEGENDARY_NATIVE_CONTROLLER_READY' then acknowledged = true end
    end,
    onConnectionError = function(e) if not intentional then fail(e) end end,
    onLoginError = function(e) fail(e) end,
  })
  loginPeer()
end)
scheduleEvent(function() if not done then fail('500-second ordinary peer timeout') end end, 500000)
