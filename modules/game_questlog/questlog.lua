questLogButton = nil
questTrackerButton = nil
window = nil
trackerWindow = nil
settings = {}
hideCompletedSettings = {}
currentQuestLogEntries = nil

local callDelay = 1000 -- each call delay is also increased by random values (0-callDelay/2)
local dispatcher = {}
local refreshQuestsEvent = nil
local refreshTrackerEvent = nil
local LOGIN_TRACKER_SYNC_DELAY = 1200
local TRACKER_REQUEST_STEP_DELAY = 120
local updateHideCompletedButton = nil

function init()
  g_ui.importStyle('questlogwindow')

  window = g_ui.createWidget('QuestLogWindow', rootWidget)
  window:hide()
  trackerWindow = g_ui.createWidget('QuestTracker', modules.game_interface.getRightPanel())
  trackerWindow:setup()
  trackerWindow:hide()
  
  if not g_app.isMobile() then
    questLogButton = modules.client_topmenu.addLeftGameButton('questLogButton', tr('Quest Log'), '/images/topbuttons/questlog', function() g_game.requestQuestLog() end, false, 8)
    questTrackerButton = modules.client_topmenu.addLeftGameButton('questTrackerButton', tr('Quest Tracker'), '/images/topbuttons/quest_tracker', toggle, false, 9)
  end
  
  connect(g_game, { onQuestLog = onGameQuestLog,
                    onQuestLine = onGameQuestLine,
                    onGameEnd = offline,
                    onGameStart = online})
  online()
end

function terminate()
  disconnect(g_game, { onQuestLog = onGameQuestLog,
                       onQuestLine = onGameQuestLine,
                       onGameEnd = offline,
                       onGameStart = online})

  offline()
  if questLogButton then
    questLogButton:destroy()
  end
  if questTrackerButton then
    questTrackerButton:destroy()
  end
end

function toggle()
  if trackerWindow:isVisible() then
    trackerWindow:hide()
  else
    trackerWindow:show()
  end
end

function offline()
  if refreshQuestsEvent then
    removeEvent(refreshQuestsEvent)
    refreshQuestsEvent = nil
  end
  if refreshTrackerEvent then
    removeEvent(refreshTrackerEvent)
    refreshTrackerEvent = nil
  end

  if window then
    window:hide()
  end
  if trackerWindow then
    trackerWindow:hide()
  end
  save()
  -- reset tracker
  trackerWindow.contentsPanel.list:destroyChildren()
  trackerWindow.contentsPanel.list:setHeight(0)
end

function online()
  local playerName = g_game.getCharacterName()
  if not playerName then return end -- just to be sure

  if refreshQuestsEvent then
    removeEvent(refreshQuestsEvent)
    refreshQuestsEvent = nil
  end
  if refreshTrackerEvent then
    removeEvent(refreshTrackerEvent)
    refreshTrackerEvent = nil
  end

  load()
  refreshQuests()
  -- Delay initial tracker sync slightly to avoid request bursts while
  -- the login/map packet burst is still being processed.
  refreshTrackerEvent = scheduleEvent(function()
    refreshTrackerEvent = nil
    refreshTrackerWidgets()
  end, LOGIN_TRACKER_SYNC_DELAY)

  local playerName = g_game.getCharacterName()
  settings[playerName] = settings[playerName] or {}
  hideCompletedSettings[playerName] = hideCompletedSettings[playerName] or false
  local settings = settings[playerName]
  updateHideCompletedButton()
  local missionList = window.missionlog.missionList
  local track = window.missionlog.track
  local missionDescription = window.missionlog.missionDescription

  connect(missionList, { 
    onChildFocusChange = function(self, focusedChild)
      if focusedChild == nil then return end
        missionDescription:setText(focusedChild.description)
        if focusedChild:isVisible() then
          track:setEnabled(true)
        end
        track:setChecked(settings[focusedChild.trackData])
      end 
    }
  )
