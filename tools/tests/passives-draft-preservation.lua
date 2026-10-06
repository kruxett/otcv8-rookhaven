-- Real native combat rejection through UI Apply, then retry the retained draft.
-- Disposable Passive Tester only. Uses existing isolated runtime fixtures.
local mod, login, failed, done, finishing
local replies, metrics, expected, revision, session = {}, nil, nil, nil, nil
local verify = true
local function fail(reason)
  if failed or done then return end
  failed = true
  print('PASSIVES_DRAFT_AUDIT_FAILED ' .. tostring(reason))
  if g_game.isOnline() then
    g_game.cancelAttack()
    g_game.talk('/passiveqa quiesce Passive Tester')
    scheduleEvent(function() g_game.talk('/passivetest stop') end, 200)
    scheduleEvent(function() g_game.safeLogout() end, 500)
  end
  scheduleEvent(function() g_app.exit() end, 1100)
end
local function later(ms, fn)
  scheduleEvent(function()
    if failed or done then return end
    local ok, err = pcall(fn); if not ok then fail(err) end
  end, ms)
end
local function wait(label, predicate, nextStep, timeout)
  local deadline = g_clock.millis() + (timeout or 8000)
  local function poll()
    if predicate() then nextStep(); return end
    assert(g_clock.millis() < deadline, label .. ' timeout')
    later(70, poll)
  end
  later(100, poll)
end
local function state() return mod.getState() end
local function sum(ranks) local n=0; for _,r in pairs(ranks) do n=n+r end; return n end
local function copy(ranks) local out={}; for id,r in pairs(ranks) do out[id]=r end; return out end
local function same(a,b)
  for id,r in pairs(a) do if r ~= (b[id] or 0) then return false end end
  for id,r in pairs(b) do if r ~= (a[id] or 0) then return false end end
  return true
end
local function commands(list, nextStep)
  local function step(i)
    if i > #list then later(450,nextStep); return end
    g_game.talk(list[i]); later(350,function() step(i+1) end)
  end
  step(1)
end
local function click(id)
  local widget = assert(mod.getWindow():recursiveGetChildById(id), 'Missing UI button ' .. id)
  assert(widget:isEnabled(), 'UI button disabled ' .. id)
  signalcall(widget.onClick, widget)
end
local function finish()
  g_game.cancelAttack()
  commands({'/passiveqa quiesce Passive Tester','/passivetest stop'},function()
    wait('overlay cleanup',function() return not state().active end,function()
      finishing=true; g_game.safeLogout()
      wait('logout',function() return not g_game.isOnline() end,function()
        done=true
        print(verify and 'PASSIVES_DRAFT_PRESERVE_OK' or 'PASSIVES_DRAFT_LOSS_REPRO_OK')
        scheduleEvent(function() g_app.exit() end,400)
      end)
    end)
  end)
end
local function afterReject(id)
  wait('server rejected actual UI Apply',function() return replies[id] ~= nil and not state().pending end,function()
    local reply=replies[id]
    assert(reply.ok==false and reply.error:find('combat',1,true), 'Expected actual combat rejection: '..tostring(reply.error))
    assert(state().revision==revision and state().session==session and sum(state().ranks)==0, 'Rejection changed authoritative state')
    local preserved=same(expected,state().draft)
    print('PASSIVES_DRAFT_REJECT_EVIDENCE '..json.encode({
      serverError=reply.error, revisionBefore=revision, revisionAfter=state().revision,
      savedPoints=sum(state().ranks), draftedBefore=sum(expected), draftedAfter=sum(state().draft),
      draftPreserved=preserved, realUiApply=true, nativeCombat=true}))
    mod.show();mod.selectNode('minor_vitality')
    later(150,function()
      g_app.doScreenshot('/passives-draft-server-rejected.png')
      if not verify then
        assert(not preserved and sum(state().draft)==0,'Current binary did not reproduce expected draft loss')
        finish();return
      end
      assert(preserved,'Failed UI Apply discarded the legal draft')
      g_game.cancelAttack()
      commands({'/passiveqa quiesce Passive Tester'},function()
        click('applyButton')
        wait('calm retry saves same draft',function() return state().revision>revision and not state().pending end,function()
          assert(same(expected,state().ranks),'Calm retry failed to save preserved draft')
          print('PASSIVES_DRAFT_RETRY_OK')
          finish()
        end)
      end)
    end)
  end)
