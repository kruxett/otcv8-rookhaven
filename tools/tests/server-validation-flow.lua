-- Actual shipped 8.60 emitters, owned loopback GUID9001 only.
local done,failed,finishing=false,false,false
local rows,speech,packets={},{},{}
local phase,login,world,player,prepared=0
local originalOpcode
local function fail(reason)
 if failed or done then return end
 failed=true;print('SERVER_VALIDATION_FLOW_CLIENT_FAILED '..tostring(reason))
 if g_game.isOnline() then g_game.cancelAttack();g_game.talk('/validationflow cleanup');g_game.safeLogout() end
 if originalOpcode then ProtocolGame.onExtendedOpcode=originalOpcode end
 scheduleEvent(function()g_app.exit()end,1500)
end
local function later(ms,fn)
 scheduleEvent(function()
  if failed or done then return end
  local ok,reason=xpcall(fn,debug.traceback);if not ok then fail(reason) end
 end,ms)
end
local function wait(label,predicate,nextStep,timeout)
 local deadline=g_clock.millis()+(timeout or 15000)
 local function poll()
  local result=predicate();if result then nextStep(result);return end
  assert(g_clock.millis()<deadline,label..' timeout');later(75,poll)
 end
 later(75,poll)
end
local function row(label,after)
 for n=#rows,(after or 0)+1,-1 do if rows[n].label==label then return rows[n] end end
end
local function command(verb,label,nextStep)
 local before=#rows;g_game.talk('/validationflow '..verb)
 wait(label,function()return row(label,before)end,nextStep or function()end)
end
local function container(clientId)
 for id,c in pairs(g_game.getContainers()) do if c:getContainerItem():getId()==clientId then return {id=id,value=c} end end
end
local function loginWorld()
 finishing=false
 g_game.loginWorld(G.account,G.password,world.worldName,'127.0.0.1',SERVER_VALIDATION_PROXY and 7176 or 7175,world.name,'','')
end
local function finish()
 command('finish','complete',function(result)
  assert(result.checks>=10 and result.restored and result.nativeProtocol and row('cleanup'),'Incomplete flow restoration')
  local calibration=assert(row('calibration'))
  assert(calibration.zeroLegitimateRejects and calibration.belowQuarterCapacity,'Calibration headroom failed')
  finishing=true;g_game.safeLogout()
  wait('restored final logout',function()return not g_game.isOnline()end,function()
   done=true
   if originalOpcode then ProtocolGame.onExtendedOpcode=originalOpcode end
   print('SERVER_VALIDATION_FLOW_CLIENT_OK '..json.encode({checks=result.checks,connections=phase,
    rttMs=SERVER_VALIDATION_RTT or 0,actual860Emitters=true,calibration=calibration}))
   scheduleEvent(function()g_app.exit()end,700)
  end)
 end)
end
local function reconnect(force)
 command('reconnect_ready','reconnect_ready',function()
  finishing=true
  if force then g_game.forceLogout() else g_game.safeLogout() end
  wait('transport logout',function()return not g_game.isOnline()end,function()later(1300,loginWorld)end)
 end)
end
local function windows()
 local counts={};for opcode,list in pairs(packets)do counts[opcode]=#list end
 modules.game_guild.toggle()
 modules.game_shop.check();modules.game_shop.show()
 local cy=assert(modules.game_cyclopedia.Cyclopedia)
 modules.game_cyclopedia.show('character')
 cy.sendCyclopediaRequest('character.baseInfo','')
 cy.sendCyclopediaRequest('character.combatStats','')
 cy.sendCyclopediaRequest('bestiary.categories','')
 cy.sendCyclopediaRequest('bestiary.tracker','list')
 command('windows','windows_ready',function()
  wait('normal guild/shop/task/cyclopedia replies',function()
   for _,opcode in ipairs({95,101,201,31})do if not packets[opcode] or #packets[opcode]<=(counts[opcode] or 0)then return false end end
   return true
  end,function()
   local taskWindow=g_ui.getRootWidget():recursiveGetChildById('taskBoardWindow')
   assert(taskWindow and taskWindow:isVisible(),'Actual Task Board did not open')
   signalcall(taskWindow:recursiveGetChildById('refreshButton').onClick)
   modules.game_shop.showHistory(true)
   wait('passive status negotiation',function()return modules.game_passives.getState().ready end,function()
    later(1200,function()reconnect(true)end)
   end)
  end)
 end)
