Icons = {}
Icons[PlayerStates.Poison] = { tooltip = tr('You are poisoned'), path = '/images/game/states/poisoned', id = 'condition_poisoned' }
Icons[PlayerStates.Burn] = { tooltip = tr('You are burning'), path = '/images/game/states/burning', id = 'condition_burning' }
Icons[PlayerStates.Energy] = { tooltip = tr('You are electrified'), path = '/images/game/states/electrified', id = 'condition_electrified' }
Icons[PlayerStates.Drunk] = { tooltip = tr('You are drunk'), path = '/images/game/states/drunk', id = 'condition_drunk' }
Icons[PlayerStates.ManaShield] = { tooltip = tr('You are protected by a magic shield'), path = '/images/game/states/magic_shield', id = 'condition_magic_shield' }
Icons[PlayerStates.Paralyze] = { tooltip = tr('You are paralysed'), path = '/images/game/states/slowed', id = 'condition_slowed' }
Icons[PlayerStates.Haste] = { tooltip = tr('You are hasted'), path = '/images/game/states/haste', id = 'condition_haste' }
Icons[PlayerStates.Swords] = { tooltip = tr('You may not logout during a fight'), path = '/images/game/states/logout_block', id = 'condition_logout_block' }
Icons[PlayerStates.Drowning] = { tooltip = tr('You are drowning'), path = '/images/game/states/drowning', id = 'condition_drowning' }
Icons[PlayerStates.Freezing] = { tooltip = tr('You are freezing'), path = '/images/game/states/freezing', id = 'condition_freezing' }
Icons[PlayerStates.Dazzled] = { tooltip = tr('You are dazzled'), path = '/images/game/states/dazzled', id = 'condition_dazzled' }
Icons[PlayerStates.Cursed] = { tooltip = tr('You are cursed'), path = '/images/game/states/cursed', id = 'condition_cursed' }
Icons[PlayerStates.PartyBuff] = { tooltip = tr('You are strengthened'), path = '/images/game/states/strengthened', id = 'condition_strengthened' }
Icons[PlayerStates.PzBlock] = { tooltip = tr('You may not logout or enter a protection zone'), path = '/images/game/states/protection_zone_block', id = 'condition_protection_zone_block' }
Icons[PlayerStates.Pz] = { tooltip = tr('You are within a protection zone'), path = '/images/game/states/protection_zone', id = 'condition_protection_zone' }
Icons[PlayerStates.Bleeding] = { tooltip = tr('You are bleeding'), path = '/images/game/states/bleeding', id = 'condition_bleeding' }
Icons[PlayerStates.Hungry] = { tooltip = tr('You are hungry'), path = '/images/game/states/hungry', id = 'condition_hungry' }

local WATER_OFFERINGS_EXP_BUFF_OPCODE = 32
local WATER_OFFERINGS_EXP_BUFF_ICON_ID = 'condition_water_offerings_expbuff'
local WATER_OFFERINGS_EXP_BUFF_ICON_PATH = '/images/game/states/expbuff'
local waterOfferingsExpBuffState = { active = false, percent = 0, expiresAt = 0 }

healthInfoWindow = nil
healthBar = nil
manaBar = nil
experienceBar = nil
soulLabel = nil
capLabel = nil
healthTooltip = 'Your character health is %d out of %d.'
manaTooltip = 'Your character mana is %d out of %d.'
experienceTooltip = 'You have %d%% to advance to level %d.'

overlay = nil
healthCircleFront = nil
manaCircleFront = nil
healthCircle = nil
manaCircle = nil
topHealthBar = nil
topManaBar = nil

local function requestWaterOfferingsExpBuffStatus()
  local protocol = g_game.getProtocolGame()
  if protocol and protocol.sendExtendedOpcode then
    protocol:sendExtendedOpcode(WATER_OFFERINGS_EXP_BUFF_OPCODE, 'status')
  end
end

local function updateWaterOfferingsExpBuffIcon()
  if not healthInfoWindow then
    return
  end

  local content = healthInfoWindow:recursiveGetChildById('conditionPanel')
  if not content then
    return
  end

  local icon = content:getChildById(WATER_OFFERINGS_EXP_BUFF_ICON_ID)
  local remaining = (waterOfferingsExpBuffState.expiresAt or 0) - os.time()
  if not waterOfferingsExpBuffState.active or remaining <= 0 then
    if icon then
      icon:destroy()
    end
    return
  end

  if not icon then
    icon = g_ui.createWidget('ConditionWidget', content)
    icon:setId(WATER_OFFERINGS_EXP_BUFF_ICON_ID)
    icon:setImageSource(WATER_OFFERINGS_EXP_BUFF_ICON_PATH)
  end

  local hours = math.floor(remaining / 3600)
  local minutes = math.floor((remaining % 3600) / 60)
  local remainText = (hours > 0) and string.format('%dh %02dm', hours, minutes) or string.format('%dm', math.max(1, minutes))
  icon:setTooltip(string.format('Sacred Water Offering: +%d%% experience and skill gain.\nTime remaining: %s.',
    waterOfferingsExpBuffState.percent or 0,
    remainText))
