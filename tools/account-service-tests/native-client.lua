local failed,done,loggingOut,reconnected=false,false,false,false
local receipts,requests={},{}
local maxLogin=false
local tlsChecks=0
local function fail(why)
  if failed then return end;failed=true;print('ACCOUNTS_UI_FAILED '..tostring(why));g_app.exit()
end
local function later(ms,fn)
  scheduleEvent(function()if failed or done then return end;local ok,e=xpcall(fn,debug.traceback);if not ok then fail(e)end end,ms)
end
local function wait(label,test,nextStep)
  local deadline=g_clock.millis()+15000
  local function poll()
    local result=test();if result then nextStep(result);return end
    assert(g_clock.millis()<deadline,label..' timed out');later(80,poll)
  end
  later(100,poll)
end
local function win(id)local w=rootWidget:getChildById(id);return w and w:isVisible()and w end
local function ready(id)return function()local w=win(id);return w and w:getChildById('submit'):isEnabled()and w end end
local function qa(action,nextStep)
  local before=receipts[action];g_game.talk('/accountsqa '..action)
  wait(action,function()return receipts[action]~=before and receipts[action]end,nextStep)
end
local function shot(name,nextStep)
  g_window.resize({width=1280,height=800})
  later(450,function()
    g_app.doScreenshot('/accounts-'..name..'-1280.png');g_window.resize({width=800,height=640})
    later(450,function()g_app.doScreenshot('/accounts-'..name..'-800.png');nextStep()end)
  end)
end
local function logout(nextStep)
  loggingOut=true;g_game.safeLogout();wait('logout',function()return not g_game.isOnline()end,nextStep)
end
local function finish()
  qa('state',function(r)
    assert(r.modernPassword,'game login did not upgrade the legacy password')
    assert(r.guild=='Accounts QA Guild'and r.rank==3 and r.canInvite and not r.canCreate,'guild membership/rank/permissions did not survive reconnect')
    assert(r.knife==1 and r.torch==1 and r.bag==1 and r.apple==1 and r.robe==1,'starter items duplicated or lost after reconnect')
    qa('rest',function()logout(function()
      -- The largest newly permitted credentials must fit the real RH2 game-login RSA block.
      local account,password,name=string.rep('a',20),string.rep('p',40),string.rep('B',29)
      local endpoint=assert(EnterGame.getAccountEndpoint())
      local first=ProtocolAccounts.create();_G.maxCredentialsProtocol=first
      first:request(endpoint,1,{account=account,password=password,email='max@example.invalid'},function(ok,message)
        assert(ok,message)
        local second=ProtocolAccounts.create();_G.maxCredentialsProtocol=second
        second:request(endpoint,2,{account=account,password=password,name=name,sex=1},function(created,why,canonical)
          assert(created,why);maxLogin=true;loggingOut=false
          CharacterList.hide();EnterGame.doLogin(account,password,'',endpoint.address)
          wait('maximum credentials list',CharacterList.isVisible,function()CharacterList.doLogin()end)
        end)
      end)
    end)end)
  end)
end
local function guild()
  g_game.getProtocolGame():sendExtendedOpcode(101,json.encode({action='create',name='No Guildmaster Guild'}))
  later(400,function()qa('state',function(r)
    assert(r.guild==''and not r.canCreate,'creation bypassed Guildmaster')
    -- Dismiss the expected error dialog before speaking to the NPC.
    local m=rootWidget:getChildById('messageBox');if m then m:destroy()end
    qa('guildmaster',function()
      g_game.talkChannel(MessageModes.NpcTo,0,'hi')
      later(1500,function()g_game.talkChannel(MessageModes.NpcTo,0,'guild')
        wait('Guildmaster founding UI',function()
          local w=win('guildWindow');local panel=w and w:recursiveGetChildById('createGuildPanel')
          return panel and panel:isVisible()and w
        end,function(w)
          w:recursiveGetChildById('guildNameField'):setText('Accounts QA Guild')
          local button=w:recursiveGetChildById('createGuildBtn');signalcall(button.onClick,button)
          later(500,function()qa('state',function(r)
            assert(r.guild=='Accounts QA Guild'and r.rank==3 and r.canInvite and not r.canCreate,'guild creation failed')
            -- Revisiting a Guildmaster cannot grant a member a second guild.
            g_game.talkChannel(MessageModes.NpcTo,0,'guild')
            later(1400,function()
              g_game.getProtocolGame():sendExtendedOpcode(101,json.encode({action='create',name='Second QA Guild'}))
              later(400,function()qa('state',function(r)
                assert(r.guild=='Accounts QA Guild'and not r.canCreate,'member could create another guild')
                qa('legacy',function(r)
                  assert(not r.modernPassword,'legacy game-login fixture not installed')
                  qa('rest',function()logout(function()
                    reconnected=true;later(400,function()loggingOut=false;CharacterList.doLogin()end)
                  end)end)
                end)
              end)end)
            end)
          end)end)
        end)
      end)
    end)
  end)end)
