-- game_guild.lua
-- Client-side guild management module.

local GUILD_OPCODE = 101

local guildWindow = nil
local snapshotData = nil  -- last received guild data

-- ──────────────────────────────────────────────────────────────────────────────
-- Internal helpers
-- ──────────────────────────────────────────────────────────────────────────────

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

-- ──────────────────────────────────────────────────────────────────────────────
-- Render helpers
-- ──────────────────────────────────────────────────────────────────────────────

local function renderNoGuild(data)
  if not guildWindow then return end

  local tabContent = guildWindow:getChildById('tabContent')
  if not tabContent then return end
  clearChildren(tabContent)

  -- Show "No guild" info
  local noGuildPanel = g_ui.createWidget('GuildNoGuildPanel', tabContent)
  if noGuildPanel then
    local msgLabel = noGuildPanel:getChildById('messageLabel')
    if msgLabel then
      msgLabel:setText("You are not in a guild.\nSpeak to a Guildmaster to create or join one.")
    end
  end

  -- Show pending invites
  if data.invites and #data.invites > 0 then
    local invitesLabel = g_ui.createWidget('GuildSectionLabel', tabContent)
    if invitesLabel then invitesLabel:setText("Pending Guild Invitations:") end

    for _, inv in ipairs(data.invites) do
      local row = g_ui.createWidget('GuildInviteRow', tabContent)
      if row then
        local nameLabel = row:getChildById('guildName')
        if nameLabel then nameLabel:setText(inv.guildName or "") end

        local acceptBtn = row:getChildById('acceptBtn')
        if acceptBtn then
          acceptBtn.onClick = function()
            sendAction("accept_invite", { guild_id = inv.guildId })
          end
        end

        local declineBtn = row:getChildById('declineBtn')
        if declineBtn then
          declineBtn.onClick = function()
            sendAction("decline_invite", { guild_id = inv.guildId })
          end
        end
      end
    end
  end
end

