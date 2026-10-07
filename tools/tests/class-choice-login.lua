-- Actual native login/class-choice UI and ordinary native permanent transaction.
-- The runner seeds only loopback disposable GUID9003..9005. No NPC/chat bridge,
-- teleports, native class-grant fixture or production connection is used here.
local phase,tree=PASSIVES_PROBE_CAP,PASSIVES_PROBE_TREE
local ordinary=phase=='ordinary'
local account=phase=='magic'and'passivemagic'or phase=='sword'and'passivelegacy'or'passiveclass'
local character=phase=='magic'and'Passive Mystic'or phase=='sword'and'Passive Veteran'or'Passive Initiate'
local expectedFocus=phase=='magic'and 5 or phase=='sword'and 3 or -1
local classes={'reaver','blademaster','earthshaker','marksman','arcanist','lifekeeper'}
local focusByClass={reaver=2,blademaster=3,earthshaker=1,marksman=4,arcanist=5,lifekeeper=5}
local starterNames={reaver={'Cleaving Arc','Rend'},blademaster={'Focused Thrust','Flurry'},
 earthshaker={'Crushing Blow','Rolling Thunder'},marksman={'Blitzshot','Scattershot'},
 arcanist={'Resonant Burst','Arcane Surge'},lifekeeper={'Mending Thread','Essence Lash'}}
local starterSet={}
for _,names in pairs(starterNames)do for _,name in ipairs(names)do starterSet[name]=true end end
local mod,choice,player,login,nextOnline,metrics,baseline
local sequence,packetSequence,loginStart=0,0,0
local packets={}
local done,failed,intentional=false,false,false
local successfulOffer,successfulRevision

local function fail(reason)
 if done or failed then return end
 failed=true;print('CLASS_CHOICE_LOGIN_FAILED '..phase..' '..tostring(reason))
 if g_game.isOnline()then g_game.talk('/passivepermanent calm');g_game.safeLogout()else g_game.cancelLogin()end
 scheduleEvent(function()g_app.exit()end,500)
end
local function later(ms,fn)
 scheduleEvent(function()
  if done or failed then return end
  local ok,error=pcall(fn);if not ok then fail(error)end
 end,ms)
end
local function wait(label,predicate,fn,ms)
 local deadline=g_clock.millis()+(ms or 15000)
 local function poll()
  if predicate()then fn();return end
  assert(g_clock.millis()<deadline,label..' timeout');later(80,poll)
 end
 later(120,poll)
end
local function visible(widget)return widget and widget:isVisible()or false end
local function state()return choice.getDebugState()end
local function packet(action,payload)
 payload=payload or{};payload.v=1;payload.action=action
 g_game.getProtocolGame():sendExtendedOpcode(103,json.encode(payload))
end
local function count(action,after)
 local total=0
 for index=(after or 0)+1,packetSequence do if packets[index].action==action then total=total+1 end end
 return total
end
local function rejected(after,offer)
 for index=after+1,packetSequence do
  local data=packets[index]
  if data.action=='class_choice_result'and data.offer==offer and data.ok==false then return true end
 end
 return false
end
local function qa(command,fn)
 local before=sequence;g_game.talk('/passivepermanent '..command)
 wait('fixture '..command,function()return sequence>before and metrics.label==command end,function()fn(metrics)end)
end
local function click(widget,label)
 assert(widget and widget:isVisible()and widget:isEnabled(),(label or'widget')..' unavailable')
 signalcall(widget.onClick,widget)
end
local function button(id)click(assert(choice.getWindow()):recursiveGetChildById(id),id)end
local function confirmButton(id)click(assert(choice.getConfirmation()):getChildById(id),id)end
local function equal(a,b)
 if type(a)~=type(b)then return false end
 if type(a)~='table'then return a==b end
 for key,value in pairs(a)do if not equal(value,b[key])then return false end end
 for key in pairs(b)do if a[key]==nil then return false end end
 return true