end
local function combatApply()
  commands({'/passiveqa arena','/passiveqa join Passive Tester,1'},function()
    local target
    for _,c in ipairs(g_map.getSpectators(g_game.getLocalPlayer():getPosition(),false)) do
      if c:getName()=='Passive Test Dummy' and (not target or c:getId()<target:getId()) then target=c end
    end
    assert(target,'Owned runtime dummy not visible')
    g_game.attack(target)
    later(450,function()
      metrics=nil;g_game.talk('/passiveqa metrics Passive Tester')
      wait('native combat metrics',function() return metrics~=nil end,function()
        assert(metrics.infight or (metrics.attackedId or 0)>0,'No actual native combat context')
        print('PASSIVES_DRAFT_COMBAT_METRICS '..json.encode(metrics))
        assert(same(expected,state().draft),'Setup changed the draft before Apply')
        click('applyButton')
        local id=assert(state().pending,'Actual UI Apply did not send a request')
        afterReject(id)
      end)
    end)
  end)
end
local function online()
  EnterGame.hide()
  wait('handshake',function() return state().ready end,function()
    commands({'/passiveqa quiesce Passive Tester','/passivetest stop','/passiveqa equip reaver','/passivetest start reaver'},function()
      wait('fresh temporary tree',function() return state().active and state().tree and state().tree.id=='reaver' and sum(state().ranks)==0 end,function()
        mod.show();assert(mod.selectNode('minor_vitality'))
        click('addRank');click('addRank')
        expected=copy(state().draft);revision=state().revision;session=state().session
        assert(sum(expected)==2 and not mod.validateDraft(expected),'Expected legal two-point draft')
        print('PASSIVES_DRAFT_BEFORE '..json.encode(expected))
        combatApply()
      end)
    end)
  end)
end
later(200,function()
  assert(LOCAL_PASSIVES_TEST and Services.updater=='' and g_resources.getLayout()=='retro')
  mod=assert(modules.game_passives)
  ProtocolGame.registerExtendedJSONOpcode(103,function(_,_,data)
    if data.action=='result' and data.requestId then replies[data.requestId]=data end
  end)
  connect(g_game,{
    onGameStart=function() later(250,online) end,
    onTextMessage=function(_,message)
      print('PASSIVES_DRAFT_MESSAGE '..message)
      local raw=message:match('^PASSIVEQA_METRICS (.+)$')
      if raw then metrics=json.decode(raw) end
    end,
    onConnectionError=function(err) if not finishing then fail(err) end end
  })
  g_settings.set('window-maximized',false);g_window.resize({width=1280,height=800})
  g_game.setClientVersion(860);g_game.setProtocolVersion(860);g_game.setRsa(OTSERV_RSA)
  G.account,G.password='passivetest','passivetest'
  login=ProtocolLogin.create();_G.draftAuditLogin=login
  login.onLoginError=function(_,err) fail(err) end
  login.onCharacterList=function(_,chars)
    for _,c in ipairs(chars) do if c.name=='Passive Tester' then
      g_game.loginWorld(G.account,G.password,c.worldName,c.worldIp,c.worldPort,c.name,'','');return
    end end
    fail('Missing disposable fixture character')
  end
  login:login('127.0.0.1',7174,G.account,G.password,'',false)
end)
scheduleEvent(function() if not done then fail('60-second audit timeout') end end,60000)
