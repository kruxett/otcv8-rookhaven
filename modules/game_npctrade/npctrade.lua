BUY = 1
SELL = 2
CURRENCY = 'gold'
CURRENCY_DECIMAL = false
WEIGHT_UNIT = 'oz'
LAST_INVENTORY = 10

npcWindow = nil
itemsPanel = nil
radioTabs = nil
radioItems = nil
searchText = nil
setupPanel = nil
quantity = nil
quantityScroll = nil
idLabel = nil
nameLabel = nil
priceLabel = nil
moneyLabel = nil
weightDesc = nil
weightLabel = nil
capacityDesc = nil
capacityLabel = nil
tradeButton = nil
buyTab = nil
sellTab = nil
initialized = false

showWeight = true
buyWithBackpack = nil
ignoreCapacity = nil
ignoreEquipped = nil
showAllItems = nil
confirmSellAllCheckbox = nil
sellAllButton = nil
sellAllWithDelayButton = nil
playerFreeCapacity = 0
playerMoney = 0
tradeItems = {}
playerItems = {}
rarityNameCounts = {}
selectedItem = nil

cancelNextRelease = nil

sellAllWithDelayEvent = nil

function init()
  npcWindow = g_ui.displayUI('npctrade')
  npcWindow:setVisible(false)

  itemsPanel = npcWindow:recursiveGetChildById('itemsPanel')
  searchText = npcWindow:recursiveGetChildById('searchText')

  setupPanel = npcWindow:recursiveGetChildById('setupPanel')
  quantityScroll = setupPanel:getChildById('quantityScroll')
  idLabel = setupPanel:getChildById('id')
  nameLabel = setupPanel:getChildById('name')
  priceLabel = setupPanel:getChildById('price')
  moneyLabel = setupPanel:getChildById('money')
  weightDesc = setupPanel:getChildById('weightDesc')
  weightLabel = setupPanel:getChildById('weight')
  capacityDesc = setupPanel:getChildById('capacityDesc')
  capacityLabel = setupPanel:getChildById('capacity')
  tradeButton = npcWindow:recursiveGetChildById('tradeButton')

  buyWithBackpack = npcWindow:recursiveGetChildById('buyWithBackpack')
  ignoreCapacity = npcWindow:recursiveGetChildById('ignoreCapacity')
  ignoreEquipped = npcWindow:recursiveGetChildById('ignoreEquipped')
  showAllItems = npcWindow:recursiveGetChildById('showAllItems')
  confirmSellAllCheckbox = npcWindow:recursiveGetChildById('confirmSellAll')
  sellAllButton = npcWindow:recursiveGetChildById('sellAllButton')
  sellAllWithDelayButton = npcWindow:recursiveGetChildById('sellAllWithDelayButton')
  buyTab = npcWindow:getChildById('buyTab')
  sellTab = npcWindow:getChildById('sellTab')

  confirmSellAllCheckbox:setChecked(not g_settings.getBoolean('npcTradeConfirmSellAll', true))

  radioTabs = UIRadioGroup.create()
  radioTabs:addWidget(buyTab)
  radioTabs:addWidget(sellTab)
  radioTabs:selectWidget(buyTab)
  radioTabs.onSelectionChange = onTradeTypeChange

  cancelNextRelease = false

  if g_game.isOnline() then
    playerFreeCapacity = g_game.getLocalPlayer():getFreeCapacity()
  end

  connect(g_game, { onGameEnd = hide,
                    onOpenNpcTrade = onOpenNpcTrade,
                    onCloseNpcTrade = onCloseNpcTrade,
                    onPlayerGoods = onPlayerGoods } )

  ProtocolGame.registerExtendedOpcode(99, function(protocol, opcode, buffer)
    rarityNameCounts = {}
    for entry in buffer:gmatch("[^|]+") do
      local name, count = entry:match("^(.+):(%d+)$")
      if name and count then
        rarityNameCounts[name:lower()] = tonumber(count)
      end
    end
    -- Refresh the UI now that exact per-tier counts are known.
    -- Use addEvent so this runs after any pending show() call from onOpenNpcTrade,
    -- which also defers via addEvent. This guarantees the window is visible first.
    if initialized then
      addEvent(refreshPlayerGoods)
    end
  end)

  connect(LocalPlayer, { onFreeCapacityChange = onFreeCapacityChange,
                         onInventoryChange = onInventoryChange } )

  initialized = true