end
local function treeQuiet(label)
 assert(not visible(mod.getWindow()),label..': passive tree opened automatically')
end
local function allQuiet(label)
 treeQuiet(label)
 assert(not choice.getWindow()and not choice.getConfirmation()and not state().offer,label..': class-choice UI/state survived')
end
local function preserved(m,label,chosen)
 assert(baseline,'Missing preservation baseline')
 for _,key in ipairs({'level','vocation','group','bank','money','hp','maxHP','quest'})do
  assert(m[key]==baseline[key],label..': changed '..key)
 end
 assert(equal(m.progression,baseline.progression),label..': XP/mana/mastery/position/outfit/inventory changed')
 local focus=chosen and(expectedFocus>0 and expectedFocus or focusByClass[tree])or expectedFocus
 assert(m.focus==focus,label..': changed legacy discipline unexpectedly')
 for name,n in pairs(baseline.savedSpells)do
  if not starterSet[name]then assert(m.savedSpells[name]==n,label..': changed legacy spell '..name)end
 end
 for name,n in pairs(m.savedSpells)do
  if not starterSet[name]then assert(baseline.savedSpells[name]==n,label..': added legacy spell '..name)end
 end
 assert(m.learned['Light Healing']and(m.savedSpells['Light Healing']or 0)==1,label..': legacy Light Healing changed')
 for id,names in pairs(starterNames)do for _,name in ipairs(names)do
  local granted=chosen and id==tree
  assert(m.learned[name]==(granted==true)and(m.savedSpells[name]or 0)==(granted and 1 or 0),label..': wrong/duplicate starter '..name)
 end end
 if chosen then
  assert(m.saved.classId==tree and m.saved.respecCount==0,label..': permanent class/respec changed')
  assert(m.profile.active and m.profile.mode=='permanent'and m.profile.treeId==tree and m.profile.classLocked,label..': native permanent profile missing')
  for _,rank in pairs(m.profile.ranks)do assert(rank==0,label..': class selection allocated talent ranks')end
 else assert(not m.saved.classId and not m.profile.active,label..': committed before confirmation')end
end
local function doLogin(fn)
 nextOnline=fn;loginStart=packetSequence;G.account,G.password=account,account
 login=ProtocolLogin.create();_G.classChoiceLoginProbe=login
 login.onLoginError=function(_,error)fail(error)end
 login.onCharacterList=function(_,list)
  for _,entry in ipairs(list)do if entry.name==character then
   assert(entry.worldIp=='127.0.0.1'and entry.worldPort==7175,'Fixture advertised a non-loopback world')
   g_game.loginWorld(account,account,entry.worldName,entry.worldIp,entry.worldPort,entry.name,'','');return
  end end
  fail('Disposable login fixture absent')
 end
 login:login('127.0.0.1',7174,account,account,'',false)
end
local function logout(fn)
 intentional=true;g_game.safeLogout()
 wait('ordinary logout',function()return not g_game.isOnline()end,function()
  assert(not choice.getWindow()and not choice.getConfirmation()and not state().offer,'Class-choice UI/state retained on logout')
  if fn then later(6000,function()doLogin(fn)end)else done=true;print('CLASS_CHOICE_LOGIN_OK '..phase..' tree='..tree);g_app.exit()end
 end)
end
local function inspectOffer(label)
 assert(visible(choice.getWindow())and state().offer and state().stage=='offer',label..': no native automatic offer')
 treeQuiet(label)
 local allowed=0
 local rect=choice.getWindow():getRect()
 for _,id in ipairs(classes)do
  local card=assert(choice.getCard(id),label..': missing '..id)
  local expected=phase=='unfocused'or phase=='magic'and(id=='arcanist'or id=='lifekeeper')or phase=='sword'and id=='blademaster'
  assert(card:isVisible()and card:isEnabled()==expected,label..': incorrect availability '..id)
  local r=card:getRect()
  assert(r.x>=rect.x and r.y>=rect.y and r.x+r.width<=rect.x+rect.width and r.y+r.height<=rect.y+rect.height,label..': clipped card '..id)
  if expected then allowed=allowed+1;click(card,id);assert(state().selectedId==id,'Preview did not select '..id)end
 end
 assert(allowed==(phase=='magic'and 2 or phase=='sword'and 1 or 6),'Wrong number of legacy choices')
 return allowed
