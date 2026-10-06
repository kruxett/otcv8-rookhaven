-- Natural Stonebond shield block + a second client's real Heal Friend/Aegis.
-- Fixed native energy hits measure absorption without physical talent reduction.
local failed,finished=false,false
local metrics,mod,login,sequence= nil,nil,nil,0
local rootName,peerName='Passive Tester','Passive Peer'
local function fail(reason)
 if failed or finished then return end;failed=true;print('PASSIVES_WARD_PARTY_FAILED '..tostring(reason))
 if g_game.isOnline()then g_game.cancelAttack();g_game.talk('/passiveqa cleanup');g_game.talk('/passivetest stop '..peerName);g_game.talk('/passivetest stop '..rootName);g_game.talk('/passiveqa wardsignal finish')end
 scheduleEvent(function()g_app.exit()end,1500)
end
local function later(ms,fn)scheduleEvent(function()if failed or finished then return end;local ok,e=pcall(fn);if not ok then fail(e)end end,ms)end
local function wait(label,predicate,nextStep,timeout)
 local deadline=g_clock.millis()+(timeout or 10000)
 local function poll()if predicate()then later(60,nextStep);return end;assert(g_clock.millis()<deadline,label..' timeout');later(100,poll)end
 later(100,poll)
end
local function commands(list,nextStep)
 local function run(n)if n>#list then later(140,nextStep);return end;g_game.talk(list[n]);later(180,function()run(n+1)end)end
 run(1)
end
local function measure(nextStep)
 local previous=sequence;g_game.talk('/passiveqa metrics '..rootName)
 wait('root native metrics',function()return sequence>previous end,function()print('PASSIVES_WARD_PARTY_METRICS '..json.encode(metrics));nextStep(metrics)end)
end
local function assertPools(m,combat,healing)
 assert((m.combatWard or 0)==combat and(m.healingWard or 0)==healing,'Unexpected ward pools '..json.encode(m))
 assert(m.ward==combat+healing and m.ward<=math.floor(m.maxHP*.10),'Aggregate ward/cap differs from source pools')
end
local function heal(amount,nextStep)
 commands({'/passiveqa heal '..rootName,'/passiveqa hurt '..rootName..','..amount,'/passiveqa heal '..peerName},function()
  measure(function(before)
   g_game.talk('/passiveqa wardsignal heal:'..tostring(g_clock.millis()))
   local deadline=g_clock.millis()+6000
   local function poll()measure(function(after)
    if after.playerHP>before.playerHP then nextStep(before,after);return end
    assert(g_clock.millis()<deadline,'Actual second-client Heal Friend did not heal');later(120,poll)
   end)end
   later(200,poll)
  end)
 end)
end
local function natural(nextStep)
 commands({'/passiveqa quiesce '..peerName,'/passiveqa quiesce '..rootName,
  '/passiveqa equip earthshaker,'..rootName,'/passiveqa equip lifekeeper,'..peerName,
  '/passivetest start earthshaker,'..rootName,'/passivetest preset '..rootName..',stonebond',
  '/passivetest start lifekeeper,'..peerName,'/passivetest preset '..peerName..',aegis',
  '/passiveqa learn '..peerName,'/passiveqa arena','/passiveqa join '..rootName..',1','/passiveqa join '..peerName..',2'},function()
  assert(mod.getState().ranks.cap_stonebond==1,'Stonebond preset missing')
  local deadline=g_clock.millis()+40000
  local function awaitParty()
   measure(function(m)
    if m.partySize==2 then
     commands({'/passiveqa victim '..rootName..',1'},function()
      local function poll()measure(function(after)
       if(after.combatWard or 0)>0 then
        assert(after.shieldBlocks>0,'Stonebond was not produced by a real shield block')
        commands({'/passiveqa quietmonsters'},function()measure(function(still)
         assert(still.combatWard>0 and(still.healingWard or 0)==0,'Natural combat ward missing or stale')
         print('PASSIVES_WARD_STONEBOND_NATURAL_OK shieldBlocks='..still.shieldBlocks..' combatWard='..still.combatWard)
         nextStep(still)
        end)end)
       else assert(g_clock.millis()<deadline,'Natural shield block/Stonebond timeout');later(150,poll)end
      end)end
      poll()
     end)
    else
     for _,peer in ipairs(g_map.getSpectators(g_game.getLocalPlayer():getPosition(),false))do if peer:getName()==peerName then g_game.partyInvite(peer:getId())end end
     assert(g_clock.millis()<deadline,'Native two-client party timeout');later(500,awaitParty)
    end
   end)
  end
  awaitParty()
 end)
