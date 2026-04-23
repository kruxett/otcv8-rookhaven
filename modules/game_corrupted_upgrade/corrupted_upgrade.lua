local CORRUPTED_UPGRADE_OPCODE = 93
local DEBUG_DROP = false

local window = nil
local selectedPath = nil
local entryByPath = {}
local pathsByClientId = {}
local pathsByItemId = {}
local dragMonitorEvent = nil

local function protocolSend(payload)
  local protocol = g_game.getProtocolGame()
  if protocol then
    protocol:sendExtendedOpcode(CORRUPTED_UPGRADE_OPCODE, json.encode(payload))
  end
end

local function debugDrop(msg)
  if not DEBUG_DROP then
    return
  end

  local text = '[CorruptedUpgradeUI] ' .. tostring(msg)
  print(text)

  if g_logger and g_logger.info then
    g_logger.info(text)
  end

  if window then
    local debugLabel = window:getChildById('debugLabel')
    if debugLabel then
      debugLabel:setText('DBG: ' .. tostring(msg))
    end
  end
end

local function syncDebugUi()
  if not window then
    return
  end

  local debugButton = window:getChildById('debugButton')
  local debugLabel = window:getChildById('debugLabel')

  if debugButton then
    debugButton:setText(DEBUG_DROP and 'Debug ON' or 'Debug OFF')
  end

  if debugLabel then
    debugLabel:setText(DEBUG_DROP and 'DBG: waiting for drag event...' or 'Debug OFF')
  end
end

local function destroyWindow()
  if dragMonitorEvent then
    removeEvent(dragMonitorEvent)
    dragMonitorEvent = nil
  end

  if window then
    window:destroy()
    window = nil
    selectedPath = nil
    entryByPath = {}
    pathsByClientId = {}
    pathsByItemId = {}
  end
end

local function startDragMonitor(itemDropZone, resolveItemFromWidget, trySelectItem)
  if dragMonitorEvent then
    removeEvent(dragMonitorEvent)
    dragMonitorEvent = nil
  end

  local wasDragging = false
  local lastDraggedItem = nil

  local function tick()
    local ok, err = pcall(function()
      if not window or not itemDropZone then
        dragMonitorEvent = nil
        return
      end

      local draggingWidget = g_ui.getDraggingWidget and g_ui.getDraggingWidget() or nil
      local mousePos = g_window and g_window.getMousePosition and g_window.getMousePosition() or nil
      local overSlot = (mousePos and itemDropZone:containsPoint(mousePos)) and true or false

      if DEBUG_DROP and window then
        local debugLabel = window:getChildById('debugLabel')
        if debugLabel then
          local draggingClass = draggingWidget and draggingWidget:getClassName() or 'none'
          local lastId = lastDraggedItem and tostring(lastDraggedItem:getId()) or 'none'
          debugLabel:setText(string.format('DBG tick drag=%s overSlot=%s lastItem=%s', draggingClass, tostring(overSlot), lastId))
        end
      end

      if draggingWidget then
        local item = resolveItemFromWidget(draggingWidget)
        if item then
          lastDraggedItem = item
        end
        wasDragging = true
      elseif wasDragging then
        -- Drag just ended: if mouse is over our drop zone, accept via fallback.
        if lastDraggedItem and overSlot then
          debugDrop('drag monitor fallback: release over slot detected')
          trySelectItem(lastDraggedItem)
        end
        wasDragging = false
        lastDraggedItem = nil
      end
    end)

    if not ok then
      if DEBUG_DROP and window then
        local debugLabel = window:getChildById('debugLabel')
        if debugLabel then
          debugLabel:setText('DBG monitor error: ' .. tostring(err))
        end
      end
      print('[CorruptedUpgradeUI] drag monitor error: ' .. tostring(err))
    end

    if window then
      dragMonitorEvent = scheduleEvent(tick, 50)
    else
      dragMonitorEvent = nil
    end
  end

  dragMonitorEvent = scheduleEvent(tick, 50)
end