end
local function selectConfirm(fn)
 click(choice.getCard(tree),tree);button('chooseButton')
 wait('native confirmation',function()return visible(choice.getConfirmation())and state().stage=='confirmation'and not state().pending end,fn)
end

local function chosenLogin()
 later(2200,function()
  allQuiet('Chosen relogin')
  assert(count('class_choice_offer',loginStart)==0 and count('open',loginStart)==0,'Chosen login received an unsolicited UI request')
  local reopen=mod.getReopenButton();assert(reopen and reopen:isVisible(),'Chosen class lost passive toolbar button')
  qa('state',function(m)
   preserved(m,'Chosen relogin',true)
   packet('class_choice_confirm',{offer=successfulOffer,revision=successfulRevision})
   later(300,function()qa('state',function(after)
    preserved(after,'Committed token after relogin',true);allQuiet('Committed token replay')
    print('CLASS_CHOICE_LOGIN_CHOSEN_QUIET_OK '..phase)
    print('CLASS_CHOICE_LOGIN_PRESERVED_OK '..phase..' xp='..m.progression.experience..' mana='..m.progression.mana..' skillProgress=nonzero inventory=exact')
    g_app.doScreenshot('/class-choice-login-'..phase..'-chosen-quiet.png')
    logout()
   end)end)
  end)
 end)
end
local function commit()
 successfulOffer,successfulRevision=state().offer,state().revision
 assert(successfulOffer and visible(choice.getConfirmation()),'Remote confirmation disappeared')
 confirmButton('confirmButton')
 assert(state().pending=='confirm'and choice.confirm()==false,'Immediate second UI confirmation was not suppressed')
 packet('class_choice_confirm',{offer=successfulOffer,revision=successfulRevision})
 wait('remote native permanent class',function()
  local s=mod.getState();return s.active and s.mode=='permanent'and s.tree and s.tree.id==tree
 end,function()qa('state',function(m)
  preserved(m,'Remote/double confirmation',true)
  assert(not choice.getWindow()and not choice.getConfirmation(),'Successful remote selection left choice windows')
  assert(m.progression.position.z==7,'Remote confirmation moved player to The Nameless')
  print('CLASS_CHOICE_LOGIN_REMOTE_COMMIT_OK '..phase..' templeFloor=7')
  packet('class_choice_select',{offer=successfulOffer,classId=classes[1]})
  packet('class_choice_confirm',{offer=successfulOffer,revision=successfulRevision})
  later(300,function()qa('state',function(after)
   preserved(after,'Duplicate consumed token',true)
   print('CLASS_CHOICE_LOGIN_DOUBLE_COMMIT_OK '..phase..' starters=exactlyTwoOnce')
   logout(chosenLogin)
  end)end)
 end)end)
end
local function combat()
 selectConfirm(function()
  qa('combat',function(m)
   preserved(m,'Entering combat',false)
   local before,offer=packetSequence,state().offer;confirmButton('confirmButton')
   wait('actual combat rejection',function()return rejected(before,offer)end,function()
    qa('state',function(after)
     preserved(after,'Combat rejection',false)
     assert(visible(choice.getConfirmation())and state().offer==offer and not state().pending,'Combat rejection lost retryable remote confirmation')
     qa('calm',function(calm)
      preserved(calm,'Combat cleanup',false);print('CLASS_CHOICE_LOGIN_COMBAT_REJECT_OK '..phase)
      commit()
     end)
    end)
   end)
  end)
 end)
