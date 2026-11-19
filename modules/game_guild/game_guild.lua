local GUILD_OPCODE = 101
local GUILD_DEBUG = false
local GUILD_TOPMENU_ICON = '/images/topbuttons/guildmanager'

local guildWindow = nil
local guildButton = nil
local myLevel = 0
local permissions = {
  canInvite = false,
  canKick = false,
  canSetMotd = false,
  canManageRanks = false,
  canSetTitle = false,
  canCreate = false,
}
local memberSortMode = 'rank'
local selectedRankPermissionId = nil
local worldNamesEvent = nil
local worldNamesEnabled = false
local inputWindows = {}
local currentGuildId
local selectedTab = 'infoTab'
local currentPage = 1
local requestSequence = 0
local latestViewRequest = 0
local refreshEvent, filterEvent, importEvent
local importGeneration = 0
local emblemMeta = {revision=0,present=false,enabled=false}
local emblemCache, emblemRequest, previewPixels
local paintedWindow, paintedHeader, paintedPreview
local emblemBusy = false
local refreshEmblem, updatePager
local function closeInputs()
  for widget in pairs(inputWindows) do widget:destroy() end
  inputWindows = {}
end

local function cancelWorldNamesEvent()
  if worldNamesEvent then
    removeEvent(worldNamesEvent)
    worldNamesEvent = nil
  end
end

local function clearWorldNames()
  local localPlayer = g_game.getLocalPlayer()
  if not localPlayer then return end
  local position = localPlayer:getPosition()
  if not position then return end
  for _, creature in ipairs(g_map.getSpectators(position, true)) do
    if creature:isPlayer() then creature:setGuildName('') end
  end
end

local VOCATION_NAMES = {
  [0] = 'Unawakened',
  [1] = 'Awakened',
  [2] = 'Ascendant',
  [3] = 'Ascended',
}

local function sendAction(action, params)
  local protocol = g_game.getProtocolGame()
  if not protocol then return end
  local payload = { action = action }
  if params then
    for k, v in pairs(params) do
      payload[k] = v
    end
  end
  if action == 'open' then
    requestSequence = requestSequence + 1
    latestViewRequest = requestSequence
    payload.requestId = latestViewRequest
    payload.section = selectedTab:gsub('Tab$', '')
    payload.page = currentPage
    payload.sort = memberSortMode
    if guildWindow then
      local search = guildWindow:recursiveGetChildById('memberSearchField')
      local online = guildWindow:recursiveGetChildById('memberOnlineOnlyCheck')
      payload.search = search and search:getText() or ''
      payload.onlineOnly = online and online:isChecked() or false
      for _,id in ipairs({'guildPreviousBtn','guildNextBtn'}) do
        local button=guildWindow:recursiveGetChildById(id)
        if button then button:setEnabled(false) end
      end
    end
  end
  protocol:sendExtendedOpcode(GUILD_OPCODE, json.encode(payload))
end

local function requestWorldNames()
  worldNamesEvent = nil
  if not worldNamesEnabled or not g_game.isOnline() then return end
  sendAction('world_names')
  -- Also refresh stationary players after a join, kick or guild disband.
  worldNamesEvent = scheduleEvent(requestWorldNames, 2000)
end

function setWorldNamesEnabled(enabled)
  worldNamesEnabled = enabled == true
  cancelWorldNamesEvent()
  clearWorldNames()
  if worldNamesEnabled and g_game.isOnline() then requestWorldNames() end
end

local function onGameStart()
  setWorldNamesEnabled(modules.client_options.getOption('showGuildNames'))
end

local function clearChildren(panel)
  if not panel then return end
  for _, child in ipairs(panel:getChildren()) do
    child:destroy()
  end
end

local function debugGuild(fmt, ...)
  if not GUILD_DEBUG then return end
  if select('#', ...) > 0 then
    print(string.format('[GuildUI] ' .. fmt, ...))
  else
    print('[GuildUI] ' .. tostring(fmt))
  end
end

local function W(id)
  if not guildWindow then return nil end
  return guildWindow:recursiveGetChildById(id)
end

local function queueRefresh(delay)
  if refreshEvent then removeEvent(refreshEvent) end
  refreshEvent = scheduleEvent(function()
    refreshEvent=nil
    if guildWindow and g_game.isOnline() then
      if GuildDirectory.isActive() then GuildDirectory.refresh() else sendAction('open') end
    end
  end, delay or 100)
end

function updateListScrollBar(area)
  local bar=area.verticalScrollBar
  if not bar then return end
  local needed=bar:getMaximum()>bar:getMinimum()
  bar:setVisible(needed)
  area:setMarginRight(needed and 12 or 0)
end

local function filtersChanged(delay)
  if filterEvent then removeEvent(filterEvent) end
  filterEvent=scheduleEvent(function()
    filterEvent=nil
    currentPage=1
    sendAction('open')
  end,delay or 250)
end

local function showGuildError(message)
  if displayErrorBox then
    displayErrorBox('Guild', message or 'An error occurred.')
    return
  end

  local localPlayer = g_game.getLocalPlayer()
  if localPlayer and localPlayer.say then
    localPlayer:say(message or 'Guild error.', SpeakDefault)
  end
end

updatePager=function(data)
  local paging=data.paging
  if data.type=='guild_data' and data.section~=selectedTab:gsub('Tab$','') then paging=nil end
  local bar=W('guildPager')
  if bar then bar:setVisible(paging~=nil) end
  if not paging then return end
  currentPage=paging.page or 1
  local units={members={'member','members'},invites={'invitation','invitations'},activity={'event','events'}}
  local unit=units[data.type=='no_guild' and 'invites' or data.section] or {'entry','entries'}
  W('guildPageLabel'):setText(string.format('Page %d / %d  -  %d %s',currentPage,paging.pages or 1,
    paging.total or 0,unit[paging.total==1 and 1 or 2]))
  for _,entry in ipairs({{'guildPreviousBtn',-1},{'guildNextBtn',1}}) do
    local step=entry[2]
    local button=W(entry[1])
    button:setEnabled(step<0 and currentPage>1 or step>0 and currentPage<(paging.pages or 1))
    button.onClick=function() currentPage=currentPage+step;sendAction('open') end
  end
