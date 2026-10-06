-- Verify the documented manual preview commands without choosing a class.
local mod,choice,login,done,failed,intentional
local function fail(e)
 if done or failed then return end;failed=true;print('CLASS_CHOICE_REVIEW_FAILED '..tostring(e))
 if g_game.isOnline()then g_game.safeLogout()end;scheduleEvent(function()g_app.exit()end,500)
end
local function later(ms,fn)
 scheduleEvent(function()if done or failed then return end;local ok,e=pcall(fn);if not ok then fail(e)end end,ms)
end
local function wait(label,predicate,fn)
 local limit=g_clock.millis()+15000
 local function poll()if predicate()then fn();return end;assert(g_clock.millis()<limit,label..' timeout');later(80,poll)end
 later(100,poll)
end
later(250,function()
 mod=assert(modules.game_passives);choice=assert(mod.getClassChoice())
 g_settings.set('window-maximized',false);g_window.resize({width=1280,height=800})
 connect(g_game,{onGameStart=function()
  EnterGame.hide();wait('handshake',function()return mod.getState().ready end,function()
   g_game.talk('/passivetest stop')
   later(250,function()g_game.talk('/goto The Nameless')
    later(400,function()g_game.talkChannel(MessageModes.NpcTo,0,'hi')
     wait('manual class choice window',function()return choice.getWindow()and choice.getWindow():isVisible()end,function()
      local s=choice.getDebugState();local n=0
      for _,info in pairs(s.classes)do if info.allowed then n=n+1 end end
      assert(n==6,'Manual preview does not offer all six classes')
      assert(choice.selectLocal('reaver'));assert(not mod.getState().active,'Preview created a class')
      later(400,function()
       g_app.doScreenshot('/class-choice-review-ready.png')
       choice.cancel();assert(not choice.getWindow()and not choice.getConfirmation(),'Manual Close did not cancel')
       assert(not mod.getState().active,'Close granted a class')
       intentional=true;g_game.safeLogout();wait('logout',function()return not g_game.isOnline()end,function()
        done=true;print('CLASS_CHOICE_REVIEW_READY_OK');g_app.exit()
       end)
      end)
     end)
    end)
   end)
  end)
 end,onLoginError=fail,onConnectionError=function(e)if not done and not intentional then fail(e)end end})
 g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
 G.account,G.password='passivetest','passivetest'
 login=ProtocolLogin.create();_G.classChoiceReviewLogin=login
 login.onLoginError=function(_,e)fail(e)end
 login.onCharacterList=function(_,list)
  for _,c in ipairs(list)do if c.name=='Passive Tester'then
   g_game.loginWorld(G.account,G.password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return
  end end;fail('Manual admin fixture absent')
 end
 login:login('127.0.0.1',7174,G.account,G.password,'',false)
end)
