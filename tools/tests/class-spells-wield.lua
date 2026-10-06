-- Actual ordinary-player retained-equipment gates and delayed stat-loss.
-- Run separately for arcanist, earthshaker, lifekeeper, marksman; ranks empty.
-- /wield and /learnlegacy are bounded disposable runtime fixtures, not gameplay
-- acquisition evidence. No SQL or server process orchestration belongs here.
local tree=PASSIVES_PROBE_TREE or 'arcanist'
local names={arcanist='Arcanist',earthshaker='Earthshaker',lifekeeper='Lifekeeper',marksman='Marksman'}
local mod,spells,player,login,metrics,lossMetrics
local sequence,cooldownSequence=0,0
local notices={}
local done,failed,intentional=false,false,false
local function fail(reason)
 if done or failed then return end
 failed=true;print('CLASS_SPELLS_WIELD_FAILED '..tree..' '..tostring(reason))
 if g_game.isOnline()then g_game.cancelAttack();g_game.talk('/classspellqa cleanup');g_game.safeLogout()else g_game.cancelLogin()end
 scheduleEvent(function()g_app.exit()end,700)
end
local function later(ms,fn)
 scheduleEvent(function()if done or failed then return end;local ok,e=pcall(fn);if not ok then fail(e)end end,ms)
end
local function wait(label,predicate,fn,ms)
 local deadline=g_clock.millis()+(ms or 8000)
 local function poll()if predicate()then fn();return end;assert(g_clock.millis()<deadline,label..' timeout');later(60,poll)end
 later(80,poll)
end
local function qa(cmd,fn)
 local before=sequence;local label=cmd:match('^%S+');g_game.talk('/classspellqa '..cmd)
 wait('fixture '..cmd,function()return sequence>before and metrics.label==label end,function()fn(metrics)end)
end
local function entry(id)
 local c=assert(spells.getState().catalog,'Missing real class spell catalog')
 for _,s in ipairs(c.spells)do if s.id==id then return s end end;error('Missing spell '..id)
end
local function ready(kind,fn)
 wait('actual shared '..kind..' expiry',function()return(spells.getState().shared[kind]or 0)<=g_clock.millis()end,fn,7000)
