-- private variables
local topMenu
local fpsUpdateEvent = nil
local statusUpdateEvent = nil

-- private functions
local function addButton(id, description, icon, callback, panel, toggle, front, index)
  local class
  if toggle then
    class = 'TopToggleButton'
  else
    class = 'TopButton'
  end
  
  if topMenu.reverseButtons then
    front = not front
  end

  local button = panel:getChildById(id)
  if not button then
    button = g_ui.createWidget(class)
    if front then
      panel:insertChild(1, button)
    else
      panel:addChild(button)
    end
  end
  button:setId(id)
  button:setTooltip(description)
  button:setIcon(resolvepath(icon, 3))
  button.onMouseRelease = function(widget, mousePos, mouseButton)
    if widget:containsPoint(mousePos) and mouseButton ~= MouseMidButton and mouseButton ~= MouseTouch then
      callback()
      return true
    end
  end
  button.onTouchRelease = button.onMouseRelease
  if not button.index and type(index) == 'number' then
    button.index = index
  end
  return button
end

-- public functions
function init()
  connect(g_game, { onGameStart = online,
                    onGameEnd = offline })

  topMenu = g_ui.createWidget('TopMenu', g_ui.getRootWidget())
  if not topMenu then
    -- UI style/layout might not be loaded yet; retry shortly.
    scheduleEvent(init, 50)
    return
  end
  g_keyboard.bindKeyDown('Ctrl+Shift+T', toggle)
  
  if g_game.isOnline() then
    scheduleEvent(online, 10)
  end
  
  updateFps()  
  updateStatus()
end

function terminate()
  disconnect(g_game, { onGameStart = online,
                       onGameEnd = offline })
  removeEvent(fpsUpdateEvent)
  removeEvent(statusUpdateEvent)
  
  g_keyboard.unbindKeyDown('Ctrl+Shift+T')
  topMenu:destroy()
end

function online()
  if topMenu.hideIngame then
    hide()
  else
    modules.game_interface.getRootPanel():addAnchor(AnchorTop, 'topMenu', AnchorBottom)
  end
  if topMenu.onlineLabel then
    topMenu.onlineLabel:hide()
  end
  
  showGameButtons()
end

function offline()
  if topMenu.hideIngame then
    show()
  end
  if topMenu.onlineLabel then
    topMenu.onlineLabel:show()
  end

  hideGameButtons()
  updateStatus()
end

function updateFps()
  if not topMenu.fpsLabel then return end
  fpsUpdateEvent = scheduleEvent(updateFps, 500)
  text = 'FPS: ' .. g_app.getFps()
  topMenu.fpsLabel:setText(text)
end

function setFpsVisible(enable)
  if not topMenu.fpsLabel then return end
  topMenu.fpsLabel:setVisible(enable)
end

function addLeftButton(id, description, icon, callback, front, index)
  return addButton(id, description, icon, callback, topMenu.leftButtonsPanel, false, front, index)
end

function addLeftToggleButton(id, description, icon, callback, front, index)
  return addButton(id, description, icon, callback, topMenu.leftButtonsPanel, true, front, index)
end

function addRightButton(id, description, icon, callback, front, index)
  return addButton(id, description, icon, callback, topMenu.rightButtonsPanel, false, front, index)
end

function addRightToggleButton(id, description, icon, callback, front, index)
  return addButton(id, description, icon, callback, topMenu.rightButtonsPanel, true, front, index)
end

function addLeftGameButton(id, description, icon, callback, front, index)
  local button = addButton(id, description, icon, callback, topMenu.leftGameButtonsPanel, false, front, index)
  if modules.game_buttons then
    modules.game_buttons.takeButton(button)
  end
  return button
end

function addLeftGameToggleButton(id, description, icon, callback, front, index)
  local button = addButton(id, description, icon, callback, topMenu.leftGameButtonsPanel, true, front, index)
  if modules.game_buttons then
    modules.game_buttons.takeButton(button)
  end
  return button
end

function addRightGameButton(id, description, icon, callback, front, index)
  local button = addButton(id, description, icon, callback, topMenu.rightGameButtonsPanel, false, front, index)
  if modules.game_buttons then
    modules.game_buttons.takeButton(button)
  end
  return button
end

function addRightGameToggleButton(id, description, icon, callback, front, index)
  local button = addButton(id, description, icon, callback, topMenu.rightGameButtonsPanel, true, front, index)
  if modules.game_buttons then
    modules.game_buttons.takeButton(button)
  end
  return button
end

function showGameButtons()
  topMenu.leftGameButtonsPanel:show()
  topMenu.rightGameButtonsPanel:show()
  if modules.game_buttons then
    modules.game_buttons.takeButtons(topMenu.leftGameButtonsPanel:getChildren())
    modules.game_buttons.takeButtons(topMenu.rightGameButtonsPanel:getChildren())
  end
end

function hideGameButtons()
  topMenu.leftGameButtonsPanel:hide()
  topMenu.rightGameButtonsPanel:hide()
end

function getButton(id)
  return topMenu:recursiveGetChildById(id)
end

function getTopMenu()
  return topMenu
end

function toggle()
  if not topMenu then
    return
  end
  
  if topMenu:isVisible() then
    hide()
  else
    show()
  end
end

function hide()
  topMenu:hide()
  if not topMenu.hideIngame then
    modules.game_interface.getRootPanel():addAnchor(AnchorTop, 'parent', AnchorTop)
  end
  if modules.game_stats then
    modules.game_stats.show()
  end
end

function show()
  topMenu:show()
  if not topMenu.hideIngame then
    modules.game_interface.getRootPanel():addAnchor(AnchorTop, 'topMenu', AnchorBottom)
  end
  if modules.game_stats then
    modules.game_stats.hide()
  end
end

function updateStatus()
  removeEvent(statusUpdateEvent)
  if not Services or not Services.status or Services.status:len() < 4 then return end
  if not topMenu.onlineLabel then return end
  if g_game.isOnline() then return end
  HTTP.postJSON(Services.status, {type="cacheinfo"}, function(data, err)
    if err then
      g_logger.warning("HTTP error for " .. Services.status .. ": " .. err) 
      statusUpdateEvent = scheduleEvent(updateStatus, 5000)
      return
    end
    if topMenu.onlineLabel then
      if data.online then
        topMenu.onlineLabel:setText(data.online)
      elseif data.playersonline then
        topMenu.onlineLabel:setText(data.playersonline .. " players online")
      end
    end
    if data.discord_online and topMenu.discordLabel then
      topMenu.discordLabel:setText(data.discord_online)
    end
    if data.discord_link and topMenu.discordLabel and topMenu.discord then
      local discordOnClick = function()
        g_platform.openUrl(data.discord_link)
      end
      topMenu.discordLabel.onClick = discordOnClick
      topMenu.discord.onClick = discordOnClick
    end
    statusUpdateEvent = scheduleEvent(updateStatus, 60000)
  end)
end