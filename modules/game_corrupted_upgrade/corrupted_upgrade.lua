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
  minChance = 0.02,
  maxChance = 0.45,
  failExponent = 0.11,
  weightMaxBonus = 6.0,
  weightExponent = 0.16,
  maxInvest = 20,
}

local GOLD_COIN_ITEM_ID = 3031
local PLATINUM_COIN_ITEM_ID = 3035
local CRYSTAL_COIN_ITEM_ID = 3043
local CORRUPTED_FRAGMENT_ITEM_ID = 12787
local corruptedFragmentClientId = CORRUPTED_FRAGMENT_ITEM_ID
local OPTIONAL_PANEL_HEIGHT = 146
local REQ_CARD_WIDTH = 98
local REQ_CARD_SPACING = 4

local updatePreview
local stopDragMonitor
local destroyWindow
local truncateText

local lastDraggedItem = nil
local wasDragging = false
local availableCorruptedFragments = 0
local investSyncLock = false
local pendingStatusText = nil
local pendingStatusColor = nil
local detailsRequestPending = {}

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

  ui.useCorruptedBox = nil -- removed: panel visibility is the toggle now
  ui.corruptedCountEdit = findWidgetById(window, 'corruptedCountEdit')
  ui.corruptedCountSlider = findWidgetById(window, 'corruptedCountSlider')
  ui.corruptedCountLimitLabel = findWidgetById(window, 'corruptedCountLimitLabel')
  ui.corruptedFragmentIcon = findWidgetById(window, 'corruptedFragmentIcon')
  ui.affixSelector = findWidgetById(window, 'affixSelector')
  ui.failChanceLabel = findWidgetById(window, 'failChanceLabel')
  ui.successChanceLabel = findWidgetById(window, 'successChanceLabel')
  ui.weightLabel = findWidgetById(window, 'weightLabel')
  ui.targetAffixChanceLabel = findWidgetById(window, 'targetAffixChanceLabel')
  ui.toggleAffixBoostButton = findWidgetById(window, 'toggleAffixBoostButton')
  ui.optionalPanel = findWidgetById(window, 'optionalPanel')

  return ui.itemDropZone ~= nil and ui.itemPreview ~= nil and ui.statusLabel ~= nil
end

local function protocolSend(payload)
  local protocol = g_game.getProtocolGame()
  if protocol then
    protocol:sendExtendedOpcode(FORGING_UPGRADE_OPCODE, json.encode(payload))
  end
end

local function requestEntryDetails(path)
  local key = tostring(path or '')
  if key == '' or detailsRequestPending[key] then
    return
  end

  detailsRequestPending[key] = true
  protocolSend({ action = 'details', path = key })
end

local function setStatus(text, color)
  if not ui.statusLabel then
    return
  end

  ui.statusLabel:setText(text or '')
  ui.statusLabel:setColor(color or '#d9d2bf')
end

local function formatCount(amount)
  local n = math.floor(tonumber(amount) or 0)
  local s = tostring(n)
  local k = 0
  repeat
    s, k = s:gsub('^(%-?%d+)(%d%d%d)', '%1,%2')
  until k == 0
  return s
end

local function formatCompactCount(amount)
  local n = math.floor(tonumber(amount) or 0)
  if n >= 1000000 then
    return string.format('%.1fM', n / 1000000)
  end
  if n >= 1000 then
    return string.format('%dk', math.floor(n / 1000))
  end
  return tostring(n)
end

local function isUsingCorrupted()
  return ui.optionalPanel ~= nil and ui.optionalPanel:isVisible()
end

local function refreshCorruptedFragmentIcon()
  if not ui.corruptedFragmentIcon then
    return
  end

  local iconId = tonumber(corruptedFragmentClientId) or CORRUPTED_FRAGMENT_ITEM_ID
  if iconId <= 0 then
    iconId = CORRUPTED_FRAGMENT_ITEM_ID
  end

  -- Force a redraw when opening/repopulating the window to avoid stale empty UIItem state.
  ui.corruptedFragmentIcon:setItemId(0)
  ui.corruptedFragmentIcon:setItemId(iconId)
  ui.corruptedFragmentIcon:setTooltip('Corrupted Fragment')
end

local syncInvestLimitLabel
local refreshRiskPreview
local refreshOptionalWidgetState

