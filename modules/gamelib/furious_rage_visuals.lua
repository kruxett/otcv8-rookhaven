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
  activeState[creatureId] = nil
  if not state then
    return
  end

  local creature = g_map.getCreatureById(creatureId)
  if not creature then
    return
  end

  local outfit = creature:getOutfit()
  local currentShader = outfit and outfit.shader or ""
  if currentShader ~= SHADER then
    return
  end

  setCreatureShader(creature, state.previousShader or "")
end

local function applyVisual(creatureId, durationMs)
  local creature = g_map.getCreatureById(creatureId)
  if not creature then
    return
  end

  local previousShader = ""
  local existing = activeState[creatureId]
  if existing and existing.previousShader then
    previousShader = existing.previousShader
  else
    local outfit = creature:getOutfit()
    previousShader = outfit and outfit.shader or ""
    if previousShader == SHADER then
      previousShader = ""
    end
  end

  activeState[creatureId] = {
    previousShader = previousShader
  }

  setCreatureShader(creature, SHADER)

  clearTimer(creatureId)
  local ttl = tonumber(durationMs) or DEFAULT_DURATION_MS
  if ttl > 0 then
    activeTimers[creatureId] = scheduleEvent(function()
      removeVisual(creatureId)
    end, ttl)
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
end

function terminate()
  if ProtocolGame then
    pcall(function()
      ProtocolGame.unregisterExtendedOpcode(OPCODE)
    end)
  end

  for creatureId, _ in pairs(activeTimers) do
    clearTimer(creatureId)
  end
  activeState = {}
end
