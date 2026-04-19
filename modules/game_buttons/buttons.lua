buttonsWindow = nil
contentsPanel = nil
baseButtonsWindowHeight = nil

function init()
  buttonsWindow = g_ui.loadUI('buttons', modules.game_interface.getRightPanel())
  buttonsWindow:disableResize()
  buttonsWindow:setup()
  contentsPanel = buttonsWindow.contentsPanel
  baseButtonsWindowHeight = buttonsWindow:getHeight()
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

  if not baseButtonsWindowHeight then
    baseButtonsWindowHeight = buttonsWindow:getHeight()
  end

  -- Grid is effectively 6 buttons per row in the current right panel width.
  local buttonsPerRow = 6
  local rows = math.max(1, math.ceil(visibleCount / buttonsPerRow))
  local targetHeight = baseButtonsWindowHeight + ((rows - 1) * 22)

  if buttonsWindow:getHeight() ~= targetHeight then
    buttonsWindow:setHeight(targetHeight)

    -- Force right panel relayout so miniwindows below (e.g. Battle) move down.
    local parent = buttonsWindow:getParent()
    local layout = parent and parent:getLayout()
    if layout then
      layout:update()
    end
  end
end