end

local function emblemStatus(text)
  local label=W('emblemStatus')
  if label then label:setText(text) end
end

local function paintEmblem(pixels)
  if paintedWindow~=guildWindow then
    paintedWindow=guildWindow;paintedHeader=nil;paintedPreview=nil
  end
  for _,id in ipairs({'guildCrest','emblemPreview'}) do
    local widget=W(id)
    local desired=id=='emblemPreview' and previewPixels or pixels
    local key=desired or false
    local previous=paintedPreview
    if id=='guildCrest' then previous=paintedHeader end
    if widget and (id=='guildCrest' or myLevel>=3) and previous~=key then
      if desired and widget:setGuildEmblemPixels(desired) then
        widget:setImageClip({x=0,y=0,width=32,height=32})
      else
        widget:setImageSource('/images/game/emblems/emblem_member')
        widget:setImageClip({x=0,y=0,width=0,height=0})
      end
      if id=='guildCrest' then paintedHeader=key else paintedPreview=key end
    end
  end
end

local function paintPreview(pixels)
  if not pixels or not W('emblemPreview') then return false end
  if paintedPreview~=pixels then
    if not W('emblemPreview'):setGuildEmblemPixels(pixels) then return false end
    W('emblemPreview'):setImageClip({x=0,y=0,width=32,height=32})
    paintedPreview=pixels
  end
  return true
end

local function emblemButtons()
  local leader=myLevel>=3 and emblemMeta.enabled==true
  for _,id in ipairs({'chooseEmblemBtn','saveEmblemBtn','cancelEmblemBtn','removeEmblemBtn'}) do
    local button=W(id)
    if button then button:setVisible(leader);button:setEnabled(not emblemBusy) end
  end
  if W('chooseEmblemBtn') then W('chooseEmblemBtn'):setEnabled(leader and not emblemBusy and g_platform.guildEmblemImportAvailable()) end
  if W('saveEmblemBtn') then W('saveEmblemBtn'):setEnabled(leader and not emblemBusy and previewPixels~=nil) end
  if W('cancelEmblemBtn') then W('cancelEmblemBtn'):setEnabled(leader and not emblemBusy and previewPixels~=nil) end
  if W('removeEmblemBtn') then W('removeEmblemBtn'):setEnabled(leader and not emblemBusy and emblemMeta.present) end
end

local function chooseEmblem()
  if emblemBusy or not currentGuildId then return end
  if not g_platform.beginGuildEmblemImport() then return showGuildError('The image chooser is already open or unavailable.') end
  local generation,target=importGeneration,currentGuildId
  emblemBusy=true;emblemButtons();emblemStatus('Choosing an image...')
  local function poll()
    importEvent=nil
    local value=g_platform.pollGuildEmblemImport()
    if value=='pending' then importEvent=scheduleEvent(poll,100);return end
    if generation~=importGeneration or target~=currentGuildId or not guildWindow then return end
    emblemBusy=false
    if value:sub(1,7)=='pixels:' then
      previewPixels=value:sub(8)
      -- Keep the header on the saved emblem until Save succeeds.
      if paintPreview(previewPixels) then
        emblemStatus('Preview - save to share with your guild.')
      else previewPixels=nil;emblemStatus('The image could not be imported.') end
    elseif value:sub(1,6)=='error:' then emblemStatus(value:sub(7))
    else emblemStatus(previewPixels and 'Preview - not saved.' or 'No changes saved.') end
    emblemButtons()
  end
  importEvent=scheduleEvent(poll,100)
end

refreshEmblem=function(data)
  local meta=data.emblem or {enabled=false,revision=0,present=false}
  if not emblemCache or emblemCache.guildId~=currentGuildId then emblemCache=nil end
  if emblemMeta.revision~=meta.revision or emblemMeta.present~=meta.present or not meta.enabled then
    previewPixels=nil;emblemBusy=false;emblemRequest=nil;importGeneration=importGeneration+1
  end
  emblemMeta=meta
  paintEmblem(meta.enabled and meta.present and emblemCache and emblemCache.revision==meta.revision and emblemCache.pixels or nil)
  if previewPixels then paintPreview(previewPixels) end
  if not meta.enabled then emblemStatus('Guild emblems are currently disabled.')
  elseif previewPixels then emblemStatus('Preview - not saved.')
  else emblemStatus(meta.present and 'Your guild emblem.' or 'Your guild has no custom emblem yet.') end
  if meta.enabled and meta.present and not emblemRequest and (not emblemCache or emblemCache.revision~=meta.revision) then
    requestSequence=requestSequence+1
    emblemRequest={id=requestSequence,guildId=currentGuildId,revision=meta.revision}
    sendAction('emblem',{requestId=requestSequence})
  end
  W('chooseEmblemBtn').onClick=chooseEmblem
  W('saveEmblemBtn').onClick=function()
    if not previewPixels or emblemBusy then return end
    emblemBusy=true;emblemButtons();emblemStatus('Saving emblem...')
    sendAction('set_emblem',{revision=emblemMeta.revision,first=previewPixels:sub(1,2732),second=previewPixels:sub(2733)})
  end
  W('cancelEmblemBtn').onClick=function()
    previewPixels=nil;paintEmblem(emblemCache and emblemCache.pixels);emblemButtons();emblemStatus('No changes saved.')
  end
  W('removeEmblemBtn').onClick=function()
    local box
    local function close() if box then box:destroy() end end
    box=displayGeneralBox('Remove Guild Emblem','Remove the current emblem? This counts as one of the three daily changes.',{
      {text='Remove',callback=function()close();emblemBusy=true;emblemButtons();sendAction('clear_emblem',{revision=emblemMeta.revision})end},
      {text='Cancel',callback=close}},nil,close)
  end
  emblemButtons()