end
local function hpMap(m)
 local out={};assert(#m.targets==3,'Expected owned three-target arena')
 for _,t in ipairs(m.targets)do out[t.id]=t.hp end;return out
end
local function damage(before,after)
 local original=hpMap(before);local hits,total=0,0
 for _,t in ipairs(after.targets)do
  local loss=assert(original[t.id],'Fixture target changed')-t.hp
  assert(loss>=0,'Dummy healed during measurement');if loss>0 then hits=hits+1;total=total+loss end
 end
 return hits,total
end
local function sawNotice(after,needle)
 for n=after+1,#notices do if notices[n]:lower():find(needle,1,true)then return true end end;return false
end
local function finish()
 qa('cleanup',function(m)
  assert(#m.targets==0 and not m.wield,'Cleanup retained monsters or wield fixture')
  assert(m.level==40 and m.skills.club==60,'Cleanup failed to restore level/base weapon skill')
  intentional=true;g_game.safeLogout()
  wait('logout',function()return not g_game.isOnline()end,function()
   assert(not spells.getWindow()and not spells.getButton()and not spells.getState().catalog,'Logout retained class UI')
   done=true;print('CLASS_SPELLS_WIELD_OK '..tree);g_app.exit()
  end)
 end)
end
local function fixtureCase(m,case)
 local skill=tree=='earthshaker';local w=assert(m.wield,'Missing wield metadata')
 assert(w.case==case and w.item==(skill and 12735 or 2190)and m.weaponId==w.item,'Wrong retained fixture weapon')
 assert(w.required==(skill and 30 or 7),'Wrong real weapon requirement')
 if skill then assert(m.skills.club==(case=='skillbelow'and 29 or 30),'Wrong retained club skill')
 else assert(m.level==(case=='levelbelow'and 6 or 7),'Wrong retained level')end
end
local delayed
local function accepted(case,fn)
 ready('combat',function()qa('wield '..case,function(m)
  fixtureCase(m,case)
  qa('focus',function()later(250,function()qa('state',function(before)
   local s=entry(tree=='arcanist'and'resonant_burst'or'crushing_blow')
   assert(spells.show());assert(spells.cast(s.id),'UI rejected exact-requirement spell')
   later(120,function()qa('stop',function()
    later(tree=='arcanist'and 1200 or 250,function()qa('state',function(after)
     local hits,total=damage(before,after)
     assert(hits==1 and total>0,'Exact requirement did not allow real primary monster damage')
     assert(before.mana-after.mana==s.mana,'Exact requirement charged wrong actual catalog cost')
     print('CLASS_SPELLS_WIELD_EXACT_OK '..case..' actualDamage='..total..' mana='..s.mana)
     g_app.doScreenshot('/class-spells-wield-'..tree..'-exact.png');fn()
    end)end)
   end)end)
  end)end)end)
 end)end)
end
local function rejected()
 local below=tree=='arcanist'and'levelbelow'or'skillbelow'
 local exact=tree=='arcanist'and'levelexact'or'skillexact'
 qa('wield '..below,function(m)
  fixtureCase(m,below)
  qa('focus',function()later(250,function()qa('state',function(before)
   local s=entry(tree=='arcanist'and'resonant_burst'or'crushing_blow')
   local note,events=#notices,cooldownSequence
   g_game.talk(s.words)
   later(160,function()qa('stop',function()qa('state',function(after)
    local hits,total=damage(before,after)
    assert(hits==0 and total==0 and before.mana==after.mana and before.ammo==after.ammo,'Below requirement cast damaged or paid resources')
    assert(cooldownSequence==events,'Rejected wield cast emitted successful exhaustion')
    assert(sawNotice(note,'wield requirements'),'Rejected cast lacked actual wield requirement feedback')
    print('CLASS_SPELLS_WIELD_BELOW_OK '..below)
    accepted(exact,tree=='arcanist'and delayed or finish)
   end)end)end)
  end)end)end)
 end)
end
delayed=function()
 ready('combat',function()qa('wield delaylevel',function(m)
  fixtureCase(m,'delaylevel');lossMetrics=nil
  qa('focus',function()later(250,function()qa('state',function(before)
   assert(not before.wield.lossApplied,'Ordinary autoattack incorrectly triggered delayed wield-loss fixture')
   local s=entry('resonant_burst');assert(spells.cast(s.id))
   wait('real first-pulse wield loss',function()return lossMetrics~=nil end,function()
    local loss=lossMetrics
    assert(loss.wield.lossApplied and not loss.wield.watchExpired and loss.level==6 and loss.weaponId==2190,
     'Watcher did not lower real level on retained wand after a spell pulse')
    local hits,total=damage(before,loss)
    assert(hits==1 and total>0,'No actual first pulse before requirement loss')
    -- The existing experience-loss path refills/clamps current mana to the new
    -- maximum. Compare payment before that fixture transition, then verify no
    -- later pulse changes the resulting mana after the real level loss.
    assert(before.mana-assert(loss.wield.manaBeforeLoss)==s.mana,'Delayed first pulse charged wrong catalog cost')
    qa('stop',function()
     later(1500,function()qa('state',function(after)
      local laterHits,laterDamage=damage(loss,after)
      assert(laterHits==0 and laterDamage==0,'Later pulse dealt damage below retained weapon requirement')
      assert(after.mana==loss.mana,'Delayed invalidation charged/refunded mana')
      assert(after.runtime.procCount==loss.runtime.procCount,'Invalid later pulse activated a passive proc')
      print('CLASS_SPELLS_WIELD_DELAYED_LEVEL_LOSS_OK firstDamage='..total)
      g_app.doScreenshot('/class-spells-wield-arcanist-delayed-loss.png');finish()
     end)end)
    end)
   end,1500)
  end)end)end)
 end)end)
end
local function healCast(words,id,cost,low,high,label,fn)
 ready('healing',function()qa('hurt',function(before)
  assert(before.level==40 and before.magicLevel==6,'Unexpected L40 ML6 healing fixture')
  assert(before.profile.spent==0,'Healing formula comparison requires empty ranks')
  if id then assert(spells.show());assert(spells.cast(id))else g_game.talk(words)end
  later(250,function()qa('state',function(after)
   local heal=after.hp-before.hp;local hits,total=damage(before,after)
   assert(heal>=low and heal<=high,label..' actual direct heal '..heal..' outside '..low..'..'..high)
   assert(before.mana-after.mana==cost,label..' actual mana does not match expected cost')
   assert(hits==0 and total==0 and after.runtime.procCount==before.runtime.procCount,'Baseline direct heal caused an offensive/capstone effect')
   assert((spells.getState().shared.healing or 0)>g_clock.millis(),'Real healing cast omitted shared exhaustion')
   print('CLASS_SPELLS_HEAL_FORMULA_OK '..label..' HP='..heal..' mana='..cost)
   g_app.doScreenshot('/class-spells-wield-lifekeeper-'..label..'.png');fn()
  end)end)
 end)end)
end
local function healing()
 qa('learnlegacy',function()
  -- Light Healing is explicitly granted by the local fixture for this formula
  -- check. This does not prove that an Ascended player can acquire it in-world.
  healCast('exura',nil,20,24,29,'legacy-light',function()
   local s=entry('mending_thread')
   assert(s.mana==22,'Revised Mending base mana missing from actual server catalog')
   healCast(nil,s.id,s.mana,27,31,'mending',finish)
  end)
 end)
end
local function lastAmmo()
 local ids={'blitzshot','scattershot'}
 local function nextSpell(index)
  if not ids[index]then finish();return end
  ready('combat',function()qa('lastammo',function(initial)
   assert(initial.ammo==1 and initial.profile.spent==0,'Expected one actual arrow and no allocated passive ranks')
   qa('focus',function()later(250,function()qa('state',function(before)
    -- The initial ordinary shot was completed with a full stack before setting
    -- one round; fixture weapon speed suppresses further autos. If one sneaks
    -- through, fail explicitly rather than credit it as a successful spell.
    assert(before.ammo==1,'An ordinary auto consumed the last round before the spell')
    local s=entry(ids[index]);assert(spells.show());assert(spells.cast(s.id))
    later(120,function()qa('stop',function()later(250,function()qa('state',function(after)
     local hits,total=damage(before,after)
     assert(hits==(index==1 and 2 or 3)and total>0,'Last-round spell hit wrong monster recipients')
     assert(before.ammo==1 and after.ammo==0,'Successful spell did not consume exactly the last round')
     assert(before.mana-after.mana==s.mana,'Last-round spell charged wrong actual catalog cost')
     assert(after.runtime.pendingActions==0,'Last-round spell retained an unfinished action')
     assert(after.runtime.procCount==before.runtime.procCount,'Bow starter incorrectly activated an ordinary-shot capstone')
     g_app.doScreenshot('/class-spells-wield-marksman-lastammo-'..s.id..'.png')
     later(1200,function()qa('state',function(last)
      local delayedHits,delayedDamage=damage(after,last)
      assert(delayedHits==0 and delayedDamage==0 and last.ammo==0 and last.mana==after.mana,
       'Completed last-round action replayed damage or resource billing')
      assert(last.runtime.pendingActions==0 and last.runtime.procCount==after.runtime.procCount,'Last-round cleanup produced an action/proc later')
      print('CLASS_SPELLS_LAST_AMMO_OK '..s.id..' mana='..s.mana..' targets='..hits)
      nextSpell(index+1)
     end)end)
    end)end)end)end)
   end)end)end)
  end)end)
 end
 -- Prime the one natural autoattack with the setup's100 arrows, then stop before
 -- the isolated last-round measurement. Do not fabricate attack counters.
 qa('focus',function()later(250,function()qa('stop',function()nextSpell(1)end)end)end)
end
local function begin()
 wait('permanent learned class',function()
  local s=mod.getState();return s.ready and s.active and s.mode=='permanent'and s.tree and s.tree.id==tree and spells.getState().catalog
 end,function()
  qa('setup',function(m)
   assert(m.level==40 and m.profile.spent==0,'Runner must supply an empty ordinary level40 permanent class')
   local scenario=tree=='lifekeeper'and healing or tree=='marksman'and lastAmmo or rejected
   mod.hide();later(11000,scenario)
  end)
 end)
end
later(250,function()
 assert(names[tree]and LOCAL_PASSIVES_TEST and Services.updater==''and g_resources.getLayout()=='retro')
 mod=assert(modules.game_passives);spells=assert(mod.ClassSpells)
 g_settings.set('window-maximized',false);g_window.resize({width=1280,height=800})
 ProtocolGame.registerExtendedJSONOpcode(103,function(_,_,data)
  if data.action=='class_spell_cooldown'then cooldownSequence=cooldownSequence+1 end
 end)
 connect(g_game,{
  onTextMessage=function(_,message)
   print('CLASS_SPELLS_WIELD_MESSAGE '..message)
   if message:find('CLASS_SPELL_QA_FAILED',1,true)then fail(message);return end
   local raw=message:match('^CLASS_SPELL_QA (.+)$')
   if raw then
    metrics=json.decode(raw);sequence=sequence+1
    if metrics.label=='wieldloss'then lossMetrics=metrics end
    if metrics.label=='wieldtimeout'then fail('No real pulse before fixture watcher expired')end
   else notices[#notices+1]=message end
  end,
  onGameStart=function()EnterGame.hide();player=assert(g_game.getLocalPlayer());later(300,begin)end,
  onLoginError=function(e)fail(e)end,
  onConnectionError=function(e)if not intentional then fail(e)end end,
 })
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 G.account='class'..tree;G.password=G.account
 login=ProtocolLogin.create();_G.classWieldLogin=login
 login.onLoginError=function(_,e)fail(e)end
 login.onCharacterList=function(_,list)
  for _,c in ipairs(list)do if c.name=='Starter '..names[tree]then
   g_game.loginWorld(G.account,G.password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return
  end end;fail('Ordinary class fixture missing')
 end
 login:login('127.0.0.1',7174,G.account,G.password,'',false)
end)
scheduleEvent(function()if not done then fail('100-second wield/formula timeout')end end,100000)
