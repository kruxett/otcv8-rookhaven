local characterPanel = nil
local UI = nil
local _sessionStartXp = nil
local _sessionStartTime = nil
local _sessionXpGained = 0       -- accumulated XP delta from onExperienceChange
local _sessionLastXp  = nil      -- last known XP value for delta calculation
local characterLiveRefreshEvent = nil
local characterLiveSignalsConnected = false
local _serverCharacterTitle = nil
local _serverAscension = nil
local _serverClassName = nil
local characterLivePollEvent = nil
local characterPresentationModel = nil
local characterSourceSelection = { overview = nil, talents = nil }
local combatSourceOpen = false
local combatRows = {}
local combatLayoutEvent = nil

local function cancelCharacterLivePoll()
    if characterLivePollEvent then
        removeEvent(characterLivePollEvent)
        characterLivePollEvent = nil
    end
end

local function cancelCharacterLiveRefresh()
    if characterLiveRefreshEvent then
        removeEvent(characterLiveRefreshEvent)
        characterLiveRefreshEvent = nil
    end
end

local function shouldRefreshCharacterStatsLive()
    if not UI or not UI:isVisible() or not g_game.isOnline() then
        return false
    end

    local selected = UI.selectedOption
    return selected == "InfoBase"
        or selected == "PassiveStats"
        or selected == "CharacterStats"
        or selected == "CombatStats"
        or selected == "OffenceStats"
        or selected == "DeffenceStats"
        or selected == "MiscStats"
end

local function refreshSelectedCharacterStatsNow()
    if not shouldRefreshCharacterStatsLive() then
        return
    end

    local selected = UI.selectedOption
    if selected == "InfoBase" then
        Cyclopedia.sendCyclopediaRequest("character.baseInfo", "")
    elseif selected == "PassiveStats" then
        Cyclopedia.sendCyclopediaRequest("character.combatStats", "")
    elseif selected == "CharacterStats" then
        if Cyclopedia.buildAndLoadGeneralStats then
            Cyclopedia.buildAndLoadGeneralStats()
        end
    else
        local infoType = nil
        if selected == "CombatStats" then
            infoType = CyclopediaCharacterInfoTypes and CyclopediaCharacterInfoTypes.CombatStats
        elseif selected == "OffenceStats" then
            infoType = CyclopediaCharacterInfoTypes and CyclopediaCharacterInfoTypes.Offencestats
        elseif selected == "DeffenceStats" then
            infoType = CyclopediaCharacterInfoTypes and CyclopediaCharacterInfoTypes.Defencestats
        elseif selected == "MiscStats" then
            infoType = CyclopediaCharacterInfoTypes and CyclopediaCharacterInfoTypes.Miscstats
        end

        if infoType and g_game.requestCharacterInfo then
            g_game.requestCharacterInfo(0, infoType)
        end
    end
end

local function pollCharacterStats()
    cancelCharacterLivePoll()
    if not UI or not g_game.isOnline() then return end
    characterLivePollEvent = scheduleEvent(function()
        characterLivePollEvent = nil
        refreshSelectedCharacterStatsNow()
        pollCharacterStats()
    end, 1000)
end

local function queueCharacterLiveRefresh()
    if not shouldRefreshCharacterStatsLive() then
        return
    end

    cancelCharacterLiveRefresh()
    characterLiveRefreshEvent = scheduleEvent(function()
        characterLiveRefreshEvent = nil
        refreshSelectedCharacterStatsNow()
    end, 220)
end

local function onCharacterLiveStatsChanged(...)
    queueCharacterLiveRefresh()
end

-- Dedicated XP handler: signal fires as (newXp, oldXp) — no player arg
local function onCharacterXpChanged(newXp, oldXp)
    if type(newXp) == 'number' and type(oldXp) == 'number' then
        local delta = newXp - oldXp
        if delta > 0 then
            _sessionXpGained = (_sessionXpGained or 0) + delta
            _sessionStartTime = _sessionStartTime or os.time()
        end
    end
    queueCharacterLiveRefresh()
end

local function disconnectCharacterLiveSignals()
    if not characterLiveSignalsConnected then
        return
    end

    disconnect(LocalPlayer, {
        onInventoryChange = onCharacterLiveStatsChanged,
        onHealthChange = onCharacterLiveStatsChanged,
        onManaChange = onCharacterLiveStatsChanged,
        onExperienceChange = onCharacterXpChanged,
        onLevelChange = onCharacterLiveStatsChanged,
        onSpeedChange = onCharacterLiveStatsChanged,
        onBaseSpeedChange = onCharacterLiveStatsChanged,
        onFreeCapacityChange = onCharacterLiveStatsChanged,
        onTotalCapacityChange = onCharacterLiveStatsChanged,
        onRegenerationChange = onCharacterLiveStatsChanged,
        onStatesChange = onCharacterLiveStatsChanged,
        onStaminaChange = onCharacterLiveStatsChanged,
        onSkillChange = onCharacterLiveStatsChanged,
        onBaseSkillChange = onCharacterLiveStatsChanged,
        onMagicLevelChange = onCharacterLiveStatsChanged,
        onBaseMagicLevelChange = onCharacterLiveStatsChanged,
    })

    characterLiveSignalsConnected = false
end

local function connectCharacterLiveSignals()
    disconnectCharacterLiveSignals()

    connect(LocalPlayer, {
        onInventoryChange = onCharacterLiveStatsChanged,
        onHealthChange = onCharacterLiveStatsChanged,
        onManaChange = onCharacterLiveStatsChanged,
        onExperienceChange = onCharacterXpChanged,
        onLevelChange = onCharacterLiveStatsChanged,
        onSpeedChange = onCharacterLiveStatsChanged,
        onBaseSpeedChange = onCharacterLiveStatsChanged,
        onFreeCapacityChange = onCharacterLiveStatsChanged,
        onTotalCapacityChange = onCharacterLiveStatsChanged,
        onRegenerationChange = onCharacterLiveStatsChanged,
        onStatesChange = onCharacterLiveStatsChanged,
        onStaminaChange = onCharacterLiveStatsChanged,
        onSkillChange = onCharacterLiveStatsChanged,
        onBaseSkillChange = onCharacterLiveStatsChanged,
        onMagicLevelChange = onCharacterLiveStatsChanged,
        onBaseMagicLevelChange = onCharacterLiveStatsChanged,
    })

    characterLiveSignalsConnected = true
end

function Cyclopedia.resetSessionXp()
    _sessionStartXp   = nil
    _sessionStartTime = nil
    _sessionXpGained  = 0
    _sessionLastXp    = nil
    _profileKills     = nil
    _profileDeaths    = nil
    _cachedVocationName = nil
    _serverCharacterTitle = nil
    _serverAscension = nil
    _serverClassName = nil
    Cyclopedia.characterPassiveStats = nil
    characterPresentationModel = nil
    characterSourceSelection = { overview = nil, talents = nil }
    combatSourceOpen = false
    combatRows = {}
    if combatLayoutEvent then removeEvent(combatLayoutEvent); combatLayoutEvent = nil end
    cancelCharacterLivePoll()
end

local function getPlayerVocationName(player)
    if not player then
        return "Unknown"
    end

    if _serverCharacterTitle and _serverCharacterTitle ~= "" then
        return _serverCharacterTitle
    end

    -- Return cached vocation if available (from server character data)
    if _cachedVocationName then
        return _cachedVocationName
    end

    local vocationId = player.getVocation and player:getVocation() or 0
    local vocationNames = _G.CyclopediaVocationFallbackNames or {
        [0] = "Unawakened",
        [1] = "Awakened",
        [2] = "Ascendant",
        [3] = "Ascended",
        [4] = "Knight",
        [5] = "Master Sorcerer",
        [6] = "Elder Druid",
        [7] = "Royal Paladin",
        [8] = "Elite Knight"
    }

    -- Some client builds can return an outdated client-id vocation name.
    -- Prefer server vocation id mapping whenever it is available.
    if vocationId > 0 then
        _cachedVocationName = vocationNames[vocationId] or tostring(vocationId)
        return _cachedVocationName
    end

    if player.getVocationNameByClientId then
        local byClientId = player:getVocationNameByClientId()
        if byClientId and byClientId ~= "" then
            _cachedVocationName = byClientId
            return _cachedVocationName
        end
    end

    _cachedVocationName = vocationNames[vocationId] or tostring(vocationId)
    return _cachedVocationName
end

local function updateCharacterIdentityHeader()
    local player = g_game.getLocalPlayer()
    if not player or not UI or not UI.CharacterBase then return end
    local class = _serverClassName or (_serverAscension and "Class not chosen" or getPlayerVocationName(player))
    UI.CharacterBase.InfoLabel:setText(string.format("Level: %d\n%s\nAscension: %s", player:getLevel(), class, _serverAscension or "—"))
end

local function close(parent)
    if table.empty(parent.subCategories) then
        return
    end

    for subId, _ in ipairs(parent.subCategories) do
        local subWidget = parent:getChildById(subId)

        if subWidget then
            subWidget:setVisible(false)
        end
    end

    parent:setHeight(parent.closedSize)
    parent.opened = false
    parent.Button.Arrow:setVisible(true)
end

local function reset()
    _cachedVocationName = nil  -- Clear vocation cache on reset
    _serverCharacterTitle = nil
    characterPanel.InfoBase.inventoryPanel:setVisible(true)
    characterPanel.InfoBase.outfitPanel:setVisible(false)

    if characterPanel.InfoBase.CharacterButton.state ~= 1 then
        Cyclopedia.characterButton(characterPanel.InfoBase.CharacterButton)
    end

    Cyclopedia.selectCharacterPage()
    characterPanel.openedCategory = nil
end

local function open(parent)
    local oldOpen = UI.openedCategory

    for subId, _ in ipairs(parent.subCategories) do
        local subWidget = parent:getChildById(subId)

        if subWidget then
            if tonumber(subWidget:getId()) == 1 then
                subWidget.Button.onClick(subWidget)
            end

            subWidget:setVisible(true)
        end
    end

    if oldOpen ~= nil and oldOpen ~= parent then
        close(oldOpen)
    end

    parent:setHeight(parent.openedSize)
    parent.opened = true
    parent.Button.Arrow:setVisible(false)

    UI.openedCategory = parent
end

function showCharacter()
    characterPanel = g_ui.loadUI("character", contentContainer)
    UI = characterPanel
    characterPanel:show()
    connectCharacterLiveSignals()
    UI.selectedOption = "InfoBase"

    if g_game.isOnline() then
        local player = g_game.getLocalPlayer()
        UI.CharacterBase:setText(player:getName())
        updateCharacterIdentityHeader()
        UI.CharacterBase.Outfit:setOutfit(player:getOutfit())

        UI.InfoBase.outfitPanel.Sprite:setOutfit(player:getOutfit())
        UI.InfoBase.InspectLabel:setText(tr("You are inspecting") .. ": " .. player:getName())

        for i = InventorySlotFirst, InventorySlotPurse do
            local item = player:getInventoryItem(i)
            local itemWidget = UI.InfoBase.inventoryPanel["slot" .. i]
            if itemWidget then
                if item then
                    itemWidget:setStyle("InventoryItemCyclopedia")
                    itemWidget:setItem(item)
                    if ItemsDatabase then
                        if ItemsDatabase.setRarityItem then
                            ItemsDatabase.setRarityItem(itemWidget, itemWidget:getItem())
                        end
                        if ItemsDatabase.setTier then
                            ItemsDatabase.setTier(itemWidget, itemWidget:getItem())
                        end
                    end
                    itemWidget:setIcon("")
                else
                    itemWidget:setStyle(Cyclopedia.InventorySlotStyles[i].name)
                    itemWidget:setIcon(Cyclopedia.InventorySlotStyles[i].icon)
                    itemWidget:setItem(nil)
                end
            end
        end

        if g_game.isOnline() then
            Cyclopedia.createCharacterDescription()
            Cyclopedia.configureCharacterCategories()
        end
    end

    reset()
    Cyclopedia.renderCharacterPresentation()
    local thisPanel = characterPanel
    thisPanel.onDestroy = function()
        if UI == thisPanel then
            if combatLayoutEvent then removeEvent(combatLayoutEvent); combatLayoutEvent = nil end
            combatRows = {}
            cancelCharacterLivePoll()
            cancelCharacterLiveRefresh()
            disconnectCharacterLiveSignals()
            UI = nil
            characterPanel = nil
        end
    end
    Cyclopedia.sendCyclopediaRequest("character.baseInfo", "")
    pollCharacterStats()
    controllerCyclopedia.ui.CharmsBase:setVisible(false)  -- charms not used in 8.60
    controllerCyclopedia.ui.GoldBase:setVisible(true)
    controllerCyclopedia.ui.BestiaryTrackerButton:setVisible(false)
    if controllerCyclopedia.ui.TaskTrackerButton then
        controllerCyclopedia.ui.TaskTrackerButton:setVisible(false)
    end
    if g_game.getClientVersion() >= 1410 then
        controllerCyclopedia.ui.CharmsBase1410:setVisible(true)
    end
end

Cyclopedia.Character = {}
Cyclopedia.Character.Achievements = {}
Cyclopedia.Character.Items = Cyclopedia.Character.Items or {}
Cyclopedia.InventorySlotStyles = {
    [InventorySlotHead] = {
        icon = "/images/game/slots/inventory-head",
        name = "CyclopediaHeadSlot"
    },
    [InventorySlotNeck] = {
        icon = "/images/game/slots/inventory-neck",
        name = "CyclopediaNeckSlot"
    },
    [InventorySlotBack] = {
        icon = "/images/game/slots/inventory-back",
        name = "CyclopediaBackSlot"
    },
    [InventorySlotBody] = {
        icon = "/images/game/slots/inventory-torso",
        name = "CyclopediaBodySlot"
    },
    [InventorySlotRight] = {
        icon = "/images/game/slots/inventory-right-hand",
        name = "CyclopediaRightSlot"
    },
    [InventorySlotLeft] = {
        icon = "/images/game/slots/inventory-left-hand",
        name = "CyclopediaLeftSlot"
    },
    [InventorySlotLeg] = {
        icon = "/images/game/slots/inventory-legs",
        name = "CyclopediaLegSlot"
    },
    [InventorySlotFeet] = {
        icon = "/images/game/slots/inventory-feet",
        name = "CyclopediaFeetSlot"
    },
    [InventorySlotFinger] = {
        icon = "/images/game/slots/inventory-finger",
        name = "CyclopediaFingerSlot"
    },
    [InventorySlotAmmo] = {
        icon = "/images/game/slots/inventory-hip",
        name = "CyclopediaAmmoSlot"
    }
}

