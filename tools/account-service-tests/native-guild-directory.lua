-- Owned loopback discovery and management integration. Never sends a chat message.
local done,failed,expectedLogout=false,false,false
local window,loginReady
local function fail(e)
  if failed then return end;failed=true;print('GUILDS_DIRECTORY_FAILED '..tostring(e))
  g_app.doScreenshot('/accounts-directory-failure.png');scheduleEvent(function()g_app.exit()end,400)
end
local function later(ms,fn)scheduleEvent(function()if done or failed then return end;local ok,e=xpcall(fn,debug.traceback);if not ok then fail(e)end end,ms)end
local function wait(label,test,nextStep)
  local deadline=g_clock.millis()+15000
  local function poll()local value=test();if value then nextStep(value);return end;assert(g_clock.millis()<deadline,label..' timed out');later(100,poll)end
  later(100,poll)
end
local function W(id)return window:recursiveGetChildById(id)end
local function click(widget)assert(widget and widget:isEnabled(),'control unavailable');signalcall(widget.onClick,widget)end
local function shot(name,nextStep)
  g_window.resize({width=800,height=640});later(200,function()g_app.doScreenshot('/accounts-directory-'..name..'-800.png')
    g_window.resize({width=1280,height=800});later(200,function()g_app.doScreenshot('/accounts-directory-'..name..'-1280.png');g_window.resize({width=800,height=640});nextStep()end)
  end)
end
local function steps(list,index)
  index=index or 1;if not list[index]then return end
  list[index](function()later(100,function()steps(list,index+1)end)end)
end
local function login(account,name,ready)
  loginReady=ready;CharacterList.hide();EnterGame.doLogin(account,'HouseFixtureOnly','','127.0.0.1:7187:860')
  wait('character list',function()return CharacterList.isVisible()and G.characters and G.characters[1]and G.characters[1].name==name end,function()CharacterList.doLogin()end)
end
local function switchLogin(account,name,ready)
  expectedLogout=true;g_game.safeLogout()
  wait('normal logout',function()return not g_game.isOnline()end,function()login(account,name,ready)end)
end
local function profileReady()
  return W('directoryProfile'):isVisible()and W('guildNameLabel'):getText()=='Native Renamed Guild' and W('guildCrest'):getImageTextureWidth()==32
end
local function leaderReview()
  assert(W('emblemPanel'):isVisible()and W('chooseEmblemBtn'):isEnabled(),'leader lost emblem controls')
  assert(W('recruitmentSettings'):isVisible(),'leader cannot set recruitment')
  W('recruitmentStatusBox'):setCurrentOption('Closed to recruitment');click(W('saveRecruitmentBtn'))
  later(600,function()
    click(W('browseGuildsBtn'));W('directorySearch'):setText('Native Renamed Guild')
    wait('recruitment change visible',function()
      local rows=W('directoryGuildList'):getChildren()
      return #rows==1 and rows[1]:recursiveGetChildById('directoryGuildStatus'):getText()=='Closed to recruitment'
    end,function()
      shot('leader-recruitment',function()
        click(W('myGuildBtn'))
        wait('leader management restored',function()return W('infoPanel'):isVisible()and W('emblemPanel'):isVisible()end,function()
          assert(W('recruitmentStatusBox'):getCurrentOption().data==2,'recruitment selection not restored')
          shot('leader-management',function()
            done=true;print('GUILDS_DIRECTORY_NATIVE_OK guildless=true guilded=true profile=true over100=true emblems=true search=true contact=true roleIsolation=true recruitment=true');g_app.exit()
          end)
        end)
      end)
    end)
  end)
end
local function memberReview()
  assert(not W('recruitmentSettings'):isVisible()and not W('emblemPanel'):isVisible(),'member can see leader editors')
  click(W('browseGuildsBtn'));W('directorySearch'):setText('Directory Guild a')
  wait('foreign guild from member',function()return #W('directoryGuildList'):getChildren()==1 end,function()
    click(W('directoryGuildList'):getChildren()[1])
    wait('foreign profile',function()return W('guildNameLabel'):getText()=='Directory Guild a' and W('directoryProfile'):isVisible()end,function()
      assert(not W('infoPanel'):isVisible()and not W('guildTabsRow'):isVisible(),'foreign profile exposes management')
      click(W('myGuildBtn'))
      wait('own member view',function()return W('infoPanel'):isVisible()and W('guildNameLabel'):getText()=='Native Renamed Guild'end,function()
        assert(not W('emblemPanel'):isVisible()and not W('recruitmentSettings'):isVisible(),'public browsing elevated member permissions')
        shot('member-management',function()switchLogin('homebuyer','Home Buyer',leaderReview)end)
      end)
    end)
  end)
