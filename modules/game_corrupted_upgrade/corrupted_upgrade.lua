local FORGING_UPGRADE_OPCODE = 93

local window = nil
local ui = {}
local dragMonitorEvent = nil

local selectedPath = nil
local selectedItem = nil
local entryByPath = {}
local pathsByPosition = {}
local pathsByClientId = {}
local pathsByItemId = {}
local failConfig = {
  minChance = 0.02,
  maxChance = 0.67,
  failExponent = 0.07,
  failCurvePower = 0.85,
  breakRiskThreshold = 0.50,
  highRiskScalePower = 1.00,
  weightMaxBonus = 10.0, -- keeps favored affix chance high at high-risk investment
  weightExponent = 0.16,
  maxInvest = 10,
  over50OverrollChance = 0.10,
  over50OverrollChanceAtMax = 0.30,
  over50OverrollMultiplier = 1.20,
  over50BreakOnFailChance = 0.08,
  over50BreakOnFailChanceAtMax = 0.32,
}

local GOLD_COIN_ITEM_ID = 3031
local PLATINUM_COIN_ITEM_ID = 3035
local CRYSTAL_COIN_ITEM_ID = 3043
local CORRUPTED_FRAGMENT_ITEM_ID = 12787
local corruptedFragmentClientId = CORRUPTED_FRAGMENT_ITEM_ID
local OPTIONAL_PANEL_HEIGHT = 194
local REQUIREMENTS_SECTION_HEIGHT = 108
local WINDOW_BASE_HEIGHT = 202  -- no requirements, no optional panel
local REQ_CARD_WIDTH = 98
local REQ_CARD_SPACING = 4
local REQ_CARD_MIN_WIDTH = 84

local updatePreview
local stopDragMonitor
local destroyWindow
local truncateText

local lastDraggedItem = nil
local lastDraggedPos = nil
local wasDragging = false
local availableCorruptedFragments = 0
local investSyncLock = false
local pendingStatusText = nil
local pendingStatusColor = nil
local detailsRequestPending = {}
local statusLockedByResult = false
local resultFxEvents = {}
local stationModeHint = nil
local currentOpenMode = 'all'
local highRiskConfirmWindow = nil

local function getRiskSnapshot(invest)
  local failChance = 0
  local weight = 1.0
  local overrollBaseChance = tonumber(failConfig.over50OverrollChance) or 0.10
  local overrollMaxChance = tonumber(failConfig.over50OverrollChanceAtMax) or 0.30
  local breakBaseChance = tonumber(failConfig.over50BreakOnFailChance) or 0.08
  local breakMaxChance = tonumber(failConfig.over50BreakOnFailChanceAtMax) or 0.32
  local destructionThreshold = tonumber(failConfig.breakRiskThreshold) or 0.5
  local highRiskScale = 0.0
  local overrollChance = overrollBaseChance
  local breakOnFailChance = breakBaseChance

  if overrollMaxChance < overrollBaseChance then
    overrollMaxChance = overrollBaseChance
  end
  if breakMaxChance < breakBaseChance then
    breakMaxChance = breakBaseChance
  end

  if invest > 0 then
    local maxInvest = tonumber(failConfig.maxInvest) or 10
    local minC = tonumber(failConfig.minChance) or 0.01
    local maxC = tonumber(failConfig.maxChance) or 0.67
    local curvePower = tonumber(failConfig.failCurvePower) or 0.85
    local maxBonus = tonumber(failConfig.weightMaxBonus) or 3.2
    local kWeight = tonumber(failConfig.weightExponent) or 0.14
    local scalePower = tonumber(failConfig.highRiskScalePower) or 1.00

    if curvePower < 1.0 then
      curvePower = 1.0
    end
    if scalePower < 0.1 then
      scalePower = 0.1
    end

    local ratio = math.min(math.max(invest / math.max(maxInvest, 1), 0), 1)
    failChance = minC + (maxC - minC) * (ratio ^ curvePower)
    weight = 1 + maxBonus * (1 - math.exp(-kWeight * invest))

    if failChance >= destructionThreshold and maxC >= destructionThreshold then
      local scaleRatio = 0
      if maxC > destructionThreshold then
        scaleRatio = math.min(math.max((failChance - destructionThreshold) / (maxC - destructionThreshold), 0), 1)
      else
        scaleRatio = 1
      end
      highRiskScale = scaleRatio ^ scalePower
      overrollChance = overrollBaseChance + (overrollMaxChance - overrollBaseChance) * highRiskScale
      breakOnFailChance = breakBaseChance + (breakMaxChance - breakBaseChance) * highRiskScale
    end
  end

  return {
    failChance = failChance,
    weight = weight,
    destructionThreshold = destructionThreshold,
    highRiskActive = failChance >= destructionThreshold,
    overrollChance = overrollChance,
    breakOnFailChance = breakOnFailChance,
    overrollBaseChance = overrollBaseChance,
    overrollMaxChance = overrollMaxChance,
    overrollBonusPct = math.floor(((tonumber(failConfig.over50OverrollMultiplier) or 1.20) - 1.0) * 100 + 0.5),
  }
