-- Exercise the existing login settings write path, including failure before login.
tr=function(s)return s end
G={};g_game={isOnline=function()return false end,getClientVersion=function()return 860 end}
local saved={account='old-encrypted-account',password='old-encrypted-password'}
g_settings={get=function(k)return saved[k]end,set=function(k,v)saved[k]=v end,remove=function(k)saved[k]=nil end,save=function()end}
function string:trim()return self end
function string:split()return {self}end
dofile('modules/client_entergame/entergame.lua')
local function upvalue(fn,name,value)
  for n=1,99 do local key=debug.getupvalue(fn,n);if not key then break end;if key==name then debug.setupvalue(fn,n,value);return end end
  error('missing upvalue '..name)
end
local checked=false
upvalue(EnterGame.doLogin,'enterGame',{getChildById=function(_,id)return {getText=function()return id=='accountNameTextEdit'and 'newaccount'or 'plaintext-password' end}end})
upvalue(EnterGame.doLogin,'rememberPasswordBox',{isChecked=function()return checked end})
upvalue(EnterGame.doLogin,'serverSelector',{getText=function()return 'Default'end})
upvalue(EnterGame.doLogin,'serverHostTextEdit',{getText=function()return 'x'end}) -- controlled validation failure after saving settings
EnterGame.onError=function()end
EnterGame.doLogin()
assert(saved.account==nil and saved.password==nil,'unchecked Remember password stored credentials on failed login')
checked=true;saved.account,saved.password='previous-cipher-account','previous-cipher-password'
EnterGame.doLogin()
assert(saved.account=='previous-cipher-account'and saved.password=='previous-cipher-password','failed login replaced remembered credentials')
print('ACCOUNTS_LOGIN_SETTINGS_OK uncheckedCredentialsRemoved=true failedLoginDoesNotPersistPlaintext=true rememberedCredentialsPreserved=true')
