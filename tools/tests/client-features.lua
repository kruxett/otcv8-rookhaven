assert(APP_VERSION == 10084)
g_configs.loadSettings('/dev-startup-test-config.otml')
local ready = false
for _, operation in pairs(HTTP.operations) do
  if operation.url == Services.updater then
    local callback = operation.callback
    operation.callback = function(data, err)
      assert(not err and type(data) == 'table')
      callback({upToDate=true}, nil)
      ready = true
    end
  end
end
local announcements = {}
local combatOk = false
local finished = false
local function onTextMessage(mode, text)
    print('FEATURE_MESSAGE '..text)
    for stage, name in ipairs({'Awakened','Ascendant','Ascended'}) do
      if text:find('[TEST] [Ascension]',1,true) and text:find('to '..name..'!',1,true) then
        announcements[stage] = true
      end
    end
    if text == 'FEATURE_NATIVE_COMBAT_OK' then combatOk = true end
    assert(not text:find('FEATURE_NATIVE_COMBAT_FAILED',1,true), text)
end
connect(g_game, {
  onGameStart=function()
    scheduleEvent(function()
      EnterGame.hide()
      -- gamelib defines its text-message dispatcher during module loading.
      connect(g_game, {onTextMessage=onTextMessage})
      local player = assert(g_game.getLocalPlayer())
      local originalLevel = player:getLevel()
      local map = modules.game_interface.getMapPanel()
      assert(not modules.client_options.getOption('showGuildNames'), 'guild labels must default off')
      assert(not map:isDrawingGuildNames())
      modules.client_options.setOption('showGuildNames', true)
      assert(map:isDrawingGuildNames() and g_settings.getBoolean('showGuildNames'), 'switch did not persist')
      for stage=1,3 do
        scheduleEvent(function() g_game.talk('/testascensionannouncement '..stage) end, stage*1100)
      end
      scheduleEvent(function() g_game.talk('/featureprobe burst') end, 4500)
      scheduleEvent(function()
        assert(player:getGuildName() == 'Feature Testers', 'guild metadata missing')
        assert(announcements[1] and announcements[2] and announcements[3], 'stage announcement missing')
        assert(player:getLevel() == originalLevel, 'announcement test changed progression')
        assert(combatOk, 'native combat probe did not pass')
        print('FEATURE_ANNOUNCEMENTS_AND_COMBAT_OK')
        g_app.doScreenshot('/feature-guild-enabled.png')
        scheduleEvent(function()
          modules.client_options.setOption('showGuildNames', false)
          assert(not map:isDrawingGuildNames() and not g_settings.getBoolean('showGuildNames'))
          assert(player:getGuildName() == '', 'switch off did not clear labels')
          print('FEATURE_GUILD_SWITCH_OK')
          g_app.doScreenshot('/feature-guild-disabled.png')
          scheduleEvent(function() modules.client_options.setOption('showGuildNames', true) end, 400)
        end, 500)
      end, 7000)
      scheduleEvent(function()
        assert(player:getGuildName() == 'Feature Testers', 'switch on did not reload guild metadata')
        g_game.talk('/featureprobe guildclear')
      end, 10000)
      scheduleEvent(function()
        assert(player:getGuildName() == '', 'stationary guild removal did not refresh')
        print('FEATURE_GUILD_MEMBERSHIP_REFRESH_OK')
        modules.client_options.setOption('showGuildNames', false)
        assert(not map:isDrawingGuildNames() and not g_settings.getBoolean('showGuildNames'))
        assert(player:getGuildName() == '', 'switch off did not clear labels')
        finished = true
        g_game.safeLogout()
        scheduleEvent(function() print('CLIENT_FEATURES_OK') g_app.exit() end, 1000)
      end, 13000)
    end, 1500)
  end,
  onConnectionError=function(err) assert(finished, err) end,
})
local began = g_clock.millis()
local function login()
  if not ready or not g_modules.getModule('game_interface'):isLoaded() then
    assert(g_clock.millis()-began < 20000, 'startup timeout')
    scheduleEvent(login, 100)
    return
  end
  EnterGame.hide()
  g_game.setClientVersion(860)
  g_game.setProtocolVersion(860)
  g_game.setRsa(OTSERV_RSA)
  G.account='itemtest' G.password='itemtest'
  local protocol = ProtocolLogin.create()
  _G.featureTestLogin = protocol
  protocol.onLoginError=function(_,err) error(err) end
  protocol.onCharacterList=function(_,characters)
    local ch=assert(characters[1])
    g_game.loginWorld('itemtest','itemtest',ch.worldName,ch.worldIp,ch.worldPort,ch.name,'','')
  end
  protocol:login('127.0.0.1',7174,'itemtest','itemtest','',false)
end
scheduleEvent(login,100)
scheduleEvent(function() if not finished then error('FEATURE_TEST_TIMEOUT') end end, 35000)