function Cyclopedia.characterAppearancesFilter(widget)
    -- no-op: filter UI removed; equipment preview has no filter
end

function Cyclopedia.reloadCharacterAppearances()
    Cyclopedia.loadEquipmentPreview()
end

function Cyclopedia.loadEquipmentPreview()
    local player = g_game.getLocalPlayer()
    if not player or not UI or not UI.CharacterAppearances then return end

    local list = UI.CharacterAppearances.ListBase.list
    list:destroyChildren()

    local SLOT_NAMES = {
        [InventorySlotHead]   = "Head",
        [InventorySlotNeck]   = "Neck",
        [InventorySlotBody]   = "Armor",
        [InventorySlotRight]  = "Right Hand",
        [InventorySlotLeft]   = "Left Hand",
        [InventorySlotLeg]    = "Legs",
        [InventorySlotFeet]   = "Feet",
        [InventorySlotFinger] = "Ring",
        [InventorySlotAmmo]   = "Ammo",
        [InventorySlotBack]   = "Backpack",
    }
    local SLOT_ORDER = {
        InventorySlotHead, InventorySlotNeck, InventorySlotBody,
        InventorySlotRight, InventorySlotLeft, InventorySlotLeg,
        InventorySlotFeet, InventorySlotFinger, InventorySlotAmmo,
        InventorySlotBack,
    }

    for _, slot in ipairs(SLOT_ORDER) do
        local widget = g_ui.createWidget("CyclopediaEquipSlot", list)
        if not widget then break end
        widget.slotLabel:setText(SLOT_NAMES[slot] or "")

        local item = player:getInventoryItem(slot)
        if item then
            widget.itemWidget:setItem(item)
            local thing = g_things.getThingType(item:getId(), ThingCategoryItem)
            local marketData = thing and thing.getMarketData and thing:getMarketData() or nil
            local name = (marketData and marketData.name ~= "" and marketData.name) or ("Item #" .. item:getId())
            widget.itemLabel:setText(name)
            widget.itemLabel:setColor("#C0C0C0")
        else
            widget.itemWidget:setItem(nil)
            widget.itemLabel:setText("—")
            widget.itemLabel:setColor("#404040")
        end
    end
end

function Cyclopedia.loadCharacterAppearances(color, outfits, mounts, familiars)
    -- Repurposed: show equipment preview instead of outfit gallery
    Cyclopedia.loadEquipmentPreview()
end

function Cyclopedia.characterItemsSearch(text)
    local filter = UI.CharacterItems.filters
    local activeFilters = {}

    for i = 1, filter:getChildCount() do
        local child = filter:getChildByIndex(i)
        if child:isChecked() then
            table.insert(activeFilters, child:getId())
        end
    end

    local characterItems = Cyclopedia.Character.Items or {}
    for _, item in ipairs(characterItems) do
        local data = item.data
        local name = data.name:lower()
        local meetsSearchCriteria = text == "" or string.find(name, text:lower()) ~= nil
        local meetsFilterCriteria = #activeFilters == 0 or table.contains(activeFilters, data.type)
        data.visible = meetsSearchCriteria and meetsFilterCriteria
    end

    Cyclopedia.reloadCharacterItems()
end

function Cyclopedia.characterItemsFilter(widget, force)
    if force then
        widget:setChecked(true)
    end

    local id = widget:getId()

    local characterItems = Cyclopedia.Character.Items or {}
    for _, item in ipairs(characterItems) do
        local data = item.data
        if data.type == id then
            data.visible = widget:isChecked()
        end
    end

    Cyclopedia.reloadCharacterItems()
end

function Cyclopedia.reloadCharacterItems()
    UI.CharacterItems.ListBase.list:destroyChildren()
    UI.CharacterItems.gridBase.grid:destroyChildren()

    local colors = {"#484848", "#414141"}
    local colorIndex = 1

    local characterItems = Cyclopedia.Character.Items or {}
    for _, item in ipairs(characterItems) do
        local itemId, data = item.itemId, item.data

        if data.visible then
            local listItem = g_ui.createWidget("CharacterListItem", UI.CharacterItems.ListBase.list)
            listItem.item:setItemId(itemId)
            listItem.name:setText(data.name)
            if ItemsDatabase then
                if ItemsDatabase.setRarityItem then
                    ItemsDatabase.setRarityItem(listItem.item, listItem.item:getItem())
                end
                if ItemsDatabase.setTier then
                    ItemsDatabase.setTier(listItem.item, item.tier)
                end
            end
            listItem.amount:setText(data.amount)
            listItem:setBackgroundColor(colors[colorIndex])
            local gridItem = g_ui.createWidget("CharacterGridItem", UI.CharacterItems.gridBase.grid)
            gridItem.item:setItemId(itemId)
            gridItem.amount:setText(data.amount)
            if ItemsDatabase then
                if ItemsDatabase.setRarityItem then
                    ItemsDatabase.setRarityItem(gridItem.item, gridItem.item:getItem())
                end
                if ItemsDatabase.setTier then
                    ItemsDatabase.setTier(gridItem.item, item.tier)
                end
            end
            colorIndex = 3 - colorIndex
        end
    end
end

function Cyclopedia.loadCharacterItems(data)
    local inventory = data.inventory
    local store = data.store
    local stash = data.stash
    local depot = data.depot
    local inbox = data.inbox
    Cyclopedia.Character.Items = {}

    local function insert(data, type)
        if not data then
            return
        end

        local thing = g_things.getThingType(data.itemId, ThingCategoryItem)
        local marketData = thing and thing.getMarketData and thing:getMarketData() or nil
        local marketName = marketData and marketData.name or ""
        local name = marketName:lower()
        name = name ~= "" and name or "?"

        local data_t = {
            visible = false,
            name = name,
            amount = data.amount,
            type = type
        }

        local itemKey = data.itemId .. "-" .. (data.tier or "no_tier")
        local insertedItem = Cyclopedia.Character.Items[itemKey]
        if insertedItem and insertedItem.amount then
            insertedItem.amount = insertedItem.amount + data.amount
        else
            Cyclopedia.Character.Items[itemKey] = {
                itemId = data.itemId,
                tier = data.tier,
                data = data_t
            }
        end
    end

    local function processContainer(container, containerType)
        for i = 0, #container do
            local data = container[i]
            if data then
                insert(data, containerType)
            end
        end
    end

    processContainer(inventory, "inventory")
    processContainer(store, "store")
    processContainer(stash, "stash")
    processContainer(depot, "depot")
    processContainer(inbox, "inbox")

    local sortedItems = {}

    for _, itemData in pairs(Cyclopedia.Character.Items) do
        table.insert(sortedItems, itemData)
    end

    local function compareByName(a, b)
        local nameA = a.data.name:lower()
        local nameB = b.data.name:lower()

        if nameA ~= "?" and nameB == "?" then
            return true
        elseif nameA == "?" and nameB ~= "?" then
            return false
        else
            return nameA < nameB
        end
    end

    table.sort(sortedItems, compareByName)
    Cyclopedia.Character.Items = sortedItems
    Cyclopedia.characterItemsFilter(UI.CharacterItems.filters.inventory, true)
end

function Cyclopedia.loadCharacterAchievements()
    if not Cyclopedia.Character.Achievements.Loaded then
        UI.CharacterAchievements.sort:addOption("Alphabetically", 1, true)
        UI.CharacterAchievements.sort:addOption("By Grade", 2, true)
        UI.CharacterAchievements.sort:addOption("By Unlock Date", 3, true)
        Cyclopedia.achievementFilter(UI.CharacterAchievements.filters.accomplished)
        Cyclopedia.Character.Achievements.Loaded = true
    end
end

function Cyclopedia.characterItemListFilter(widget)
    local parent = widget:getParent()
    for i = 1, parent:getChildCount() do
        local child = parent:getChildByIndex(i)
        if child then
            child:setChecked(false)
        end
    end

    widget:setChecked(true)

    if widget:getId() == "list" then
        UI.CharacterItems.ListBase:setVisible(true)
        UI.CharacterItems.gridBase:setVisible(false)
    else
        UI.CharacterItems.ListBase:setVisible(false)
        UI.CharacterItems.gridBase:setVisible(true)
    end
end

function Cyclopedia.achievementFilter(widget)
    local parent = widget:getParent()
    for i = 1, parent:getChildCount() do
        local child = parent:getChildByIndex(i)
        if child then
            child:setChecked(false)
        end
    end

    if widget:getId() ~= "accomplished" then
        local last = Cyclopedia.Character.Achievements.lastSort
        last = last or 1
        Cyclopedia.achievementSort(last)
    else
        UI.CharacterAchievements.ListBase.List:destroyChildren()
    end

    widget:setChecked(not widget:isChecked())
end

function Cyclopedia.achievementSort(option)
    local tempTable = {}

    for id, data in pairs(ACHIEVEMENTS) do
        local tempData = {
            id = id,
            name = data.name,
            description = data.description,
            grade = data.grade
        }

        table.insert(tempTable, tempData)
    end

    if option == 1 then
        table.sort(tempTable, function(a, b)
            return a.name < b.name
        end)
    elseif option == 2 then
        table.sort(tempTable, function(a, b)
            return a.grade > b.grade
        end)
    end

    UI.CharacterAchievements.ListBase.List:destroyChildren()

    for _, data in pairs(tempTable) do
        local widget = g_ui.createWidget("Achievement", UI.CharacterAchievements.ListBase.List)
        widget:setId(data.id)
        widget.title:setText(data.name)
        widget.title = data.name
        widget:setText(data.description)
        widget.icon:setWidth(11 * data.grade)
        widget.grade = data.grade
    end

    Cyclopedia.Character.Achievements.lastSort = option
end

function Cyclopedia.loadCharacterRecentKills(data)
    UI.RecentKills.ListBase.List:destroyChildren()

    if not table.empty(data) then
        local color = "#484848"

        for i = 1, #data do
            local entry = data[i]
            local time = entry.timestamp
            local description = entry.description
            local status = entry.status
            local widget = g_ui.createWidget("CharacterKill", UI.RecentKills.ListBase.List)

            widget:setId(i)
            widget.date:setText(os.date("%Y-%m-%d, %H:%M:%S", time))
            widget.description:setText(description)
            widget.status:setText(status)
            widget.color = color
            widget:setBackgroundColor(color)

            color = color == "#484848" and "#414141" or "#484848"

            function widget:onClick()
                local parent = widget:getParent()
                for y = 1, parent:getChildCount() do
                    local child = parent:getChildByIndex(y)
                    child:setChecked(false)
                    child.date:setOn(false)
                    child.description:setOn(false)
                    child.status:setOn(false)
                end

                self:setChecked(not self:isChecked())
            end

            function widget:onCheckChange()
                if self:isChecked() then
                    self:setBackgroundColor("#585858")
                else
                    self:setBackgroundColor(self.color)
                end

                self.date:setOn(not self:isOn())
                self.description:setOn(not self:isOn())
                self.status:setOn(not self:isOn())
            end

            if i == 1 then
                widget:setChecked(true)
            end
        end
    end
end

function Cyclopedia.loadCharacterRecentDeaths(data)

    UI.RecentDeaths.ListBase.List:destroyChildren()

    if not table.empty(data) then
        local color = "#484848"

        for i = 1, #data do
            local entry = data[i]
            local widget = g_ui.createWidget("CharacterDeath", UI.RecentDeaths.ListBase.List)

            widget:setId(i)
            widget.date:setText(os.date("%Y-%m-%d, %H:%M:%S", entry.timestamp))
            widget.cause:setText(entry.cause)
            widget.color = color
            widget:setBackgroundColor(color)
            color = color == "#484848" and "#414141" or "#484848"

            function widget:onClick()
                local parent = widget:getParent()
                for y = 1, parent:getChildCount() do
                    local child = parent:getChildByIndex(y)
                    child:setChecked(false)
                    child.cause:setOn(false)
                    child.date:setOn(false)
                end

                self:setChecked(not self:isChecked())
            end

            function widget:onCheckChange()
                if self:isChecked() then
                    self:setBackgroundColor("#585858")
                else
                    self:setBackgroundColor(self.color)
                end

                self.cause:setOn(not self:isOn())
                self.date:setOn(not self:isOn())
            end

            if i == 1 then
                widget:setChecked(true)
            end
        end
    end
end

local function setCombatRowVisible(row, visible)
    if row then row:setVisible(visible); row:setHeight(visible and 20 or 0) end
end

