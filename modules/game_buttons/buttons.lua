buttonsWindow = nil
contentsPanel = nil

function init()
  buttonsWindow = g_ui.loadUI('buttons', modules.game_interface.getRightPanel())
  buttonsWindow:disableResize()
  buttonsWindow:setup()
  contentsPanel = buttonsWindow.contentsPanel
  if not buttonsWindow.forceOpen or not contentsPanel.buttons then
    buttonsWindow:close()
  end
end

function terminate()
  buttonsWindow:destroy()
end

function takeButtons(buttons)
  if not buttonsWindow.forceOpen or not contentsPanel.buttons then return end
  for i, button in ipairs(buttons) do
    takeButton(button, true)
  end
  updateOrder()
end

function takeButton(button, dontUpdateOrder)
  if not buttonsWindow.forceOpen or not contentsPanel.buttons then return end
  button:setParent(contentsPanel.buttons)
  if not dontUpdateOrder then
    updateOrder()
  end
end

function updateOrder()
  local children = contentsPanel.buttons:getChildren()
  table.sort(children, function(a, b)
    return (a.index or 1000) < (b.index or 1000)
  end)
  contentsPanel.buttons:reorderChildren(children)

  local visibleCount = 0
  for _, child in ipairs(children) do
    if child:isVisible() then
      visibleCount = visibleCount + 1
    end
  end

  -- Retro layout: 8 buttons per row (cell-size: 20, spacing: 3)
  -- 1-row height = 32px (matches original behaviour); each extra row adds 23px (20 cell + 3 spacing)
  local buttonsPerRow = 8
  local rows = math.max(1, math.ceil(visibleCount / buttonsPerRow))
  local targetHeight = 32 + (rows - 1) * 23

  if buttonsWindow:getHeight() ~= targetHeight then
    buttonsWindow:setHeight(targetHeight)
  end
end