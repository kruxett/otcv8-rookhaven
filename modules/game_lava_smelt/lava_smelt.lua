---@diagnostic disable: undefined-global, undefined-field, need-check-nil
local LAVA_SMELT_OPCODE = 98
local window = nil
local rerollConfirmWindow = nil
local slotWidgets = {}
local slotData = {}
local ui = {}
local rerollItemIds = {
  [12805] = true,
  [12807] = true,
  [12808] = true,
  [12810] = true,
  [12813] = true,
  [12814] = true,
  [12819] = true,
}

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

local function positionKey(pos)
  if type(pos) ~= 'table' then
    return ''
  end
  return string.format('%s:%s:%s', tostring(pos.x), tostring(pos.y), tostring(pos.z))
end

local function copyPos(pos)
  if type(pos) ~= 'table' then
    return nil
  end
  return {
    x = tonumber(pos.x) or 0,
    y = tonumber(pos.y) or 0,
    z = tonumber(pos.z) or 0,
  }
end

local function protocolSend(payload)
  local protocol = g_game.getProtocolGame()
  if protocol then
    protocol:sendExtendedOpcode(LAVA_SMELT_OPCODE, json.encode(payload))
  end
end

local function destroyRerollConfirm()
  if rerollConfirmWindow then
    rerollConfirmWindow:destroy()
    rerollConfirmWindow = nil
  end
end

local function destroyWindow()
  destroyRerollConfirm()
  if window then
    window:destroy()
    window = nil
  end
  slotWidgets = {}
  slotData = {}
  ui = {}
end

local function setStatus(text, color)
  if ui.statusLabel then
    ui.statusLabel:setText(text or '')
    ui.statusLabel:setColor(color or '#d9d2bf')
  end
end

local function setResult(text, color)
  if ui.resultLabel then
    ui.resultLabel:setText(text or '')
    ui.resultLabel:setColor(color or '#cdbb91')
  end
end

local function applySlotVisual(index)
  local widget = slotWidgets[index]
  local data = slotData[index]
  if not widget then
    return
  end

  local item = widget:getChildById('item')
  local nameLabel = widget:getChildById('nameLabel')
  local tierLabel = widget:getChildById('tierLabel')
  if not item or not nameLabel or not tierLabel then
    return
  end

  if not data then
    item:setItemId(0)
    nameLabel:setText('Drop a rarity item here')
    tierLabel:setText('Right-click to clear this slot')
    tierLabel:setColor('#9e9080')
    return
  end

  item:setItemId(data.clientId or data.itemId or 0)
  nameLabel:setText(data.name or 'Selected item')
  tierLabel:setText(string.format('%s item   Fee: %d gold', data.tierLabel or '-', tonumber(data.fee) or 0))

  local tier = (data.tier or ''):lower()
  if tier == 'legendary' then
    tierLabel:setColor('#f0cf67')
  elseif tier == 'epic' then
    tierLabel:setColor('#b8a7ff')
  elseif tier == 'rare' then
    tierLabel:setColor('#8dd0ff')
  else
    tierLabel:setColor('#cdbb91')
  end
end