function Cyclopedia.loadCharacterCombatStats(data, mitigation, additionalSkillsArray, forgeSkillsArray,
    perfectShotDamageRanges, combatsArray, concoctionsArray)

    local combat = UI.CombatStats.Viewport.Content
    local rookhaven = g_game.getClientVersion() == 860
    -- Keep the compact layout without duplicated or theoretical total rows.
    for _, id in ipairs({"criticalChance", "armor", "manaLeech", "defenseWindow"}) do
        setCombatRowVisible(combat[id], not rookhaven)
    end
    setCombatRowVisible(combat.atkSpeed, not rookhaven or (data.attackSpeed or 2000) ~= 2000)
    setCombatRowVisible(combat.attack, not rookhaven or (data.weaponMaxHitChance or 0) > 0)

    -- Hide stats not applicable to Tibia 8.60
    local sectionsToHide = {"concoction", "concoctionPanel", "blessings"}
    for _, id in ipairs(sectionsToHide) do
        if combat[id] then
            combat[id]:setVisible(false)
        end
    end

    -- Use dedicated element icons (clientCombat paths) instead of player-state-flags sprite sheet
    local function setElementIcon(iconWidget, elementId)
        local elementInfo = Cyclopedia.clientCombat[elementId]
        if elementInfo then
            iconWidget:setImageSource(elementInfo.path)
            iconWidget:setImageSize({width = 9, height = 9})
        end
    end

    setElementIcon(combat.attack.icon, data.weaponElement)
    combat.attack.value:setText(data.weaponMaxHitChance)

    -- Weapon name tooltip on Attack Value
    do
        local player = g_game.getLocalPlayer()
        if player then
            local function getWeaponName(slot)
                local item = player:getInventoryItem(slot)
                if not item then return nil end
                local thing = g_things.getThingType(item:getId(), ThingCategoryItem)
                local md = thing and thing.getMarketData and thing:getMarketData() or nil
                return (md and md.name ~= "" and md.name) or nil
            end
            local weaponName = getWeaponName(InventorySlotRight) or getWeaponName(InventorySlotLeft)
            if weaponName then
                combat.attack:setTooltip("Weapon attack rating used to calculate normal attack damage; it is not HP damage.\nEquipped: " .. weaponName)
            else
                combat.attack:setTooltip("Weapon attack rating used to calculate normal attack damage; it is not HP damage. Skills, level and fighting stance also affect damage.")
            end
        end
    end

    -- Estimated max hit using real TFS formula:
    -- MaxDamage = round((level/5) + (((skill/4+1) * (attack/3)) * 1.03) / attackFactor)
    -- attackFactor: Full=1.0, Balanced=1.2, Defensive=2.0
    if combat.estDps then
        local player = g_game.getLocalPlayer()
        local skillLevel = player and player:getSkillLevel(data.weaponSkillId or 0) or 0
        local level = player and player:getLevel() or 0
        local attack = data.weaponMaxHitChance or 0
        local elemAttack = data.weaponElementDamage or 0

        local fightMode = g_game.getFightMode()
        local attackFactor = 1.0
        if fightMode == FightBalanced then
            attackFactor = 1.2
        elseif fightMode == FightDefensive then
            attackFactor = 2.0
        end

        local function calcMax(atk)
            if atk <= 0 then return 0 end
            return math.floor((level / 5) + (((skillLevel / 4 + 1) * (atk / 3)) * 1.03) / attackFactor + 0.5)
        end

        local maxPhy = calcMax(attack)
        local maxElem = calcMax(elemAttack)
        local estMaxHit = maxPhy + maxElem

        combat.estDps.value:setText(tostring(estMaxHit))

        local modeNames = { [FightOffensive] = "Full Attack", [FightBalanced] = "Balanced", [FightDefensive] = "Defensive" }
        local modeName = modeNames[fightMode] or "Full Attack"
        local skillNames = { [0]="Fist", [1]="Club", [2]="Sword", [3]="Axe", [4]="Distance" }
        local skillName = skillNames[data.weaponSkillId or 0] or "Fist"
        local tip = string.format(
            "Est. max hit  (%s mode)\n%s skill %d  x  Attack %d  -> Phys: %d",
            modeName, skillName, skillLevel, attack, maxPhy)
        if maxElem > 0 then
            tip = tip .. string.format("\nElement attack %d  -> Elem: %d", elemAttack, maxElem)
            tip = tip .. string.format("\nTotal: %d + %d = %d", maxPhy, maxElem, estMaxHit)
        end
        combat.estDps:setTooltip(tip)
    end
        -- All combat calculations in one scoped block so locals are shared between rows:
        -- MaxDamage = round((level/5) + (((skill/4+1) * (attack/3)) * 1.03) / attackFactor)
        -- attackFactor: Full Attack=1.0, Balanced=1.2, Defensive=2.0
        do
            local combatPlayer = g_game.getLocalPlayer()
            local skillLevel = combatPlayer and combatPlayer:getSkillLevel(data.weaponSkillId or 0) or 0
            local level = combatPlayer and combatPlayer:getLevel() or 0
            local attack = data.weaponMaxHitChance or 0
            local elemAttack = data.weaponElementDamage or 0
            local fightMode = g_game.getFightMode()
            local attackFactor = (fightMode == FightBalanced) and 1.2 or (fightMode == FightDefensive) and 2.0 or 1.0

            local function calcMax(atk)
                if atk <= 0 then return 0 end
                return math.floor((level / 5) + (((skillLevel / 4 + 1) * (atk / 3)) * 1.03) / attackFactor + 0.5)
            end

            local maxPhy  = calcMax(attack)
            local maxElem = calcMax(elemAttack)
            local passiveStats = data.passiveStats or {}
            local estMaxHit  = tonumber(passiveStats.ordinaryMaxHit) or (maxPhy + maxElem)
            local avgHit     = math.floor(estMaxHit / 2)
            local atkSpeedMs = data.attackSpeed or 2000
            local critChance = tonumber(passiveStats.criticalChance) or 0
            local critMultiplier = tonumber(passiveStats.criticalMultiplier) or 200
            local expectedCritFactor = 1 + (critChance / 100) * (critMultiplier / 100 - 1)
            local dpsVal     = (atkSpeedMs > 0) and (avgHit * expectedCritFactor * 1000 / atkSpeedMs) or 0

            local modeNames = { [FightOffensive] = "Full Attack", [FightBalanced] = "Balanced", [FightDefensive] = "Defensive" }
            local modeName  = modeNames[fightMode] or "Full Attack"
            local skillNames = { [0]="Fist", [1]="Club", [2]="Sword", [3]="Axe", [4]="Distance" }
            local skillName  = skillNames[data.weaponSkillId or 0] or "Fist"

            -- Max Hit
            if combat.estDps then
                combat.estDps.value:setText(tostring(estMaxHit))
                local tip = string.format(
                    "Estimated max hit (%s mode)\n%s skill %d x Attack %d -> Physical: %d",
                    modeName, skillName, skillLevel, attack, maxPhy)
                if maxElem > 0 then
                    tip = tip .. string.format("\nElement attack %d -> Element: %d", elemAttack, maxElem)
                    tip = tip .. string.format("\nTotal: %d + %d = %d", maxPhy, maxElem, estMaxHit)
                end
                if passiveStats.ordinaryMaxHit ~= nil then
                    tip = string.format("Server weapon max: %.0f\nCurrent ordinary PvE talent bonus: +%.2f%%\nPrepared primary bonus: +%.2f%%\nBefore critical, target armor, defense and hit checks.\nConditions and secondary passive procs are excluded.",
                        (passiveStats.baseMaxHit or 0) + (passiveStats.baseElementMaxHit or 0),
                        passiveStats.ordinaryDamagePercent or 0, passiveStats.ordinaryPrimaryExtraPercent or 0)
                end
                combat.estDps:setTooltip(tip)
            end

            -- Avg Hit
            if combat.avgHit then
                combat.avgHit.value:setText(tostring(avgHit))
                combat.avgHit:setTooltip(string.format(
                    "Estimated HP damage per normal attack, before critical hits and target defenses.\nRough average: half of current non-critical max hit %d.\nWeapon minimum damage, misses and target reductions can change the actual average.", estMaxHit))
            end

            -- Attack Speed
            if combat.atkSpeed then
                combat.atkSpeed.value:setText(string.format("%.1fs", atkSpeedMs / 1000))
            end

            -- Est. DPS
            if combat.dps then
                combat.dps.value:setText(string.format("%.1f", dpsVal))
                combat.dps:setTooltip(string.format(
                    "Estimated normal attack damage per second against monsters, before misses and target defenses.\nRough DPS = average estimate %.0f / attack interval %.1fs\nCurrent ordinary critical chance and multiplier are included.\nConditions and secondary procs are excluded; actual hunting damage may be lower.",
                    avgHit, atkSpeedMs / 1000))
            end

        end

        -- Defensive rows are intentionally attack-independent.
        do
            local armorVal = data.armor or 0
            local totalMitigationPct = math.max(0, math.min(95, tonumber(mitigation) or 0))
            local defenseVal = math.max(0, tonumber(data.defense) or 0)

            -- Match server armor behavior (Creature::blockHit):
            -- armor 1-3 => fixed reduction of 1
            -- armor >3  => random in [armor/2, armor - (armor % 2 + 1)]
            local function getAverageArmorReduction(armor)
                if armor <= 0 then
                    return 0
                end
                if armor <= 3 then
                    return 1
                end

                local minReduction = math.floor(armor / 2)
                local maxReduction = armor - ((armor % 2) + 1)
                if maxReduction < minReduction then
                    maxReduction = minReduction
                end

                return (minReduction + maxReduction) / 2
            end

            local avgArmor = getAverageArmorReduction(armorVal)

            local minArmorReduction = 0
            local maxArmorReduction = 0
            if armorVal > 0 then
                if armorVal <= 3 then
                    minArmorReduction = 1
                    maxArmorReduction = 1
                else
                    minArmorReduction = math.floor(armorVal / 2)
                    maxArmorReduction = armorVal - ((armorVal % 2) + 1)
                    if maxArmorReduction < minArmorReduction then
                        maxArmorReduction = minArmorReduction
                    end
                end
            end

            -- Match server defense behavior (Creature::blockHit):
            -- damage -= random(defense / 2, defense)
            local minDefenseReduction = math.floor(defenseVal / 2)
            local maxDefenseReduction = defenseVal
            local avgDefenseReduction = (minDefenseReduction + maxDefenseReduction) / 2
            local avgTotalReduction = avgArmor + avgDefenseReduction
            local minTotalReduction = minArmorReduction + minDefenseReduction
            local maxTotalReduction = maxArmorReduction + maxDefenseReduction

            if combat.criticalChance then
                combat.criticalChance.value:setText(string.format("%.1f%%", totalMitigationPct))
                combat.criticalChance.value:setColor(totalMitigationPct >= 15 and "#44AD25" or "#C0C0C0")
                combat.criticalChance:setTooltip(string.format(
                    "Estimate against a 100-damage reference hit.\nNot universal physical resistance.\nAverage flat armor reduction: %.1f per hit.",
                    avgArmor))
            end

            if combat.criticalDamage then
                combat.criticalDamage.value:setText(string.format("%.1f", avgArmor))
                combat.criticalDamage.value:setColor("#C0C0C0")
                combat.criticalDamage:setTooltip(string.format(
                    "Average HP removed from incoming hits that check armor; this is not a percentage.\nArmor value: %d\nAverage reduction: %.1f per hit.", armorVal, avgArmor))
            end

            if combat.lifeLeech then
                combat.lifeLeech.value:setText(string.format("%.1f", avgDefenseReduction))
                combat.lifeLeech.value:setColor("#C0C0C0")
                combat.lifeLeech:setTooltip(string.format(
                    "Average HP removed when an incoming hit gets a defense check.\nNot every attack can be blocked; skill, weapon or shield and stance affect this value.\nDefense value: %d\nRoll range: %d to %d\nAverage reduction: %.1f when a defense check triggers.",
                    defenseVal, minDefenseReduction, maxDefenseReduction, avgDefenseReduction))
            end

            if combat.manaLeech then
                setCombatRowVisible(combat.manaLeech, not rookhaven)
                combat.manaLeech.value:setText(string.format("%.1f", avgTotalReduction))
                combat.manaLeech.value:setColor("#44AD25")
                combat.manaLeech:setTooltip(string.format(
                    "Combined average flat reduction from armor and defense formulas.\nArmor average: %.1f\nDefense average: %.1f\nTotal average: %.1f\nApplies when both checks are active.",
                    avgArmor, avgDefenseReduction, avgTotalReduction))
            end

            if combat.defenseWindow then
                setCombatRowVisible(combat.defenseWindow, not rookhaven)
                combat.defenseWindow.value:setText(string.format("%d - %d", minTotalReduction, maxTotalReduction))
                combat.defenseWindow.value:setColor("#C0C0C0")
                combat.defenseWindow:setTooltip(string.format(
                    "Theoretical total reduction interval from server formulas.\nArmor range: %d to %d\nDefense range: %d to %d\nCombined range: %d to %d\nThe defense component requires a defense check.",
                    minArmorReduction, maxArmorReduction, minDefenseReduction, maxDefenseReduction, minTotalReduction, maxTotalReduction))
            end
        end

    if data.weaponElementDamage > 0 then
        setCombatRowVisible(combat.converted, true)
        combat.converted.none:setVisible(false)
        combat.converted.value:setVisible(true)
        combat.converted.icon:setVisible(true)
        setElementIcon(combat.converted.icon, data.weaponElementType)
        combat.converted.value:setText(tostring(data.weaponElementDamage))
        combat.converted:setTooltip("Elemental attack supplied by your current weapon or ammunition; not a percentage. The matching element icon shows its damage type.")
    else
        setCombatRowVisible(combat.converted, not rookhaven)
        combat.converted.none:setVisible(true)
        combat.converted.value:setVisible(false)
        combat.converted.icon:setVisible(false)
    end

    local function getAdditionalSkillValue(skillId)
        local skillIndex = ({
            [Skill.CriticalChance] = 1,
            [Skill.CriticalDamage] = 2,
            [Skill.LifeLeechAmount] = 3,
            [Skill.ManaLeechAmount] = 4,
        })[skillId]

        if not skillIndex or not additionalSkillsArray or not additionalSkillsArray[skillIndex] then
            return 0
        end

        return tonumber(additionalSkillsArray[skillIndex][2]) or 0
    end

    local critChance = getAdditionalSkillValue(Skill.CriticalChance)
    local critTotal = getAdditionalSkillValue(Skill.CriticalDamage)
    if critTotal <= 0 then
        critTotal = 100
    end
    local critExtra = math.max(0, critTotal - 100)
    setCombatRowVisible(combat.defence, not rookhaven or critChance > 0)
    setCombatRowVisible(combat.mitigation, not rookhaven or critChance > 0)
    setCombatRowVisible(combat.passiveReduction, not rookhaven or (data.passiveStats and (data.passiveStats.physicalReductionPercent or 0) > 0) or false)

    if combat.defence then
        combat.defence.value:setText(string.format("%.2f%%", critChance))
        combat.defence:setTooltip(
            "Approximate ordinary PvE critical probability from the server's actual roll formulas.\nGear uses a shaped normal roll; its displayed gear threshold is not a uniform percentage. Passive critical chance is a separate uniform roll after a non-critical gear roll. Class spells retain their own rules.")
    end

    if combat.armor then
        combat.armor.value:setText(string.format("+%.2f%%", critExtra))
        combat.armor:setTooltip(
            "Extra damage on an ordinary PvE critical, including active Critical Force ranks. Spell and condition critical rules remain separate.")
    end

    if combat.mitigation then
        combat.mitigation.value:setText(string.format("%.2f%%", critTotal))
        combat.mitigation:setTooltip(
            "Total critical hit multiplier.\nFormula: 100% base + critical extra damage.")
    end
    if combat.passiveReduction then
        local passive = data.passiveStats or {}
        combat.passiveReduction.value:setText(string.format("%.2f%%", passive.physicalReductionPercent or 0))
        combat.passiveReduction:setTooltip("Current direct physical monster damage reduction from active talents, applied after armor and defense. Includes low-HP and prepared protection; excludes conditions and PvP. See Passive Talents for individual effects.")
    end

    if combat.reductionNone then
        combat.reductionNone:destroyChildren()
        if combat.reduction then
            combat.reduction:setVisible(false)
        end

        local function decodeReductionPercent(encoded)
            if encoded < 32768 then
                return encoded / 100
            else
                return -(65535 - encoded) / 100
            end
        end

        -- Show only actual equipped resistance/vulnerability, including physical.
        local elementEntries = {}
        if combatsArray then
            for _, entry in ipairs(combatsArray) do
                if entry[1] ~= nil and decodeReductionPercent(entry[2] or 0) ~= 0 then
                    table.insert(elementEntries, entry)
                end
            end
        end

        if #elementEntries > 0 then
            if combat.reduction then
                combat.reduction:setVisible(true)
            end
            combat.reductionNone:setVisible(true)

            for _, entry in ipairs(elementEntries) do
                local elementId = entry[1]
                local encodedPercent = entry[2]
                local pct = decodeReductionPercent(encodedPercent)
                -- The server has already capped rarity resistance and combined
                -- it with native equipment absorption. Do not cap that total.
                local displayPct = pct

                local elementInfo = Cyclopedia.clientCombat and Cyclopedia.clientCombat[elementId]
                local elementName = elementInfo and elementInfo.id or ("Element " .. elementId)
                local elementPath = elementInfo and elementInfo.path or nil

                local row = g_ui.createWidget("CharacterSkillBase", combat.reductionNone)

                if elementPath then
                    local icon = g_ui.createWidget("UIWidget", row)
                    icon:addAnchor(AnchorLeft, "parent", AnchorLeft)
                    icon:addAnchor(AnchorVerticalCenter, "parent", AnchorVerticalCenter)
                    icon:setImageSource(elementPath)
                    icon:setImageSize({width = 9, height = 9})
                    icon:setSize({width = 9, height = 9})
                end

                local nameLabel = g_ui.createWidget("SkillNameLabel", row)
                nameLabel:setMarginLeft(elementPath and 12 or 0)
                nameLabel:setText(elementName .. ":")

                local valueLabel = g_ui.createWidget("SkillValueLabel", row)
                local sign = displayPct > 0 and "+" or ""
                valueLabel:setText(sign .. Cyclopedia.CharacterPresentation.formatValue(displayPct, "%"))
                row:setTooltip("Reduces " .. elementName:lower() .. " damage through your equipped items. Negative values increase damage taken.\nEquipment effects stack; per-hit rounding may change the exact reduction. Armor and talent protection are shown separately.")

                if displayPct == 50 then
                    valueLabel:setColor("#ffd700") -- yellow for cap
                elseif displayPct > 0 then
                    valueLabel:setColor("#44AD25")
                elseif displayPct < 0 then
                    valueLabel:setColor("#CC2929")
                else
                    valueLabel:setColor("#C0C0C0")
                end
            end
        else
            combat.reductionNone:setVisible(false)
        end
    end

    -- concoctions
    combat.concoctionPanel:destroyChildren()
    if concoctionsArray and next(concoctionsArray) ~= nil then
        for i = 1, #concoctionsArray do
            local widget = g_ui.createWidget("CharacterGridItem", combat.concoctionPanel)
            local itemId = concoctionsArray[i][1]
            widget:setId("concoction_" .. itemId)
            widget.item:setItemId(itemId)
            widget.item:setVirtual(true)
            local minutes = concoctionsArray[i][2] / 60
            local itemObj = widget.item:getItem()
            local itemName = "Unknown"
            if itemObj and itemObj.getMarketData then
                local marketData = itemObj:getMarketData()
                if marketData and marketData.name and marketData.name ~= "" then
                    itemName = marketData.name
                end
            end
            widget.item:setTooltip(string.format("%s: %.0f minutes", itemName, minutes))
            widget.amount:setVisible(false)
        end
    end

    for i = 1, #forgeSkillsArray do
        local skillId = forgeSkillsArray[i][1]
        local id = "special_" .. skillId
        if combat[id] then
            combat[id]:destroy()
        end
    end

    local firstSpecial = true

    for i = 1, #forgeSkillsArray do
        local skillId = forgeSkillsArray[i][1]
        local percent = forgeSkillsArray[i][2]

        if percent > 0 and not rookhaven then
            local widget = g_ui.createWidget("CharacterSkillBase", combat)
            widget:setId("special_" .. skillId)

            local specialName = {
                [13] = "Onslaught",
                [14] = "Ruse",
                [15] = "Momentum",
                [16] = "Transcendence"
            }

            if firstSpecial then
                widget:addAnchor(AnchorTop, "manaLeech", AnchorBottom)
                widget:addAnchor(AnchorLeft, "criticalHit", AnchorLeft)
                widget:addAnchor(AnchorRight, "parent", AnchorRight)
                widget:setMarginTop(5)
            else
                widget:addAnchor(AnchorTop, "prev", AnchorBottom)
                widget:addAnchor(AnchorLeft, "criticalHit", AnchorLeft)
                widget:addAnchor(AnchorRight, "parent", AnchorRight)
                widget:setMarginTop(0)
            end

            widget:setMarginLeft(0)

            local name = g_ui.createWidget("SkillNameLabel", widget)
            name:setText(specialName[skillId])
            name:setColor("#C0C0C0")

            local value = g_ui.createWidget("SkillValueLabel", widget)
            value:setText(string.format("%.2f%%", percent / 100))
            value:setColor("#C0C0C0")
            value:setMarginRight(2)
            value:setColor("#C0C0C0")
            firstSpecial = firstSpecial and false
        end
    end
    Cyclopedia.renderCharacterPresentation()
