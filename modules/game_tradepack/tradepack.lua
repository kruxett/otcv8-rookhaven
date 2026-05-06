-- ============================================================
-- game_tradepack UI
-- ============================================================
-- Server sends opcode 100 with JSON:
--   mode="select":
--     tiers  = [{id, label, cost, slowdown, reward}, ...]
--     routes = [{id, label, multiplier}, ...]
--   mode="confirm":
--     {tier_id, tier_label, dest_id, dest_label, cost, reward, slowdown}
--
-- Client replies:
--   { action="pick",    tier=<id>, dest=<id> }
--   { action="confirm" }
--   { action="cancel"  }
-- ============================================================

local TRADEPACK_OPCODE = 100

local tradepackWindow = nil
local selectedTierId = nil
local selectedDestId = nil
local tiersData = nil
local routesData = nil
local lastSelectData = nil

local function destroyWindow()
  if tradepackWindow then
    tradepackWindow:destroy()
    tradepackWindow = nil
  end
  selectedTierId = nil
  selectedDestId = nil
  tiersData = nil
  routesData = nil
end

local function sendResponse(payload)
  local protocol = g_game.getProtocolGame()
  if not protocol then return end
  local ok, encoded = pcall(function() return json.encode(payload) end)
  if ok and type(encoded) == 'string' then
    protocol:sendExtendedOpcode(TRADEPACK_OPCODE, encoded)
  end
end

-- Update the right-hand detail panel based on currently selected tier + dest
local function updateDetails()
  if not tradepackWindow then return end
  local detailPanel = tradepackWindow:recursiveGetChildById('detailPanel')
  if not detailPanel then return end

  local function lbl(id) return detailPanel:getChildById(id) end

  -- find tier entry
  local tierEntry = nil
  if tiersData and selectedTierId then
    for _, t in ipairs(tiersData) do
      if t.id == selectedTierId then tierEntry = t; break end
    end
  end

  -- find route entry for multiplier
  local routeEntry = nil
  if routesData and selectedDestId then
    for _, r in ipairs(routesData) do
      if r.id == selectedDestId then routeEntry = r; break end
    end
  end

  if not tierEntry then
    local w = lbl('detailTitle'); if w then w:setText('Select a pack size') end
    local c = lbl('detailCost');  if c then c:setText('') end
    local rw = lbl('detailReward'); if rw then rw:setText('') end
    local sp = lbl('detailSpeed');  if sp then sp:setText('') end
    return
  end

  local w = lbl('detailTitle')
  if w then w:setText(tierEntry.label or tierEntry.id) end

  local c = lbl('detailCost')
  if c then
    c:setText('Cost: ' .. (tierEntry.cost or ''))
    c:setColor(tierEntry.can_afford == false and '#e07070' or '#d0d0d0')
  end

  local baseReward = tonumber(tierEntry.reward) or 0
  local mult = routeEntry and (tonumber(routeEntry.multiplier) or 1.0) or 1.0
  local actualReward = math.floor(baseReward * mult)
  local rw = lbl('detailReward')
  if rw then rw:setText('Reward: ' .. actualReward .. ' gold') end

  local sp = lbl('detailSpeed')
  if sp then sp:setText('Speed penalty: -' .. tostring(tierEntry.slowdown or 0) .. '%') end
end

-- Returns tier data by id, or nil if not a tier row (e.g. a category header).
local function getTierEntry(id)
  if not tiersData then return nil end
  for _, t in ipairs(tiersData) do
    if t.id == id then return t end
  end
  return nil
end

local function highlightTierRow(listPanel, selectedId)
  for _, child in ipairs(listPanel:getChildren()) do
    local id = child:getId()
    local te = getTierEntry(id)
    if te then  -- skip category headers
      if id == selectedId then
        child:setBackgroundColor('#ffffff22')
        child:setBorderColor('#888888')
      elseif te.can_afford == false then
        child:setBackgroundColor('#141414')
        child:setBorderColor('#1e1e1e')
      else
        child:setBackgroundColor('#232323')
        child:setBorderColor('#000000')
      end
    end
  end
end

local CATEGORY_LABELS = {
  green = 'Green Crystals',
  blue  = 'Blue Crystals',
  azure = 'Azure Crystals',
  red   = 'Red Crystals',
}

