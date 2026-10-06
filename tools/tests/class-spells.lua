-- Real group1 class choice, learned spells and casts. Runtime QA GUID9006..9011 only.
local tree = PASSIVES_PROBE_TREE
local names = {reaver='Reaver',blademaster='Blademaster',earthshaker='Earthshaker',
  marksman='Marksman',arcanist='Arcanist',lifekeeper='Lifekeeper'}
local foreignWords = tree == 'reaver' and 'exori sis punct' or 'exori sec vul'
local mod, spells, player, login, nextOnline, metrics
local sequence, npcSequence, castIndex = 0, 0, 0
local done, failed, intentional = false, false, false
local npcMessages, notices = {}, {}
local allNames = {'Cleaving Arc','Rend','Focused Thrust','Flurry','Crushing Blow','Rolling Thunder',
  'Blitzshot','Scattershot','Resonant Burst','Arcane Surge','Mending Thread','Essence Lash'}
local function fail(reason)
  if failed or done then return end
  failed = true; print('CLASS_SPELLS_FAILED '..tostring(reason))
  if g_game.isOnline() then
    g_game.cancelAttack(); g_game.talk('/classspellqa cleanup'); g_game.safeLogout()
  else g_game.cancelLogin() end
  scheduleEvent(function()g_app.exit()end,700)
end
local function later(ms, fn)
  scheduleEvent(function()
    if done or failed then return end
    local ok,errorMessage=pcall(fn);if not ok then fail(errorMessage)end
  end,ms)
end
local function wait(label, predicate, fn, timeout)
  local deadline=g_clock.millis()+(timeout or 12000)
  local function poll()
    if predicate()then fn();return end
    assert(g_clock.millis()<deadline,label..' timeout');later(70,poll)
  end
  later(100,poll)
end
local function qa(command,fn)
  local before=sequence;local label=command:match('^%S+')
  g_game.talk('/classspellqa '..command)
  wait('fixture '..command,function()return sequence>before and metrics.label==label end,function()fn(metrics)end)
end
local function state()return mod.getState()end
local function catalog()return spells.getState().catalog end
local function sawNotice(after,needle)
  for index=after+1,#notices do if notices[index]:lower():find(needle,1,true)then return true end end
  return false
