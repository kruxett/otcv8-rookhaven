local TASK_CENTER_OPCODE = TaskCenterOpcode or 95

local taskCenterWindow = nil
local taskCenterButton = nil

local availableTab = nil
local activeTab = nil
local readyTab = nil
local listPanel = nil
local statusLabel = nil
local taskTitle = nil
local creaturesLabel = nil
local progressLabel = nil
local rewardLabel = nil
local reasonLabel = nil
local creaturesPreviewPanel = nil
local actionButton = nil
local refreshButton = nil
local closeButton = nil
local availablePaginator = nil
local prevPageButton = nil
local nextPageButton = nil
local pageInfoLabel = nil

local currentTab = 'available'
local snapshotData = nil
local selectedKey = nil
local requestId = 0
local availablePage = 1
local availablePageSize = 20
local renderedEntries = {}

local function destroyWindow()
  if taskCenterWindow then
    taskCenterWindow:destroy()
    taskCenterWindow = nil
  end

  availableTab = nil
  activeTab = nil
  readyTab = nil
  listPanel = nil
  statusLabel = nil
  taskTitle = nil
  creaturesLabel = nil
  progressLabel = nil
  rewardLabel = nil
  reasonLabel = nil
  creaturesPreviewPanel = nil
  actionButton = nil
  refreshButton = nil
  closeButton = nil
  availablePaginator = nil
  prevPageButton = nil
  nextPageButton = nil
  pageInfoLabel = nil
  renderedEntries = {}
end

local function sendRequest(action, payload)
  local protocol = g_game.getProtocolGame()
  if not protocol then
    return
  end

  requestId = requestId + 1
  local request = payload or {}
  request.action = action
  request.requestId = requestId

  local ok, encoded = pcall(function() return json.encode(request) end)
  if not ok or type(encoded) ~= 'string' then
    return
  end

  protocol:sendExtendedOpcode(TASK_CENTER_OPCODE, encoded)
end

local function sendRefreshRequest()
  sendRequest('refresh', {
    availablePage = availablePage,
    availablePageSize = availablePageSize,
  })
end

local function getEntriesForCurrentTab()
  if not snapshotData then
    return {}
  end

  if currentTab == 'available' then
    return snapshotData.available or {}
  elseif currentTab == 'active' then
    return snapshotData.active or {}
  else
    return snapshotData.ready or {}
  end
end

local function buildEntryKey(entry)
  if currentTab == 'active' then
    return 'slot:' .. tostring(entry.slot or 0)
  end

  return 'task:' .. tostring(entry.taskId or 0)
end

local function setStatus(text, color)
  if not statusLabel then
    return
  end

  statusLabel:setText(text or '')
  if color then
    statusLabel:setColor(color)
  else
    statusLabel:setColor('#9fc7ff')
  end
end

local function formatCreatures(creatures)
  if not creatures or #creatures == 0 then
    return 'Unknown creature'
  end

  return table.concat(creatures, ', ')
end

local function resolveCreatureOutfit(creatureName)
  if not creatureName or creatureName == '' then
    return nil
  end

  if not g_things or not g_things.getRacesByName or not g_things.getRaceData then
    return nil
  end

  local races = g_things.getRacesByName(creatureName) or {}
  if #races == 0 then
    return nil
  end

  local selected = races[1]
  local needle = tostring(creatureName):lower()
  for _, race in ipairs(races) do
    if tostring(race.name or ''):lower() == needle then
      selected = race
      break
    end
  end

  local raceId = tonumber(selected.raceId)
  if not raceId then
    return nil
  end

  local raceData = g_things.getRaceData(raceId)
  if not raceData or not raceData.outfit or (tonumber(raceData.outfit.type) or 0) <= 0 then
    return nil
  end

  return raceData.outfit
end