end

local function getModeUiStrings()
  if currentOpenMode == 'wand_only' then
    return {
      itemLabel = 'Focus for Arcane Ritual',
      requirementsLabel = 'Arcane Ritual Requirements',
      toggleCollapsed = '+ Arcane Imbuement',
      toggleExpanded = '- Arcane Imbuement',
      toggleTooltip = 'Fragments 1-6: failed upgrade consumes materials only. Fragments 7-10: failure risk is above 50%, failed upgrade can destroy the item, and overroll chance increases with risk.',
      successPrefix = 'Ritual success',
      bannerSuccess = 'RITUAL SUCCESS',
      bannerFailure = 'RITUAL FAILED',
    }
  end

  if currentOpenMode == 'no_wand' then
    return {
      itemLabel = 'Item to Temper',
      requirementsLabel = 'Tempering Requirements',
      toggleCollapsed = '+ Corrupted Imbuement',
      toggleExpanded = '- Corrupted Imbuement',
      toggleTooltip = 'Fragments 1-6: failed upgrade consumes materials only. Fragments 7-10: failure risk is above 50%, failed upgrade can destroy the item, and overroll chance increases with risk.',
      successPrefix = 'Forge success',
      bannerSuccess = 'FORGE SUCCESS',
      bannerFailure = 'FORGE FAILED',
    }
  end

  if currentOpenMode == 'distance_only' then
    return {
      itemLabel = 'Ranged Weapon to Refine',
      requirementsLabel = 'Precision Refinement Requirements',
      toggleCollapsed = '+ Corrupted Fletching',
      toggleExpanded = '- Corrupted Fletching',
      toggleTooltip = 'Fragments 1-6: failed upgrade consumes materials only. Fragments 7-10: failure risk is above 50%, failed upgrade can destroy the item, and overroll chance increases with risk.',
      successPrefix = 'Refinement success',
      bannerSuccess = 'REFINEMENT SUCCESS',
      bannerFailure = 'REFINEMENT FAILED',
    }
  end

  return {
    itemLabel = 'Item to Upgrade',
    requirementsLabel = 'Upgrade Requirements',
    toggleCollapsed = '+ Optional Imbuement',
    toggleExpanded = '- Optional Imbuement',
    toggleTooltip = 'Fragments 1-6: failed upgrade consumes materials only. Fragments 7-10: failure risk is above 50%, failed upgrade can destroy the item, and overroll chance increases with risk.',
    successPrefix = 'Upgrade success',
    bannerSuccess = 'UPGRADE SUCCESS',
    bannerFailure = 'UPGRADE FAILED',
  }
end

local function applyModeUiStrings()
  local modeText = getModeUiStrings()

  if ui.itemToForgeLabel then
    ui.itemToForgeLabel:setText(modeText.itemLabel)
  end

  if ui.reqTitleLabel then
    ui.reqTitleLabel:setText(modeText.requirementsLabel)
  end

  if ui.toggleAffixBoostButton then
    if ui.optionalPanel and ui.optionalPanel:isVisible() then
      ui.toggleAffixBoostButton:setText(modeText.toggleExpanded)
    else
      ui.toggleAffixBoostButton:setText(modeText.toggleCollapsed)
    end
    ui.toggleAffixBoostButton:setTooltip(modeText.toggleTooltip)
  end
