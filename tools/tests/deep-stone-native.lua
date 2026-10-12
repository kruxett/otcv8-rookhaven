-- Actual 8.60 client, real Eldric dialogue and the real small stone chest on the
-- loopback-only fixture. Reads the native quest log after every quest step.
local failed,finished=false,false
local speech,receipts,texts,evidence={},{},{},{}
local questLog,questLines=nil,{}
local QUEST='The Deep Stone'
local function fail(err)
 if failed or finished then return end;failed=true;print('DEEP_STONE_NATIVE_FAILED '..tostring(err))
 if g_game.isOnline()then g_game.talk('/deepstoneqa cleanup')end
 scheduleEvent(function()g_app.exit()end,1000)
end
local function later(ms,fn)
 scheduleEvent(function()if failed or finished then return end;local ok,e=xpcall(fn,debug.traceback);if not ok then fail(e)end end,ms)
end
local function wait(label,fn,nextStep,timeout)
 local untilAt=g_clock.millis()+(timeout or 10000)
 local function poll()
  local result=fn();if result then nextStep(result);return end
  assert(g_clock.millis()<untilAt,label..' timeout');later(80,poll)
 end
 later(80,poll)
end
local function command(mode,label,fn)
 local previous=receipts[label];g_game.talk('/deepstoneqa '..mode)
 wait(label,function()return receipts[label]~=previous and receipts[label]end,fn)
end
local function say(text)g_game.talkChannel(MessageModes.NpcTo,0,text)end
local function spoken(part,after)
 for i=(after or 0)+1,#speech do if speech[i].text:find(part,1,true)then return i end end
end
-- Eldric locks input while a multi-line reply is still being spoken.
local function reply(label,part,after,nextStep)
 wait(label,function()return spoken(part,after)end,function()later(1500,nextStep)end,40000)
