-- GUID9006 ordinary Bloodletting; runner temporarily gives ONLY runtime1494
-- physical MagicField semantics. The XML bytes and owned tiles are restored.
local mod,login,metrics
local seq=0
local done,failed,intentional=false,false,false
local function fail(e)
 if done or failed then return end;failed=true;print('PASSIVES_FINITE_FIELD_FAILED '..tostring(e))
 if g_game.isOnline()then g_game.talk('/classspellqa rend cleanup');g_game.safeLogout()else g_game.cancelLogin()end
 scheduleEvent(function()g_app.exit()end,700)
end
local function later(ms,fn)scheduleEvent(function()if done or failed then return end;local ok,e=pcall(fn);if not ok then fail(e)end end,ms)end
local function wait(label,pred,fn)
 local deadline=g_clock.millis()+14000
 local function poll()if pred()then fn();return end;assert(g_clock.millis()<deadline,label..' timeout');later(80,poll)end
 later(120,poll)
end
local function qa(op,fn)
 local before=seq;g_game.talk('/classspellqa rend '..op)
 wait('field diagnostic '..op,function()return seq>before end,function()fn(metrics)end)
end
local function online()
 EnterGame.hide();wait('permanent handshake',function()local s=mod.getState();return s.ready and s.active end,function()
  local s=mod.getState();assert(s.mode=='permanent'and s.tree.id=='reaver'and s.ranks.cap_bloodletting==1,'Run ordinary Rend regression first to allocate its legitimate Bloodletting build')
  qa('field',function(before)
   -- The shared fixture selects its target for Rend; this case measures only
   -- the two real conditions, so cancel ordinary autos before pacification ends.
   g_game.cancelAttack()
   assert(before.field.specialField and before.field.legacyField,'Two real fields required')
   assert(before.ownStacks==1 and before.allStacks==1 and before.field.legacyStacks==1,'Both initial conditions required')
   later(4500,function()qa('state',function(after)
    assert(after.field.specialField and after.field.legacyField,'Fields removed before the finite/legacy comparison')
    assert(after.field.specialDamage==2 and after.ownStacks==0 and after.allStacks==0,'Finite Bloodletting repeated damage or survived expiry on a physical field')
    assert(after.field.legacyDamage>=3 and after.field.legacyStacks==1,'Legacy physical-field-held repetition changed')
    print('PASSIVES_FINITE_FIELD_EVIDENCE '..json.encode(after))
    intentional=true;g_game.talk('/classspellqa rend cleanup');g_game.talk('/classspellqa cleanup')
    later(300,function()g_game.safeLogout();wait('logout',function()return not g_game.isOnline()end,function()
     done=true;print('PASSIVES_FINITE_FIELD_OK finite budget2 expired; legacy remains field-held');scheduleEvent(function()g_app.exit()end,350)
    end)end)
   end)end)
  end)
 end)
end
later(200,function()
 assert(LOCAL_PASSIVES_TEST and Services.updater==''and g_resources.getLayout()=='retro')
 mod=assert(modules.game_passives)
 connect(g_game,{
  onGameStart=online,
  onTextMessage=function(_,text)
   print('PASSIVES_FINITE_FIELD_MESSAGE '..text)
   if text:find('CLASS_SPELL_QA_FAILED',1,true)then fail(text)end
   local raw=text:match('^REND_BLEED_QA (.+)$');if raw then metrics=json.decode(raw);seq=seq+1 end
  end,
  onLoginError=function(e)fail(e)end,onConnectionError=function(e)if not intentional then fail(e)end end,
 })
 G.account,G.password='classreaver','classreaver'
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 login=ProtocolLogin.create();_G.finiteFieldLogin=login
 login.onLoginError=function(_,e)fail(e)end
 login.onCharacterList=function(_,list)
  for _,c in ipairs(list)do if c.name=='Starter Reaver'then g_game.loginWorld(G.account,G.password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return end end;fail('Fixed ordinary Reaver fixture missing')
 end
 login:login('127.0.0.1',7174,G.account,G.password,'',false)
end)
scheduleEvent(function()if not done then fail('finite physical-field timeout')end end,35000)
