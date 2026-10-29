local receipts,done,failed,lastChoice={ },false,false,nil
local reconnecting,finishing,lastWorld=false,false,nil
local function fail(reason)if failed then return end;failed=true;print('ANCIENTS_UI_FAILED '..tostring(reason));g_app.exit()end
local function later(ms,fn)scheduleEvent(function()if failed or done then return end;local ok,e=xpcall(fn,debug.traceback);if not ok then fail(e)end end,ms)end
local function wait(label,test,nextStep)
  local deadline=g_clock.millis()+12000
  local function poll()local result=test();if result then nextStep(result);return end;assert(g_clock.millis()<deadline,label..' timed out');later(80,poll)end
  later(100,poll)
end
local function qa(action,label,nextStep)
  local before=receipts[label or action];g_game.talk('/ancientsqa '..action)
  wait(action,function()return receipts[label or action]~=before and receipts[label or action]end,nextStep)
end
local function window()local w=rootWidget:getChildById('questRewardWindow');return w and w:isVisible()and w end
local function clickChest(nextStep)
  local c=receipts.reset.chest
  wait('mapped chest',function()local tile=g_map.getTile(c);return tile and tile:getTopUseThing()end,function(item)
    g_game.use(item);wait('reward UI',window,nextStep)
  end)
end
local function state(nextStep)qa('state','state',nextStep)end
local function finish()
  local function logout()
    finishing=true;g_game.safeLogout()
    wait('logout',function()return not g_game.isOnline()end,function()
      done=true;print('ANCIENTS_UI_NATIVE_OK selectedRod=true selectedWand=true duplicateDenied=true capRetry=true exchange=true inlineInfo=true equipChecks='..(ANCIENTS_DETAILS_ONLY and 0 or 336));g_app.exit()
    end)
  end
  if ANCIENTS_DETAILS_ONLY then qa('rest','rest',logout)
  else qa('levels','levels',function(r)
    assert(r.checked==336 and r.ordinaryKnifeChecks==6,'native level coverage');logout()
  end)end
end
local function reconnect()
  qa('rest','rest',function()
    reconnecting=true;finishing=true;g_game.safeLogout()
    wait('first logout',function()return not g_game.isOnline()end,function()
      later(400,function()
        local c=lastWorld
        g_game.loginWorld(G.account,G.password,c.worldName,c.worldIp,c.worldPort,c.name,'','')
      end)
    end)
  end)
end
local function legacy()
  qa('legacy','legacy',function()
    g_game.talkChannel(MessageModes.NpcTo,0,'hi')
    later(1600,function()
      g_game.talkChannel(MessageModes.NpcTo,0,'ssythari')
      later(1800,function()
        g_game.talkChannel(MessageModes.NpcTo,0,'yes')
        later(1800,function()state(function(r)
          assert(r.rods==1 and r.wands==0 and r.choice==2 and r.claim==1,'actual Plipus exchange')
          assert(r.affixes.totals['14']==9 and r.affixes.totals['35']==3,'exchange lost enchantments')
          reconnect()
        end)end)
      end)
    end)
  end)
end
local function wand()
  qa('reset','reset',function()clickChest(function(w)
    modules.game_questreward.selectChoice('wand');modules.game_questreward.confirm()
    wait('wand delivery',function()return not window()end,function()state(function(r)
      assert(r.vocation==0 and r.wands==1 and r.rods==0 and r.choice==1,'pre-Ascension wand branch');legacy()
    end)end)
  end)end)
end
local function capacity()
  qa('reset','reset',function()qa('capzero','capzero',function()clickChest(function(w)
    modules.game_questreward.selectChoice('rod');modules.game_questreward.confirm()
    wait('capacity refusal',function()return w:recursiveGetChildById('confirm'):isEnabled()end,function()
      state(function(r)
        assert(r.rods==0 and r.claim==-1,'refusal consumed claim')
        qa('capok','capok',function()
          modules.game_questreward.confirm()
          wait('retry delivery',function()return not window()end,function()state(function(r)
            assert(r.rods==1 and r.claim==1,'native CAP retry');wand()
          end)end)
        end)
      end)
    end)
  end)end)end)
