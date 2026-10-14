-- Native loopback integration: normal client consumers affected by removing bot
-- modules/loaders. The separate QA executable supplies this driver.
assert(LOCAL_PASSIVES_TEST and not g_game.isOnline())
local done, failed, finishing = false, false, false
local evidence, chats, looks = {}, {}, {}
local function samePosition(a,b) return a.x==b.x and a.y==b.y and a.z==b.z end
local function fail(reason)
  if done or failed then return end
  failed = true; print('CLIENT_NO_BOT_FAILED ' .. tostring(reason))
  if g_game.isOnline() then g_game.safeLogout() end
  scheduleEvent(function() g_app.exit() end, 500)
end
local function later(ms, fn)
  scheduleEvent(function()
    if done or failed then return end
    local ok, reason = xpcall(fn, debug.traceback)
    if not ok then fail(reason) end
  end, ms)
end
local function wait(label, condition, nextStep)
  local deadline = g_clock.millis() + 8000
  local function poll()
    if condition() then nextStep(); return end
    assert(g_clock.millis() < deadline, label .. ' timeout')
    later(80, poll)
  end
  later(80, poll)
end
local function finish()
  finishing = true; g_game.safeLogout()
  wait('logout', function() return not g_game.isOnline() end, function()
    done = true; print('CLIENT_NO_BOT_NATIVE_OK ' .. json.encode(evidence))
    scheduleEvent(function() g_app.exit() end, 300)
  end)
end
local function exercise()
  assert(not g_modules.getModule('game_bot') and not g_modules.getModule('client_terminal'))
  assert(not g_game.getFeature(95), 'Legacy bot feature still enabled')
  assert(g_resources.getLayout() == 'retro')
  evidence.botModulesAbsent = true
  evidence.retro = true
  EnterGame.hide()
  modules.game_hotkeys.show()
  later(250, function()
    modules.game_hotkeys.hide()
    modules.client_options.show()
    later(250, function()
      modules.client_options.hide()
      evidence.hotkeysAndOptions = true
      _G.ROOKHAVEN_CHAT_CODE_EXECUTED = nil
      modules.game_console.sendMessage('/lua _G.ROOKHAVEN_CHAT_CODE_EXECUTED=true')
      later(400, function()
        assert(_G.ROOKHAVEN_CHAT_CODE_EXECUTED == nil, '/lua still executes code')
        evidence.chatCodeDisabled = true
        local player = assert(g_game.getLocalPlayer())
        local item
        for slot=1,10 do item = player:getInventoryItem(slot); if item then break end end
        assert(item, 'Fixture needs an inventory item')
        g_game.look(item)
        wait('inventory look response', function() return #looks > 0 end, function()
          evidence.inventoryLook = true
          g_game.talk('Rookhaven local client regression check')
          wait('ordinary chat echo', function() return #chats > 0 end, function()
            evidence.normalChat = true
            local origin = player:getPosition()
            local destination
            for _,delta in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
              local position = {x=origin.x+delta[1], y=origin.y+delta[2], z=origin.z}
              local tile = g_map.getTile(position)
              if tile and tile:isWalkable() then destination=position;break end
            end
            assert(destination, 'No free adjacent fixture tile')
            player:autoWalk(destination)
            wait('normal map autowalk', function() return samePosition(player:getPosition(),destination) end, function()
              evidence.normalMapAutowalk = true
              player:autoWalk(origin)
              wait('return to start', function() return samePosition(player:getPosition(),origin) end, function()
                g_app.doScreenshot('/client-no-bot-native.png')
                later(300, finish)
              end)
            end)
          end)
        end)
      end)
    end)
  end)
end
later(300, function()
  -- Native restriction must reject even a loopback-looking DNS name. No network
  -- request is made: it throws before opening a socket.
  local protocol = Protocol.create()
  local ok = pcall(function() protocol:connect('localhost',7175) end)
  assert(not ok, 'QA endpoint restriction is missing')
  evidence.qaDnsEndpointRefused = true
  connect(g_game, {
    onGameStart=function() later(500, exercise) end,
    onLoginError=fail,
    onConnectionError=function(reason) if not finishing then fail(reason) end end,
    onTalk=function(name, _, _, text)
      if name == 'Passive Tester' and text == 'Rookhaven local client regression check' then chats[#chats+1]=text end
    end,
    onTextMessage=function(_, text) if text:find('You see',1,true) then looks[#looks+1]=text end end
  })
  g_game.setClientVersion(860); g_game.setProtocolVersion(860); g_game.setRsa(OTSERV_RSA)
  G.account='passivetest'; G.password='passivetest'
  local login=ProtocolLogin.create(); _G.noBotLogin=login
  login.onLoginError=function(_, reason) fail(reason) end
  login.onCharacterList=function(_, list)
    for _,character in ipairs(list) do
      if character.name == 'Passive Tester' then
        assert(character.worldIp == '127.0.0.1' and character.worldPort == 7175)
        evidence.loginCharacterList=true
        g_game.loginWorld(G.account,G.password,character.worldName,character.worldIp,character.worldPort,character.name,'','')
        return
      end
    end
    fail('Owned local fixture character missing')
  end
  login:login('127.0.0.1',7174,G.account,G.password,'',false)
end)
scheduleEvent(function() if not done then fail('Native no-bot regression timeout') end end,45000)