end
local function createdCharacter()
  assert(#G.characters==1 and G.characters[1].name=='Ui New Hero','character refresh/focus failed')
  assert(not g_settings.get('password') or g_settings.get('password')=='','unchecked Remember password persisted credentials')
  g_app.doScreenshot('/accounts-character-list-800.png')
  later(350,function()
  AccountServicesUI.openCharacter()
  wait('reopened character view',ready('createCharacterWindow'),function()
    AccountServicesUI.close();assert(CharacterList.isVisible(),'cancel did not return to list')
    local account,password=G.account,G.password
    rootWidget:recursiveGetChildById('rememberPasswordBox'):setChecked(true)
    CharacterList.hide();EnterGame.doLogin(account,password,'',G.accountEndpoint)
    wait('remembered normal login',CharacterList.isVisible,function()
      assert(g_settings.get('password')~=password and g_crypt.decrypt(g_settings.get('password'))==password,'Remember password did not encrypt credentials')
      CharacterList.doLogin()
    end)
  end)
  end)
end
later(350,function()
  assert(LOCAL_PASSIVES_TEST and Services.updater==''and g_resources.getLayout()=='retro')
  HTTP.timeout=15
  HTTP.postJSON('https://updater2.rookhaven-ot.com/api/updater',{version=10103,platform='windows',channel='dev'},function(data,err)
    assert(not err and type(data)=='table' and data.upToDate==true,'authenticated DEV updater failed: '..tostring(err))
    tlsChecks=tlsChecks+1;print('AUTH_TLS_PASS valid DEV certificate')
  end)
  for _,host in ipairs({'self-signed.badssl.com','expired.badssl.com','wrong.host.badssl.com'})do
    HTTP.get('https://'..host..'/',function(_,err)
      assert(type(err)=='string' and err:find('HTTPS handshake error') and err:find('certificate verify failed'),'invalid certificate was not refused: '..host..' '..tostring(err))
      tlsChecks=tlsChecks+1;print('AUTH_TLS_PASS refused '..host)
    end)
  end
  local original=ProtocolAccounts.request
  ProtocolAccounts.request=function(self,endpoint,action,values,callback)
    assert(endpoint.host=='127.0.0.1'and endpoint.port==7187,'wrong server target')
    requests[action]=(requests[action]or 0)+1
    return original(self,endpoint,action,values,callback)
  end
  connect(g_game,{onLoginError=fail,onConnectionError=function(e)if not loggingOut then fail(e)end end,
    onTextMessage=function(_,text)
      local raw=text:match('^ACCOUNTS_NATIVE (.+)$');if raw then local r=json.decode(raw);receipts[r.label]=r end
    end,
    onGameStart=function()
      EnterGame.hide()
      later(800,function()
        if modules.game_outfit.destroy then modules.game_outfit.destroy(true,true)end
        if maxLogin then
          assert(tlsChecks==4,'native HTTPS certificate checks did not finish')
          assert(#g_game.getLocalPlayer():getName()==29,'maximum character name was truncated')
          logout(function()
            done=true;print('ACCOUNTS_UI_NATIVE_OK register=true emailRequired=true noPlaintextSettings=true rememberedEncrypted=true character=true compactForm=true duplicateSubmit=true firstItems=true reconnect=true guildmaster=true maximumRsaCredentials=true tlsCertificates=true');g_app.exit()
          end)
          return
        end
        if reconnected then return finish()end
        qa('state',function(r)
          assert(r.level==1 and r.vocation==0 and r.group==1,'ordinary new character progression')
          assert(r.knife==1 and r.torch==1 and r.bag==1 and r.apple==1 and r.robe==1,'first login starter items')
          guild()
        end)
      end)
    end})
  Servers.Default='127.0.0.1:7187:860';EnterGame.onServerChange()
  rootWidget:recursiveGetChildById('rememberPasswordBox'):setChecked(false)
  g_window.resize({width=800,height=640})
  later(450,function()g_app.doScreenshot('/accounts-login-800.png')end)
  later(900,function()
  AccountServicesUI.openAccount();AccountServicesUI.close()
  AccountServicesUI.openAccount() -- stale first policy callback must not touch this window
  wait('registration',ready('createAccountWindow'),function(w)
    shot('register',function()
      w:getChildById('account'):setText('uiaccountsqa');w:getChildById('password'):setText('UiLoopbackOnlyPass');w:getChildById('confirm'):setText('UiLoopbackOnlyPass')
      AccountServicesUI.submit();assert(w:getChildById('status'):getText():find('email'),'missing email accepted')
      w:getChildById('email'):setText('ui+qa@example.invalid');w:getChildById('confirm'):setText('mismatch')
      AccountServicesUI.submit();assert(w:getChildById('status'):getText():find('do not match'),'password confirmation accepted')
      w:getChildById('confirm'):setText('UiLoopbackOnlyPass');AccountServicesUI.submit();AccountServicesUI.submit();AccountServicesUI.close()
      assert(AccountServicesUI.isVisible()and requests[1]==1 and not w:getChildById('cancel'):isEnabled(),'duplicate request or close while submitting')
      wait('empty account list',CharacterList.isVisible,function()
        assert(#G.characters==0 and rootWidget:recursiveGetChildById('emptyCharacters'):isVisible(),'empty account path')
        g_app.doScreenshot('/accounts-empty-list-800.png')
        later(350,function()
        local button=rootWidget:recursiveGetChildById('createCharacter');signalcall(button.onClick,button)
        wait('character form',ready('createCharacterWindow'),function(c)
          c:getChildById('name'):setText('ui new hero');c:getChildById('sex'):setCurrentOptionByData(0)
          assert(c:getChildById('sex'):getCurrentOption().data==0,'female selection did not update')
          assert(c:getChildById('preview'):getOutfit().type==136,'female preview does not match actual outfit')
          shot('character',function()
            c:getChildById('name'):setText('A')
            AccountServicesUI.submit()
            assert(requests[2]==nil and c:getChildById('status'):getText():find('3%-29'),'invalid name was submitted')
            c:getChildById('name'):setText('ui new hero')
            AccountServicesUI.submit();AccountServicesUI.submit();assert(requests[2]==1,'duplicate character request')
            wait('refreshed list',CharacterList.isVisible,createdCharacter)
          end)
        end)
        end)
      end)
    end)
  end)
  end)
end)
scheduleEvent(function()if not done then fail('native UI timeout')end end,165000)