end

function Cyclopedia.loadCharacterGeneralStats(data, skills)
    local player = g_game.getLocalPlayer()
    if not player then
        return
    end

    local function format(value)
        local totalMinutes = value / 60
        local hours = math.floor(totalMinutes / 60)
        local minutes = math.floor(totalMinutes % 60)

        if hours < 10 then
            hours = "0" .. hours
        end

        if minutes < 10 then
            minutes = "0" .. minutes
        end

        return hours .. ":" .. minutes
    end

    local function formatSecondsClock(seconds)
        local safeSeconds = math.max(0, math.floor(tonumber(seconds) or 0))
        local minutes = math.floor(safeSeconds / 60)
        local remSeconds = safeSeconds % 60
        return string.format("%02d:%02d", minutes, remSeconds)
    end

    local function setSkillTooltip(id, tooltip)
        local skill = UI.CharacterStats:recursiveGetChildById(id)
        if not skill then
            return
        end

        if tooltip and tooltip ~= "" then
            skill:setTooltip(tooltip)
        else
            skill:removeTooltip()
        end
    end

    Cyclopedia.setCharacterSkillValue("level", comma_value(data.level))

    local text = tr("You have %s percent to go", 100 - data.levelPercent)
    Cyclopedia.setCharacterSkillPercent("level", data.levelPercent, text)

    local experience = player:getExperience()
    local nextLevelExperience = type(expForLevel) == "function" and expForLevel(data.level + 1) or nil
    local remainingExperience = nextLevelExperience and math.max(0, nextLevelExperience - experience) or nil
    Cyclopedia.setCharacterSkillValue("experience", comma_value(experience))
    if nextLevelExperience and remainingExperience then
        setSkillTooltip("experience", string.format("To next level: %s\nNext level at: %s total XP",
            comma_value(remainingExperience), comma_value(nextLevelExperience)))
    end

    local expGainRate = data.baseExpGain + data.XpBoostPercent
    local hasStoreExpBonus = data.XpBoostPercent > 0
    local hasStaminaBonus = data.staminaMinutes / 60 >= 3

    expGainRate = hasStaminaBonus and expGainRate * 1.5 or expGainRate

    local staminaBonusTime = string.format("%02d:%02d", math.floor(math.min(data.staminaMinutes, 180) / 60),
        math.min(data.staminaMinutes, 180) % 60)
    local storeExpBonusTime = format(data.XpBoostBonusRemainingTime)
    local expGainRateTooltip = string.format(
        "Your current XP gain rate amounts to %d%%.\nYour XP gain rate is calculated as follows:\n- Base XP gain rate: %d%%",
        expGainRate, data.baseExpGain)

    expGainRateTooltip = hasStoreExpBonus and expGainRateTooltip ..
                             string.format("\n- XP boost: %d%% (%s h remaining).", data.XpBoostPercent,
            storeExpBonusTime) or expGainRateTooltip
    expGainRateTooltip = hasStaminaBonus and expGainRateTooltip ..
                             string.format("\n- Stamina bonus: x1.5 (%s h remaining).", staminaBonusTime) or
                             expGainRateTooltip

    UI.CharacterStats.expGainRate:setTooltip(expGainRateTooltip)
    -- UI.CharacterStats.expGainRate:setTooltipAlign(AlignTopLeft)
    Cyclopedia.setCharacterSkillValue("expGainRate", comma_value(expGainRate) .. "%")

    local currentHealth = player.getHealth and player:getHealth() or data.maxHealth
    local maxHealth = data.maxHealth
    local healthPercent = maxHealth > 0 and math.floor((currentHealth * 100) / maxHealth) or 0
    Cyclopedia.setCharacterSkillValue("health", string.format("%s / %s", comma_value(currentHealth), comma_value(maxHealth)))
    setSkillTooltip("health", string.format("Current health: %s%%", healthPercent))

    local currentMana = player.getMana and player:getMana() or data.mana
    local maxMana = data.mana
    local manaPercent = maxMana > 0 and math.floor((currentMana * 100) / maxMana) or 0
    Cyclopedia.setCharacterSkillValue("mana", string.format("%s / %s", comma_value(currentMana), comma_value(maxMana)))
    setSkillTooltip("mana", string.format("Current mana: %s%%", manaPercent))

    Cyclopedia.setCharacterSkillValue("soul", data.soul)

    local freeCapacity = math.floor(player:getFreeCapacity())
    if player.getTotalCapacity then
        local totalCapacity = math.floor(player:getTotalCapacity())
        local usedCapacity = math.max(0, totalCapacity - freeCapacity)
        Cyclopedia.setCharacterSkillValue("capacity", string.format("%s / %s", comma_value(freeCapacity), comma_value(totalCapacity)))
        setSkillTooltip("capacity", string.format("Free: %s\nUsed: %s", comma_value(freeCapacity), comma_value(usedCapacity)))
    else
        Cyclopedia.setCharacterSkillValue("capacity", comma_value(freeCapacity))
    end

    if data.speed > 0 then
        UI.CharacterStats.speed.value:setColor("#44AD25")
    else
        UI.CharacterStats.speed.value:setColor("#C0C0C0")
    end

    local speedValue = math.floor(data.speed)
    Cyclopedia.setCharacterSkillValue("speed", comma_value(speedValue))
    if player.getBaseSpeed then
        local baseSpeed = math.floor(player:getBaseSpeed())
        local bonusSpeed = speedValue - baseSpeed
        local speedSign = bonusSpeed >= 0 and "+" or ""
        setSkillTooltip("speed", string.format("Base speed: %d\nBonus: %s%d", baseSpeed, speedSign, bonusSpeed))
    end

    Cyclopedia.setCharacterSkillValue("food", formatSecondsClock(data.regenerationCondition))
    setSkillTooltip("food", "Time left until your food regeneration ends")

    local function formatTime(time)
        local hours = math.floor(time / 60)
        local minutes = time % 60
        if minutes < 10 then
            minutes = "0" .. minutes
        end
        return hours, minutes
    end

    local staminaPercent = math.floor(100 * data.staminaMinutes / 2520)
    local staminaHours, staminaMinutes = formatTime(data.staminaMinutes)

    Cyclopedia.setCharacterSkillValue("stamina", staminaHours .. ":" .. staminaMinutes)
    local staminaTooltip = tr("You have %s hours and %s minutes left", staminaHours, staminaMinutes)

    if data.staminaMinutes > 2400 and g_game.getClientVersion() >= 1038 and player:isPremium() then
        local text = tr("You have %s hours and %s minutes left", staminaHours, staminaMinutes) .. "\n" ..
                         tr("Now you will gain 50%% more experience")

        Cyclopedia.setCharacterSkillPercent("stamina", staminaPercent, text, "green")
    elseif data.staminaMinutes > 2400 and g_game.getClientVersion() >= 1038 and not player:isPremium() then
        local text = tr("You have %s hours and %s minutes left", staminaHours, staminaMinutes) .. "\n" ..
                         tr(
                "You will not gain 50%% more experience because you aren't premium player, now you receive only 1x experience points")

        Cyclopedia.setCharacterSkillPercent("stamina", staminaPercent, text, "#89F013")
    elseif data.staminaMinutes <= 840 and data.staminaMinutes > 0 then
        local text = tr("You have %s hours and %s minutes left", staminaHours, staminaMinutes) .. "\n" ..
                         tr("You gain only 50%% experience and you don't may gain loot from monsters")

        Cyclopedia.setCharacterSkillPercent("stamina", staminaPercent, text, "red")
    elseif data.staminaMinutes == 0 then
        local text = tr("You have %s hours and %s minutes left", staminaHours, staminaMinutes) .. "\n" ..
                         tr("You don't may receive experience and loot from monsters")

        Cyclopedia.setCharacterSkillPercent("stamina", staminaPercent, text, "black")
    else
        Cyclopedia.setCharacterSkillPercent("stamina", staminaPercent, staminaTooltip, "#C0C0C0")
    end

    local trainerHours, trainerMinutes = formatTime(data.offlineTrainingTime)
    local trainerPercent = 100 * data.offlineTrainingTime / 720

    Cyclopedia.setCharacterSkillValue("trainer", trainerHours .. ":" .. trainerMinutes)
    Cyclopedia.setCharacterSkillPercent("trainer", trainerPercent, tr("You have %s percent", trainerPercent))
    Cyclopedia.setCharacterSkillValue("magiclevel", data.magicLevel)
    Cyclopedia.setCharacterSkillPercent("magiclevel", data.magicLevelPercent,
        tr("You have %s percent to go", 100 - data.magicLevelPercent))
    Cyclopedia.setCharacterSkillBase("magiclevel", data.magicLevel, data.baseMagicLevel)

    for i = Skill.Fist + 1, Skill.Fishing + 1 do
        local values = skills and skills[i] or nil
        local skillLevel = values and values[1] or 0
        local baseSkill = values and values[2] or 0
        local skillPercent = values and values[3] or 0
        Cyclopedia.onSkillChange(player, i - 1, skillLevel, skillPercent)
        Cyclopedia.onBaseCharacterSkillChange(player, i - 1, baseSkill)
    end

    -- Skill ETA tooltips (set after base changes so we can override)
    local skillNames = { "Fist", "Club", "Sword", "Axe", "Distance", "Shielding", "Fishing" }
    for i = 0, 6 do
        local values = skills and skills[i + 1] or nil
        if values then
            local skillLevel = values[1] or 0
            local baseSkill  = values[2] or 0
            local skillPct   = values[3] or 0
            local skillWidget = UI.CharacterStats:recursiveGetChildById("skillId" .. i)
            if skillWidget then
                local tip = string.format("%s: Level %d -> %d  (%d%% complete)",
                    skillNames[i + 1] or "Skill", skillLevel, skillLevel + 1, skillPct)
                if baseSkill > 0 and baseSkill ~= skillLevel then
                    tip = tip .. string.format("\nBase: %d (bonus: %+d)", baseSkill, skillLevel - baseSkill)
                end
                skillWidget:setTooltip(tip)
            end
        end
    end
    do
        local mlWidget = UI.CharacterStats:recursiveGetChildById("magiclevel")
        if mlWidget then
            local tip = string.format("Magic Level: %d -> %d  (%d%% complete)",
                data.magicLevel, data.magicLevel + 1, data.magicLevelPercent)
            if data.baseMagicLevel ~= data.magicLevel then
                tip = tip .. string.format("\nBase: %d (bonus: %+d)", data.baseMagicLevel, data.magicLevel - data.baseMagicLevel)
            end
            mlWidget:setTooltip(tip)
        end
    end

    local sessionXp = math.max(0, tonumber(_sessionXpGained) or 0)
    local sessionSecs = 0
    if _sessionStartTime and _sessionStartTime > 0 then
        sessionSecs = math.max(0, os.time() - _sessionStartTime)
    end

    -- Session XP/hour: read expSpeed from LocalPlayer (same source as Skills widget)
    local xpPerHourText
    if player.expSpeed ~= nil and player.expSpeed > 0 then
        xpPerHourText = comma_value(math.floor(player.expSpeed * 3600)) .. " /h"
    else
        xpPerHourText = "0 /h"
    end
    Cyclopedia.setCharacterSkillValue("xpPerHour", xpPerHourText)
    local xpHrWidget = UI.CharacterStats:recursiveGetChildById("xpPerHour")
    if xpHrWidget then
        xpHrWidget:setTooltip(string.format(
            "Session XP gained: %s\nSession duration: %d min",
            comma_value(sessionXp), math.floor(sessionSecs / 60)))
    end

    -- Refresh vocation display with current player data
    _cachedVocationName = nil  -- Clear cache to get fresh data
    local currentVocationName = getPlayerVocationName(player)
    if UI and UI.CharacterBase and UI.CharacterBase.InfoLabel then
        updateCharacterIdentityHeader()
    end
    Cyclopedia.renderCharacterPresentation()
