-- ============================================================
-- game_tradepack UI
-- ============================================================
-- Server sends opcode 100 with JSON:
--   { mode="select", tiers=[{id,label,cost,slowdown}, ...], routes=[{id,label}, ...] }
--   { mode="confirm", tier_id, tier_label, dest_id, dest_label, cost, reward }
--
-- Client replies with opcode 100:
--   { action="pick",    tier=<id>, dest=<id> }   (from select stage)
--   { action="confirm"                        }   (from confirm stage)
--   { action="cancel"                         }   (from either stage)
-- ============================================================

local TRADEPACK_OPCODE = 100

local tradepackWindow = nil

-- ---- helpers ------------------------------------------------

local function destroyWindow()
  if tradepackWindow then
    tradepackWindow:ungrabMouse()
    tradepackWindow:destroy()
    tradepackWindow = nil
  end
end

local function sendResponse(payload)
  local protocol = g_game.getProtocolGame()
  if protocol then
    protocol:sendExtendedOpcode(TRADEPACK_OPCODE, json.encode(payload))
  end
end

-- ---- public callbacks (referenced from .otui) ---------------

function cancel()
  sendResponse({ action = "cancel" })
  destroyWindow()
end

function confirm()
  sendResponse({ action = "confirm" })
  destroyWindow()
end

-- Called when the player clicks "Request Pack" in the select view.
-- Reads the selected radio buttons and sends a pick action.
function requestPack()
  if not tradepackWindow then return end

  local tierGroup = tradepackWindow:getChildById('tierGroup')
  local destGroup = tradepackWindow:getChildById('destGroup')
  if not tierGroup or not destGroup then return end

  local selectedTier = tierGroup:getSelectedOption()
  local selectedDest = destGroup:getSelectedOption()
  if not selectedTier or not selectedDest then
    -- nothing selected yet, ignore
    return
  end

  sendResponse({ action = "pick", tier = selectedTier, dest = selectedDest })
  -- window stays open; server will reply with a confirm payload
end

-- ---- opcode handler -----------------------------------------

local function onTradepackOpcode(protocol, opcode, buffer)
  local data = json.decode(buffer)
  if not data then return end

  destroyWindow()

  if data.mode == "select" then
    -- --------------------------------------------------------
    -- Stage 1: size + destination picker
    -- --------------------------------------------------------
    tradepackWindow = g_ui.displayUI('tradepack_select', rootWidget)
    if not tradepackWindow then return end

    local tierGroup = tradepackWindow:getChildById('tierGroup')
    local destGroup = tradepackWindow:getChildById('destGroup')

    -- Populate tier radio buttons
    if tierGroup and data.tiers then
      for i, t in ipairs(data.tiers) do
        local btn = g_ui.createWidget('TradepackRadioButton', tierGroup)
        btn:setId('tier_' .. t.id)
        btn:setText(t.label .. '\n' .. t.cost)
        btn:setOption(t.id)
        if i == 1 then btn:setChecked(true) end
      end
    end

    -- Populate destination radio buttons
    if destGroup and data.routes then
      for i, r in ipairs(data.routes) do
        local btn = g_ui.createWidget('TradepackRadioButton', destGroup)
        btn:setId('dest_' .. r.id)
        btn:setText(r.label)
        btn:setOption(r.id)
        if i == 1 then btn:setChecked(true) end
      end
    end

    tradepackWindow:grabMouse()

  elseif data.mode == "confirm" then
    -- --------------------------------------------------------
    -- Stage 2: summary before final commit
    -- --------------------------------------------------------
    tradepackWindow = g_ui.displayUI('tradepack_confirm', rootWidget)
    if not tradepackWindow then return end

    local function setLabel(id, text)
      local w = tradepackWindow:getChildById(id)
      if w then w:setText(text) end
    end

    setLabel('sizeLabel',    'Size: '        .. (data.tier_label or ''))
    setLabel('destLabel',    'Destination: ' .. (data.dest_label or ''))
    setLabel('costLabel',    'Cost: '        .. (data.cost       or '') .. ' (materials)')
    setLabel('rewardLabel',  'Reward: '      .. (data.reward     or '') .. ' gold on delivery')
    setLabel('slowLabel',    'Speed penalty: ' .. (data.slowdown or '') .. '%')

    tradepackWindow:grabMouse()
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