end

local function onWaterOfferingsExpBuffOpcode(protocol, opcode, buffer)
  local parts = string.split(buffer or '', '|')
  local active = tonumber(parts[1] or '0') == 1
  local percent = tonumber(parts[2] or '0') or 0
  local expiresAt = tonumber(parts[3] or '0') or 0

  waterOfferingsExpBuffState.active = active and percent > 0 and expiresAt > os.time()
  waterOfferingsExpBuffState.percent = percent
  waterOfferingsExpBuffState.expiresAt = expiresAt
  updateWaterOfferingsExpBuffIcon()
end

function init()
  ProtocolGame.registerExtendedOpcode(WATER_OFFERINGS_EXP_BUFF_OPCODE, onWaterOfferingsExpBuffOpcode)

  connect(LocalPlayer, { onHealthChange = onHealthChange,
                         onManaChange = onManaChange,
                         onLevelChange = onLevelChange,
                         onStatesChange = onStatesChange,
                         onSoulChange = onSoulChange,
                         onFreeCapacityChange = onFreeCapacityChange })

  connect(g_game, { onGameEnd = offline })
  connect(g_game, { onGameStart = online })

  healthInfoWindow = g_ui.loadUI('healthinfo', modules.game_interface.getRightPanel())
  if not healthInfoWindow then
    return
  end
  healthInfoWindow:disableResize()
  
  if not healthInfoWindow.forceOpen then
    healthInfoButton = modules.client_topmenu.addRightGameToggleButton('healthInfoButton', tr('Health Information'), '/images/topbuttons/healthinfo', toggle)
    if g_app.isMobile() then
      healthInfoButton:hide()
    else
      healthInfoButton:setOn(true)
    end
  end

  healthBar = healthInfoWindow:recursiveGetChildById('healthBar')
  manaBar = healthInfoWindow:recursiveGetChildById('manaBar')
  experienceBar = healthInfoWindow:recursiveGetChildById('experienceBar')
  soulLabel = healthInfoWindow:recursiveGetChildById('soulLabel')
  capLabel = healthInfoWindow:recursiveGetChildById('capLabel')

  if healthBar then
    healthBar:setOn(true)
  end

  if manaBar then
    manaBar:setOn(true)
  end

  -- Hide all HeadlessMiniWindow chrome widgets
  local topBar = healthInfoWindow:getChildById('miniwindowTopBar')
  if topBar then
    topBar:setVisible(false)
    topBar:setHeight(0)
    topBar:setMargin(0)
  end

  local scrollBar = healthInfoWindow:getChildById('miniwindowScrollBar')
  if scrollBar then
    scrollBar:setVisible(false)
    scrollBar:setWidth(0)
    scrollBar:setMarginTop(0)
    scrollBar:setMarginRight(0)
    scrollBar:setMarginBottom(0)
  end

  local resizeBorder = healthInfoWindow:getChildById('bottomResizeBorder')
  if resizeBorder then
    resizeBorder:setVisible(false)
    resizeBorder:setHeight(0)
    resizeBorder:setMargin(0)
  end

  -- Disable overlay/top bars/health-mana circles entirely
  overlay = nil
  healthCircleFront = nil
  manaCircleFront = nil
  healthCircle = nil
  manaCircle = nil
  topHealthBar = nil
  topManaBar = nil
  
  -- load condition icons
  for k,v in pairs(Icons) do
    g_textures.preload(v.path)
  end

  if g_game.isOnline() then
    local localPlayer = g_game.getLocalPlayer()
    onHealthChange(localPlayer, localPlayer:getHealth(), localPlayer:getMaxHealth())
    onManaChange(localPlayer, localPlayer:getMana(), localPlayer:getMaxMana())
    onLevelChange(localPlayer, localPlayer:getLevel(), localPlayer:getLevelPercent())
    onStatesChange(localPlayer, localPlayer:getStates(), 0)
    onSoulChange(localPlayer, localPlayer:getSoul())
    onFreeCapacityChange(localPlayer, localPlayer:getFreeCapacity())
    requestWaterOfferingsExpBuffStatus()
  end


  hideLabels()
  hideExperience()

  healthInfoWindow:setup()
  addEvent(function()
    updateCompactHeight()
  end)

  if g_app.isMobile() then
    healthInfoWindow:close()
    healthInfoButton:setOn(false)  
  end
