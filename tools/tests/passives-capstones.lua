-- Real normal attacks, shield blocks, ordinary walks, spells and effective heals.
-- Fixture refill/equipment/HP-deficit commands are setup only, not forced proc events.
local tree,cap=PASSIVES_PROBE_TREE,PASSIVES_PROBE_CAP
local mod,login,player,metrics,sequence= nil,nil,nil,nil,0
local failed,done,finishing=false,false,false
local function fail(reason)
 if failed or done then return end
 failed=true;print('PASSIVES_CAPSTONE_FAILED '..tree..' '..cap..' '..tostring(reason))
 if g_game.isOnline()then g_game.cancelAttack();g_game.talk('/passiveqa quiesce Passive Tester');g_game.safeLogout()end
 scheduleEvent(function()g_app.exit()end,700)
end
local function later(ms,fn)
 scheduleEvent(function()if failed or done then return end;local ok,err=pcall(fn);if not ok then fail(err)end end,ms)
end
local function wait(label,predicate,nextStep,timeout)
 local deadline=g_clock.millis()+(timeout or 10000)
 local function poll()
  if predicate()then nextStep();return end
  assert(g_clock.millis()<deadline,label..' timeout');later(70,poll)
 end
 later(100,poll)
end
local function commands(list,nextStep)
 local function step(n)
  if n>#list then later(400,nextStep);return end
  g_game.talk(list[n]);later(300,function()step(n+1)end)
 end
 step(1)
end
local function state()return mod.getState()end
local function measure(nextStep,name)
 name=name or 'Passive Tester'
 local before=sequence;g_game.talk('/passiveqa metrics '..name)
 wait('native metrics',function()return sequence>before and metrics.player==name end,function()nextStep(metrics)end)
end
local function finish(m)
 finishing=true;g_game.cancelAttack()
 mod.show();mod.selectNode('cap_'..cap)
 print('PASSIVES_CAPSTONE_NATURAL_OK '..tree..' '..cap..' '..json.encode(m))
 later(350,function()
 g_app.doScreenshot('/passives-natural-'..tree..'-'..cap..'.png')
 later(250,function()commands({'/passiveqa quiesce Passive Tester','/passivetest stop'},function()
  assert(not state().active,'stop retained native overlay')
  assert(player:getMaxHealth()==735,'stop retained derived health')
  finishing=true;g_game.safeLogout()
  wait('logout cleanup',function()return not g_game.isOnline()end,function()
   assert(not state().tree and not mod.getWindow(),'logout retained passive tree')
   done=true;print('PASSIVES_CAPSTONE_OK '..tree..' '..cap);scheduleEvent(function()g_app.exit()end,400)
  end)
 end)end)end)
end
local deadline,castNumber,moveWest,casting=0,0,true,false
local normalOnly={riposte=true,bladestorm=true,stonebond=true,deadeye=true,skirmisher=true,quarry=true,concord=true}
local function castLoop()
 if failed or done or finishing then return end
 local spell
 if tree=='blademaster'then spell='exori sis'
 elseif tree=='earthshaker'then spell='exori mal'
 elseif tree=='arcanist'then
  castNumber=castNumber+1
  spell=cap=='spellweaver'and(castNumber%2==1 and'exori vis lux'or'exori gran vis')or'exori vis lux'
 end
 if spell then g_game.talk(spell)end
 later(tree=='arcanist'and cap~='spellweaver'and 2600 or 4400,castLoop)
end
local function movementLoop()
 if failed or done or finishing then return end
 g_game.walk(moveWest and West or East);moveWest=not moveWest
 later(2100,movementLoop)
end
local function poll()
 measure(function(m)
  assert(g_game.isOnline() and player:getHealth()>0,'fixture died')
  if PASSIVES_PROBE_PARTY and cap=='stonebond'and (tonumber(m.ward)or 0)==0 then
   assert(g_clock.millis()<deadline,'no current shared ward after natural block')
   later(350,poll);return
  end
  if (tonumber(m.capstoneProcCount)or 0)>0 then
   if cap=='riposte'or cap=='stoneguard'or cap=='stonebond'then assert((tonumber(m.shieldBlocks)or 0)>0,'effect lacked actual shield block')end
   if cap=='renewal'then
    -- Wait for an actual HoT tick as well as the initial schedule.
    if (tonumber(m.hotHealed)or 0)==0 then assert(g_clock.millis()<deadline,'Renewal HoT did not heal');later(350,poll);return end
   end
   if PASSIVES_PROBE_PARTY then
    measure(function(peer)
     assert(peer.profile.active==false,'peer accidentally received overlay')
     if cap=='stonebond'then
      if peer.ward<10 or peer.wardMs<2500 then assert(g_clock.millis()<deadline,'no fresh party ward');later(350,poll);return end
      assert(m.ward>0,'caster has no current ward')
      local initialWard,initialHP,expiry=peer.ward,peer.hp,g_clock.millis()+peer.wardMs
      finishing=true;g_game.cancelAttack();g_game.talk('/passiveqa wardhit Passive Peer,10')
      later(250,function()measure(function(hit)
       assert(not hit.profile.active,'peer overlay appeared')
       assert(g_clock.millis()<expiry,'ward expired before measurement')
       assert(hit.ward==initialWard-10 and hit.hp==initialHP,'party ward failed controlled native 10-HP absorption '..json.encode(hit))
       print('PASSIVES_PARTY_WARD_ABSORBED '..json.encode(hit));finish(m)
      end,'Passive Peer')end);return
     end
     if cap=='concord'then assert((tonumber(m.healedAmount)or 0)>0,'party Concord produced no effective heal');assert(m.lastHealTarget==peer.id,'Concord healed the wrong party recipient')end
     print('PASSIVES_PARTY_RECIPIENT_OK '..json.encode(peer));finish(m)
    end,'Passive Peer')
   else finish(m)end
   return
  end
  assert(g_clock.millis()<deadline,'natural capstone did not activate '..json.encode(m))
  if player:getHealth()<200 and cap~='concord'and cap~='renewal'and cap~='aegis'then g_game.talk('/passiveqa heal Passive Tester')end
  later(350,poll)
 end)
