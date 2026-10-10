-- The closed quiver's contents are known by the server, not the client cache.
QuiverAmmo = {}

local OPCODE = 104
local QUIVER_CID = 11867
local state
local requestEvent
local requestGeneration = 0
local registered = false
local decoratedWidget
local baseTooltip
local lastTooltip

local function ammoWidget()
  return inventoryPanel and inventoryPanel:getChildById('slot' .. InventorySlotAmmo)
end

local function isEquipped()
  local player = g_game.isOnline() and g_game.getLocalPlayer()
  local item = player and player:getInventoryItem(InventorySlotAmmo)
  return item and item:getId() == QUIVER_CID
end

local function cancelRequest()
  requestGeneration = requestGeneration + 1
  if requestEvent then
    removeEvent(requestEvent)
    requestEvent = nil
  end
end

local function refreshHoveredTooltip(widget, text)
  if widget:isHovered() and g_tooltip then
    if text and text ~= '' then g_tooltip.display(text) else g_tooltip.hide() end
  end
end

local function clearDecoration()
  if not decoratedWidget then return end
  local badge = decoratedWidget:getChildById('quiverAmmoCount')
  if badge then badge:hide() end
  if decoratedWidget:getTooltip() == lastTooltip then
    decoratedWidget:setTooltip(baseTooltip)
    refreshHoveredTooltip(decoratedWidget, baseTooltip)
  end
  decoratedWidget, baseTooltip, lastTooltip = nil, nil, nil
end

local function badgeFor(widget)
  local badge = widget:getChildById('quiverAmmoCount')
  if not badge then
    badge = g_ui.createWidget('Label', widget)
    badge:setId('quiverAmmoCount')
    badge:setPhantom(true)
    badge:setFocusable(false)
    badge:setFont('verdana-11px-rounded')
    badge:setColor('#e7e7e7')
    badge:setTextAlign(AlignBottomRight)
    badge:setHeight(13)
    badge:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    badge:addAnchor(AnchorRight, 'parent', AnchorRight)
    badge:addAnchor(AnchorBottom, 'parent', AnchorBottom)
    badge:setMarginRight(3)
  end
  return badge
end

local function displayedCount(snapshot)
  -- Keep the presentation policy separate from the authoritative counts.
  if snapshot.launcherReady then return snapshot.compatible end
  return snapshot.total
end

local function tooltipFor(snapshot)
  local lines = {tr('Magic Quiver'), tr('Total ammunition: %s', snapshot.total),
    tr('Arrows: %s', snapshot.arrows), tr('Bolts: %s', snapshot.bolts)}
  local other = snapshot.total - snapshot.arrows - snapshot.bolts
  if other > 0 then lines[#lines + 1] = tr('Other ammunition: %s', other) end
  if snapshot.total == 0 then
    lines[#lines + 1] = tr('The quiver is empty.')
  elseif snapshot.requiredAmmo == 'arrow' then
    lines[#lines + 1] = tr('Usable with your bow: %s arrows', snapshot.compatible)
  elseif snapshot.requiredAmmo == 'bolt' then
    lines[#lines + 1] = tr('Usable with your crossbow: %s bolts', snapshot.compatible)
  else
    lines[#lines + 1] = tr('Equip a bow or crossbow to use this ammunition.')
    lines[#lines + 1] = tr('The number shown is the total ammunition.')
  end
  return table.concat(lines, '\n')
end

local function render()
  local widget = ammoWidget()
  if not widget or not isEquipped() or not state or not state.equipped then
    clearDecoration()
    return
  end
  if decoratedWidget ~= widget then
    clearDecoration()
    decoratedWidget, baseTooltip = widget, widget:getTooltip()
  end
  local badge = badgeFor(widget)
  badge:setText(tostring(displayedCount(state)))
  badge:show()
  lastTooltip = tooltipFor(state)
  widget:setTooltip(lastTooltip)
  refreshHoveredTooltip(widget, lastTooltip)
end

local function uint(value)
  return type(value) == 'number' and value >= 0 and value <= 2147483647
    and value == math.floor(value)
end

local function valid(snapshot)
  if type(snapshot) ~= 'table' or snapshot.schema ~= 1
      or type(snapshot.equipped) ~= 'boolean' or type(snapshot.launcherReady) ~= 'boolean' then
    return false
  end
  for _, field in ipairs({'total', 'arrows', 'bolts', 'compatible'}) do
    if not uint(snapshot[field]) then return false end
  end
  if snapshot.arrows + snapshot.bolts > snapshot.total or snapshot.compatible > snapshot.total then
    return false
  end
  if not snapshot.equipped then
    return snapshot.quiverCid == 0 and snapshot.total == 0 and snapshot.arrows == 0
      and snapshot.bolts == 0 and snapshot.compatible == 0
      and snapshot.requiredAmmo == 'none' and not snapshot.launcherReady
  end
  if snapshot.quiverCid ~= QUIVER_CID then return false end
  if snapshot.requiredAmmo == 'arrow' then
    return snapshot.launcherReady and snapshot.compatible == snapshot.arrows
  elseif snapshot.requiredAmmo == 'bolt' then
    return snapshot.launcherReady and snapshot.compatible == snapshot.bolts
  end
  return snapshot.requiredAmmo == 'none' and not snapshot.launcherReady and snapshot.compatible == 0
end

local function requestStatus()
  if requestEvent or not registered or not isEquipped() then return end
  local generation = requestGeneration
  requestEvent = scheduleEvent(function()
    if generation ~= requestGeneration then return end
    requestEvent = nil
    if not registered or not isEquipped() then return end
    local protocol = g_game.getProtocolGame()
    if protocol and g_game.getFeature(GameExtendedOpcode) then
      protocol:sendExtendedOpcode(OPCODE, 'status')
    end
  end, 100)
end

local function onOpcode(protocol, opcode, buffer)
  if not registered or not g_game.isOnline() or protocol ~= g_game.getProtocolGame() or opcode ~= OPCODE then return end
  if type(buffer) ~= 'string' or #buffer > 4096 then return end
  local ok, snapshot = pcall(json.decode, buffer)
  if not ok or not valid(snapshot) then return end
  -- Copy only the contract fields; callers cannot mutate the accepted snapshot.
  state = {schema=1, equipped=snapshot.equipped, quiverCid=snapshot.quiverCid,
    total=snapshot.total, arrows=snapshot.arrows, bolts=snapshot.bolts,
    compatible=snapshot.compatible, requiredAmmo=snapshot.requiredAmmo,
    launcherReady=snapshot.launcherReady}
  cancelRequest()
  render()
end

function QuiverAmmo.init()
  ProtocolGame.registerExtendedOpcode(OPCODE, onOpcode)
  registered = true
end

function QuiverAmmo.reset()
  cancelRequest()
  state = nil
  clearDecoration()
end

function QuiverAmmo.start()
  QuiverAmmo.reset()
  requestStatus()
end

function QuiverAmmo.onInventoryChange(slot)
  if slot ~= InventorySlotAmmo and slot ~= InventorySlotLeft and slot ~= InventorySlotRight then return end
  -- Same-CID quiver replacements and hand swaps need a fresh server snapshot.
  -- Never retain a former quiver's contents or a former weapon's usable count.
  QuiverAmmo.reset()
  requestStatus()
end

function QuiverAmmo.terminate()
  QuiverAmmo.reset()
  if registered then ProtocolGame.unregisterExtendedOpcode(OPCODE) end
  registered = false
end

function QuiverAmmo.getState()
  if not state then return nil end
  local copy = {}
  for key, value in pairs(state) do copy[key] = value end
  return copy
end
