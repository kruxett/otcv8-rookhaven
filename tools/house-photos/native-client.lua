-- Native map framebuffer captures, using only the owned loopback photo helper.
local catalogue=json.decode([==[__PHOTO_CATALOGUE__]==])
local limit=__PHOTO_LIMIT__
local plan={};local index=0;local failed=false;local active
local function fail(e)
  if failed then return end;failed=true;print('HOUSE_PHOTOS_FAILED '..tostring(e))
  g_app.doScreenshot('/accounts-photo-failure.png');scheduleEvent(function()g_app.exit()end,400)
end
local function later(ms,fn)scheduleEvent(function()if failed then return end;local ok,e=xpcall(fn,debug.traceback);if not ok then fail(e)end end,ms)end
local function wait(label,test,fn)
  local deadline=g_clock.millis()+15000
  local function poll()local value=test();if value then fn(value);return end;assert(g_clock.millis()<deadline,label..' timed out');later(100,poll)end
  later(100,poll)
end
local function nextPhoto()
  index=index+1
  if index>#plan then
    later(1500,function()print('HOUSE_PHOTOS_OK houses='..math.min(#catalogue,limit)..' floors='..#plan);g_app.exit()end);return
  end
  active=plan[index];g_game.talk('/housephoto '..active.house.id..' '..active.floor.z)
end
later(400,function()
  assert(LOCAL_PASSIVES_TEST and Services.updater=='' and g_resources.getLayout()=='retro')
  ProtocolGame.registerExtendedOpcode(119,function(protocol,opcode,buffer)
    local message=json.decode(buffer);local current=active
    if not current or message.id~=current.house.id or message.z~=current.floor.z then return end
    local map=modules.game_interface.getMapPanel()
    local f=current.floor
    -- Centre the house bounds, even when its middle tile cannot hold a player.
    -- The raw 18x14 framebuffer has one extra tile below/right of the camera.
    local camera={x=math.floor((f.minx+f.maxx)/2),y=math.floor((f.miny+f.maxy)/2),z=f.z}
    map:followCreature(nil);map:setCameraPosition(camera);map:setMultifloor(false);map:lockVisibleFloor(message.z)
    map:setVisibleDimension({width=15,height=11});map:setFloorFading(0)
    map:setDrawNames(false);map:setDrawGuildNames(false);map:setDrawHealthBars(false);map:setDrawManaBar(false);map:setDrawTexts(false);map:setDrawLights(false)
    map:setCrosshair('');g_game.getLocalPlayer():setOutfit({type=0,auxType=0,head=0,body=0,legs=0,feet=0,addons=0,mount=0,wings=0,aura=0,shader='',healthBar=0,manaBar=0})
    later(650,function()
      if modules.game_outfit.destroy then modules.game_outfit.destroy(true,true)end
      local f=current.floor
      for _,p in ipairs(f.tiles)do assert(g_map.getTile(p),'missing native house tile '..p.x..','..p.y..','..p.z)end
      local dimensions=map:getVisibleDimension();assert(dimensions.width==15 and dimensions.height==11,'unexpected native projection')
      local file='/accounts-photo-'..message.id..'-'..message.z..'.png'
      g_app.doMapScreenshot(file)
      print('HOUSE_PHOTO_FRAME '..json.encode({file=file,id=message.id,z=message.z,position=camera,dimension=dimensions}))
      if index==1 then g_app.doScreenshot('/accounts-photo-native-render.png')end
      later(200,nextPhoto)
    end)
  end)
  for i,house in ipairs(catalogue)do
    if i>limit then break end
    for _,floor in ipairs(house.floors)do plan[#plan+1]={house=house,floor=floor}end
  end
  connect(g_game,{onLoginError=fail,onConnectionError=fail,onGameStart=function()
    EnterGame.hide();if modules.game_outfit.destroy then modules.game_outfit.destroy(true,true)end
    later(800,nextPhoto)
  end})
  Servers.Default='127.0.0.1:7187:860';EnterGame.onServerChange()
  rootWidget:recursiveGetChildById('rememberPasswordBox'):setChecked(false)
  EnterGame.doLogin('homebuyer','HouseFixtureOnly','','127.0.0.1:7187:860')
  wait('character list',CharacterList.isVisible,function()CharacterList.doLogin()end)
end)
scheduleEvent(function()fail('photograph timeout')end,240000)
