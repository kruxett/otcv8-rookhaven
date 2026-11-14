AccountServicesUI = {}
local window, state, protocol
local generation = 0

local function field(id) return window:getChildById(id) end
local function status(message, error)
  field('status'):setText(message)
  field('status'):setColor(error and '#e3a0a0' or '#c6b58c')
end
local function enabled(value)
  for _, id in ipairs(state.kind == 1 and {'account','email','password','confirm'} or {'name','sex'}) do
    field(id):setEnabled(value)
  end
  field('cancel'):setEnabled(value)
  field('submit'):setEnabled(value and state.policy ~= nil and state.allowed)
end
local function dispose()
  generation = generation + 1
  if protocol then protocol:cancel(); protocol = nil end
  if window then window:destroy(); window = nil end
  state = nil
end
local function request(action, values, callback)
  local current = generation
  protocol = ProtocolAccounts.create()
  protocol:request(state.endpoint, action, values, function(...)
    if current ~= generation or not window then return end
    protocol = nil
    callback(...)
  end)
end
local function open(kind)
  if window then return AccountServicesUI.raise() end
  local endpoint = EnterGame.getAccountEndpoint(kind == 2)
  if not endpoint or (kind == 2 and (not G.account or not G.password)) then
    displayErrorBox(tr('Creation unavailable'), tr('Log in to the selected Rookhaven server and try again.'))
    return
  end
  state = {kind=kind, endpoint=endpoint, account=kind == 2 and G.account or nil,
           password=kind == 2 and G.password or nil, token=G.authenticatorToken}
  EnterGame.hide()
  if CharacterList.isVisible() then CharacterList.hide() end
  window = g_ui.displayUI(kind == 1 and 'createaccount' or 'createcharacter')
  if kind == 2 then
    field('sex'):addOption(tr('Male'), 1)
    field('sex'):addOption(tr('Female'), 0)
    AccountServicesUI.updatePreview()
    field('description'):setText(tr('Begin as Unawakened at level 1. Choose your class as you progress.'))
  end
  field(kind == 1 and 'account' or 'name'):focus()
  status(tr('Checking availability...'))
  request(0, {}, function(success, message, name, policy)
    if not success then status(message, true); return end
    state.policy, state.allowed = policy, kind == 1 and policy.account or kind == 2 and policy.character
    if kind == 2 then
      field('description'):setText(tr('Begin as Unawakened at level 1 in %s. Choose your class as you progress.', policy.town))
    end
    status(state.allowed and (kind == 1 and tr('Create an account on %s.', policy.world) or
      tr('Names use 3-29 letters and single spaces. Up to %s characters per account.', policy.limit)) or
      tr('Creation is currently closed on this server.'), not state.allowed)
    enabled(true)
  end)
end

function AccountServicesUI.init()
  connect(g_game, {onGameStart=AccountServicesUI.abort})
end
function AccountServicesUI.terminate()
  disconnect(g_game, {onGameStart=AccountServicesUI.abort})
  dispose()
  AccountServicesUI = nil
end
function AccountServicesUI.abort() dispose() end
function AccountServicesUI.isVisible() return window ~= nil end
function AccountServicesUI.raise()
  if window then window:raise(); window:focus() end
end
function AccountServicesUI.openAccount() open(1) end
function AccountServicesUI.openCharacter() open(2) end
function AccountServicesUI.close()
  if not state or state.busy then return end
  local kind = state.kind
  dispose()
  if kind == 2 then CharacterList.show() else EnterGame.show() end
end
function AccountServicesUI.updatePreview()
  if not window or state.kind ~= 2 then return end
  local option = field('sex'):getCurrentOption()
  field('preview'):setOutfit({type=option and option.data == 0 and 136 or 128, head=78, body=69, legs=58, feet=76, addons=0})
  field('preview'):setDirection(South)
end
function AccountServicesUI.submit()
  if not state or state.busy or not state.policy or not state.allowed then return end
  local values
  if state.kind == 1 then
    values = {account=field('account'):getText():trim(), email=field('email'):getText():trim(), password=field('password'):getText()}
    if #values.account < 4 or #values.account > 20 or values.account:find('[^A-Za-z0-9_]') then
      status(tr('Account names need 4-20 letters, numbers or underscores.'), true); return
    end
    if not values.email:match('^[^%s@]+@[^%s@]+%.[^%s@]+$') then
      status(tr('Enter a valid email address.'), true); return
    end
    if #values.password < 10 or #values.password > 40 or values.password:find('%c') then
      status(tr('Use a password of 10-40 characters without control characters.'), true); return
    end
    if values.password ~= field('confirm'):getText() then status(tr('The passwords do not match.'), true); return end
  else
    values = {account=state.account, password=state.password, name=field('name'):getText():trim(), sex=field('sex'):getCurrentOption().data}
    if #values.name < 3 or #values.name > 29 or values.name:find('[^A-Za-z ]') or values.name:find('  ') then
      status(tr('Use 3-29 letters with single spaces for your character name.'), true); return
    end
  end
  state.busy = true
  enabled(false)
  status(tr('Creating... Please wait for confirmation.'))
  request(state.kind, values, function(success, message, name, policy)
    state.busy = false
    if not success then status(message, true); enabled(true); return end
    local endpoint, token, kind = state.endpoint.address, state.token, state.kind
    if kind == 2 then
      g_settings.set('last-used-character', name)
      g_settings.set('last-used-world', policy.world)
    end
    local account, password = values.account, values.password
    dispose()
    -- Refresh through ordinary login, including its Remember password behavior.
    EnterGame.doLogin(account, password, token, endpoint)
  end)
end