end
local function combat()
 mod.hide();deadline=g_clock.millis()+160000
 if cap=='riposte'or cap=='stoneguard'or cap=='stonebond'then g_game.setFightMode(FightDefensive)else g_game.setFightMode(FightOffensive)end
 if cap=='renewal'or cap=='aegis'then
  commands({'/passiveqa hurt Passive Tester,400'},function()g_game.talk('exura');poll()end)
  return
 end
 local target
 for _,c in ipairs(g_map.getSpectators(player:getPosition(),false))do
  if c:getName()=='Passive Test Dummy'and(not target or c:getId()<target:getId())then target=c end
 end
 assert(target,'arena target missing')
 if cap=='concord'then g_game.talk('/passiveqa hurt '..(PASSIVES_PROBE_PARTY and 'Passive Peer' or 'Passive Tester')..',400')end
 g_game.attack(target)
 if cap=='skirmisher'then later(2200,movementLoop)end
 if not normalOnly[cap]then later(1300,castLoop)end
 poll()
end
local function useCritDraft(nextStep)
 if cap~='bladestorm'then nextStep();return end
 local current=state();local ranks={};for id,rank in pairs(current.ranks)do ranks[id]=rank end
 ranks.major_precision=2;ranks.minor_power=4
 assert(not mod.validateDraft(ranks),'crit-oriented legal draft failed prerequisites')
 local revision=current.revision
 g_game.getProtocolGame():sendExtendedOpcode(103,json.encode({v=1,action='apply',session=current.session,revision=revision,requestId='natural-crit-draft',ranks=ranks}))
 wait('legal crit draft',function()return state().revision>revision and state().ranks.major_precision==2 end,function()
  local spent=0;for _,rank in pairs(state().ranks)do spent=spent+rank end
  assert(spent==16,'crit-oriented natural capstone fixture must still spend exactly16 points')
  nextStep()
 end)
end
local function setup()
 commands({'/passiveqa quiesce Passive Tester','/passivetest stop','/passiveqa equip '..tree,'/passiveqa learn','/passiveqa heal Passive Tester','/passivetest start '..tree,'/passivetest preset Passive Tester,'..cap,'/passivetest trace Passive Tester,on'},function()
  assert(state().tree.id==tree and state().ranks['cap_'..cap]==1,'requested native profile missing')
  local spent=0;for _,rank in pairs(state().ranks)do spent=spent+rank end
  assert(spent==16,'natural capstone fixture must spend exactly 16 points')
  assert(player:getLevel()==40,'natural capstone fixture must be level 40')
  if cap=='renewal'or cap=='aegis'then combat();return end
  useCritDraft(function()commands({'/passiveqa arena','/passiveqa join Passive Tester,1'},function()
   -- Existing server login/teleport pacification stays in force.
   if PASSIVES_PROBE_PARTY then
    commands({'/passiveqa join Passive Peer,2','/passiveqa heal Passive Peer'},function()
     local peer
     for _,c in ipairs(g_map.getSpectators(player:getPosition(),false))do if c:getName()=='Passive Peer'then peer=c end end
     assert(peer,'party peer not visible');g_game.partyInvite(peer:getId())
     later(3000,function()
      measure(function(m)assert(m.partySize==2,'real party was not joined');later(11000,combat)end)
     end)
    end)
   else later(11000,combat)end
  end)end)
 end)
end
local function online()
 EnterGame.hide();player=g_game.getLocalPlayer()
 connect(g_game,{onTextMessage=function(_,text)
  print('PASSIVES_CAPSTONE_MESSAGE '..text)
  local payload=text:match('^PASSIVEQA_METRICS (.+)$')
  if payload then metrics=json.decode(payload);sequence=sequence+1 end
 end})
 wait('handshake',function()return state().ready end,setup)
end
later(200,function()
 assert(LOCAL_PASSIVES_TEST and Services.updater=='' and g_resources.getLayout()=='retro')
 mod=assert(modules.game_passives);mod.setStatusVisible(true)
 g_settings.set('window-maximized',false);g_window.resize({width=1280,height=800})
 connect(g_game,{onGameStart=function()later(250,online)end,onConnectionError=function(err)if not finishing then fail(err)end end})
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 G.account='passivetest';G.password='passivetest'
 login=ProtocolLogin.create();_G.capstoneLogin=login
 login.onLoginError=function(_,err)fail(err)end
 login.onCharacterList=function(_,chars)
  for _,c in ipairs(chars)do if c.name=='Passive Tester'then g_game.loginWorld(G.account,G.password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return end end
  fail('fixture missing')
 end
 login:login('127.0.0.1',7174,G.account,G.password,'',false)
end)
scheduleEvent(function()if not done then fail('200-second capstone timeout')end end,200000)
