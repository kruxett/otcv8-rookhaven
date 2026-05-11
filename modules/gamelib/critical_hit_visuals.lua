local OPCODE = CriticalHitVisualOpcode or 99
local DEFAULT_SHADER = "outfit_critical_overdrive"
local DEFAULT_DURATION_MS = 700
local FLASH_INTERVAL_MS = 90
local FLASH_TOGGLES = 6

local activeState = {}
local flashTimers = {}
local removeTimers = {}
local initialized = false

local function clearTimer(timerTable, creatureId)
  local eventId = timerTable[creatureId]
  if eventId then
    removeEvent(eventId)
    timerTable[creatureId] = nil
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

local function applyCurrentShaderState(creatureId)
  local state = activeState[creatureId]
  if not state then
    return
  end

  local creature = g_map.getCreatureById(creatureId)
  if not creature then
    return
  end

  if state.visible then
    setCreatureShader(creature, state.shader or DEFAULT_SHADER)
  else
    setCreatureShader(creature, state.previousShader or "")
  end
end

local function removeVisual(creatureId)
  clearTimer(flashTimers, creatureId)
  clearTimer(removeTimers, creatureId)

  local state = activeState[creatureId]
  activeState[creatureId] = nil
  if not state then
    return
  end

  local creature = g_map.getCreatureById(creatureId)
  if creature then
    setCreatureShader(creature, state.previousShader or "")
  end
end

local function scheduleFlashToggle(creatureId)
  local state = activeState[creatureId]
  if not state then
    return
  end

  if state.togglesLeft <= 0 then
    state.visible = true
    applyCurrentShaderState(creatureId)
    return
  end

  clearTimer(flashTimers, creatureId)
  flashTimers[creatureId] = scheduleEvent(function()
    local current = activeState[creatureId]
    flashTimers[creatureId] = nil
    if not current then
      return
    end

    current.visible = not current.visible
    current.togglesLeft = current.togglesLeft - 1
    applyCurrentShaderState(creatureId)
    scheduleFlashToggle(creatureId)
  end, FLASH_INTERVAL_MS)
end

local function applyVisual(creatureId, durationMs, shader)
  local creature = g_map.getCreatureById(creatureId)
  local existing = activeState[creatureId]

  local previousShader = ""
  if existing and existing.previousShader then
    previousShader = existing.previousShader
  elseif creature then
    local outfit = creature:getOutfit()
    previousShader = outfit and outfit.shader or ""
    if previousShader == shader then
      previousShader = ""
    end
  end

  activeState[creatureId] = {
    previousShader = previousShader,
    shader = shader,
    visible = true,
    togglesLeft = FLASH_TOGGLES,
  }

  applyCurrentShaderState(creatureId)
  scheduleFlashToggle(creatureId)

  clearTimer(removeTimers, creatureId)
  local ttl = math.max(1, tonumber(durationMs) or DEFAULT_DURATION_MS)
  removeTimers[creatureId] = scheduleEvent(function()
    removeVisual(creatureId)
  end, ttl)
end

local function onCreatureAppear(creature)
  if not creature then
    return
  end

  local creatureId = creature:getId()
  if activeState[creatureId] then
    applyCurrentShaderState(creatureId)
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

  if data.action == "remove" then
    removeVisual(creatureId)
    return
  end

  local shader = type(data.shader) == "string" and data.shader or DEFAULT_SHADER
  local ttl = tonumber(data.duration) or DEFAULT_DURATION_MS
  applyVisual(creatureId, ttl, shader)
end

local function clearAll()
  for creatureId, _ in pairs(activeState) do
    removeVisual(creatureId)
  end

  activeState = {}
  flashTimers = {}
  removeTimers = {}
end

local function onGameEnd()
  clearAll()
end

function init()
  if initialized then
    return
  end

  ProtocolGame.registerExtendedOpcode(OPCODE, onExtendedOpcode)
  connect(Creature, {
    onAppear = onCreatureAppear,
  })

  connect(g_game, {
    onGameEnd = onGameEnd,
  })

  initialized = true
end

function terminate()
  if initialized then
    pcall(function()
      ProtocolGame.unregisterExtendedOpcode(OPCODE)
    end)

    pcall(function()
      disconnect(Creature, {
        onAppear = onCreatureAppear,
      })
    end)

    pcall(function()
      disconnect(g_game, {
        onGameEnd = onGameEnd,
      })
    end)
  end

  clearAll()
  initialized = false
end

init()
