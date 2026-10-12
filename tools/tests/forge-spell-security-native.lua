-- Connected loopback GUID9001 probe. The server fixture restores its own state.
-- Real Use packets open carried/map bags; source spell callbacks use native combat.
local done,failed,finishing=false,false,false
local login,player
local rows={}
local function fail(reason)
 if failed or done then return end
 failed=true;print('FORGE_SPELL_SECURITY_NATIVE_FAILED '..tostring(reason))
 if g_game.isOnline() then g_game.cancelAttack();g_game.talk('/forgespellqa cleanup');g_game.safeLogout() end
 scheduleEvent(function()g_app.exit()end,800)
end
local function later(ms,fn)
 scheduleEvent(function()
  if failed or done then return end
  local okay,reason=xpcall(fn,debug.traceback);if not okay then fail(reason)end
 end,ms)
end
local function wait(label,predicate,nextStep,timeout)
 local deadline=g_clock.millis()+(timeout or 10000)
 local function poll()
  local value=predicate();if value then nextStep(value);return end
  assert(g_clock.millis()<deadline,label..' timeout');later(70,poll)
 end
 later(70,poll)
end
local function latest(label)
 for n=#rows,1,-1 do if rows[n].label==label then return rows[n]end end
end
local function containerAfter(previous,clientId)
 for id,c in pairs(g_game.getContainers())do
  if not previous[id] and c:getContainerItem():getId()==clientId then return id end
 end
end
local function ids()
 local result={};for id in pairs(g_game.getContainers())do result[id]=true end;return result
end
local function openGround(row,carried)
 local previous=ids();local tile=assert(g_map.getTile(row.groundPos),'Actual map fixture tile missing')
 local bag
 for _,i in ipairs(tile:getItems())do if i:getId()==row.groundBagClientId then bag=i end end
 assert(bag,'Actual map fixture bag missing');g_game.use(bag)
 wait('actual open map container',function()return containerAfter(previous,row.groundBagClientId)end,function(ground)
  assert(carried~=ground,'Map and carried container addresses alias')
  g_game.talk('/forgespellqa containers '..carried..' '..ground)
  wait('native measured spell/forge receipts',function()return latest('complete')end,function(result)
   assert(result.checks>=15 and result.actualNativeCombat and result.actualNativeContainers,'Incomplete native security fixture receipt')
   assert(latest('cleanup') and latest('soul_real_four_second_callback'),'Native owned cleanup/real callback missing')
   finishing=true;g_game.safeLogout()
   wait('ordinary profile logout',function()return not g_game.isOnline()end,function()
    done=true;print('FORGE_SPELL_SECURITY_NATIVE_OK '..json.encode(result));scheduleEvent(function()g_app.exit()end,400)
   end)
  end,22000)
 end)
end
local function prepared(row)
 assert(row.ordinaryGroup==1 and row.nativeInventory,'Fixture did not enter ordinary native behavior')
 local previous=ids();local bag=assert(player:getInventoryItem(3),'Actual carried fixture backpack missing')
 assert(bag:getId()==row.bagClientId,'Actual carried fixture backpack differs');g_game.use(bag)
 wait('actual open carried container',function()return containerAfter(previous,row.bagClientId)end,function(id)openGround(row,id)end)
end
later(200,function()
 assert(LOCAL_PASSIVES_TEST and Services.updater=='' and g_resources.getLayout()=='retro','Owned local native client required')
 connect(g_game,{
  onGameStart=function()later(350,function()
   EnterGame.hide();player=assert(g_game.getLocalPlayer());g_game.cancelAttack()
   g_game.talk('/forgespellqa prepare')
   wait('strict native fixture prepare',function()return latest('prepared')end,prepared)
  end)end,
  onTextMessage=function(_,text)
   local raw=text:match('^FORGE_SPELL_SECURITY_NATIVE (.+)$');if not raw then return end
   local okay,reason=xpcall(function()
    local row=json.decode(raw);print(text)
    if row.label=='FAILED'then error(row.error or 'Native server fixture failed')end
    rows[#rows+1]=row
   end,debug.traceback)
   if not okay then fail(reason)end
  end,
  onConnectionError=function(reason)if not finishing then fail(reason)end end,
 })
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 G.account='passivetest';G.password='passivetest'
 login=ProtocolLogin.create();_G.forgeSpellSecurityLogin=login
 login.onLoginError=function(_,reason)fail(reason)end
 login.onCharacterList=function(_,list)
  for _,c in ipairs(list)do if c.name=='Passive Tester'then
   assert(c.worldIp=='127.0.0.1' and c.worldPort==7175,'Non-loopback game world')
   g_game.loginWorld(G.account,G.password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return
  end end
  fail('Disposable GUID9001 fixture character missing')
 end
 login:login('127.0.0.1',7174,G.account,G.password,'',false)
end)
scheduleEvent(function()if not done then fail('native security probe timeout')end end,60000)
