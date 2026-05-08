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
  protocol:sendExtendedOpcode(GUILD_OPCODE, json.encode(payload))
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

local function ensureWindow()
  if guildWindow then
    return true
  end

  guildWindow = g_ui.displayUI('game_guild', rootWidget)
  if not guildWindow then
    return false
  end

  local refreshBtn = W('refreshBtn')
  if refreshBtn then
    refreshBtn.onClick = function()
      sendAction('open')
    end
  end

  if guildButton then
    guildButton:setOn(true)
  end

  return true
end

local function makeInputWindow(title, onOk)
  local win = g_ui.createWidget('GuildInputWindow', rootWidget)
  if not win then return end

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
end

function switchTab(tabName)
  if not guildWindow then return end

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

  local guildNameLabel = W('guildNameLabel')
  if guildNameLabel then guildNameLabel:setText(info.name or 'Guild') end

  local infoGuildName = W('infoGuildName')
  local infoOwnerName = W('infoOwnerName')
  local infoMemberCount = W('infoMemberCount')
  if infoGuildName then infoGuildName:setText(info.name or '') end
  if infoOwnerName then infoOwnerName:setText(info.ownerName or '') end
  if infoMemberCount then infoMemberCount:setText(tostring(#members)) end

  local motdEdit = W('motdEdit')
  if motdEdit then
    motdEdit:setText(info.motd or '')
    motdEdit:setEnabled(canSetMotd)
  end

  local saveMotdBtn = W('saveMotdBtn')
  if saveMotdBtn then
    saveMotdBtn:setVisible(canSetMotd)
    saveMotdBtn.onClick = function()
      if motdEdit then
        sendAction('set_motd', { motd = motdEdit:getText() })
      end
    end
  end

  local leaveGuildBtn = W('leaveGuildBtn')
  if leaveGuildBtn then
    leaveGuildBtn:setVisible(not isLeader)
    leaveGuildBtn.onClick = function() sendAction('leave') end
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
  local memberSortBox = W('memberSortBox')
  local memberOnlineOnlyCheck = W('memberOnlineOnlyCheck')

  local function buildMembersList()
    if not membersListPanel then return end
    clearChildren(membersListPanel)

    local search = ''
    if memberSearchField then
      search = string.lower(memberSearchField:getText() or '')
    end
    local onlineOnly = memberOnlineOnlyCheck and memberOnlineOnlyCheck:isChecked() or false

    local filtered = {}
    for _, member in ipairs(members) do
      local nick = member.nick or ''
      local hay = string.lower((member.name or '') .. ' ' .. nick .. ' ' .. (member.rankName or ''))
      if (search == '' or string.find(hay, search, 1, true)) and (not onlineOnly or member.online) then
        table.insert(filtered, member)
      end
    end

    table.sort(filtered, function(a, b)
      if memberSortMode == 'name' then
        return (a.name or '') < (b.name or '')
      elseif memberSortMode == 'level' then
        if (a.level or 0) == (b.level or 0) then return (a.name or '') < (b.name or '') end
        return (a.level or 0) > (b.level or 0)
      elseif memberSortMode == 'lastseen' then
        if a.online ~= b.online then return a.online end
        if (a.lastSeen or 0) == (b.lastSeen or 0) then return (a.name or '') < (b.name or '') end
        return (a.lastSeen or 0) > (b.lastSeen or 0)
      elseif memberSortMode == 'online' then
        if a.online ~= b.online then return a.online end
        return (a.name or '') < (b.name or '')
      end

      if (a.rankLevel or 0) == (b.rankLevel or 0) then return (a.name or '') < (b.name or '') end
      return (a.rankLevel or 0) > (b.rankLevel or 0)
    end)

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
        end

        if canManageMembers then
          local memberCopy = member
          local ranksCopy = ranks
          local myLevelCopy = myLevel
          row.onMouseRelease = function(widget, mousePos, mouseButton)
            if mouseButton ~= MouseRightButton then return end

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
                sendAction('transfer_leadership', { name = memberCopy.name })
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
      buildMembersList()
    end
  end

  if memberSearchField then
    memberSearchField.onTextChange = function() buildMembersList() end
  end
  if memberOnlineOnlyCheck then
    memberOnlineOnlyCheck.onCheckChange = function() buildMembersList() end
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
        if rankName then rankName:setText(rank.name .. '  (Tier ' .. rank.level .. ')') end

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

  if data.type == 'error' then
    showGuildError(data.message or 'An error occurred.')
    return
  end

  if data.type == 'success' then
    if data.refresh then
      sendAction('open')
    end
    return
  end

  if data.type ~= 'no_guild' and data.type ~= 'guild_data' then
    debugGuild('Ignoring unexpected payload type: %s', tostring(data.type))
    return
  end

  if not ensureWindow() then
    return
  end

  guildWindow:show()
  guildWindow:raise()
  guildWindow:focus()
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
    return
  end

  if data.type == 'guild_data' then
    local guildTabsRow = W('guildTabsRow')
    local noGuildWrapper = W('noGuildWrapper')
    if guildTabsRow then guildTabsRow:setVisible(true) end
    if noGuildWrapper then noGuildWrapper:setVisible(false) end

    renderGuildData(data)
    switchTab('infoTab')
  end
end

local function onGameEnd()
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
  sendAction('open')
end

function canInviteMembers()
  return permissions.canInvite == true
end

function inviteByName(name)
  if not canInviteMembers() then return end
  sendAction('invite', { name = name })
end

function init()
  connect(g_game, { onGameEnd = onGameEnd })
  ProtocolGame.registerExtendedOpcode(GUILD_OPCODE, onGuildOpcode)

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
  disconnect(g_game, { onGameEnd = onGameEnd })
  ProtocolGame.unregisterExtendedOpcode(GUILD_OPCODE)
  onGameEnd()
end
