-- Ordinary GUID9002 actual native client: NPC chat and page Use are real packets.
local account=LEGENDARY_NATIVE_PEER_ACCOUNT or 'passivepeer'
local password=LEGENDARY_NATIVE_PEER_PASSWORD or account
local done,failed,intentional,ack=false,false,false,false
local phase,login
local milestones={}
local function notify(text)if g_game.isOnline()then g_game.talkPrivate(MessageModes.PrivateTo,'Passive Tester',text)end end
local function fail(reason)
 if done or failed then return end;failed=true
 print('FORGOTTEN_QUEST_PEER_FAILED '..tostring(reason));g_game.cancelAttack()
 notify('FORGOTTEN_QUEST_PEER_FAILED '..tostring(reason))
 -- Stay online briefly so the issuer's cleanup can restore this disposable peer.
 scheduleEvent(function()if g_game.isOnline()then intentional=true;g_game.safeLogout()end;g_app.exit()end,2500)
end
local function guarded(fn)if done or failed then return end;local ok,why=pcall(fn);if not ok then fail(why)end end
local function later(ms,fn)scheduleEvent(function()guarded(fn)end,ms)end
local function wait(label,predicate,nextStep,timeout)
 local deadline=g_clock.millis()+(timeout or 15000)
 local function poll()
  local value=predicate();if value then nextStep(value);return end
  assert(g_clock.millis()<deadline,label..' timeout');later(80,poll)
 end
 later(80,poll)
end
local function mark(name)
 if milestones[name]then return end;milestones[name]=true
 print('FORGOTTEN_QUEST_MILESTONE '..name);notify('FORGOTTEN_QUEST_MILESTONE '..name)
end
local function ask(nextPhase,delay,greet)
 phase=nextPhase
 later(delay or 0,function()
  if greet then g_game.talk('hi');later(1100,function()g_game.talkChannel(MessageModes.NpcTo,0,'forgotten works')end)
  else g_game.talkChannel(MessageModes.NpcTo,0,'forgotten works')end
 end)
end
local function pageUse(row)
 phase='page'
 assert(row.nativeBackpackVerified==true,'Native seeded page must be inside the owned backpack')
 local bag=g_game.getLocalPlayer():getInventoryItem(InventorySlotBack)
 assert(bag and bag:getId()==row.bagClientId,'Actual quest bag absent')
 g_game.open(bag)
 wait('actual recovered page native container',function()
  for _,container in pairs(g_game.getContainers())do
   for _,item in ipairs(container:getItems())do if item:getId()==row.pageClientId then return item end end
  end
 end,function(item)g_game.use(item)end)
end
local function ready()
 if ack or done or failed then return end
 notify('FORGOTTEN_QUEST_PEER_READY');later(1500,ready)
end
later(300,function()
 assert(LOCAL_PASSIVES_TEST==true and Services.updater=='' and DEFAULT_SERVER_ENDPOINT=='127.0.0.1:7174:860'
  and g_resources.getLayout()=='retro','Requires isolated local retro peer profile')
 connect(g_game,{
  onGameStart=function()guarded(function()
   assert(g_game.getLocalPlayer():getName()=='Passive Peer','Wrong ordinary identity');EnterGame.hide();ready()
  end)end,
  onGameEnd=function()if not intentional and not failed then fail('Unexpected ordinary peer logout')end end,
  onDeath=function()fail('Unexpected ordinary quest peer death')end,
  onConnectionError=function(e)if not intentional then fail(e)end end,onLoginError=fail,
  onTalk=function(name,_,mode,text)guarded(function()
   if name=='Passive Tester' and(mode==MessageModes.PrivateFrom or mode==MessageModes.GamemasterPrivateFrom)then
    if text=='FORGOTTEN_QUEST_CONTROLLER_READY'then ack=true
    elseif text=='FORGOTTEN_QUEST_TEMPERING'then
     phase='tempering';later(19000,function()g_game.talkChannel(MessageModes.NpcTo,0,'tempering')end)
    end
   elseif name=='Bolgrim'then
    print('FORGOTTEN_QUEST_ACTUAL_NPC '..json.encode({phase=phase,mode=mode,text=text}))
    local low=text:lower()
    if phase=='unascended' and low:find('ascend first',1,true)then mark('unascended')
    elseif phase=='accept' and low:find('old mould went missing',1,true)then mark('accepted')
    elseif phase=='foreign' and low:find('no mould, no old craft',1,true)then mark('foreign')
    elseif phase=='return' and low:find('forgotten works are open',1,true)then mark('returned')
    elseif phase=='tempering' and low:find('a core remembers honest battle',1,true)then
     later(9500,function()
      if FORGOTTEN_QUEST_QA_SCREENSHOT then g_app.doScreenshot(FORGOTTEN_QUEST_QA_SCREENSHOT)end
      mark('tempering')
     end)
    end
   end
  end)end,
  onTextMessage=function(_,text)
   if text:match('^FORGOTTEN_QUEST_QA ')then print(text)end
   guarded(function()
    if phase=='page' and text:find('You study the recovered page',1,true)then mark('read');return end
    local raw=text:match('^FORGOTTEN_QUEST_QA (.+)$');if not raw then return end
    local row=json.decode(raw)
    if row.label=='prepared'then ask('unascended',350,true)
    elseif row.label=='ascended_setup'then ask('accept',500,false)
    elseif row.label=='foreign_setup'then ask('foreign',10000,false)
    elseif row.label=='hunt_ready'then
     phase='hunt';assert(row.actualNativeWorldSpawn and not row.syntheticDamage,'Artificial hunt target')
     wait('real mapped authored dwarf',function()return g_map.getCreatureById(row.targetId)end,
      function(target)g_game.attack(target)end)
    elseif row.label=='natural_drop'then g_game.cancelAttack()
    elseif row.label=='collected'then ask('return',350,true)
    elseif row.label=='page_ready'then pageUse(row)
    elseif row.label=='FAILED' or row.label=='RESTORE_UNCONFIRMED'then error(row.error or row.label)
    elseif row.label=='cleanup'then
     intentional=true;done=true;notify('FORGOTTEN_QUEST_PEER_CLEAN')
     local complete=true
     for _,name in ipairs({'unascended','accepted','foreign','returned','read','tempering'})do if not milestones[name]then complete=false end end
     if complete then
      print('FORGOTTEN_QUEST_PEER_OK '..json.encode({actualNativeNpcLines=true,actualPaidWorldAttack=true,actualPageUse=true,seededPageFrequencyUnmeasured=true}))
     else print('FORGOTTEN_QUEST_PEER_CLEANUP_ONLY '..json.encode({milestones=milestones,complete=false}))end
     scheduleEvent(function()g_game.safeLogout();scheduleEvent(function()g_app.exit()end,500)end,300)
    end
   end)
  end,
 })
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 G.account,G.password=account,password
 login=ProtocolLogin.create();_G.forgottenQuestPeerLogin=login
 login.onLoginError=function(_,e)fail(e)end
 login.onCharacterList=function(_,list)guarded(function()
  for _,c in ipairs(list)do if c.name=='Passive Peer'then
   assert(c.worldIp=='127.0.0.1'and c.worldPort==7175,'Non-loopback peer world')
   g_game.loginWorld(account,password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return
  end end;error('Disposable ordinary peer absent')
 end)end
 login:login('127.0.0.1',7174,account,password,'',false)
end)
scheduleEvent(function()if not done then fail('240-second ordinary quest timeout')end end,240000)
