-- Actual 8.60 client and loopback-only NPC fixture. No live commands.
local failed,finished=false,false
local speech,receipts,evidence={},{},{}
local tradeOpened=false
local function fail(err)
 if failed or finished then return end;failed=true;print('NPC_DIALOG_NATIVE_FAILED '..tostring(err))
 if g_game.isOnline()then g_game.talk('/dialogqa cleanup')end
 scheduleEvent(function()g_app.exit()end,1000)
end
local function later(ms,fn)
 scheduleEvent(function()if failed or finished then return end;local ok,e=xpcall(fn,debug.traceback);if not ok then fail(e)end end,ms)
end
local function wait(label,fn,nextStep)
 local untilAt=g_clock.millis()+10000
 local function poll()
  local result=fn();if result then nextStep(result);return end
  assert(g_clock.millis()<untilAt,label..' timeout');later(80,poll)
 end
 later(80,poll)
end
local function command(mode,label,fn)
 local previous=receipts[label];g_game.talk('/dialogqa '..mode)
 wait(label,function()return receipts[label]~=previous and receipts[label]end,fn)
end
local function say(text)g_game.talkChannel(MessageModes.NpcTo,0,text)end
local function rows(prefix,after)
 local found={};for i=(after or 0)+1,#speech do if speech[i].text:sub(1,#prefix)==prefix then found[#found+1]=speech[i]end end;return found
end
local function pacing(values,ms)
 for i=2,#values do local gap=values[i].at-values[i-1].at;assert(math.abs(gap-ms)<1100,'Actual NPC pacing changed: '..gap)end
end
local function finish()
 command('cleanup','cleaned',function(receipt)
  assert(receipt.restored);finished=true;g_game.safeLogout()
  scheduleEvent(function()print('NPC_DIALOG_NATIVE_OK '..json.encode(evidence));g_app.exit()end,1000)
 end)
end
local function realNpc()
 command('real','ready',function(ready)
  local first=#speech;g_game.talk('hi')
  wait('Torvind greeting',function()for i=first+1,#speech do if speech[i].name==ready.npcName then return true end end end,function()
   later(1800,function()
    local start=#speech;say('explain')
    for _,ms in ipairs({8000,24000,30000,35000})do later(ms,function()say(ms%16000==0 and 'hi'or 'hello')end)end
    later(39000,function()
     local expected={'Of course!','Slay the required','Every kill counts','The ranks are:','Each new rank','Normally you may','If a task'}
     local messages={}
     for _,prefix in ipairs(expected)do local got=rows(prefix,start);assert(#got==1,'Torvind missing/repeated line '..prefix);messages[#messages+1]=got[1]end
     pacing(messages,6000);evidence.torvind={lines=#messages,greetingSpam=true};finish()
    end)
   end)
  end)
 end)
end
local function emotes()
 command('emote','ready',function()
  local first=#speech;g_game.talk('hi');later(2000,function()say('hello')end);later(5200,function()say('hi')end)
  later(10000,function()
   local got=rows('QAEMOTE',first);assert(#got==2,'Emote greeting interrupted/restarted');pacing(got,3000)
   evidence.emote={spokenLines=2,interval=got[2].at-got[1].at}
   first=#speech;say('hi')
   later(4300,function()
    command('walk','moved',function()
     local before=#rows('QAEMOTE',first)
     later(4500,function()
      assert(#rows('QAEMOTE',first)==before,'Emote continued after walking away')
      command('back','moved',function()
       local again=#speech;g_game.talk('hi')
       later(8500,function()assert(#rows('QAEMOTE',again)==2,'Walk-away left stale greeting lock');evidence.walkAway=true;realNpc()end)
      end)
     end)
    end)
   end)
  end)
 end)
end
local function shop()
 local first=#speech;say('trade')
 later(7500,function()say('hello');say('ping')end)
 later(15000,function()
  local got=rows('QASHOP',first);assert(#got==3 and tradeOpened,'Actual shop response/window failed')
  pacing(got,6000);assert(#rows('QAPONG',first)==0,'Shop lock bypassed');evidence.shop=true
  g_game.closeNpcTrade();later(1300,emotes)
 end)
end
local function question()
 local first=#speech;say('question')
 later(1600,function()say('yes')end);later(8000,function()say('hello');say('ping')end)
 later(15000,function()
  assert(#rows('QAASK',first)==3 and #rows('QAACCEPTED',first)==0 and #rows('QAPONG',first)==0,'Early input interrupted question')
  say('yes');wait('answer after complete question',function()return #rows('QAACCEPTED',first)==1 end,function()evidence.question=true;later(500,shop)end)
 end)
end
local function begin()
 command('plain','ready',function()
  local first=#speech;g_game.talk('hi')
  for _,ms in ipairs({1500,7300,11000})do later(ms,function()say('hi');say('hello');say('ping')end)end
  later(15000,function()
   local got=rows('QAPLAIN',first);assert(#got==3,'Plain greeting interrupted/restarted');pacing(got,6000)
   assert(#rows('QAPONG',first)==0,'Registered keyword bypassed native input lock');evidence.plain={lines=3}
   say('ping');wait('keyword after greeting',function()return #rows('QAPONG',first)==1 end,function()later(500,question)end)
  end)
 end)
end
later(250,function()
 assert(LOCAL_PASSIVES_TEST and Services.updater=='','Loopback-only probe')
 connect(g_game,{
  onGameStart=function()later(500,function()EnterGame.hide();g_game.cancelAttack();begin()end)end,
  onTalk=function(name,level,mode,text)
   if mode==MessageModes.NpcFrom or mode==MessageModes.NpcFromStartBlock then
    speech[#speech+1]={name=name,text=text,at=g_clock.millis()};print('NPC_DIALOG_SPEECH '..text)
   end
  end,
  onOpenNpcTrade=function()tradeOpened=true end,
  onTextMessage=function(_,text)
   local raw=text:match('^NPC_DIALOG_QA (.+)$');if not raw then return end
   local r=json.decode(raw);print(text);if r.label=='FAILED'then fail(r.reason)else receipts[r.label]=r end
  end,
  onConnectionError=function(err)if not finished then fail(err)end end
 })
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 G.account='passivetest';G.password='passivetest'
 local login=ProtocolLogin.create();_G.npcDialogLogin=login
 login.onLoginError=function(_,err)fail(err)end
 login.onCharacterList=function(_,list)
  for _,c in ipairs(list)do if c.name=='Passive Tester'then
   assert(c.worldIp=='127.0.0.1'and c.worldPort==7175,'Unexpected NPC test world')
   g_game.loginWorld(G.account,G.password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return
  end end
  fail('Owned actor absent')
 end
 login:login('127.0.0.1',7174,G.account,G.password,'',false)
end)
scheduleEvent(function()if not finished then fail('160-second native dialogue timeout')end end,160000)
