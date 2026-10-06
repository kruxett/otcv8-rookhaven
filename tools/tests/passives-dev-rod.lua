-- Normal purchased rod: actual weapon autos and authoritative HP/mana observations.
-- A separately gated disposable-runtime helper arranges the target and reads HP.
local done,failed,login,player,metrics=false,false,nil,nil,nil
local seq=0
local function fail(reason)
 if done or failed then return end;failed=true;print('PASSIVES_DEV_ROD_FAILED '..tostring(reason))
 if g_game.isOnline()then g_game.cancelAttack();g_game.talk('/passivedevrod cleanup');g_game.safeLogout()end
 scheduleEvent(function()g_app.exit()end,500)
end
local function later(ms,fn)scheduleEvent(function()if done or failed then return end;local ok,e=pcall(fn);if not ok then fail(e)end end,ms)end
local function wait(label,pred,fn)
 local deadline=g_clock.millis()+14000
 local function poll()if pred()then fn();return end;assert(g_clock.millis()<deadline,label..' timeout');later(100,poll)end
 later(100,poll)
end
local function observe(action,fn)
 local before=seq;g_game.talk('/passivedevrod '..action)
 wait('observer '..action,function()return seq>before and metrics.label==action end,function()fn(metrics)end)
end
local function target()
 for _,c in ipairs(g_map.getSpectators(player:getPosition(),false))do if c:getId()==metrics.targetId then return c end end
 error('Prepared target absent')
end
local function finish()
 observe('cleanup',function()done=true;print('PASSIVES_DEV_ROD_OK ordinaryPurchasedRod=2182 exactAutoDamage=2..5 manaPerHit=2 zeroManaDenied=true starterCast=true')
 g_game.safeLogout();scheduleEvent(function()g_app.exit()end,400)end)
end
local function test()
 player=assert(g_game.getLocalPlayer())
 observe('prepare',function(before)
  assert(before.group==1 and before.weaponId==2182 and before.money==0 and before.classId=='lifekeeper','Purchased ordinary rod baseline missing')
  assert(before.mana==40 and before.hp>0,'Uncontrolled baseline')
  -- Allow the ordinary login pacification to expire, without removing it.
  later(11000,function()
   local enemy=target();g_game.attack(enemy)
   local function sample()
    observe('state',function(m)
     if m.hp==before.hp then later(100,sample);return end
     g_game.cancelAttack();local damage=before.hp-m.hp
     assert(damage>=2 and damage<=5,'Native rod autoroll differs from2..5: '..damage)
     assert(before.mana-m.mana==2,'Native rod did not spend exactly2mana')
     print('PASSIVES_DEV_ROD_AUTO_OK actualDamage='..damage..' manaSpent=2')
     observe('zero',function(zero)
      assert(zero.mana==1,'Expected insufficient1mana');g_game.attack(enemy)
      later(4300,function()g_game.cancelAttack();observe('state',function(after)
       assert(after.hp==zero.hp and after.mana==1,'Insufficient-mana auto dealt damage or billed mana')
       observe('spell',function(b)
        g_game.talk('exori vita')
        wait('learned Essence Lash payment',function()return player:getMana()<b.mana end,function()
         observe('state',function(c)
          assert(b.mana-c.mana==12 and c.hp<b.hp,'Ordinary purchased rod did not support learned Essence Lash')
          finish()
         end)
        end)
       end)
      end)end)
     end)
    end)
   end
   sample()
  end)
 end)
end
later(200,function()
 assert(LOCAL_PASSIVES_TEST and Services.updater=='','Disposable local probe required')
 connect(g_game,{onGameStart=function()later(300,test)end,onTextMessage=function(_,text)
  local payload=text:match('^PASSIVE_DEV_ROD (.+)$');if payload then metrics=json.decode(payload);seq=seq+1 end
  if text:find('^PASSIVE_DEV_ROD_FAILED')then fail(text)end
 end,onLoginError=fail})
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 G.account='passivemagic';G.password=G.account;login=ProtocolLogin.create();_G.devRodLogin=login
 login.onLoginError=function(_,e)fail(e)end
 login.onCharacterList=function(_,list)for _,c in ipairs(list)do if c.name=='Passive Mystic'then g_game.loginWorld(G.account,G.password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return end end;fail('Owned fixture absent')end
 login:login('127.0.0.1',7174,G.account,G.password,'',false)
end)
scheduleEvent(function()if not done then fail('Bounded60second timeout')end end,58000)