end
local function assertLearned(m)
  assert(m.profile.mode=='permanent'and m.profile.treeId==tree,'Wrong permanent class')
  local c=assert(catalog(),'Learned spell catalog missing')
  assert(c.classId==tree and #c.spells==2,'Wrong class spell catalog')
  local own={};for _,s in ipairs(c.spells)do own[s.name]=true end
  local count=0
  for _,name in ipairs(allNames)do
    assert(type(m.learned[name])=='boolean','Missing server learned-state entry: '..name)
    assert(m.learned[name]==(own[name]==true),'Incorrect learned class gate: '..name)
    if m.learned[name]then count=count+1 end
  end
  assert(count==2,'Expected exactly two learned starter spells')
end
local function targetMap(m)
  local out={};for _,t in ipairs(m.targets or{})do out[t.id]=t.hp end;return out
end
local function damage(before,after)
  local original=targetMap(before);local hit,total=0,0
  assert(#before.targets==3 and #after.targets==3,'Fresh three-dummy arena required')
  for _,t in ipairs(after.targets)do
    assert(original[t.id],'Arena target changed mid-cast')
    local loss=original[t.id]-t.hp;assert(loss>=0,'Dummy healed during measurement')
    if loss>0 then hit=hit+1;total=total+loss end
  end
  return hit,total
end
local function unchanged(before,after,label)
  local hits,total=damage(before,after)
  assert(hits==0 and total==0 and before.mana==after.mana and before.ammo==after.ammo,
    label..' changed health, mana or ammo: '..json.encode({before=before,after=after}))
end
local function firstSpell()return assert(catalog()).spells[1]end
local function doLogin(fn)
  nextOnline=fn;G.account='class'..tree;G.password=G.account
  login=ProtocolLogin.create();_G.classSpellsLogin=login
  login.onLoginError=function(_,e)fail('Account login: '..tostring(e))end
  login.onCharacterList=function(_,list)
    for _,entry in ipairs(list)do if entry.name=='Starter '..names[tree]then
      g_game.loginWorld(G.account,G.password,entry.worldName,entry.worldIp,entry.worldPort,entry.name,'','');return
    end end
    fail('Ordinary class fixture absent')
  end
  login:login('127.0.0.1',7174,G.account,G.password,'',false)
  wait('world login',function()return g_game.isOnline()end,function()end,16000)
end
local function relog(fn)
  intentional=true;g_game.safeLogout()
  wait('logout',function()return not g_game.isOnline()end,function()
    assert(not spells.getWindow()and not spells.getButton()and not spells.getState().catalog,'Logout retained class spell state')
    -- Both account/world sockets count toward the existing local IP throttle.
    later(6000,function()doLogin(fn)end)
  end)
end
local function npcSay(words,needle,fn)
  local before=npcSequence;g_game.talkChannel(MessageModes.NpcTo,0,words)
  wait('NPC '..words,function()
    for n=before+1,npcSequence do if npcMessages[n]:lower():find(needle,1,true)then return true end end
    return false
  end,fn,22000)
end
local function inside(widget,rect)
  local r=widget:getRect()
  return widget:isVisible()and r.x>=rect.x and r.y>=rect.y and r.x+r.width<=rect.x+rect.width and r.y+r.height<=rect.y+rect.height
end
local function uiCheck(fn)
  mod.hide()
  assert(spells.getButton()and spells.getButton():isVisible(),'Ordinary learned-spell button missing')
  assert(spells.show());local w=assert(spells.getWindow())
  for _,s in ipairs(catalog().spells)do
    local card=assert(spells.getCard(s.id));assert(inside(card,w:getRect()),'Spell card clipped')
    assert(card:getChildById('words'):getText():find(s.words,1,true),'Incantation missing')
    assert(card:getChildById('cost'):getText():find(tostring(s.mana),1,true),'Mana metadata missing')
  end
  later(400,function()
   g_app.doScreenshot('/class-spells-'..tree..'-book.png')
   g_window.resize({width=800,height=640})
   later(400,function()
    local root=g_ui.getRootWidget():getRect();local r=w:getRect()
    assert(inside(w,root),'Class spell window outside 800x640')
    assert(inside(w:getChildById('closeButton'),r),'Close button clipped')
    for _,s in ipairs(catalog().spells)do
      local card=spells.getCard(s.id);assert(inside(card,r)and inside(card:getChildById('cast'),r),'Small-window card/cast clipped')
      assert(card:getChildById('descriptionScroll'):getHeight()>35,'Description viewport collapsed')
    end
    if tree=='lifekeeper'then assert(inside(w:getChildById('targetName'),r),'Heal target field clipped')end
    g_app.doScreenshot('/class-spells-'..tree..'-small.png')
    g_window.resize({width=1280,height=800});later(300,fn)
   end)
  end)
end
local function finish()
  qa('cleanup',function()
    intentional=true;g_game.safeLogout()
    wait('final logout',function()return not g_game.isOnline()end,function()
      assert(not spells.getWindow()and not spells.getButton()and not spells.getState().catalog,'Final logout retained class spells')
      done=true;print('CLASS_SPELLS_OK '..tree);g_app.exit()
    end)
  end)
end
local castNext, rejectedGates
local function rejected(words,label,fn,focus)
  local function attempt()
    qa('state',function(before)
      local note=#notices;g_game.talk(words)
      later(120,function()qa('stop',function()
        qa('state',function(after)
          unchanged(before,after,label)
          local expected=({wrongclass='matching permanent',wrongweapon='class weapon',nomana='enough mana',unlearned='learn this spell'})[label]
          assert(sawNotice(note,assert(expected)),label..' did not produce the specific server rejection')
          print('CLASS_SPELLS_GATE_OK '..label);fn()
        end)
      end)end)
    end)
  end
  -- These four gates precede native target selection. Clear the target so an
  -- ordinary attack cannot contaminate a rejected spell's damage measurement.
  qa('stop',function()attempt()end)
end
rejectedGates=function()
  local s=firstSpell()
  qa('reset',function()
    rejected(foreignWords,'wrongclass',function()
      qa('wrongweapon',function()
        rejected(s.words,'wrongweapon',function()
          qa('equip',function()qa('empty',function()
            rejected(s.words,'nomana',function()
              qa('reset',function()qa('forget '..s.name,function(m)
                assert(m.learned[s.name]==false,'Fixture did not forget selected spell')
                rejected(s.words,'unlearned',function()
                  qa('restore',function(m)
                    assertLearned(m);print('CLASS_SPELLS_RESTORE_LEARNED_OK');finish()
                  end)
                end,s.kind=='combat')
              end)end)
            end,s.kind=='combat')
          end)end)
        end,s.kind=='combat')
      end)
    end,false)
  end)
end
local function pulseAbort(fn)
  local s
  for _,entry in ipairs(catalog().spells)do if entry.id=='resonant_burst'then s=entry end end
  if not s then fn();return end
  qa('reset',function()qa('equip',function()qa('focus',function()
    later(250,function()qa('state',function(before)
      g_game.talk(s.words)
      later(100,function()qa('wrongweapon',function(atSwitch)
        qa('stop',function()
          later(1100,function()qa('state',function(after)
            local hit,total=damage(before,atSwitch);assert(hit==1 and total>0,'First real pulse missing before weapon change')
            unchanged(atSwitch,after,'delayed weapon invalidation')
            assert(before.mana-after.mana==s.mana,'Pulse invalidation refunded or double-paid mana')
            print('CLASS_SPELLS_DELAYED_WEAPON_ABORT_OK');fn()
          end)end)
        end)
      end)end)
    end)end)
  end)end)end)
end
local function verifyCast(s,before,after)
  assert(before.mana-after.mana==s.mana,'Wrong actual mana cost for '..s.name)
  if s.kind=='healing'then
    local hit,total=damage(before,after);assert(hit==0 and total==0 and after.hp>before.hp,'Mending Thread did not directly heal self')
    -- Empty permanent tree: assert the agreed revised formula, not just positive HP.
    local level,ml=player:getLevel(),player:getMagicLevel()
    local low=math.floor(level/5+ml*1.6+9+0.5)
    local high=math.floor(level/5+ml*2.0+11+0.5)
    local actual=after.hp-before.hp
    assert(actual>=low and actual<=high,'Mending self heal outside revised raw formula: '..actual)
  else
    local hits,total=damage(before,after)
    local expected=({cleaving_arc=3,rend=1,focused_thrust=1,flurry=1,crushing_blow=1,
      rolling_thunder=3,blitzshot=2,scattershot=3,resonant_burst=1,arcane_surge=3,essence_lash=1})[s.id]
    assert(hits==expected and total>0,s.name..' hit wrong recipients: '..hits..' expected '..tostring(expected))
    if tree=='marksman'then assert(before.ammo-after.ammo==1,'Bow spell did not consume exactly one round')end
  end
  print('CLASS_SPELLS_REAL_CAST_OK '..s.id..' mana='..(before.mana-after.mana))
end
local function runCast(s)
  local function targeted()
    qa('state',function(before)
      local castAt=g_clock.millis();assert(spells.cast(s.id),'UI cast rejected ready spell')
      later(120,function()qa('stop',function(stopped)
        g_app.doScreenshot('/class-spells-'..tree..'-'..s.id..'-effect.png')
        -- Immediate repeat is sent directly; UI correctly blocks exhausted cards.
        assert(not spells.cast(s.id),'UI ignored shared cooldown')
        for _,other in ipairs(catalog().spells)do if other.kind==s.kind then
          assert(not spells.getCard(other.id):getChildById('cast'):isEnabled(),'Shared group left another card enabled')
        end end
        local note=#notices;g_game.talk(s.words)
        later(150,function()qa('state',function(repeatState)
          assert(repeatState.mana==stopped.mana and repeatState.ammo==stopped.ammo,'Cooldown rejection charged a second cost')
          assert(sawNotice(note,'exhaust'),'Immediate repeat lacked the specific shared-exhaustion rejection')
          if s.id=='resonant_burst'then
            later(math.max(40,castAt+660-g_clock.millis()),function()qa('state',function(second)
              local firstHP=targetMap(stopped);local secondHP=targetMap(second)
              assert(secondHP[before.targets[1].id]<firstHP[before.targets[1].id],'Second real Resonant pulse missing')
              later(math.max(40,castAt+1250-g_clock.millis()),function()qa('state',function(after)
                assert(targetMap(after)[before.targets[1].id]<secondHP[before.targets[1].id],'Third real Resonant pulse missing')
                verifyCast(s,before,after);castNext()
              end)end)
            end)end)
          else
            local settle=(s.id=='rolling_thunder'and 800 or s.id=='flurry'and 550 or 450)
            later(math.max(40,castAt+settle-g_clock.millis()),function()qa('state',function(after)
              verifyCast(s,before,after);castNext()
            end)end)
          end
        end)end)
      end)end)
    end)
  end
  -- Runtime refill clears native exhaustion for setup, but deliberately does not
  -- fabricate a client cooldown event. Let the previous real group timer expire.
  wait('real UI cooldown '..s.id,function()
    return (spells.getState().shared[s.kind]or 0)<=g_clock.millis()
  end,function()
    qa('reset',function()
      if s.kind=='healing'then qa('hurt',function()targeted()end)
      else qa('focus',function()later(250,targeted)end)end
    end)
  end)
end
castNext=function()
  castIndex=castIndex+1
  local s=catalog().spells[castIndex]
  if not s then pulseAbort(rejectedGates);return end
  if s.id=='arcane_surge'then qa('line',function()runCast(s)end)else runCast(s)end
end
local function beginCasts()
  qa('setup',function(m)
    assertLearned(m);assert(#m.targets==3,'Fixture did not create fresh dummy cluster')
    uiCheck(function()mod.hide();spells.hide();later(11000,castNext)end)
  end)
end
local function chosen()
  wait('chosen class and learned metadata',function()
    return state().active and state().mode=='permanent'and state().tree.id==tree and catalog()~=nil
  end,function()
    qa('state',function(m)
      assertLearned(m);print('CLASS_SPELLS_NPC_LEARNED_OK '..tree)
      qa('save',function()relog(function()
        qa('state',function(m)assertLearned(m);print('CLASS_SPELLS_LEARNED_RELOGIN_OK '..tree);beginCasts()end)
      end)end)
    end)
  end)
end
local function initial()
  if state().active and state().mode=='permanent' and state().tree.id==tree then
    qa('state',function(m)assertLearned(m);relog(function()
      qa('state',function(m)assertLearned(m);print('CLASS_SPELLS_LEARNED_RELOGIN_OK '..tree);beginCasts()end)
    end)end)
    return
  end
  assert(not state().active and not catalog(),'Runner did not seed a fresh classless player')
  qa('npc',function()
    npcSay('hi','which',function()npcSay(tree,'certain',function()
      g_game.talkChannel(MessageModes.NpcTo,0,'yes');chosen()
    end)end)
  end)
end
later(250,function()
  assert(names[tree]and LOCAL_PASSIVES_TEST and Services.updater==''and g_resources.getLayout()=='retro')
  mod=assert(modules.game_passives);spells=assert(mod.ClassSpells)
  g_settings.set('window-maximized',false);g_window.resize({width=1280,height=800})
  connect(g_game,{
    onTalk=function(name,level,mode,message)
      if name=='The Nameless'then npcSequence=npcSequence+1;npcMessages[npcSequence]=message;print('CLASS_SPELLS_NPC '..message)end
    end,
    onTextMessage=function(_,message)
      print('CLASS_SPELLS_MESSAGE '..message)
      if message:find('CLASS_SPELL_QA_FAILED',1,true)then fail(message);return end
      local raw=message:match('^CLASS_SPELL_QA (.+)$')
      if raw then metrics=json.decode(raw);sequence=sequence+1 else notices[#notices+1]=message end
    end,
    onGameStart=function()
      EnterGame.hide();player=assert(g_game.getLocalPlayer());intentional=false
      local fn=nextOnline;nextOnline=nil
      wait('capable handshake',function()return state().ready end,function()later(350,fn)end)
    end,
    onLoginError=function(e)fail(e)end,
    onConnectionError=function(e)if not intentional then fail(e)end end,
  })
  g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
  doLogin(initial)
end)
scheduleEvent(function()if not done then fail('180-second starter spell timeout')end end,180000)
