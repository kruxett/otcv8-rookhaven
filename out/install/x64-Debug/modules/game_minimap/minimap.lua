minimapWidget = nil
minimapButton = nil
minimapWindow = nil
minimapOriginalParent = nil
fullmapView = false
loaded = false
oldZoom = nil
oldPos = nil

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
  loadMap()
  updateCameraPosition()
end

function offline()
  saveMap()
end

function loadMap()
  local clientVersion = g_game.getClientVersion()

  g_minimap.clean()
  loaded = false

  local minimapFile = '/minimap.otmm'
  local dataMinimapFile = '/data' .. minimapFile
  local versionedMinimapFile = '/minimap' .. clientVersion .. '.otmm'
  if g_resources.fileExists(dataMinimapFile) then
    loaded = g_minimap.loadOtmm(dataMinimapFile)
  end
  if not loaded and g_resources.fileExists(versionedMinimapFile) then
    loaded = g_minimap.loadOtmm(versionedMinimapFile)
  end
  if not loaded and g_resources.fileExists(minimapFile) then
    loaded = g_minimap.loadOtmm(minimapFile)
  end
  if not loaded then
    print("Minimap couldn't be loaded, file missing?")
  end
  minimapWidget:load()
end

function saveMap()
  local clientVersion = g_game.getClientVersion()
  local minimapFile = '/minimap' .. clientVersion .. '.otmm' 
  g_minimap.saveOtmm(minimapFile)
  minimapWidget:save()
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