end
local function rod()
  clickChest(function(w)
    for _,key in ipairs({'wand','rod'})do
      local row=w:getChildById(key)
      assert(row:getChildById('role'):getText()==(key=='wand'and 'Wand'or 'Rod')..' | Death | Level 13','weapon type without implying class requirement')
      assert(row:getChildById('summary'):getText():find('8-15 death damage | 4 mana',1,true),'inline base damage and mana')
      assert(row:getChildById('bonuses'):getText()=='Epic: +6 death damage | +1 Mana Regen','inline actual reward bonuses')
    end
    assert(not w:recursiveGetChildById('look'),'No extra Look button')
    modules.game_questreward.selectChoice('wand')
    g_window.resize({width=1280,height=800})
    later(700,function()
      g_app.doScreenshot('/ancients-choice-1280.png')
      g_window.resize({width=800,height=640});modules.game_questreward.selectChoice('rod')
      later(700,function()
        g_app.doScreenshot('/ancients-choice-800.png')
        modules.game_questreward.cancel()
        state(function(r)
          assert(r.claim==-1 and r.rods==0 and r.wands==0,'cancel consumed reward')
          clickChest(function()
            modules.game_questreward.selectChoice('rod');modules.game_questreward.confirm();modules.game_questreward.confirm()
            wait('rod delivery',function()return not window()end,function()
              assert(lastChoice);g_game.getProtocolGame():sendExtendedOpcode(106,json.encode(lastChoice))
              state(function(r)
                assert(r.vocation==0 and r.claim==1 and r.choice==2 and r.rods==1 and r.wands==0,'pre-Ascension rod branch and duplicate denial')
                assert(r.affixes.totals['14']==6 and r.affixes.totals['35']==1,'new rod fixed affixes');capacity()
              end)
            end)
          end)
        end)
      end)
    end)
  end)
end
later(300,function()
  assert(LOCAL_PASSIVES_TEST and Services.updater=='','loopback QA only')
  local original=ProtocolGame.sendExtendedOpcode
  ProtocolGame.sendExtendedOpcode=function(self,op,buffer)
    if op==106 then local m=json.decode(buffer);if m.action=='choose'then lastChoice=m end end
    return original(self,op,buffer)
  end
  connect(g_game,{onGameStart=function()EnterGame.hide();later(600,function()
      finishing=false
      if reconnecting then
        state(function(r)
          assert(r.claim==1 and r.choice==2 and r.rods==1 and r.wands==0,'persisted reward/claim')
          assert(r.affixes.totals['14']==9 and r.affixes.totals['35']==3,'persisted affixes')
          reconnecting=false;finish()
        end)
        return
      end
      if modules.game_passives and modules.game_passives.getClassChoice then modules.game_passives.getClassChoice().cancel()end
      qa('reset','reset',rod)
    end)end,
    onTextMessage=function(_,text)
      local raw=text:match('^ANCIENTS_NATIVE (.+)$');if raw then local r=json.decode(raw);if r.label=='FAILED'then fail(r.reason)else receipts[r.label]=r end end
      if not raw then print('ANCIENTS_NOTICE '..text)end
    end,onLoginError=fail,onConnectionError=function(e)if not done and not finishing then fail(e)end end})
  g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
  G.account,G.password='ancientsqa','AncientsLoopbackOnly'
  local login=ProtocolLogin.create();_G.ancientsLogin=login;login.onLoginError=function(_,e)fail(e)end
  login.onCharacterList=function(_,characters)
    for _,c in ipairs(characters)do if c.name=='Passive Tester'then
      assert(c.worldIp=='127.0.0.1'and c.worldPort==7186,'QA endpoint')
      lastWorld=c
      g_game.loginWorld(G.account,G.password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return
    end end;fail('owned character absent')
  end
  login:login('127.0.0.1',7185,G.account,G.password,'',false)
end)
scheduleEvent(function()if not done then fail('native timeout')end end,110000)