local function toggleAffixPanelInternal()
  if not ui.optionalPanel or not window then return end
  local isExpanded = ui.optionalPanel:isVisible()
  local currentSize = window:getSize()

  if isExpanded then
    -- collapse
    ui.optionalPanel:setVisible(false)
    ui.optionalPanel:setHeight(0)
    window:resize(currentSize.width, currentSize.height - OPTIONAL_PANEL_HEIGHT)
    if ui.toggleAffixBoostButton then
      ui.toggleAffixBoostButton:setText('+ Corrupted Imbuement')
    end
  else
    -- expand
    ui.optionalPanel:setHeight(OPTIONAL_PANEL_HEIGHT)
    ui.optionalPanel:setVisible(true)
    window:resize(currentSize.width, currentSize.height + OPTIONAL_PANEL_HEIGHT)
    refreshCorruptedFragmentIcon()
    if ui.toggleAffixBoostButton then
      ui.toggleAffixBoostButton:setText('- Corrupted Imbuement')
    end
    syncInvestLimitLabel()
    refreshOptionalWidgetState()
    refreshRiskPreview()
  end
end

local function clearRequirementWidgets()
  if not ui.requirementsPanel then return end
  local children = ui.requirementsPanel:getChildren()
  for _, child in ipairs(children or {}) do
    child:destroy()
  end
end

local function resolveCoinDisplay(haveGold, needGold)
  local need = tonumber(needGold) or 0
  local scaleSource = need

  local iconDivisor = 1
  local iconItemId = GOLD_COIN_ITEM_ID
  if scaleSource > 10000 then
    iconItemId = CRYSTAL_COIN_ITEM_ID
    iconDivisor = 10000
  elseif scaleSource > 1000 then
    iconItemId = PLATINUM_COIN_ITEM_ID
    iconDivisor = 100
  end

  return {
    itemId = iconItemId,
    label = 'Gold Cost',
    iconDivisor = iconDivisor,
    showRawCount = true,
  }
end

local function prettifyRequirementLabel(label)
  local raw = tostring(label or '?')
  local lower = string.lower(raw)

  if lower == 'gold' or lower == 'platinum coin' or lower == 'crystal coin' or lower == 'gold cost' then
    return 'Gold'
  elseif lower == 'light blue fragment' then
    return 'Light Blue'
  elseif lower == 'green fragment' then
    return 'Green Frag'
  elseif lower == 'red fragment' then
    return 'Red Frag'
  elseif lower == 'pristine forging shard' then
    return 'Pristine'
  elseif lower == 'tempered forging shard' then
    return 'Tempered'
  elseif lower == 'forging shard' then
    return 'Shard'
  end

  local first = string.sub(raw, 1, 1)
  local rest = string.sub(raw, 2)
  return string.upper(first) .. rest
end

local function getRequirementTooltip(req)
  local raw = tostring((req and req.label) or '?')
  local lower = string.lower(raw)
  if lower == 'gold' or lower == 'gold cost' or lower == 'crystal coin' or lower == 'platinum coin' then
    return 'Gold Cost'
  end
  return raw
end

