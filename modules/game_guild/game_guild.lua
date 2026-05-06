local GUILD_OPCODE = 101
local GUILD_DEBUG = false

local guildWindow = nil
local myLevel = 0
local permissions = {
  canInvite = false,
}

local function sendAction(action, params)
  local protocol = g_game.getProtocolGame()
  if not protocol then return end
  local payload = table.merge({ action = action }, params or {})
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
  }

  for _, entry in ipairs(tabs) do
    local active = entry.tab == tabName
    local tab = W(entry.tab)
    local panel = W(entry.panel)
    if tab then tab:setChecked(active) end
    if panel then panel:setVisible(active) end
  end
end

local function renderNoGuild(data)
  local tabContent = W('tabContent')
  if tabContent then
    clearChildren(tabContent)

    if data.invites and #data.invites > 0 then
      local section = g_ui.createWidget('GuildSectionLabel', tabContent)
      if section then section:setText('Pending Guild Invitations:') end

      for _, invite in ipairs(data.invites) do
        local row = g_ui.createWidget('GuildInviteRow', tabContent)
        if row then
          local nameLabel = row:recursiveGetChildById('guildName')
          if nameLabel then nameLabel:setText(invite.guildName or '') end

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
    createBtn.onClick = function()
      local guildName = guildNameField:getText()
      if guildName and #guildName >= 3 then
        sendAction('create', { name = guildName })
      end
    end
  end
end

local function renderGuildData(data)
  local info = data.info or {}
  local members = data.members or {}
  local invites = data.invites or {}
  local ranks = data.ranks or {}

  myLevel = data.myLevel or 0
  permissions = data.permissions or { canInvite = false }

  local isLeader = myLevel >= 3
  local canInvite = permissions.canInvite == true
  local canManageMembers = myLevel >= 2

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
    motdEdit:setEnabled(isLeader)
  end

  local saveMotdBtn = W('saveMotdBtn')
  if saveMotdBtn then
    saveMotdBtn:setVisible(isLeader)
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
    disbandGuildBtn.onClick = function() sendAction('disband') end
  end

  local membersListPanel = W('membersListPanel')
  if membersListPanel then
    clearChildren(membersListPanel)

    for _, member in ipairs(members) do
      local row = g_ui.createWidget('GuildMemberRow', membersListPanel)
      if row then
        local onlineIndicator = row:recursiveGetChildById('onlineIndicator')
        if onlineIndicator then
          onlineIndicator:setBackgroundColor(member.online and '#44cc44' or '#666666')
        end

        local memberName = row:recursiveGetChildById('memberName')
        if memberName then
          local displayName = member.name
          if member.nick and member.nick ~= '' then
            displayName = displayName .. ' (' .. member.nick .. ')'
          end
          memberName:setText(displayName)
        end

        local memberRank = row:recursiveGetChildById('memberRank')
        if memberRank then memberRank:setText(member.rankName or '') end

        if canManageMembers then
          local memberCopy = member
          local ranksCopy = ranks
          local myLevelCopy = myLevel
          row.onMouseRelease = function(widget, mousePos, mouseButton)
            if mouseButton ~= MouseRightButton then return end

            local menu = g_ui.createWidget('PopupMenu', rootWidget)
            if not menu then return end

            if isLeader and memberCopy.rankLevel and memberCopy.rankLevel < 3 then
              menu:addOption('Set Rank', function()
                local rankMenu = g_ui.createWidget('PopupMenu', rootWidget)
                if rankMenu then
                  for _, rank in ipairs(ranksCopy) do
                    if rank.level < 3 then
                      local rankId = rank.id
                      rankMenu:addOption(rank.name, function()
                        sendAction('set_rank', { name = memberCopy.name, rank_id = rankId })
                      end)
                    end
                  end
                  rankMenu:display(mousePos)
                end
              end)

              menu:addOption('Set Title', function()
                makeInputWindow('Set Title for ' .. memberCopy.name, function(value)
                  sendAction('set_nick', { name = memberCopy.name, nick = value })
                end)
              end)

              menu:addOption('Transfer Leadership', function()
                sendAction('transfer_leadership', { name = memberCopy.name })
              end)
            end

            if memberCopy.rankLevel and memberCopy.rankLevel < myLevelCopy then
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
          if inviteeName then inviteeName:setText(invite.name or '') end
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

        if isLeader and rank.level == 1 then
          local rankId = rank.id

          local deleteRankBtn = row:recursiveGetChildById('deleteRankBtn')
          if deleteRankBtn then
            deleteRankBtn:setVisible(true)
            deleteRankBtn.onClick = function()
              sendAction('delete_rank', { rank_id = rankId })
            end
          end

          local renameRankBtn = row:recursiveGetChildById('renameRankBtn')
          if renameRankBtn then
            renameRankBtn:setVisible(true)
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
    addRankBtn:setVisible(isLeader)
    addRankBtn.onClick = nil
    if isLeader then
      addRankBtn.onClick = function()
        makeInputWindow('New Rank Name', function(value)
          sendAction('create_rank', { rank_name = value })
        end)
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

  if data.type == 'no_guild' then
    local guildTabsRow = W('guildTabsRow')
    local noGuildWrapper = W('noGuildWrapper')
    if guildTabsRow then guildTabsRow:setVisible(false) end
    if noGuildWrapper then noGuildWrapper:setVisible(true) end
    -- explicitly hide all tab panels to prevent overlap
    local tabPanels = { 'infoPanel', 'membersPanelWrapper', 'invitesPanelWrapper', 'ranksPanelWrapper' }
    for _, id in ipairs(tabPanels) do
      local p = W(id)
      if p then p:setVisible(false) end
    end

    myLevel = 0
    permissions = { canInvite = false }
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
  permissions = { canInvite = false }
end

function hide()
  if guildWindow then
    guildWindow:destroy()
    guildWindow = nil
  end
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
end

function terminate()
  disconnect(g_game, { onGameEnd = onGameEnd })
  ProtocolGame.unregisterExtendedOpcode(GUILD_OPCODE)
  onGameEnd()
end