end

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
  ui.requirementsSectionPanel = findWidgetById(window, 'requirementsSectionPanel')
  ui.requirementsPanel = findWidgetById(window, 'requirementsPanel')

  ui.resourceLabel = findWidgetById(window, 'resourceLabel')
  ui.resultBanner = findWidgetById(window, 'resultBanner')
  ui.statusLabel = findWidgetById(window, 'statusLabel')
  ui.itemToForgeLabel = findWidgetById(window, 'itemToForgeLabel')
  ui.reqTitleLabel = findWidgetById(window, 'reqTitleLabel')
  ui.itemNameLabel = findWidgetById(window, 'itemNameLabel')
  ui.itemTypeLabel = findWidgetById(window, 'itemTypeLabel')

  ui.tierLabel = findWidgetById(window, 'tierLabel')
  ui.rollsLabel = findWidgetById(window, 'rollsLabel')
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
  ui.acceptButton = findWidgetById(window, 'acceptButton')

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

local function setAutoStatus(text, color)
  if statusLockedByResult then
    return
  end

  setStatus(text, color)
end

local function clearResultStatusLock()
  statusLockedByResult = false
end

local function clearResultFxEvents()
  for i = 1, #resultFxEvents do
    removeEvent(resultFxEvents[i])
  end
  resultFxEvents = {}
end

local function resetResultFxVisuals()
  if ui.resultBanner then
    ui.resultBanner:setVisible(false)
    ui.resultBanner:setOpacity(1.0)
  end

  if ui.itemDropZone then
    ui.itemDropZone:setBorderWidth(1)
    ui.itemDropZone:setBorderColor('#5a5040')
  end

  if ui.acceptButton then
    ui.acceptButton:setText('Upgrade')
    ui.acceptButton:setEnabled(true)
  end
end

local function playResultFeedback(success)
  clearResultFxEvents()
  resetResultFxVisuals()

  local accent = success and '#7fd992' or '#e05050'
  local dim = success and '#4f8f62' or '#8f3d3d'
  local modeText = getModeUiStrings()
  local bannerText = success and modeText.bannerSuccess or modeText.bannerFailure
  local buttonText = success and 'SUCCESS' or 'FAILED'

  if ui.resultBanner then
    ui.resultBanner:setText(bannerText)
    ui.resultBanner:setColor(accent)
    ui.resultBanner:setVisible(true)
  end

  if ui.itemDropZone then
    ui.itemDropZone:setBorderWidth(2)
    ui.itemDropZone:setBorderColor(accent)
  end

  if ui.acceptButton then
    ui.acceptButton:setText(buttonText)
    ui.acceptButton:setEnabled(false)
  end

  local pulse = { accent, dim, accent, dim, accent }
  for i = 1, #pulse do
    resultFxEvents[#resultFxEvents + 1] = scheduleEvent(function()
      if ui.itemDropZone then
        ui.itemDropZone:setBorderColor(pulse[i])
      end
      if ui.resultBanner then
        ui.resultBanner:setColor(pulse[i])
        ui.resultBanner:setOpacity((i % 2 == 0) and 0.85 or 1.0)
      end
    end, (i - 1) * 140)
  end

  resultFxEvents[#resultFxEvents + 1] = scheduleEvent(function()
    if ui.acceptButton then
      ui.acceptButton:setText('Upgrade')
      ui.acceptButton:setEnabled(true)
    end
  end, 850)

  resultFxEvents[#resultFxEvents + 1] = scheduleEvent(function()
    if ui.resultBanner then
      ui.resultBanner:setVisible(false)
      ui.resultBanner:setOpacity(1.0)
    end
    if ui.itemDropZone then
      ui.itemDropZone:setBorderWidth(1)
      ui.itemDropZone:setBorderColor('#5a5040')
    end
  end, 1900)
end

local function resizeWindow()
  if not window then return end
  local h = WINDOW_BASE_HEIGHT
  if ui.requirementsSectionPanel and ui.requirementsSectionPanel:isVisible() then
    h = h + REQUIREMENTS_SECTION_HEIGHT
  end
  if ui.optionalPanel and ui.optionalPanel:isVisible() then
    h = h + OPTIONAL_PANEL_HEIGHT
  end
  window:resize(window:getWidth(), h)
end

