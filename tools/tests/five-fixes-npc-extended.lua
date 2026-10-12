-- Actual Say/NpcTo and production opcode93 processing against an owned loopback runtime.
local done,failed,finishing=false,false,false
local rows,opcodes,speech={},{},{}
local originalOpcode
local function fail(reason)
 if done or failed then return end
 failed=true;print('FIVE_FIXES_NPC_EXTENDED_FAILED '..tostring(reason))
 if g_game.isOnline() then g_game.talk('/fivenpcqa cleanup');g_game.safeLogout() end
 if originalOpcode then ProtocolGame.onExtendedOpcode=originalOpcode end
 scheduleEvent(function()g_app.exit()end,800)
end
local function later(ms,fn)
 scheduleEvent(function()
  if done or failed then return end
  local ok,reason=xpcall(fn,debug.traceback);if not ok then fail(reason) end
 end,ms)
end
local function wait(label,fn,nextStep,timeout)
 local deadline=g_clock.millis()+(timeout or 10000)
 local function poll()
  local value=fn();if value then nextStep(value);return end
  assert(g_clock.millis()<deadline,label..' timeout');later(70,poll)
 end
 later(70,poll)
end
local function row(label,index)
 for n=#rows,1,-1 do if rows[n].label==label and (not index or rows[n].index==index) then return rows[n] end end
end
local function opcodeAfter(index,action)
 for n=index+1,#opcodes do if opcodes[n].action==action then return opcodes[n] end end
end
local function send(payload) assert(g_game.getProtocolGame()):sendExtendedOpcode(93,json.encode(payload)) end
local function confirm(path) send({action='confirm',path=path,selectedAffixId=0,corruptedInvestCount=0}) end
local function command(verb) g_game.talk('/fivenpcqa '..verb) end
local function npcUpgrade() g_game.talkChannel(MessageModes.NpcTo,0,'upgrade') end
local function lifetime(stage)
 local started=g_clock.millis()
 for _,ms in ipairs({60000,120000,180000,240000,295000}) do
  later(ms,function()
   local before=#opcodes;send({action='refresh'})
   wait('real live default session refresh',function()return opcodeAfter(before,'open')end,function(payload)
    assert(payload.openMode=='no_wand','Default session category changed');command('refresh')
   end)
  end)
 end
 later(303000,function()
  assert(g_clock.millis()-started>=300000,'Full default lifetime was shortened')
  local before=#opcodes;confirm(stage.path)
  wait('expired real confirm packet',function()return opcodeAfter(before,'result')end,function(result)
   assert(result.success==false,'Expired actual confirmation was accepted')
   command('expired')
   wait('server default lifetime evidence',function()return row('complete')end,function(receipt)
    assert(receipt.actualDefaultLifetime and receipt.allThreePrivateNpcDialogues and receipt.checks>=15,'Incomplete extended NPC native coverage')
    assert(row('cleanup') and row('default_300s_expired'),'Owned NPC cleanup or actual expiration receipt missing')
    finishing=true;g_game.safeLogout()
    wait('NPC profile logout',function()return not g_game.isOnline()end,function()
     ProtocolGame.onExtendedOpcode=originalOpcode;done=true
     print('FIVE_FIXES_NPC_EXTENDED_OK '..json.encode(receipt));scheduleEvent(function()g_app.exit()end,400)
    end)
   end)
  end)
 end)
end
local beginStage
local function openPermitted(stage)
 command('permit')
 wait('NPC Rite preparation',function()return row('permitted',stage.index)end,function()
  local before=#opcodes;npcUpgrade()
  wait('actual NPC callback opener',function()return opcodeAfter(before,'open')end,function(payload)
   assert(payload.openMode==stage.mode,'Actual NPC callback category differs')
   local selected
   for _,entry in ipairs(payload.items or {}) do if entry.itemId==stage.itemId and entry.currentTier=='common' then selected=entry end end
   assert(selected and selected.path==stage.path,'Actual private NPC window donor missing')
   command('opened')
   wait('native station identity',function()return row('opened',stage.index)end,function(receipt)
    assert(receipt.ordinaryGroup==1 and receipt.npcName==stage.npcName,'Ordinary NPC context differs')
    if stage.index==4 then lifetime(stage);return end
    local previous=#opcodes;confirm(selected.path)
    wait('actual valid confirm packet',function()return opcodeAfter(previous,'result')end,function(result)
     assert(result.success==true,'Real NPC/confirm upgrade failed: '..tostring(result.message))
     command('upgraded')
     wait('native upgrade/cost evidence',function()return row('upgraded',stage.index)end,function()
      beginStage(stage.index+1)
     end)
    end)
   end)
  end)
 end)
