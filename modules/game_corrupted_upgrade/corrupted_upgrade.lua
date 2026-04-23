local CORRUPTED_UPGRADE_OPCODE = 93

local DEBUG_DROP = false

local window = nil
local ui = {}
local dragMonitorEvent = nil

local selectedPath = nil
local selectedItem = nil
local entryByPath = {}
local pathsByClientId = {}
local pathsByItemId = {}

local updatePreview
local stopDragMonitor
local FORCE_RARE_FRAME_PATH = '/images/ui/rarity_blue'

local lastDraggedItem = nil
local wasDragging = false

local function findWidgetById(root, id)
  if not root or not id then
    return nil
  end

  if root.getId and root:getId() == id then
    return root
  end

  if not root.getChildren then
    return nil
  end

  for _, child in ipairs(root:getChildren() or {}) do
    local found = findWidgetById(child, id)
    if found then
      return found
    end
  end

  return nil
end

local function bindWidgets()
  ui = {}
  if not window then
    return false
  end

  ui.previewPanel = findWidgetById(window, 'previewPanel')
  ui.itemDropZone = findWidgetById(window, 'itemDropZone')
  ui.itemPreview = findWidgetById(window, 'itemPreview')

  ui.costsLabel = findWidgetById(window, 'costsLabel')
  ui.resourceLabel = findWidgetById(window, 'resourceLabel')
  ui.statusLabel = findWidgetById(window, 'statusLabel')
  ui.itemNameLabel = findWidgetById(window, 'itemNameLabel')
  ui.itemTypeLabel = findWidgetById(window, 'itemTypeLabel')
  ui.bonusPreviewLabel = findWidgetById(window, 'bonusPreviewLabel')
  ui.selectedPathLabel = findWidgetById(window, 'selectedPathLabel')

  return ui.itemDropZone ~= nil and ui.itemPreview ~= nil and ui.statusLabel ~= nil
end

local function protocolSend(payload)
  local protocol = g_game.getProtocolGame()
  if protocol then
    protocol:sendExtendedOpcode(CORRUPTED_UPGRADE_OPCODE, json.encode(payload))
  end
end

local function applyPreviewRarityFrame(item)
  if not ui.itemPreview then
    return
  end

  local framePath = nil
  if _G.affixSystem and item then
    framePath = _G.affixSystem.getRarityFrame(item)
  end

  ui.itemPreview:setImageSource(framePath or '/images/ui/item')
end

local function refreshItemVisuals()
  if modules and modules.game_inventory and modules.game_inventory.refresh then
    modules.game_inventory.refresh()
  end

  if modules and modules.game_containers and modules.game_containers.reloadContainers then
    modules.game_containers.reloadContainers()
  end

  if selectedItem and ui.itemPreview then
    applyPreviewRarityFrame(selectedItem)
    if selectedPath then
      updatePreview(selectedPath)
    end
  end
end

local function destroyWindow()
  stopDragMonitor()

  if window then
    window:destroy()
    window = nil
  end

  ui = {}
  selectedPath = nil
  selectedItem = nil
  entryByPath = {}
  pathsByClientId = {}
  pathsByItemId = {}
end

local function getSelectedInventorySlot()
  if type(selectedPath) ~= 'string' or selectedPath == '' then
    return nil
  end

  local slotToken = selectedPath:match('^(%d+):') or selectedPath:match('^(%d+)$')
  local slot = tonumber(slotToken)
  if not slot then
    return nil
  end

  local chain = selectedPath:match('^%d+:(.*)$') or ''
  if chain ~= '' then
    return nil
  end

  return slot
end

local function applyImmediateRareFrame()
  if ui.itemPreview then
    ui.itemPreview:setImageSource(FORCE_RARE_FRAME_PATH)
    if selectedItem then
      ui.itemPreview:setItem(selectedItem)
    end
  end

  local slot = getSelectedInventorySlot()
  if not slot then
    return
  end

  if inventoryPanel then
    local itemWidget = inventoryPanel:getChildById('slot' .. slot)
    if itemWidget then
      itemWidget:setImageSource(FORCE_RARE_FRAME_PATH)

      local localPlayer = g_game and g_game.getLocalPlayer and g_game.getLocalPlayer() or nil
      local equippedItem = localPlayer and localPlayer.getInventoryItem and localPlayer:getInventoryItem(slot) or nil
      if equippedItem then
        itemWidget:setItem(equippedItem)
      end
    end
  end
