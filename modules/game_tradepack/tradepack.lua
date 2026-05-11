-- ============================================================
-- game_tradepack UI
-- ============================================================
-- Server sends opcode 100 with JSON:
--   mode="select":
--     tiers  = [{id, label, cost, slowdown, materials, can_afford}, ...]
--     routes = [{id, label, multiplier}, ...]
--   mode="confirm":
--     {tier_id, tier_label, cost, slowdown, routes, delivery_text}
--
-- Client replies:
--   { action="pick",    tier=<id> }
--   { action="confirm" }
--   { action="cancel"  }
-- ============================================================

local TRADEPACK_OPCODE = 100

local tradepackWindow = nil
local selectedTierId = nil
local tiersData = nil
local routesData = nil
local lastSelectData = nil

local function destroyWindow()
  if tradepackWindow then
    tradepackWindow:destroy()
    tradepackWindow = nil
  end
  selectedTierId = nil
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

local function getRouteText()
  if not routesData or #routesData == 0 then
    return 'any tradepack dropoff point'
  end

  local labels = {}
  for _, route in ipairs(routesData) do
    labels[#labels + 1] = route.label or route.id or '?'
  end

  if #labels == 1 then
    return labels[1]
  elseif #labels == 2 then
    return labels[1] .. ' or ' .. labels[2]
  end

  local last = labels[#labels]
  labels[#labels] = nil
  return table.concat(labels, ', ') .. ', or ' .. last
end

local function updateDeliveryLabel()
  if not tradepackWindow then return end
  local label = tradepackWindow:recursiveGetChildById('deliveryLabel')
  if not label then return end

  local routeText = getRouteText()
  if routesData and #routesData > 0 then
    label:setText('Deliverable at: ' .. routeText)
  else
    label:setText('Deliverable at any tradepack dropoff point')
  end
end

local function getTierReward(tierId)
  if not lastSelectData or not lastSelectData.tiers then
    return nil
  end

  for _, tier in ipairs(lastSelectData.tiers) do
    if tier.id == tierId then
      return tonumber(tier.reward) or 0
    end
  end

  return nil
end

-- Update the right-hand detail panel based on currently selected tier.
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

  if not tierEntry then
    local w = lbl('detailTitle'); if w then w:setText('Select a pack') end
    local wt = lbl('detailWeight'); if wt then wt:setText('') end
    local c = lbl('detailCost');  if c then c:setText('') end
    local rw = lbl('detailReward'); if rw then rw:setText('') end
    local sp = lbl('detailSpeed');  if sp then sp:setText('') end
    return
  end

  local w = lbl('detailTitle')
  if w then w:setText(tierEntry.display_label or tierEntry.label or tierEntry.id) end

  local wt = lbl('detailWeight')
  if wt then
    local oz = tonumber(tierEntry.weight_oz) or 0
    wt:setText('Weight: ' .. oz .. ' oz')
  end

  local c = lbl('detailCost')
  if c then
    c:setText('Cost: ' .. (tierEntry.cost or ''))
    c:setColor(tierEntry.can_afford == false and '#e07070' or '#d0d0d0')
  end

  local baseReward = tonumber(tierEntry.reward) or 0
  local rw = lbl('detailReward')
  if rw then
    if routesData and #routesData > 0 then
      local rewardLines = {}
      for _, route in ipairs(routesData) do
        local mult = tonumber(route.multiplier) or 1.0
        rewardLines[#rewardLines + 1] = string.format('%s: %d gold', route.label or route.id or '?', math.floor(baseReward * mult))
      end
      rw:setText('Reward on delivery:\n' .. table.concat(rewardLines, '\n'))
    else
      rw:setText('Reward on delivery: ' .. baseReward .. ' gold')
    end
  end

  local sp = lbl('detailSpeed')
  if sp then sp:setText('Speed penalty: -' .. tostring(tierEntry.slowdown or 0) .. '%') end

  -- enable/disable Next button based on affordability
  local nextBtn = tradepackWindow:recursiveGetChildById('nextButton')
  if nextBtn then
    nextBtn:setEnabled(tierEntry.can_afford ~= false)
  end
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
        hdr:setText((CATEGORY_LABELS[t.category] or t.category))
      end

      local row = g_ui.createWidget('TradepackTierRow', listPanel)
      row:setId(t.id)
      local crateIcon = row:getChildById('crateIcon')
      local rowTitle  = row:getChildById('rowTitle')
      local rowSub    = row:getChildById('rowSub')

      if crateIcon then
        crateIcon:setItemId(tonumber(t.icon_item) or 7483)
      end
      if rowTitle  then rowTitle:setText(t.label or t.id) end

      local weightOz = tonumber(t.weight_oz) or 0
      if rowSub then
        if t.can_afford == false and t.materials and #t.materials > 0 then
          -- show worst shortfall: the material furthest from completion
          local worst, worstPct = nil, 1.0
          for _, m in ipairs(t.materials) do
            local pct = (tonumber(m.have) or 0) / (tonumber(m.need) or 1)
            if pct < worstPct then worstPct = pct; worst = m end
          end
          if worst then
            local have = tonumber(worst.have) or 0
            local need = tonumber(worst.need) or 0
            -- strip "crystal fragment" down to just the colour word for brevity
            local shortName = (worst.name or ''):match('^(%a+)') or worst.name or ''
            rowSub:setText(have .. ' / ' .. need .. ' ' .. shortName)
            rowSub:setColor('#775555')
          else
            rowSub:setText('missing materials')
            rowSub:setColor('#555555')
          end
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
        -- unaffordable rows can be browsed but not commissioned
        if t.can_afford == false then
          selectedTierId = t.id
          highlightTierRow(listPanel, t.id)
          updateDetails()
          return true
        end
        selectedTierId = t.id
        highlightTierRow(listPanel, t.id)
        updateDetails()
        return true
      end
    end
  end

  updateDeliveryLabel()
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
  if not selectedTierId then return end
  sendResponse({ action = "pick", tier = selectedTierId })
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

    local baseReward = getTierReward(data.tier_id) or 0
    local rewardLines = {}
    local confirmRoutes = data.routes or {}
    for _, route in ipairs(confirmRoutes) do
      local multiplier = tonumber(route.multiplier) or 1.0
      rewardLines[#rewardLines + 1] = string.format('%s: %d gold', route.label or route.id or '?', math.floor(baseReward * multiplier))
    end

    setLabel('sizeLabel',   'Size: '           .. (data.tier_label or ''))
    setLabel('destLabel',   'Delivery points:\n' .. (data.delivery_text or getRouteText()))
    setLabel('costLabel',   'Cost: '           .. (data.cost       or '') .. ' (materials)')
    setLabel('rewardLabel', 'Reward on delivery:\n' .. table.concat(rewardLines, '\n'))
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
