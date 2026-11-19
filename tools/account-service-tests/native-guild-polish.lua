-- Owned loopback member/leader UI review. No real player or normal profile.
local done,failed,expectedLogout=false,false,false
local w,loginReady
local function fail(e)
  if failed then return end;failed=true;print('GUILDS_POLISH_FAILED '..tostring(e))
  g_app.doScreenshot('/accounts-member-review-failure.png');scheduleEvent(function()g_app.exit()end,400)
end
local function later(ms,fn)scheduleEvent(function()if done or failed then return end;local ok,e=xpcall(fn,debug.traceback);if not ok then fail(e)end end,ms)end
local function wait(label,test,nextStep)
  local deadline=g_clock.millis()+15000
  local function poll()local value=test();if value then nextStep(value);return end;assert(g_clock.millis()<deadline,label..' timed out');later(100,poll)end
  later(100,poll)
end
local function W(id)return w:recursiveGetChildById(id)end
local function click(widget)assert(widget and widget:isEnabled(),'control unavailable');signalcall(widget.onClick,widget)end
local function shot(name,nextStep)
  g_window.resize({width=800,height=640});later(200,function()g_app.doScreenshot('/accounts-member-review-'..name..'-800.png')
    g_window.resize({width=1280,height=800});later(200,function()g_app.doScreenshot('/accounts-member-review-'..name..'-1280.png');g_window.resize({width=800,height=640});nextStep()end)
  end)
end
local function steps(list,index)
  index=index or 1
  if not list[index]then return end
  list[index](function()later(80,function()steps(list,index+1)end)end)
end
local function login(account,ready)
  loginReady=ready
  CharacterList.hide()
  EnterGame.doLogin(account,'HouseFixtureOnly','','127.0.0.1:7187:860')
  local expectedName=account=='homeseller' and 'Home Seller' or 'Home Buyer'
  wait('character list',function()return CharacterList.isVisible()and G.characters and G.characters[1]and G.characters[1].name==expectedName end,function()CharacterList.doLogin()end)
end
local function switchLogin(account,ready)
  expectedLogout=true;g_game.safeLogout()
  wait('normal logout',function()return not g_game.isOnline()end,function()login(account,ready)end)
end
local function memberAppearance(emptyDescription)
  assert(w:getHeight()==400,'member window retains management height')
  assert(not W('emblemPanel'):isVisible(),'member can see emblem editor/specification')
  assert(W('guildCrest'):getImageTextureWidth()==32,'member cannot see selected emblem')
  assert(not W('motdEdit'):isVisible(),'description is an editable-looking field for a member')
  if emptyDescription then
    assert(not W('motdReadOnly'):isVisible()and not W('motdTitleLabel'):isVisible(),'empty description leaves a placeholder')
    assert(W('leaveGuildBtn'):getY()-W('infoMemberCount'):getY()-W('infoMemberCount'):getHeight()<=16,'empty description leaves a gap before Leave')
  else
    assert(W('motdReadOnly'):isVisible()and W('motdReadOnly'):getText()=='Native public description','read-only description lost content')
    assert(W('leaveGuildBtn'):getY()-W('motdReadOnly'):getY()-W('motdReadOnly'):getHeight()<=16,'leave action separated by an unnecessary gap')
  end
  assert(not W('invitesTab'):isVisible(),'ordinary member sees invitation management tab')
  local tabGap=W('ranksTab'):getX()-W('membersTab'):getX()-W('membersTab'):getWidth()
  assert(W('ranksTab'):getText()=='Ranks' and tabGap>=0 and tabGap<=3,'hidden invitation tab leaves a gap: '..tabGap)
end
local function leaderReview()
  assert(w:getHeight()==550 and W('emblemPanel'):isVisible(),'leader lost emblem management')
  assert(W('chooseEmblemBtn'):isVisible()and W('chooseEmblemBtn'):isEnabled(),'leader cannot choose emblem image')
  assert(W('motdEdit'):isVisible()and W('saveMotdBtn'):isVisible(),'leader lost description editing')
  assert(W('invitesTab'):isVisible()and W('ranksTab'):getText()=='Ranks & rights','leader lost management tabs')
  shot('leader-overview',function()
    W('motdEdit'):setText('');click(W('saveMotdBtn'))
    later(700,function()
      switchLogin('homeseller',function()
        memberAppearance(true)
        shot('overview-empty-description',function()
          done=true;print('GUILDS_POLISH_NATIVE_OK member=true leader=true noEditorLeak=true compactSpacing=true actualWheelScroll=true overflowOnly=true roleReconnect=true emptyDescription=true');g_app.exit()
        end)
      end)
    end)
  end)