end

function terminate()
  initialized = false
  npcWindow:destroy()
  removeEvent(sellAllWithDelayEvent)
  
  disconnect(g_game, {  onGameEnd = hide,
                        onOpenNpcTrade = onOpenNpcTrade,
                        onCloseNpcTrade = onCloseNpcTrade,
                        onPlayerGoods = onPlayerGoods } )

  ProtocolGame.unregisterExtendedOpcode(99)

  disconnect(LocalPlayer, { onFreeCapacityChange = onFreeCapacityChange,
                            onInventoryChange = onInventoryChange } )
end

function show()
  if g_game.isOnline() then
    if #tradeItems[BUY] > 0 then
      radioTabs:selectWidget(buyTab)
    else
      radioTabs:selectWidget(sellTab)
    end

    npcWindow:show()
    npcWindow:raise()
    npcWindow:focus()
  end
end

function hide()
  removeEvent(sellAllWithDelayEvent)

  npcWindow:hide()

  local layout = itemsPanel:getLayout()
  layout:disableUpdates()

  clearSelectedItem()

  searchText:clearText()
  setupPanel:disable()
  itemsPanel:destroyChildren()

  if radioItems then
    radioItems:destroy()
    radioItems = nil
  end

  layout:enableUpdates()
  layout:update()  
end

function onItemBoxChecked(widget)
  if widget:isChecked() then
    local item = widget.item
    selectedItem = item
    refreshItem(item)
    if canTradeItem(item) then
      tradeButton:enable()
    else
      tradeButton:disable()
    end

    if getCurrentTradeType() == SELL then
      quantityScroll:setValue(quantityScroll:getMaximum())
    end
  end
end

function onQuantityValueChange(quantity)
  if selectedItem then
    weightLabel:setText(string.format('%.2f', selectedItem.weight*quantity) .. ' ' .. WEIGHT_UNIT)
    priceLabel:setText(formatCurrency(getItemPrice(selectedItem)))
  end
end

function onTradeTypeChange(radioTabs, selected, deselected)
  tradeButton:setText(selected:getText())
  selected:setOn(true)
  deselected:setOn(false)

  local currentTradeType = getCurrentTradeType()
  buyWithBackpack:setVisible(currentTradeType == BUY)
  ignoreCapacity:setVisible(currentTradeType == BUY)
  ignoreEquipped:setVisible(currentTradeType == SELL)
  showAllItems:setVisible(currentTradeType == SELL)
  confirmSellAllCheckbox:setVisible(currentTradeType == SELL)
  sellAllButton:setVisible(currentTradeType == SELL)
  sellAllWithDelayButton:setVisible(currentTradeType == SELL)
  
  refreshTradeItems()
  refreshPlayerGoods()
end

function onTradeClick()
  removeEvent(sellAllWithDelayEvent)
  if getCurrentTradeType() == BUY then
    g_game.buyItem(selectedItem.ptr, quantityScroll:getValue(), ignoreCapacity:isChecked(), buyWithBackpack:isChecked())
  else
    g_game.sellItem(selectedItem.ptr, quantityScroll:getValue(), ignoreEquipped:isChecked())
  end
end

function onSearchTextChange()
  refreshPlayerGoods()
end

function itemPopup(self, mousePosition, mouseButton)
  if cancelNextRelease then
    cancelNextRelease = false
    return false
  end

  if mouseButton == MouseRightButton then
    local menu = g_ui.createWidget('PopupMenu')
    menu:setGameMenu(true)
    menu:addOption(tr('Look'), function() return g_game.inspectNpcTrade(self:getItem()) end)
    if getCurrentTradeType() == SELL then
      local itemId = self:getItem():getId()
      local label = isExcluded(itemId) and tr('Unprotect from Sell All') or tr('Protect from Sell All')
      menu:addOption(label, function()
        toggleExclusion(itemId)
        refreshPlayerGoods()
      end)
    end
    menu:display(mousePosition)
    return true
  elseif ((g_mouse.isPressed(MouseLeftButton) and mouseButton == MouseRightButton)
    or (g_mouse.isPressed(MouseRightButton) and mouseButton == MouseLeftButton)) then
    cancelNextRelease = true
    g_game.inspectNpcTrade(self:getItem())
    return true
  end
  return false