local function applySelectionLayout(hasSelection)
  hasSelection = hasSelection == true
  if ui.requirementsSectionPanel then
    ui.requirementsSectionPanel:setVisible(hasSelection)
    ui.requirementsSectionPanel:setHeight(hasSelection and REQUIREMENTS_SECTION_HEIGHT or 0)
  end
  resizeWindow()
end

local function makePositionKey(pos)
  if type(pos) ~= 'table' then
    return nil
  end

  local x = tonumber(pos.x)
  local y = tonumber(pos.y)
  local z = tonumber(pos.z)
  if not x or not y or not z then
    return nil
  end

  return string.format('%d:%d:%d', x, y, z)
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

  if isExpanded then
    -- collapse
    ui.optionalPanel:setVisible(false)
    ui.optionalPanel:setHeight(0)
    if ui.toggleAffixBoostButton then
      ui.toggleAffixBoostButton:setText(getModeUiStrings().toggleCollapsed)
    end
  else
    -- expand
    ui.optionalPanel:setHeight(OPTIONAL_PANEL_HEIGHT)
    ui.optionalPanel:setVisible(true)
    refreshCorruptedFragmentIcon()
    if ui.toggleAffixBoostButton then
      ui.toggleAffixBoostButton:setText(getModeUiStrings().toggleExpanded)
    end
    syncInvestLimitLabel()
    refreshOptionalWidgetState()
    refreshRiskPreview()
  end
  resizeWindow()
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
  -- Use window width directly to avoid reading the panel width before the first
  -- layout pass (which returns 0 and causes cards to jump horizontally).
  -- requirementsPanel uses 10px margins on both sides.
  if window and window.getWidth then
    local w = tonumber(window:getWidth()) or 0
    if w > 20 then
      return math.floor(w - 20)
    end
  end

  return 430
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
  local availableSpacing = math.max(reqCount - 1, 0) * REQ_CARD_SPACING
  -- Panel is window width minus 20px (10px margin each side).
  local panelWidth = (window and window.getWidth) and (tonumber(window:getWidth()) - 20) or 440
  panelWidth = math.max(panelWidth, 100)
  -- Use ideal card width, but shrink if cards would overflow the panel.
  local cardWidth = REQ_CARD_WIDTH
  if reqCount > 0 then
    local maxCardWidth = math.floor((panelWidth - availableSpacing) / reqCount)
    if maxCardWidth < cardWidth then
      cardWidth = math.max(maxCardWidth, REQ_CARD_MIN_WIDTH)
    end
  end
  local totalWidth = (reqCount * cardWidth) + availableSpacing

  -- Create a centered inner container of exact total width.
  -- Anchoring horizontalCenter to parent.horizontalCenter guarantees centering
  -- regardless of panel width or number of cards.
  local innerPanel = g_ui.createWidget('Panel', ui.requirementsPanel)
  innerPanel:setPhantom(true)
  innerPanel:setWidth(totalWidth)
  innerPanel:setHeight(82)
  innerPanel:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
  innerPanel:addAnchor(AnchorTop, 'parent', AnchorTop)
  innerPanel:setMarginTop(0)

  local x = 0
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

    local card = g_ui.createWidget('ForgingReqCard', innerPanel)
    card:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    card:addAnchor(AnchorTop, 'parent', AnchorTop)
    card:setWidth(cardWidth)
    card:setMarginLeft(x)
    card:setMarginTop(0)

    local prettyLabel = prettifyRequirementLabel(req.label)
    local hoverLabel = getRequirementTooltip(req)
    local icon = card:getChildById('reqItemIcon')
    if icon then
      local displayId = tonumber(req.clientId) or tonumber(req.itemId) or 0
      icon:setItemId(0)
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

    x = x + cardWidth + REQ_CARD_SPACING
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
  local risk = getRiskSnapshot(invest)
  local failChance = risk.failChance
  local weight = risk.weight

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

  local hasInvest = isUsingCorrupted() and invest > 0
  local successChance = 1 - failChance

  ui.failChanceLabel:setText(string.format('Failure Risk: %.1f%%', failChance * 100))
  ui.failChanceLabel:setColor(pickRiskColor(failChance))

  if ui.successChanceLabel then
    ui.successChanceLabel:setVisible(true)
    ui.successChanceLabel:setText(string.format('%s: %.1f%%', getModeUiStrings().successPrefix, successChance * 100))
    ui.successChanceLabel:setColor(pickChanceColor(successChance))
  end

  ui.weightLabel:setText('Favored affix chance: -')
  ui.weightLabel:setColor('#d9d2bf')

  local entry = selectedPath and entryByPath[selectedPath] or nil
  local affixId = getSelectedAffixId()
  local _, weightedChance = calculateTargetAffixChance(entry, affixId, weight)
  if weightedChance then
    ui.weightLabel:setText(string.format('Favored Affix Chance: %.1f%%', weightedChance * 100))
    ui.weightLabel:setColor(pickChanceColor(weightedChance))
  else
    ui.weightLabel:setText('Favored Affix Chance: choose one')
  end

  if ui.targetAffixChanceLabel then
    ui.targetAffixChanceLabel:setVisible(true)

    if not hasInvest then
      ui.targetAffixChanceLabel:setText('Add Corrupted Fragments to preview risk and reward scaling.')
      ui.targetAffixChanceLabel:setColor('#d9d2bf')
    elseif risk.highRiskActive then
      ui.targetAffixChanceLabel:setText('High-Risk Active: item can break on failed craft. Confirmation popup shows full details.')
      ui.targetAffixChanceLabel:setColor('#e05050')
    else
      ui.targetAffixChanceLabel:setText(string.format('Safe Zone: no item break risk below %.0f%% failure.', risk.destructionThreshold * 100))
      ui.targetAffixChanceLabel:setColor('#7fd992')
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

