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

  if creature.setOutfitShader then
    local ok = pcall(function()
      creature:setOutfitShader(shader)
    end)
    if ok then
      return true
    end
  end

  if creature.setShader then
    local ok = pcall(function()
      creature:setShader(shader)
    end)
    if ok then
      return true
    end
  end

  return false
end

local function removeVisual(creatureId)
  clearTimer(creatureId)

  local state = activeState[creatureId]
  if not state then
    return
  end

  -- Try to remove from creature if it's loaded on map
  local creature = g_map.getCreatureById(creatureId)
  if creature then
    local outfit = creature:getOutfit()
    local currentShader = outfit and outfit.shader or ""
    if currentShader == SHADER then
      setCreatureShader(creature, state.previousShader or "")
    end
  end
  
  -- Clear state regardless of whether creature is on map
  activeState[creatureId] = nil
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

-- Hook for when creatures enter the map view
local function onCreatureLoad(creature)
  if not creature then return end
  local creatureId = creature:getId()
  local state = activeState[creatureId]
  
  -- If we have an active visual state for this creature, apply it now
  if state and state.shaderActive then
    setCreatureShader(creature, SHADER)
  end
end

-- Hook for when creatures leave the map view (optional cleanup)
local function onCreatureUnload(creature)
  -- No need to do anything - state is preserved for when they return
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
  
  -- Connect creature load/unload hooks
  if g_game then
    connect(g_game, "onCreatureLoad", onCreatureLoad)
    connect(g_game, "onCreatureUnload", onCreatureUnload)
  end
end

function terminate()
  if ProtocolGame then
    pcall(function()
      ProtocolGame.unregisterExtendedOpcode(OPCODE)
    end)
  end

  if g_game then
    pcall(function()
      disconnect(g_game, "onCreatureLoad", onCreatureLoad)
      disconnect(g_game, "onCreatureUnload", onCreatureUnload)
    end)
  end

  for creatureId, _ in pairs(activeTimers) do
    clearTimer(creatureId)
  end
  activeState = {}
end

-- Initialize on load
init()

connect(g_game, "onGameEnd", terminate)
