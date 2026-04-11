minimapWidget = nil
minimapButton = nil
minimapWindow = nil
minimapOriginalParent = nil
fullmapView = false
loaded = false
oldZoom = nil
oldPos = nil
minimapSessionFile = nil
minimapSessionLockFile = nil
minimapSessionVersion = nil
sharedMapSaveEnabled = true

local ensureSessionFiles
local releaseSessionLock

local function copyFileCompat(sourceFile, targetFile)
  local sourceData = g_resources.readFileContents(sourceFile)
  if not sourceData or sourceData == '' then
    return false
  end

  return g_resources.writeFileContents(targetFile, sourceData)
end

local function getVersionedMinimapFile(clientVersion)
  return '/minimap' .. clientVersion .. '.otmm'
end

local function getSessionPid()
  local pid = 0
  if g_platform and g_platform.getProcessId then
    pid = tonumber(g_platform.getProcessId()) or 0
  end

  if pid <= 0 then
    pid = os.time()
  end

  return tostring(pid)
end

local function getSessionMinimapFile(clientVersion)
  return '/minimap' .. clientVersion .. '.pid' .. getSessionPid() .. '.otmm'
end

local function getSessionLockFile(clientVersion)
  return '/minimap' .. clientVersion .. '.pid' .. getSessionPid() .. '.lock'
end

local function getPidFromLockFile(fileName, clientVersion)
  local pattern = '^minimap' .. tostring(clientVersion) .. '%.pid(%d+)%.lock$'
  local pid = string.match(fileName, pattern)
  return tonumber(pid)
end

local function refreshSharedSavePolicy(clientVersion)
  local files = g_resources.listDirectoryFiles('/') or {}
  local activeLocks = 0

  for _, fileName in ipairs(files) do
    local pid = getPidFromLockFile(fileName, clientVersion)
    if pid then
      if g_platform and g_platform.isProcessRunning and g_platform.isProcessRunning(pid) then
        activeLocks = activeLocks + 1
      else
        g_resources.deleteFile('/' .. fileName)
      end
    end
  end

  sharedMapSaveEnabled = activeLocks <= 1
  return activeLocks
end

ensureSessionFiles = function(clientVersion)
  if minimapSessionVersion and minimapSessionVersion ~= clientVersion then
    releaseSessionLock(minimapSessionVersion)
    minimapSessionFile = nil
  end

  minimapSessionVersion = clientVersion

  if not minimapSessionFile then
    minimapSessionFile = getSessionMinimapFile(clientVersion)
  end

  if not minimapSessionLockFile then
    minimapSessionLockFile = getSessionLockFile(clientVersion)
    g_resources.writeFileContents(minimapSessionLockFile, tostring(os.time()))
  end

  local activeLocks = refreshSharedSavePolicy(clientVersion)
  if activeLocks > 1 then
    print('[Minimap] Multiclient detected (' .. activeLocks .. ' instances). Shared minimap file writes are temporarily disabled.')
  end
end

releaseSessionLock = function(clientVersion)
  if minimapSessionLockFile and g_resources.fileExists(minimapSessionLockFile) then
    g_resources.deleteFile(minimapSessionLockFile)
  end

  minimapSessionLockFile = nil
  minimapSessionVersion = nil
  refreshSharedSavePolicy(clientVersion)
end

local function createBackupIfExists(filePath)
  if not g_resources.fileExists(filePath) then
    return
  end

  local backupFile = filePath .. '.bak'
  if copyFileCompat(filePath, backupFile) then
    print('[Minimap] Created backup at ' .. backupFile)
  else
    print('[Minimap] Warning: failed to create backup at ' .. backupFile)
  end
end

local function tryLoadMapFile(filePath)
  if not g_resources.fileExists(filePath) then
    return false
  end

  return g_minimap.loadOtmm(filePath)
end

function init()
  minimapWindow = g_ui.loadUI('minimap', modules.game_interface.getRightPanel())
  minimapWindow:setContentMinimumHeight(64)

  if not minimapWindow.forceOpen then
    minimapButton = modules.client_topmenu.addRightGameToggleButton('minimapButton', 
      tr('Minimap') .. ' (Ctrl+M)', '/images/topbuttons/minimap', toggle)
    minimapButton:setOn(true)
  end

  minimapWidget = minimapWindow:recursiveGetChildById('minimap')
  minimapOriginalParent = minimapWidget and minimapWidget:getParent() or nil

  local gameRootPanel = modules.game_interface.getRootPanel()
  g_keyboard.bindKeyPress('Alt+Left', function() minimapWidget:move(1,0) end, gameRootPanel)
  g_keyboard.bindKeyPress('Alt+Right', function() minimapWidget:move(-1,0) end, gameRootPanel)
  g_keyboard.bindKeyPress('Alt+Up', function() minimapWidget:move(0,1) end, gameRootPanel)
  g_keyboard.bindKeyPress('Alt+Down', function() minimapWidget:move(0,-1) end, gameRootPanel)
  g_keyboard.bindKeyDown('Ctrl+M', toggle, gameRootPanel)
  g_keyboard.bindKeyDown('Ctrl+Shift+M', toggleFullMap, gameRootPanel)

  minimapWindow:setup()

  connect(g_game, {
    onGameStart = online,
    onGameEnd = offline,
  })

  connect(LocalPlayer, {
    onPositionChange = updateCameraPosition
  })

  if g_game.isOnline() then
    online()
  end
