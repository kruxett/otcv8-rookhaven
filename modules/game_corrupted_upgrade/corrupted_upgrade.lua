local CORRUPTED_UPGRADE_OPCODE = 93

local window = nil
local selectedPath = nil
local entryByPath = {}
local pathsByClientId = {}
local pathsByItemId = {}

local function protocolSend(payload)
  local protocol = g_game.getProtocolGame()
  if protocol then
    protocol:sendExtendedOpcode(CORRUPTED_UPGRADE_OPCODE, json.encode(payload))
  end
end

local function destroyWindow()
  if window then
    window:destroy()
    window = nil
    selectedPath = nil
    entryByPath = {}
    pathsByClientId = {}
    pathsByItemId = {}
  end
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

  local itemPreview = window:getChildById('itemPreview')
  if not itemPreview then
    return
  end

  itemPreview.onDragEnter = function(self, mousePos)
    self:setBorderWidth(1)
    setStatus('Release to select this item for upgrade.', '#d6c9e8')
    return true
  end

  itemPreview.onDragLeave = function(self, droppedWidget, mousePos)
    self:setBorderWidth(0)
    return true
  end

  itemPreview.onDrop = function(self, widget, mousePos, forced)
    self:setBorderWidth(0)

    local item = widget and widget.currentDragThing
    if not item or not item.isItem or not item:isItem() then
      setStatus('Drop an inventory item here.', '#d26b6b')
      return false
    end

    local draggedId = tonumber(item:getId() or 0) or 0
    local candidates = pathsByClientId[draggedId]
    if not candidates or #candidates == 0 then
      candidates = pathsByItemId[draggedId]
    end
    if not candidates or #candidates == 0 then
      setStatus('That item is not eligible for corrupted upgrade.', '#d26b6b')
      return false
    end

    if #candidates > 1 then
      setStatus('Multiple matching items found. Using the first eligible one.', '#d6c9e8')
    else
      setStatus('Item selected. Press Upgrade to continue.', '#d6c9e8')
    end

    local chosenPath = candidates[1]
    local chosenEntry = entryByPath[chosenPath]
    if chosenEntry then
      self:setItemId(tonumber(chosenEntry.clientId) or draggedId)
      updatePreview(chosenPath)
      return true
    end

    setStatus('Failed to resolve dropped item.', '#d26b6b')
    return false
  end

  itemPreview.onMouseRelease = function(self, mousePosition, mouseButton)
    if mouseButton == MouseRightButton then
      selectedPath = nil
      self:setItemId(0)

      local itemNameLabel = window:getChildById('itemNameLabel')
      local itemTypeLabel = window:getChildById('itemTypeLabel')
      local bonusPreviewLabel = window:getChildById('bonusPreviewLabel')
      local selectedPathLabel = window:getChildById('selectedPathLabel')

      if itemNameLabel then itemNameLabel:setText('No item selected') end
      if itemTypeLabel then itemTypeLabel:setText('Type: -') end
      if bonusPreviewLabel then bonusPreviewLabel:setText('Upgrade: -') end
      if selectedPathLabel then selectedPathLabel:setText('Selected: none') end

      setStatus('Selection cleared. Drag an item into the slot.', '#d6c9e8')
      return true
    end
    return false
  end
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
  else
    setStatus('No eligible items found in inventory.', '#d26b6b')
  end
end

local function ensureWindow()
  if window then
    return window
  end

  window = g_ui.displayUI('corrupted_upgrade', rootWidget)
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
    win:show()
    win:raise()
    win:focus()
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

function decline()
  destroyWindow()
end
