-- Real, ordinary axe combat against runtime-only dummy monsters.
-- Refills/quiesce are setup diagnostics and are excluded from combat evidence.
local failed, finished = false, false
local metrics, login, mod, sharedTargetId
local selfName = 'Passive Tester'
local function fail(reason)
  if failed or finished then return end
  failed = true; print('PASSIVES_COMBAT_FAILED '..tostring(reason))
  if g_game.isOnline() then
    g_game.cancelAttack(); g_game.talk('/passiveqa cleanup')
    scheduleEvent(function() g_game.talk('/passivetest stop '..selfName) end,150)
    scheduleEvent(function() g_game.safeLogout() end,350)
  end
  scheduleEvent(function() g_app.exit() end,800)
end
local function later(ms,fn)
  scheduleEvent(function()
    if failed or finished then return end
    local ok,err=pcall(fn); if not ok then fail(err) end
  end,ms)
end
local function waitFor(label,predicate,nextStep,timeout)
  local untilTime=g_clock.millis()+(timeout or 9000)
  local function poll()
    if failed then return end
    local ok,yes=pcall(predicate)
    if not ok then fail(yes); return end
    if yes then later(100,nextStep); return end
    if g_clock.millis()>untilTime then fail(label..' timed out'); return end
    later(100,poll)
  end
  poll()
end
local function talk(text) g_game.talk(text) end
local function commands(list,nextStep)
  local function step(index)
    if index>#list then later(800,nextStep); return end
    talk(list[index]); later(300,function() step(index+1) end)
  end
  step(1)
end
local function measure(name,check,nextStep)
  metrics=nil; talk('/passiveqa metrics '..name)
  waitFor('real native metrics '..name,function() return metrics and metrics.sourcePlayerName==name end,function()
    print('PASSIVES_COMBAT_METRICS '..json.encode(metrics))
    check(metrics); nextStep()
  end)
end
local function measureUntil(name,predicate,nextStep)
  local untilTime=g_clock.millis()+15000
  local function query()
    measure(name,function() end,function()
      if predicate(metrics) then nextStep(); return end
      assert(g_clock.millis()<untilTime,'native metrics condition timed out')
      later(600,query)
    end)
  end
  query()
end
local function shoot(name,nextStep)
  g_app.doScreenshot('/'..name..'.png'); later(600,nextStep)
end
local function state() return mod.getState() end
local function axeAttack()
  local candidates=g_map.getSpectators(g_game.getLocalPlayer():getPosition(),false)
  local target
  for _,c in ipairs(candidates) do
    if c:getName()=='Passive Test Dummy' and (not target or c:getId()<target:getId()) then target=c end
  end
  assert(target,'real dummy not visible'); g_game.attack(target)
