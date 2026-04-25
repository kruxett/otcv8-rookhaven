local OPCODE = FuriousRageVisualOpcode or 94
local SHADER = "outfit_blood_rage_pulse"
local DEFAULT_DURATION_MS = 20000

local activeTimers = {}
local activeState = {}

local function clearTimer(creatureId)
  local eventId = activeTimers[creatureId]
  if eventId then
    removeEvent(eventId)
    activeTimers[creatureId] = nil
  end
end

local function setCreatureShader(creature, shader)
  if not creature then
    return false
  end

  local applied = false

  if creature.setOutfitShader then
    local ok = pcall(function()
      creature:setOutfitShader(shader)
    end)
    applied = applied or ok
  end

  if creature.setShader then
    local ok = pcall(function()
      creature:setShader(shader)
    end)
    applied = applied or ok
  end

  -- Some builds keep the old shader until outfit is reapplied.
  local outfit = creature:getOutfit()
  if outfit then
    outfit.shader = shader or ""
    local ok = pcall(function()
      creature:setOutfit(outfit)
    end)
    applied = applied or ok
  end

  return applied
end

local function removeVisual(creatureId)
  clearTimer(creatureId)

  local state = activeState[creatureId]
  activeState[creatureId] = nil
  if not state then
    return
  end

  -- Try to remove from creature if it's loaded on map
  local creature = g_map.getCreatureById(creatureId)
  if creature then
    setCreatureShader(creature, state.previousShader or "")
  end
end

local function applyVisual(creatureId, durationMs)
  local creature = g_map.getCreatureById(creatureId)
  
  -- Store state even if creature is not on map (for when it enters view later)
  local previousShader = ""
  local existing = activeState[creatureId]
  if existing and existing.previousShader then
    previousShader = existing.previousShader
  elseif creature then
    local outfit = creature:getOutfit()
    previousShader = outfit and outfit.shader or ""
    if previousShader == SHADER then
      previousShader = ""
    end
  end

  activeState[creatureId] = {
    previousShader = previousShader,
    shaderActive = true,
    appliedAt = os.time()
  }

  -- Apply shader to creature if loaded
  if creature then
    setCreatureShader(creature, SHADER)
  end

  -- Set up removal timer
  clearTimer(creatureId)
  local ttl = tonumber(durationMs) or DEFAULT_DURATION_MS
  if ttl > 0 then
    activeTimers[creatureId] = scheduleEvent(function()
      removeVisual(creatureId)
    end, ttl)
  end
end

-- Reapply while active when a creature appears on screen.
local function onCreatureAppear(creature)
  if not creature then return end
  local creatureId = creature:getId()
  local state = activeState[creatureId]

  if state and state.shaderActive then
    setCreatureShader(creature, SHADER)
  end
end

local function onExtendedOpcode(protocol, opcode, buffer)
  if opcode ~= OPCODE or not buffer or buffer == "" then
    return
  end

  local ok, data = pcall(function()
    return json.decode(buffer)
  end)
  if not ok or type(data) ~= "table" then
    return
  end

  local creatureId = tonumber(data.creatureId)
  if not creatureId then
    return
  end

  if data.action == "apply" then
    applyVisual(creatureId, tonumber(data.duration) or DEFAULT_DURATION_MS)
  elseif data.action == "remove" then
    removeVisual(creatureId)
  end
end

function init()
  ProtocolGame.registerExtendedOpcode(OPCODE, onExtendedOpcode)
  connect(Creature, {
    onAppear = onCreatureAppear,
  })
end

function terminate()
  if ProtocolGame then
    pcall(function()
      ProtocolGame.unregisterExtendedOpcode(OPCODE)
    end)
  end

  pcall(function()
    disconnect(Creature, {
      onAppear = onCreatureAppear,
    })
  end)

  for creatureId, _ in pairs(activeTimers) do
    clearTimer(creatureId)
  end
  activeState = {}
end

-- Initialize on load
init()

connect(g_game, {
  onGameEnd = terminate,
})