local function renderGuildData(data)
  if not guildWindow then return end

  local info    = data.info    or {}
  local members = data.members or {}
  local ranks   = data.ranks   or {}
  local invites = data.invites or {}
  local myLevel = data.myLevel or 0

  local isLeader = (myLevel >= 3)
  local isOfficer = (myLevel >= 2)

  -- Update title bar
  local titleLabel = guildWindow:getChildById('guildNameLabel')
  if titleLabel then titleLabel:setText(info.name or "Guild") end

  -- Tab: Info
  local infoPanel = guildWindow:getChildById('infoPanel')
  if infoPanel then
    local nameVal = infoPanel:getChildById('infoGuildName')
    if nameVal then nameVal:setText(info.name or "") end

    local ownerVal = infoPanel:getChildById('infoOwnerName')
    if ownerVal then ownerVal:setText(info.ownerName or "") end

    local countVal = infoPanel:getChildById('infoMemberCount')
    if countVal then countVal:setText(tostring(#members)) end

    local motdEdit = infoPanel:getChildById('motdEdit')
    if motdEdit then
      motdEdit:setText(info.motd or "")
      motdEdit:setEnabled(isLeader)
    end

    local saveMotdBtn = infoPanel:getChildById('saveMotdBtn')
    if saveMotdBtn then
      saveMotdBtn:setVisible(isLeader)
      saveMotdBtn.onClick = function()
        if motdEdit then
          sendAction("set_motd", { motd = motdEdit:getText() })
        end
      end
    end

    local leaveBtn = infoPanel:getChildById('leaveGuildBtn')
    if leaveBtn then
      leaveBtn:setVisible(not isLeader)
      leaveBtn.onClick = function()
        sendAction("leave")
      end
    end

    local disbandBtn = infoPanel:getChildById('disbandGuildBtn')
    if disbandBtn then
      disbandBtn:setVisible(isLeader)
      disbandBtn.onClick = function()
        sendAction("disband")
      end
    end
  end

  -- Tab: Members
  local membersPanel = guildWindow:getChildById('membersListPanel')
  if membersPanel then
    clearChildren(membersPanel)

    -- Build rank name lookup
    local rankNames = {}
    for _, rk in ipairs(ranks) do
      rankNames[rk.id] = rk.name
    end

    for _, member in ipairs(members) do
      local row = g_ui.createWidget('GuildMemberRow', membersPanel)
      if row then
        local onlineIndicator = row:getChildById('onlineIndicator')
        if onlineIndicator then
          onlineIndicator:setColor(member.online and "#44cc44" or "#666666")
        end

        local nameLabel = row:getChildById('memberName')
        if nameLabel then
          local displayName = member.name
          if member.nick and member.nick ~= "" then
            displayName = displayName .. " (" .. member.nick .. ")"
          end
          nameLabel:setText(displayName)
        end

        local rankLabel = row:getChildById('memberRank')
        if rankLabel then rankLabel:setText(member.rankName or "") end

        -- Right-click context menu for leader/officer
        if isOfficer then
          row.onMouseRelease = function(widget, mousePos, mouseButton)
            if mouseButton == MouseRightButton then
              local menu = g_ui.createWidget('PopupMenu', rootWidget)
              if menu then
                if isLeader and member.rankLevel and member.rankLevel < 3 then
                  menu:addOption("Set Rank", function()
                    -- Build rank submenu
                    local rankMenu = g_ui.createWidget('PopupMenu', rootWidget)
                    if rankMenu then
                      for _, rk in ipairs(ranks) do
                        if rk.level < 3 then
                          local rkCopy = rk
                          rankMenu:addOption(rk.name, function()
                            sendAction("set_rank", { name = member.name, rank_id = rkCopy.id })
                          end)
                        end
                      end
                      rankMenu:display(mousePos)
                    end
                  end)
                  menu:addOption("Set Title", function()
                    local inputWindow = g_ui.createWidget('GuildInputWindow', rootWidget)
                    if inputWindow then
                      local titleLabel2 = inputWindow:getChildById('windowTitle')
                      if titleLabel2 then titleLabel2:setText("Set Title for " .. member.name) end
                      local okBtn = inputWindow:getChildById('okBtn')
                      if okBtn then
                        okBtn.onClick = function()
                          local inputField = inputWindow:getChildById('inputField')
                          if inputField then
                            sendAction("set_nick", { name = member.name, nick = inputField:getText() })
                          end
                          inputWindow:destroy()
                        end
                      end
                      local cancelBtn = inputWindow:getChildById('cancelBtn')
                      if cancelBtn then
                        cancelBtn.onClick = function() inputWindow:destroy() end
                      end
                    end
                  end)
                  menu:addOption("Transfer Leadership", function()
                    sendAction("transfer_leadership", { name = member.name })
                  end)
                end
                if member.rankLevel and member.rankLevel < myLevel then
                  menu:addOption("Kick", function()
                    sendAction("kick", { name = member.name })
                  end)
                end
                menu:display(mousePos)
              end
            end
          end
        end
      end
    end
  end

  -- Invite input in members panel header
  if isOfficer then
    local inviteField = guildWindow:getChildById('inviteNameField')
    local inviteBtn   = guildWindow:getChildById('inviteBtn')
    if inviteField and inviteBtn then
      inviteBtn:setVisible(true)
      inviteBtn.onClick = function()
        local name = inviteField:getText()
        if name and #name > 0 then
          sendAction("invite", { name = name })
          inviteField:clearText()
        end
      end
    end
  end

  -- Tab: Invites (guild invites sent to others)
  local invitesPanel = guildWindow:getChildById('invitesListPanel')
  if invitesPanel then
    clearChildren(invitesPanel)
    if #invites == 0 then
      local emptyLabel = g_ui.createWidget('GuildSectionLabel', invitesPanel)
      if emptyLabel then emptyLabel:setText("No pending invitations.") end
    else
      for _, inv in ipairs(invites) do
        local row = g_ui.createWidget('GuildInvitedRow', invitesPanel)
        if row then
          local nameLabel = row:getChildById('inviteeName')
          if nameLabel then nameLabel:setText(inv.name or "") end
        end
      end
    end
  end

  -- Tab: Ranks (leader only)
  local ranksPanel = guildWindow:getChildById('ranksListPanel')
  if ranksPanel then
    clearChildren(ranksPanel)
    for _, rk in ipairs(ranks) do
      local row = g_ui.createWidget('GuildRankRow', ranksPanel)
      if row then
        local rkLabel = row:getChildById('rankName')
        if rkLabel then rkLabel:setText(rk.name .. " (Tier " .. rk.level .. ")") end

        if isLeader and rk.level == 1 then
          local delBtn = row:getChildById('deleteRankBtn')
          if delBtn then
            delBtn:setVisible(true)
            delBtn.onClick = function()
              sendAction("delete_rank", { rank_id = rk.id })
            end
          end
          local renameBtn = row:getChildById('renameRankBtn')
          if renameBtn then
            renameBtn:setVisible(true)
            renameBtn.onClick = function()
              local inputWindow = g_ui.createWidget('GuildInputWindow', rootWidget)
              if inputWindow then
                local wTitle = inputWindow:getChildById('windowTitle')
                if wTitle then wTitle:setText("Rename Rank") end
                local okBtn = inputWindow:getChildById('okBtn')
                if okBtn then
                  okBtn.onClick = function()
                    local inputField = inputWindow:getChildById('inputField')
                    if inputField then
                      sendAction("update_rank", { rank_id = rk.id, rank_name = inputField:getText() })
                    end
                    inputWindow:destroy()
                  end
                end
                local cancelBtn = inputWindow:getChildById('cancelBtn')
                if cancelBtn then cancelBtn.onClick = function() inputWindow:destroy() end end
              end
            end
          end
        end
      end
    end

    -- Add new rank button
    if isLeader then
      local addRankBtn = guildWindow:getChildById('addRankBtn')
      if addRankBtn then
        addRankBtn:setVisible(true)
        addRankBtn.onClick = function()
          local inputWindow = g_ui.createWidget('GuildInputWindow', rootWidget)
          if inputWindow then
            local wTitle = inputWindow:getChildById('windowTitle')
            if wTitle then wTitle:setText("New Rank Name") end
            local okBtn = inputWindow:getChildById('okBtn')
            if okBtn then
              okBtn.onClick = function()
                local inputField = inputWindow:getChildById('inputField')
                if inputField then
                  sendAction("create_rank", { rank_name = inputField:getText() })
                end
                inputWindow:destroy()
              end
            end
            local cancelBtn = inputWindow:getChildById('cancelBtn')
            if cancelBtn then cancelBtn.onClick = function() inputWindow:destroy() end end
          end
        end
      end
    end
  end
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Create guild window (for players not in a guild)
-- ──────────────────────────────────────────────────────────────────────────────

local function renderCreateGuild(data)
  if not guildWindow then return end

  local createPanel = guildWindow:getChildById('createGuildPanel')
  if not createPanel then return end

  createPanel:setVisible(true)

  local nameField = createPanel:getChildById('guildNameField')
  local createBtn = createPanel:getChildById('createGuildBtn')
  if createBtn then
    createBtn.onClick = function()
      if nameField then
        sendAction("create", { name = nameField:getText() })
      end
    end
  end
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Tab switching
-- ──────────────────────────────────────────────────────────────────────────────

local function switchTab(tabName)
  if not guildWindow then return end
  local tabs = { 'infoTab', 'membersTab', 'invitesTab', 'ranksTab' }
  local panels = { 'infoPanel', 'membersPanelWrapper', 'invitesPanelWrapper', 'ranksPanelWrapper' }

  for i, tab in ipairs(tabs) do
    local btn = guildWindow:getChildById(tab)
    local panel = guildWindow:getChildById(panels[i])
    if btn then btn:setChecked(tab == tabName) end
    if panel then panel:setVisible(tab == tabName) end
  end
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Opcode handler
-- ──────────────────────────────────────────────────────────────────────────────

local function onGuildOpcode(protocol, opcode, buffer)
  local ok, data = pcall(json.decode, buffer)
  if not ok or type(data) ~= 'table' then return end

  snapshotData = data

  if data.type == 'error' then
    displayErrorBox('Guild', data.message or 'An error occurred.')
    return
  end

  if data.type == 'success' then
    if data.message and #data.message > 0 then
      g_game.localPlayerSay(g_game.getLocalPlayer(), data.message, TalkTypes.MonsterSay)
    end
    -- If the server wants a refresh, it will follow up with guild_data
    return
  end

  -- Open window if not open yet
  if not guildWindow then
    guildWindow = g_ui.displayUI('game_guild', rootWidget)
    if not guildWindow then return end

    -- Hook tab buttons
    local infoTabBtn = guildWindow:getChildById('infoTab')
    if infoTabBtn then infoTabBtn.onClick = function() switchTab('infoTab') end end
    local membersTabBtn = guildWindow:getChildById('membersTab')
    if membersTabBtn then membersTabBtn.onClick = function() switchTab('membersTab') end end
    local invitesTabBtn = guildWindow:getChildById('invitesTab')
    if invitesTabBtn then invitesTabBtn.onClick = function() switchTab('invitesTab') end end
    local ranksTabBtn = guildWindow:getChildById('ranksTab')
    if ranksTabBtn then ranksTabBtn.onClick = function() switchTab('ranksTab') end end

    -- Refresh button
    local refreshBtn = guildWindow:getChildById('refreshBtn')
    if refreshBtn then
      refreshBtn.onClick = function()
        sendAction("open")
      end
    end
  end

  if data.type == 'no_guild' then
    -- Hide guild tabs, show create/invite panel
    local guildTabs = guildWindow:getChildById('guildTabsRow')
    if guildTabs then guildTabs:setVisible(false) end
    local noGuildWrapper = guildWindow:getChildById('noGuildWrapper')
    if noGuildWrapper then noGuildWrapper:setVisible(true) end
    renderNoGuild(data)

    -- Show create-guild section
    renderCreateGuild(data)

  elseif data.type == 'guild_data' then
    local guildTabs = guildWindow:getChildById('guildTabsRow')
    if guildTabs then guildTabs:setVisible(true) end
    local noGuildWrapper = guildWindow:getChildById('noGuildWrapper')
    if noGuildWrapper then noGuildWrapper:setVisible(false) end

    renderGuildData(data)
    switchTab('infoTab')
  end
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Lifecycle
-- ──────────────────────────────────────────────────────────────────────────────

local function onGameEnd()
  if guildWindow then
    guildWindow:destroy()
    guildWindow = nil
  end
  snapshotData = nil
end

function hide()
  if guildWindow then
    guildWindow:destroy()
    guildWindow = nil
  end
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