end

local function shouldHideCompletedQuests()
  local playerName = g_game.getCharacterName()
  if not playerName then return false end
  return hideCompletedSettings[playerName] == true
end

updateHideCompletedButton = function()
  if not window or not window.hideCompletedButton then
    return
  end

  if shouldHideCompletedQuests() then
    window.hideCompletedButton:setText('Show Completed')
  else
    window.hideCompletedButton:setText('Hide Completed')
  end
end

local function renderQuestLog(quests)
  local questList = window.questlog.questList
  questList:destroyChildren()

  local rowIndex = 0
  for _, questEntry in pairs(quests or {}) do
    local id, name, completed = unpack(questEntry)
    local isCompleted = completed == true or completed == 1

    if not (shouldHideCompletedQuests() and isCompleted) then
      rowIndex = rowIndex + 1

      local questLabel = g_ui.createWidget('QuestLabel', questList)
      questLabel:setChecked(rowIndex % 2 == 0)
      questLabel.questId = id -- for quest tracker
      questLabel.questName = name
      name = isCompleted and name .. " (completed)" or name
      questLabel:setText(name)
      questLabel.onDoubleClick = function()
        window.missionlog.currentQuest = id
        g_game.requestQuestLine(id)
        window.missionlog.questName:setText(questLabel.questName)
      end
    end
  end

  local firstChild = questList:getFirstChild()
  if firstChild then
    questList:focusChild(firstChild)
  end
end

function show(questlog)
  if questlog then
    window:raise()
    window:show()
    window:focus()
    window.missionlog.currentQuest = nil -- reset current quest
    window.questlog:setVisible(true)
    window.missionlog:setVisible(false)
    window.closeButton:setText('Close')
    window.showButton:setVisible(true)
    window.hideCompletedButton:setVisible(true)
    window.missionlog.track:setEnabled(false)
    window.missionlog.track:setChecked(false)
    window.missionlog.missionDescription:setText('')
    updateHideCompletedButton()
  else
    window.questlog:setVisible(false)
    window.missionlog:setVisible(true)
    window.closeButton:setText('Back')
    window.showButton:setVisible(false)
    window.hideCompletedButton:setVisible(false)
  end
end

function back()
  if window:isVisible() then
    if window.questlog:isVisible() then
      window:hide()
    else
      show(true)
    end
  end
end

function showQuestLine()
  local questList = window.questlog.questList
  local child = questList:getFocusedChild()

  g_game.requestQuestLine(child.questId)
  window.missionlog.questName:setText(child.questName)
  window.missionlog.currentQuest = child.questId
end

function onGameQuestLog(quests)
  show(true)
  currentQuestLogEntries = quests
  updateHideCompletedButton()
  renderQuestLog(quests)
end

function onHideCompletedButtonClick()
  local playerName = g_game.getCharacterName()
  if not playerName then
    return
  end

  hideCompletedSettings[playerName] = not shouldHideCompletedQuests()
  updateHideCompletedButton()
  renderQuestLog(currentQuestLogEntries)
  save()
end

function onGameQuestLine(questId, questMissions)
  show(false)
  local missionList = window.missionlog.missionList

  if questId == window.missionlog.currentQuest then
    missionList:destroyChildren()
  end
  for i,questMission in pairs(questMissions) do
    local name, description = unpack(questMission)

    --questlog
    local missionLabel = g_ui.createWidget('QuestLabel', missionList)
    local widgetId = questId..'.'..i
    missionLabel:setChecked(i % 2 == 0)
    missionLabel:setId(widgetId)
    missionLabel.questId = questId
    missionLabel.trackData = widgetId
    missionLabel:setText(name)
    missionLabel.description = description
    missionLabel:setVisible(questId == window.missionlog.currentQuest)

    --tracker
    local trackerLabel = trackerWindow.contentsPanel.list[widgetId]
    trackerLabel = trackerLabel or g_ui.createWidget('QuestTrackerLabel', trackerWindow.contentsPanel.list)
    trackerLabel:setId(widgetId)
    trackerLabel.description:setText(description)
    local data = settings[g_game.getCharacterName()]
    trackerLabel:setVisible(description:len() > 0 and data[widgetId])
  end
  local focusTarget = missionList:getFirstChild()
  if focusTarget and focusTarget:isVisible() then
    missionList:focusChild(focusTarget)
  end
