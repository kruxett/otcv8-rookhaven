-- Inventory presentation only: never change an Item, shader, rarity frame, or
-- the slot's drag/drop/look behavior. Status adds to the native item tooltip.
-- Four native 32x32 frames form each strip.
LegendaryInventoryOverlay = {}
local profiles = {
  [11868] = 'deepwarden', [11869] = 'oath-of-the-deep',
  [11870] = 'ashcleaver', [11871] = 'elders-reckoning',
  [11872] = 'forgeheart', [11873] = 'mountains-verdict',
  [11874] = 'wayfarer', [11875] = 'deepforge-arbalest',
  [11876] = 'stonewake', [11877] = 'ashen-requiem'
}
local slots = {}
local timer = nil
local frame = 1
local status = nil
local lastProc = 0
local flashUntil = 0
local OPCODE = 105
local signatureNames = {
  [11868] = 'Swordguard', [11869] = 'Sweeping Edge', [11870] = 'Ground Ember',
  [11871] = 'Frontal Sweep', [11872] = 'Stone Mend', [11873] = 'Stormcall',
  [11874] = 'Windstride', [11875] = 'Ricochet', [11876] = 'Living Bark', [11877] = 'Soul Draw'
}

local function statusTooltip(state, data, active)
  -- UIItem:onItemChange and other item helpers can replace the native tooltip.
  -- Adopt that newer value instead of overwriting it with an old cached one.
  local current = state.parent:getTooltip()
  if current ~= state.tooltipApplied then state.tooltipBase = current end
  local lines = {}
  if active and data then
    local name = signatureNames[state.clientId]
    if data.charge > 0 and state.clientId == 11876 then
      lines[#lines + 1] = string.format('[G%d] %s ready: %ds.', data.charge, name, data.charge)
      lines[#lines + 1] = string.format('Ward budget: %d HP; %d direct hits remaining.', data.ward, data.hits)
      lines[#lines + 1] = 'Each hit absorbs up to 6 HP in PvE or 3 HP in PvP.'
    elseif data.charge > 0 then
      lines[#lines + 1] = string.format('[G%d] %s ready: %ds.', data.charge, name, data.charge)
      lines[#lines + 1] = 'Next melee physical hit: 50% less damage, up to 16 PvE / 8 PvP.'
    elseif data.wind > 0 then
      lines[#lines + 1] = string.format('[M%d] %s movement bonus: %ds (+40 speed).', data.wind, name, data.wind)
    elseif data.cooldown == 0 then
      lines[#lines + 1] = name .. ' activated.'
    end
    if data.cooldown > 0 then
      lines[#lines + 1] = string.format('%s: shared cooldown %ds.', name, data.cooldown)
      lines[#lines + 1] = 'Changing Legendary weapons does not reset the cooldown.'
    end
  end
  local base = state.tooltipBase
  local suffix = table.concat(lines, '\n')
  if suffix == '' then state.tooltipApplied = base
  else state.tooltipApplied = (type(base) == 'string' and base ~= '' and (base .. '\n\n') or '') .. suffix end
  state.parent:setTooltip(state.tooltipApplied)
end

local function applyStatus(state)
  local data = status and status.clientId == state.clientId and status or nil
  local charged = data and (data.charge > 0 or data.wind > 0)
  local active = charged or (data and data.cooldown > 0) or g_clock.millis() < flashUntil
  state.badge:setVisible(active and data ~= nil)
  statusTooltip(state, data, active)
  if not data then return end
  state.badge:setColor(charged and '#b9e3a0' or '#e3c17a')
  state.badge:setText(data.charge > 0 and ('G' .. data.charge)
    or data.wind > 0 and ('M' .. data.wind)
    or data.cooldown > 0 and tostring(data.cooldown) or '*')
end

local function onStatus(protocol, opcode, buffer)
  if not g_game.isOnline() or protocol ~= g_game.getProtocolGame() or opcode ~= OPCODE
    or type(buffer) ~= 'string' or #buffer > 1024 then return end
  local ok, data = pcall(json.decode, buffer)
  if not ok or type(data) ~= 'table' or data.v ~= 1 then return end
  for _, key in ipairs({'clientId', 'cooldown', 'charge', 'ward', 'hits', 'wind', 'procs'}) do
    if type(data[key]) ~= 'number' or data[key] < 0 or data[key] ~= math.floor(data[key]) then return end
  end
  if data.clientId ~= 0 and not profiles[data.clientId] then return end
  if data.cooldown > 12 or data.charge > 8 or data.wind > 3 or data.ward > 12 or data.hits > 2 then return end
  if data.procs > lastProc then flashUntil = g_clock.millis() + 1000 end
  lastProc = data.procs
  status = data.clientId ~= 0 and data or nil
  for _, state in pairs(slots) do applyStatus(state) end
end

function LegendaryInventoryOverlay.init()
  ProtocolGame.registerExtendedOpcode(OPCODE, onStatus)
end

function LegendaryInventoryOverlay.terminate()
  LegendaryInventoryOverlay.clear()
  ProtocolGame.unregisterExtendedOpcode(OPCODE)
end

local function applyFrame(widget)
  widget:setImageClip({x = (frame - 1) * 32, y = 0, width = 32, height = 32})
end

local function cancelTimer()
  if timer then removeEvent(timer); timer = nil end
end

local function removeSlot(slot)
  local state = slots[slot]
  if state and state.parent and not state.parent:isDestroyed() and state.parent:getTooltip() == state.tooltipApplied then
    state.parent:setTooltip(state.tooltipBase)
  end
  if state and state.widget then state.widget:destroy() end
  if state and state.badge then state.badge:destroy() end
  slots[slot] = nil
end

local function tick()
  timer = nil
  if not g_game.isOnline() then LegendaryInventoryOverlay.clear(); return end
  frame = frame % 4 + 1
  local active = false
  for slot, state in pairs(slots) do
    local item = state.parent:getItem()
    if not item or item:getId() ~= state.clientId then
      removeSlot(slot)
    else
      applyFrame(state.widget)
      applyStatus(state)
      active = true
    end
  end
  if active then timer = scheduleEvent(tick, 500) end
end

function LegendaryInventoryOverlay.clear()
  cancelTimer()
  for slot in pairs(slots) do removeSlot(slot) end
  frame = 1
  status = nil; lastProc = 0; flashUntil = 0
end

function LegendaryInventoryOverlay.update(slot, parent, item)
  if slot ~= InventorySlotLeft and slot ~= InventorySlotRight then return end
  removeSlot(slot)
  local clientId = item and item:getId()
  local profile = clientId and profiles[clientId]
  if parent and type(profile) == 'string' and profile:match('^[a-z-]+$') then
    local overlay = g_ui.createWidget('UIWidget', parent)
    overlay:setId('legendaryInventoryOverlay')
    overlay:setSize({width = 32, height = 32})
    overlay:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
    overlay:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
    overlay:setPhantom(true)
    overlay:setFocusable(false)
    overlay:setImageSource('/images/items/legendary/' .. profile .. '-frames.png')
    applyFrame(overlay)
    local badge = g_ui.createWidget('UILabel', parent)
    badge:setId('legendarySignatureStatus')
    badge:setSize({width = 25, height = 12})
    badge:addAnchor(AnchorRight, 'parent', AnchorRight)
    badge:addAnchor(AnchorBottom, 'parent', AnchorBottom)
    badge:setFont('verdana-11px-monochrome')
    badge:setTextAlign(AlignCenter)
    badge:setBackgroundColor('#202020cc')
    badge:setPhantom(true); badge:setFocusable(false)
    slots[slot] = {widget = overlay, badge = badge, parent = parent, clientId = clientId,
      tooltipBase = parent:getTooltip(), tooltipApplied = parent:getTooltip()}
    applyStatus(slots[slot])
  end
  if next(slots) then
    if not timer then timer = scheduleEvent(tick, 500) end
  else
    cancelTimer()
    frame = 1
  end
end