end

local function ensureWindow()
  if guildWindow then
    return true
  end

  guildWindow = g_ui.displayUI('game_guild', rootWidget)
  if not guildWindow then
    return false
  end

  GuildDirectory.attach(guildWindow,sendAction,function(active)
    closeInputs();importGeneration=importGeneration+1;previewPixels=nil;emblemBusy=false;emblemRequest=nil
    paintedWindow=nil;paintedHeader=nil;paintedPreview=nil
    W('browseGuildsBtn'):setChecked(active);W('myGuildBtn'):setChecked(not active)
    W('guildDirectoryPanel'):setVisible(active)
    for _,id in ipairs({'guildTabsRow','noGuildWrapper','infoPanel','membersPanelWrapper','invitesPanelWrapper','ranksPanelWrapper','activityPanelWrapper','guildPager'})do
      W(id):hide()
    end
    if active then guildWindow:setHeight(500) else sendAction('open') end
  end)

  local refreshBtn = W('refreshBtn')
  if refreshBtn then
    refreshBtn.onClick = function()
      if GuildDirectory.isActive() then GuildDirectory.refresh() else sendAction('open') end
    end
  end

  if guildButton then
    guildButton:setOn(true)
  end

  return true
end

function browseGuilds()GuildDirectory.open()end
function showMyGuild()GuildDirectory.close()end

local function makeInputWindow(title, onOk)
  local win = g_ui.createWidget('GuildInputWindow', rootWidget)
  if not win then return end
  inputWindows[win]=true
  win.onDestroy=function()inputWindows[win]=nil end

  local titleWidget = win:recursiveGetChildById('windowTitle')
  if titleWidget then titleWidget:setText(title) end

  local okBtn = win:recursiveGetChildById('okBtn')
  if okBtn then
    okBtn.onClick = function()
      local inputField = win:recursiveGetChildById('inputField')
      if inputField then
        onOk(inputField:getText())
      end
      win:destroy()
    end
  end

  local cancelBtn = win:recursiveGetChildById('cancelBtn')
  if cancelBtn then cancelBtn.onClick = function() win:destroy() end end
  local field=win:recursiveGetChildById('inputField');if field then field:focus()end
  return win
end

function switchTab(tabName, rendering)
  if not guildWindow then return end
  if tabName=='invitesTab' and permissions.canInvite~=true then tabName='infoTab' end
  local changed=selectedTab~=tabName
  selectedTab=tabName
  if changed then
    currentPage=1
    if filterEvent then removeEvent(filterEvent);filterEvent=nil end
  end

  local tabs = {
    { tab = 'infoTab', panel = 'infoPanel' },
    { tab = 'membersTab', panel = 'membersPanelWrapper' },
    { tab = 'invitesTab', panel = 'invitesPanelWrapper' },
    { tab = 'ranksTab', panel = 'ranksPanelWrapper' },
    { tab = 'activityTab', panel = 'activityPanelWrapper' },
  }

  for _, entry in ipairs(tabs) do
    local active = entry.tab == tabName
    local tab = W(entry.tab)
    local panel = W(entry.panel)
    if tab then tab:setChecked(active) end
    if panel then panel:setVisible(active) end
  end
  if changed and not rendering then sendAction('open') end
end

local function formatTimeLeft(expiresAt)
  local ts = tonumber(expiresAt) or 0
  if ts <= 0 then return 'no expiry' end
  local left = ts - os.time()
  if left <= 0 then return 'expired' end
  local days = math.floor(left / 86400)
  local hours = math.floor((left % 86400) / 3600)
  local minutes = math.floor((left % 3600) / 60)
  if days > 0 then return string.format('%dd %dh', days, hours) end
  if hours > 0 then return string.format('%dh %dm', hours, minutes) end
  return string.format('%dm', minutes)
end

local function formatActivityLine(entry)
  local event = entry.event or 'updated'
  local actor = entry.actor or 'System'
  local payload = entry.payload or {}

  if event == 'guild_created' then
    return string.format('%s founded the guild.', actor)
  elseif event == 'member_invited' then
    return string.format('%s invited %s.', actor, payload.targetName or 'a player')
  elseif event == 'invite_accepted' then
    return string.format('%s joined the guild.', payload.playerName or actor)
  elseif event == 'invite_declined' then
    return string.format('%s declined an invite.', actor)
  elseif event == 'member_kicked' then
    return string.format('%s kicked %s.', actor, payload.targetName or 'a member')
  elseif event == 'member_rank_changed' then
    return string.format('%s changed %s\'s rank.', actor, payload.targetName or 'a member')
  elseif event == 'member_title_changed' then
    return string.format('%s changed %s\'s title.', actor, payload.targetName or 'a member')
  elseif event == 'motd_updated' then
    return string.format('%s updated the MOTD.', actor)
  elseif event == 'guild_renamed' then
    return string.format('%s renamed the guild to %s.', actor, payload.name or '')
  elseif event == 'recruitment_updated' then
    return string.format('%s updated the recruitment status.',actor)
  elseif event == 'invite_revoked' then
    return string.format('%s withdrew the invitation for %s.', actor, payload.name or '')
  elseif event == 'rank_created' then
    return string.format('%s created rank %s.', actor, payload.rankName or '')
  elseif event == 'rank_renamed' then
    return string.format('%s renamed a rank to %s.', actor, payload.rankName or '')
  elseif event == 'rank_deleted' then
    return string.format('%s deleted a rank.', actor)
  elseif event == 'rank_permissions_updated' then
    return string.format('%s updated rank permissions.', actor)
  elseif event == 'member_left' then
    return string.format('%s left the guild.', payload.playerName or actor)
  elseif event == 'leadership_transferred' then
    return string.format('%s transferred leadership to %s.', actor, payload.newLeaderName or 'another member')
  end

  return string.format('%s performed %s.', actor, event)