end
local function finish()
 commands({'/passiveqa cleanup','/passivetest stop '..peerName,'/passivetest stop '..rootName,'/passiveqa wardsignal finish'},function()
  finished=true;g_game.safeLogout();scheduleEvent(function()print('PASSIVES_WARD_PARTY_OK');g_app.exit()end,1200)
 end)
end
local function phase(mode)
 natural(function(stone)
  heal(30,function(before,both)
   local combat=stone.combatWard
   local healing=math.floor((both.playerHP-before.playerHP)*.15)
   assert(healing>0 and healing<combat,'Small real heal must give a distinct smaller Aegis')
   assertPools(both,combat,healing)
   print('PASSIVES_WARD_COOPERATION_OK phase='..mode..' combat='..combat..' healing='..healing)
   g_app.doScreenshot('/passives-ward-party-both-'..mode..'.png')
   if mode==1 then
    heal(20,function(_,same)
     assertPools(same,combat,healing)
     print('PASSIVES_WARD_SAME_KIND_NONSTACK_OK')
     heal(100,function(beforeStrong,strong)
      local increased=math.floor((strong.playerHP-beforeStrong.playerHP)*.15)
      assert(increased>healing,'Stronger Aegis probe must exceed prior ward')
      assertPools(strong,combat,increased)
      print('PASSIVES_WARD_SAME_KIND_REPLACEMENT_OK old='..healing..' new='..increased)
      commands({'/passiveqa wardhitenergy '..rootName..',10'},function()measure(function(partial)
       assert(partial.playerHP==strong.playerHP and partial.ward==strong.ward-10,'Native first hit did not consume exactly10 shield HP')
       commands({'/passiveqa wardhitenergy '..rootName..','..(partial.ward+5)},function()measure(function(empty)
        assertPools(empty,0,0);assert(partial.playerHP-empty.playerHP==5,'Both real pools did not contribute before HP damage')
        print('PASSIVES_WARD_BOTH_ABSORB_OK total='..strong.ward..' finalHPDamage=5')
        phase(2)
       end)end)
      end)end)
     end)
    end)
   elseif mode==2 then
    commands({'/passivetest stop '..rootName},function()measure(function(stopped)
     assert(not stopped.profile.active,'Earthshaker Stop retained overlay')
     assertPools(stopped,0,healing)
     commands({'/passiveqa wardhitenergy '..rootName..','..(healing+1)},function()measure(function(hit)
      assertPools(hit,0,0);assert(stopped.playerHP-hit.playerHP==1,'Inactive recipient lost independent Aegis protection')
      print('PASSIVES_WARD_COMBAT_SOURCE_CLEANUP_OK healingPreserved='..healing)
      phase(3)
     end)end)
    end)end)
   else
    commands({'/passivetest stop '..peerName},function()measure(function(stopped)
     assertPools(stopped,combat,0)
     commands({'/passiveqa wardhitenergy '..rootName..','..(combat+5)},function()measure(function(hit)
      assertPools(hit,0,0);assert(stopped.playerHP-hit.playerHP==5,'Healer Stop incorrectly removed another source combat protection')
      print('PASSIVES_WARD_HEALING_SOURCE_CLEANUP_OK combatPreserved='..combat)
      finish()
     end)end)
    end)end)
   end
  end)
 end)
end
local function online()
 EnterGame.hide();mod=assert(modules.game_passives)
 connect(g_game,{onTextMessage=function(_,text)
  print('PASSIVES_WARD_PARTY_MESSAGE '..text)
  local encoded=text:match('^PASSIVEQA_METRICS (.+)$');if encoded then metrics=json.decode(encoded);sequence=sequence+1 end
 end})
 wait('native module handshake',function()return mod.getState().ready end,function()later(11500,function()phase(1)end)end)
end
later(200,function()
 assert(LOCAL_PASSIVES_TEST and Services.updater==''and g_resources.getLayout()=='retro')
 connect(g_game,{onGameStart=function()later(300,online)end,onConnectionError=function(err)if not finished then fail(err)end end})
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 G.account='passivetest';G.password='passivetest';login=ProtocolLogin.create();_G.wardPartyLogin=login
 login.onLoginError=function(_,err)fail(err)end
 login.onCharacterList=function(_,chars)for _,c in ipairs(chars)do if c.name==rootName then g_game.loginWorld(G.account,G.password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return end end;fail('Root fixture missing')end
 login:login('127.0.0.1',7174,G.account,G.password,'',false)
end)
scheduleEvent(function()if not finished then fail('220 second real-party regression timeout')end end,220000)