end

function terminate()
  ProtocolGame.unregisterExtendedOpcode(WATER_OFFERINGS_EXP_BUFF_OPCODE)

  disconnect(LocalPlayer, { onHealthChange = onHealthChange,
                            onManaChange = onManaChange,
                            onLevelChange = onLevelChange,
                            onStatesChange = onStatesChange,
                            onSoulChange = onSoulChange,
                            onFreeCapacityChange = onFreeCapacityChange })

  disconnect(g_game, { onGameEnd = offline })
  disconnect(g_game, { onGameStart = online })
  if overlay then
    disconnect(overlay, { onGeometryChange = onOverlayGeometryChange })
  end
  
  healthInfoWindow:destroy()
  if healthInfoButton then
    healthInfoButton:destroy()
  end
  if overlay then
    overlay:destroy()
  end
end

function toggle()
  if not healthInfoButton then return end
  if healthInfoButton:isOn() then
    healthInfoWindow:close()
    healthInfoButton:setOn(false)
  else
    healthInfoWindow:open()
    healthInfoButton:setOn(true)
  end
end

function toggleIcon(bitChanged)
  local content = healthInfoWindow:recursiveGetChildById('conditionPanel')

  local icon = content:getChildById(Icons[bitChanged].id)
  if icon then
    icon:destroy()
  else
    icon = loadIcon(bitChanged)
    icon:setParent(content)
  end
end

function loadIcon(bitChanged)
  local icon = g_ui.createWidget('ConditionWidget', content)
  icon:setId(Icons[bitChanged].id)
  icon:setImageSource(Icons[bitChanged].path)
  icon:setTooltip(Icons[bitChanged].tooltip)
  return icon
end

function offline()
  healthInfoWindow:recursiveGetChildById('conditionPanel'):destroyChildren()
  waterOfferingsExpBuffState.active = false
end

function online()
  requestWaterOfferingsExpBuffStatus()
end

-- hooked events
function onMiniWindowClose()
  if healthInfoButton then
    healthInfoButton:setOn(false)
  end
end

function onHealthChange(localPlayer, health, maxHealth)
  if health > maxHealth then
    maxHealth = health
  end

  if healthBar then
    healthBar:setText(comma_value(health) .. ' / ' .. comma_value(maxHealth))
    healthBar:setTooltip(tr(healthTooltip, health, maxHealth))
    healthBar:setValue(health, 0, maxHealth)
  end

  if topHealthBar then
    topHealthBar:setText(comma_value(health) .. ' / ' .. comma_value(maxHealth))
    topHealthBar:setTooltip(tr(healthTooltip, health, maxHealth))
    topHealthBar:setValue(health, 0, maxHealth)
  end

  if healthCircleFront then
    local healthPercent = math.floor(g_game.getLocalPlayer():getHealthPercent())
    local Yhppc = math.floor(208 * (1 - (healthPercent / 100)))
    local rect = { x = 0, y = Yhppc, width = 63, height = 208 - Yhppc + 1 }
    healthCircleFront:setImageClip(rect)
    healthCircleFront:setImageRect(rect)

    if healthPercent > 92 then
      healthCircleFront:setImageColor("#00BC00FF")
    elseif healthPercent > 60 then
      healthCircleFront:setImageColor("#50A150FF")
    elseif healthPercent > 30 then
      healthCircleFront:setImageColor("#A1A100FF")
    elseif healthPercent > 8 then
      healthCircleFront:setImageColor("#BF0A0AFF")
    elseif healthPercent > 3 then
      healthCircleFront:setImageColor("#910F0FFF")
    else
      healthCircleFront:setImageColor("#850C0CFF")
    end
  end
end

function onManaChange(localPlayer, mana, maxMana)
  if mana > maxMana then
    maxMana = mana
  end
  
  if manaBar then
    manaBar:setOn(true)
    manaBar:setText(comma_value(mana) .. ' / ' .. comma_value(maxMana))
    manaBar:setTooltip(tr(manaTooltip, mana, maxMana))
    manaBar:setValue(mana, 0, maxMana)
  end

  if topManaBar then
    topManaBar:setText(comma_value(mana) .. ' / ' .. comma_value(maxMana))
    topManaBar:setTooltip(tr(manaTooltip, mana, maxMana))
    topManaBar:setValue(mana, 0, maxMana)
  end

  if manaCircleFront then
    local Ymppc = math.floor(208 * (1 - (math.floor((maxMana - (maxMana - mana)) * 100 / maxMana) / 100)))
    local rect = { x = 0, y = Ymppc, width = 63, height = 208 - Ymppc + 1 }
    manaCircleFront:setImageClip(rect)
    manaCircleFront:setImageRect(rect)
  end
