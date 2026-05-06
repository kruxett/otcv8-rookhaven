-- ============================================================
-- game_tradepack UI
-- ============================================================
-- Server sends opcode 100 with JSON:
--   { mode="select", tiers=[{id,label,cost,slowdown}, ...], routes=[{id,label}, ...] }
--   { mode="confirm", tier_id, tier_label, dest_id, dest_label, cost, reward, slowdown }
--
-- Client replies with opcode 100:
--   { action="pick",    tier=<id>, dest=<id> }   (from select stage)
--   { action="confirm"                        }   (from confirm stage)
--   { action="cancel"                         }   (from either stage)
-- ============================================================

local TRADEPACK_OPCODE = 100

local tradepackWindow = nil

-- Selection state tracked manually (same pattern as game_taskcenter)
local selectedTierId = nil
local selectedDestId = nil

-- ---- helpers ------------------------------------------------

local function destroyWindow()
  if tradepackWindow then
    tradepackWindow:destroy()
    tradepackWindow = nil
  end
  selectedTierId = nil
  selectedDestId = nil
end

local function sendResponse(payload)
  local protocol = g_game.getProtocolGame()
  if not protocol then return end
  local ok, encoded = pcall(function() return json.encode(payload) end)
  if ok and type(encoded) == 'string' then
    protocol:sendExtendedOpcode(TRADEPACK_OPCODE, encoded)
  end
end

local function highlightSelected(panel, selectedId)
  for _, child in ipairs(panel:getChildren()) do
    if child:getId() == selectedId then
      child:setBackgroundColor('#ffffff22')
    else
      child:setBackgroundColor('#232323')
    end
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

-- Called when the player clicks "Next" in the select view.
function requestPack()
  if not tradepackWindow then return end
  if not selectedTierId or not selectedDestId then
    return  -- nothing selected yet
  end
  sendResponse({ action = "pick", tier = selectedTierId, dest = selectedDestId })
  -- window stays open; server replies with confirm payload
end

-- ---- opcode handler -----------------------------------------

local function onTradepackOpcode(protocol, opcode, buffer)
  local ok, data = pcall(function() return json.decode(buffer) end)
  if not ok or not data then return end

  destroyWindow()

  if data.mode == "select" then
    -- --------------------------------------------------------
    -- Stage 1: size + destination picker
    -- --------------------------------------------------------
    tradepackWindow = g_ui.displayUI('tradepack_select', rootWidget)
    if not tradepackWindow then return end

    local tierPanel = tradepackWindow:getChildById('tierPanel')
    local destPanel = tradepackWindow:getChildById('destPanel')

    -- Populate tier list items
    if tierPanel and data.tiers then
      for i, t in ipairs(data.tiers) do
        local row = g_ui.createWidget('TradepackListItem', tierPanel)
        row:setId(t.id)
        row.titleLabel:setText(t.label or t.id)
        row.subtitleLabel:setText((t.cost or '') .. '  |  ' .. (t.slowdown or '') .. '% speed')
        if i == 1 then
          selectedTierId = t.id
          row:setBackgroundColor('#ffffff22')
        end
        row.onMousePress = function(widget)
          selectedTierId = t.id
          highlightSelected(tierPanel, t.id)
          return true
        end
      end
    end

    -- Populate destination list items
    if destPanel and data.routes then
      for i, r in ipairs(data.routes) do
        local row = g_ui.createWidget('TradepackListItem', destPanel)
        row:setId(r.id)
        row.titleLabel:setText(r.label or r.id)
        row.subtitleLabel:setText('')
        if i == 1 then
          selectedDestId = r.id
          row:setBackgroundColor('#ffffff22')
        end
        row.onMousePress = function(widget)
          selectedDestId = r.id
          highlightSelected(destPanel, r.id)
          return true
        end
      end
    end

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

    setLabel('sizeLabel',   'Size: '           .. (data.tier_label or ''))
    setLabel('destLabel',   'Destination: '    .. (data.dest_label or ''))
    setLabel('costLabel',   'Cost: '           .. (data.cost       or '') .. ' (materials)')
    setLabel('rewardLabel', 'Reward: '         .. (data.reward     or '') .. ' gold on delivery')
    setLabel('slowLabel',   'Speed penalty: '  .. (data.slowdown   or '') .. '%')
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
