-- Corrupted creature visuals (client-side)
-- Applies a custom info color (name + health bar) and a dark pulsing outfit shader
-- to monsters whose names contain "Corrupted".

local CORRUPTED_NAME_TOKEN = "corrupted"
local CORRUPTED_INFO_COLOR_HEX = "#7a36a6ff"
local CORRUPTED_OUTFIT_SHADER = "outfit_corrupted_pulse"
local CORRUPTED_REFRESH_INTERVAL_MS = 1200
local applyingShader = false
local refreshEvent = nil

local function getCorruptedInfoColor()
  if Color then
    return Color(122, 54, 166)
  end

  if tocolor then
    return tocolor(CORRUPTED_INFO_COLOR_HEX)
  end

  return nil
end

local function isCorruptedMonster(creature)
  if not creature or not creature:isMonster() then
    return false
  end

  local name = creature:getName()
  if not name then
    return false
  end

  return name:lower():find(CORRUPTED_NAME_TOKEN, 1, true) ~= nil
end

local function applyCorruptedVisuals(creature)
  if not isCorruptedMonster(creature) then
    return
  end

  local infoColor = getCorruptedInfoColor()
  if infoColor then
    creature:setInformationColor(infoColor)
  end

  -- Avoid recursive outfit-change loops.
  if applyingShader then
    return
  end

  local outfit = creature:getOutfit()
  if outfit and outfit.shader == CORRUPTED_OUTFIT_SHADER then
    return
  end

  applyingShader = true
  local ok = false

  if creature.setOutfitShader then
    ok = pcall(function()
      creature:setOutfitShader(CORRUPTED_OUTFIT_SHADER)
    end)
  end

  if not ok and creature.setShader then
    ok = pcall(function()
      creature:setShader(CORRUPTED_OUTFIT_SHADER)
    end)
  end

  applyingShader = false

  if not ok then
    return
  end
end

local function refreshVisibleCorruptedCreatures()
  local localPlayer = g_game.getLocalPlayer()
  if not localPlayer then
    return
  end

  local spectators = g_map.getSpectators(localPlayer:getPosition(), true)
  for _, creature in ipairs(spectators) do
    applyCorruptedVisuals(creature)
  end
end

local function onCreatureAppear(creature)
  applyCorruptedVisuals(creature)
end

local function onCreatureOutfitChange(creature, outfit, oldOutfit)
  applyCorruptedVisuals(creature)
end

local function stopRefreshLoop()
  if refreshEvent then
    removeEvent(refreshEvent)
    refreshEvent = nil
  end
end

local function startRefreshLoop()
  stopRefreshLoop()

  local function tick()
    refreshVisibleCorruptedCreatures()
    if g_game.isOnline() then
      refreshEvent = scheduleEvent(tick, CORRUPTED_REFRESH_INTERVAL_MS)
    else
      refreshEvent = nil
    end
  end

  if g_game.isOnline() then
    refreshEvent = scheduleEvent(tick, CORRUPTED_REFRESH_INTERVAL_MS)
  end
end

local function onGameStart()
  -- Delay a little so visible creatures are fully initialized.
  scheduleEvent(refreshVisibleCorruptedCreatures, 200)
  startRefreshLoop()
end

local function onGameEnd()
  stopRefreshLoop()
end

connect(Creature, {
  onAppear = onCreatureAppear,
  onOutfitChange = onCreatureOutfitChange,
})

connect(g_game, {
  onGameStart = onGameStart,
  onGameEnd = onGameEnd,
})