end

local function setStatus(text, color)
  if not ui.statusLabel then
    return
  end

  ui.statusLabel:setText(text or '')
  ui.statusLabel:setColor(color or '#d6c9e8')
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
end

local function syncDebugUi()
  return
end

local function clearSelection()
  selectedPath = nil
  selectedItem = nil

  if ui.itemPreview then
    ui.itemPreview:setImageSource('/images/ui/item')
    ui.itemPreview:setItemId(0)
  end
  if ui.itemNameLabel then ui.itemNameLabel:setText('No item selected') end
  if ui.itemTypeLabel then ui.itemTypeLabel:setText('Type: -') end
  if ui.bonusPreviewLabel then ui.bonusPreviewLabel:setText('Upgrade: -') end
  if ui.selectedPathLabel then ui.selectedPathLabel:setText('Selected: none') end
end

updatePreview = function(path)
  selectedPath = path
  local entry = entryByPath[path or '']
  if not entry then
    return
  end

  if ui.itemPreview then
    applyPreviewRarityFrame(selectedItem)
    ui.itemPreview:setItemId(tonumber(entry.clientId) or tonumber(entry.itemId) or 0)
  end

  if ui.itemNameLabel then
    ui.itemNameLabel:setText(entry.name or 'Unknown item')
  end

  if ui.itemTypeLabel then
    ui.itemTypeLabel:setText('Type: ' .. ((entry.kind == 'weapon') and 'Weapon' or 'Armor'))
  end

  if ui.bonusPreviewLabel then
    ui.bonusPreviewLabel:setText('Upgrade: ' .. (entry.preview or '-'))
  end

  if ui.selectedPathLabel then
    ui.selectedPathLabel:setText('Selected: ' .. tostring(path))
  end
end

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
    debugDrop('trySelectItem: no item payload')
    return false
  end

  local draggedId = tonumber(item:getId() or 0) or 0
  local candidates = pathsByClientId[draggedId]
  if not candidates or #candidates == 0 then
    candidates = pathsByItemId[draggedId]
  end

  if not candidates or #candidates == 0 then
    setStatus('That item is not eligible for corrupted upgrade.', '#d26b6b')
    debugDrop('trySelectItem: no candidates for id=' .. tostring(draggedId))
    return false
  end

  local chosenPath = candidates[1]
  local chosenEntry = entryByPath[chosenPath]
  if not chosenEntry then
    setStatus('Failed to resolve selected item.', '#d26b6b')
    debugDrop('trySelectItem: entry missing for path=' .. tostring(chosenPath))
    return false
  end

  if #candidates > 1 then
    setStatus('Multiple identical items found. Using first eligible match.')
  else
    setStatus('Item selected. Press Upgrade to continue.')
  end

  selectedItem = item
  updatePreview(chosenPath)
  debugDrop('trySelectItem: selected path=' .. tostring(chosenPath) .. ' id=' .. tostring(draggedId))
  return true
end

stopDragMonitor = function()
  if dragMonitorEvent then
    removeEvent(dragMonitorEvent)
    dragMonitorEvent = nil
  end
  wasDragging = false
  lastDraggedItem = nil
end

local function startDragMonitor()
  stopDragMonitor()

  local function tick()
    if not window or not ui.itemDropZone then
      dragMonitorEvent = nil
      return
    end

    local ok = pcall(function()
      local draggingWidget = g_ui.getDraggingWidget and g_ui.getDraggingWidget() or nil
      local mousePos = g_window and g_window.getMousePosition and g_window.getMousePosition() or nil
      local overSlot = (mousePos and ui.itemDropZone:containsPoint(mousePos)) and true or false

      if draggingWidget then
        local item = resolveItemFromWidget(draggingWidget)
        if item then
          lastDraggedItem = item
        end
        wasDragging = true
      elseif wasDragging then
        if lastDraggedItem and overSlot then
          debugDrop('drag monitor: release over slot detected')
          trySelectItem(lastDraggedItem)
        end
        wasDragging = false
        lastDraggedItem = nil
      end
    end)

    if not ok then
      debugDrop('drag monitor: runtime error')
    end

    if window then
      dragMonitorEvent = scheduleEvent(tick, 50)
    end
  end

  dragMonitorEvent = scheduleEvent(tick, 50)