local function collectPositions()
  local positions = {}
  for index = 1, 6 do
    if slotData[index] and slotData[index].pos then
      positions[#positions + 1] = copyPos(slotData[index].pos)
    end
  end
  return positions
end

local function refreshSlots()
  for index = 1, 6 do
    applySlotVisual(index)
  end
end

local function requestPreview()
  protocolSend({ action = 'preview', positions = collectPositions() })
end

local function clearSlot(index, skipPreview)
  slotData[index] = nil
  applySlotVisual(index)
  if not skipPreview then
    requestPreview()
  end
end

local function clearAll()
  for index = 1, 6 do
    slotData[index] = nil
  end
  refreshSlots()
  requestPreview()
end

local function findFirstEmptySlot()
  for index = 1, 6 do
    if not slotData[index] then
      return index
    end
  end
  return nil
end

local function rebuildFromPreview(entries)
  slotData = {}
  for index = 1, math.min(#(entries or {}), 6) do
    local entry = entries[index]
    slotData[index] = {
      pos = copyPos(entry.pos),
      itemId = entry.itemId,
      clientId = entry.clientId,
      name = entry.name,
      tier = entry.tier,
      tierLabel = entry.tierLabel,
      fee = entry.fee,
    }
  end
  refreshSlots()
end

local function applyPreview(preview)
  preview = preview or {}
  rebuildFromPreview(preview.entries or {})

  if ui.selectedCountLabel then
    ui.selectedCountLabel:setText(string.format('Selected: %d / 6', tonumber(preview.totalCount) or 0))
  end
  if ui.goldCostLabel then
    ui.goldCostLabel:setText(string.format('Gold Fee: %d', tonumber(preview.totalFee) or 0))
  end
  if ui.rarityBreakdownLabel then
    local counts = preview.counts or {}
    ui.rarityBreakdownLabel:setText(string.format('Rare: %d  Epic: %d  Legendary: %d', tonumber(counts.rare) or 0, tonumber(counts.epic) or 0, tonumber(counts.legendary) or 0))
  end
  if ui.smeltButton then
    ui.smeltButton:setEnabled((tonumber(preview.totalCount) or 0) > 0)
  end

  if tonumber(preview.ignored) and tonumber(preview.ignored) > 0 then
    setStatus(string.format('%d invalid selection(s) were ignored. The forge only accepts rarity gear.', tonumber(preview.ignored) or 0), '#e05050')
  elseif (tonumber(preview.totalCount) or 0) > 0 then
    setStatus('The forge is ready. Smelting destroys all listed items.', '#d9d2bf')
  else
    setStatus('The forge accepts only rarity gear.', '#d9d2bf')
  end
end

local function handleDrop(index, droppedWidget)
  if not droppedWidget or type(droppedWidget.getItem) ~= 'function' then
    return
  end

  local item = droppedWidget:getItem()
  if not item then
    return
  end

  local pos = item:getPosition()
  local key = positionKey(pos)
  if key == '' then
    return
  end

  for slotIndex = 1, 6 do
    if slotData[slotIndex] and positionKey(slotData[slotIndex].pos) == key then
      setStatus('That item is already in the smelting queue.', '#e05050')
      return
    end
  end

  local targetIndex = index or findFirstEmptySlot()
  if not targetIndex then
    setStatus('The smelting queue is full.', '#e05050')
    return
  end

  slotData[targetIndex] = {
    pos = copyPos(pos),
    itemId = item:getId(),
    name = 'Checking item...',
    tier = '',
    tierLabel = '-',
    fee = 0,
  }
  applySlotVisual(targetIndex)
  requestPreview()
end

local function bindWindow()
  ui.selectedCountLabel = findWidgetById(window, 'selectedCountLabel')
  ui.goldCostLabel = findWidgetById(window, 'goldCostLabel')
  ui.rarityBreakdownLabel = findWidgetById(window, 'rarityBreakdownLabel')
  ui.statusLabel = findWidgetById(window, 'statusLabel')
  ui.resultLabel = findWidgetById(window, 'resultLabel')
  ui.clearButton = findWidgetById(window, 'clearButton')
  ui.smeltButton = findWidgetById(window, 'smeltButton')
  ui.closeButton = findWidgetById(window, 'closeButton')

  slotWidgets = {}
  for index = 1, 6 do
    local slot = findWidgetById(window, 'slot' .. index)
    slotWidgets[index] = slot
    if slot then
      slot.onDrop = function(widget, droppedWidget, mousePos)
        handleDrop(index, droppedWidget)
      end
      slot.onMouseRelease = function(widget, mousePos, mouseButton)
        if mouseButton == MouseRightButton then
          clearSlot(index)
          return true
        end
        return false
      end
    end
  end

  if ui.clearButton then
    ui.clearButton.onClick = clearAll
  end
  if ui.smeltButton then
    ui.smeltButton.onClick = function()
      protocolSend({ action = 'smelt', positions = collectPositions() })
    end
    ui.smeltButton:setEnabled(false)
  end
  if ui.closeButton then
    ui.closeButton.onClick = function()
      modules.game_lava_smelt.close()
    end
  end

  refreshSlots()
end

local function ensureWindow()
  if window then
    return true
  end

  window = g_ui.displayUI('lava_smelt', rootWidget)
  if not window then
    return false
  end

  bindWindow()
  return true
end

local function showRerollPrompt(data)
  destroyRerollConfirm()

  local message = string.format('Use %s to %s on %s (%s item)?', data.materialName or 'this material', data.modeText or 'reroll', data.targetName or 'the selected item', (data.tierLabel or 'Unknown'):lower())

  rerollConfirmWindow = displayGeneralBox(tr('Confirm Reroll'), message, {
    {
      text = tr('Confirm'),
      callback = function()
        if rerollConfirmWindow then
          rerollConfirmWindow:ok()
        end
        protocolSend({ action = 'reroll_confirm' })
      end
    },
    {
      text = tr('Cancel'),
      callback = function()
        if rerollConfirmWindow then
          rerollConfirmWindow:cancel()
        end
        protocolSend({ action = 'reroll_cancel' })
      end
    }
  })
end

local function formatYieldText(yields)
  if type(yields) ~= 'table' or #yields == 0 then
    return ''
  end

  local parts = {}
  for index = 1, #yields do
    local entry = yields[index]
    parts[#parts + 1] = string.format('%dx %s', tonumber(entry.count) or 0, entry.name or 'Material')
  end
  return 'Latest yield: ' .. table.concat(parts, ', ')
end

local function onLavaSmeltOpcode(protocol, opcode, buffer)
  local data = json.decode(buffer)
  if not data then
    return
  end

  if data.action == 'reroll_prompt' then
    showRerollPrompt(data)
    return
  end

  if data.action == 'reroll_result' then
    destroyRerollConfirm()
    if data.success then
      modules.game_textmessage.displayStatusMessage(data.message or 'Reroll complete.')
    else
      modules.game_textmessage.displayFailureMessage(data.message or 'Reroll failed.')
    end
    setStatus(data.message or '', data.success and '#7fd992' or '#e05050')
    return
  end

  if not ensureWindow() then
    return
  end

  window:show()
  window:raise()
  window:focus()

  if data.action == 'open' then
    applyPreview(data.preview or {})
    setResult('')
    return
  end

  if data.action == 'preview' then
    applyPreview(data)
    return
  end

  if data.action == 'result' then
    if data.preview then
      applyPreview(data.preview)
    end
    setStatus(data.message or '', data.success and '#7fd992' or '#e05050')
    setResult(formatYieldText(data.yields), data.success and '#cdbb91' or '#c47c7c')
    if data.success then
      modules.game_textmessage.displayStatusMessage(data.message or 'Smelting complete.')
    else
      modules.game_textmessage.displayFailureMessage(data.message or 'Smelting failed.')
    end
  end
end

local function onGameEnd()
  destroyWindow()
end

local function rerollMenuCondition(menuPosition, lookThing, useThing, creatureThing)
  return useThing and useThing:isItem() and rerollItemIds[useThing:getId()] == true
end

local function rerollMenuCallback(menuPosition, lookThing, useThing, creatureThing)
  if useThing then
    modules.game_interface.startUseWith(useThing)
  end
end

function init()
  connect(g_game, {
    onGameEnd = onGameEnd,
  })
  ProtocolGame.registerExtendedOpcode(LAVA_SMELT_OPCODE, onLavaSmeltOpcode)
  modules.game_interface.addMenuHook('lava_smelt', 'Reforge with...', rerollMenuCallback, rerollMenuCondition)
end

function terminate()
  disconnect(g_game, {
    onGameEnd = onGameEnd,
  })
  ProtocolGame.unregisterExtendedOpcode(LAVA_SMELT_OPCODE)
  modules.game_interface.removeMenuHook('lava_smelt', 'Reforge with...')
  destroyWindow()
end

function close()
  destroyWindow()
end