local FORGING_UPGRADE_OPCODE = 93

local window = nil
local ui = {}
local dragMonitorEvent = nil

local selectedPath = nil
local selectedItem = nil
local entryByPath = {}
local pathsByClientId = {}
local pathsByItemId = {}
local failConfig = {
  minChance = 0.04,
  maxChance = 0.70,
  failExponent = 0.11,
  weightMaxBonus = 3.2,
  weightExponent = 0.08,
  maxInvest = 100000,
}

local GOLD_COIN_ITEM_ID = 3031
local REQ_CARD_WIDTH = 66
local REQ_CARD_SPACING = 8

local updatePreview
local stopDragMonitor
local destroyWindow
local truncateText

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

  ui.resourceLabel = findWidgetById(window, 'resourceLabel')
  ui.statusLabel = findWidgetById(window, 'statusLabel')
  ui.itemNameLabel = findWidgetById(window, 'itemNameLabel')
  ui.itemTypeLabel = findWidgetById(window, 'itemTypeLabel')

  ui.tierLabel = findWidgetById(window, 'tierLabel')
  ui.rollsLabel = findWidgetById(window, 'rollsLabel')
  ui.requirementsPanel = findWidgetById(window, 'requirementsPanel')

  ui.useCorruptedBox = findWidgetById(window, 'useCorruptedBox')
  ui.corruptedCountEdit = findWidgetById(window, 'corruptedCountEdit')
  ui.affixSelector = findWidgetById(window, 'affixSelector')
  ui.failChanceLabel = findWidgetById(window, 'failChanceLabel')
  ui.weightLabel = findWidgetById(window, 'weightLabel')

  return ui.itemDropZone ~= nil and ui.itemPreview ~= nil and ui.statusLabel ~= nil
end

local function protocolSend(payload)
  local protocol = g_game.getProtocolGame()
  if protocol then
    protocol:sendExtendedOpcode(FORGING_UPGRADE_OPCODE, json.encode(payload))
  end
end

local function setStatus(text, color)
  if not ui.statusLabel then
    return
  end

  ui.statusLabel:setText(text or '')
  ui.statusLabel:setColor(color or '#d9d2bf')
end

local function formatGold(amount)
  local n = tonumber(amount) or 0
  if n >= 1000000 then
    return string.format('%.1fM', n / 1000000)
  elseif n >= 10000 then
    return string.format('%dk', math.floor(n / 1000))
  else
    return tostring(n)
  end
end

local function clearRequirementWidgets()
  if not ui.requirementsPanel then return end
  local children = ui.requirementsPanel:getChildren()
  for _, child in ipairs(children or {}) do
    child:destroy()
  end
end

local function buildRequirementWidgets(entry)
  clearRequirementWidgets()
  if not ui.requirementsPanel or not entry then return end

  local allReqs = {}
  for _, r in ipairs(entry.requirements or {}) do
    table.insert(allReqs, r)
  end

  local goldHave = tonumber(entry.goldHave) or 0
  local goldNeed = tonumber(entry.goldRequired) or 0
  if goldNeed > 0 then
    table.insert(allReqs, {
      itemId = GOLD_COIN_ITEM_ID,
      label = 'Gold',
      have = goldHave,
      required = goldNeed,
    })
  end

  local x = 2
  for _, req in ipairs(allReqs) do
    local have = tonumber(req.have) or 0
    local need = tonumber(req.required) or 0
    local met = have >= need

    local card = g_ui.createWidget('ForgingReqCard', ui.requirementsPanel)
    card:setWidth(REQ_CARD_WIDTH)
    card:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    card:addAnchor(AnchorTop, 'parent', AnchorTop)
    card:setMarginLeft(x)
    card:setMarginTop(4)

    local icon = card:getChildById('reqItemIcon')
    if icon then
      local displayId = tonumber(req.clientId) or tonumber(req.itemId) or 0
      icon:setItemId(displayId)
      icon:setItemCount(math.min(math.max(need, 1), 9999))
    end

    local countLabel = card:getChildById('reqCountLabel')
    if countLabel then
      countLabel:setText(formatGold(have) .. ' / ' .. formatGold(need))
      countLabel:setColor(met and '#7fd992' or '#e05050')
    end

    local nameLabel = card:getChildById('reqNameLabel')
    if nameLabel then
      nameLabel:setText(truncateText(req.label or '?', 10))
    end

    x = x + REQ_CARD_WIDTH + REQ_CARD_SPACING
  end
