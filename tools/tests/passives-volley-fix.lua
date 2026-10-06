-- Real legacy Volley: both hands, exact mana/ammo/CD and rejection paths.
local failed,finished=false,false
local metrics,mod,login
local name='Passive Tester'
local function fail(reason)
 if failed or finished then return end;failed=true
 print('PASSIVES_VOLLEY_FIX_FAILED '..tostring(reason))
 if g_game.isOnline()then g_game.cancelAttack();g_game.talk('/passiveqa cleanup')end
 scheduleEvent(function()g_app.exit()end,600)
end
local function later(ms,fn)
 scheduleEvent(function()if failed or finished then return end;local ok,err=pcall(fn);if not ok then fail(err)end end,ms)
end
local function waitFor(label,predicate,nextStep)
 local deadline=g_clock.millis()+10000
 local function poll()if predicate()then later(100,nextStep);return end;assert(g_clock.millis()<deadline,label..' timeout');later(100,poll)end
 later(1,poll)
end
local function commands(list,nextStep)
 local function run(n)if n>#list then later(500,nextStep);return end;g_game.talk(list[n]);later(300,function()run(n+1)end)end
 run(1)
end
local function measure(nextStep)
 metrics=nil;g_game.talk('/passiveqa metrics '..name)
 waitFor('metrics',function()return metrics~=nil end,function()print('PASSIVES_VOLLEY_FIX_METRICS '..json.encode(metrics));nextStep(metrics)end)
end
local function complete()
 commands({'/passiveqa cleanup','/passiveqa quiesce '..name,'/passivetest stop '..name},function()
  finished=true;g_game.safeLogout();scheduleEvent(function()print('PASSIVES_VOLLEY_FIX_OK');g_app.exit()end,1000)
 end)
end
local function probe()
 commands({'/passiveqa quiesce '..name,'/passiveqa equip marksman','/passivetest start marksman','/passiveqa arena','/passiveqa join '..name..',1'},function()
  local cases={{id='left',mana=40,ammo=3,hits=true},{id='right',mana=40,ammo=3,hits=true},
   {id='few',mana=40,ammo=2,hits=true},{id='none',mana=0,ammo=0,hits=false},
   {id='noammo',mana=0,ammo=0,hits=false},{id='wrongammo',mana=0,ammo=0,hits=false},
   {id='lowmana',mana=0,ammo=0,hits=false},{id='away',mana=0,ammo=0,hits=false}}
  local function step(index)
   if index>#cases then complete();return end
   local case=cases[index]
   commands({'/passiveqa volleyfixture '..case.id},function()
    later(2600,function()measure(function(before)
     g_game.talk('exevo gran sagitta')
     later(550,function()measure(function(after)
      assert(before.mana-after.mana==case.mana,case.id..' Volley mana billing wrong')
      assert(before.ammo-after.ammo==case.ammo,case.id..' Volley ammo billing wrong')
      assert((after.targetHP<before.targetHP)==case.hits,case.id..' Volley primary damage/rejection wrong')
      print('PASSIVES_VOLLEY_FIX_CASE_OK '..case.id..' mana='..case.mana..' ammo='..case.ammo)
      if case.id=='left'then
       g_game.talk('exevo gran sagitta');later(400,function()measure(function(rejected)
        assert(rejected.mana==after.mana and rejected.targetHP==after.targetHP,'Volley cooldown recast must not damage or pay')
        print('PASSIVES_VOLLEY_FIX_COOLDOWN_OK cooldown=2000')
        step(index+1)
       end)end)
      else step(index+1)end
     end)end)
    end)end)
   end)
  end
  step(1)
 end)
end
local function online()
 EnterGame.hide()
 connect(g_game,{onTextMessage=function(_,text)
  print('PASSIVES_VOLLEY_FIX_MESSAGE '..text);local m=text:match('^PASSIVEQA_METRICS (.+)$');if m then metrics=json.decode(m)end
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
