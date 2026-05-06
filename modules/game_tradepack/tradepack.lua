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
local selectedTierId = nil
local selectedDestId = nil

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
  if not protocol then
    return
  end

  local ok, encoded = pcall(function() return json.encode(payload) end)
  if ok and type(encoded) == 'string' then
    protocol:sendExtendedOpcode(TRADEPACK_OPCODE, encoded)
  end
end

local function readComboSelection(combo)
  if not combo then
    return nil
  end

  local option = combo:getCurrentOption()
  if not option then
    return nil
  end

  if option.data ~= nil and option.data ~= '' then
    return tostring(option.data)
  end

  if option.text ~= nil and option.text ~= '' then
    return tostring(option.text)
  end

  return nil
end

function cancel()
  sendResponse({ action = "cancel" })
  destroyWindow()
end

function confirm()
  sendResponse({ action = "confirm" })
  destroyWindow()
end

function requestPack()
  if not tradepackWindow then
    return
  end

  local tierSelector = tradepackWindow:getChildById('tierSelector')
  local destSelector = tradepackWindow:getChildById('destSelector')

  selectedTierId = selectedTierId or readComboSelection(tierSelector)
  selectedDestId = selectedDestId or readComboSelection(destSelector)

  if not selectedTierId or not selectedDestId then
    return
  end

  sendResponse({ action = "pick", tier = selectedTierId, dest = selectedDestId })
end

local function onTradepackOpcode(protocol, opcode, buffer)
  local ok, data = pcall(function() return json.decode(buffer) end)
  if not ok or not data then
    return
  end

  destroyWindow()

  if data.mode == "select" then
    tradepackWindow = g_ui.displayUI('tradepack_select', rootWidget)
    if not tradepackWindow then
      return
    end

    local tierSelector = tradepackWindow:getChildById('tierSelector')
    local destSelector = tradepackWindow:getChildById('destSelector')

    if tierSelector then
      tierSelector:clearOptions()
      if data.tiers then
        for i, t in ipairs(data.tiers) do
          local label = tostring(t.label or t.id)
          if t.cost and t.cost ~= '' then
            label = label .. ' - ' .. tostring(t.cost)
          end
          tierSelector:addOption(label, tostring(t.id))
          if i == 1 then
            selectedTierId = tostring(t.id)
            tierSelector:setCurrentOption(label, false)
          end
        end
      end

      tierSelector.onOptionChange = function(widget, text, optionData)
        if optionData ~= nil and optionData ~= '' then
          selectedTierId = tostring(optionData)
        else
          local current = widget:getCurrentOption()
          selectedTierId = current and tostring(current.data or current.text or '') or nil
        end
      end
    end

    if destSelector then
      destSelector:clearOptions()
      if data.routes then
        for i, r in ipairs(data.routes) do
          local label = tostring(r.label or r.id)
          destSelector:addOption(label, tostring(r.id))
          if i == 1 then
            selectedDestId = tostring(r.id)
            destSelector:setCurrentOption(label, false)
          end
        end
      end

      destSelector.onOptionChange = function(widget, text, optionData)
        if optionData ~= nil and optionData ~= '' then
          selectedDestId = tostring(optionData)
        else
          local current = widget:getCurrentOption()
          selectedDestId = current and tostring(current.data or current.text or '') or nil
        end
      end
    end

  elseif data.mode == "confirm" then
    tradepackWindow = g_ui.displayUI('tradepack_confirm', rootWidget)
    if not tradepackWindow then
      return
    end

    local function setLabel(id, text)
      local w = tradepackWindow:getChildById(id)
      if w then
        w:setText(text)
      end
    end

    setLabel('sizeLabel', 'Size: ' .. (data.tier_label or ''))
    setLabel('destLabel', 'Destination: ' .. (data.dest_label or ''))
    setLabel('costLabel', 'Cost: ' .. (data.cost or '') .. ' (materials)')
    setLabel('rewardLabel', 'Reward: ' .. (data.reward or '') .. ' gold on delivery')
    setLabel('slowLabel', 'Speed penalty: ' .. (data.slowdown or '') .. '%')
  end
end

function init()
  connect(g_game, { onGameEnd = destroyWindow })
  ProtocolGame.registerExtendedOpcode(TRADEPACK_OPCODE, onTradepackOpcode)
end

function terminate()
  disconnect(g_game, { onGameEnd = destroyWindow })
  ProtocolGame.unregisterExtendedOpcode(TRADEPACK_OPCODE)
  destroyWindow()
end