end
local function relogin(oldOffer,oldRevision)
 wait('relogin automatic offer',function()return visible(choice.getWindow())and state().offer end,function()
  assert(state().offer~=oldOffer,'Relogin reused a retired confirmation token')
  assert(count('class_choice_offer',loginStart)==1,'Relogin did not issue exactly one new automatic offer')
  inspectOffer('Unchosen relogin')
  local newOffer=state().offer
  packet('class_choice_confirm',{offer=oldOffer,revision=oldRevision})
  packet('class_choice_select',{offer='forged-login-offer',classId=tree})
  later(300,function()qa('state',function(m)
   preserved(m,'Stale token after relogin',false)
   assert(state().offer==newOffer and not choice.getConfirmation(),'Stale token changed new class-choice UI')
   print('CLASS_CHOICE_LOGIN_RELOGIN_FRESH_TOKEN_OK '..phase)
   combat()
  end)end)
 end)
end
local function reopen()
 local old=state().offer;g_game.talk('!passives')
 wait('ordinary !passives remote choice',function()return visible(choice.getWindow())and state().offer and state().offer~=old end,function()
  inspectOffer('Explicit remote reopen');print('CLASS_CHOICE_LOGIN_REOPEN_OK '..phase)
  selectConfirm(function()
   local offer,revision=state().offer,state().revision
   qa('state',function(m)
    preserved(m,'Pending choice before logout',false)
    logout(function()relogin(offer,revision)end)
   end)
  end)
 end)
end
local function cancelAndRefresh()
 local offer,revision=state().offer,state().revision
 assert(state().confirmFocus=='back','Permanent confirmation did not default to safe Go back')
 signalcall(choice.getConfirmation().onKeyDown,choice.getConfirmation(),KeyEnter,KeyboardNoModifier)
 wait('Enter returns to cards',function()return visible(choice.getWindow())and not choice.getConfirmation()and not state().pending end,function()
  button('cancelButton')
  wait('cancel clears choice',function()return not choice.getWindow()and not state().offer end,function()
   local afterCancel=packetSequence
   packet('class_choice_confirm',{offer=offer,revision=revision})
   packet('snapshot');packet('status')
   later(2200,function()qa('state',function(m)
    preserved(m,'Cancel/status/snapshot/stale confirmation',false);allQuiet('Cancelled choice and background status')
    assert(count('class_choice_offer',afterCancel)==0 and count('open',afterCancel)==0,'Background synchronization reopened cancelled choice/tree')
    print('CLASS_CHOICE_LOGIN_CANCEL_SILENT_OK '..phase)
    reopen()
   end)end)
  end)
 end)
end
local function wrongRevision()
 selectConfirm(function()
  local before,offer=packetSequence,state().offer
  packet('class_choice_confirm',{offer=offer,revision=state().revision+50})
  wait('wrong revision rejection',function()return rejected(before,offer)end,function()qa('state',function(m)
   preserved(m,'Wrong revision',false)
   assert(visible(choice.getConfirmation()),'Stale revision removed current safe confirmation')
   print('CLASS_CHOICE_LOGIN_STALE_CONFIRM_OK '..phase)
   cancelAndRefresh()
  end)end)
 end)