local function setStatus(text, color)
  if not window then
    return
  end

  local statusLabel = window:getChildById('statusLabel')
  if statusLabel then
    statusLabel:setText(text or '')
    if color then
      statusLabel:setColor(color)
    else
      statusLabel:setColor('#d6c9e8')
    end
  end
end

local function updatePreview(path)
  if not window then
    return
  end

  selectedPath = path
  local entry = entryByPath[path or '']
  if not entry then
    return
  end

  local itemPreview = window:getChildById('itemPreview')
  local itemNameLabel = window:getChildById('itemNameLabel')
  local itemTypeLabel = window:getChildById('itemTypeLabel')
  local bonusPreviewLabel = window:getChildById('bonusPreviewLabel')
  local selectedPathLabel = window:getChildById('selectedPathLabel')

  if itemPreview then
    itemPreview:setItemId(tonumber(entry.clientId) or 0)
  end

  if itemNameLabel then
    itemNameLabel:setText(entry.name or 'Unknown item')
  end

  if itemTypeLabel then
    local typeText = (entry.kind == 'weapon') and 'Weapon' or 'Armor'
    itemTypeLabel:setText('Type: ' .. typeText)
  end

  if bonusPreviewLabel then
    bonusPreviewLabel:setText('Upgrade: ' .. (entry.preview or '-'))
  end

  if selectedPathLabel then
    selectedPathLabel:setText('Selected: ' .. tostring(path or 'none'))
  end
end