end

function onBuyWithBackpackChange()
  if selectedItem then
    refreshItem(selectedItem)
  end
end

function onIgnoreCapacityChange()
  refreshPlayerGoods()
end

function onIgnoreEquippedChange()
  refreshPlayerGoods()
end

function onShowAllItemsChange()
  refreshPlayerGoods()
end

function onConfirmSellAllChange()
  g_settings.set('npcTradeConfirmSellAll', not confirmSellAllCheckbox:isChecked())
end

-- Sell All exclusion helpers
function getExclusions()
  local raw = g_settings.get('sellAllExclusions', '')
  local result = {}
  for part in raw:gmatch('[^,]+') do
    local id = tonumber(part)
    if id then result[id] = true end
  end
  return result
end

function saveExclusions(excludeMap)
  local parts = {}
  for id, _ in pairs(excludeMap) do
    parts[#parts + 1] = tostring(id)
  end
  g_settings.set('sellAllExclusions', table.concat(parts, ','))
end

function toggleExclusion(itemId)
  local excl = getExclusions()
  if excl[itemId] then
    excl[itemId] = nil
  else
    excl[itemId] = true
  end
  saveExclusions(excl)
end

function isExcluded(itemId)
  return getExclusions()[itemId] == true
end

function setCurrency(currency, decimal)
  CURRENCY = currency
  CURRENCY_DECIMAL = decimal
end

function setShowWeight(state)
  showWeight = state
  weightDesc:setVisible(state)
  weightLabel:setVisible(state)
end

function setShowYourCapacity(state)
  capacityDesc:setVisible(state)
  capacityLabel:setVisible(state)
  ignoreCapacity:setVisible(state)
end

function clearSelectedItem()
  idLabel:clearText()
  nameLabel:clearText()
  weightLabel:clearText()
  priceLabel:clearText()
  tradeButton:disable()
  quantityScroll:setMinimum(0)
  quantityScroll:setMaximum(0)
  if selectedItem then
    radioItems:selectWidget(nil)
    selectedItem = nil
  end
end

function getCurrentTradeType()
  if tradeButton:getText() == tr('Buy') then
    return BUY
  else
    return SELL
  end
end

function getItemPrice(item, single)
  local amount = 1
  local single = single or false
  if not single then
    amount = quantityScroll:getValue()
  end
  if getCurrentTradeType() == BUY then
    if buyWithBackpack:isChecked() then
      if item.ptr:isStackable() then
          return item.price*amount + 20
      else
        return item.price*amount + math.ceil(amount/20)*20
      end
    end
  end
  return item.price*amount
end

local function isRarityRolledItem(item)
  if not item then
    return false
  end

  local article = item:getArticle()
  if not article or article == '' then
    return false
  end

  article = article:lower()
  return article:find('rare', 1, true) ~= nil or
         article:find('epic', 1, true) ~= nil or
         article:find('legendary', 1, true) ~= nil
end

local function isRarityShopEntry(tradeItem)
  if not tradeItem or not tradeItem.name then
    return false
  end

  local name = tradeItem.name:lower()
  return name:find('rare ', 1, true) == 1 or
         name:find('epic ', 1, true) == 1 or
         name:find('legendary ', 1, true) == 1
end

function getSellQuantity(tradeItem)
  if not tradeItem then return 0 end

  local item = tradeItem.ptr or tradeItem
  if not item then return 0 end

  local itemId = item:getId()
  if not playerItems[itemId] then return 0 end

  -- No fallback to playerItems: opcode 99 is authoritative for rarity tiers.
  -- Absence of a key means 0 of that tier (sold/not in inventory).
  if isRarityShopEntry(tradeItem) then
    return rarityNameCounts[tradeItem.name:lower()] or 0
  end

  -- Vanilla logic for normal shops: subtract ignoreEquipped items.
  local removeAmount = 0
  if ignoreEquipped:isChecked() then
    local localPlayer = g_game.getLocalPlayer()
    for i = 1, LAST_INVENTORY do
      local inventoryItem = localPlayer:getInventoryItem(i)
      if inventoryItem and inventoryItem:getId() == itemId and not isRarityRolledItem(inventoryItem) then
        removeAmount = removeAmount + inventoryItem:getCount()
      end
    end
  end
  return math.max(0, playerItems[itemId] - removeAmount)
end

function canTradeItem(item)
  if getCurrentTradeType() == BUY then
    return (ignoreCapacity:isChecked() or (not ignoreCapacity:isChecked() and playerFreeCapacity >= item.weight)) and playerMoney >= getItemPrice(item, true)
  else
    return getSellQuantity(item) > 0
  end
end

function refreshItem(item)
  -- idLabel:setText(item.ptr:getId())  -- Disabled: don't show item ID
  nameLabel:setText(item.name)
  weightLabel:setText(string.format('%.2f', item.weight) .. ' ' .. WEIGHT_UNIT)
  priceLabel:setText(formatCurrency(getItemPrice(item)))

  if getCurrentTradeType() == BUY then
    local capacityMaxCount = math.floor(playerFreeCapacity / item.weight)
    if ignoreCapacity:isChecked() then
      capacityMaxCount = 65535
    end
    local priceMaxCount = math.floor(playerMoney / getItemPrice(item, true))
    local finalCount = math.max(0, math.min(getMaxAmount(), math.min(priceMaxCount, capacityMaxCount)))
    quantityScroll:setMinimum(1)
    quantityScroll:setMaximum(finalCount)
  else
    quantityScroll:setMinimum(1)
    quantityScroll:setMaximum(math.max(0, math.min(getMaxAmount(), getSellQuantity(item))))
  end

  setupPanel:enable()
end

function refreshTradeItems()
  local layout = itemsPanel:getLayout()
  layout:disableUpdates()

  clearSelectedItem()

  searchText:clearText()
  setupPanel:disable()
  itemsPanel:destroyChildren()

  if radioItems then
    radioItems:destroy()
  end
  radioItems = UIRadioGroup.create()

  local currentTradeItems = tradeItems[getCurrentTradeType()]
  for key,item in pairs(currentTradeItems) do
    local itemBox = g_ui.createWidget('NPCItemBox', itemsPanel)
    itemBox.item = item

    local text = ''
    local name = item.name
    text = text .. name
    if showWeight then
      local weight = string.format('%.2f', item.weight) .. ' ' .. WEIGHT_UNIT
      text = text .. '\n' .. weight
    end
    local price = formatCurrency(item.price)
    text = text .. '\n' .. price
    itemBox:setText(text)

    local itemWidget = itemBox:getChildById('item')
    itemWidget:setItem(item.ptr)
    itemWidget.onMouseRelease = itemPopup

    radioItems:addWidget(itemBox)
  end

  layout:enableUpdates()
  layout:update()
end

function refreshPlayerGoods()
  if not initialized then return end

  checkSellAllTooltip()

  moneyLabel:setText(formatCurrency(playerMoney))
  capacityLabel:setText(string.format('%.2f', playerFreeCapacity) .. ' ' .. WEIGHT_UNIT)

  local currentTradeType = getCurrentTradeType()
  local searchFilter = searchText:getText():lower()
  local foundSelectedItem = false
  local selectedWidget = nil
  local selectedCanTrade = false

  local items = itemsPanel:getChildCount()
  for i=1,items do
    local itemWidget = itemsPanel:getChildByIndex(i)
    local item = itemWidget.item

    local canTrade = canTradeItem(item)
    itemWidget:setOn(canTrade)
    itemWidget:setEnabled(canTrade)

    -- Visual indicator for protected items (sell tab only)
    if currentTradeType == SELL then
      local itemId = item.ptr:getId()
      local badge = itemWidget:getChildById('protectedBadge')
      if badge then
        badge:setVisible(isExcluded(itemId))
      end
    end

    local searchCondition = (searchFilter == '') or (searchFilter ~= '' and string.find(item.name:lower(), searchFilter) ~= nil)
    local showAllItemsCondition = (currentTradeType == BUY) or (showAllItems:isChecked()) or (currentTradeType == SELL and not showAllItems:isChecked() and canTrade)
    itemWidget:setVisible(searchCondition and showAllItemsCondition)

    if selectedItem == item and itemWidget:isEnabled() and itemWidget:isVisible() then
      foundSelectedItem = true
      selectedWidget = itemWidget
      selectedCanTrade = canTrade
    end
  end

  if not foundSelectedItem then
    clearSelectedItem()
  else
    -- Keep radio-selection visuals consistent after periodic refreshes.
    if selectedWidget then
      radioItems:selectWidget(selectedWidget)
      selectedWidget:setChecked(true)
    end
    if selectedCanTrade then
      tradeButton:enable()
    else
      tradeButton:disable()
    end
  end

  if selectedItem then
    refreshItem(selectedItem)
  end
end

function onOpenNpcTrade(items)
  tradeItems[BUY] = {}
  tradeItems[SELL] = {}
  for key,item in pairs(items) do
    if item[4] > 0 then
      local newItem = {}
      newItem.ptr = item[1]
      newItem.name = item[2]
      newItem.weight = item[3] / 100
      newItem.price = item[4]
      table.insert(tradeItems[BUY], newItem)
    end
    
    if item[5] > 0 then
      local newItem = {}
      newItem.ptr = item[1]
      newItem.name = item[2]
      newItem.weight = item[3] / 100
      newItem.price = item[5]
      table.insert(tradeItems[SELL], newItem)
    end
  end

  refreshTradeItems()
  addEvent(show) -- player goods has not been parsed yet
end

function closeNpcTrade()
  g_game.closeNpcTrade()
  addEvent(hide)
end

function onCloseNpcTrade()
  rarityNameCounts = {}
  addEvent(hide)
end

function onPlayerGoods(money, items)
  playerMoney = money

  playerItems = {}
  for key,item in pairs(items) do
    local id = item[1]:getId()
    if not playerItems[id] then
      playerItems[id] = item[2]
    else
      playerItems[id] = playerItems[id] + item[2]
    end
  end

  refreshPlayerGoods()
end

function onFreeCapacityChange(localPlayer, freeCapacity, oldFreeCapacity)
  playerFreeCapacity = freeCapacity

  if npcWindow:isVisible() then
    refreshPlayerGoods()
  end
end

function onInventoryChange(inventory, item, oldItem)
  refreshPlayerGoods()
end

function getTradeItemData(id, type)
  if table.empty(tradeItems[type]) then
    return false
  end

  if type then
    for key,item in pairs(tradeItems[type]) do
      if item.ptr and item.ptr:getId() == id then
        return item
      end
    end
  else
    for _,items in pairs(tradeItems) do
      for key,item in pairs(items) do
        if item.ptr and item.ptr:getId() == id then
          return item
        end
      end
    end
  end
  return false
end

function checkSellAllTooltip()
  sellAllButton:setEnabled(true)
  sellAllButton:removeTooltip()
  sellAllWithDelayButton:setEnabled(true)
  sellAllWithDelayButton:removeTooltip()

  local total = 0
  local info = ''
  local first = true

  for _, data in ipairs(tradeItems[SELL] or {}) do
    local amount = getSellQuantity(data)
    if amount > 0 then
      info = info..(not first and "\n" or "")..
             amount.." "..
             data.name.." ("..
             data.price*amount.." gold)"

      total = total+(data.price*amount)
      if first then first = false end
    end
  end
  if info ~= '' then
    info = info.."\nTotal: "..total.." gold"
    sellAllButton:setTooltip(info)
    sellAllWithDelayButton:setTooltip(info)
  else
    sellAllButton:setEnabled(false)
    sellAllWithDelayButton:setEnabled(false)
  end
end

function formatCurrency(amount)
  if CURRENCY_DECIMAL then
    return string.format("%.02f", amount/100.0) .. ' ' .. CURRENCY
  else
    return amount .. ' ' .. CURRENCY
  end
end

function getMaxAmount()
  if getCurrentTradeType() == SELL and g_game.getFeature(GameDoubleShopSellAmount) then
    return 10000
  end
  return 100
end

function sellAll(delayed, exceptions)
  -- backward support
  if type(delayed) == "table" then
    exceptions = delayed
    delayed = false
  end
  exceptions = exceptions or {}
  removeEvent(sellAllWithDelayEvent)
  local queue = {}
  for _,entry in ipairs(tradeItems[SELL]) do
    local id = entry.ptr:getId()
    if not table.find(exceptions, id) then
      local sellQuantity = getSellQuantity(entry)
      while sellQuantity > 0 do
        local maxAmount = math.min(sellQuantity, getMaxAmount())
        if delayed then
          g_game.sellItem(entry.ptr, maxAmount, ignoreEquipped:isChecked())
          sellAllWithDelayEvent = scheduleEvent(function() sellAll(true) end, 1100)
          return
        end
        table.insert(queue, {entry.ptr, maxAmount, ignoreEquipped:isChecked()})
        sellQuantity = sellQuantity - maxAmount
      end
    end
  end
  for _, entry in ipairs(queue) do
    g_game.sellItem(entry[1], entry[2], entry[3])
  end
end

local function buildSellAllSummary(exceptions, maxLines)
  exceptions = exceptions or {}
  maxLines = maxLines or 20

  local function normalizeItemName(name)
    name = tostring(name or "")
    name = name:gsub("%s+", " ")
    name = name:match("^%s*(.-)%s*$") or ""
    return name
  end

  local entries = {}
  local totalGold = 0

  for _, tradeEntry in ipairs(tradeItems[SELL]) do
    local itemId = tradeEntry.ptr:getId()
    if not table.find(exceptions, itemId) then
      local amount = getSellQuantity(tradeEntry)
      if amount > 0 then
        local itemName = normalizeItemName(tradeEntry.name)
        local lineTotal = tradeEntry.price * amount
        totalGold = totalGold + lineTotal
        table.insert(entries, {
          name = itemName,
          text = string.format("%dx %s (%d gold)", amount, itemName, lineTotal)
        })
      end
    end
  end

  table.sort(entries, function(a, b)
    return a.name < b.name
  end)

  local lines = {}
  for i = 1, math.min(#entries, maxLines) do
    lines[#lines + 1] = entries[i].text
  end

  local hiddenEntries = #entries - #lines
  if hiddenEntries > 0 then
    lines[#lines + 1] = tr("...and %d more item stacks.", hiddenEntries)
  end

  return lines, totalGold, #entries
end

function confirmSellAll(delayed, exceptions)
  exceptions = exceptions or {}
  -- merge in persistent exclusions
  local excl = getExclusions()
  for id, _ in pairs(excl) do
    if not table.find(exceptions, id) then
      table.insert(exceptions, id)
    end
  end

  if confirmSellAllCheckbox and confirmSellAllCheckbox:isChecked() then
    sellAll(delayed, exceptions)
    return
  end

  local lines, totalGold, entryCount = buildSellAllSummary(exceptions, 20)
  if entryCount == 0 then
    return
  end

  local message = tr("Are you sure you want to sell these items?") .. "\n\n" ..
                  table.concat(lines, "\n") .. "\n\n" ..
                  tr("Total: %d gold", totalGold)

  local confirmWindow
  confirmWindow = displayGeneralBox(tr("Confirm Sell All"), message, {
    {
      text = tr("Yes"),
      callback = function()
        if confirmWindow then
          confirmWindow:ok()
        end
        sellAll(delayed, exceptions)
      end
    },
    {
      text = tr("No"),
      callback = function()
        if confirmWindow then
          confirmWindow:cancel()
        end
      end
    }
  })
end
