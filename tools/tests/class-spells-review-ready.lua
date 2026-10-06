-- Clean, actual retro-client screenshots of the ordinary saved class delivery.
local tree=PASSIVES_PROBE_TREE or 'lifekeeper'
local classNames={reaver='Reaver',blademaster='Blademaster',earthshaker='Earthshaker',marksman='Marksman',arcanist='Arcanist',lifekeeper='Lifekeeper'}
local done,failed=false,false
local function fail(reason)
  if failed or done then return end
  failed=true;print('CLASS_SPELLS_REVIEW_FAILED '..tostring(reason))
  if g_game.isOnline()then g_game.cancelAttack();g_game.safeLogout()end
  scheduleEvent(function()g_app.exit()end,650)
end
local function later(ms,fn)
  scheduleEvent(function()if failed or done then return end;local ok,e=pcall(fn);if not ok then fail(e)end end,ms)
end
local function capture()
  local mod=assert(modules.game_passives);local spells=assert(mod.ClassSpells)
  local deadline=g_clock.millis()+12000
  local function ready()
    local state=mod.getState();local catalog=spells.getState().catalog
    if not(state.ready and state.active and state.mode=='permanent'and state.classId==tree and catalog)then
      assert(g_clock.millis()<deadline,'Ordinary saved class metadata timeout');later(80,ready);return
    end
    assert(#catalog.spells==2,'Ordinary class lacks two learned starters')
    mod.hide();mod.setStatusVisible(false);assert(spells.show())
    modules.game_console.clear()
    later(500,function()
      local window=assert(spells.getWindow())
      for _,entry in ipairs(catalog.spells)do
        local icon=assert(spells.getCard(entry.id)):getChildById('icon')
        assert(icon:getWidth()==32 and icon:getHeight()==32,'Native icon dimensions changed')
      end
      g_app.doScreenshot('/class-spells-'..tree..'-review-ready.png')
      g_window.resize({width=800,height=640})
      later(500,function()
        local r=window:getRect();local root=g_ui.getRootWidget():getRect()
        assert(r.x>=root.x and r.y>=root.y and r.x+r.width<=root.x+root.width and r.y+r.height<=root.y+root.height,'Retro spell window escaped small viewport')
        g_app.doScreenshot('/class-spells-'..tree..'-review-small.png')
        g_window.resize({width=1280,height=800})
        g_game.safeLogout()
        local logoutDeadline=g_clock.millis()+5000
        local function finish()
          if g_game.isOnline()then assert(g_clock.millis()<logoutDeadline,'Clean review logout timeout');later(80,finish);return end
          assert(not spells.getWindow()and not spells.getButton()and not spells.getState().catalog,'Review logout retained class UI')
          done=true;print('CLASS_SPELLS_REVIEW_OK '..tree);g_app.exit()
        end
        later(200,finish)
      end)
    end)
  end
  later(300,ready)
end
later(250,function()
  assert(LOCAL_PASSIVES_TEST and Services.updater==''and g_resources.getLayout()=='retro')
  g_settings.set('window-maximized',false);g_window.resize({width=1280,height=800})
  connect(g_game,{onGameStart=function()EnterGame.hide();capture()end,onLoginError=function(e)fail(e)end})
  g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
  G.account='class'..tree;G.password=G.account
  local login=ProtocolLogin.create();_G.classSpellsReviewLogin=login
  login.onLoginError=function(_,e)fail(e)end
  login.onCharacterList=function(_,list)
    for _,c in ipairs(list)do if c.name=='Starter '..assert(classNames[tree])then
      g_game.loginWorld(G.account,G.password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return
    end end
    fail('Ordinary class review account missing')
  end
  login:login('127.0.0.1',7174,G.account,G.password,'',false)
end)
scheduleEvent(function()if not done then fail('40-second clean review limit')end end,40000)