end

function terminate()
  if g_game.isOnline() then
    saveMap()
    releaseSessionLock(g_game.getClientVersion())
  end

  disconnect(g_game, {
    onGameStart = online,
    onGameEnd = offline,
  })

  disconnect(LocalPlayer, {
    onPositionChange = updateCameraPosition
  })

  local gameRootPanel = modules.game_interface.getRootPanel()
  g_keyboard.unbindKeyPress('Alt+Left', gameRootPanel)
  g_keyboard.unbindKeyPress('Alt+Right', gameRootPanel)
  g_keyboard.unbindKeyPress('Alt+Up', gameRootPanel)
  g_keyboard.unbindKeyPress('Alt+Down', gameRootPanel)
  g_keyboard.unbindKeyDown('Ctrl+M')
  g_keyboard.unbindKeyDown('Ctrl+Shift+M')

  minimapWindow:destroy()
  if minimapButton then
    minimapButton:destroy()
  end
end

function toggle()
  if not minimapButton then return end
  if minimapButton:isOn() then
    minimapWindow:close()
    minimapButton:setOn(false)
  else
    minimapWindow:open()
    minimapButton:setOn(true)
  end
end

function onMiniWindowClose()
  if minimapButton then
    minimapButton:setOn(false)
  end
end

function online()
  ensureSessionFiles(g_game.getClientVersion())
  loadMap()
  updateCameraPosition()
end

function offline()
  saveMap()
  releaseSessionLock(g_game.getClientVersion())
end

function loadMap()
  local clientVersion = g_game.getClientVersion()

  g_minimap.clean()
  loaded = false

  ensureSessionFiles(clientVersion)

  local minimapFile = '/minimap.otmm'
  local dataMinimapFile = '/data' .. minimapFile
  local versionedMinimapFile = getVersionedMinimapFile(clientVersion)
  local versionedBackupFile = versionedMinimapFile .. '.bak'
  local sessionFile = minimapSessionFile
  local sessionBackupFile = sessionFile .. '.bak'

  loaded = tryLoadMapFile(dataMinimapFile)
  if not loaded then loaded = tryLoadMapFile(sessionFile) end
  if not loaded then loaded = tryLoadMapFile(sessionBackupFile) end
  if not loaded then loaded = tryLoadMapFile(versionedMinimapFile) end
  if not loaded then loaded = tryLoadMapFile(versionedBackupFile) end
  if not loaded then loaded = tryLoadMapFile(minimapFile) end

  if not loaded then
    print('[Minimap] Minimap could not be loaded, file missing or corrupted')
  end
  minimapWidget:load()
end

function saveMap()
  local clientVersion = g_game.getClientVersion()
  ensureSessionFiles(clientVersion)

  local sessionFile = minimapSessionFile
  local sharedFile = getVersionedMinimapFile(clientVersion)

  createBackupIfExists(sessionFile)
  g_minimap.saveOtmm(sessionFile)

  if sharedMapSaveEnabled then
    createBackupIfExists(sharedFile)
    if copyFileCompat(sessionFile, sharedFile) then
      print('[Minimap] Shared map synchronized from session file')
    else
      print('[Minimap] Warning: failed to synchronize shared map file')
    end
  else
    print('[Minimap] Skipping shared map save while multiple clients are running')
  end

  minimapWidget:save()
  print('[Minimap] Map saved successfully to ' .. sessionFile)
end

function updateCameraPosition()
  local player = g_game.getLocalPlayer()
  if not player then return end
  local pos = player:getPosition()
  if not pos then return end
  if not minimapWidget:isDragging() then
    if not fullmapView then
      minimapWidget:setCameraPosition(player:getPosition())
    end
    minimapWidget:setCrossPosition(player:getPosition())
  end
end

function toggleFullMap()
  if not minimapWidget then return end
  local rootPanel = modules.game_interface.getRootPanel()
  if not rootPanel then return end

  if not fullmapView then
    fullmapView = true
    minimapWindow:hide()
    minimapWidget:setParent(rootPanel)
    minimapWidget:fill('parent')
    minimapWidget:raise()
    minimapWidget:setAlternativeWidgetsVisible(true)
  else
    fullmapView = false
    local restoreParent = minimapOriginalParent
    if not restoreParent or restoreParent:isDestroyed() then
      restoreParent = minimapWindow:getChildById('contentsPanel') or minimapWindow
    end
    minimapWidget:setParent(restoreParent)
    minimapWidget:fill('parent')
    minimapWindow:show()
    minimapWidget:raise()
    minimapWidget:setAlternativeWidgetsVisible(false)
  end

  local zoom = oldZoom or 0
  local pos = oldPos or minimapWidget:getCameraPosition()
  oldZoom = minimapWidget:getZoom()
  oldPos = minimapWidget:getCameraPosition()
  minimapWidget:setZoom(zoom)
  minimapWidget:setCameraPosition(pos)
end
