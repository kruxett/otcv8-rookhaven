-- Real native retro client + authoritative Nameless UI; disposable GUID9003..9005.
local phase, tree = PASSIVES_PROBE_CAP, PASSIVES_PROBE_TREE
local fresh = phase == 'fresh'
local account = fresh and 'passiveclass' or phase == 'magic' and 'passivemagic' or 'passivelegacy'
local character = fresh and 'Passive Initiate' or phase == 'magic' and 'Passive Mystic' or 'Passive Veteran'
local mod, choice, player, login, nextOnline, metrics
local sequence, packetSequence = 0, 0
local done, failed, intentional = false, false, false
local packets = {}
local classes = {'reaver','blademaster','earthshaker','marksman','arcanist','lifekeeper'}
local starterNames = {reaver={'Cleaving Arc','Rend'},blademaster={'Focused Thrust','Flurry'},
 earthshaker={'Crushing Blow','Rolling Thunder'},marksman={'Blitzshot','Scattershot'},
 arcanist={'Resonant Burst','Arcane Surge'},lifekeeper={'Mending Thread','Essence Lash'}}
local function fail(reason)
 if done or failed then return end
 failed=true;print('CLASS_CHOICE_FAILED '..tostring(reason))
 if g_game.isOnline() then g_game.talk('/passivepermanent calm');g_game.safeLogout() else g_game.cancelLogin() end
 scheduleEvent(function()g_app.exit()end,500)
end
local function later(ms,fn)
 scheduleEvent(function()if done or failed then return end;local ok,e=pcall(fn);if not ok then fail(e)end end,ms)
end
local function wait(label,predicate,fn,ms)
 local deadline=g_clock.millis()+(ms or 15000)
 local function poll()if predicate()then fn();return end;assert(g_clock.millis()<deadline,label..' timeout');later(80,poll)end
 later(120,poll)
end
local function state()return choice.getDebugState()end
local function qa(command,fn)
 local before=sequence;g_game.talk('/passivepermanent '..command)
 wait('fixture '..command,function()return sequence>before and metrics.label==command end,function()fn(metrics)end)
end
local function packet(action,payload)
 payload=payload or {};payload.v=1;payload.action=action
 g_game.getProtocolGame():sendExtendedOpcode(103,json.encode(payload))
end
local function click(widget,label)
 assert(widget and widget:isVisible()and widget:isEnabled(),(label or 'widget')..' unavailable')
 signalcall(widget.onClick,widget)
end
local function windowButton(id)click(assert(choice.getWindow()):recursiveGetChildById(id),id)end
local function confirmButton(id)click(assert(choice.getConfirmation()):getChildById(id),id)end
local function unchosen(m,label)
 assert(m.level==40 and m.vocation==(fresh and 2 or 3)and not m.saved.classId,label..' changed class/progression')
 assert(m.quest==7 and m.learned['Light Healing'],'Quest or legacy learning changed at '..label)
 for _,names in pairs(starterNames)do for _,name in ipairs(names)do
  assert(not m.learned[name]and (m.savedSpells[name]or 0)==0,'Starter grant before confirmation '..label)
 end end
 if fresh then assert(player:getInventoryItem(InventorySlotLeft)and player:getInventoryItem(InventorySlotRight),'Preview/cancel moved possessions '..label)end
end
local function chosen(m)
 assert(m.group==1 and m.vocation==3 and m.saved.classId==tree,'Incorrect chosen ordinary class')
 assert(m.level==(fresh and 1 or 40),'Wrong fresh/legacy level consequence')
 assert(m.focus==(tree=='reaver'and 2 or tree=='blademaster'and 3 or 5),'Wrong discipline focus')
 assert(m.learned['Light Healing'],'Lost legacy learning')
 for id,names in pairs(starterNames)do for _,name in ipairs(names)do
  assert(m.learned[name]==(id==tree)and (m.savedSpells[name]or 0)==(id==tree and 1 or 0),'Wrong or duplicate starter entitlement '..name)
 end end
 if fresh then
  assert(m.quest==8 and player:getMaxMana()==0,'Fresh reset quest/mana incorrect')
  assert(not player:getInventoryItem(InventorySlotLeft)and not player:getInventoryItem(InventorySlotRight),'Ascension did not move equipped possessions')
 end
end
local function doLogin(fn)
 nextOnline=fn;G.account,G.password=account,account
 login=ProtocolLogin.create();_G.classChoiceLogin=login
 login.onLoginError=function(_,e)fail(e)end
 login.onCharacterList=function(_,list)
  for _,c in ipairs(list)do if c.name==character then g_game.loginWorld(account,account,c.worldName,c.worldIp,c.worldPort,c.name,'','');return end end
  fail('Choice fixture absent')
 end
 login:login('127.0.0.1',7174,account,account,'',false)
end
local function inside(widget,rect)
 local r=widget:getRect()
 return widget:isVisible()and r.x>=rect.x and r.y>=rect.y and r.x+r.width<=rect.x+rect.width and r.y+r.height<=rect.y+rect.height