end
local function memberReview()
  memberAppearance()
  steps({
    function(nextStep)shot('overview',nextStep)end,
    function(nextStep)
      click(W('membersTab'))
      wait('member list overflow',function()return #W('membersListPanel'):getChildren()==10 and W('membersScrollBar'):isVisible()end,function()
        assert(not W('inviteNameLabel'):isVisible()and not W('inviteNameField'):isVisible()and not W('inviteBtn'):isVisible(),'orphan invitation controls')
        assert(W('memberSearchField'):getY()-W('membersPanelWrapper'):getY()<=4,'hidden invite controls leave a blank row')
        local area=W('membersListPanel');local before=area:getVirtualOffset().y
        area:onMouseWheel({x=area:getX()+5,y=area:getY()+5},MouseWheelDown)
        assert(area:getVirtualOffset().y>before,'mouse wheel does not scroll real content')
        shot('members-overflow',nextStep)
      end)
    end,
    function(nextStep)
      W('memberSearchField'):focus()
      W('memberSearchField'):setText('Home')
      wait('small filtered list',function()return #W('membersListPanel'):getChildren()==2 and not W('membersScrollBar'):isVisible()end,function()
        assert(W('membersListPanel'):getVirtualOffset().y==0 and W('membersListPanel'):getMarginRight()==0,'hidden scrollbar leaves an offset or gutter')
        assert(W('memberSearchField'):isFocused(),'list refresh stole keyboard focus from search')
        shot('members-fit',nextStep)
      end)
    end,
    function(nextStep)
      W('memberSearchField'):setText('Nobody Matches This')
      wait('empty search',function()return W('guildPageLabel'):getText():find('0 members',1,true)end,function()
        assert(not W('membersScrollBar'):isVisible(),'empty list displays a scrollbar')
        shot('empty-search',nextStep)
      end)
    end,
    function(nextStep)
      W('memberSearchField'):setText('')
      wait('restored overflow',function()return #W('membersListPanel'):getChildren()==10 and W('membersScrollBar'):isVisible()end,function()nextStep()end)
    end,
    function(nextStep)
      click(W('ranksTab'))
      later(400,function()
        assert(not W('rankPermTitle'):isVisible()and not W('rankPermTargetBox'):isVisible()and not W('addRankBtn'):isVisible(),'member sees rank editing controls')
        assert(W('ranksListPanel'):getMarginTop()==22 and not W('ranksScrollBar'):isVisible(),'rank editor leaves a gap or unused scroll rail')
        shot('ranks',nextStep)
      end)
    end,
    function(nextStep)
      click(W('activityTab'))
      wait('activity records',function()return #W('activityListPanel'):getChildren()==10 end,function()
        assert(not W('activityScrollBar'):isVisible(),'fitting activity list displays a scrollbar')
        shot('activity-fit',nextStep)
      end)
    end,
    function(nextStep)
      w:setHeight(280)
      wait('activity overflow after resize',function()return W('activityScrollBar'):isVisible()end,function()
        local area=W('activityListPanel');area:onMouseWheel({x=area:getX()+5,y=area:getY()+5},MouseWheelDown)
        assert(area:getVirtualOffset().y>0,'activity wheel has no effect')
        shot('activity-overflow',nextStep)
      end)
    end,
    function(nextStep)
      w:setHeight(400)
      wait('activity fits again',function()return not W('activityScrollBar'):isVisible()end,function()
        assert(W('activityListPanel'):getVirtualOffset().y==0 and W('activityListPanel'):getMarginRight()==0,'scroll rail/offset survives when no longer needed')
        nextStep()
      end)
    end,
    function()switchLogin('homebuyer',leaderReview)end,
  })
end
later(400,function()
  assert(LOCAL_PASSIVES_TEST and Services.updater==''and g_resources.getLayout()=='retro')
  connect(g_game,{onLoginError=fail,onConnectionError=function(e)if not expectedLogout then fail(e)end end,onGameStart=function()
    expectedLogout=false;EnterGame.hide()
    later(650,function()
      if modules.game_outfit.destroy then modules.game_outfit.destroy(true,true)end
      modules.game_guild.toggle()
      wait('guild loaded',function()
        w=rootWidget:recursiveGetChildById('guildWindow')
        return w and w:isVisible()and w:recursiveGetChildById('guildCrest'):getImageTextureWidth()==32
      end,function()local ready=loginReady;loginReady=nil;ready()end)
    end)
  end})
  Servers.Default='127.0.0.1:7187:860';EnterGame.onServerChange()
  rootWidget:recursiveGetChildById('rememberPasswordBox'):setChecked(false)
  login('homeseller',memberReview)
end)
scheduleEvent(function()if not done then fail('member/leader review timed out')end end,170000)