end

local function normalizeLabel(label)
  if type(label) ~= 'string' or label == '' then
    return 'Unknown'
  end

  local first = string.sub(label, 1, 1)
  local rest = string.sub(label, 2)
  return string.upper(first) .. rest
end

truncateText = function(text, limit)
  local s = tostring(text or '')
  local maxLen = tonumber(limit) or 140
  if #s <= maxLen then
    return s
  end
  return string.sub(s, 1, maxLen - 3) .. '...'
end

local function getInvestCount()
  if not ui.corruptedCountEdit then
    return 0
  end

  local raw = tonumber(ui.corruptedCountEdit:getText() or '0') or 0
  if raw < 0 then
    raw = 0
  end
  local maxInvest = tonumber(failConfig.maxInvest) or 100000
  if raw > maxInvest then
    raw = maxInvest
  end
  return math.floor(raw)
end

local function setInvestCount(v)
  if not ui.corruptedCountEdit then
    return
  end

  local value = tonumber(v) or 0
  if value < 0 then
    value = 0
  end
  local maxInvest = tonumber(failConfig.maxInvest) or 100000
  if value > maxInvest then
    value = maxInvest
  end
  ui.corruptedCountEdit:setText(tostring(math.floor(value)))
end

local function getSelectedAffixId()
  if not ui.affixSelector then
    return 0
  end

  local option = ui.affixSelector:getCurrentOption()
  if not option or option.data == nil then
    return 0
  end

  return tonumber(option.data) or 0
end

local function refreshRiskPreview()
  if not ui.failChanceLabel or not ui.weightLabel then
    return
  end

  local useCorrupted = ui.useCorruptedBox and ui.useCorruptedBox:isChecked() or false
  local invest = useCorrupted and getInvestCount() or 0

  local failChance = 0
  local weight = 1.0
  if invest > 0 then
    local minC = tonumber(failConfig.minChance) or 0.04
    local maxC = tonumber(failConfig.maxChance) or 0.70
    local kFail = tonumber(failConfig.failExponent) or 0.11
    local maxBonus = tonumber(failConfig.weightMaxBonus) or 3.2
    local kWeight = tonumber(failConfig.weightExponent) or 0.08

    failChance = minC + (maxC - minC) * (1 - math.exp(-kFail * invest))
    weight = 1 + maxBonus * (1 - math.exp(-kWeight * invest))
  end

  ui.failChanceLabel:setText(string.format('Fail chance: %.1f%%', failChance * 100))
  ui.weightLabel:setText(string.format('Weight multiplier: x%.2f', weight))
end

local function refreshOptionalWidgetState()
  local checked = ui.useCorruptedBox and ui.useCorruptedBox:isChecked() or false

  if ui.corruptedCountEdit then
    ui.corruptedCountEdit:setEnabled(checked)
  end

  if ui.affixSelector then
    local canUseSelector = checked and selectedPath ~= nil and ui.affixSelector:getOptionsCount() > 0
    ui.affixSelector:setEnabled(canUseSelector)
  end
end