end
local function openOffer(fn)
 local previous=state().offer
 qa('npc',function()g_game.talkChannel(MessageModes.NpcTo,0,'bye')
  later(750,function()g_game.talkChannel(MessageModes.NpcTo,0,'hi')
   wait('new server NPC offer',function()return state().offer and state().offer~=previous and choice.getWindow()and choice.getWindow():isVisible()end,fn)
  end)
 end)
end
local function review(fn)
 local w=assert(choice.getWindow());local count=0
 for _,id in ipairs(classes)do
  local card=assert(choice.getCard(id),'Missing class card '..id)
  assert(inside(card,w:getRect()),'Card clipped '..id)
  local allowed=fresh or phase=='magic'and(id=='arcanist'or id=='lifekeeper')or phase=='sword'and id=='blademaster'
  assert(card:isEnabled()==allowed,'Wrong legacy availability '..id)
  if allowed then click(card,id);count=count+1;assert(state().selectedId==id,'Card did not select '..id)end
 end
 assert(count==(fresh and 6 or phase=='magic'and 2 or 1),'Wrong selectable class count')
 qa('state',function(m)unchosen(m,'six-card browsing')
  later(300,function()
   g_app.doScreenshot('/class-choice-'..phase..'-large.png')
   g_window.resize({width=800,height=640})
   later(350,function()
    assert(inside(w,g_ui.getRootWidget():getRect()),'800x640 class window clipped')
    for _,id in ipairs(classes)do assert(inside(choice.getCard(id),w:getRect()),'800x640 card clipped '..id)end
    for _,id in ipairs({'chooseButton','cancelButton'})do assert(inside(w:recursiveGetChildById(id),w:getRect()),'800x640 action clipped '..id)end
    g_app.doScreenshot('/class-choice-'..phase..'-small.png');print('CLASS_CHOICE_VISUAL_OK '..phase..' allowed='..count);fn()
   end)
  end)
 end)
end
local function selectConfirm(fn)
 click(choice.getCard(tree),tree);windowButton('chooseButton')
 wait('server-backed confirm',function()return choice.getConfirmation()and choice.getConfirmation():isVisible()and state().revision end,function()
  local box=choice.getConfirmation();assert(inside(box,g_ui.getRootWidget():getRect()),'Confirm window clipped')
  assert(inside(box:getChildById('confirmButton'),box:getRect()),'Confirm action clipped')
  later(250,function()g_app.doScreenshot('/class-choice-'..phase..'-confirm.png');fn()end)
 end)
end
local successOffer,successRevision
local function finishAfterLogin()
 qa('state',function(m)chosen(m)
  assert(not choice.getWindow()and not choice.getConfirmation(),'Choice windows survived selection/logout')
  packet('class_choice_confirm',{offer=successOffer,revision=successRevision})
  later(300,function()qa('state',function(after)chosen(after)
   print('CLASS_CHOICE_REPLAY_AFTER_COMMIT_OK '..phase)
   intentional=true;g_game.safeLogout()
   wait('final logout',function()return not g_game.isOnline()end,function()
    assert(not choice.getWindow()and not choice.getConfirmation()and not state().offer,'Choice state survived logout')
    done=true;print('CLASS_CHOICE_OK '..phase);g_app.exit()
   end)
  end)end)
 end)
end
local function commit()
 openOffer(function()selectConfirm(function()
  successOffer,successRevision=state().offer,state().revision
  intentional=fresh
  confirmButton('confirmButton')
  if fresh then
   wait('real third-ascension kick',function()return not g_game.isOnline()end,function()later(6000,function()doLogin(finishAfterLogin)end)end)
  else
   wait('legacy permanent class',function()return mod.getState().active and mod.getState().mode=='permanent'and mod.getState().tree.id==tree end,function()
    qa('state',function(m)chosen(m);intentional=true;g_game.safeLogout()
     wait('legacy relog',function()return not g_game.isOnline()end,function()later(6000,function()doLogin(finishAfterLogin)end)end)
    end)
   end)
  end
 end)end)
end
local function expire()
 if not fresh then commit();return end
 openOffer(function()
  local stale=state().offer
  wait('server offer expiry',function()return not choice.getWindow()end,function()
   later(1500,function()packet('class_choice_select',{offer=stale,classId=tree})
    later(250,function()qa('state',function(m)unchosen(m,'expired offer');print('CLASS_CHOICE_EXPIRY_OK');commit()end)end)
   end)
  end,65000)
 end)
end
local function combat()
 openOffer(function()selectConfirm(function()
  qa('combat',function()
   local before=packetSequence;confirmButton('confirmButton')
   wait('combat rejection',function()
    for i=before+1,packetSequence do if packets[i].action=='class_choice_close'or packets[i].action=='class_choice_result'and packets[i].ok==false then return true end end
    return false
   end,function()qa('state',function(m)unchosen(m,'combat rejection')
    qa('calm',function()print('CLASS_CHOICE_COMBAT_OK');expire()end)
   end)end)
  end)
 end)end)