local function canAttemptUpgrade(invest)
  local entry = selectedPath and entryByPath[selectedPath] or nil
  if not entry then
    return false, 'No item selected.'
  end

  if entry.detailsLoaded ~= true then
    requestEntryDetails(selectedPath)
    return false, 'Loading item details...'
  end

  for _, req in ipairs(entry.requirements or {}) do
    local have = tonumber(req.have) or 0
    local need = tonumber(req.required) or 0
    if have < need then
      local label = tostring(req.label or 'material')
      return false, string.format('Missing %s (%d/%d).', label, have, need)
    end
  end

  local goldHave = tonumber(entry.goldHave) or 0
  local goldNeed = tonumber(entry.goldRequired) or 0
  if goldHave < goldNeed then
    return false, string.format('Missing gold (%d/%d).', goldHave, goldNeed)
  end

  if invest > 0 and (tonumber(availableCorruptedFragments) or 0) < invest then
    return false, string.format('Not enough Corrupted Fragments (%d/%d).', tonumber(availableCorruptedFragments) or 0, invest)
  end

  return true, nil
end

local function clearSelection()
  selectedPath = nil
  selectedItem = nil
  applySelectionLayout(false)

  -- Collapse the optional/affix panel if it was left open
  if ui.optionalPanel and ui.optionalPanel:isVisible() then
    ui.optionalPanel:setVisible(false)
    ui.optionalPanel:setHeight(0)
    if ui.toggleAffixBoostButton then
      ui.toggleAffixBoostButton:setText(getModeUiStrings().toggleCollapsed)
    end
  end

  -- Ensure window height matches collapsed layout after clearing selection.
  resizeWindow()

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

  applySelectionLayout(true)

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

    setAutoStatus('Loading item details...')
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
    return nil, nil
  end

  local sourcePos = nil
  if type(w.position) == 'table' then
    sourcePos = {
      x = tonumber(w.position.x) or 0,
      y = tonumber(w.position.y) or 0,
      z = tonumber(w.position.z) or 0,
    }
  end

  if type(w.getItem) == 'function' then
    local ok, fromGetItem = pcall(function() return w:getItem() end)
    if ok and fromGetItem and fromGetItem.isItem and fromGetItem:isItem() then
      if not sourcePos then
        local itemPos = fromGetItem:getPosition()
        if type(itemPos) == 'table' then
          sourcePos = {
            x = tonumber(itemPos.x) or 0,
            y = tonumber(itemPos.y) or 0,
            z = tonumber(itemPos.z) or 0,
          }
        end
      end
      return fromGetItem, sourcePos
    end
  end

  local dragThing = w.currentDragThing
  if dragThing and dragThing.isItem and dragThing:isItem() then
    if not sourcePos then
      local itemPos = dragThing:getPosition()
      if type(itemPos) == 'table' then
        sourcePos = {
          x = tonumber(itemPos.x) or 0,
          y = tonumber(itemPos.y) or 0,
          z = tonumber(itemPos.z) or 0,
        }
      end
    end
    return dragThing, sourcePos
  end

  return nil, sourcePos