local function getRequirementPanelWidth()
  local width = 0

  if ui.requirementsPanel and ui.requirementsPanel.getWidth then
    width = tonumber(ui.requirementsPanel:getWidth()) or 0
  end

  if width <= 0 and window and window.getWidth then
    -- requirementsPanel uses 10px margins on both sides.
    width = (tonumber(window:getWidth()) or 460) - 20
  end

  if width <= 0 then
    width = 430
  end

  return math.floor(width)
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
    local coinDisplay = resolveCoinDisplay(goldHave, goldNeed)
    table.insert(allReqs, {
      itemId = coinDisplay.itemId,
      label = coinDisplay.label,
      have = goldHave,
      required = goldNeed,
      iconDivisor = coinDisplay.iconDivisor,
      showRawCount = coinDisplay.showRawCount,
    })
  end

  local reqCount = #allReqs
  local totalWidth = (reqCount * REQ_CARD_WIDTH) + (math.max(reqCount - 1, 0) * REQ_CARD_SPACING)
  local panelWidth = getRequirementPanelWidth()
  local x = math.max(math.floor((panelWidth - totalWidth) / 2), 0)
  for _, req in ipairs(allReqs) do
    local have = tonumber(req.have) or 0
    local need = tonumber(req.required) or 0
    local met = have >= need
    local divisor = tonumber(req.iconDivisor) or 1

    local iconNeedCount = need
    local displayHave = have
    local displayNeed = need
    if divisor > 1 then
      iconNeedCount = math.ceil(need / divisor)
      if not req.showRawCount then
        displayHave = math.floor(have / divisor)
        displayNeed = math.ceil(need / divisor)
      end
    end

    local card = g_ui.createWidget('ForgingReqCard', ui.requirementsPanel)
    card:setWidth(REQ_CARD_WIDTH)
    card:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    card:addAnchor(AnchorTop, 'parent', AnchorTop)
    card:setMarginLeft(x)
    card:setMarginTop(4)

    local prettyLabel = prettifyRequirementLabel(req.label)
    local hoverLabel = getRequirementTooltip(req)
    local icon = card:getChildById('reqItemIcon')
    if icon then
      local displayId = tonumber(req.clientId) or tonumber(req.itemId) or 0
      icon:setItemId(displayId)
      icon:setItemCount(math.min(math.max(math.floor(iconNeedCount), 1), 9999))
      icon:setTooltip(hoverLabel)
    end

    if card.setTooltip then
      card:setTooltip(hoverLabel)
    end

    local countLabel = card:getChildById('reqCountLabel')
    if countLabel then
      if req.showRawCount then
        -- Keep required gold fully visible while compacting the player's amount.
        countLabel:setText(formatCompactCount(displayHave) .. '/' .. formatCount(displayNeed))
      else
        countLabel:setText(formatCount(displayHave) .. '/' .. formatCount(displayNeed))
      end
      countLabel:setColor(met and '#7fd992' or '#e05050')
    end

    local nameLabel = card:getChildById('reqNameLabel')
    if nameLabel then
      nameLabel:setText('')
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

local function getInvestCap()
  local maxInvest = tonumber(failConfig.maxInvest) or 20
  local cap = tonumber(availableCorruptedFragments) or 0
  if cap < 0 then
    cap = 0
  end
  if cap > maxInvest then
    cap = maxInvest
  end
  return math.floor(cap)
end

syncInvestLimitLabel = function()
  if not ui.corruptedCountLimitLabel then
    return
  end
  local maxInvest = tonumber(failConfig.maxInvest) or 20
  ui.corruptedCountLimitLabel:setText('/ ' .. tostring(maxInvest))
end

local function getInvestCount()
  if not ui.corruptedCountEdit then
    return 0
  end

  local raw = tonumber(ui.corruptedCountEdit:getText() or '0') or 0
  if raw < 0 then
    raw = 0
  end
  local maxInvest = getInvestCap()
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
  local maxInvest = getInvestCap()
  if value > maxInvest then
    value = maxInvest
  end

  value = math.floor(value)

  investSyncLock = true
  local textValue = tostring(value)
  if ui.corruptedCountEdit:getText() ~= textValue then
    ui.corruptedCountEdit:setText(textValue)
  end
  if ui.corruptedCountSlider then
    if ui.corruptedCountSlider:getValue() ~= value then
      ui.corruptedCountSlider:setValue(value)
    end
  end
  investSyncLock = false
end

local function syncInvestBoundsAndValue(defaultValue)
  local cap = getInvestCap()

  if ui.corruptedCountSlider then
    ui.corruptedCountSlider:setMinimum(0)
    ui.corruptedCountSlider:setMaximum(cap)
    ui.corruptedCountSlider:setStep(1)
    ui.corruptedCountSlider:setVisible(cap > 1)
  end

  syncInvestLimitLabel()

  if defaultValue ~= nil then
    setInvestCount(defaultValue)
  else
    setInvestCount(getInvestCount())
  end
end