end
local function journal(label,expected,nextStep)
 questLog=nil;g_game.requestQuestLog()
 wait(label..' quest log',function()return questLog end,function(quests)
  local entry
  for _,quest in ipairs(quests)do local id,name,completed=unpack(quest);if name==QUEST then entry={id=id,completed=completed==true or completed==1}end end
  if not expected then assert(not entry,label..': quest listed before it was accepted');evidence[label]={listed=false};nextStep();return end
  assert(entry,label..': quest missing from the log')
  assert(entry.completed==expected.completed,label..': quest completed flag is '..tostring(entry.completed))
  questLines[entry.id]=nil;g_game.requestQuestLine(entry.id)
  wait(label..' quest line',function()return questLines[entry.id]end,function(missions)
   local names={}
   for i,mission in ipairs(missions)do
    local name,description=unpack(mission);names[i]=name
    local want=expected.missions[i];assert(want,label..': unexpected mission '..name)
    assert(name==want[1],label..': mission '..i..' is "'..name..'"')
    assert(description:find(want[2],1,true),label..': mission '..i..' description is "'..description..'"')
   end
   assert(#missions==#expected.missions,label..': '..#missions..' missions shown')
   evidence[label]={completed=entry.completed,missions=names};nextStep()
  end)
 end)
end
local function storage(label,expected,nextStep)
 command('state','state',function(state)
  for key,value in pairs(expected)do assert(state[key]==value,label..': '..key..' is '..tostring(state[key]))end
  nextStep()
 end)
end
local function useChest(moved)
 local pos=moved.chestPos;local tile=g_map.getTile({x=pos.x,y=pos.y,z=pos.z});assert(tile,'Actual chest tile not visible')
 for _,thing in ipairs(tile:getThings())do if thing:isItem()and thing:getId()==moved.chestClientId then g_game.use(thing);return end end
 error('Actual chest item not visible')
end
local function finish()
 command('cleanup','cleaned',function(receipt)
  assert(receipt.restored);finished=true;g_game.safeLogout()
  scheduleEvent(function()print('DEEP_STONE_NATIVE_OK '..json.encode(evidence));g_app.exit()end,1000)
 end)
end
local function returned()
 storage('returned',{accepted=1,stone=1,returned=1,progress=3,spell=true},function()
  journal('returned',{completed=true,missions={
   {'Venture into the deep (completed)','You ventured into the deep mines'},
   {'The ancient stone (completed)','You returned the ancient stone to Eldric.'},
   {'The bonding ritual (completed)',"Eldric taught you the spell 'Imbue Stone'"}}},finish)
 end)
end
local function deliver()
 command('back','moved',function()
  local first=#speech;later(800,function()g_game.talk('hi')end)
  reply('stone greeting','understand what lies beneath Rookhaven',first,function()
   say('stone')
   reply('stone return','ask and I will guide you',first,returned)
  end)
 end)
end
local function found(moved)
 storage('found',{accepted=1,stone=1,returned=-1,progress=2,stones=1},function()
  journal('found',{completed=false,missions={
   {'Venture into the deep (completed)','You ventured into the deep mines'},
   {'The ancient stone','Return it to Eldric to learn what comes next.'}}},function()
   local before=#texts;useChest(moved)
   wait('empty chest',function()for i=before+1,#texts do if texts[i]=='It is empty.'then return true end end end,function()
    storage('second use',{stone=1,progress=2,stones=1},function()evidence.chestOnce=true;deliver()end)
   end)
  end)
 end)
end
local function chest()
 command('chest','moved',function(moved)
  later(1200,function()
   local before=#texts;useChest(moved)
   wait('stone found',function()for i=before+1,#texts do if texts[i]=='You have found an ancient small stone.'then return true end end end,function()found(moved)end)
  end)
 end)
end
local function accepted()
 storage('accepted',{accepted=1,stone=-1,returned=-1,progress=1,stones=0},function()
  journal('accepted',{completed=false,missions={{'Venture into the deep','Eldric challenged you to venture into the deep mines'}}},function()
   local first=#speech;say('bye')
   reply('farewell','Go carefully.',first,function()
    g_game.talk('hi')
    reply('on quest greeting','Did you find the stone I asked for?',first,chest)
   end)
  end)
 end)
end
local function begin()
 command('setup','ready',function(ready)
  evidence.npc=ready.npcName
  storage('fresh',{accepted=-1,stone=-1,returned=-1,progress=-1},function()
   journal('fresh',nil,function()
    local first=#speech;g_game.talk('hi')
    reply('greeting','Keep offering mana to the stone',first,function()
     say('ascension')
     reply('offer','Will you accept this trial?',first,function()
      say('yes')
      reply('accept','May your path stay true.',first,accepted)
     end)
    end)
   end)
  end)
 end)
end
later(250,function()
 assert(LOCAL_PASSIVES_TEST and Services.updater=='','Loopback-only probe')
 connect(g_game,{
  onGameStart=function()later(500,function()EnterGame.hide();g_game.cancelAttack();begin()end)end,
  onTalk=function(name,level,mode,text)
   if mode==MessageModes.NpcFrom or mode==MessageModes.NpcFromStartBlock then
    speech[#speech+1]={name=name,text=text,at=g_clock.millis()};print('DEEP_STONE_SPEECH '..text)
   end
  end,
  onQuestLog=function(quests)questLog=quests end,
  onQuestLine=function(questId,missions)questLines[questId]=missions end,
  onTextMessage=function(_,text)
   local raw=text:match('^DEEP_STONE_QA (.+)$')
   if not raw then texts[#texts+1]=text;return end
   local r=json.decode(raw);print(text);if r.label=='FAILED'then fail(r.reason)else receipts[r.label]=r end
  end,
  onConnectionError=function(err)if not finished then fail(err)end end
 })
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 G.account='passivetest';G.password='passivetest'
 local login=ProtocolLogin.create();_G.deepStoneLogin=login
 login.onLoginError=function(_,err)fail(err)end
 login.onCharacterList=function(_,list)
  for _,c in ipairs(list)do if c.name=='Passive Tester'then
   assert(c.worldIp=='127.0.0.1'and c.worldPort==7175,'Unexpected deep stone test world')
   g_game.loginWorld(G.account,G.password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return
  end end
  fail('Owned actor absent')
 end
 login:login('127.0.0.1',7174,G.account,G.password,'',false)
end)
scheduleEvent(function()if not finished then fail('200-second native deep stone timeout')end end,200000)
