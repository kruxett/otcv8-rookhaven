-- The server publishes learned class spells. Existing text hotkeys remain usable.
ClassSpells = {}
local window, button, tickEvent, featureEnabled
local catalog, cards = nil, {}
local cooldowns, shared = {}, {}
local classes = {
  reaver = {'cleaving_arc', 'rend'}, blademaster = {'focused_thrust', 'flurry'},
  earthshaker = {'crushing_blow', 'rolling_thunder'}, marksman = {'blitzshot', 'scattershot'},
  arcanist = {'resonant_burst', 'arcane_surge'}, lifekeeper = {'mending_thread', 'essence_lash'}
}
local gearHints = {
  reaver='Requires an equipped axe.',
  blademaster='Requires an equipped sword.',
  earthshaker='Requires an equipped club.',
  marksman='Requires an equipped bow/crossbow and compatible ammunition.',
  arcanist='Requires an equipped elemental wand.',
  lifekeeper='Requires an equipped elemental rod.'
}
local function enabled()
  return featureEnabled and featureEnabled() and g_resources.getLayout() == 'retro' and g_game.isOnline()
end
function ClassSpells.init(capabilityCallback) featureEnabled=capabilityCallback end
local function integer(value, maximum)
  return type(value) == 'number' and value >= 0 and value <= maximum and value == math.floor(value)
end
local function text(value, maximum)
  return type(value) == 'string' and #value > 0 and #value <= maximum and not value:find('[%z\1-\8\11\12\14-\31]')
end
local function seconds(ms) return string.format('%g', ms / 1000) end
local function setStatus(message, error)
  if window then
    local label = window:getChildById('status')
    label:setText(message)
    label:setColor(error and '#dca065' or '#c7c1b2')
  end
end
function ClassSpells.clamp()
  if not window then return end
  local root = g_ui.getRootWidget():getRect()
  window:setSize({width = math.min(580, root.width - 16), height = math.min(530, root.height - 16)})
  window:setPosition({x = root.x + math.floor((root.width - window:getWidth()) / 2),
    y = root.y + math.floor((root.height - window:getHeight()) / 2)})
end
function ClassSpells.hide()
  if window then window:hide() end
  if button then button:setOn(false) end
end
local function knownObstacle(spell)
  local player=g_game.getLocalPlayer()
  if not player then return nil end
  -- Base costs may be discounted by passives. Only zero mana is certain;
  -- equipped-item type, wield requirements, target and final cost stay server-owned.
  if spell.mana>0 and player:getMana()==0 then return 'No mana' end
  if not player:getInventoryItem(InventorySlotRight) and not player:getInventoryItem(InventorySlotLeft) then
    return 'Equip your class weapon'
  end
  if catalog.classId=='marksman' and not player:getInventoryItem(InventorySlotAmmo) then return 'Equip ammunition' end
  local passives=modules.game_passives and modules.game_passives.getState()
  if passives and passives.classId==catalog.classId and passives.runtime.weaponActive==false then
    return 'Class weapon required'
  end
end
local function updateCooldowns()
  if tickEvent then removeEvent(tickEvent); tickEvent = nil end
  if not catalog then return end
  local now, ticking = g_clock.millis(), false
  for _, spell in ipairs(catalog.spells) do
    local group = math.max(0, (shared[spell.kind] or 0) - now)
    ticking = ticking or group > 0
    local card = cards[spell.id]
    if card then
      local message = group > 0 and string.format('Shared %s cooldown: %.1f s', spell.kind, group / 1000) or 'Cooldown ready'
      local obstacle=knownObstacle(spell)
      if obstacle then message=message..' | '..obstacle end
      card:getChildById('cooldown'):setText(message)
      card:getChildById('cooldown'):setTooltip(message..'\n'..gearHints[catalog.classId]..'\nMana shown is the base cost; talents may change it. Your class weapon and a valid target in range are required.')
      card:getChildById('cast'):setEnabled(enabled() and group == 0)
    end
  end
  if ticking or window and window:isVisible() then tickEvent = scheduleEvent(updateCooldowns, ticking and 100 or 250) end
end
function ClassSpells.cast(id)
  if not enabled() or not catalog then return false end
  local spell
  for _, entry in ipairs(catalog.spells) do if entry.id == id then spell = entry; break end end
  if not spell then return false end
  local now = g_clock.millis()
  if (shared[spell.kind] or 0) > now then
    setStatus('Wait for your shared cooldown to finish.', true); return false
  end
  local words = spell.words
  if spell.parameter and window then
    local target = window:getChildById('targetName'):getText():trim()
    if #target > 0 then
      if #target > 30 or not target:match("^[A-Za-z][A-Za-z '%-]*$") then
        setStatus('Enter a player name without quotes or commands.', true); return false
      end
      words = words .. ' "' .. target .. '"'
    end
  end
  g_game.talk(words)
  setStatus('Invoking ' .. spell.name .. '.')
  -- No predicted mana debit or cooldown: wait for the authoritative event.
  return true