end
local function arena(nextStep,withPeer)
  local list={'/passiveqa arena','/passiveqa join '..selfName..',1','/passiveqa heal '..selfName}
  if withPeer then list[#list+1]='/passiveqa join Passive Peer,2'; list[#list+1]='/passiveqa heal Passive Peer' end
  commands(list,function() mod.hide(); axeAttack(); if withPeer then talk('/passiveqa attack Passive Peer') end; nextStep() end)
end
local function quiet(nextStep)
  g_game.cancelAttack()
  commands({'/passiveqa cleanup','/passiveqa quiesce '..selfName,'/passiveqa quiesce Passive Peer'},nextStep)
end
local function complete()
  quiet(function()
    commands({'/passivetest stop '..selfName,'/passivetest stop Passive Peer'},function()
      assert(not state().active,'end retained overlay')
      assert(g_game.getLocalPlayer():getMaxHealth()==735,'temporary max HP did not return to baseline')
      finished=true
      g_game.safeLogout()
      scheduleEvent(function() print(PASSIVES_COMBAT_PHASE=='ward' and 'PASSIVES_WARD_OK' or 'PASSIVES_COMBAT_OK'); g_app.exit() end,1200)
    end)
  end)
end
local function weaponCleanup()
  g_game.cancelAttack()
  local player=g_game.getLocalPlayer()
  local item=assert(player:getInventoryItem(InventorySlotLeft),'fixture axe missing')
  local itemId,position=item:getId(),player:getPosition()
  g_game.move(item,position,1)
  waitFor('real axe unequip',function()
    return not player:getInventoryItem(InventorySlotLeft) and state().runtime.weaponActive==false
  end,function()
    assert(player:getMaxHealth()==735,'unequip retained temporary max HP')
    assert((state().runtime.ward or 0)==0 and state().runtime.berserkUntil<=g_clock.millis(),'unequip retained combat effects')
    assert(state().ranks.cap_bloodguard==1,'weapon change removed allocated ranks')
    print('PASSIVES_WEAPON_CLEANUP_OK')
    shoot('passives-combat-05-axe-inactive',function()
      local ground
      for _,thing in ipairs(assert(g_map.getTile(position)):getItems()) do if thing:getId()==itemId then ground=thing;break end end
      assert(ground,'dropped fixture axe missing')
      local beforeHealth=player:getHealth()
      g_game.move(ground,{x=65535,y=InventorySlotLeft,z=0},1)
      waitFor('real axe re-equip',function()
        return player:getInventoryItem(InventorySlotLeft) and state().runtime.weaponActive==true and player:getMaxHealth()==779
      end,function()
        assert(player:getHealth()<=beforeHealth,'re-equipping granted free healing')
        print('PASSIVES_WEAPON_REEQUIP_OK')
        complete()
      end)
    end)
  end)
end
local function bloodguard()
  quiet(function()
    commands({'/passivetest start reaver','/passivetest preset '..selfName..', bloodguard','/passivetest trace '..selfName..',on'},function()
      assert(state().ranks.cap_bloodguard==1,'Bloodguard preset missing')
      assert(g_game.getLocalPlayer():getMaxHealth()>735,'derived HP did not increase')
      arena(function()
        waitFor('natural Bloodguard shield',function() return (state().runtime.ward or 0)>0 end,function()
          print('PASSIVES_NATURAL_BLOODGUARD_OK '..json.encode(state().runtime))
          local initialWard=state().runtime.ward
          shoot('passives-combat-04-bloodguard-shield',function()
            measure(selfName,function(m) assert(m.profile.ranks.cap_bloodguard==1 and (m.ward or 0)<=math.floor(m.maxHP*.06),'native shield limit/profile invalid') end,function()
              measureUntil(selfName,function(m) return m.ward<initialWard and m.wardMs>0 end,function()
                print('PASSIVES_WARD_ABSORPTION_OK')
                weaponCleanup()
              end)
            end)
          end)
        end,30000)
      end)
    end)
  end)
end
local function bloodletting()
  quiet(function()
    commands({'/passivetest preset '..selfName..', bloodletting','/passivetest trace '..selfName..',on'},function()
      assert(state().ranks.cap_bloodletting==1,'Bloodletting preset missing')
      arena(function()
        waitFor('three natural owned wounds',function() return (state().runtime.bleedStacks or 0)==3 end,function()
          print('PASSIVES_NATURAL_THREE_WOUNDS_OK '..json.encode(state().runtime))
          shoot('passives-combat-02-three-owned-wounds',function()
            measureUntil(selfName,function(m) return m.ownStacks==3 and m.allStacks>=6 end,function()
              sharedTargetId=metrics.targetId
              measureUntil('Passive Peer',function(m) return m.ownStacks==3 end,function()
                assert(metrics.targetId==sharedTargetId,'the two owners attacked different targets')
                talk('/passivetest stop '..selfName)
                later(600,function()
                  assert(not state().active,'stop retained own overlay')
                  measure(selfName,function(m) assert(m.ownStacks==0 and m.allStacks>=1,'stop removed wrong owner wounds') end,function()
                    shoot('passives-combat-03-owner-cleanup',function()
                      g_game.cancelAttack(); talk('/passiveqa stop Passive Peer')
                      later(400,function()
                        talk('/passiveqa cure')
                        later(400,function()
                          measure('Passive Peer',function(m) assert(m.allStacks==0,'cure retained wounds') end,bloodguard)
                        end)
                      end)
                    end)
                  end)
                end)
              end)
            end)
          end)
        end,45000)
      end,true)
    end)
  end)
end
local function berserker()
  commands({'/passivetest start reaver','/passivetest preset '..selfName..', berserker','/passivetest trace '..selfName..',on'},function()
    assert(state().ranks.cap_berserker==1,'Berserker preset missing')
    local p=g_game.getLocalPlayer()
    assert(p:getMaxHealth()>735 and p:getHealth()<=735,'derived max HP healed or failed')
    arena(function()
      waitFor('ten real axe hits reach Berserker',function() return (state().runtime.berserkUntil or 0)>g_clock.millis()+1000 end,function()
        assert((state().runtime.rage or 0)==0,'rage not consumed in Berserker')
        print('PASSIVES_NATURAL_BERSERKER_OK '..json.encode(state().runtime))
        shoot('passives-combat-01-natural-berserker',bloodletting)
      end,50000)
    end)
  end)
end
local function online()
  EnterGame.hide()
  connect(g_game,{onTextMessage=function(_,text)
    print('PASSIVES_COMBAT_MESSAGE '..text)
    local payload=text:match('^PASSIVEQA_METRICS (.+)$')
    if payload then local ok,m=pcall(json.decode,payload); if ok then metrics=m end end
  end})
  waitFor('real handshake',function() return state().ready end,function()
    commands({'/passiveqa quiesce '..selfName,'/passiveqa equip reaver','/passiveqa heal '..selfName},PASSIVES_COMBAT_PHASE=='ward' and bloodguard or berserker)
  end,12000)
end
local function begin()
  assert(LOCAL_PASSIVES_TEST and Services.updater=='' and g_resources.getLayout()=='retro')
  mod=assert(modules.game_passives)
  mod.setStatusVisible(true)
  g_settings.set('window-maximized',false); g_window.resize({width=1280,height=800})
  connect(g_game,{onGameStart=function() later(300,online) end,onConnectionError=function(err) if not finished then fail(err) end end})
  g_game.setClientVersion(860); g_game.setProtocolVersion(860); g_game.setRsa(OTSERV_RSA)
  G.account='passivetest';G.password='passivetest'
  login=ProtocolLogin.create(); _G.passivesCombatLogin=login
  login.onLoginError=function(_,err) fail(err) end
  login.onCharacterList=function(_,chars)
    for _,c in ipairs(chars) do if c.name==selfName then g_game.loginWorld(G.account,G.password,c.worldName,c.worldIp,c.worldPort,c.name,'',''); return end end
    fail('character not found')
  end
  login:login('127.0.0.1',7174,G.account,G.password,'',false)
end
later(200,begin)
scheduleEvent(function() if not finished then fail('180 second combat timeout') end end,180000)
