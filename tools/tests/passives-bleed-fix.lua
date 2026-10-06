-- Exact native budgets, stacking/replacement/cure, normal proc and bleed-only immunity.
local failed,finished=false,false
local metrics,mod,login,suite,replacement,immune
local name='Passive Tester'
local function fail(reason)
 if failed or finished then return end;failed=true
 print('PASSIVES_BLEED_BUDGET_FAILED '..tostring(reason))
 if g_game.isOnline()then g_game.cancelAttack();g_game.talk('/passiveqa cleanup')end
 scheduleEvent(function()g_app.exit()end,600)
end
local function later(ms,fn)
 scheduleEvent(function()if failed or finished then return end;local ok,err=pcall(fn);if not ok then fail(err)end end,ms)
end
local function waitFor(label,predicate,nextStep,timeout)
 local deadline=g_clock.millis()+(timeout or 10000)
 local function poll()if predicate()then later(100,nextStep);return end;assert(g_clock.millis()<deadline,label..' timeout');later(100,poll)end
 later(1,poll)
end
local function commands(list,nextStep)
 local function run(n)if n>#list then later(500,nextStep);return end;g_game.talk(list[n]);later(300,function()run(n+1)end)end
 run(1)
end
local function measure(nextStep)
 metrics=nil;g_game.talk('/passiveqa metrics '..name)
 waitFor('metrics',function()return metrics~=nil end,function()print('PASSIVES_BLEED_BUDGET_METRICS '..json.encode(metrics));nextStep(metrics)end)
end
local function complete()
 commands({'/passiveqa cleanup','/passiveqa quiesce '..name,'/passivetest stop '..name},function()
  finished=true;g_game.safeLogout();scheduleEvent(function()print('PASSIVES_BLEED_FIX_OK');g_app.exit()end,1000)
 end)
end
local function probe()
 commands({'/passiveqa quiesce '..name,'/passiveqa equip reaver','/passiveqa heal '..name,
  '/passivetest start reaver','/passivetest preset '..name..',bloodletting','/passiveqa bleedsuite'},function()
  assert(mod.getState().ranks.cap_bloodletting==1,'Bloodletting preset missing')
  waitFor('36 finite bleed budgets',function()return suite~=nil and replacement~=nil and immune~=nil end,function()
   assert(suite.ok and #suite.rows==36,'One or more exact native bleed budgets failed: '..json.encode(suite))
   assert(replacement.ok and replacement.actual==15 and replacement.stacks==0,'Three-stack/stronger replacement budget failed')
   assert(not immune.accepted and immune.ownStacks==0 and immune.allStacks==0,'Bleed-only immune phantom wound accepted')
   print('PASSIVES_BLEED_FIX_BUDGETS_OK cases=36 budgets=1..12 durations=18000,12500,17000 replacement=15')
   commands({'/passiveqa cleanup','/passiveqa arena','/passiveqa join '..name..',1','/passiveqa attack '..name},function()
    local function natural()
     measure(function(m)
      if m.ownStacks>0 then
       assert(m.ownStacks<=3,'Native wound limit exceeded');g_game.cancelAttack();g_game.talk('/passiveqa stop '..name)
       print('PASSIVES_BLEED_FIX_NATURAL_TRIGGER_OK stacks='..m.ownStacks)
       later(20500,function()measure(function(after)
        assert(after.ownStacks==0,'Native wound did not expire')
        commands({'/passiveqa cleanup','/passiveqa arena','/passiveqa join '..name..',1','/passiveqa bleedimmunearena'},function()
         measure(function(before)
          commands({'/passiveqa attack '..name},function()
           later(8500,function()g_game.cancelAttack();g_game.talk('/passiveqa stop '..name);measure(function(afterImmune)
            assert(afterImmune.targetHP<before.targetHP,'Immune fixture must still take ordinary physical damage')
            assert(afterImmune.ownStacks==0 and afterImmune.allStacks==0,'Natural Bloodletting counted an immune wound')
            print('PASSIVES_BLEED_FIX_NATURAL_IMMUNITY_OK ownStacks=0 rendOwnWoundGate=false')
            complete()
           end)end)
          end)
         end)
        end)
       end)end)
      else later(700,natural)end
     end)
    end
    natural()
   end)
  end,27000)
 end)
end
local function online()
 EnterGame.hide()
 connect(g_game,{onTextMessage=function(_,text)
  print('PASSIVES_BLEED_BUDGET_MESSAGE '..text);local m=text:match('^PASSIVEQA_METRICS (.+)$');if m then metrics=json.decode(m)end
  local a=text:match('^PASSIVEQA_BLEED_SUITE (.+)$');if a then suite=json.decode(a)end
  local b=text:match('^PASSIVEQA_BLEED_REPLACEMENT (.+)$');if b then replacement=json.decode(b)end
  local c=text:match('^PASSIVEQA_BLEED_IMMUNE (.+)$');if c then immune=json.decode(c)end
 end})
 waitFor('handshake',function()return mod.getState().ready end,probe)
end
local function begin()
 assert(LOCAL_PASSIVES_TEST and Services.updater=='' and g_resources.getLayout()=='retro');mod=assert(modules.game_passives)
 connect(g_game,{onGameStart=function()later(300,online)end,onConnectionError=function(err)if not finished then fail(err)end end})
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 G.account='passivetest';G.password='passivetest';login=ProtocolLogin.create();_G.bleedBudgetLogin=login
 login.onLoginError=function(_,err)fail(err)end
 login.onCharacterList=function(_,chars)
  for _,c in ipairs(chars)do if c.name==name then g_game.loginWorld(G.account,G.password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return end end
  fail('Fixture character unavailable')
 end
 login:login('127.0.0.1',7174,G.account,G.password,'',false)
end
later(200,begin)
scheduleEvent(function()if not finished then fail('125 second native regression timeout')end end,125000)