local function displaySelectUI(data)
  destroyWindow()
  tradepackWindow = g_ui.displayUI('tradepack_select', rootWidget)
  if not tradepackWindow then return end

  tiersData = data.tiers or {}
  routesData = data.routes or {}

  local listPanel = tradepackWindow:recursiveGetChildById('listPanel')
  local destSelector = tradepackWindow:recursiveGetChildById('destSelector')

  -- pick first affordable tier for initial selection (fall back to first tier)
  selectedTierId = nil
  for _, t in ipairs(tiersData) do
    if t.can_afford ~= false then
      selectedTierId = t.id
      break
    end
  end
  if not selectedTierId and tiersData[1] then
    selectedTierId = tiersData[1].id
  end

  if listPanel then
    local lastCat = nil
    for _, t in ipairs(tiersData) do
      -- insert category header when the crystal type changes
      if t.category ~= lastCat then
        lastCat = t.category
        local hdr = g_ui.createWidget('TradepackCategoryHeader', listPanel)
        hdr:setId('cat_' .. (t.category or 'unknown'))
        hdr:setText('\xe2\x94\x80\xe2\x94\x80 ' .. (CATEGORY_LABELS[t.category] or t.category) .. ' \xe2\x94\x80\xe2\x94\x80')
      end

      local row = g_ui.createWidget('TradepackTierRow', listPanel)
      row:setId(t.id)
      local crateIcon = row:getChildById('crateIcon')
      local rowTitle  = row:getChildById('rowTitle')
      local rowSub    = row:getChildById('rowSub')

      if crateIcon then crateIcon:setItemId(7483); crateIcon:setCount(1) end
      if rowTitle  then rowTitle:setText(t.label or t.id) end

      local weightOz = tonumber(t.weight_oz) or 0
      if rowSub then
        if t.can_afford == false then
          rowSub:setText('no materials')
          rowSub:setColor('#555555')
        else
          rowSub:setText(weightOz .. ' oz')
          rowSub:setColor('#b0b0b0')
        end
      end

      -- grey out unaffordable rows
      if t.can_afford == false then
        row:setBackgroundColor('#141414')
        row:setBorderColor('#1e1e1e')
        if rowTitle then rowTitle:setColor('#4a4a4a') end
      end

      if t.id == selectedTierId then
        row:setBackgroundColor('#ffffff22')
        row:setBorderColor('#888888')
      end

      row.onMousePress = function(widget)
        selectedTierId = t.id
        highlightTierRow(listPanel, t.id)
        updateDetails()
        return true
      end
    end
  end

  if destSelector then
    destSelector:clearOptions()
    for i, r in ipairs(routesData) do
      destSelector:addOption(tostring(r.label or r.id), tostring(r.id))
      if i == 1 then
        selectedDestId = tostring(r.id)
        destSelector:setCurrentOption(tostring(r.label or r.id), false)
      end
    end

    destSelector.onOptionChange = function(widget, text, optionData)
      selectedDestId = (optionData ~= nil and optionData ~= '') and tostring(optionData) or text
      updateDetails()
    end
  end

  updateDetails()
end

-- ---- public callbacks (referenced from .otui) ---------------

function cancel()
  lastSelectData = nil
  sendResponse({ action = "cancel" })
  destroyWindow()
end

function confirm()
  sendResponse({ action = "confirm" })
  destroyWindow()
end

function prev()
  if lastSelectData then
    displaySelectUI(lastSelectData)
  end
end

function requestPack()
  if not tradepackWindow then return end
  if not selectedTierId or not selectedDestId then return end
  sendResponse({ action = "pick", tier = selectedTierId, dest = selectedDestId })
  -- window stays open; server replies with confirm payload
end

-- ---- opcode handler -----------------------------------------

local function onTradepackOpcode(protocol, opcode, buffer)
  local ok, data = pcall(function() return json.decode(buffer) end)
  if not ok or not data then return end

  if data.mode == "select" then
    lastSelectData = data
    displaySelectUI(data)

  elseif data.mode == "confirm" then
    destroyWindow()
    tradepackWindow = g_ui.displayUI('tradepack_confirm', rootWidget)
    if not tradepackWindow then return end

    local function setLabel(id, text)
      local w = tradepackWindow:getChildById(id)
      if w then w:setText(text) end
    end

    setLabel('sizeLabel',   'Size: '           .. (data.tier_label or ''))
    setLabel('destLabel',   'Destination: '    .. (data.dest_label or ''))
    setLabel('costLabel',   'Cost: '           .. (data.cost       or '') .. ' (materials)')
    setLabel('rewardLabel', 'Reward: '         .. tostring(data.reward or '') .. ' gold on delivery')
    setLabel('slowLabel',   'Speed penalty: -' .. tostring(data.slowdown or '') .. '%')

    local costW = tradepackWindow:getChildById('costLabel')
    if costW then
      costW:setColor(data.can_afford and '#70e070' or '#e07070')
    end
  end
end

-- ---- module lifecycle ---------------------------------------

function init()
  connect(g_game, { onGameEnd = destroyWindow })
  ProtocolGame.registerExtendedOpcode(TRADEPACK_OPCODE, onTradepackOpcode)
end

function terminate()
  disconnect(g_game, { onGameEnd = destroyWindow })
  ProtocolGame.unregisterExtendedOpcode(TRADEPACK_OPCODE)
  destroyWindow()
end