end
local function walkAway()
 openOffer(function()local stale=state().offer
  qa('temple',function()wait('walkaway closes UI',function()return not choice.getWindow()end,function()
   packet('class_choice_select',{offer=stale,classId=tree})
   later(200,function()qa('state',function(m)unchosen(m,'remote old offer');print('CLASS_CHOICE_REMOTE_OK');combat()end)end)
  end)end)
 end)
end
local function reconnect()
 openOffer(function()selectConfirm(function()
  local stale,revision=state().offer,state().revision
  qa('armdetach',function()
   intentional=true;g_game.getProtocolGame():disconnect();g_game.forceLogout()
   wait('preview TCP logout',function()return not g_game.isOnline()end,function()
    assert(not choice.getWindow()and not choice.getConfirmation()and not state().offer,'Preview retained on TCP logout')
    later(6000,function()doLogin(function()
     packet('class_choice_confirm',{offer=stale,revision=revision})
     later(250,function()qa('state',function(m)
      unchosen(m,'old confirmation after reconnect')
      local observed=assert(m.observed.detach,'Missing detached-object observation')
      assert(observed.onlineEntity and observed.sameEntity and observed.ip==0,'Expected retained entity before reconnect')
      print('CLASS_CHOICE_RETAINED_RECONNECT_OK '..phase);walkAway()
     end)end)
    end)end)
   end)
  end)
 end)end)
end
local function cancelAndReplay()
 selectConfirm(function()
  local stale,revision=state().offer,state().revision
  -- Even an exact copy of the reserved bridge message sent as ordinary NPC
  -- chat cannot authorize the prepared permanent choice.
  g_game.talkChannel(MessageModes.NpcTo,0,'__rookhaven_class_choice_ui__')
  later(200,function()qa('state',function(m)
  unchosen(m,'raw reserved NPC message');print('CLASS_CHOICE_RAW_NPC_GUARD_OK '..phase)
  local before=packetSequence
  packet('class_choice_confirm',{offer=stale,revision=revision+50})
  wait('stale revision rejected',function()
   for i=before+1,packetSequence do if packets[i].action=='class_choice_result'and packets[i].ok==false then return true end end
   return false
  end,function()qa('state',function(m)unchosen(m,'wrong revision')
   -- Reopen if the server closed the rejected offer; otherwise go back through
   -- the real confirmation button before cancelling the entire window.
   local function cancel()
    windowButton('cancelButton');wait('cancel clears UI',function()return not choice.getWindow()end,function()
     packet('class_choice_confirm',{offer=stale,revision=revision})
     later(250,function()qa('state',function(after)unchosen(after,'cancel and replay');print('CLASS_CHOICE_CANCEL_REPLAY_OK');reconnect()end)end)
    end)
   end
   if choice.getConfirmation()then
    assert(state().confirmFocus=='back','Permanent confirmation did not default to Go back')
    signalcall(choice.getConfirmation().onKeyDown,choice.getConfirmation(),KeyEnter,KeyboardNoModifier)
    wait('Enter safely returns to cards',function()return not choice.getConfirmation()and not state().pending end,cancel)
   elseif choice.getWindow()then cancel()else openOffer(cancel)end
  end)end)
  end)end)
 end)
end
local function initial()
 assert(not mod.getState().active,'Runner failed to seed classless fixture')
 local function start()openOffer(function()review(function()
  local before=packetSequence
  packet('class_choice_select',{offer='invented-offer',classId=tree})
  if not fresh then packet('class_choice_select',{offer=state().offer,classId='reaver'})end
  later(250,function()qa('state',function(m)unchosen(m,'forged or incompatible choice')
   print('CLASS_CHOICE_FORGED_OK '..phase);cancelAndReplay()
  end)end)
 end)end)end
 qa('calm',function()if fresh then qa('equip',start)else start()end end)
end
later(250,function()
 assert(LOCAL_PASSIVES_TEST and Services.updater==''and g_resources.getLayout()=='retro')
 mod=assert(modules.game_passives);choice=assert(mod.getClassChoice())
 g_settings.set('window-maximized',false);g_window.resize({width=1280,height=800})
 ProtocolGame.registerExtendedJSONOpcode(103,function(_,_,data)
  if data.action and data.action:find('^class_choice_')then packetSequence=packetSequence+1;packets[packetSequence]=data;print('CLASS_CHOICE_PACKET '..json.encode(data))end
 end)
 connect(g_game,{
  onTextMessage=function(_,text)
   local raw=text:match('^PASSIVE_PERMANENT_STATE (.+)$');if raw then metrics=json.decode(raw);sequence=sequence+1 end
   if text:find('PASSIVES_PERMANENT_FIXTURE_FAILED',1,true)then fail(text)end
  end,
  onGameStart=function()
   EnterGame.hide();player=assert(g_game.getLocalPlayer());intentional=false
   local fn=nextOnline;nextOnline=nil
   wait('capable handshake',function()return mod.getState().ready end,function()later(350,fn)end)
  end,
  onConnectionError=function(e)if not intentional then fail(e)end end,
  onLoginError=function(e)fail(e)end,
 })
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 doLogin(initial)
end)
scheduleEvent(function()if not done then fail('200-second choice probe timeout')end end,200000)