end

local function trySelectItem(item, sourcePos)
  clearResultStatusLock()

  if not item or not item.isItem or not item:isItem() then
    setStatus('Drop an inventory item here.', '#d26b6b')
    return false
  end

  local pos = sourcePos
  if type(pos) ~= 'table' then
    local itemPos = item:getPosition()
    if type(itemPos) == 'table' then
      pos = {
        x = tonumber(itemPos.x) or 0,
        y = tonumber(itemPos.y) or 0,
        z = tonumber(itemPos.z) or 0,
      }
    end
  end

  if type(pos) ~= 'table' then
    setStatus('Could not resolve source position for this item.', '#d26b6b')
    return false
  end

  selectedItem = item
  setStatus('Resolving selected item...')
  protocolSend({
    action = 'resolve',
    sourcePos = pos,
  })
  return true
end

stopDragMonitor = function()
  if dragMonitorEvent then
    removeEvent(dragMonitorEvent)
    dragMonitorEvent = nil
  end
  wasDragging = false
  lastDraggedItem = nil
  lastDraggedPos = nil
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
        local item, sourcePos = resolveItemFromWidget(draggingWidget)
        if item then
          lastDraggedItem = item
          lastDraggedPos = sourcePos
        end
        wasDragging = true
      elseif wasDragging then
        if lastDraggedItem and overSlot then
          trySelectItem(lastDraggedItem, lastDraggedPos)
        end
        wasDragging = false
        lastDraggedItem = nil
        lastDraggedPos = nil
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
    local item, sourcePos = resolveItemFromWidget(droppedWidget)
    return trySelectItem(item, sourcePos)
  end

  if ui.previewPanel then
    ui.previewPanel.onDrop = function(self, droppedWidget, mousePos)
      if ui.itemDropZone then ui.itemDropZone:setBorderWidth(0) end
      local item, sourcePos = resolveItemFromWidget(droppedWidget)
      return trySelectItem(item, sourcePos)
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
        local item, sourcePos = resolveItemFromWidget(draggingWidget)
        if trySelectItem(item, sourcePos) then
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
  pathsByPosition = {}
  pathsByClientId = {}
  pathsByItemId = {}
  detailsRequestPending = {}

  if type(data.failConfig) == 'table' then
    failConfig = data.failConfig
  end

  currentOpenMode = tostring(data.openMode or 'all')

  if window then
    window:setText(tostring(data.stationTitle or 'Forging Station'))
  end
  stationModeHint = tostring(data.modeHint or '')
  applyModeUiStrings()

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
      local posKey = makePositionKey(entry.sourcePos)

      if posKey then
        pathsByPosition[posKey] = pathsByPosition[posKey] or {}
        table.insert(pathsByPosition[posKey], entry.path)
      end

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
      setAutoStatus('Item selected. Press Upgrade to continue.')
    else
      setAutoStatus(stationModeHint ~= '' and stationModeHint or 'Drop an item into the upgrade slot to begin.')
    end
  else
    local emptyMsg = 'No eligible items found in inventory.'
    if stationModeHint and stationModeHint ~= '' then
      emptyMsg = stationModeHint
    end
    setAutoStatus(emptyMsg, '#d26b6b')
  end

  if pendingStatusText then
    setStatus(pendingStatusText, pendingStatusColor)
    statusLockedByResult = true
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
  applySelectionLayout(false)
  refreshCorruptedFragmentIcon()
  applyModeUiStrings()
  resizeWindow()

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
      clearResultStatusLock()
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
      setAutoStatus('Item selected. Press Upgrade to continue.')
    end
    return
  end

  if data.action == 'resolve' then
    if data.success == false then
      setStatus(data.message or 'Failed to resolve selected item.', '#d26b6b')
      return
    end

    local path = tostring(data.path or '')
    local entry = data.entry
    if type(entry) == 'table' and entry.path then
      local merged = entryByPath[entry.path] or {}
      for key, value in pairs(entry) do
        merged[key] = value
      end
      entryByPath[entry.path] = merged
    end

    availableCorruptedFragments = tonumber(data.fragmentCount) or availableCorruptedFragments
    if ui.resourceLabel then
      ui.resourceLabel:setText(string.format('Your resources: %d Corrupted Fragment(s)  |  %d gold', availableCorruptedFragments, tonumber(data.gold) or 0))
    end

    if path == '' or not entryByPath[path] then
      setStatus('Selected item is no longer available. Try again.', '#d26b6b')
      return
    end

    updatePreview(path)
    setStatus('Item selected. Press Upgrade to continue.')
    return
  end

  if data.action == 'result' then
    playResultFeedback(data.success == true)

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
    clearResultFxEvents()

    if highRiskConfirmWindow then
      highRiskConfirmWindow:destroy()
      highRiskConfirmWindow = nil
    end

    if window then
      window:destroy()
      window = nil
    end
    ui = {}
    selectedPath = nil
    selectedItem = nil
    entryByPath = {}
    pathsByPosition = {}
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
    clearResultStatusLock()
    setStatus('No item selected.', '#d26b6b')
    return
  end

  local useCorrupted = isUsingCorrupted()
  local invest = useCorrupted and getInvestCount() or 0
  local selectedAffixId = useCorrupted and getSelectedAffixId() or 0

  if invest > 0 and selectedAffixId <= 0 then
    clearResultStatusLock()
    setStatus('Pick one affix when using Corrupted Fragments.', '#d26b6b')
    return
  end

  local canAttempt, attemptMessage = canAttemptUpgrade(invest)
  if not canAttempt then
    clearResultStatusLock()
    setStatus(attemptMessage or 'Missing requirements.', '#d26b6b')
    return
  end

  local function sendConfirm()
    protocolSend({
      action = 'confirm',
      path = selectedPath,
      corruptedInvestCount = invest,
      selectedAffixId = selectedAffixId,
    })
  end

  if invest > 0 then
    local risk = getRiskSnapshot(invest)
    if risk.highRiskActive then
      if highRiskConfirmWindow then
        highRiskConfirmWindow:destroy()
        highRiskConfirmWindow = nil
      end

      local failPct = math.floor(risk.failChance * 100 + 0.5)
      local breakPct = math.floor(risk.breakOnFailChance * 100 + 0.5)
      local overrollPct = math.floor(risk.overrollChance * 100 + 0.5)
      local overrollBonusPct = risk.overrollBonusPct

      local message = string.format(
        'This upgrade can break the item on failure.\n\nFailure risk: %d%%\nIf it fails, item break chance: %d%%\nOverroll chance: %d%% (+%d%% max value)\n\nDo you want to proceed?',
        failPct,
        breakPct,
        overrollPct,
        overrollBonusPct
      )

      local function onUpgrade()
        if highRiskConfirmWindow then
          highRiskConfirmWindow:destroy()
          highRiskConfirmWindow = nil
        end
        sendConfirm()
      end

      local function onCancel()
        if highRiskConfirmWindow then
          highRiskConfirmWindow:destroy()
          highRiskConfirmWindow = nil
        end
      end

      highRiskConfirmWindow = displayGeneralBox(
        'Confirm Upgrade',
        message,
        {
          { text = 'Upgrade', callback = onUpgrade },
          { text = 'Cancel', callback = onCancel, isDefaultCancel = true },
          anchor = AnchorHorizontalCenter,
        },
        onUpgrade,
        onCancel
      )
      return
    end
  end

  sendConfirm()
end

function refresh()
  protocolSend({ action = 'refresh' })
end

function decline()
  clearResultFxEvents()

  if highRiskConfirmWindow then
    highRiskConfirmWindow:destroy()
    highRiskConfirmWindow = nil
  end

  stopDragMonitor()
  if window then
    window:destroy()
    window = nil
  end
  ui = {}
  selectedPath = nil
  selectedItem = nil
  entryByPath = {}
  pathsByPosition = {}
  pathsByClientId = {}
  pathsByItemId = {}
end

function toggleAffixPanel()
  toggleAffixPanelInternal()
end
