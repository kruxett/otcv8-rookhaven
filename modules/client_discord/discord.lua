local updateEvent = nil
local initialized = false
local rpcEnabled = false

local function getSetting(name, fallback)
  local value = g_settings.getString(name)
  if value == nil or value == '' then
    return fallback
  end
  return value
end

local function buildPresence()
  if not g_game.isOnline() then
    return {
      state = 'In menus',
      details = 'Idle',
    }
  end

  local charName = g_game.getCharacterName() or ''
  local worldName = g_game.getWorldName() or ''

  local details = charName
  if details == '' then
    details = 'Adventuring'
  end

  local state = worldName
  if state == '' then
    state = 'In game'
  else
    state = 'World: ' .. state
  end

  return {
    state = state,
    details = details,
  }
end

local function updatePresence()
  if not rpcEnabled or not g_discord.isInitialized() then
    return
  end

  local largeImageKey = getSetting('discordRpcLargeImageKey', '')
  local largeImageText = getSetting('discordRpcLargeImageText', 'Rookhaven')
  local smallImageKey = getSetting('discordRpcSmallImageKey', '')
  local smallImageText = getSetting('discordRpcSmallImageText', '')

  local presence = buildPresence()
  g_discord.setPresence(presence.state, presence.details, largeImageKey, largeImageText, smallImageKey, smallImageText)
end

local function tick()
  if not rpcEnabled then
    return
  end

  g_discord.runCallbacks()
  updatePresence()
  updateEvent = scheduleEvent(tick, 15000)
end

local function onGameStart()
  updatePresence()
end

local function onGameEnd()
  if rpcEnabled and g_discord.isInitialized() then
    g_discord.clearPresence()
  end
end

function init()
  if initialized then
    return
  end

  if g_app.getOs() ~= 'windows' then
    initialized = true
    return
  end

  local appId = getSetting('discordRpcAppId', '')
  if appId == '' then
    g_logger.info('Discord RPC disabled: set setting discordRpcAppId to enable Rich Presence')
    initialized = true
    return
  end

  rpcEnabled = g_discord.initialize(appId)
  if not rpcEnabled then
    g_logger.warning('Discord RPC unavailable: ' .. (g_discord.getLastError() or 'unknown error'))
    initialized = true
    return
  end

  connect(g_game, {
    onGameStart = onGameStart,
    onGameEnd = onGameEnd,
  })

  updatePresence()
  updateEvent = scheduleEvent(tick, 1000)
  initialized = true
end

function terminate()
  if updateEvent then
    removeEvent(updateEvent)
    updateEvent = nil
  end

  if rpcEnabled then
    disconnect(g_game, {
      onGameStart = onGameStart,
      onGameEnd = onGameEnd,
    })

    if g_discord.isInitialized() then
      g_discord.clearPresence()
      g_discord.shutdown()
    end
  end

  rpcEnabled = false
  initialized = false
end
