-- Isolated paired client: real native party/Heal Friend packets, no ward injection.
local account=LEGENDARY_NATIVE_ACCOUNT or'passivetest';local password=LEGENDARY_NATIVE_PASSWORD or account
local failed,done,finishing,ready,prepared,peerDone,runRequested=false,false,false,false,false,false,false
local receipts,login={},nil
local function fail(why)
 if failed or done then return end;failed=true;print('LEGENDARY_WARD_CEILING_NATIVE_FAILED '..tostring(why))
 if g_game.isOnline()then if prepared then g_game.talk('/legendarywardceilingqa cleanup')end;scheduleEvent(function()g_game.safeLogout()end,700)end
 scheduleEvent(function()g_app.exit()end,1700)
end
local function guarded(fn)if failed or done then return end;local ok,why=pcall(fn);if not ok then fail(why)end end
local function later(ms,fn)scheduleEvent(function()guarded(fn)end,ms)end
local function wait(label,predicate,nextStep,timeout)
 local deadline=g_clock.millis()+(timeout or 20000)
 local function poll()if predicate()then nextStep();return end;assert(g_clock.millis()<deadline,label..' timeout');later(80,poll)end
 later(80,poll)
end
local function command(text)g_game.talk('/legendarywardceilingqa '..text)end
local function passiveClientReady()
 local module=modules.game_passives
 return module and module.getState and module.getState().ready==true
end
local function join()
 if runRequested then return end
 for _,p in ipairs(g_map.getSpectators(g_game.getLocalPlayer():getPosition(),false))do if p:getName()=='Passive Peer'then g_game.partyInvite(p:getId())end end
 command('party')
end
later(300,function()
 assert(LOCAL_PASSIVES_TEST and Services.updater==''and DEFAULT_SERVER_ENDPOINT=='127.0.0.1:7174:860'and g_resources.getLayout()=='retro')
 connect(g_game,{
  onGameStart=function()later(300,function()
   assert(g_game.getLocalPlayer():getName()=='Passive Tester');EnterGame.hide()
   wait('actual passive capability acknowledgement',passiveClientReady,function()
   wait('ordinary peer capability acknowledgement',function()return ready end,function()
    g_game.talkPrivate(MessageModes.PrivateTo,'Passive Peer','LEGENDARY_WARD_CEILING_CONTROLLER_READY');command('prepare Passive Peer')
   end,50000)
   end,15000)
  end)end,
  onGameEnd=function()if not finishing and not failed then fail('Unexpected controller logout')end end,
  onConnectionError=function(why)if not finishing then fail(why)end end,onLoginError=fail,
  onTalk=function(name,_,mode,text)guarded(function()
   if name~='Passive Peer'or mode~=MessageModes.PrivateFrom then return end
   if text=='LEGENDARY_WARD_CEILING_PEER_READY'then ready=true
   elseif text=='LEGENDARY_WARD_CEILING_PEER_CLEAN'then peerDone=true
   elseif text:match('^LEGENDARY_WARD_CEILING_PEER_FAILED')then error(text)end
  end)end,
  onTextMessage=function(_,text)guarded(function()
   local raw=text:match('^LEGENDARY_WARD_CEILING_QA (.+)$');if not raw then return end
   local row=json.decode(raw);print(text);receipts[row.label]=row
   if row.label=='FAILED'or row.label=='RESTORE_UNCONFIRMED'then error(row.error or row.label)
   elseif row.label=='prepared'then
    prepared=true;assert(row.actualClientCapabilities and row.normalPaidCaster and row.actualAegisPreset and row.peerMaxHP==150 and row.ceiling==15);later(400,join)
   elseif row.label=='party'then
    if row.ready and not runRequested then runRequested=true;command('run')elseif not runRequested then later(900,join)end
   elseif row.label=='heal'then assert(row.paidGroup==1 and row.manaBefore>=140);g_game.talk(row.words)
   elseif row.label=='passive_first'then assert(row.aegis==12 and row.bark==3 and row.total==15 and row.manaPaid>0)
   elseif row.label=='legendary_first'then assert(row.aegis==3 and row.bark==12 and row.total==15 and row.manaPaid>0)
   elseif row.label=='done'then
    assert(receipts.passive_first and receipts.legendary_first and receipts.absorption and receipts.source_cleanup and row.independentSourceCleanup)
    later(200,function()command('cleanup')end)
   elseif row.label=='cleanup'then
    assert(row.groupAccountHPManaPositionRestored and row.ownedGearRemoved);prepared=false
    wait('ordinary peer cleanup',function()return peerDone end,function()
     finishing=true;g_game.safeLogout();wait('controller logout',function()return not g_game.isOnline()end,function()
      done=true;print('LEGENDARY_WARD_CEILING_NATIVE_OK '..json.encode({bothGrantOrders=true,realPaidHealAndAttack=true,aggregate15=true,independentSourceCleanup=true,
       unmeasured='Stonebond unchanged old gate; native skill/mana spent requires outer DB restore'}));g_app.exit()
     end)
    end)
   end
  end)end,
 })
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 G.account,G.password=account,password;login=ProtocolLogin.create();_G.legendaryWardCeilingLogin=login
 login.onLoginError=function(_,why)fail(why)end
 login.onCharacterList=function(_,list)guarded(function()
  for _,c in ipairs(list)do if c.name=='Passive Tester'then assert(c.worldIp=='127.0.0.1'and c.worldPort==7175);g_game.loginWorld(account,password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return end end
  error('Owned controller absent')
 end)end
 login:login('127.0.0.1',7174,account,password,'',false)
end)
scheduleEvent(function()if not done then fail('150-second shared ward deadline')end end,150000)
