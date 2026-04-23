-- Corrupted creature visuals (client-side)
-- Applies a custom info color (name + health bar) and a dark pulsing outfit shader
-- to monsters whose names contain "Corrupted".

local CORRUPTED_NAME_TOKEN = "corrupted"
local CORRUPTED_INFO_COLOR = Color(140, 60, 190)
local CORRUPTED_OUTFIT_SHADER = "outfit_corrupted_pulse"

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

  creature:setInformationColor(CORRUPTED_INFO_COLOR)
  creature:setOutfitShader(CORRUPTED_OUTFIT_SHADER)
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

local function onGameStart()
  -- Delay a little so visible creatures are fully initialized.
  scheduleEvent(refreshVisibleCorruptedCreatures, 200)
end

connect(Creature, {
  onAppear = onCreatureAppear,
  onOutfitChange = onCreatureOutfitChange,
})

connect(g_game, {
  onGameStart = onGameStart,
})