end
local function outsiderReview()
  assert(W('noGuildWrapper'):isVisible(),'guildless view missing')
  click(W('browseGuildsBtn'))
  steps({
    function(nextStep)
      wait('public guilds and emblems',function()
        local rows=W('directoryGuildList'):getChildren()
        return #rows==10 and rows[10]:recursiveGetChildById('directoryGuildCrest'):getImageTextureWidth()==32
      end,function()
        assert(not W('guildTabsRow'):isVisible()and W('browseGuildsBtn'):isChecked(),'discovery overlaps management')
        assert(W('directoryListBar'):isVisible(),'overflow list has no scrollbar')
        local area=W('directoryGuildList');area:onMouseWheel({x=area:getX()+5,y=area:getY()+5},MouseWheelDown)
        assert(area:getVirtualOffset().y>0,'public guild list does not scroll')
        shot('guilds',nextStep)
      end)
    end,
    function(nextStep)
      W('directoryRecruitingOnly'):setChecked(true)
      wait('recruiting filter',function()return W('directoryPageLabel'):getText():find('5 guilds',1,true)end,function()
        for _,row in ipairs(W('directoryGuildList'):getChildren())do assert(row:recursiveGetChildById('directoryGuildStatus'):getText()=='Recruiting','non-recruiting guild in filtered list')end
        W('directoryRecruitingOnly'):setChecked(false)
        wait('unfiltered directory restored',function()return W('directoryPageLabel'):getText():find('14 guilds',1,true)end,function()nextStep()end)
      end)
    end,
    function(nextStep)
      click(W('directoryNextBtn'))
      wait('second public page',function()return W('directoryPageLabel'):getText():find('Page 2 / 2',1,true)end,function()
        assert(#W('directoryGuildList'):getChildren()==4 and not W('directoryListBar'):isVisible(),'short page retains scroll or wrong rows')
        shot('second-page',nextStep)
      end)
    end,
    function(nextStep)
      W('directorySearch'):focus();W('directorySearch'):setText('Native Renamed Guild')
      wait('search entire directory',function()return #W('directoryGuildList'):getChildren()==1 end,function()
        assert(W('directorySearch'):isFocused(),'search refresh stole focus')
        assert(not W('directoryListBar'):isVisible(),'one guild has a useless scrollbar')
        click(W('directoryGuildList'):getChildren()[1]);wait('selected public profile',profileReady,function()
          assert(W('guildSummaryLine'):getText():find('152 members',1,true),'wrong guild total')
          assert(#W('directoryMemberList'):getChildren()==10,'foreign roster is not paged')
          assert(not W('infoPanel'):isVisible()and not W('emblemPanel'):isVisible(),'guildless player sees editing controls')
          shot('profile',nextStep)
        end)
      end)
    end,
    function(nextStep)
      W('directoryOnlineOnly'):setChecked(true)
      wait('online-only empty roster',function()return W('directoryStatus'):getText()=='No members match your search.'end,function()
        assert(not W('directoryMemberBar'):isVisible(),'empty online roster has scrollbar')
        W('directoryOnlineOnly'):setChecked(false)
        wait('unfiltered roster restored',function()return #W('directoryMemberList'):getChildren()==10 end,function()nextStep()end)
      end)
    end,
    function(nextStep)
      W('directoryMemberSearch'):setText('Directory Member ft')
      wait('member outside first 100',function()return #W('directoryMemberList'):getChildren()==1 end,function()
        local row=W('directoryMemberList'):getChildren()[1]
        assert(row:recursiveGetChildById('memberName'):getText():find('Arcanist',1,true),'actual permanent class not shown')
        assert(not W('directoryMemberBar'):isVisible(),'single member has a useless scrollbar')
        shot('member-search',nextStep)
      end)
    end,
    function(nextStep)
      W('directoryMemberSearch'):setText('Nobody Matches')
      wait('empty roster filter',function()return W('directoryStatus'):getText()=='No members match your search.'end,function()
        assert(not W('directoryMemberBar'):isVisible(),'empty roster has a scrollbar');nextStep()
      end)
    end,
    function(nextStep)
      click(W('directoryBackBtn'))
      wait('return preserves guild filter',function()return W('directoryFilters'):isVisible()and #W('directoryGuildList'):getChildren()==1 end,function()
        assert(W('directorySearch'):getText()=='Native Renamed Guild','back lost search')
        W('directorySearch'):setText('Nobody Matches')
        wait('empty guild filter',function()return W('directoryStatus'):getText()=='No guilds match your search.'end,function()shot('empty-search',nextStep)end)
      end)
    end,
    function(nextStep)
      W('directorySearch'):setText('Native Renamed Guild')
      wait('restore search',function()return #W('directoryGuildList'):getChildren()==1 end,function()
        click(W('directoryGuildList'):getChildren()[1]);wait('restore profile',profileReady,function()
          click(W('directoryContactBtn'))
          assert(modules.game_console.getTab('Home Buyer'),'contact did not open a normal private chat')
          assert(not rootWidget:recursiveGetChildById('guildWindow'),'contact left an orphan guild window')
          switchLogin('homeseller','Home Seller',memberReview)
        end)
      end)
    end,
  })
end
later(400,function()
  assert(LOCAL_PASSIVES_TEST and Services.updater==''and g_resources.getLayout()=='retro')
  connect(g_game,{onLoginError=fail,onConnectionError=function(e)if not expectedLogout then fail(e)end end,onGameStart=function()
    expectedLogout=false;EnterGame.hide()
    later(650,function()
      if modules.game_outfit.destroy then modules.game_outfit.destroy(true,true)end
      modules.game_guild.toggle()
      wait('initial own guild view',function()
        window=rootWidget:recursiveGetChildById('guildWindow')
        return window and window:isVisible()and (window:recursiveGetChildById('noGuildWrapper'):isVisible()or window:recursiveGetChildById('infoPanel'):isVisible())
      end,function()local ready=loginReady;loginReady=nil;ready()end)
    end)
  end})
  Servers.Default='127.0.0.1:7187:860';EnterGame.onServerChange()
  rootWidget:recursiveGetChildById('rememberPasswordBox'):setChecked(false)
  login('homerival','Home Rival',outsiderReview)
end)
scheduleEvent(function()if not done then fail('directory UI timed out')end end,280000)
