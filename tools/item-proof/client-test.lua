assert(APP_VERSION == 10083)
g_configs.loadSettings('/dev-startup-test-config.otml')
local ready=false
for _,op in pairs(HTTP.operations) do
  if op.url==Services.updater then
    local cb=op.callback
    op.callback=function(data,err)
      assert(not err and type(data)=='table')
      print('ITEM_UPDATER_OK version='..APP_VERSION)
      cb({upToDate=true},nil)
      ready=true
    end
  end
end
local phase=0
local blade
local sawLook=false
local expectedDisconnect=false
local interactive=os.getenv('ROOKHAVEN_ITEM_INTERACTIVE')=='1'
local function checkClassicInventory()
  assert(g_resources.getLayout()=='retro')
  local inventory=modules.game_inventory
  local style=g_ui.getStyle('InventoryItem')
  assert(style['image-source']=='/images/ui/item')
  assert(style['$on']['image-source']=='/images/ui/item')
  for _,blessed in ipairs({true,false}) do
    inventory.toggleAdventurerStyle(blessed)
    for slot=1,10 do
      local widget=assert(inventory.inventoryPanel:getChildById('slot'..slot))
      if widget:getItem() then
        assert(widget:getIconPath()=='','Empty-slot icon covers an equipped item')
      else
        assert(widget:getIconPath():find('/images/game/slots/inventory-',1,true),
          'Empty inventory slot did not use a transparent classic icon')
        assert(widget:getStyle()['image-source']=='/images/ui/item')
      end
    end
  end
  print('CLASSIC_INVENTORY_OK')
end
local function findBlade()
  local p=g_game.getLocalPlayer()
  for slot=1,10 do
    local i=p:getInventoryItem(slot)
    if i and i:getId()==11866 then return i end
  end
end
connect(g_game,{
  onLoginError=function(message) print('ITEM_TEST_FAILED '..message) g_app.exit() end,
  onConnectionError=function(message)
    if not expectedDisconnect then print('ITEM_TEST_FAILED '..message) g_app.exit() end
  end,
  onTextMessage=function(mode,text)
    print('ITEM_SERVER_MESSAGE '..text)
    if text:find('rookhaven duskblade',1,true) and text:find('52',1,true) then sawLook=true end
  end,
  onGameStart=function()
    print('ITEM_GAME_START phase='..phase)
    scheduleEvent(function()
      EnterGame.hide()
      blade=assert(findBlade(),'Server did not send CID 11866 in inventory')
      assert(blade:isPickupable() and not blade:isNotMoveable())
      print('ITEM_NATIVE_ASSET_OK CID='..blade:getId())
      checkClassicInventory()
      if interactive then
        g_game.look(blade)
        print('LOCAL_ITEM_CLIENT_READY')
        return
      end
      if phase==0 then
        phase=1
        g_game.look(blade)
        local pos=g_game.getLocalPlayer():getPosition()
        g_game.move(blade,pos,1)
        scheduleEvent(function()
          assert(not findBlade(),'Item was not moved out of equipment')
          checkClassicInventory()
          local tile=assert(g_map.getTile(pos))
          local ground
          for _,thing in pairs(tile:getThings()) do
            if thing:isItem() and thing:getId()==11866 then ground=thing end
          end
          assert(ground,'Item did not arrive on the ground')
          print('ITEM_GROUND_MOVE_OK')
          g_game.move(ground,{x=65535,y=5,z=0},1)
          scheduleEvent(function()
            assert(findBlade(),'Item could not be equipped again')
            checkClassicInventory()
            assert(sawLook,'Server look did not contain the expected item name/stats')
            print('ITEM_EQUIP_LOOK_OK')
            g_app.doScreenshot('/item-proof-in-game.png')
            scheduleEvent(function() expectedDisconnect=true g_game.safeLogout() end,800)
          end,1000)
        end,1000)
      else
        print('ITEM_RELOGIN_PERSISTENCE_OK')
        print('ITEM_INTEGRATION_OK')
        expectedDisconnect=true
        g_game.safeLogout()
        scheduleEvent(function()g_app.exit()end,500)
      end
    end,1200)
  end,
  onGameEnd=function()
    if phase==1 then
      phase=2
      scheduleEvent(function()
        expectedDisconnect=false
        local mapPath='/minimap860.pid'..g_platform.getProcessId()..'.otmm'
        assert(g_resources.fileExists(mapPath),'Small minimap was not saved')
        print('ITEM_MINIMAP_SAVE_OK bytes='..#g_resources.readFileContents(mapPath))
        g_game.loginWorld('itemtest','itemtest','Rookhaven Local Item Test','127.0.0.1',7175,'Item Tester','','')
      end,1000)
    end
  end
})
local began=g_clock.millis()
local function start()
  if not ready or not g_modules.getModule('game_interface'):isLoaded() then
    assert(g_clock.millis()-began<20000,'Updater did not finish')
    scheduleEvent(start,100) return
  end
  EnterGame.hide()
  local ok,err=pcall(g_resources.readFileContents,'/item-proof-deliberately-missing.txt')
  assert(not ok and err:find('unable to open file',1,true))
  print('ITEM_LUA_ERROR_RECOVERY_OK')
  for line in g_resources.readFileContents('/item-proof-checksum-paths.txt'):gmatch('[^\r\n]+') do
    local path=line
    if not g_resources.fileExists(path) and path:sub(-4)=='.lua' then path=path..'c' end
    print('ITEM_CHECKSUM '..line..'='..g_resources.fileChecksum(path))
  end
  connect(g_game,{onTextMessage=function(mode,text)
    print('ITEM_SERVER_MESSAGE '..text)
    if text:find('rookhaven duskblade',1,true) and text:find('52',1,true) then sawLook=true end
  end})
  g_game.setClientVersion(860)
  g_game.setProtocolVersion(860)
  g_game.setRsa(OTSERV_RSA)
  G.account='itemtest' G.password='itemtest'
  local login=ProtocolLogin.create()
  _G.itemProofLogin=login
  login.onLoginError=function(_,err) print('ITEM_TEST_FAILED '..err) g_app.exit() end
  login.onCharacterList=function(_,chars,account)
    local ch=assert(chars[1])
    assert(ch.name=='Item Tester' and ch.worldIp=='127.0.0.1' and ch.worldPort==7175)
    print('ITEM_LOGIN_PROTOCOL_OK')
    g_game.loginWorld('itemtest','itemtest',ch.worldName,ch.worldIp,ch.worldPort,ch.name,'','')
  end
  login:login('127.0.0.1',7174,'itemtest','itemtest','',false)
end
scheduleEvent(start,100)
if not interactive then
  scheduleEvent(function()print('ITEM_TEST_TIMEOUT')g_app.exit()end,35000)
end
