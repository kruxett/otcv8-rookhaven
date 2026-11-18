AccountManagementUI = {}
local window, state, protocol
local generation = 0
local A = {overview=3,password=4,delete=5,setup=6,enable=7,disable=8,codes=9,recover=10,sendVerification=11,verify=12,sendReset=13,reset=14}
local function widget(id) return window and window:recursiveGetChildById(id) end
local function text(id) local w=widget(id); return w and w:getText() or '' end
local function status(message, bad)
  if not window then return end
  widget('status'):setText(message or '')
  widget('status'):setColor(bad and '#e3a0a0' or '#c6b58c')
end
local function busy(value)
  state.busy=value
  widget('content'):setEnabled(not value)
  for _,id in ipairs({'accountTab','charactersTab','securityTab','authenticator'}) do widget(id):setEnabled(not value) end
  widget('back'):setEnabled(not value)
end
local function clear()
  widget('content'):destroyChildren()
  state.fields={}
end
local function label(value, height)
  local w=g_ui.createWidget('AccountManagerLabel',widget('content'))
  w:setText(value); w:setHeight(height or 24); return w
end
local function field(id, caption, secret, value, limit)
  label(caption,16)
  local w=g_ui.createWidget(secret and 'AccountManagerPassword' or 'AccountManagerField',widget('content'))
  w:setId(id); w:setText(value or ''); w:setMaxLength(limit or 128)
  state.fields[#state.fields+1]=id
  return w
end
local function button(id, caption, action)
  local w=g_ui.createWidget('AccountManagerButton',widget('content'))
  w:setId(id); w:setText(caption); w.onClick=action; return w
end
local function dispose()
  generation=generation+1
  if protocol then protocol:cancel(); protocol=nil end
  if window then window:destroy(); window=nil end
  state=nil
end
local function request(action, values, callback)
  if not state or state.busy then return end
  values=values or {}
  values.management=true
  values.account=values.account or state.account
  values.password=values.password or state.password
  values.token=values.token or text('authenticator'):trim()
  local current=generation
  busy(true); status(tr('Please wait...'))
  protocol=ProtocolAccounts.create()
  protocol:request(state.endpoint,action,values,function(success,message,name,policy,data)
    if not window or current~=generation then return end
    protocol=nil; busy(false)
    state.policy=policy or state.policy
    status(message,not success)
    if callback then callback(success,message,data or {}) end
  end)
end
local function showCodes(data)
  if type(data.recoveryCodes)~='table' or #data.recoveryCodes~=10 then status(tr('Invalid recovery-code response. Please refresh.'),true);return end
  clear(); state.form='codes'
  label(tr('Recovery codes'),20)
  label(tr('Save these codes somewhere safe. They can turn off a lost authenticator when used with your account password. These codes are shown only once.'),52)
  for index=1,10,2 do
    label(string.format('%s     %s',data.recoveryCodes[index],data.recoveryCodes[index+1]),20)
  end
  button('copyCodes',tr('Copy recovery codes'),function() g_window.setClipboardText(table.concat(data.recoveryCodes,'\n'));status(tr('Recovery codes copied. Keep them private.')) end)
  state.unsavedCodes=true
  button('savedCodes',tr('I have saved these codes'),function() state.unsavedCodes=false;AccountManagementUI.tab('security') end)
end
local function confirmFields()
  field('currentPassword',tr('Current password'),true,'',128)
end
local function changed(message)
  state.changed=true
  status(message)
end

function AccountManagementUI.tab(tab)
  if not state or state.busy then return end
  if state.unsavedCodes then status(tr('Save the recovery codes, then press "I have saved these codes".'),true);return end
  clear();state.form=nil;state.tab=tab;status('')
  for _,id in ipairs({'account','characters','security'}) do widget(id..'Tab'):setOn(tab==id) end
  if state.recovery then
    label(tr('Recover a lost authenticator'),20)
    label(tr('This turns off your authenticator and invalidates its old recovery codes. Your account password and one recovery code are required.'),48)
    field('recoveryAccount',tr('Account name'),false,state.account,128)
    field('recoveryPassword',tr('Account password'),true,'',128)
    field('recoveryCode',tr('Recovery code'),true,'',16)
    button('recoverAuthenticator',tr('Disable lost authenticator'),function()
      request(A.recover,{account=text('recoveryAccount'):trim(),password=text('recoveryPassword'),token=text('recoveryCode'):trim()},function(ok,message)
        if ok then state.account=text('recoveryAccount'):trim();clear();label(message,68);button('returnLogin',tr('Return to login'),AccountManagementUI.close) end
      end)
    end)
    if state.policy and state.policy.passwordRecovery then button('passwordRecovery',tr('Recover password by email'),AccountManagementUI.passwordRecovery) end
    return
  end
  local data=state.data
  if not data then
    label(tr('Enter a current authenticator code below if your account uses one, then refresh.'),48)
    button('refreshAccount',tr('Refresh account'),AccountManagementUI.refresh)
    return
  end
  if tab=='account' then
    label(tr('Account: %s',data.account),20)
    label(tr('Email: %s',data.email),32)
    label(data.premiumUntil and data.premiumUntil>os.time() and tr('Premium until %s',os.date('%Y-%m-%d',data.premiumUntil)) or tr('Free account'),20)
    label(data.emailVerified and tr('Email verified') or tr('Email not verified'),20)
    button('changePassword',tr('Change password'),AccountManagementUI.password)
    if state.policy.emailVerification then
      button('verifyEmail',tr('Verify email address'),AccountManagementUI.emailVerification)
    else label(tr('Email verification is not enabled on this server.'),32) end
    button('refreshAccount',tr('Refresh account'),AccountManagementUI.refresh)
  elseif tab=='characters' then
    local characters=type(data.characters)=='table' and data.characters or {}
    label(tr('Characters: %s / %s',#characters,data.limit),20)
    state.selected=nil
    local listPanel=g_ui.createWidget('AccountManagerCharacters',widget('content'))
    local list=listPanel:getChildById('list');list:setId('accountCharacters')
    for _,character in ipairs(characters) do
      local row=g_ui.createWidget('AccountManagerCharacter',list);row:setId('character-'..character.id);row:setText(character.name..'  ('..tr('Level %s',character.level)..')'..(character.online and '  '..tr('Online') or ''))
      row.onDoubleClick=function() AccountManagementUI.deleteCharacter(character) end
      row.onFocusChange=function(_,focused) if focused then state.selected=character end end
    end
    label(tr('Select a character to delete. Log out and finish guild, shop and house commitments first.'),36)
    button('createCharacter',tr('Create character'),function() AccountManagementUI.close(true);AccountServicesUI.openCharacter() end)
    button('deleteCharacter',tr('Delete selected character'),function()
      if state.selected then AccountManagementUI.deleteCharacter(state.selected) else status(tr('Select a character first.'),true) end
    end)
  elseif tab=='security' then
    label(data.twoFactor and tr('Authenticator enabled') or tr('Authenticator not enabled'),24)
    label(tr('Use a time-based authenticator app for login. Recovery codes let you regain access if that app is lost.'),48)
    if data.twoFactor then
      button('newRecoveryCodes',tr('Generate new recovery codes'),function()
        AccountManagementUI.securityConfirmation(A.codes,tr('Replace all recovery codes? Old codes will stop working.'))
      end)
      button('disableAuthenticator',tr('Disable authenticator'),function()
        AccountManagementUI.securityConfirmation(A.disable,tr('Turn off the authenticator? Your account will use password-only login.'))
      end)
    elseif state.policy.twoFactor then button('setupAuthenticator',tr('Set up authenticator'),AccountManagementUI.setup)
    else label(tr('Authenticator setup is not enabled on this server.'),32) end
  end
end

function AccountManagementUI.refresh()
  request(A.overview,{},function(ok,_,data)
    if not ok then return end
    if type(data.account)~='string' or type(data.email)~='string' or type(data.twoFactor)~='boolean' then status(tr('Invalid account response.'),true);return end
    state.data=data;state.selected=nil;widget('identity'):setText(data.account..'  -  '..state.policy.world)
    AccountManagementUI.tab(state.tab or 'account')
  end)
end
function AccountManagementUI.password()
  clear();state.form='password';label(tr('Change password'),20);confirmFields()
  field('newPassword',tr('New password (10-40 characters)'),true,'',40)
  field('confirmPassword',tr('Confirm new password'),true,'',40)
  local show=g_ui.createWidget('CheckBox',widget('content'));show:setId('showPasswords');show:setText(tr('Show passwords'));show:setHeight(18)
  show.onCheckChange=function(_,checked)
    for _,id in ipairs({'currentPassword','newPassword','confirmPassword'}) do widget(id):setTextHidden(not checked) end
  end
  button('savePassword',tr('Change password'),function()
    local value=text('newPassword')
    if #value<10 or #value>40 or value:find('%c') or value~=text('confirmPassword') then status(tr('Use 10-40 characters and enter the same new password twice.'),true);widget('newPassword'):focus();return end
    request(A.password,{password=text('currentPassword'),value=value,extra=text('confirmPassword')},function(ok,message)
      if ok then state.password=value;G.password=value;g_settings.remove('password');AccountManagementUI.tab('account');changed(message) end
    end)
  end)
end
function AccountManagementUI.deleteCharacter(character)
  if state.busy then return end
  clear();state.form='delete';state.selected=character
  label(tr('Delete %s?',character.name),24):setColor('#e3a0a0')
  label(tr('This removes the character from your account. It cannot log in again and will be permanently removed on a later server restart. This cannot be undone here.'),58)
  confirmFields();field('characterConfirmation',tr('Type the exact character name: %s',character.name),false,'',29)
  button('confirmDeleteCharacter',tr('Delete character'),function()
    if text('characterConfirmation')~=character.name then status(tr('Enter the exact character name to confirm deletion.'),true);widget('characterConfirmation'):focus();return end
    request(A.delete,{password=text('currentPassword'),value=character.name,extra=text('characterConfirmation')},function(ok,message)
      if ok then state.password=text('currentPassword');state.changed=true;state.tab='characters';AccountManagementUI.refresh();status(message) end
    end)
  end)
end
function AccountManagementUI.setup()
  request(A.setup,{},function(ok,message,data)
    if not ok then return end
    if type(data.secret)~='string' or #data.secret~=32 then status(tr('Invalid authenticator setup response.'),true);return end
    clear();state.form='setup';label(message,74)
    local secret=field('setupSecret',tr('Manual entry key'),false,data.secret,32);secret:setEditable(false)
    button('copySecret',tr('Copy setup key'),function()g_window.setClipboardText(data.secret);status(tr('Setup key copied. Keep it private.'))end)
    field('setupCode',tr('Six-digit code from your authenticator app'),false,'',6)
    button('enableAuthenticator',tr('Enable authenticator'),function()
      local code=text('setupCode'):trim()
      request(A.enable,{value=code},function(enabled,msg,codes)
        if enabled then state.data.twoFactor=true;state.changed=true;widget('authenticator'):setText(code);G.authenticatorToken=code;showCodes(codes);status(msg) end
      end)
    end)
  end)
end
function AccountManagementUI.securityConfirmation(action,prompt)
  clear();state.form='security';label(prompt,50);confirmFields()
  button('confirmSecurity',action==A.disable and tr('Disable authenticator') or tr('Replace recovery codes'),function()
    request(action,{password=text('currentPassword')},function(ok,message,data)
      if not ok then return end
      state.password=text('currentPassword');state.changed=true
      if action==A.codes then showCodes(data) else state.data.twoFactor=false;widget('authenticator'):clearText();G.authenticatorToken='';AccountManagementUI.tab('security') end
      status(message)
    end)
  end)
end
function AccountManagementUI.emailVerification()
  request(A.sendVerification,{},function(ok,message)
    if not ok then return end
    clear();state.form='email';label(message,55);field('emailCode',tr('Verification code from your email'),false,'',64)
    button('confirmEmail',tr('Verify email'),function()request(A.verify,{value=text('emailCode'):trim()},function(verified,msg)
      if verified then state.data.emailVerified=true;AccountManagementUI.tab('account');changed(msg) end
    end)end)
  end)
end
function AccountManagementUI.passwordRecovery()
  clear();state.form='resetRequest';label(tr('Recover password by email'),24)
  field('resetAccount',tr('Account name'),false,state.account,128);field('resetEmail',tr('Registered email address'),false,'',254)
  button('requestReset',tr('Send recovery code'),function()
    local account=text('resetAccount'):trim()
    request(A.sendReset,{account=account,password='',token='',value=text('resetEmail'):trim()},function(ok,message)
      if not ok then return end
      clear();state.form='reset';label(message,48)
      field('resetCode',tr('Recovery code from your email'),false,'',64)
      field('resetPassword',tr('New password (10-40 characters)'),true,'',40)
      field('resetConfirm',tr('Confirm new password'),true,'',40)
      button('confirmReset',tr('Reset password'),function()
        request(A.reset,{account=account,password='',token=text('resetCode'):trim(),value=text('resetPassword'),extra=text('resetConfirm')},function(done,msg)
          if done then clear();label(msg,64);button('returnLogin',tr('Return to login'),AccountManagementUI.close) end
        end)
      end)
    end)
  end)
end
function AccountManagementUI.back()
  if not state or state.busy then return end
  if state.form then AccountManagementUI.tab(state.tab or 'account') else AccountManagementUI.close() end
end
function AccountManagementUI.close(skipRefresh)
  if not state then return end
  if state.unsavedCodes then status(tr('Save the recovery codes and confirm before closing.'),true);return end
  local old=state
  local token=text('authenticator'):trim()
  dispose()
  if old.recovery then EnterGame.show()
  elseif old.changed and not skipRefresh then EnterGame.doLogin(old.account,old.password,token,old.endpoint.address)
  else CharacterList.show() end
end
local function open(recovery)
  if window then window:raise();window:focus();return end
  if g_game.isOnline() or g_game.isLogging() then return end
  local endpoint=EnterGame.getAccountEndpoint(not recovery)
  if not endpoint or (not recovery and (not G.account or not G.password)) then displayErrorBox(tr('Account Management'),tr('Log in to the selected server first.'));return end
  state={endpoint=endpoint,account=G.account or '',password=G.password or '',recovery=recovery,fields={}}
  EnterGame.hide();CharacterList.hide()
  window=g_ui.displayUI('accountmanagement');widget('identity'):setText(endpoint.address)
  widget('authenticator'):setText(G.authenticatorToken or '')
  if recovery then
    widget('accountTab'):setText(tr('Recovery'));widget('charactersTab'):hide();widget('securityTab'):hide()
    widget('authenticator'):hide();widget('authenticatorCaption'):hide()
    request(0,{},function(ok)
      if ok then AccountManagementUI.tab('account') end
    end)
  else AccountManagementUI.tab('account');AccountManagementUI.refresh() end
end
function AccountManagementUI.open() open(false) end
function AccountManagementUI.openRecovery() open(true) end
function AccountManagementUI.init() connect(g_game,{onGameStart=dispose}) end
function AccountManagementUI.terminate() disconnect(g_game,{onGameStart=dispose});dispose() end