local function calculateTargetAffixChance(entry, selectedAffixId, weight)
  if type(entry) ~= 'table' or type(entry.affixOptions) ~= 'table' then
    return nil, nil
  end

  local selectedId = tonumber(selectedAffixId) or 0
  if selectedId <= 0 then
    return nil, nil
  end

  local totalBase = 0
  local selectedBase = 0
  for _, option in ipairs(entry.affixOptions) do
    local base = tonumber(option.baseWeight) or tonumber(option.chance) or 0
    if base > 0 then
      totalBase = totalBase + base
      if tonumber(option.id) == selectedId then
        selectedBase = base
      end
    end
  end

  if totalBase <= 0 or selectedBase <= 0 then
    return nil, nil
  end

  local weightedTotal = totalBase - selectedBase + (selectedBase * weight)
  if weightedTotal <= 0 then
    return nil, nil
  end

  local baseChance = selectedBase / totalBase
  local weightedChance = (selectedBase * weight) / weightedTotal
  return baseChance, weightedChance
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

refreshRiskPreview = function()
  if not ui.failChanceLabel or not ui.weightLabel then
    return
  end

  local invest = isUsingCorrupted() and getInvestCount() or 0

  local failChance = 0
  local weight = 1.0
  if invest > 0 then
    local minC = tonumber(failConfig.minChance) or 0.01
    local maxC = tonumber(failConfig.maxChance) or 0.28
    local kFail = tonumber(failConfig.failExponent) or 0.075
    local maxBonus = tonumber(failConfig.weightMaxBonus) or 3.2
    local kWeight = tonumber(failConfig.weightExponent) or 0.14

    failChance = minC + (maxC - minC) * (1 - math.exp(-kFail * invest))
    weight = 1 + maxBonus * (1 - math.exp(-kWeight * invest))
  end

  local function pickRiskColor(value)
    if value >= 0.30 then
      return '#e05050'
    elseif value >= 0.15 then
      return '#d8b56a'
    end
    return '#7fd992'
  end

  local function pickChanceColor(value)
    if value >= 0.50 then
      return '#7fd992'
    elseif value >= 0.25 then
      return '#d8b56a'
    end
    return '#d9d2bf'
  end

  ui.failChanceLabel:setText(string.format('Ruin risk: %.1f%%', failChance * 100))
  ui.failChanceLabel:setColor(pickRiskColor(failChance))
  if ui.successChanceLabel then
    ui.successChanceLabel:setText(string.format('Forge success: %.1f%%', (1 - failChance) * 100))
    ui.successChanceLabel:setColor(pickChanceColor(1 - failChance))
  end
  ui.weightLabel:setText('Favored affix: -')
  ui.weightLabel:setColor('#d9d2bf')

  if ui.targetAffixChanceLabel then
    local entry = selectedPath and entryByPath[selectedPath] or nil
    local affixId = getSelectedAffixId()
    local baseChance, weightedChance = calculateTargetAffixChance(entry, affixId, weight)
    if baseChance and weightedChance then
      ui.weightLabel:setText(string.format('Favored affix: %.1f%%', weightedChance * 100))
      ui.weightLabel:setColor(pickChanceColor(weightedChance))
    else
      ui.weightLabel:setText('Favored affix: choose one')
    end
  end
end

