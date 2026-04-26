ui = nil
updateEvent = nil

function init()
  ui = g_ui.loadUI('stats', modules.game_interface.getMapPanel())
  
  if not modules.client_options.getOption("showFps") then
    ui.fps:hide()
  end

  if ui.ping and not modules.client_options.getOption("showPing") then
    ui.ping:hide()
  end
  
  updateEvent = scheduleEvent(update, 200)
end

function terminate()
  removeEvent(updateEvent)
end

function update()
  updateEvent = scheduleEvent(update, 500)
  if ui:isHidden() then return end

  text = 'FPS: ' .. g_app.getFps()
  ui.fps:setText(text)

  if ui.ping then
    local pingText = 'PING: --'
    local pingColor = '#ffffff'
    if g_game.isOnline() then
      local ping = tonumber(g_game.getPing()) or -1
      if ping >= 0 then
        pingText = string.format('PING: %d ms', ping)
        if ping >= 300 then
          pingColor = '#d97a7a'
        elseif ping >= 150 then
          pingColor = '#e0b070'
        else
          pingColor = '#7ac97a'
        end
      else
        pingText = 'PING: ...'
        pingColor = '#e0b070'
      end
    end
    ui.ping:setText(pingText)
    ui.ping:setColor(pingColor)
  end
end

function show()
  ui:setVisible(true)
end

function hide()
  ui:setVisible(false)
end