local function renderCreaturePreviews(creatures, creatureVisuals)
  if not creaturesPreviewPanel then
    return
  end

  creaturesPreviewPanel:destroyChildren()
  local visualEntries = {}

  if creatureVisuals and #creatureVisuals > 0 then
    for _, visual in ipairs(creatureVisuals) do
      visualEntries[#visualEntries + 1] = {
        name = tostring(visual.name or ''),
        outfitType = tonumber(visual.outfitType) or 0,
      }
    end
  elseif creatures and #creatures > 0 then
    for _, creatureName in ipairs(creatures) do
      visualEntries[#visualEntries + 1] = {
        name = tostring(creatureName or ''),
        outfitType = 0,
      }
    end
  end

  if #visualEntries == 0 then
    return
  end

  local maxPreviews = 6
  for index, visual in ipairs(visualEntries) do
    if index > maxPreviews then
      local more = g_ui.createWidget('TaskCreaturePreview', creaturesPreviewPanel)
      more.nameLabel:setText('+' .. tostring(#visualEntries - maxPreviews))
      more:setTooltip(string.format('%d more creatures', #visualEntries - maxPreviews))
      more.sprite:setVisible(false)
      return
    end

    local preview = g_ui.createWidget('TaskCreaturePreview', creaturesPreviewPanel)
    preview.nameLabel:setText(tostring(visual.name))
    preview:setTooltip(tostring(visual.name))

    local appliedOutfit = nil
    if visual.outfitType and visual.outfitType > 0 then
      appliedOutfit = { type = visual.outfitType, head = 0, body = 0, legs = 0, feet = 0, addons = 0 }
    else
      appliedOutfit = resolveCreatureOutfit(visual.name)
    end

    if appliedOutfit then
      preview.sprite:setOutfit(appliedOutfit)
      pcall(function()
        local creature = preview.sprite:getCreature()
        if creature and creature.setStaticWalking then
          creature:setStaticWalking(1000)
        end
      end)
    else
      preview.sprite:setVisible(false)
    end
  end
end

local function updateStatusFromSnapshot(message)
  local playerData = snapshotData and snapshotData.player or {}
  local cooldownBlocks = playerData and playerData.cooldownBlocksAccept == true
  local cooldownRemaining = math.max(0, tonumber(playerData and playerData.cooldownRemaining) or 0)

  if cooldownBlocks and cooldownRemaining > 0 then
    local mins = math.floor(cooldownRemaining / 60)
    local secs = cooldownRemaining % 60
    setStatus(string.format('Cooldown active: %02d:%02d before new tasks can be accepted.', mins, secs), '#e0b070')
    return
  end

  if message and message ~= '' then
    local lower = message:lower()
    if lower:find('failed', 1, true) or lower:find('invalid', 1, true) or lower:find('error', 1, true) then
      setStatus(message, '#d97a7a')
      return
    end
  end

  setStatus('', '#9fc7ff')
end

local function findSelectedEntry(entriesOverride)
  local entries = entriesOverride or renderedEntries
  if #entries == 0 then
    return nil
  end

  if not selectedKey then
    selectedKey = buildEntryKey(entries[1])
    return entries[1]
  end

  for _, entry in ipairs(entries) do
    if buildEntryKey(entry) == selectedKey then
      return entry
    end
  end

  selectedKey = buildEntryKey(entries[1])
  return entries[1]
end

local function updateDetails()
  if not taskCenterWindow then
    return
  end

  local entry = findSelectedEntry()
  if not entry then
    taskTitle:setText('No task selected')
    creaturesLabel:setText('')
    renderCreaturePreviews(nil, nil)
    progressLabel:setText('')
    rewardLabel:setText('')
    reasonLabel:setText('')
    actionButton:disable()
    return
  end

  local taskName = entry.taskName or ('Task ' .. tostring(entry.taskId or 0))
  local creatures = formatCreatures(entry.creatures)
  taskTitle:setText(taskName)
  creaturesLabel:setText('Creatures: ' .. creatures)
  renderCreaturePreviews(entry.creatures, entry.creatureVisuals)

  if currentTab == 'available' then
    progressLabel:setText('Required kills: ' .. tostring(entry.killsRequired or 0))
    local reward = entry.rewardPreview or {}
    rewardLabel:setText(string.format('Reward Preview: %d XP, %d gold', tonumber(reward.xpBonus) or 0, tonumber(reward.goldBonus) or 0))

    if entry.canAccept then
      reasonLabel:setText('')
      actionButton:setText('Accept Task')
      actionButton:enable()
    else
      reasonLabel:setText('Unavailable: ' .. tostring(entry.lockReason or 'Unknown'))
      actionButton:setText('Accept Task')
      actionButton:disable()
    end
  elseif currentTab == 'active' then
    progressLabel:setText(string.format('Progress: %d / %d (%d%%)', tonumber(entry.progress) or 0, tonumber(entry.required) or 0, tonumber(entry.percent) or 0))
    local reward = entry.rewardPreview or {}
    rewardLabel:setText(string.format('Reward Preview: %d XP, %d gold', tonumber(reward.xpBonus) or 0, tonumber(reward.goldBonus) or 0))
    reasonLabel:setText('Abandoning starts cooldown.')
    actionButton:setText('Abandon Task')
    actionButton:enable()
  else
    progressLabel:setText(string.format('Completed kills: %d', tonumber(entry.killsCompleted) or 0))
    local reward = entry.rewardExact or {}
    rewardLabel:setText(string.format('Ready Reward: %d XP, %d gold', tonumber(reward.xpBonus) or 0, tonumber(reward.goldBonus) or 0))
    reasonLabel:setText('Claiming rewards clears ready tasks.')
    actionButton:setText('Claim Reward')
    actionButton:enable()
  end
end

local function updatePaginator()
  if not availablePaginator or not prevPageButton or not nextPageButton or not pageInfoLabel then
    return
  end

  if currentTab ~= 'available' then
    availablePaginator:hide()
    return
  end

  availablePaginator:show()

  local pagination = snapshotData and snapshotData.pagination and snapshotData.pagination.available or {}
  local page = math.max(1, tonumber(pagination.page) or availablePage or 1)
  local totalPages = math.max(1, tonumber(pagination.totalPages) or 1)
  local totalItems = math.max(0, tonumber(pagination.totalItems) or 0)
  local hasPrev = (pagination.hasPrev == true) or page > 1
  local hasNext = (pagination.hasNext == true) or page < totalPages

  availablePage = page
  pageInfoLabel:setText(string.format('Page %d/%d  (%d tasks)', page, totalPages, totalItems))

  if hasPrev then
    prevPageButton:enable()
  else
    prevPageButton:disable()
  end

  if hasNext then
    nextPageButton:enable()
  else
    nextPageButton:disable()
  end
end

local function renderList()
  if not listPanel then
    return
  end

  listPanel:destroyChildren()
  local entries = getEntriesForCurrentTab()

  -- Snapshot is already filtered server-side (including cooldown-visible tasks).

  -- Always track what's actually rendered so findSelectedEntry stays in sync
  renderedEntries = entries

  if #entries == 0 then
    selectedKey = nil
    local empty = g_ui.createWidget('TaskCenterListItem', listPanel)
    empty.title:setText('Nothing to show')
    empty.subtitle:setText('Try another tab or refresh.')
    empty.status:setText('')
    updateDetails()
    return
  end

  local selectedExists = false
  for _, entry in ipairs(entries) do
    if buildEntryKey(entry) == selectedKey then
      selectedExists = true
      break
    end
  end

  if not selectedExists then
    selectedKey = buildEntryKey(entries[1])
  end

  local function selectRow(widget, key)
    selectedKey = key
    for _, child in ipairs(listPanel:getChildren()) do
      child:setBackgroundColor('#232323')
    end
    widget:setBackgroundColor('#ffffff22')
    updateDetails()
  end

  for _, entry in ipairs(entries) do
    local row = g_ui.createWidget('TaskCenterListItem', listPanel)
    local key = buildEntryKey(entry)
    local name = entry.taskName or ('Task ' .. tostring(entry.taskId or 0))
    local subtitle = formatCreatures(entry.creatures)

    row.title:setText(name)
    row.subtitle:setText(subtitle)

    if currentTab == 'available' then
      if entry.canAccept then
        row.status:setText('Available')
        row.status:setColor('#8fdc8f')
      elseif entry.cooldownLocked then
        row.status:setText('Cooldown')
        row.status:setColor('#e0b070')
      else
        row.status:setText('Locked')
        row.status:setColor('#d18f8f')
      end
    elseif currentTab == 'active' then
      row.status:setText(string.format('%d/%d', tonumber(entry.progress) or 0, tonumber(entry.required) or 0))
      row.status:setColor('#ffd27f')
    else
      row.status:setText('Ready')
      row.status:setColor('#8fdc8f')
    end

    if key == selectedKey then
      row:setBackgroundColor('#ffffff22')
    end

    row.onMousePress = function(widget)
      selectRow(widget, key)
      return true
    end

    row.onClick = function(widget)
      selectRow(widget, key)
    end
  end

  updateDetails()
  updatePaginator()
end

local function setTab(tabName)
  currentTab = tabName

  if availableTab then
    availableTab:setOn(tabName == 'available')
  end
  if activeTab then
    activeTab:setOn(tabName == 'active')
  end
  if readyTab then
    readyTab:setOn(tabName == 'ready')
  end

  selectedKey = nil
  renderList()
end

local function applySnapshot(payload)
  snapshotData = payload and payload.data or nil
  local message = payload and payload.message

  if snapshotData and snapshotData.pagination and snapshotData.pagination.available then
    local page = tonumber(snapshotData.pagination.available.page)
    local pageSize = tonumber(snapshotData.pagination.available.pageSize)
    if page and page >= 1 then
      availablePage = math.floor(page)
    end
    if pageSize and pageSize >= 1 then
      availablePageSize = math.floor(pageSize)
    end
  end

  updateStatusFromSnapshot(message)

  renderList()
end

local function ensureWindow()
  if taskCenterWindow then
    return taskCenterWindow
  end

  taskCenterWindow = g_ui.displayUI('taskcenter', rootWidget)
  if not taskCenterWindow then
    return nil
  end

  availableTab = taskCenterWindow:getChildById('availableTab')
  activeTab = taskCenterWindow:getChildById('activeTab')
  readyTab = taskCenterWindow:getChildById('readyTab')
  listPanel = taskCenterWindow:recursiveGetChildById('listPanel')
  statusLabel = taskCenterWindow:recursiveGetChildById('statusLabel')
  taskTitle = taskCenterWindow:recursiveGetChildById('taskTitle')
  creaturesLabel = taskCenterWindow:recursiveGetChildById('creaturesLabel')
  progressLabel = taskCenterWindow:recursiveGetChildById('progressLabel')
  rewardLabel = taskCenterWindow:recursiveGetChildById('rewardLabel')
  reasonLabel = taskCenterWindow:recursiveGetChildById('reasonLabel')
  creaturesPreviewPanel = taskCenterWindow:recursiveGetChildById('creaturesPreviewPanel')
  actionButton = taskCenterWindow:recursiveGetChildById('actionButton')
  refreshButton = taskCenterWindow:recursiveGetChildById('refreshButton')
  closeButton = taskCenterWindow:recursiveGetChildById('closeButton')
  availablePaginator = taskCenterWindow:recursiveGetChildById('availablePaginator')
  prevPageButton = taskCenterWindow:recursiveGetChildById('prevPageButton')
  nextPageButton = taskCenterWindow:recursiveGetChildById('nextPageButton')
  pageInfoLabel = taskCenterWindow:recursiveGetChildById('pageInfoLabel')

  availableTab.onClick = function() setTab('available') end
  activeTab.onClick = function() setTab('active') end
  readyTab.onClick = function() setTab('ready') end

  actionButton.onClick = function()
    local entry = findSelectedEntry()
    if not entry then
      return
    end

    if currentTab == 'available' then
      sendRequest('accept', {
        taskId = entry.taskId,
        availablePage = availablePage,
        availablePageSize = availablePageSize,
      })
    elseif currentTab == 'active' then
      sendRequest('abandon', {
        slot = entry.slot,
        availablePage = availablePage,
        availablePageSize = availablePageSize,
      })
    else
      sendRequest('claim', {
        availablePage = availablePage,
        availablePageSize = availablePageSize,
      })
    end
  end

  refreshButton.onClick = function()
    sendRefreshRequest()
  end

  prevPageButton.onClick = function()
    if availablePage <= 1 then
      return
    end

    availablePage = availablePage - 1
    sendRefreshRequest()
  end

  nextPageButton.onClick = function()
    local totalPages = 1
    if snapshotData and snapshotData.pagination and snapshotData.pagination.available then
      totalPages = math.max(1, tonumber(snapshotData.pagination.available.totalPages) or 1)
    end

    if availablePage >= totalPages then
      return
    end

    availablePage = availablePage + 1
    sendRefreshRequest()
  end

  closeButton.onClick = function()
    modules.game_taskcenter.hide()
  end

  setTab('available')
  setStatus('', '#9fc7ff')
  taskCenterWindow:hide()

  return taskCenterWindow
end

local function onExtendedOpcode(protocol, opcode, buffer)
  local payload = nil
  if type(buffer) == 'string' and buffer ~= '' then
    local ok, decoded = pcall(function() return json.decode(buffer) end)
    if ok and type(decoded) == 'table' then
      payload = decoded
    end
  end

  if not payload then
    return
  end

  local action = tostring(payload.action or ''):lower()

  if action == 'open' then
    modules.game_taskcenter.show()
    sendRequest('refresh', {
      source = payload.source or 'server',
      availablePage = availablePage,
      availablePageSize = availablePageSize,
    })
    return
  end

  if action == 'snapshot' then
    modules.game_taskcenter.show()
    applySnapshot(payload)
    return
  end

  if action == 'error' then
    modules.game_taskcenter.show()
    setStatus(payload.message or 'Task Center request failed.', '#d97a7a')
  end
end

function init()
  connect(g_game, {
    onGameEnd = destroyWindow,
  })

  ProtocolGame.registerExtendedOpcode(TASK_CENTER_OPCODE, onExtendedOpcode)

  taskCenterButton = modules.client_topmenu.addRightGameToggleButton('taskCenterButton', tr('Task Center'), '/images/topbuttons/quest_tracker',
    function()
      modules.game_taskcenter.toggle()
    end, false, 11)
end

function terminate()
  ProtocolGame.unregisterExtendedOpcode(TASK_CENTER_OPCODE)

  disconnect(g_game, {
    onGameEnd = destroyWindow,
  })

  destroyWindow()

  if taskCenterButton then
    taskCenterButton:destroy()
    taskCenterButton = nil
  end
end

function show()
  local window = ensureWindow()
  if not window then
    return
  end

  window:show()
  window:raise()
  window:focus()

  if taskCenterButton then
    taskCenterButton:setOn(true)
  end
end

function hide()
  if taskCenterWindow then
    taskCenterWindow:hide()
  end

  if taskCenterButton then
    taskCenterButton:setOn(false)
  end
end

function toggle()
  local window = ensureWindow()
  if not window then
    return
  end

  if window:isVisible() then
    hide()
    return
  end

  show()
  sendRequest('open', { source = 'client_toggle' })
end