end
local function spellAndNpc()
 g_game.cancelAttack();g_game.cancelFollow()
 g_game.requestChannels();g_game.requestOutfit()
 g_game.changeOutfit(player:getOutfit());g_game.partyShareExperience(true)
 g_game.talk('A quiet test of the ordinary chat channel.')
 local before=#speech;g_game.talkChannel(MessageModes.NpcTo,0,'hi')
 wait('actual NPC greeting',function()
  for n=before+1,#speech do if speech[n].name=='Samwell' then return true end end
 end,function()
  g_game.talkChannel(MessageModes.NpcTo,0,'bye')
  command('light_begin','light_ready',function()
   g_game.talk('utevo lux');g_game.talk('utevo lux')
   later(1200,function()command('light_check','spell_runtime',windows)end)
  end)
 end)
end
local function combat()
 local target=assert(g_map.getCreatureById(prepared.monster),'Actual fixture monster absent from client')
 g_game.setChaseMode(DontChase);g_game.setFightMode(FightBalanced);g_game.setSafeFight(true)
 g_game.attack(target)
 command('attack','attack',function()
  g_game.follow(target)
  command('follow','follow',spellAndNpc)
 end)
end
local function inventory()
 local bag=assert(player:getInventoryItem(InventorySlotBack),'Actual carried backpack missing')
 assert(bag:getId()==prepared.bagClientId,'Wrong native bag');g_game.look(bag);g_game.use(bag)
 wait('native outer bag open',function()return container(prepared.bagClientId)end,function(outer)
  command('container '..outer.id,'container',function()
   local inner
   for _,item in ipairs(outer.value:getItems())do if item:getId()==prepared.innerClientId then inner=item end end
   assert(inner,'Native inner bag missing');g_game.use(inner)
   wait('native nested bag open',function()return container(prepared.innerClientId)end,function(opened)
    command('container '..opened.id,'container',combat)
   end)
  end)
 end)
end
local function begin(rowData)
 prepared=rowData;assert(prepared.ordinaryGroup==1,'Fixture needs ordinary group')
 g_game.walk(East)
 later(650,function()command('walk','walk',function()
  local steps=0
  local function onStep() steps=steps+1 end
  connect(player,{onPositionChange=onStep})
  g_game.autoWalk({West,East,West},player:getPosition())
  wait('three native autowalk steps',function()
   local pos=player:getPosition()
   return steps>=3 and pos.x==prepared.source.x and pos.y==prepared.source.y and pos.z==prepared.source.z
  end,function()
   disconnect(player,{onPositionChange=onStep})
   command('autowalk','autowalk',inventory)
  end)
 end)end)
end
later(200,function()
 assert(LOCAL_PASSIVES_TEST and Services.updater=='' and g_resources.getLayout()=='retro','Owned local QA client required')
 originalOpcode=assert(ProtocolGame.onExtendedOpcode)
 ProtocolGame.onExtendedOpcode=function(protocol,opcode,buffer)
  originalOpcode(protocol,opcode,buffer)
  if protocol==g_game.getProtocolGame()then
   packets[opcode]=packets[opcode] or {};packets[opcode][#packets[opcode]+1]=true
  end
 end
 connect(g_game,{
  onGameStart=function()later(450,function()
   phase=phase+1;EnterGame.hide();player=assert(g_game.getLocalPlayer())
   if phase==1 then command('prepare','prepared',begin)
   elseif phase==2 then command('reconnected','reconnected',function()reconnect(false)end)
   elseif phase==3 then command('reconnected','reconnected',finish)
   else error('Unexpected extra connection') end
  end)end,
  onTalk=function(name,level,mode,text) speech[#speech+1]={name=name,mode=mode} end,
  onTextMessage=function(_,text)
   local raw=text:match('^SERVER_VALIDATION_FLOW (.+)$');if not raw then return end
   local ok,reason=xpcall(function()
    local receipt=json.decode(raw);print(text)
    if receipt.label=='FAILED'then error(receipt.error or 'Native flow failed')end
    rows[#rows+1]=receipt
   end,debug.traceback)
   if not ok then fail(reason)end
  end,
  onConnectionError=function(reason)if not finishing then fail(reason)end end,
 })
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 G.account='passivetest';G.password='passivetest'
 login=ProtocolLogin.create();_G.serverValidationFlowLogin=login
 login.onLoginError=function(_,reason)fail(reason)end
 login.onCharacterList=function(_,list)
  for _,entry in ipairs(list)do if entry.name=='Passive Tester'then
   assert(entry.worldIp=='127.0.0.1' and entry.worldPort==7175,'Non-loopback game world')
   world=entry;loginWorld();return
  end end
  fail('Owned GUID9001 character absent')
 end
 login:login('127.0.0.1',7174,G.account,G.password,'',false)
end)
scheduleEvent(function()if not done then fail('native flow probe timeout')end end,110000)