end

local function renderNoGuild(data)
  closeInputs();currentGuildId=nil
  guildWindow:setHeight(500)
  emblemCache=nil;emblemRequest=nil;previewPixels=nil;emblemBusy=false;importGeneration=importGeneration+1
  W('guildNameLabel'):setText('Guild Manager')
  W('guildSummaryLine'):setText('Accept an invitation or visit a Guildmaster to found your guild.')
  paintEmblem(nil)
  local canCreate = data.permissions and data.permissions.canCreate == true
  local noGuildInfoLabel = W('noGuildInfoLabel')
  local noGuildTipsLabel = W('noGuildTipsLabel')
  local createPanel = W('createGuildPanel')

  if noGuildInfoLabel then
    if canCreate then
      noGuildInfoLabel:setText('Guild Founding Mode is active for a short time. Create one below or accept an invitation.')
    else
      noGuildInfoLabel:setText('You are not in a guild. Founding is available only through a Guildmaster.')
    end
  end

  if noGuildTipsLabel then
    if canCreate then
      noGuildTipsLabel:setText('Tip: This founding window expires soon. Guild management remains available in top menu > Guild Manager.')
    else
      noGuildTipsLabel:setText('Tip: Use top menu > Guild Manager for invites and member overview anywhere.\nSpeak to a Guildmaster and say "guild" to found a new guild.')
    end
  end

  if createPanel then
    createPanel:setVisible(canCreate)
  end

  local tabContent = W('tabContent')
  if tabContent then
    clearChildren(tabContent)
    tabContent:setMarginTop(canCreate and 48 or 8)

    if data.invites and #data.invites > 0 then
      local section = g_ui.createWidget('GuildSectionLabel', tabContent)
      if section then section:setText('Pending Guild Invitations:') end

      for _, invite in ipairs(data.invites) do
        local row = g_ui.createWidget('GuildInviteRow', tabContent)
        if row then
          local nameLabel = row:recursiveGetChildById('guildName')
          if nameLabel then
            local timeLeft = formatTimeLeft(invite.expiresAt)
            nameLabel:setText(string.format('%s  [expires in %s]', invite.guildName or '', timeLeft))
          end

          local guildId = invite.guildId
          local acceptBtn = row:recursiveGetChildById('acceptBtn')
          if acceptBtn then
            acceptBtn.onClick = function()
              sendAction('accept_invite', { guild_id = guildId })
            end
          end

          local declineBtn = row:recursiveGetChildById('declineBtn')
          if declineBtn then
            declineBtn.onClick = function()
              sendAction('decline_invite', { guild_id = guildId })
            end
          end
        end
      end
    end
  end

  local createBtn = W('createGuildBtn')
  local guildNameField = W('guildNameField')
  if createBtn and guildNameField then
    createBtn:setEnabled(canCreate)
    createBtn.onClick = nil
    if canCreate then
      createBtn.onClick = function()
        local guildName = guildNameField:getText()
        if guildName and #guildName >= 3 then
          sendAction('create', { name = guildName })
        else
          showGuildError('Guild name must be at least 3 characters long.')
        end
      end
    end
  end
end

