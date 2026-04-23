local CORRUPTED_UPGRADE_OPCODE = 93

local window = nil
local selectedPath = nil
local entryByPath = {}

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
end

local function populate(data)
  if not window then
    return
  end

  entryByPath = {}
  selectedPath = nil

  local costsLabel = window:getChildById('costsLabel')
  local resourceLabel = window:getChildById('resourceLabel')
  local itemCombo = window:getChildById('itemCombo')

  if costsLabel then
    costsLabel:setText(string.format('Cost: 1 Corrupted Fragment + %d gold', tonumber(data.costGold) or 1000))
  end

  if resourceLabel then
    resourceLabel:setText(string.format('Your resources: %d fragment(s), %d gold', tonumber(data.fragmentCount) or 0, tonumber(data.gold) or 0))
  end

  if not itemCombo then
    return
  end

  itemCombo:clearOptions()

  itemCombo.onOptionChange = function(widget, option, value)
    updatePreview(value)
  end

  for _, entry in ipairs(data.items or {}) do
    if entry.path then
      entryByPath[entry.path] = entry
      itemCombo:addOption(entry.label or entry.name or entry.path, entry.path)
    end
  end

  local hasAny = next(entryByPath) ~= nil
  if hasAny then
    local firstPath = nil
    for _, entry in ipairs(data.items or {}) do
      if entry.path then
        firstPath = entry.path
        break
      end
    end
    if firstPath then
      updatePreview(firstPath)
    end
    setStatus('Select an item and press Upgrade.')
  else
    setStatus('No eligible items found in inventory.', '#d26b6b')
  end
end

local function ensureWindow()
  if window then
    return window
  end

  window = g_ui.displayUI('corrupted_upgrade', rootWidget)
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
    win:grabMouse()
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
  if window then
    window:ungrabMouse()
  end
  destroyWindow()
end
