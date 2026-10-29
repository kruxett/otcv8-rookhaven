local OPCODE = 106
local window, token, selected, busy

local function child(id) return window:recursiveGetChildById(id) end
local function destroy()
  if window then window:ungrabKeyboard(); window:destroy() end
  window, token, selected, busy = nil, nil, nil, false
end
local function send(message)
  local protocol = g_game.getProtocolGame()
  if not protocol then return false end
  protocol:sendExtendedOpcode(OPCODE, json.encode(message))
  return true
end
local function updateButtons()
  child('wand'):setEnabled(not busy)
  child('rod'):setEnabled(not busy)
  child('confirm'):setEnabled(selected ~= nil and not busy)
  for _, key in ipairs({'wand','rod'}) do
    child(key):setBorderColor(selected == key and '#c8a456' or '#555555')
  end
end
function selectChoice(key)
  if not window or busy or (key ~= 'wand' and key ~= 'rod') then return end
  selected = key
  child('status'):setText('')
  updateButtons()
end
function confirm()
  if not window or not selected or busy then return end
  busy = true
  updateButtons()
  child('status'):setText(tr('Claiming your reward...'))
  if not send({action='choose',token=token,choice=selected}) then destroy() end
end
function cancel()
  if token and g_game.isOnline() then send({action='cancel',token=token}) end
  destroy()
end
local function onOpcode(protocol, opcode, buffer)
  if type(buffer) ~= 'string' or #buffer > 8192 then return end
  local ok, data = pcall(json.decode, buffer)
  if not ok or type(data) ~= 'table' or type(data.token) ~= 'string' or #data.token > 128 then return end
  if data.action == 'offer' then
    if type(data.choices) ~= 'table' or #data.choices ~= 2 or type(data.message) ~= 'string' or #data.message > 512 then return end
    local offered = {}
    for _, choice in ipairs(data.choices) do
      if type(choice) ~= 'table' or (choice.key ~= 'wand' and choice.key ~= 'rod') or offered[choice.key]
          or type(choice.name) ~= 'string' or #choice.name > 64 or type(choice.clientId) ~= 'number'
          or choice.clientId < 1 or choice.clientId > 65535 or choice.clientId % 1 ~= 0
          or type(choice.role) ~= 'string' or #choice.role > 64
          or type(choice.element) ~= 'string' or #choice.element > 32
          or type(choice.summary) ~= 'string' or #choice.summary > 160
          or type(choice.bonuses) ~= 'string' or #choice.bonuses > 160 then return end
      offered[choice.key] = choice
    end
    if not offered.wand or not offered.rod then return end
    destroy()
    window = g_ui.displayUI('questreward', rootWidget)
    if not window then return end
    token, busy = data.token, false
    child('description'):setText(data.message)
    for _, key in ipairs({'wand','rod'}) do
      local row, choice = child(key), offered[key]
      row:getChildById('icon'):setItemId(choice.clientId)
      row:getChildById('title'):setText(choice.name)
      row:getChildById('role'):setText(choice.role .. ' | ' .. choice.element .. ' | ' .. tr('Level') .. ' ' .. tostring(choice.level or 13))
      row:getChildById('summary'):setText(choice.summary)
      row:getChildById('bonuses'):setText(choice.bonuses)
      row.onClick = function() selectChoice(key) end
    end
    child('confirm').onClick = confirm
    child('cancel').onClick = cancel
    window.onEscape = cancel
    window.onEnter = confirm
    window:grabKeyboard()
    updateButtons()
  elseif window and data.token == token then
    if data.action == 'close' or (data.action == 'result' and (data.success or data.closed)) then
      destroy()
      if data.message and not data.success then displayInfoBox(tr('Quest Reward'), data.message) end
    elseif data.action == 'result' then
      busy = false
      child('status'):setText(type(data.message) == 'string' and data.message or tr('Please try again.'))
      updateButtons()
    end
  end
end
function init()
  ProtocolGame.registerExtendedOpcode(OPCODE, onOpcode)
  connect(g_game, {onGameEnd=destroy})
end
function terminate()
  cancel()
  ProtocolGame.unregisterExtendedOpcode(OPCODE)
  disconnect(g_game, {onGameEnd=destroy})
end