local function setupDropSlot()
  if not window then
    return
  end

  local itemDropZone = window:getChildById('itemDropZone')
  local previewPanel = window:getChildById('previewPanel')
  local itemPreview = window:getChildById('itemPreview')
  if not itemDropZone or not itemPreview then
    return
  end

  syncDebugUi()
  debugDrop('setupDropSlot initialized')

  local function resolveItemFromWidget(w)
    if not w then
      return nil
    end

    if type(w.getItem) == 'function' then
      local ok, fromGetItem = pcall(function() return w:getItem() end)
      if ok and fromGetItem and fromGetItem.isItem and fromGetItem:isItem() then
        return fromGetItem
      end
    end

    local dragThing = w.currentDragThing
    if dragThing and dragThing.isItem and dragThing:isItem() then
      return dragThing
    end

    return nil
  end

  local function trySelectItem(item)
    if not item or not item.isItem or not item:isItem() then
      setStatus('Drop an inventory item here.', '#d26b6b')
      return false
    end

    local draggedId = tonumber(item:getId() or 0) or 0
    debugDrop('Trying dropped item id=' .. tostring(draggedId))

    local candidates = pathsByClientId[draggedId]
    if not candidates or #candidates == 0 then
      candidates = pathsByItemId[draggedId]
    end
    if not candidates or #candidates == 0 then
      setStatus('That item is not eligible for corrupted upgrade.', '#d26b6b')
      debugDrop('No candidates for id=' .. tostring(draggedId))
      return false
    end

    if #candidates > 1 then
      setStatus('Multiple matching items found. Using the first eligible one.', '#d6c9e8')
      debugDrop('Multiple candidates for id=' .. tostring(draggedId) .. ' count=' .. tostring(#candidates))
    else
      setStatus('Item selected. Press Upgrade to continue.', '#d6c9e8')
    end

    local chosenPath = candidates[1]
    local chosenEntry = entryByPath[chosenPath]
    if chosenEntry then
      itemPreview:setItemId(tonumber(chosenEntry.clientId) or draggedId)
      updatePreview(chosenPath)
      debugDrop('Selected path=' .. tostring(chosenPath))
      return true
    end

    setStatus('Failed to resolve dropped item.', '#d26b6b')
    debugDrop('Entry missing for chosen path=' .. tostring(chosenPath))
    return false
  end

  -- Expose helpers for debug-only external triggers.
  window._corruptedResolveItemFromWidget = resolveItemFromWidget
  window._corruptedTrySelectItem = trySelectItem

  itemDropZone.onDragEnter = function(self, mousePos)
    self:setBorderWidth(1)
    setStatus('Release to select this item for upgrade.', '#d6c9e8')
    debugDrop('onDragEnter fired')
    return true
  end

  itemDropZone.onDragLeave = function(self, droppedWidget, mousePos)
    self:setBorderWidth(0)
    debugDrop('onDragLeave fired')
    return true
  end

  itemDropZone.onDrop = function(self, droppedWidget, mousePos)
    self:setBorderWidth(0)
    debugDrop('onDrop fired. droppedWidget=' .. tostring(droppedWidget and droppedWidget:getClassName() or 'nil'))

    local item = resolveItemFromWidget(droppedWidget)
    return trySelectItem(item)
  end

  if previewPanel then
    previewPanel.onDragEnter = function(self, mousePos)
      itemDropZone:setBorderWidth(1)
      setStatus('Release to select this item for upgrade.', '#d6c9e8')
      debugDrop('previewPanel onDragEnter fired')
      return true
    end

    previewPanel.onDragLeave = function(self, droppedWidget, mousePos)
      itemDropZone:setBorderWidth(0)
      debugDrop('previewPanel onDragLeave fired')
      return true
    end

    previewPanel.onDrop = function(self, droppedWidget, mousePos)
      itemDropZone:setBorderWidth(0)
      debugDrop('previewPanel onDrop fired')

      local item = resolveItemFromWidget(droppedWidget)
      return trySelectItem(item)
    end
  end

  itemDropZone.onMouseRelease = function(self, mousePosition, mouseButton)
    debugDrop('onMouseRelease fired button=' .. tostring(mouseButton))

    if mouseButton == MouseLeftButton then
      local draggingWidget = g_ui.getDraggingWidget and g_ui.getDraggingWidget() or nil
      if draggingWidget then
        debugDrop('MouseRelease fallback with draggingWidget=' .. tostring(draggingWidget:getClassName()))
        local item = resolveItemFromWidget(draggingWidget)
        if trySelectItem(item) then
          return true
        end
      end
    end

    if mouseButton == MouseRightButton then
      selectedPath = nil
      itemPreview:setItemId(0)

      local itemNameLabel = window:getChildById('itemNameLabel')
      local itemTypeLabel = window:getChildById('itemTypeLabel')
      local bonusPreviewLabel = window:getChildById('bonusPreviewLabel')
      local selectedPathLabel = window:getChildById('selectedPathLabel')

      if itemNameLabel then itemNameLabel:setText('No item selected') end
      if itemTypeLabel then itemTypeLabel:setText('Type: -') end
      if bonusPreviewLabel then bonusPreviewLabel:setText('Upgrade: -') end
      if selectedPathLabel then selectedPathLabel:setText('Selected: none') end

      setStatus('Selection cleared. Drag an item into the slot.', '#d6c9e8')
      debugDrop('Selection cleared by right click')
      return true
    end
    return false
  end

  startDragMonitor(itemDropZone, resolveItemFromWidget, trySelectItem)
end

local function populate(data)
  if not window then
    return
  end

  entryByPath = {}
  pathsByClientId = {}
  pathsByItemId = {}
  selectedPath = nil

  local costsLabel = window:getChildById('costsLabel')
  local resourceLabel = window:getChildById('resourceLabel')
  local itemPreview = window:getChildById('itemPreview')
  local itemNameLabel = window:getChildById('itemNameLabel')
  local itemTypeLabel = window:getChildById('itemTypeLabel')
  local bonusPreviewLabel = window:getChildById('bonusPreviewLabel')
  local selectedPathLabel = window:getChildById('selectedPathLabel')

  if costsLabel then
    costsLabel:setText(string.format('Cost: 1 Corrupted Fragment + %d gold', tonumber(data.costGold) or 1000))
  end

  if resourceLabel then
    resourceLabel:setText(string.format('Your resources: %d fragment(s), %d gold', tonumber(data.fragmentCount) or 0, tonumber(data.gold) or 0))
  end

  if itemPreview then
    itemPreview:setItemId(0)
  end
  if itemNameLabel then itemNameLabel:setText('No item selected') end
  if itemTypeLabel then itemTypeLabel:setText('Type: -') end
  if bonusPreviewLabel then bonusPreviewLabel:setText('Upgrade: -') end
  if selectedPathLabel then selectedPathLabel:setText('Selected: none') end

  for _, entry in ipairs(data.items or {}) do
    if entry.path then
      entryByPath[entry.path] = entry

      local clientId = tonumber(entry.clientId or entry.itemId or 0) or 0
      local itemId = tonumber(entry.itemId or 0) or 0
      if clientId > 0 then
        if not pathsByClientId[clientId] then
          pathsByClientId[clientId] = {}
        end
        table.insert(pathsByClientId[clientId], entry.path)
      end
      if itemId > 0 then
        if not pathsByItemId[itemId] then
          pathsByItemId[itemId] = {}
        end
        table.insert(pathsByItemId[itemId], entry.path)
      end
    end
  end

  local hasAny = next(entryByPath) ~= nil
  if hasAny then
    setStatus('Drag an item into the slot, then press Upgrade.')
    debugDrop('populate: eligible entries=' .. tostring(#(data.items or {})))
  else
    setStatus('No eligible items found in inventory.', '#d26b6b')
    debugDrop('populate: no eligible entries')
  end
end

local function ensureWindow()
  if window then
    return window
  end

  window = g_ui.displayUI('corrupted_upgrade', rootWidget)
  window:setDraggable(false)
  window.static = true
  window.onDragEnter = function(self, mousePos)
    debugDrop('window.onDragEnter ignored')
    return false
  end
  debugDrop('window configured as non-draggable/static')
  setupDropSlot()
  return window
end

local function onOpcode(protocol, opcode, buffer)
  local data = json.decode(buffer)
  if not data then
    return
  end

  if data.action == 'open' then
    local win = ensureWindow()
    if not win then
      return
    end
    populate(data)
    syncDebugUi()
    win:show()
    win:raise()
    win:focus()
    debugDrop('window opened')
    return
  end

  if data.action == 'result' then
    if data.success then
      setStatus(data.message or 'Upgrade successful.', '#7fd992')
      protocolSend({ action = 'refresh' })
    else
      setStatus(data.message or 'Upgrade failed.', '#d26b6b')
    end
  end
end

function init()
  connect(g_game, {
    onGameEnd = destroyWindow,
  })
  ProtocolGame.registerExtendedOpcode(CORRUPTED_UPGRADE_OPCODE, onOpcode)
end

function terminate()
  disconnect(g_game, {
    onGameEnd = destroyWindow,
  })
  ProtocolGame.unregisterExtendedOpcode(CORRUPTED_UPGRADE_OPCODE)
  destroyWindow()
end

function accept()
  if not window then
    return
  end

  if not selectedPath then
    setStatus('No item selected.', '#d26b6b')
    return
  end

  protocolSend({ action = 'confirm', path = selectedPath })
end

function refresh()
  protocolSend({ action = 'refresh' })
end

function toggleDebug()
  DEBUG_DROP = not DEBUG_DROP
  syncDebugUi()
  debugDrop('Debug toggled to ' .. (DEBUG_DROP and 'ON' or 'OFF'))
end

function debugPickFromDrag()
  if not window then
    return
  end

  local resolver = window._corruptedResolveItemFromWidget
  local trySelect = window._corruptedTrySelectItem
  if not resolver or not trySelect then
    setStatus('Debug helper unavailable.', '#d26b6b')
    return
  end

  local draggingWidget = g_ui.getDraggingWidget and g_ui.getDraggingWidget() or nil
  debugDrop('debugPickFromDrag draggingWidget=' .. tostring(draggingWidget and draggingWidget:getClassName() or 'nil'))

  if not draggingWidget then
    setStatus('No active dragged widget detected right now.', '#d26b6b')
    return
  end

  local item = resolver(draggingWidget)
  if not item then
    setStatus('Active dragged widget has no item payload.', '#d26b6b')
    return
  end

  if not trySelect(item) then
    return
  end

  setStatus('Debug pick selected current dragged item.', '#7fd992')
end

function decline()
  destroyWindow()
end