end
local function initial()
 local position=player:getPosition()
 assert(position.x==32097 and position.y==32219 and position.z==7,'Fixture did not login at unrelated temple floor7')
 assert(not mod.getState().active,'Runner did not seed a classless fixture')
 if ordinary then
  later(2200,function()
   allQuiet('Ordinary voc2 login')
   assert(count('class_choice_offer',loginStart)==0 and count('open',loginStart)==0,'Ordinary voc2 login received class-choice/tree offer')
   qa('state',function(m)
    baseline=m;assert(m.vocation==2 and m.group==1 and not m.saved.classId,'Ordinary fixture identity changed')
    packet('snapshot');packet('status');packet('class_choice_select',{offer='forged-login-offer',classId=tree})
    later(300,function()qa('state',function(after)
     preserved(after,'Ordinary classless refresh',false);allQuiet('Ordinary classless refresh')
     print('CLASS_CHOICE_LOGIN_ORDINARY_QUIET_OK vocation=2');logout()
    end)end)
   end)
  end)
  return
 end
 wait('automatic login offer before fixture commands',function()return visible(choice.getWindow())and state().offer end,function()
  assert(count('class_choice_offer',loginStart)==1,'Login did not issue exactly one automatic class-choice offer')
  local allowed=inspectOffer('First login')
  print('CLASS_CHOICE_LOGIN_AUTO_OFFER_OK '..phase..' allowed='..allowed..' templeFloor=7 beforeFixtureCommands=true')
  g_app.doScreenshot('/class-choice-login-'..phase..'-automatic-offer.png')
  -- The first fixture command is read-only, after actual automatic UI proof.
  qa('state',function(m)
   baseline=m
   assert(m.vocation==3 and m.group==1 and m.focus==expectedFocus and m.quest==7,'Wrong ordinary Ascended fixture identity')
   assert(m.progression.experience==988123 and m.progression.manaSpent==321 and m.progression.skills['3'].tries==123,'Preservation seed lacks meaningful XP/mastery progress')
   assert(m.progression.inventory['6'].id==2428 and m.progression.inventory['5'].id==2512 and m.progression.inventory['3'].items[1].count==37,'Preservation seed lacks nonempty possessions/container')
   preserved(m,'First automatic offer/preview',false)
   local offer=state().offer
   packet('class_choice_select',{offer='forged-login-offer',classId=tree})
   if phase~='unfocused'then
    local before=packetSequence;packet('class_choice_select',{offer=offer,classId='reaver'})
    wait('legacy incompatible class rejected',function()return rejected(before,offer)end,function()qa('state',function(after)
     preserved(after,'Forged/incompatible class',false)
     assert(state().offer==offer and not choice.getConfirmation(),'Forged class changed current offer')
     print('CLASS_CHOICE_LOGIN_FORGED_OK '..phase);wrongRevision()
    end)end)
   else later(300,function()qa('state',function(after)
    preserved(after,'Forged offer',false);assert(state().offer==offer and not choice.getConfirmation(),'Forged token changed current offer')
    print('CLASS_CHOICE_LOGIN_FORGED_OK '..phase);wrongRevision()
   end)end)end
  end)
 end)
end

later(250,function()
 assert(LOCAL_PASSIVES_TEST==true and Services.updater==''and g_resources.getLayout()=='retro','Isolated retro test profile required')
 assert(phase=='ordinary'or phase=='magic'or phase=='sword'or phase=='unfocused','Unknown login-choice phase')
 mod=assert(modules.game_passives);choice=assert(mod.getClassChoice())
 g_settings.set('window-maximized',false);g_window.resize({width=1280,height=800})
 ProtocolGame.registerExtendedJSONOpcode(103,function(_,_,data)
  if data.action then
   packetSequence=packetSequence+1;packets[packetSequence]=data
   if data.action:find('^class_choice_')then print('CLASS_CHOICE_LOGIN_PACKET '..json.encode(data))end
  end
 end)
 connect(g_game,{
  onTextMessage=function(_,text)
   local raw=text:match('^PASSIVE_PERMANENT_STATE (.+)$');if raw then metrics=json.decode(raw);sequence=sequence+1 end
   if text:find('PASSIVES_PERMANENT_FIXTURE_FAILED',1,true)then fail(text)end
  end,
  onGameStart=function()
   EnterGame.hide();player=assert(g_game.getLocalPlayer());intentional=false
   local fn=nextOnline;nextOnline=nil
   wait('actual capable handshake',function()return mod.getState().ready end,function()later(350,fn)end)
  end,
  onConnectionError=function(error)if not intentional then fail(error)end end,
  onLoginError=function(error)fail(error)end,
 })
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 doLogin(initial)
end)
scheduleEvent(function()if not done then fail('180-second login-choice probe timeout')end end,180000)