refreshOptionalWidgetState = function()
  local active = isUsingCorrupted()

  if ui.corruptedCountEdit then
    ui.corruptedCountEdit:setEnabled(active)
  end

  if ui.corruptedCountSlider then
    ui.corruptedCountSlider:setEnabled(active)
  end

  if ui.affixSelector then
    local entry = selectedPath and entryByPath[selectedPath] or nil
    local canUseSelector = active and entry ~= nil and entry.detailsLoaded == true and ui.affixSelector:getOptionsCount() > 0
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

  if entry.detailsLoaded ~= true then
    clearRequirementWidgets()

    if ui.affixSelector then
      ui.affixSelector:clearOptions()
      ui.affixSelector:addOption('Loading item details...', 0)
    end

    setStatus('Loading item details...')
    refreshOptionalWidgetState()
    refreshRiskPreview()
    requestEntryDetails(path)
    return
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
  if ui.toggleAffixBoostButton then
    ui.toggleAffixBoostButton.onClick = function(widget)
      toggleAffixPanelInternal()
    end
  end

  if ui.corruptedCountEdit then
    ui.corruptedCountEdit.onTextChange = function(widget, text)
      if investSyncLock then
        return
      end
      setInvestCount(tonumber(text) or 0)
      refreshRiskPreview()
    end
  end

  if ui.corruptedCountSlider then
    ui.corruptedCountSlider.onValueChange = function(widget, value)
      if investSyncLock then
        return
      end
      setInvestCount(tonumber(value) or 0)
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
  local previousPath = selectedPath
  local previousInvestCount = getInvestCount()
  local previousAffixId = getSelectedAffixId()

  entryByPath = {}
  pathsByClientId = {}
  pathsByItemId = {}
  detailsRequestPending = {}

  if type(data.failConfig) == 'table' then
    failConfig = data.failConfig
  end

  local fragmentClientId = tonumber(data.fragmentClientId)
    or tonumber(data.corruptedFragmentClientId)
    or tonumber(data.fragmentItemId)
    or 0
  if fragmentClientId > 0 then
    corruptedFragmentClientId = fragmentClientId
  end
  refreshCorruptedFragmentIcon()

  if ui.resourceLabel then
    ui.resourceLabel:setText(string.format('Your resources: %d Corrupted Fragment(s)  |  %d gold', tonumber(data.fragmentCount) or 0, tonumber(data.gold) or 0))
  end

  availableCorruptedFragments = tonumber(data.fragmentCount) or 0

  clearSelection()

  if previousInvestCount <= 0 then
    previousInvestCount = math.min(1, getInvestCap())
  end
  syncInvestBoundsAndValue(previousInvestCount)
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
    if previousPath and entryByPath[previousPath] then
      updatePreview(previousPath)
      if ui.affixSelector and previousAffixId > 0 then
        ui.affixSelector:setCurrentOptionByData(previousAffixId, true)
      end
      setStatus('Item selected. Press Upgrade to continue.')
    else
      setStatus('Drop an item into the forge slot to begin.')
    end
  else
    setStatus('No eligible items found in inventory.', '#d26b6b')
  end

  if pendingStatusText then
    setStatus(pendingStatusText, pendingStatusColor)
    pendingStatusText = nil
    pendingStatusColor = nil
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

  if ui.optionalPanel then
    ui.optionalPanel:setVisible(false)
    ui.optionalPanel:setHeight(0)
  end
  refreshCorruptedFragmentIcon()
  if ui.toggleAffixBoostButton then
    ui.toggleAffixBoostButton:setText('+ Corrupted Imbuement')
  end
  local initialSize = window:getSize()
  if initialSize and initialSize.height > OPTIONAL_PANEL_HEIGHT then
    window:resize(initialSize.width, initialSize.height - OPTIONAL_PANEL_HEIGHT)
  end

  if ui.corruptedCountEdit then
    ui.corruptedCountEdit:setEnabled(false)
  end
  if ui.corruptedCountSlider then
    ui.corruptedCountSlider:setEnabled(false)
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

  if data.action == 'details' then
    local path = tostring(data.path or '')
    detailsRequestPending[path] = nil

    if data.success == false then
      setStatus(data.message or 'Failed to load item details.', '#d26b6b')
      return
    end

    local entry = data.entry
    if type(entry) == 'table' and entry.path then
      local merged = entryByPath[entry.path] or {}
      for key, value in pairs(entry) do
        merged[key] = value
      end
      merged.detailsLoaded = true
      entryByPath[entry.path] = merged
    end

    availableCorruptedFragments = tonumber(data.fragmentCount) or availableCorruptedFragments
    if ui.resourceLabel then
      ui.resourceLabel:setText(string.format('Your resources: %d Corrupted Fragment(s)  |  %d gold', availableCorruptedFragments, tonumber(data.gold) or 0))
    end

    if selectedPath and entryByPath[selectedPath] and entryByPath[selectedPath].detailsLoaded == true then
      updatePreview(selectedPath)
    end
    return
  end

  if data.action == 'result' then
    if data.success then
      pendingStatusText = data.message or 'Upgrade successful.'
      pendingStatusColor = '#7fd992'
    else
      pendingStatusText = data.message or 'Upgrade failed.'
      pendingStatusColor = '#d26b6b'
    end

    scheduleEvent(function()
      if modules and modules.game_inventory and modules.game_inventory.refresh then
        modules.game_inventory.refresh()
      end
      if modules and modules.game_containers and modules.game_containers.reloadContainers then
        modules.game_containers.reloadContainers()
      end
    end, 150)

    protocolSend({ action = 'refresh' })
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
    detailsRequestPending = {}
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

  local useCorrupted = isUsingCorrupted()
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

function toggleAffixPanel()
  toggleAffixPanelInternal()
end