end

local function setupDropHandlers()
  if not ui.itemDropZone then
    debugDrop('setupDropHandlers: missing itemDropZone')
    return
  end

  ui.itemDropZone.onDragEnter = function(self, mousePos)
    self:setBorderWidth(1)
    setStatus('Release to select this item for upgrade.')
    debugDrop('itemDropZone.onDragEnter')
    return true
  end

  ui.itemDropZone.onDragLeave = function(self, droppedWidget, mousePos)
    self:setBorderWidth(0)
    debugDrop('itemDropZone.onDragLeave')
    return true
  end

  ui.itemDropZone.onDrop = function(self, droppedWidget, mousePos)
    self:setBorderWidth(0)
    debugDrop('itemDropZone.onDrop')
    local item = resolveItemFromWidget(droppedWidget)
    return trySelectItem(item)
  end

  if ui.previewPanel then
    ui.previewPanel.onDrop = function(self, droppedWidget, mousePos)
      if ui.itemDropZone then ui.itemDropZone:setBorderWidth(0) end
      debugDrop('previewPanel.onDrop fallback')
      local item = resolveItemFromWidget(droppedWidget)
      return trySelectItem(item)
    end
  end

  ui.itemDropZone.onMouseRelease = function(self, mousePos, mouseButton)
    if mouseButton == MouseRightButton then
      clearSelection()
      setStatus('Selection cleared. Drag an item into the slot.')
      debugDrop('itemDropZone.onMouseRelease right-click clear')
      return true
    end

    if mouseButton == MouseLeftButton then
      local draggingWidget = g_ui.getDraggingWidget and g_ui.getDraggingWidget() or nil
      if draggingWidget then
        debugDrop('itemDropZone.onMouseRelease left fallback')
        local item = resolveItemFromWidget(draggingWidget)
        if trySelectItem(item) then
          return true
        end
      end
    end

    return false
  end
end

local function populate(data)
  entryByPath = {}
  pathsByClientId = {}
  pathsByItemId = {}

  if ui.costsLabel then
    ui.costsLabel:setText(string.format('Cost: 1 Corrupted Fragment + %d gold', tonumber(data.costGold) or 1000))
  end

  if ui.resourceLabel then
    ui.resourceLabel:setText(string.format('Your resources: %d fragment(s), %d gold', tonumber(data.fragmentCount) or 0, tonumber(data.gold) or 0))
  end

  clearSelection()

  for _, entry in ipairs(data.items or {}) do
    if entry.path then
      entryByPath[entry.path] = entry

      local clientId = tonumber(entry.clientId or 0) or 0
      local itemId = tonumber(entry.itemId or 0) or 0

      if clientId > 0 then
        pathsByClientId[clientId] = pathsByClientId[clientId] or {}
        table.insert(pathsByClientId[clientId], entry.path)
      end

      if itemId > 0 then
        pathsByItemId[itemId] = pathsByItemId[itemId] or {}
        table.insert(pathsByItemId[itemId], entry.path)
      end
    end
  end

  if next(entryByPath) then
    setStatus('Drag an item into the slot, then press Upgrade.')
    debugDrop('populate: loaded eligible items=' .. tostring(#(data.items or {})))
  else
    setStatus('No eligible items found in inventory.', '#d26b6b')
    debugDrop('populate: no eligible items')
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
    -- Important: do not let the window consume drag events from items.
    return false
  end

  if not bindWidgets() then
    print('[CorruptedUpgradeUI] Failed to bind required widgets')
  end

  syncDebugUi()
  setupDropHandlers()
  startDragMonitor()

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
    win:show()
    win:raise()
    win:focus()
    debugDrop('window opened')
    return
  end

  if data.action == 'result' then
    if data.success then
      setStatus(data.message or 'Upgrade successful.', '#7fd992')
      applyImmediateRareFrame()
      scheduleEvent(function()
        refreshItemVisuals()
      end, 150)
      scheduleEvent(refreshItemVisuals, 400)
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

function decline()
  destroyWindow()
end