local function renderGuildData(data)
  local info = data.info or {}
  if currentGuildId~=info.id then
    closeInputs();currentGuildId=info.id
    emblemCache=nil;emblemRequest=nil;previewPixels=nil;emblemBusy=false;importGeneration=importGeneration+1
    emblemMeta={revision=0,present=false,enabled=false}
  end
  local members = data.members or {}
  local invites = data.invites or {}
  local ranks = data.ranks or {}
  local activity = data.activity or {}

  myLevel = data.myLevel or 0
  permissions = data.permissions or {
    canInvite = false,
    canKick = false,
    canSetMotd = false,
    canManageRanks = false,
    canSetTitle = false,
    canCreate = false,
  }

  local isLeader = myLevel >= 3
  local canInvite = permissions.canInvite == true
  local canKick = permissions.canKick == true
  local canSetMotd = permissions.canSetMotd == true
  local canManageRanks = permissions.canManageRanks == true
  local canSetTitle = permissions.canSetTitle == true
  local canManageMembers = canKick or canSetTitle or canManageRanks or isLeader
  if not isLeader then
    if previewPixels or emblemBusy then importGeneration=importGeneration+1 end
    previewPixels=nil;emblemBusy=false
  end
  guildWindow:setHeight((isLeader or canSetMotd or canManageRanks) and 550 or 400)
  W('emblemPanel'):setVisible(isLeader)
  W('recruitmentSettings'):setVisible(isLeader)
  local recruitment=W('recruitmentStatusBox')
  recruitment:clearOptions()
  for _,entry in ipairs({{'Not specified',0},{'Recruiting',1},{'Closed to recruitment',2}})do recruitment:addOption(entry[1],entry[2])end
  recruitment:setCurrentOption(({[0]='Not specified',[1]='Recruiting',[2]='Closed to recruitment'})[info.recruitmentStatus] or 'Not specified')
  W('saveRecruitmentBtn').onClick=function()sendAction('set_recruitment',{status=recruitment:getCurrentOption().data})end
  W('invitesTab'):setVisible(canInvite)
  W('ranksTab'):setText(canManageRanks and 'Ranks & rights' or 'Ranks')
  W('ranksTab'):setWidth(canManageRanks and 108 or 82)
  W('ranksTab'):addAnchor(AnchorLeft,canInvite and 'invitesTab' or 'membersTab',AnchorRight)
  if not canInvite and selectedTab=='invitesTab' then
    selectedTab='infoTab';currentPage=1;queueRefresh()
  end

  local guildNameLabel = W('guildNameLabel')
  if guildNameLabel then guildNameLabel:setText(info.name or 'Guild') end
  W('guildSummaryLine'):setText(string.format('%d members  -  %d online  -  %s',data.memberCount or #members,
    data.onlineCount or 0,isLeader and 'Guild leader' or 'Member'))

  local infoGuildName = W('infoGuildName')
  local infoOwnerName = W('infoOwnerName')
  local infoMemberCount = W('infoMemberCount')
  if infoGuildName then infoGuildName:setText(info.name or '') end
  if infoOwnerName then infoOwnerName:setText(info.ownerName or '') end
  if infoMemberCount then infoMemberCount:setText(string.format('%d (%d online)', data.memberCount or #members, data.onlineCount or 0)) end

  local motdEdit = W('motdEdit')
  if motdEdit then
    motdEdit:setText(info.motd or '')
    motdEdit:setEnabled(canSetMotd)
    motdEdit:setVisible(canSetMotd)
  end
  local hasDescription=(info.motd or '')~=''
  W('motdTitleLabel'):setVisible(canSetMotd or hasDescription)
  W('motdTitleLabel'):setText(canSetMotd and 'Public description / Message of the Day:' or 'Guild description:')
  W('motdReadOnly'):setText(info.motd or '')
  W('motdReadOnly'):setVisible(not canSetMotd and hasDescription)

  local saveMotdBtn = W('saveMotdBtn')
  if saveMotdBtn then
    saveMotdBtn:setVisible(canSetMotd)
    saveMotdBtn.onClick = function()
      if motdEdit then
        sendAction('set_motd', { motd = motdEdit:getText() })
      end
    end
  end

  local renameGuildBtn=W('renameGuildBtn')
  if renameGuildBtn then
    renameGuildBtn:setVisible(isLeader)
    renameGuildBtn.onClick=function()
      local input=makeInputWindow('New guild name',function(name)sendAction('rename',{name=name})end)
      if input then input:recursiveGetChildById('inputField'):setText(info.name or '')end
    end
  end

  local leaveGuildBtn = W('leaveGuildBtn')
  if leaveGuildBtn then
    leaveGuildBtn:setVisible(not isLeader)
    leaveGuildBtn:addAnchor(AnchorTop,canSetMotd and 'saveMotdBtn' or hasDescription and 'motdReadOnly' or 'infoMemberCount',AnchorBottom)
    leaveGuildBtn.onClick = function()
      local box
      local function close() if box then box:destroy() end end
      box=displayGeneralBox('Leave Guild','Leave this guild? You will need another invitation to rejoin.',{
        {text='Leave',callback=function()close();sendAction('leave')end},{text='Cancel',callback=close}},nil,close)
    end
  end

  local disbandGuildBtn = W('disbandGuildBtn')
  if disbandGuildBtn then
    disbandGuildBtn:setVisible(isLeader)
    disbandGuildBtn.onClick = nil
    if isLeader then
      disbandGuildBtn.onClick = function()
        if displayGeneralBox then
          local questionBox
          local function onConfirm()
            if questionBox then questionBox:destroy() end
            sendAction('disband')
          end
          local function onCancel()
            if questionBox then questionBox:destroy() end
          end

          questionBox = displayGeneralBox('Disband Guild',
            'Are you sure you want to disband this guild? This cannot be undone.',
            {
              { text = 'Disband', callback = onConfirm },
              { text = 'Cancel', callback = onCancel },
            }, onConfirm, onCancel)
        else
          sendAction('disband')
        end
      end
    end
  end

  local inviteNameField = W('inviteNameField')
  W('inviteNameLabel'):setVisible(canInvite)
  if inviteNameField then inviteNameField:setVisible(canInvite) end
  local inviteBtn = W('inviteBtn')
  if inviteBtn then
    inviteBtn:setVisible(canInvite)
    inviteBtn.onClick = nil
    if canInvite and inviteNameField then
      inviteBtn.onClick = function()
        local targetName = inviteNameField:getText()
        if targetName and #targetName > 0 then
          sendAction('invite', { name = targetName })
          inviteNameField:setText('')
        end
      end
    end
  end

  local membersListPanel = W('membersListPanel')
  local memberSearchField = W('memberSearchField')
  memberSearchField:addAnchor(AnchorTop,canInvite and 'inviteNameField' or 'parent',canInvite and AnchorBottom or AnchorTop)
  memberSearchField:setMarginTop(canInvite and 4 or 2)
  W('memberSortBox'):addAnchor(AnchorTop,canInvite and 'inviteNameField' or 'parent',canInvite and AnchorBottom or AnchorTop)
  W('memberSortBox'):setMarginTop(canInvite and 4 or 2)
  W('memberOnlineOnlyCheck'):addAnchor(AnchorTop,canInvite and 'inviteNameField' or 'parent',canInvite and AnchorBottom or AnchorTop)
  W('memberOnlineOnlyCheck'):setMarginTop(canInvite and 6 or 4)
  local memberSortBox = W('memberSortBox')
  local memberOnlineOnlyCheck = W('memberOnlineOnlyCheck')

  local function buildMembersList()
    if not membersListPanel then return end
    clearChildren(membersListPanel)

    local filtered = members -- Already filtered and ordered across the entire guild by the server.

    if #filtered == 0 then
      local empty = g_ui.createWidget('GuildSectionLabel', membersListPanel)
      if empty then empty:setText('No members match your filters.') end
      return
    end

    for _, member in ipairs(filtered) do
      local row = g_ui.createWidget('GuildMemberRow', membersListPanel)
      if row then
        local onlineIndicator = row:recursiveGetChildById('onlineIndicator')
        if onlineIndicator then
          onlineIndicator:setBackgroundColor(member.online and '#44cc44' or '#666666')
        end

        local memberName = row:recursiveGetChildById('memberName')
        if memberName then
          local vocName = VOCATION_NAMES[tonumber(member.vocation)] or 'Unknown'
          local displayName = string.format('%s [Lv %d, %s]', member.name or '', member.level or 0, vocName)
          if member.nick and member.nick ~= '' then
            displayName = displayName .. ' (' .. member.nick .. ')'
          end
          memberName:setText(displayName)
        end

        local memberRank = row:recursiveGetChildById('memberRank')
        if memberRank then
          local suffix = member.online and ' | Online' or ''
          memberRank:setText((member.rankName or '') .. suffix)
          memberRank:setMarginRight(canManageMembers and member.rankLevel<myLevel and 30 or 10)
        end
        row:setTooltip(string.format('%s\n%s%s',memberName and memberName:getText() or member.name,
          member.rankName or '',canManageMembers and member.rankLevel<myLevel and '\nClick to manage this member.' or ''))
        row:recursiveGetChildById('memberActionsHint'):setVisible(canManageMembers and member.rankLevel<myLevel)

        if canManageMembers and member.rankLevel<myLevel then
          local memberCopy = member
          local ranksCopy = ranks
          local myLevelCopy = myLevel
          row.onMouseRelease = function(widget, mousePos, mouseButton)
            if mouseButton ~= MouseRightButton and mouseButton ~= MouseLeftButton then return end

            local menu = g_ui.createWidget('PopupMenu', rootWidget)
            if not menu then return end

            if canManageRanks and memberCopy.rankLevel and memberCopy.rankLevel < myLevelCopy then
              menu:addOption('Set Rank', function()
                local rankMenu = g_ui.createWidget('PopupMenu', rootWidget)
                if rankMenu then
                  for _, rank in ipairs(ranksCopy) do
                    if rank.level < myLevelCopy then
                      local rankId = rank.id
                      rankMenu:addOption(rank.name, function()
                        sendAction('set_rank', { name = memberCopy.name, rank_id = rankId })
                      end)
                    end
                  end
                  rankMenu:display(mousePos)
                end
              end)
            end

            if canSetTitle and memberCopy.rankLevel and memberCopy.rankLevel < myLevelCopy then
              menu:addOption('Set Title', function()
                makeInputWindow('Set Title for ' .. memberCopy.name, function(value)
                  sendAction('set_nick', { name = memberCopy.name, nick = value })
                end)
              end)
            end

            if isLeader and memberCopy.rankLevel and memberCopy.rankLevel < 3 then
              menu:addOption('Transfer Leadership', function()
                local box
                local function close() if box then box:destroy() end end
                box=displayGeneralBox('Transfer Leadership','Make '..memberCopy.name..' the guild leader? You will lose leadership.',{
                  {text='Transfer',callback=function()close();sendAction('transfer_leadership',{name=memberCopy.name})end},
                  {text='Cancel',callback=close}},nil,close)
              end)
            end

            if canKick and memberCopy.rankLevel and memberCopy.rankLevel < myLevelCopy then
              menu:addOption('Kick', function()
                sendAction('kick', { name = memberCopy.name })
              end)
            end

            menu:display(mousePos)
          end
        end
      end
    end
  end

  if memberSortBox then
    if memberSortBox:getOptionsCount() == 0 then
      memberSortBox:addOption('Rank', 'rank')
      memberSortBox:addOption('Name', 'name')
      memberSortBox:addOption('Level', 'level')
      memberSortBox:addOption('Online', 'online')
      memberSortBox:addOption('Last Seen', 'lastseen')
    end
    memberSortBox:setCurrentOptionByData(memberSortMode, true)
    memberSortBox.onOptionChange = function(widget, option, dataValue)
      memberSortMode = dataValue or 'rank'
      filtersChanged(1)
    end
  end

  if memberSearchField then
    memberSearchField.onTextChange = function() filtersChanged() end
  end
  if memberOnlineOnlyCheck then
    memberOnlineOnlyCheck.onCheckChange = function() filtersChanged(1) end
  end
  buildMembersList()

  local invitesListPanel = W('invitesListPanel')
  if invitesListPanel then
    clearChildren(invitesListPanel)
    if #invites == 0 then
      local emptyLabel = g_ui.createWidget('GuildSectionLabel', invitesListPanel)
      if emptyLabel then emptyLabel:setText('No pending invitations.') end
    else
      for _, invite in ipairs(invites) do
        local row = g_ui.createWidget('GuildInvitedRow', invitesListPanel)
        if row then
          local inviteeName = row:recursiveGetChildById('inviteeName')
          if inviteeName then
            inviteeName:setText(string.format('%s  [expires in %s]', invite.name or '', formatTimeLeft(invite.expiresAt)))
            inviteeName:addAnchor(AnchorRight,canInvite and 'withdrawInviteBtn' or 'parent',canInvite and AnchorLeft or AnchorRight)
          end
          local withdraw=row:recursiveGetChildById('withdrawInviteBtn')
          if withdraw then
            local target=invite.name
            withdraw:setVisible(canInvite)
            withdraw.onClick=function()sendAction('revoke_invite',{name=target})end
          end
        end
      end
    end
  end

  local ranksListPanel = W('ranksListPanel')
  if ranksListPanel then
    clearChildren(ranksListPanel)
    for _, rank in ipairs(ranks) do
      local row = g_ui.createWidget('GuildRankRow', ranksListPanel)
      if row then
        local rankName = row:recursiveGetChildById('rankName')
        if rankName then
          rankName:setText(canManageRanks and (rank.name .. '  (Tier ' .. rank.level .. ')') or rank.name)
          rankName:addAnchor(AnchorRight,canManageRanks and 'renameRankBtn' or 'parent',canManageRanks and AnchorLeft or AnchorRight)
        end

        local rankId = rank.id
        local deleteRankBtn = row:recursiveGetChildById('deleteRankBtn')
        if deleteRankBtn then
          deleteRankBtn:setVisible(canManageRanks and rank.level == 1)
          deleteRankBtn.onClick = nil
          if canManageRanks and rank.level == 1 then
            deleteRankBtn.onClick = function()
              sendAction('delete_rank', { rank_id = rankId })
            end
          end
        end

        local renameRankBtn = row:recursiveGetChildById('renameRankBtn')
        if renameRankBtn then
          renameRankBtn:setVisible(canManageRanks)
          renameRankBtn.onClick = nil
          if canManageRanks then
            renameRankBtn.onClick = function()
              makeInputWindow('Rename Rank', function(value)
                sendAction('update_rank', { rank_id = rankId, rank_name = value })
              end)
            end
          end
        end
      end
    end
  end

  local addRankBtn = W('addRankBtn')
  if addRankBtn then
    addRankBtn:setVisible(canManageRanks)
    addRankBtn.onClick = nil
    if canManageRanks then
      addRankBtn.onClick = function()
        makeInputWindow('New Rank Name', function(value)
          sendAction('create_rank', { rank_name = value })
        end)
      end
    end
  end

  local rankPermTitle = W('rankPermTitle')
  local rankPermTargetBox = W('rankPermTargetBox')
  local rankPermSaveBtn = W('rankPermSaveBtn')
  local permInviteCheck = W('permInviteCheck')
  local permKickCheck = W('permKickCheck')
  local permMotdCheck = W('permMotdCheck')
  local permRanksCheck = W('permRanksCheck')
  local permTitleCheck = W('permTitleCheck')

  if rankPermTitle then rankPermTitle:setVisible(canManageRanks) end
  if rankPermTargetBox then rankPermTargetBox:setVisible(canManageRanks) end
  if rankPermSaveBtn then rankPermSaveBtn:setVisible(canManageRanks) end
  if permInviteCheck then permInviteCheck:setVisible(canManageRanks) end
  if permKickCheck then permKickCheck:setVisible(canManageRanks) end
  if permMotdCheck then permMotdCheck:setVisible(canManageRanks) end
  if permRanksCheck then permRanksCheck:setVisible(canManageRanks) end
  if permTitleCheck then permTitleCheck:setVisible(canManageRanks) end
  W('ranksListPanel'):setMarginTop(canManageRanks and 84 or 22)
  W('ranksScrollBar'):setMarginTop(canManageRanks and 84 or 22)

  if canManageRanks and rankPermTargetBox then
    rankPermTargetBox:clearOptions()
    for _, rank in ipairs(ranks) do
      rankPermTargetBox:addOption(rank.name .. ' (Tier ' .. rank.level .. ')', rank.id)
    end

    local function getRankById(rankId)
      for _, rank in ipairs(ranks) do
        if rank.id == rankId then return rank end
      end
      return nil
    end

    local function applyRankPermissionSelection(rankId)
      local rank = getRankById(rankId)
      if not rank then return end
      local rp = rank.permissions or {}

      local locked = rank.level >= 3
      if permInviteCheck then permInviteCheck:setChecked(rp.canInvite == true) permInviteCheck:setEnabled(not locked) end
      if permKickCheck then permKickCheck:setChecked(rp.canKick == true) permKickCheck:setEnabled(not locked) end
      if permMotdCheck then permMotdCheck:setChecked(rp.canSetMotd == true) permMotdCheck:setEnabled(not locked) end
      if permRanksCheck then permRanksCheck:setChecked(rp.canManageRanks == true) permRanksCheck:setEnabled(not locked) end
      if permTitleCheck then permTitleCheck:setChecked(rp.canSetTitle == true) permTitleCheck:setEnabled(not locked) end
      if rankPermSaveBtn then rankPermSaveBtn:setEnabled(not locked) end
    end

    if not selectedRankPermissionId or not getRankById(selectedRankPermissionId) then
      selectedRankPermissionId = ranks[1] and ranks[1].id or nil
    end

    rankPermTargetBox.onOptionChange = function(widget, option, dataValue)
      selectedRankPermissionId = tonumber(dataValue)
      applyRankPermissionSelection(selectedRankPermissionId)
    end

    if selectedRankPermissionId then
      rankPermTargetBox:setCurrentOptionByData(selectedRankPermissionId, true)
      applyRankPermissionSelection(selectedRankPermissionId)
    end

    if rankPermSaveBtn then
      rankPermSaveBtn.onClick = function()
        local rank = getRankById(selectedRankPermissionId)
        if not rank then return end
        if rank.level >= 3 then
          showGuildError('Leader permissions are fixed.')
          return
        end

        sendAction('set_rank_permissions', {
          rank_id = selectedRankPermissionId,
          permissions = {
            canInvite = permInviteCheck and permInviteCheck:isChecked() or false,
            canKick = permKickCheck and permKickCheck:isChecked() or false,
            canSetMotd = permMotdCheck and permMotdCheck:isChecked() or false,
            canManageRanks = permRanksCheck and permRanksCheck:isChecked() or false,
            canSetTitle = permTitleCheck and permTitleCheck:isChecked() or false,
          }
        })
      end
    end
  end

  local activityListPanel = W('activityListPanel')
  if activityListPanel then
    clearChildren(activityListPanel)
    if #activity == 0 then
      local emptyAct = g_ui.createWidget('GuildSectionLabel', activityListPanel)
      if emptyAct then emptyAct:setText('No recent activity.') end
    else
      for _, entry in ipairs(activity) do
        local row = g_ui.createWidget('GuildActivityRow', activityListPanel)
        if row then
          local timestamp = os.date('%Y-%m-%d %H:%M', tonumber(entry.createdAt) or os.time())
          row:setText(string.format('%s  -  %s', timestamp, formatActivityLine(entry)))
        end
      end
    end
  end
end

local function onGuildOpcode(protocol, opcode, buffer)
  local ok, data = pcall(json.decode, buffer)
  if not ok or type(data) ~= 'table' then
    debugGuild('Ignoring invalid payload: %s', tostring(buffer))
    return
  end

  if data.type == 'world_names' then
    if not worldNamesEnabled then return end
    if data.reset~=false then clearWorldNames() end
    for _, entry in ipairs(data.players or {}) do
      local creature = g_map.getCreatureById(tonumber(entry.id) or 0)
      if creature and creature:isPlayer() and type(entry.name) == 'string' then
        creature:setGuildName(entry.name)
      end
    end
    return
  end

  if data.type == 'error' then
    emblemBusy=false;emblemRequest=nil;emblemButtons()
    showGuildError(data.message or 'An error occurred.')
    return
  end

  if GuildDirectory.handle(data) then return end

  if data.type=='guild_emblem' then
    if GuildDirectory.isActive() then emblemRequest=nil;return end
    local expected=emblemRequest
    if not expected or data.requestId~=expected.id or data.guildId~=currentGuildId or
        data.guildId~=expected.guildId or data.revision~=expected.revision or not guildWindow then return end
    emblemRequest=nil
    if type(data.pixels)=='string' and W('guildCrest'):setGuildEmblemPixels(data.pixels) then
      emblemCache={guildId=data.guildId,revision=data.revision,pixels=data.pixels}
      paintEmblem(data.pixels)
      if previewPixels then paintPreview(previewPixels) end
    end
    return
  end

  if data.type=='guild_refresh' then
    if ensureWindow() then queueRefresh() end
    return
  end

  if data.type == 'success' then
    if data.refresh then
      emblemBusy=false
      queueRefresh()
    end
    return
  end

  if data.type ~= 'no_guild' and data.type ~= 'guild_data' then
    debugGuild('Ignoring unexpected payload type: %s', tostring(data.type))
    return
  end
  if data.requestId~=latestViewRequest or not guildWindow then return end
  if GuildDirectory.isActive() then return end

  if not ensureWindow() then
    return
  end

  guildWindow:show()
  if guildButton then guildButton:setOn(true) end

  if data.type == 'no_guild' then
    local guildTabsRow = W('guildTabsRow')
    local noGuildWrapper = W('noGuildWrapper')
    if guildTabsRow then guildTabsRow:setVisible(false) end
    if noGuildWrapper then noGuildWrapper:setVisible(true) end
    -- explicitly hide all tab panels to prevent overlap
    local tabPanels = { 'infoPanel', 'membersPanelWrapper', 'invitesPanelWrapper', 'ranksPanelWrapper', 'activityPanelWrapper' }
    for _, id in ipairs(tabPanels) do
      local p = W(id)
      if p then p:setVisible(false) end
    end

    myLevel = 0
    permissions = data.permissions or { canInvite = false, canKick = false, canSetMotd = false, canManageRanks = false, canSetTitle = false, canCreate = false }
    renderNoGuild(data)
    updatePager(data)
    return
  end

  if data.type == 'guild_data' then
    local guildTabsRow = W('guildTabsRow')
    local noGuildWrapper = W('noGuildWrapper')
    if guildTabsRow then guildTabsRow:setVisible(true) end
    if noGuildWrapper then noGuildWrapper:setVisible(false) end

    renderGuildData(data)
    switchTab(selectedTab,true)
    updatePager(data)
    refreshEmblem(data)
  end
end

local function onGameEnd()
  GuildDirectory.detach()
  closeInputs();currentGuildId=nil
  importGeneration=importGeneration+1;emblemCache=nil;emblemRequest=nil;previewPixels=nil;emblemBusy=false
  paintedWindow=nil;paintedHeader=nil;paintedPreview=nil
  if refreshEvent then removeEvent(refreshEvent);refreshEvent=nil end
  if filterEvent then removeEvent(filterEvent);filterEvent=nil end
  requestSequence=requestSequence+1;latestViewRequest=requestSequence
  selectedTab='infoTab';currentPage=1
  cancelWorldNamesEvent()
  clearWorldNames()
  if guildWindow then
    guildWindow:destroy()
    guildWindow = nil
  end
  myLevel = 0
  permissions = { canInvite = false, canKick = false, canSetMotd = false, canManageRanks = false, canSetTitle = false, canCreate = false }
  memberSortMode = 'rank'
  selectedRankPermissionId = nil
  if guildButton then guildButton:setOn(false) end
end

function hide()
  GuildDirectory.detach()
  closeInputs()
  importGeneration=importGeneration+1;previewPixels=nil;emblemBusy=false;emblemRequest=nil
  paintedWindow=nil;paintedHeader=nil;paintedPreview=nil
  if refreshEvent then removeEvent(refreshEvent);refreshEvent=nil end
  if filterEvent then removeEvent(filterEvent);filterEvent=nil end
  requestSequence=requestSequence+1;latestViewRequest=requestSequence
  if guildWindow then
    guildWindow:destroy()
    guildWindow = nil
  end
  if guildButton then guildButton:setOn(false) end
  selectedRankPermissionId = nil
end

function toggle()
  if guildWindow and guildWindow:isVisible() then
    hide()
    return
  end

  if not ensureWindow() then
    return
  end

  guildWindow:show()
  guildWindow:raise()
  guildWindow:focus()
  if guildButton then guildButton:setOn(true) end
  if GuildDirectory.isActive() then GuildDirectory.refresh() else sendAction('open') end
end

function canInviteMembers()
  return permissions.canInvite == true
end

function inviteByName(name)
  if not canInviteMembers() then return end
  sendAction('invite', { name = name })
end

function init()
  g_ui.importStyle('guild_directory')
  connect(g_game, { onGameStart = onGameStart, onGameEnd = onGameEnd })
  ProtocolGame.registerExtendedOpcode(GUILD_OPCODE, onGuildOpcode)
  if g_game.isOnline() then onGameStart() end

  if modules.client_topmenu and modules.client_topmenu.addRightGameToggleButton then
    guildButton = modules.client_topmenu.addRightGameToggleButton('guildManagerButton', tr('Guild Manager'), GUILD_TOPMENU_ICON, toggle, false, 6)
    if guildButton then
      guildButton:setOn(false)
    end
  end
end

function terminate()
  if guildButton then
    guildButton:destroy()
    guildButton = nil
  end
  disconnect(g_game, { onGameStart = onGameStart, onGameEnd = onGameEnd })
  ProtocolGame.unregisterExtendedOpcode(GUILD_OPCODE)
  onGameEnd()
end
