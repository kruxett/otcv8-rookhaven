local BOAT_FARE_OPCODE = 92

local boatFareWindow = nil

function init()
  connect(g_game, {
    onGameEnd = onGameEnd
  })
  ProtocolGame.registerExtendedOpcode(BOAT_FARE_OPCODE, onBoatFareOpcode)
end

function terminate()
  disconnect(g_game, {
    onGameEnd = onGameEnd
  })
  ProtocolGame.unregisterExtendedOpcode(BOAT_FARE_OPCODE)
  destroyWindow()
end

function onGameEnd()
  destroyWindow()
end

function destroyWindow()
  if boatFareWindow then
    boatFareWindow:destroy()
    boatFareWindow = nil
  end
end

local function onBoatFareOpcode(protocol, opcode, buffer)
  -- Only one window at a time
  if boatFareWindow then
    return
  end

  local data = json.decode(buffer)
  if not data then
    return
  end

  boatFareWindow = g_ui.displayUI('boatfare', rootWidget)

  local destinationLabel = boatFareWindow:getChildById('destinationLabel')
  local priceLabel = boatFareWindow:getChildById('priceLabel')

  if destinationLabel then
    destinationLabel:setText('Destination: ' .. (data.destination or 'Unknown'))
  end

  if priceLabel then
    priceLabel:setText('Cost: ' .. (data.price or 0) .. ' gold')
  end

  boatFareWindow:grabMouse()
end

function accept()
  if boatFareWindow then
    boatFareWindow:ungrabMouse()
    destroyWindow()
    local protocol = g_game.getProtocolGame()
    if protocol then
      protocol:sendExtendedOpcode(BOAT_FARE_OPCODE, json.encode({ response = 'accept' }))
    end
  end
end

function decline()
  if boatFareWindow then
    boatFareWindow:ungrabMouse()
    destroyWindow()
    local protocol = g_game.getProtocolGame()
    if protocol then
      protocol:sendExtendedOpcode(BOAT_FARE_OPCODE, json.encode({ response = 'decline' }))
    end
  end
end