local function formatRequirements(entry)
  if not entry then
    return '-'
  end

  local lines = {}
  local reqs = entry.requirements or {}
  for i = 1, #reqs do
    local req = reqs[i]
    local have = tonumber(req.have) or 0
    local need = tonumber(req.required) or 0
    local label = normalizeLabel(req.label or ('Item ' .. tostring(req.itemId or 0)))
    lines[#lines + 1] = string.format('- %s: %d/%d', label, have, need)
  end

  local goldHave = tonumber(entry.goldHave) or 0
  local goldNeed = tonumber(entry.goldRequired) or 0
  lines[#lines + 1] = string.format('- Gold: %d/%d', goldHave, goldNeed)

  if #lines == 0 then
    return '-'
  end

  return table.concat(lines, '\n')
end

local function clearSelection()
  selectedPath = nil
  selectedItem = nil

  if ui.itemPreview then
    ui.itemPreview:setImageSource('/images/ui/item')
    ui.itemPreview:setItemId(0)
  end
  if ui.itemNameLabel then ui.itemNameLabel:setText('No item selected') end
  if ui.itemTypeLabel then ui.itemTypeLabel:setText('-') end
  if ui.tierLabel then ui.tierLabel:setText('Tier: -') end
  if ui.rollsLabel then ui.rollsLabel:setText('New rolls: -') end

  clearRequirementWidgets()

  if ui.affixSelector then
    ui.affixSelector:clearOptions()
  end

  refreshOptionalWidgetState()
  refreshRiskPreview()
end

updatePreview = function(path)
  selectedPath = path
  local entry = entryByPath[path or '']
  if not entry then
    return
  end

  if ui.itemPreview then
    ui.itemPreview:setImageSource('/images/ui/item')
    ui.itemPreview:setItemId(tonumber(entry.clientId) or tonumber(entry.itemId) or 0)
  end

  if ui.itemNameLabel then
    ui.itemNameLabel:setText(entry.name or 'Unknown item')
  end

  if ui.itemTypeLabel then
    local kind = entry.kind or 'armor'
    local typeText = 'Armor'
    if kind == 'weapon' then
      typeText = 'Weapon'
    elseif kind == 'shield' then
      typeText = 'Shield'
    elseif kind == 'amulet' then
      typeText = 'Amulet'
    elseif kind == 'boots' then
      typeText = 'Boots'
    end
    ui.itemTypeLabel:setText('Type: ' .. typeText)
  end

  if ui.tierLabel then
    ui.tierLabel:setText(string.format('Tier: %s  ->  %s', entry.currentTierLabel or 'Common', entry.nextTierLabel or 'Max'))
  end

  if ui.rollsLabel then
    local rolls = tonumber(entry.rollsToAdd) or 0
    local rollText = rolls == 1 and '+1 new affix roll' or ('+' .. rolls .. ' new affix rolls')
    ui.rollsLabel:setText(rollText)
  end

  buildRequirementWidgets(entry)

  if ui.affixSelector then
    ui.affixSelector:clearOptions()
    local options = entry.affixOptions or {}
    for i = 1, #options do
      local opt = options[i]
      ui.affixSelector:addOption(opt.name or ('Affix ' .. tostring(opt.id)), tonumber(opt.id) or 0)
    end
    if #options == 0 then
      ui.affixSelector:addOption('No affix options available', 0)
    end
  end

  refreshOptionalWidgetState()
  refreshRiskPreview()
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
    return false
  end

  local draggedId = tonumber(item:getId() or 0) or 0
  local candidates = pathsByClientId[draggedId]
  if not candidates or #candidates == 0 then
    candidates = pathsByItemId[draggedId]
  end

  if not candidates or #candidates == 0 then
    setStatus('That item is not eligible for forging upgrade.', '#d26b6b')
    return false
  end

  local chosenPath = candidates[1]
  local chosenEntry = entryByPath[chosenPath]
  if not chosenEntry then
    setStatus('Failed to resolve selected item.', '#d26b6b')
    return false
  end

  if #candidates > 1 then
    setStatus('Multiple identical items found. Using first eligible match.')
  else
    setStatus('Item selected. Press Upgrade to continue.')
  end

  selectedItem = item
  updatePreview(chosenPath)
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
          trySelectItem(lastDraggedItem)
        end
        wasDragging = false
        lastDraggedItem = nil
      end
    end)

    if not ok then
      -- ignore
    end

    if window then
      dragMonitorEvent = scheduleEvent(tick, 50)
    end
  end

  dragMonitorEvent = scheduleEvent(tick, 50)
end

local function setupDropHandlers()
  if not ui.itemDropZone then
    return
  end

  ui.itemDropZone.onDragEnter = function(self, mousePos)
    if self then
      self:setBorderWidth(1)
    end
    setStatus('Release to select this item for upgrade.')
    return true
  end

  ui.itemDropZone.onDragLeave = function(self, droppedWidget, mousePos)
    if self then
      self:setBorderWidth(0)
    end
    return true
  end

  ui.itemDropZone.onDrop = function(self, droppedWidget, mousePos)
    if self then
      self:setBorderWidth(0)
    end
    local item = resolveItemFromWidget(droppedWidget)
    return trySelectItem(item)
  end

  if ui.previewPanel then
    ui.previewPanel.onDrop = function(self, droppedWidget, mousePos)
      if ui.itemDropZone then ui.itemDropZone:setBorderWidth(0) end
      local item = resolveItemFromWidget(droppedWidget)
      return trySelectItem(item)
    end
  end

  ui.itemDropZone.onMouseRelease = function(self, mousePos, mouseButton)
    if mouseButton == MouseRightButton then
      clearSelection()
      setStatus('Selection cleared. Drag an item into the slot.')
      return true
    end

    if mouseButton == MouseLeftButton then
      local draggingWidget = g_ui.getDraggingWidget and g_ui.getDraggingWidget() or nil
      if draggingWidget then
        local item = resolveItemFromWidget(draggingWidget)
        if trySelectItem(item) then
          return true
        end
      end
    end

    return false
  end
end

local function bindOptionalControls()
  if ui.useCorruptedBox then
    ui.useCorruptedBox.onCheckChange = function(widget, checked)
      refreshOptionalWidgetState()
      refreshRiskPreview()
    end
  end

  if ui.corruptedCountEdit then
    ui.corruptedCountEdit.onTextChange = function(widget, text)
      setInvestCount(tonumber(text) or 0)
      refreshRiskPreview()
    end
  end

  if ui.affixSelector then
    ui.affixSelector.onOptionChange = function(widget, text, data)
      refreshRiskPreview()
    end
  end
end

local function populate(data)
  entryByPath = {}
  pathsByClientId = {}
  pathsByItemId = {}

  if type(data.failConfig) == 'table' then
    failConfig = data.failConfig
  end

  if ui.resourceLabel then
    ui.resourceLabel:setText(string.format('Your resources: %d Corrupted Fragment(s)  |  %d gold', tonumber(data.fragmentCount) or 0, tonumber(data.gold) or 0))
  end

  clearSelection()

  if ui.useCorruptedBox then
    ui.useCorruptedBox:setChecked(false)
  end
  setInvestCount(1)
  refreshOptionalWidgetState()

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
    setStatus('Drop an item into the forge slot to begin.')
  else
    setStatus('No eligible items found in inventory.', '#d26b6b')
  end

  refreshRiskPreview()
end

local function ensureWindow()
  if window then
    return window
  end

  window = g_ui.displayUI('corrupted_upgrade', rootWidget)
  window:setDraggable(false)
  window.static = true
  window.onDragEnter = function(self, mousePos)
    return false
  end

  if not bindWidgets() then
    print('[CorruptedUpgradeUI] Failed to bind required widgets')
  end

  bindOptionalControls()
  setupDropHandlers()
  startDragMonitor()

  if ui.corruptedCountEdit then
    ui.corruptedCountEdit:setEnabled(false)
  end
  if ui.affixSelector then
    ui.affixSelector:setEnabled(false)
  end
  refreshOptionalWidgetState()

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
      scheduleEvent(function()
        if modules and modules.game_inventory and modules.game_inventory.refresh then
          modules.game_inventory.refresh()
        end
        if modules and modules.game_containers and modules.game_containers.reloadContainers then
          modules.game_containers.reloadContainers()
        end
      end, 150)
      protocolSend({ action = 'refresh' })
    else
      setStatus(data.message or 'Upgrade failed.', '#d26b6b')
    end
  end
end

function init()
  g_ui.importStyle('corrupted_upgrade_styles')

  destroyWindow = function()
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
    stopDragMonitor()
  end

  connect(g_game, {
    onGameEnd = destroyWindow,
  })
  ProtocolGame.registerExtendedOpcode(FORGING_UPGRADE_OPCODE, onOpcode)
end

function terminate()
  disconnect(g_game, {
    onGameEnd = destroyWindow,
  })
  ProtocolGame.unregisterExtendedOpcode(FORGING_UPGRADE_OPCODE)
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

  local useCorrupted = ui.useCorruptedBox and ui.useCorruptedBox:isChecked() or false
  local invest = useCorrupted and getInvestCount() or 0
  local selectedAffixId = useCorrupted and getSelectedAffixId() or 0

  if invest > 0 and selectedAffixId <= 0 then
    setStatus('Pick one affix when using Corrupted Fragments.', '#d26b6b')
    return
  end

  protocolSend({
    action = 'confirm',
    path = selectedPath,
    corruptedInvestCount = invest,
    selectedAffixId = selectedAffixId,
  })
end

function refresh()
  protocolSend({ action = 'refresh' })
end

function decline()
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
