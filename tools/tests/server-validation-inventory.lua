-- Owned loopback client probe; server fixture restores all temporary inventory.
local done,failed,finishing=false,false,false
local rows,login,player={}
local function fail(reason)
 if failed or done then return end
 failed=true;print('SERVER_VALIDATION_INVENTORY_CLIENT_FAILED '..tostring(reason))
 if g_game.isOnline() then g_game.talk('/validationinventory cleanup');g_game.safeLogout() end
 scheduleEvent(function()g_app.exit()end,900)
end
local function later(ms,fn)
 scheduleEvent(function()
  if failed or done then return end
  local ok,reason=xpcall(fn,debug.traceback);if not ok then fail(reason) end
 end,ms)
end
local function latest(label)
 for n=#rows,1,-1 do if rows[n].label==label then return rows[n] end end
end
local function wait(label,predicate,nextStep)
 local deadline=g_clock.millis()+15000
 local function poll()
  local result=predicate();if result then nextStep(result);return end
  assert(g_clock.millis()<deadline,label..' timeout');later(80,poll)
 end
 later(80,poll)
end
later(200,function()
 assert(LOCAL_PASSIVES_TEST and Services.updater=='' and g_resources.getLayout()=='retro','Owned loopback client required')
 connect(g_game,{
  onGameStart=function()later(400,function()
   EnterGame.hide();player=assert(g_game.getLocalPlayer());g_game.cancelAttack()
   g_game.talk('/validationinventory prepare')
   wait('native inventory prepare',function()return latest('prepared')end,function(row)
    assert(row.ordinaryGroup==1 and row.checks>=13,'Incomplete ordinary inventory checks')
    local bag=assert(player:getInventoryItem(3))
    assert(bag:getId()==row.bagClientId,'Fixture backpack missing in actual client')
    g_game.use(bag)
    wait('real carried container',function()
     for id,c in pairs(g_game.getContainers())do
      if c:getContainerItem():getId()==row.bagClientId then return {id=id} end
     end
    end,function(opened)
     g_game.talk('/validationinventory container '..opened.id)
     wait('all native inventory receipts',function()return latest('complete')end,function(result)
      assert(result.checks>=16 and result.nativeInventory and result.restored and latest('cleanup'),'Incomplete native results/restoration')
      finishing=true;g_game.safeLogout()
      wait('ordinary logout',function()return not g_game.isOnline()end,function()
       done=true;print('SERVER_VALIDATION_INVENTORY_CLIENT_OK '..json.encode(result))
       scheduleEvent(function()g_app.exit()end,500)
      end)
     end)
    end)
   end)
  end)end,
  onTextMessage=function(_,text)
   local raw=text:match('^SERVER_VALIDATION_INVENTORY (.+)$');if not raw then return end
   local ok,reason=xpcall(function()
    local row=json.decode(raw);print(text)
    if row.label=='FAILED'then error(row.error or 'Native fixture failed')end
    rows[#rows+1]=row
   end,debug.traceback)
   if not ok then fail(reason)end
  end,
  onConnectionError=function(reason)if not finishing then fail(reason)end end,
 })
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 G.account='passivetest';G.password='passivetest'
 login=ProtocolLogin.create();_G.serverValidationInventoryLogin=login
 login.onLoginError=function(_,reason)fail(reason)end
 login.onCharacterList=function(_,list)
  for _,c in ipairs(list)do if c.name=='Passive Tester'then
   assert(c.worldIp=='127.0.0.1' and c.worldPort==7175,'Non-loopback game world')
   g_game.loginWorld(G.account,G.password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return
  end end
  fail('Disposable fixture character missing')
 end
 login:login('127.0.0.1',7174,G.account,G.password,'',false)
end)
scheduleEvent(function()if not done then fail('native inventory probe timeout')end end,60000)