end

function onLevelChange(localPlayer, value, percent)
  if experienceBar then
    experienceBar:setText(percent .. '%')
    experienceBar:setTooltip(tr(experienceTooltip, percent, value+1))
    experienceBar:setPercent(percent)
  end
end

function onSoulChange(localPlayer, soul)
  if soulLabel then
    soulLabel:setText(tr('Soul') .. ': ' .. soul)
  end
end

function onFreeCapacityChange(player, freeCapacity)
  if capLabel then
    capLabel:setText(tr('Cap') .. ': ' .. freeCapacity)
  end
end

function onStatesChange(localPlayer, now, old)
  if now == old then return end

  local bitsChanged = bit32.bxor(now, old)
  for i = 1, 32 do
    local pow = math.pow(2, i-1)
    if pow > bitsChanged then break end
    local bitChanged = bit32.band(bitsChanged, pow)
    if bitChanged ~= 0 then
      toggleIcon(bitChanged)
    end
  end
  updateWaterOfferingsExpBuffIcon()
end

-- personalization functions
updateCompactHeight = function()
  if not healthInfoWindow then
    return
  end

  local content = healthInfoWindow:recursiveGetChildById('contentsPanel')
  local contentHeight = 0

  local function addWidgetHeight(widget, includeHidden)
    if widget and (includeHidden or widget:isVisible()) then
      contentHeight = contentHeight + widget:getHeight() + widget:getMarginTop() + widget:getMarginBottom()
    end
  end

  addWidgetHeight(healthBar, true)
  addWidgetHeight(manaBar, true)
  addWidgetHeight(experienceBar)
  addWidgetHeight(healthInfoWindow:recursiveGetChildById('conditionPanel'))
  addWidgetHeight(capLabel)
  addWidgetHeight(soulLabel)

  local marginTop = content and content:getMarginTop() or 0
  local marginBottom = content and content:getMarginBottom() or 0
  local paddingTop = content and content:getPaddingTop() or 0
  local paddingBottom = content and content:getPaddingBottom() or 0
  local chromeHeight = 0
  local targetHeight = contentHeight + marginTop + marginBottom + paddingTop + paddingBottom + chromeHeight

  healthInfoWindow:setHeight(math.max(targetHeight, healthInfoWindow.minimizedHeight or targetHeight))
end

function hideLabels()
  if capLabel then
    capLabel:setOn(false)
  end
  if soulLabel then
    soulLabel:setOn(false)
  end
  local content = healthInfoWindow and healthInfoWindow:recursiveGetChildById('conditionPanel') or nil
  if content then
    content:setVisible(false)
  end
  updateCompactHeight()
end

function hideExperience()
  if experienceBar then
    experienceBar:setOn(false)
  end
  updateCompactHeight()
end

function setHealthTooltip(tooltip)
  healthTooltip = tooltip

  local localPlayer = g_game.getLocalPlayer()
  if localPlayer then
    healthBar:setTooltip(tr(healthTooltip, localPlayer:getHealth(), localPlayer:getMaxHealth()))
  end
end

function setManaTooltip(tooltip)
  manaTooltip = tooltip

  local localPlayer = g_game.getLocalPlayer()
  if localPlayer then
    manaBar:setTooltip(tr(manaTooltip, localPlayer:getMana(), localPlayer:getMaxMana()))
  end
end

function setExperienceTooltip(tooltip)
  experienceTooltip = tooltip

  local localPlayer = g_game.getLocalPlayer()
  if localPlayer then
    experienceBar:setTooltip(tr(experienceTooltip, localPlayer:getLevelPercent(), localPlayer:getLevel()+1))
  end
end

function onOverlayGeometryChange() 
  if g_app.isMobile() then
    topHealthBar:setMarginTop(35)
    topManaBar:setMarginTop(35)
    local width = overlay:getWidth() 
    local margin = width / 3 + 10
    topHealthBar:setMarginLeft(margin)
    topManaBar:setMarginRight(margin)    
    return
  end

  local classic = g_settings.getBoolean("classicView")
  local minMargin = 40
  if classic then
    topHealthBar:setMarginTop(15)
    topManaBar:setMarginTop(15)
  else
    topHealthBar:setMarginTop(45 - overlay:getParent():getMarginTop())
    topManaBar:setMarginTop(45 - overlay:getParent():getMarginTop())  
    minMargin = 200
  end

  local height = overlay:getHeight()
  local width = overlay:getWidth()
     
  topHealthBar:setMarginLeft(math.max(minMargin, (width - height + 50) / 2 + 2))
  topManaBar:setMarginRight(math.max(minMargin, (width - height + 50) / 2 + 2))
end