end

function Cyclopedia.loadCharacterPlaytime(seconds)
    if not UI or not UI.CharacterStats then return end
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local text
    if hours >= 24 then
        local days = math.floor(hours / 24)
        local remHours = hours % 24
        text = string.format("%dd %dh %02dm", days, remHours, minutes)
    else
        text = string.format("%dh %02dm", hours, minutes)
    end
    Cyclopedia.setCharacterSkillValue("playtime", text)
    local widget = UI.CharacterStats:recursiveGetChildById("playtime")
    if widget then
        widget:setTooltip("Total time spent in Rookhaven")
    end
end

local _profileKills  = nil
local _profileDeaths = nil

function Cyclopedia.updateProfileStats(kills, deaths)
    _profileKills  = kills
    _profileDeaths = deaths
    -- Refresh the description list if it is currently visible
    if UI and UI.InfoBase and UI.InfoBase:isVisible() then
        Cyclopedia.createCharacterDescription()
    end
end

function Cyclopedia.setServerCharacterTitle(title)
    title = tostring(title or "")
    _serverCharacterTitle = title ~= "" and title or nil
    _cachedVocationName = nil

    local player = g_game.getLocalPlayer()
    if player and UI and UI.CharacterBase and UI.CharacterBase.InfoLabel then
        updateCharacterIdentityHeader()
    end

    if UI and UI.InfoBase and UI.InfoBase:isVisible() then
        Cyclopedia.createCharacterDescription()
    end
end

function Cyclopedia.setCharacterIdentity(identity)
    _serverAscension = identity.ascension
    _serverClassName = identity.className ~= "" and identity.className or nil
    updateCharacterIdentityHeader()
    if UI and UI.InfoBase and UI.InfoBase:isVisible() then
        Cyclopedia.createCharacterDescription()
    end
end

local function presentationText(value, limit)
    return type(value) == "string" and value:sub(1, limit or 1600) or ""
end

local function presentationValue(value)
    if type(value) == "string" then return value:sub(1, 120) end
    if type(value) == "number" and value == value and math.abs(value) < math.huge then return value end
end

local function formatPresentationValue(value, unit)
    value = presentationValue(value)
    if value == nil then return "" end
    local text = type(value) == "number" and string.format("%.3f", value):gsub("0+$", ""):gsub("%.$", "") or value
    unit = presentationText(unit, 32)
    if unit == "" then return text end
    return text .. (unit == "%" and "" or " ") .. unit
end