end

function onTrackOptionChange(checkbox)
  local newStatus = not checkbox:isChecked()
  checkbox:setChecked(newStatus)

  local missionList = window.missionlog.missionList
  local focused = missionList:getFocusedChild()
  if not focused then return end
  local settings = settings[g_game.getCharacterName()]
  local trackdata = focused.trackData

  -- settings
  settings[trackdata] = newStatus

  local trackerWidget = trackerWindow.contentsPanel.list[trackdata]
  if trackerWidget then
    trackerWidget:setVisible(newStatus)
  end

  refreshQuests()
  save()
end

function refreshQuests()
  if not g_game.isOnline() then
    refreshQuestsEvent = nil
    return
  end
  local data = settings[g_game.getCharacterName()]
  data = data or {}

  -- do not execute when questlost is in use
  if not window:isVisible() then
    for questData, track in pairs(data) do
      local id = string.split(questData, ".")[1]

      if not track then
        dispatcher[questData] = nil -- remove from dispatcher if no longer tracked
      else
        dispatcher[questData] = dispatcher[questData] or g_clock.millis()
      end

      if dispatcher[questData] and g_clock.millis() > dispatcher[questData] + callDelay + math.random(callDelay/2) then
        dispatcher[questData] = g_clock.millis()
        scheduleEvent(function()
          g_game.requestQuestLine(id) -- request update
        end, math.random(callDelay/2) )
      end
    end
  end

  refreshQuestsEvent = scheduleEvent(refreshQuests, callDelay)
end

function refreshTrackerWidgets()
  if not g_game.isOnline() then return end
  local data = settings[g_game.getCharacterName()]
  data = data or {}

  local pendingQuestIds = {}

  for questData, enabled in pairs(data) do
    local parts = string.split(questData, ".")
    local id = tonumber(parts[1])

    local widget = trackerWindow.contentsPanel.list[questData]
    if enabled and not widget and id then
      table.insert(pendingQuestIds, id)
    end
  end

  table.sort(pendingQuestIds)
  for i, id in ipairs(pendingQuestIds) do
    scheduleEvent(function()
      if g_game.isOnline() then
        g_game.requestQuestLine(id)
      end
    end, (i - 1) * TRACKER_REQUEST_STEP_DELAY)
  end
end

-- json handlers
function load()
  local file = modules.client_profiles.getSettingsFilePath("questlog.json")
  if g_resources.fileExists(file) then
    local status, result = pcall(function()
        return json.decode(g_resources.readFileContents(file))
    end)
    if not status then
        return g_logger.error(
                   "Error while reading profiles file. To fix this problem you can delete storage.json. Details: " ..
                       result)
    end
    if type(result) == 'table' and result.settings then
      settings = result.settings or {}
      hideCompletedSettings = result.hideCompletedSettings or {}
    else
      settings = result or {}
      hideCompletedSettings = {}
    end
  end
end

function save()
  local file = modules.client_profiles.getSettingsFilePath("questlog.json")
  local payload = {
    settings = settings,
    hideCompletedSettings = hideCompletedSettings,
  }
  local status, result = pcall(function() return json.encode(payload, 2) end)
  if not status then
      return g_logger.error(
                 "Error while saving profile settings. Data won't be saved. Details: " ..
                     result)
  end
  if result:len() > 100 * 1024 * 1024 then
      return g_logger.error(
                 "Something went wrong, file is above 100MB, won't be saved")
  end
  g_resources.writeFileContents(file, result)
end