end
beginStage=function(index)
 command('stage '..index)
 wait('native NPC stage',function()return row('stage',index)end,function(stage)
  local beforeSpeech=#speech;g_game.talk('hi')
  wait('actual NPC greeting',function()
   for n=beforeSpeech+1,#speech do if speech[n].name==stage.npcName and speech[n].mode==MessageModes.NpcFrom then return true end end
  end,function()
   later(650,function()
    local before=#opcodes;local beforeReply=#speech;npcUpgrade()
    wait('actual private Rite denial',function()
     for n=beforeReply+1,#speech do if speech[n].name==stage.npcName and speech[n].mode==MessageModes.NpcFrom then return speech[n] end end
    end,function()
     assert(not opcodeAfter(before,'open'),'Incomplete Rite opened actual NPC forge')
     send({action='refresh'})
     wait('denied actual refresh',function()return opcodeAfter(before,'result')end,function(result)
      assert(result.success==false,'Client refresh manufactured a station session');command('denied')
      wait('native denied resource evidence',function()return row('rite_denied',index)end,function()openPermitted(stage)end)
     end)
    end)
   end)
  end)
 end)
end
later(200,function()
 assert(LOCAL_PASSIVES_TEST and Services.updater=='' and g_resources.getLayout()=='retro','Owned local retro probe required')
 originalOpcode=assert(ProtocolGame.onExtendedOpcode)
 ProtocolGame.onExtendedOpcode=function(protocol,opcode,buffer)
  originalOpcode(protocol,opcode,buffer)
  if opcode==93 and protocol==g_game.getProtocolGame() then
   local ok,payload=pcall(json.decode,buffer);if ok and type(payload)=='table' then opcodes[#opcodes+1]=payload end
  end
 end
 connect(g_game,{
  onGameStart=function()later(350,function()
   EnterGame.hide();g_game.cancelAttack();command('prepare')
   wait('owned NPC prepare',function()return row('prepared')end,function(receipt)
    assert(receipt.defaultLifetimeSeconds==300 and receipt.ordinaryGroup==1,'NPC default/ordinary setup differs');beginStage(1)
   end)
  end)end,
  onTalk=function(name,level,mode,text,channelId,pos) speech[#speech+1]={name=name,mode=mode,text=text} end,
  onTextMessage=function(_,text)
   local raw=text:match('^FIVE_FIXES_NPC_EXTENDED (.+)$');if not raw then return end
   local ok,reason=xpcall(function()
    local receipt=json.decode(raw);print(text);if receipt.label=='FAILED' then error(receipt.error) end
    rows[#rows+1]=receipt
   end,debug.traceback);if not ok then fail(reason) end
  end,
  onConnectionError=function(reason)if not finishing then fail(reason) end end,
 })
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 G.account='passivetest';G.password='passivetest'
 local login=ProtocolLogin.create();_G.fiveFixesNpcExtendedLogin=login
 login.onLoginError=function(_,reason)fail(reason) end
 login.onCharacterList=function(_,list)
  for _,c in ipairs(list) do if c.name=='Passive Tester' then
   assert(c.worldIp=='127.0.0.1' and c.worldPort==7175,'Non-loopback NPC world')
   g_game.loginWorld(G.account,G.password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return
  end end
  fail('Owned NPC character missing')
 end
 login:login('127.0.0.1',7174,G.account,G.password,'',false)
end)
scheduleEvent(function()if not done then fail('Extended native NPC probe timeout') end end,385000)