local function normalizePresentationEntries(entries, overview)
    local result, seen = {}, {}
    if type(entries) ~= "table" then return result end
    for _, entry in ipairs(entries) do
        if #result >= 96 then break end
        if type(entry) == "table" and type(entry.id) == "string" and entry.id:match("^[%w_-]+$")
            and #entry.id <= 96 and not seen[entry.id] and type(entry.label) == "string" then
            if not overview or entry.group == "offence" or entry.group == "defence" or entry.group == "recovery" then
                local copy = {
                    id = entry.id, group = entry.group, label = presentationText(entry.label, 120),
                    value = presentationValue(entry.value), unit = presentationText(entry.unit, 32),
                    rank = presentationValue(entry.rank), status = presentationText(entry.status, 120),
                    hint = presentationText(entry.hint, 240),
                    description = presentationText(entry.description), detail = presentationText(entry.detail), sources = {}
                }
                if type(entry.sources) == "table" then
                    for index, source in ipairs(entry.sources) do
                        if index > 24 then break end
                        if type(source) == "table" and type(source.label) == "string" then
                            copy.sources[#copy.sources + 1] = {
                                label = presentationText(source.label, 120), value = presentationValue(source.value),
                                unit = presentationText(source.unit, 32)
                            }
                        end
                    end
                end
                result[#result + 1], seen[entry.id] = copy, true
            end
        end
    end
    return result
end

local function buildCharacterPresentationModel(data)
    local stats = type(data.stats) == "table" and data.stats or {}
    local presentation = type(data.presentation) == "table" and data.presentation or nil
    if presentation and presentation.version == 1 and type(presentation.header) == "table" then
        local header = presentation.header
        local talents = type(presentation.talents) == "table" and presentation.talents or {}
        return {
            version = 1,
            header = { className = presentationText(header.className, 120), weaponName = presentationText(header.weaponName, 80),
                weaponActive = header.weaponActive == true, reason = presentationText(header.reason, 420),
                spent = presentationValue(header.spent), points = presentationValue(header.points) },
            overview = normalizePresentationEntries(presentation.overview, true),
            talents = { statBonuses = normalizePresentationEntries(talents.statBonuses),
                conditionalEffects = normalizePresentationEntries(talents.conditionalEffects),
                specialEffects = normalizePresentationEntries(talents.specialEffects) }
        }
    end
    -- Older servers retain the existing combat view and their actual catalog
    -- benefits. Never infer current sources or fill unknown amounts with zero.
    local applied = {}
    for index, talent in ipairs(type(data.talents) == "table" and data.talents or {}) do
        if index > 96 then break end
        if type(talent) == "table" then
            applied[#applied + 1] = { id = "applied_" .. index, label = presentationText(talent.name, 120),
                rank = presentationValue(talent.rank), hint = presentationText(talent.benefit, 240),
                detail = presentationText(talent.benefit) .. "\n\n" .. presentationText(talent.description), sources = {} }
        end
    end
    local weapon = presentationText(stats.weaponName, 80)
    local reason = ""
    if stats.active and not stats.weaponActive and weapon ~= "" then
        reason = "Equip your " .. weapon .. " to activate your talents."
    elseif not stats.active and stats.permanent then
        reason = "Talent effects are currently unavailable. Your chosen class and applied ranks are preserved."
    elseif not stats.active and not stats.permanent then
        reason = "Choose your permanent class at the third Ascension."
    end
    return { version = 0, header = { className = presentationText(stats.className, 120), weaponName = weapon,
        weaponActive = stats.weaponActive == true, reason = reason, spent = presentationValue(stats.spent),
        points = presentationValue(stats.points) }, overview = {}, appliedTalents = applied,
        talents = { statBonuses = {}, conditionalEffects = {}, specialEffects = {} } }
end

Cyclopedia.CharacterPresentation = { formatValue = formatPresentationValue, buildModel = buildCharacterPresentationModel }

function Cyclopedia.getPresentationModel()
    return characterPresentationModel
end

local function reconcilePresentationWidgets(parent, records, update)
    local kept = {}
    for index, record in ipairs(records) do
        local widget = parent:getChildById(record.id)
        if not widget then widget = g_ui.createWidget(record.style, parent); widget:setId(record.id) end
        update(widget, record)
        local current = parent:getChildByIndex(index)
        if not current or current:getId() ~= record.id then parent:moveChildToIndex(widget, index) end
        kept[record.id] = true
    end
    for _, widget in ipairs(parent:getChildren()) do if not kept[widget:getId()] then widget:destroy() end end
end

local function renderPresentationSources(panel, entry, view)
    local records = { { id = "Title", style = "CharacterStatsSection", text = entry and entry.label or "Talent effects" } }
    if entry then
        if view == "talents" and entry.rank ~= nil then
            records[#records + 1] = { id = "Rank", style = "CharacterStatsSourceRow", label = "Applied rank", value = entry.rank }
        end
        if view == "overview" and entry.hint ~= "" then
            records[#records + 1] = { id = "Effect", style = "CharacterStatsSourceNote", text = entry.hint }
        end
        for index, source in ipairs(entry.sources) do
            records[#records + 1] = { id = "source_" .. index, style = "CharacterStatsSourceRow",
                label = source.label, value = source.value, unit = source.unit }
        end
        local description = entry.detail ~= "" and entry.detail or entry.description
        if not description or description == "" then description = entry.hint end
        if entry.status and entry.status ~= "" then description = entry.status .. (description ~= "" and (". " .. description) or "") end
        if description and description ~= "" and (view ~= "overview" or description ~= entry.hint) then
            records[#records + 1] = { id = "Description", style = "CharacterStatsSourceNote", text = description }
        end
    else
        records[#records + 1] = { id = "Description", style = "CharacterStatsSourceNote", text = "No talents applied. Choose talents in your passive tree." }
    end
    reconcilePresentationWidgets(panel.Content, records, function(widget, record)
        if record.label then
            widget.Name:setText(record.label); widget.Value:setText(formatPresentationValue(record.value, record.unit))
            widget:setTooltip(record.label .. ": " .. formatPresentationValue(record.value, record.unit))
        else
            widget:setText(record.text)
        end
    end)
end

local function renderPresentationList(panel, view, groups)
    local records, entries = {}, {}
    for _, group in ipairs(groups) do
        if #group.entries > 0 then
            records[#records + 1] = { id = "section_" .. group.id, style = "CharacterStatsSection", text = group.label }
            for _, entry in ipairs(group.entries) do
                entries[#entries + 1] = entry
                records[#records + 1] = { id = (view == "overview" and "overview_" or "talent_") .. entry.id,
                    style = "CharacterStatsSummaryRow", entry = entry }
            end
        end
    end
    local selected
    for _, entry in ipairs(entries) do if entry.id == characterSourceSelection[view] then selected = entry; break end end
    if not selected then
        selected = entries[1]
        characterSourceSelection[view] = selected and selected.id or nil
    end
    reconcilePresentationWidgets(panel.List, records, function(widget, record)
        if not record.entry then widget:setText(record.text); return end
        local entry = record.entry
        widget.Name:setText(entry.label)
        local value = formatPresentationValue(entry.value, entry.unit)
        if value == "" and entry.rank ~= nil then value = "Rank " .. formatPresentationValue(entry.rank) end
        widget.Value:setText(value)
        local hint = entry.hint
        if entry.status and entry.status ~= "" then hint = entry.status .. (hint ~= "" and (" | " .. hint) or "") end
        widget.Hint:setText(hint); widget.Hint:setVisible(hint ~= ""); widget:setHeight(hint ~= "" and 38 or 24)
        widget:setOn(selected == entry)
        widget:setTooltip(entry.detail ~= "" and entry.detail or entry.description)
        widget.onClick = function()
            characterSourceSelection[view] = entry.id
            for _, child in ipairs(panel.List:getChildren()) do if child.Hint then child:setOn(child:getId() == widget:getId()) end end
            panel.List:ensureChildVisible(widget)
            renderPresentationSources(panel.SourceDetails, entry, view)
            panel.SourceDetails.Scrollbar:setValue(0)
        end
    end)
    renderPresentationSources(panel.SourceDetails, selected, view)
end

local function presentationHeader(model, talents)
    local header = model.header
    local class = header.className ~= "" and header.className or "Class not chosen"
    local weapon = header.weaponName ~= "" and (header.weaponName .. (header.weaponActive and " equipped" or " required")) or ""
    local text = class .. (weapon ~= "" and (" | " .. weapon) or "")
    if talents and header.spent ~= nil and header.points ~= nil then text = text .. string.format("\n%s / %s talent points applied", formatPresentationValue(header.spent), formatPresentationValue(header.points)) end
    if header.reason ~= "" then text = text .. "\n" .. header.reason end
    return text
end

local function combatSourceTooltip(entry)
    local lines = { entry.label .. ": " .. formatPresentationValue(entry.value, entry.unit) }
    local effect = entry.hint ~= "" and entry.hint or entry.description
    if effect ~= "" then lines[#lines + 1] = effect end
    lines[#lines + 1] = "Click for bonus sources and conditions."
    return table.concat(lines, "\n")
end

function Cyclopedia.getCombatStatRow(id)
    return combatRows[id]
end

function Cyclopedia.getCombatSourceWindow()
    return UI and UI.CombatSources
end

local function updateCombatLayout()
    if combatLayoutEvent then removeEvent(combatLayoutEvent) end
    local owner = UI
    combatLayoutEvent = scheduleEvent(function()
        combatLayoutEvent = nil
        if not UI or UI ~= owner then return end
        local content = UI.CombatStats.Viewport.Content
        local top, bottom = content:getY(), 0
        for _, child in ipairs(content:getChildren()) do
            if child:isVisible() and child:getId() ~= "separator" then
                bottom = math.max(bottom, child:getY() - top + child:getHeight() + child:getMarginBottom())
            end
        end
        content:setHeight(math.max(bottom + 8, UI.CombatStats.Viewport:getHeight()))
    end, 30)
end

local function bindCombatSource(row, entry, secondary)
    if not row then return end
    combatRows[entry.id .. (secondary and "_extra" or "")] = row
    local tip = combatSourceTooltip(entry)
    if row:getTooltip() ~= row._combatSourceTooltip then row._combatFallbackTooltip = row:getTooltip() end
    row._combatSourceTooltip = tip
    row:setTooltip(tip)
    row.onClick = function()
        characterSourceSelection.overview = entry.id
        combatSourceOpen = true
        if entry.id ~= "maxHealth" then UI.CombatStats.Viewport:ensureChildVisible(row) end
        renderPresentationSources(UI.CombatSources, entry, "overview")
        UI.CombatSources:setVisible(true)
        UI.CombatSources:raise()
        UI.CombatSources:focus()
    end
    local value = row.Value or row.value
    local details = row.Details
    if not details then details = g_ui.createWidget("CharacterStatsInfoButton", row) end
    details.onClick = row.onClick
    details:setTooltip(tip)
    if value then
        value:removeAnchor(AnchorLeft)
        value:addAnchor(AnchorRight, "Details", AnchorLeft)
        value:setMarginRight(4)
        value:setTextAutoResize(true)
    end
end

local compactCombatRows = {
    { id = "ordinaryDamage", label = "Normal Attack Bonus:", rank = "rankPowerPercent" },
    { id = "spellDamage", label = "Class Spell Bonus:", rank = "rankPowerPercent" },
    { id = "spellPrimary", label = "Spell Primary Bonus:", rank = "rankSpellPrimaryExtraPercent" },
    { id = "spellSecondary", label = "Spell Secondary Bonus:", rank = "rankSpellSecondaryExtraPercent" },
    { id = "manaDiscount", label = "Spell Mana Saving:", rank = "rankManaDiscountPercent" },
    { id = "manaRegen", label = "Mana Regeneration:", rank = "rankManaPerSecond", recovery = true },
    { id = "healthRegen", label = "Health Regeneration:", recovery = true },
    { id = "healingRemaining", label = "Healing Remaining:", recovery = true },
    { id = "damageRecovery", label = "Damage Recovery:", rank = "rankDamageRecoveryPercent", recovery = true },
    { id = "killRecovery", label = "Kill Recovery:", rank = "rankKillRecoveryPercent", recovery = true },
    { id = "incomingHealing", label = "Received Healing Bonus:", rank = "rankIncomingHealingPercent", recovery = true },
    { id = "outgoingHealing", label = "Direct Healing Bonus:", rank = "rankOutgoingHealingPercent", recovery = true },
}

local function renderCompactCombat(model)
    local content = UI.CombatStats.Viewport.Content
    for _, row in pairs(combatRows) do
        if not row:isDestroyed() then
            row.onClick = nil
            if row:getTooltip() == row._combatSourceTooltip then row:setTooltip(row._combatFallbackTooltip or "") end
            if row.Details then row.Details.onClick = nil; row.Details:setVisible(false) end
        end
    end
    combatRows = {}
    local available = model and model.version == 1 and g_game.getClientVersion() < 1410
    local byId = {}
    if available then for _, entry in ipairs(model.overview) do byId[entry.id] = entry end end
    local stats = Cyclopedia.characterPassiveStats or {}
    local core = { normalMaxHit = "estDps", attackInterval = "atkSpeed", criticalChance = "defence",
        criticalMultiplier = "mitigation", physicalReduction = "passiveReduction" }
    for id, widgetId in pairs(core) do
        local entry, row = byId[id], content[widgetId]
        if available and (id == "criticalChance" or id == "criticalMultiplier" or id == "physicalReduction" or id == "attackInterval") then
            setCombatRowVisible(row, entry ~= nil and (id ~= "attackInterval" or tonumber(entry.value) ~= 2000))
        end
        if entry and row then
            bindCombatSource(row, entry)
            row.Details:setVisible(true)
            if id == "normalMaxHit" then row.value:setText(formatPresentationValue(entry.value))
            elseif id == "attackInterval" then row.value:setText(string.format("%.1fs", (tonumber(entry.value) or 0) / 1000))
            else row.value:setText(string.format("%.2f%%", tonumber(entry.value) or 0)) end
        end
    end
    if byId.criticalMultiplier and g_game.getClientVersion() ~= 860 then
        bindCombatSource(content.armor, byId.criticalMultiplier, true); content.armor.Details:setVisible(true)
    end
    if byId.maxHealth then
        local health = UI.CharacterStats:recursiveGetChildById("health")
        bindCombatSource(health, byId.maxHealth)
        if health and health.Details then health.Details:setVisible(true) end
    end
    local function relevant(entry, spec)
        return entry and (tonumber(entry.value) ~= nil and tonumber(entry.value) ~= 0
            or spec.rank and (tonumber(stats[spec.rank]) or 0) > 0
            or spec.id == "manaRegen" and (tonumber(stats.effectManaPerSecond) or 0) > 0
            or spec.id == "healthRegen" and (tonumber(stats.effectHealthPerSecond) or 0) > 0)
    end
    local offence, defence, recoveryAdded = {}, {}, false
    for _, spec in ipairs(compactCombatRows) do
        local entry = byId[spec.id]
        if relevant(entry, spec) then
            if spec.recovery and not recoveryAdded then
                offence[#offence + 1] = { id = "section_recovery", style = "CharacterStatsCompactSection", label = "Recovery:" }
                recoveryAdded = true
            end
            offence[#offence + 1] = { id = "overview_" .. spec.id, style = "CharacterStatsCompactRow", label = spec.label, entry = entry }
        end
    end
    for _, spec in ipairs({ { id = "ward", label = "Active Ward:" }, { id = "armor", label = "Armor:" }, { id = "defense", label = "Defense:" } }) do
        local entry = byId[spec.id]
        if entry and (spec.id ~= "ward" or (tonumber(entry.value) or 0) > 0) then
            defence[#defence + 1] = { id = "overview_" .. spec.id, style = "CharacterStatsCompactRow", label = spec.label, entry = entry }
        end
    end
    local function renderColumn(panel, records)
        reconcilePresentationWidgets(panel, records, function(widget, record)
            widget.Name:setText(record.label)
            if record.entry then
                widget.Value:setText(formatPresentationValue(record.entry.value, record.entry.unit))
                bindCombatSource(widget, record.entry)
                widget.Details:setVisible(true)
                widget.Value:setColor((tonumber(record.entry.value) == 0 and not model.header.weaponActive) and "#929292" or "#C0C0C0")
            end
        end)
        local height = 0
        for _, widget in ipairs(panel:getChildren()) do height = height + widget:getHeight() + widget:getMarginTop() + widget:getMarginBottom() end
        panel:setHeight(height)
    end
    renderColumn(content.OffenceExtras, offence)
    renderColumn(content.DefenceExtras, defence)
    local warning = available and stats.permanent and model.header.spent and model.header.spent > 0 and not model.header.weaponActive
    content.WeaponStatus:setVisible(warning or false)
    if warning then content.WeaponStatus:setText(model.header.reason) end
    UI.CombatSources.Close.onClick = function() combatSourceOpen = false; UI.CombatSources:hide() end
    UI.CombatSources.onEscape = UI.CombatSources.Close.onClick
    UI.CombatSources.onClose = UI.CombatSources.Close.onClick
    local selected = byId[characterSourceSelection.overview]
    local showingStats = UI.selectedOption == "CombatStats" or UI.selectedOption == "CharacterStats"
    if combatSourceOpen and selected and showingStats then
        renderPresentationSources(UI.CombatSources, selected, "overview")
        UI.CombatSources:show()
    else
        UI.CombatSources:hide()
        if not selected then combatSourceOpen = false end
    end
    updateCombatLayout()
end

function Cyclopedia.renderCharacterPresentation()
    if not UI then return end
    local model = Cyclopedia.getPresentationModel()
    renderCompactCombat(model)
    if not model then return end
    UI.PassiveStats.Header:setText(presentationHeader(model, true))
    local groups
    if model.version == 1 then
        groups = { { id = "statBonuses", label = "Stat bonuses", entries = model.talents.statBonuses },
            { id = "conditionalEffects", label = "Conditional effects", entries = model.talents.conditionalEffects },
            { id = "specialEffects", label = "Special effects", entries = model.talents.specialEffects } }
    else groups = { { id = "applied", label = "Applied talents", entries = model.appliedTalents } } end
    renderPresentationList(UI.PassiveStats, "talents", groups)
end

function Cyclopedia.loadCharacterPassives(data)
    if type(data) ~= "table" then return end
    Cyclopedia.characterPassiveStats = type(data.stats) == "table" and data.stats or {}
    characterPresentationModel = buildCharacterPresentationModel(data)
    Cyclopedia.renderCharacterPresentation()
end

function Cyclopedia.updateFoodRegen(regenSecs)
    if not UI or not UI.CharacterStats then return end
    local text
    if regenSecs < 0 then
        text = "Equipment"  -- infinite from worn item
    else
        local minutes = math.floor(regenSecs / 60)
        local secs = regenSecs % 60
        text = string.format("%02d:%02d", minutes, secs)
    end
    Cyclopedia.setCharacterSkillValue("food", text)
end

function Cyclopedia.setCharacterSkillValue(id, value, color)
    local skill = UI.CharacterStats:recursiveGetChildById(id)
    if not skill then
        return
    end

    local widget = skill:getChildById("value")
    if not widget then
        return
    end

    widget:setText(value)
    widget:setColor(color)
end

function Cyclopedia.setCharacterSkillPercent(id, percent, tooltip, color)
    local skill = UI.CharacterStats:recursiveGetChildById(id)
    if not skill then
        return
    end

    local widget = skill:getChildById("percent")
    if widget then
        widget:setPercent(math.floor(percent))

        if tooltip then
            widget:setTooltip(tooltip)
        end

        if color then
            widget:setBackgroundColor(color)
        end
    end
end

function Cyclopedia.setCharacterSkillBase(id, value, baseValue)
    if baseValue <= 0 or value < 0 then
        return
    end

    local skill = UI.CharacterStats:recursiveGetChildById(id)
    if not skill then
        return
    end

    local widget = skill:getChildById("value")
    if not widget then
        return
    end

    if baseValue < value then
        widget:setColor("#44AD25")
        skill:setTooltip(baseValue .. " +" .. value - baseValue)
    elseif value < baseValue then
        widget:setColor("#b22222")
        skill:setTooltip(baseValue .. " " .. value - baseValue)
    else
        widget:setColor("#bbbbbb")
        skill:removeTooltip()
    end
end

function Cyclopedia.onBaseCharacterSkillChange(localPlayer, id, baseLevel)
    Cyclopedia.setCharacterSkillBase("skillId" .. id, localPlayer:getSkillLevel(id), baseLevel)
end

function Cyclopedia.onSkillChange(localPlayer, id, level, percent)
    Cyclopedia.setCharacterSkillValue("skillId" .. id, level)
    Cyclopedia.setCharacterSkillPercent("skillId" .. id, percent, tr("You have %s percent to go", 100 - percent))
    Cyclopedia.onBaseCharacterSkillChange(localPlayer, id, localPlayer:getSkillBaseLevel(id))
end

function Cyclopedia.selectCharacterPage()
    local selectedOption = UI.selectedOption
    UI[selectedOption]:setVisible(false)
    UI.InfoBase:setVisible(true)
    Cyclopedia.closeCharacterButtons()

    local oldOpen = UI.openedCategory
    if oldOpen ~= nil then
        close(oldOpen)
    end

    UI.selectedOption = "InfoBase"
    Cyclopedia.renderCharacterPresentation()
end

function Cyclopedia.closeCharacterButtons()
    local size = UI.OptionsBase:getChildCount()
    for i = 1, size do
        local widget = UI.OptionsBase:getChildByIndex(i)
        if widget then
            if widget.subCategories ~= nil then
                for subId, _ in ipairs(widget.subCategories) do
                    local subWidget = widget:getChildById(subId)

                    if subWidget then
                        subWidget.Button:setChecked(false)
                        subWidget.Button.Arrow:setVisible(false)
                        subWidget.Button.Icon:setChecked(false)
                    end
                end
            else
                widget.Button:setChecked(false)
                widget.Button.Arrow:setVisible(false)
                widget.Button.Icon:setChecked(false)
            end
        end
    end
end

function Cyclopedia.configureCharacterCategories()
    UI.OptionsBase:destroyChildren()

    local buttons = {
        {
            text = "General Stats",
            icon = "/game_cyclopedia/images/character_icons/icon_generalstats",
            subCategories = function()
                local categories = {
                    {
                        text = "Character Stats",
                        icon = "/game_cyclopedia/images/character_icons/icon-character-generalstats-overview",
                        open = "CharacterStats"
                    }
                }
                
                if g_game.getClientVersion() < 1410 then
                    table.insert(categories, {
                        text = "Combat Stats",
                        icon = "/game_cyclopedia/images/character_icons/icon-character-generalstats-combatstats",
                        open = "CombatStats"
                    })
                else
                    table.insert(categories, {
                        text = "Offence Stats",
                        icon = "/game_cyclopedia/images/character_icons/icon-character-generalstats-combatstats",
                        open = "OffenceStats"
                    })
                    table.insert(categories, {
                        text = "Deffence Stats",
                        icon = "/game_cyclopedia/images/character_icons/icon-character-generalstats-defence",
                        open = "DeffenceStats"
                    })
                    table.insert(categories, {
                        text = "Misc. Stats",
                        icon = "/game_cyclopedia/images/character_icons/icon-character-generalstats-misc",
                        open = "MiscStats"
                    })
                end
                
                table.insert(categories, {
                    text = "Passive Talents",
                    icon = "/game_cyclopedia/images/character_icons/icon-character-generalstats-overview",
                    open = "PassiveStats"
                })
                return categories
            end
        },
        {
            text = "Battle Results",
            icon = "/game_cyclopedia/images/character_icons/icon_battleresults",
            subCategories = {
                {
                    text = "Recent Deaths",
                    icon = "/game_cyclopedia/images/character_icons/icon-character-battleresults-recentdeaths",
                    open = "RecentDeaths"
                },
                {
                    text = "Recent PvP Kills",
                    icon = "/game_cyclopedia/images/character_icons/icon-character-battleresults-recentpvpkills",
                    open = "RecentKills"
                }
            }
        },
        {
            text = "Character Titles",
            icon = "/game_cyclopedia/images/character_icons/icon-character-titles",
            open = "CharacterTitles"
        }
    }

    for id, button in ipairs(buttons) do
        local widget = g_ui.createWidget("CharacterCategoryItem", UI.OptionsBase)
        widget:setId(id)
        widget.Button.Icon:setIcon(button.icon)
        widget.Button.Title:setText(button.text)

        if button.disabled then
            widget.Button.Title:setColor("#666666")
            widget.Button.Icon:setOpacity(0.4)
            if button.tooltip then
                widget.Button:setTooltip(button.tooltip)
            end
        end

        if button.open ~= nil then
            widget.open = button.open
        end

        if button.subCategories ~= nil then
            local subCats = button.subCategories
            if type(subCats) == "function" then
                subCats = subCats()
            end
            
            widget.subCategories = subCats
            widget.subCategoriesSize = #subCats
            widget.Button.Arrow:setVisible(true)

            for subId, subButton in ipairs(subCats) do
                local subWidget = g_ui.createWidget("CharacterCategoryItem", widget)
                subWidget:setId(subId)
                subWidget.Button.Icon:setIcon(subButton.icon)
                subWidget.Button.Title:setText(subButton.text)
                subWidget:setVisible(false)
                subWidget.open = subButton.open

                function subWidget.Button:onClick(test)
                    local selectedOption = UI.selectedOption
                    Cyclopedia.closeCharacterButtons()
                    subWidget.Button:setChecked(true)
                    subWidget.Button.Arrow:setVisible(true)
                    subWidget.Button.Arrow:setImageSource("/game_cyclopedia/images/icon-arrow7x7-right")
                    subWidget.Button.Icon:setChecked(true)
                    UI[selectedOption]:setVisible(false)
                    UI[subWidget.open]:setVisible(true)

                    if subWidget.open == "CharacterStats" then
                        g_game.requestCharacterInfo(0, CyclopediaCharacterInfoTypes.GeneralStats)
                        g_game.requestCharacterInfo(0, CyclopediaCharacterInfoTypes.Badges)
                    elseif subWidget.open == "CombatStats" then
                        g_game.requestCharacterInfo(0, CyclopediaCharacterInfoTypes.CombatStats)
                    elseif subWidget.open == "PassiveStats" then
                        Cyclopedia.sendCyclopediaRequest("character.combatStats", "")
                    elseif subWidget.open == "OffenceStats" then
                        g_game.requestCharacterInfo(0, CyclopediaCharacterInfoTypes.Offencestats)
                    elseif subWidget.open == "DeffenceStats" then
                        g_game.requestCharacterInfo(0, CyclopediaCharacterInfoTypes.Defencestats)
                    elseif subWidget.open == "MiscStats" then
                        g_game.requestCharacterInfo(0, CyclopediaCharacterInfoTypes.Miscstats)
                    elseif subWidget.open == "RecentDeaths" then
                        g_game.requestCharacterInfo(0, CyclopediaCharacterInfoTypes.RecentDeaths, 23, 1)
                    elseif subWidget.open == "RecentKills" then
                        g_game.requestCharacterInfo(0, CyclopediaCharacterInfoTypes.RecentPVPKills, 23, 1)
                    end

                    UI.selectedOption = subWidget.open
                    Cyclopedia.renderCharacterPresentation()
                end

                if subId == 1 then
                    subWidget:addAnchor(AnchorTop, "parent", AnchorTop)
                    subWidget:addAnchor(AnchorHorizontalCenter, "parent", AnchorHorizontalCenter)
                    subWidget:setMarginTop(20)
                else
                    subWidget:addAnchor(AnchorTop, "prev", AnchorBottom)
                    subWidget:addAnchor(AnchorHorizontalCenter, "parent", AnchorHorizontalCenter)
                    subWidget:setMarginTop(-1)
                end
            end
        end

        if id == 1 then
            widget:addAnchor(AnchorTop, "parent", AnchorTop)
            widget:addAnchor(AnchorHorizontalCenter, "parent", AnchorHorizontalCenter)
            widget:setMarginTop(5)
        else
            widget:addAnchor(AnchorTop, "prev", AnchorBottom)
            widget:addAnchor(AnchorHorizontalCenter, "parent", AnchorHorizontalCenter)
            widget:setMarginTop(5)
        end

        function widget.Button.onClick(this)
            if button.disabled then
                return
            end
            if widget.open == "CharacterAchievements" then
                Cyclopedia.loadCharacterAchievements()
            elseif widget.open == "CharacterItems" then
                g_game.requestCharacterInfo(0, CyclopediaCharacterInfoTypes.ItemSummary)
                Cyclopedia.characterItemListFilter(UI.CharacterItems.listFilter.list)
            elseif widget.open == "CharacterAppearances" then
                g_game.requestCharacterInfo(0, CyclopediaCharacterInfoTypes.OutfitsAndMounts)
            elseif widget.open == "StoreSummary" then
                g_game.requestCharacterInfo(0, CyclopediaCharacterInfoTypes.StoreSummary)
            end

            local parent = this:getParent()
            if parent.subCategoriesSize ~= nil then
                if parent.closedSize == nil then
                    parent.closedSize = parent:getHeight() / (parent.subCategoriesSize + 1) + 15
                end

                if parent.openedSize == nil then
                    parent.openedSize = parent:getHeight() * (parent.subCategoriesSize + 1) - 6
                end

                open(parent)
            else
                local oldOpen = UI.openedCategory
                local selectedOption = UI.selectedOption

                Cyclopedia.closeCharacterButtons()
                this.Arrow:setImageSource("/game_cyclopedia/images/icon-arrow7x7-right")
                this.Arrow:setVisible(true)

                if oldOpen ~= nil and oldOpen ~= parent then
                    close(oldOpen)
                end

                this:setChecked(true)
                this.Icon:setChecked(true)
                UI[selectedOption]:setVisible(false)
                UI[parent.open]:setVisible(true)
                UI.selectedOption = parent.open
                Cyclopedia.renderCharacterPresentation()
            end
        end
    end
end

function Cyclopedia.createCharacterDescription()
    UI.InfoBase.DetailsBase.List:destroyChildren()

    local player = g_game.getLocalPlayer()
    -- Clear cached vocation to get fresh data
    _cachedVocationName = nil
    local descriptions = {
        { Level = player:getLevel() },
        { Class = _serverClassName or "Not chosen" },
        { Ascension = _serverAscension or "—" },
        { }
    }

    -- Total gold (carried + bank, both locally available)
    local carried = player.getMoney and player:getMoney() or 0
    local bank    = player.getBankBalance and player:getBankBalance() or 0
    local totalGold = carried + bank
    table.insert(descriptions, #descriptions, { ["Total Gold"] = comma_value(totalGold) .. " gp" })

    -- Kills & Deaths from server (set asynchronously by updateProfileStats)
    if _profileKills ~= nil then
        table.insert(descriptions, #descriptions, { ["Monster Kills"] = comma_value(_profileKills) })
    end
    if _profileDeaths ~= nil then
        table.insert(descriptions, #descriptions, { ["Deaths"] = tostring(_profileDeaths) })
    end

    for _, description in ipairs(descriptions) do
        local widget = g_ui.createWidget("UIWidget", UI.InfoBase.DetailsBase.List)
        for key, value in pairs(description) do
            widget:setText(key .. ": " .. value)
            widget:setColor("#C0C0C0")
        end
        widget:setTextWrap(true)
    end
end

function Cyclopedia.characterButton(widget)
    if widget.state == 1 then
        widget.state = 2
        widget:setIcon("/game_cyclopedia/images/icon-equipmentdetails")
        UI.InfoBase.inventoryPanel:setVisible(false)
        UI.InfoBase.outfitPanel:setVisible(true)
    else
        widget.state = 1
        widget:setIcon("/game_cyclopedia/images/icon-playerdetails")
        UI.InfoBase.inventoryPanel:setVisible(true)
        UI.InfoBase.outfitPanel:setVisible(false)
    end
end

function Cyclopedia.loadCharacterBadges(showAccountInformation, playerOnline, playerPremium, loyaltyTitle, badgesVector)
    -- ListBadge has been removed from UI, skip badge rendering
    local listBadge = UI.CharacterStats:recursiveGetChildById('ListBadge')
    if listBadge then listBadge:destroyChildren() end

    local accountStatus = "Free"
    local accountStatusColor = "#ff0000"
    if tonumber(playerPremium) and tonumber(playerPremium) > 0 then
        accountStatus = "Premium"
        accountStatusColor = "#00ff00"
    end

    if not loyaltyTitle or loyaltyTitle == "" then
        loyaltyTitle = "None"
    end

    Cyclopedia.setCharacterSkillValue("accountStatus", accountStatus, accountStatusColor)

    if listBadge then
        for _, badge in ipairs(badgesVector) do
            local cell = g_ui.createWidget("CharacterBadge", listBadge)
            if cell then
                cell:setImageClip(getImageClip(badge[1]))
                cell:setTooltip(badge[2])
            end
        end
    end
end

function getImageClip(elementIndex)
    local elementSize = 64
    local elementsPerRow = 21
    local y = 0
    local x = (elementIndex - 1) * elementSize
    local imageClip = string.format("%d %d %d %d", x, y, elementSize, elementSize)
    return imageClip
end

function Cyclopedia.onParseCyclopediaStoreSummary(xpBoostTime, dailyRewardXpBoostTime, blessings, preySlotsUnlocked,
    preyWildcards, instantRewards, hasCharmExpansion, hirelingsObtained, hirelingSkills, houseItems)

    UI.StoreSummary.ListBase.List.XPBoosts.RemainingStoreXPBoostTimeValue:setText(string.format("%02d:%02d",
        math.floor(xpBoostTime / 3600), math.floor((xpBoostTime % 3600) / 60)))
    UI.StoreSummary.ListBase.List.XPBoosts.RemainingDailyRewardXPBoostTimeValue:setText(string.format("%02d:%02d",
        math.floor(dailyRewardXpBoostTime / 3600), math.floor((dailyRewardXpBoostTime % 3600) / 60)))

    local panel = UI.StoreSummary.ListBase.List.Blessings.PurchasedHouseItems
    for _, blessing in ipairs(blessings) do
        local row = g_ui.createWidget('BlessCreate', panel)
        row.text1:setText(blessing[1])
        row.text2:setText("x" .. blessing[2])

    end

    UI.StoreSummary.ListBase.List.preyPanel.PermanentPreySlotsValue:setText(preySlotsUnlocked)
    UI.StoreSummary.ListBase.List.preyPanel.PreyWildcardsValue:setText(preyWildcards)
    UI.StoreSummary.ListBase.List.dailyReward.InstantRewardAccessValue:setText(instantRewards)

    if hasCharmExpansion then
        UI.StoreSummary.ListBase.List.CharmPanel.CharmExpansionValue:setText("Yes")
    else
        UI.StoreSummary.ListBase.List.CharmPanel.CharmExpansionValue:setText("No")
    end

    UI.StoreSummary.ListBase.List.hirelings.PurchasedHirelingsValue:setText(hirelingsObtained)

    local rowHeight = 130
    local maxVisibleRows = 1.6
    local itemCount = #houseItems
    UI.StoreSummary.ListBase.List.houseItems:setHeight(math.min(itemCount, maxVisibleRows) * rowHeight)
    UI.StoreSummary.ListBase.List.houseItems.PurchasedHouseItems:destroyChildren() 
    for _, item in ipairs(houseItems) do
        local row = g_ui.createWidget('RowStore2', UI.StoreSummary.ListBase.List.houseItems.PurchasedHouseItems)
        local nameLabel = row:getChildById('lblName')
        nameLabel:setText(item[2])
        nameLabel:setTextAlign(AlignCenter)
        nameLabel:setMarginRight(10)
        row:getChildById('lblPrice'):setText(item[3])
        local itemWidget = g_ui.createWidget('Item', row:getChildById('image'))
        itemWidget:setId(item[1])
        itemWidget:setItemId(item[1])
        itemWidget:fill('parent')
    end
end

local  function getWeaponSkillName(skillType)
        local skillNames = {
            [0] = "Fist Fighting",
            [1] = "Club Fighting",
            [2] = "Sword Fighting",
            [3] = "Axe Fighting",
            [4] = "Distance Fighting",
            [5] = "Shielding",
            [6] = "Fishing",
            [7] = "Magic Level",
            [8] = "Critical Hits",
            [9] = "Life Leech",
            [10] = "Mana Leech"
        }
        
        return skillNames[skillType] or "Fighting Skill"
    end
    function Cyclopedia.onCyclopediaCharacterOffenceStats(data)
        UI.OffenceStats.rightPanel:destroyChildren()
        UI.OffenceStats.leftPanel:destroyChildren()

        local function getElementName(elementId)
            local entry = Cyclopedia.clientCombat and Cyclopedia.clientCombat[elementId]
            return entry and entry.id or "Physical"
        end

        local function addStat(parent, name, valueText, tooltip)
            local widget = g_ui.createWidget("CharacterSkillBase", parent)
            local nameLabel = g_ui.createWidget("SkillNameLabel", widget)
            local valueLabel = g_ui.createWidget("SkillValueLabel", widget)
            nameLabel:setText(name .. ":")
            valueLabel:setText(valueText)
            if tooltip and tooltip ~= "" then
                widget:setTooltip(tooltip)
            end
            return widget
        end

        local attackValue = tonumber(data.weaponAttack) or 0
        local weaponSkillType = tonumber(data.weaponSkillType) or 0
        local weaponSkillLevel = tonumber(data.weaponSkillLevel) or 0
        if weaponSkillLevel <= 0 and g_game and g_game.getLocalPlayer then
            local player = g_game.getLocalPlayer()
            if player and player.getSkillLevel then
                weaponSkillLevel = tonumber(player:getSkillLevel(weaponSkillType)) or weaponSkillLevel
            end
        end
        local attackSpeedMs = tonumber(data.attackSpeed) or 2000
        local attackSpeedSec = attackSpeedMs / 1000
        local critChance = tonumber(data.critChanceTotal) or 0
        local critTotal = tonumber(data.critDamageTotal) or 100
        local critExtra = math.max(0, critTotal - 100)
        local convertedDamage = tonumber(data.weaponElementDamage) or 0
        local convertedElement = tonumber(data.weaponElement) or 0

        addStat(
            UI.OffenceStats.leftPanel,
            "Attack Value",
            tostring(attackValue),
            "Base weapon attack value from the combat packet.\nUsed as an input in melee and distance damage formulas."
        )

        addStat(
            UI.OffenceStats.leftPanel,
            getWeaponSkillName(weaponSkillType),
            tostring(weaponSkillLevel),
            "Current offensive skill used by the equipped weapon.\nDirectly contributes to formula damage output."
        )

        addStat(
            UI.OffenceStats.leftPanel,
            "Attack Speed",
            string.format("%.2fs", attackSpeedSec),
            "Time between attacks based on vocation and weapon speed.\nLower values mean more hits over time."
        )

        if convertedDamage > 0 then
            addStat(
                UI.OffenceStats.leftPanel,
                "Element Conversion",
                string.format("%d%% %s", convertedDamage, getElementName(convertedElement)),
                "Weapon element conversion from equipped item attributes.\nAffects the element split of your outgoing hits."
            )
        end

        addStat(
            UI.OffenceStats.rightPanel,
            "Critical Chance",
            string.format("%.2f%%", critChance),
            "Chance that an attack becomes a critical hit."
        )

        addStat(
            UI.OffenceStats.rightPanel,
            "Critical Extra Damage",
            string.format("+%.2f%%", critExtra),
            "Extra damage added when a critical hit triggers."
        )

        addStat(
            UI.OffenceStats.rightPanel,
            "Critical Total Multiplier",
            string.format("%.2f%%", critTotal),
            "Total critical hit damage multiplier (100% base + extra critical damage)."
        )
    end
    function Cyclopedia.onCyclopediaCharacterDefenceStats(data)
        UI.DeffenceStats.rightPanel:destroyChildren()
        UI.DeffenceStats.leftPanel:destroyChildren()
    
        local stats = {
            {name = "Defense Value", value = data.defense or 0, icon = false, percent = false},
            {name = "From Equipment", value = data.defenseEquipment or 0, align = "center", icon = false},
            {name = "From Wheel", value = data.defenseWheel or 0, align = "center", icon = false},
            {name = getWeaponSkillName(data.defenseSkillType), value = data.shieldingSkill or 0, align = "center", icon = false},
            
            {name = "Armor Value", value = data.armor or 0, icon = false, percent = false},
            
            {name = "Mitigation", value = data.mitigation or 0, icon = false, percent = true},
            {name = "From Shielding", value = data.mitigationShield or 0, align = "center", percent = true, icon = false},
            {name = "From Combat Tactics", value = data.mitigationCombatTactics or 0, align = "center", percent = true, icon = false},
            {name = "From Base", value = data.mitigationBase or 0, align = "center", percent = true, icon = false},
            {name = "From Equipment", value = data.mitigationEquipment or 0, align = "center", percent = true, icon = false},
            {name = "From Wheel", value = data.mitigationWheel or 0, align = "center", percent = true, icon = false},
            
            {name = "Dodge", value = data.dodgeTotal or 0, icon = false, percent = true},
            {name = "From Base", value = data.dodgeBase or 0, align = "center", percent = true, icon = false},
            {name = "From Amplification", value = data.dodgeBonus or 0, align = "center", percent = true, icon = false},
            {name = "From Wheel", value = data.dodgeWheel or 0, align = "center", percent = true, icon = false},
            
            {name = "Magic Shield Capacity", value = data.magicShieldCapacity or 0, icon = false, percent = false},
            {name = "Flat", value = data.magicShieldCapacityFlat or 0, align = "center", icon = false},
            {name = "Percent", value = data.magicShieldCapacityPercent or 0, align = "center", percent = true, icon = false},
            
            {name = "Reflect Physical", value = data.reflectPhysical or 0, icon = false, percent = false},
            
            {name = "Resistances", parent = "right", value = "", icon = false}
        }
        
        local resistanceMap = {}
        if data.resistances then
            for _, resistance in ipairs(data.resistances) do
                resistanceMap[resistance.element] = resistance.value
            end
        end
        
        for elementId, elementInfo in pairs(Cyclopedia.clientCombat) do
            local value = resistanceMap[elementId] or 0
            local percentValue = value *100
            local color = "#FFFFFF"
            
            if percentValue > 0 then
                color = "#44AD25"
            elseif percentValue < 0 then
                color = "#FF9900"
            end
            
            local sign = percentValue >= 0 and "+" or ""
            table.insert(stats, {
                name = "     " .. elementInfo.id,
                parent = "right", 
                value = sign .. string.format("%.2f", tonumber(percentValue)) .. "%", 
                percent = false,
                element = elementId,
                icon = true,
                color = color
            })
        end
    
        local function renderStat(stat)
            local parent = stat.parent == "right" and UI.DeffenceStats.rightPanel or UI.DeffenceStats.leftPanel
    
            if stat.align == "center" then
                local widget = g_ui.createWidget("Label", parent)
                local valueText = stat.value
                if stat.percent then
                    local percentValue = math.floor(stat.value * 10000) / 100
                    local sign = percentValue > 0 and "+ " or ""
                    valueText = sign .. percentValue .. "%"
                end
                widget:setText("   " .. valueText .. " " .. stat.name)
                widget:setMarginLeft(80)
                return widget
            else
                local widget = g_ui.createWidget("CharacterSkillBase", parent)
                local nameLabel = g_ui.createWidget("SkillNameLabel", widget)
                nameLabel:setText(stat.name .. ":")
                local valueLabel = g_ui.createWidget("SkillValueLabel", widget)
                if stat.percent then
                    local percentValue = math.floor(stat.value * 10000) / 100
                    local sign = percentValue > 0 and "+ " or ""
                    valueLabel:setText(sign .. percentValue .. "%")
                else
                    valueLabel:setText(tostring(stat.value))
                end
                
                if stat.color then
                    valueLabel:setColor(stat.color)
                end
                
                if stat.icon then
                    valueLabel:setMarginRight(12)
                    local icon = g_ui.createWidget("SkillCharacterIcon", widget)
                    icon:setMarginTop(2)
                    icon:addAnchor(AnchorRight, "parent", AnchorRight)
                    local element = Cyclopedia.clientCombat[stat.element]
                    if element then
                        icon:setImageSource(element.path)
                        icon:setImageSize({
                            width = 9,
                            height = 9
                        })
                    end
                end
    
                return widget
            end
        end
    
        for _, stat in ipairs(stats) do
            if stat.align ~= "center" and stat.value == 0 and stat.value ~= "" then
                -- Skip
            else
                renderStat(stat)
            end
        end
    end

    function Cyclopedia.onCyclopediaCharacterMiscStats(data)
        UI.MiscStats.leftPanel:destroyChildren()
        UI.MiscStats.rightPanel:destroyChildren()
    
        local stats = {
            {name = "Momentum", value = data.momentumTotal or 0, icon = false, percent = true},
            {name = "From Equipment", value = data.momentumBase or 0, align = "center", percent = true, icon = false},
            {name = "From Amplification", value = data.momentumBonus or 0, align = "center", percent = true, icon = false},
            {name = "From Wheel", value = data.momentumWheel or 0, align = "center", percent = true, icon = false},
            
            {name = "Transcendence", value = data.dodgeTotal or 0, icon = false, percent = true},
            {name = "From Base", value = data.dodgeBase or 0, align = "center", percent = true, icon = false},
            {name = "From Amplification", value = data.dodgeBonus or 0, align = "center", percent = true, icon = false},
            {name = "From Event Bonus", value = data.dodgeWheel or 0, align = "center", percent = true, icon = false},
            
            {name = "Damage Reflection", value = data.damageReflectionTotal or 0, icon = false, percent = true},
            {name = "From Base", value = data.damageReflectionBase or 0, align = "center", percent = true, icon = false},
            {name = "From Bonus", value = data.damageReflectionBonus or 0, align = "center", percent = true, icon = false},
            
            {name = "Blessings", value = (data.haveBlesses or 0) .. "/" .. (data.totalBlesses or 0), icon = false, percent = false},

        }
        
        if data.concoctions and #data.concoctions > 0 then
            for _, concoction in ipairs(data.concoctions) do
                table.insert(stats, {
                    name = "     " .. concoction.name,
                    parent = "right", 
                    value = concoction.value, 
                    percent = true,
                    icon = false
                })
            end
        end
    
        local function renderStat(stat)
            local parent = stat.parent == "right" and UI.MiscStats.rightPanel or UI.MiscStats.leftPanel
    
            if stat.align == "center" then
                local widget = g_ui.createWidget("Label", parent)
                local valueText = stat.value
                if stat.percent then
                    local percentValue = math.floor(stat.value * 10000) / 100
                    local sign = percentValue > 0 and "+ " or ""
                    valueText = sign .. percentValue .. "%"
                end
                widget:setText("   " .. valueText .. " " .. stat.name)
                widget:setMarginLeft(60)
                return widget
            else
                local widget = g_ui.createWidget("CharacterSkillBase", parent)
                local nameLabel = g_ui.createWidget("SkillNameLabel", widget)
                nameLabel:setText(stat.name .. ":")
                local valueLabel = g_ui.createWidget("SkillValueLabel", widget)
                if stat.percent then
                    local percentValue = math.floor(stat.value * 10000) / 100
                    local sign = percentValue > 0 and "+ " or ""
                    
                    
                    valueLabel:setText(sign .. percentValue .. "%")
                else
                    valueLabel:setText(tostring(stat.value))
                end
                
                if stat.icon then
                    valueLabel:setMarginRight(12)
                    local icon = g_ui.createWidget("SkillCharacterIcon", widget)
                    icon:setMarginTop(2)
                    icon:addAnchor(AnchorRight, "parent", AnchorRight)
                    if stat.element then
                        local element = Cyclopedia.clientCombat[stat.element]
                        if element then
                            icon:setImageSource(element.path)
                            icon:setImageSize({
                                width = 9,
                                height = 9
                            })
                        end
                    end
                end
    
                return widget
            end
        end
    
        for _, stat in ipairs(stats) do
            if stat.align ~= "center" and stat.value == 0 and stat.value ~= "" then
                -- Skip
            else
                renderStat(stat)
            end
        end
    end