end
local function ensureWindow()
  if window or not catalog then return end
  window = g_ui.displayUI('classspells', g_ui.getRootWidget())
  window:setText(catalog.className .. ' - Spells')
  window:getChildById('classLabel'):setText('Your two learned ' .. catalog.className .. ' spells')
  local parameter = false
  for index, spell in ipairs(catalog.spells) do
    local card = window:getChildById(index == 1 and 'spellOne' or 'spellTwo')
    cards[spell.id] = card
    card:getChildById('icon'):setImageSource(spell.icon)
    card:getChildById('name'):setText(spell.name)
    card:getChildById('words'):setText(spell.words .. (spell.parameter and ' [player name]' or ''))
    local cost = 'Base mana: ' .. spell.mana .. ' | Range: ' .. spell.range .. ' | Cooldown: ' .. seconds(spell.cooldown) .. ' s'
    if spell.groupCooldown then cost = cost .. '\nShared ' .. spell.kind .. ' exhaustion: ' .. seconds(spell.groupCooldown) .. ' s' end
    card:getChildById('cost'):setText(cost)
    card:getChildById('gear'):setText(gearHints[catalog.classId])
    card:getChildById('descriptionScroll'):getChildById('description'):setText(spell.description)
    card:getChildById('cast').onClick = function() ClassSpells.cast(spell.id) end
    parameter = parameter or spell.parameter
  end
  window:getChildById('targetLabel'):setVisible(parameter)
  window:getChildById('targetName'):setVisible(parameter)
  ClassSpells.clamp()
  updateCooldowns()
end
function ClassSpells.show()
  if not enabled() or not catalog then return false end
  ensureWindow(); window:show(); window:raise(); window:focus()
  updateCooldowns()
  if button then button:setOn(true) end
  return true
end
local function ensureButton()
  if button or not catalog then return end
  button = modules.client_topmenu.addRightGameToggleButton('classSpellsButton', 'Learned class spells',
    '/images/topbuttons/spelllist', function()
      if window and window:isVisible() then ClassSpells.hide() else ClassSpells.show() end
    end, false, 8)
end
function ClassSpells.reset()
  if tickEvent then removeEvent(tickEvent); tickEvent = nil end
  if window then window:destroy(); window = nil end
  if button then
    button:destroy(); button = nil
    if modules.game_buttons and modules.game_buttons.updateOrder then modules.game_buttons.updateOrder() end
  end
  catalog, cards, cooldowns, shared = nil, {}, {}, {}
end
function ClassSpells.receive(data, expectedClass)
  if not enabled() or type(data) ~= 'table' or data.v ~= 1 then return false end
  if data.action == 'class_spells' then
    local expected = classes[data.classId]
    if not expected or data.classId ~= expectedClass or not text(data.className, 40) or
      type(data.spells) ~= 'table' or #data.spells ~= 2 then return false end
    local spells, seen = {}, {}
    for _, spell in ipairs(data.spells) do
      if type(spell) ~= 'table' or (spell.id ~= expected[1] and spell.id ~= expected[2]) or seen[spell.id] or
        not text(spell.name, 48) or not text(spell.words, 96) or not spell.words:match('^[A-Za-z ]+$') or
        not integer(spell.mana, 100000) or not integer(spell.cooldown, 600000) or not integer(spell.range, 10) or
        (spell.kind ~= 'combat' and spell.kind ~= 'healing') or not text(spell.description, 1200) or
        not text(spell.icon, 120) or not spell.icon:match('^/images/game/passives/[a-z_]+$') or
        (spell.groupCooldown ~= nil and not integer(spell.groupCooldown, 600000)) or
        (spell.parameter ~= nil and type(spell.parameter) ~= 'boolean' and not text(spell.parameter, 30)) or
        (spell.parameter and spell.id ~= 'mending_thread') then return false end
      seen[spell.id] = true
      spells[#spells + 1] = {id = spell.id, name = spell.name, words = spell.words, mana = spell.mana,
        cooldown = spell.cooldown, range = spell.range, kind = spell.kind, description = spell.description,
        icon = spell.icon, parameter = not not spell.parameter, groupCooldown = spell.groupCooldown}
    end
    local wasVisible = window and window:isVisible()
    if catalog and catalog.classId ~= data.classId then ClassSpells.reset()
    elseif window then window:destroy(); window = nil; cards = {} end
    catalog = {classId = data.classId, className = data.className, spells = spells}
    ensureButton()
    if wasVisible then ClassSpells.show() end
    updateCooldowns()
    return true
  end
  if data.action == 'class_spell_cooldown' then
    if not catalog or not integer(data.duration, 600000) or (data.kind ~= 'combat' and data.kind ~= 'healing') then return false end
    if not ((type(data.id) == 'string' and #data.id <= 96) or integer(data.id, 65535)) then return false end
    local known = false
    for _, spell in ipairs(catalog.spells) do if spell.id == data.id and spell.kind == data.kind then known = true; break end end
    local now = g_clock.millis()
    if known then cooldowns[data.id] = math.max(cooldowns[data.id] or 0, now + data.duration) end
    -- Legacy spells also exhaust this group. Unknown IDs do not create cards.
    shared[data.kind] = math.max(shared[data.kind] or 0, now + data.duration)
    updateCooldowns()
    return true
  end
  return false
end
-- Inspection hooks for the native, ordinary-player spell probes.
function ClassSpells.getState() return {catalog = catalog, cooldowns = cooldowns, shared = shared} end
function ClassSpells.getWindow() return window end
function ClassSpells.getButton() return button end
function ClassSpells.getCard(id) return cards[id] end
