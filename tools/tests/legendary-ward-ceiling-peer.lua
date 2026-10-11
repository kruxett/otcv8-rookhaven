-- Genuine ordinary peer. Native server schedules paid weapon attacks; this
-- client supplies the real party join packet and observes exact fixture cleanup.
local account=LEGENDARY_NATIVE_PEER_ACCOUNT or'passivepeer';local password=LEGENDARY_NATIVE_PEER_PASSWORD or account
local failed,done,intentional,ack=false,false,false,false
local login,joining,joined=nil,false,false
local function notify(text)if g_game.isOnline()then g_game.talkPrivate(MessageModes.PrivateTo,'Passive Tester',text)end end
local function fail(why)
 if failed or done then return end;failed=true;print('LEGENDARY_WARD_CEILING_PEER_FAILED '..tostring(why));notify('LEGENDARY_WARD_CEILING_PEER_FAILED '..tostring(why))
 scheduleEvent(function()intentional=true;if g_game.isOnline()then g_game.safeLogout()end;g_app.exit()end,2500)
end
local function guarded(fn)if failed or done then return end;local ok,why=pcall(fn);if not ok then fail(why)end end
local function later(ms,fn)scheduleEvent(function()guarded(fn)end,ms)end
local function announce()
 if ack then return end
 -- The real module sends hello after 500ms. Advertise readiness only after
 -- its real server acknowledgement; never inject a capability/ward packet.
 local module=modules.game_passives
 if module and module.getState and module.getState().ready==true then notify('LEGENDARY_WARD_CEILING_PEER_READY')end
 later(500,announce)
end
local function join()
 if joined then return end
 if not joining then for _,p in ipairs(g_map.getSpectators(g_game.getLocalPlayer():getPosition(),false))do
  if p:getName()=='Passive Tester'then joining=true;g_game.partyJoin(p:getId());later(1300,function()joining=false end);break end
 end end
 later(750,join)
end
later(300,function()
 assert(LOCAL_PASSIVES_TEST and Services.updater==''and DEFAULT_SERVER_ENDPOINT=='127.0.0.1:7174:860'and g_resources.getLayout()=='retro')
 connect(g_game,{
  onGameStart=function()guarded(function()assert(g_game.getLocalPlayer():getName()=='Passive Peer');EnterGame.hide();announce();later(1000,join)end)end,
  onGameEnd=function()if not intentional and not failed then fail('Unexpected peer logout')end end,
  onDeath=function()fail('Unexpected ordinary peer death')end,
  onConnectionError=function(why)if not intentional then fail(why)end end,onLoginError=fail,
  onTalk=function(name,_,mode,text)guarded(function()
   if name=='Passive Tester'and(mode==MessageModes.PrivateFrom or mode==MessageModes.GamemasterPrivateFrom)and text=='LEGENDARY_WARD_CEILING_CONTROLLER_READY'then ack=true end
  end)end,
  onTextMessage=function(_,text)guarded(function()
   local raw=text:match('^LEGENDARY_WARD_CEILING_QA (.+)$');if not raw then return end;local row=json.decode(raw);print(text)
   if row.label=='FAILED'or row.label=='RESTORE_UNCONFIRMED'then error(row.error or row.label)
   elseif row.label=='party'and row.ready then joined=true
   elseif row.label=='cleanup'then
    intentional=true;notify('LEGENDARY_WARD_CEILING_PEER_CLEAN');done=true
    print('LEGENDARY_WARD_CEILING_PEER_OK actualNativeParty=true actualServerReceipt=true')
    scheduleEvent(function()g_game.safeLogout();scheduleEvent(function()g_app.exit()end,500)end,300)
   end
  end)end,
 })
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 G.account,G.password=account,password;login=ProtocolLogin.create();_G.legendaryWardCeilingPeerLogin=login
 login.onLoginError=function(_,why)fail(why)end
 login.onCharacterList=function(_,list)guarded(function()
  for _,c in ipairs(list)do if c.name=='Passive Peer'then assert(c.worldIp=='127.0.0.1'and c.worldPort==7175);g_game.loginWorld(account,password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return end end
  error('Owned ordinary peer absent')
 end)end
 login:login('127.0.0.1',7174,account,password,'',false)
end)
scheduleEvent(function()if not done then fail('160-second shared ward peer deadline')end end,160000)
