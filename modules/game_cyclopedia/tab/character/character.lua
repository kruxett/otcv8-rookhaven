local characterPanel = nil
local UI = nil
local _sessionStartXp = nil
local _sessionStartTime = nil
local _sessionXpGained = 0       -- accumulated XP delta from onExperienceChange
local _sessionLastXp  = nil      -- last known XP value for delta calculation
local characterLiveRefreshEvent = nil
local characterLiveSignalsConnected = false

local function cancelCharacterLiveRefresh()
    if characterLiveRefreshEvent then
        removeEvent(characterLiveRefreshEvent)
        characterLiveRefreshEvent = nil
    end
end

local function shouldRefreshCharacterStatsLive()
    if not UI or not g_game.isOnline() then
        return false
    end

    local selected = UI.selectedOption
    return selected == "CharacterStats"
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
    if selected == "CharacterStats" then
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
end

local function getPlayerVocationName(player)
    if not player then
        return "Unknown"
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
        UI.CharacterBase.InfoLabel:setText(string.format("Level: %d\n%s", player:getLevel(), getPlayerVocationName(player)))
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

function Cyclopedia.loadCharacterCombatStats(data, mitigation, additionalSkillsArray, forgeSkillsArray,
    perfectShotDamageRanges, combatsArray, concoctionsArray)

    -- Hide stats not applicable to Tibia 8.60
    local sectionsToHide = {"concoction", "concoctionPanel", "blessings"}
    for _, id in ipairs(sectionsToHide) do
        if UI.CombatStats[id] then
            UI.CombatStats[id]:setVisible(false)
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

    setElementIcon(UI.CombatStats.attack.icon, data.weaponElement)
    UI.CombatStats.attack.value:setText(data.weaponMaxHitChance)

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
                UI.CombatStats.attack:setTooltip("Equipped: " .. weaponName)
            else
                UI.CombatStats.attack:removeTooltip()
            end
        end
    end

    -- Estimated max hit using real TFS formula:
    -- MaxDamage = round((level/5) + (((skill/4+1) * (attack/3)) * 1.03) / attackFactor)
    -- attackFactor: Full=1.0, Balanced=1.2, Defensive=2.0
    if UI.CombatStats.estDps then
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

        UI.CombatStats.estDps.value:setText(tostring(estMaxHit))

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
        UI.CombatStats.estDps:setTooltip(tip)
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
            local estMaxHit  = maxPhy + maxElem
            local avgHit     = math.floor(estMaxHit / 2)
            local atkSpeedMs = data.attackSpeed or 2000
            local dpsVal     = (atkSpeedMs > 0) and (avgHit * 1000 / atkSpeedMs) or 0

            local modeNames = { [FightOffensive] = "Full Attack", [FightBalanced] = "Balanced", [FightDefensive] = "Defensive" }
            local modeName  = modeNames[fightMode] or "Full Attack"
            local skillNames = { [0]="Fist", [1]="Club", [2]="Sword", [3]="Axe", [4]="Distance" }
            local skillName  = skillNames[data.weaponSkillId or 0] or "Fist"

            -- Max Hit
            if UI.CombatStats.estDps then
                UI.CombatStats.estDps.value:setText(tostring(estMaxHit))
                local tip = string.format(
                    "Estimated max hit (%s mode)\n%s skill %d x Attack %d -> Physical: %d",
                    modeName, skillName, skillLevel, attack, maxPhy)
                if maxElem > 0 then
                    tip = tip .. string.format("\nElement attack %d -> Element: %d", elemAttack, maxElem)
                    tip = tip .. string.format("\nTotal: %d + %d = %d", maxPhy, maxElem, estMaxHit)
                end
                UI.CombatStats.estDps:setTooltip(tip)
            end

            -- Avg Hit
            if UI.CombatStats.avgHit then
                UI.CombatStats.avgHit.value:setText(tostring(avgHit))
                UI.CombatStats.avgHit:setTooltip(string.format(
                    "Average hit is half of estimated max hit.\nActual hit roll: random(0, %d).", estMaxHit))
            end

            -- Attack Speed
            if UI.CombatStats.atkSpeed then
                UI.CombatStats.atkSpeed.value:setText(string.format("%.1fs", atkSpeedMs / 1000))
            end

            -- Est. DPS
            if UI.CombatStats.dps then
                UI.CombatStats.dps.value:setText(string.format("%.1f", dpsVal))
                UI.CombatStats.dps:setTooltip(string.format(
                    "Estimated DPS = Average Hit %.0f / Attack Speed %.1fs\nShown before armor and defense reductions.",
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

            if UI.CombatStats.criticalChance then
                UI.CombatStats.criticalChance.value:setText(string.format("%.1f%%", totalMitigationPct))
                UI.CombatStats.criticalChance.value:setColor(totalMitigationPct >= 15 and "#44AD25" or "#C0C0C0")
                UI.CombatStats.criticalChance:setTooltip(string.format(
                    "Estimated mitigation from your defensive setup.\nBased on armor formula output.\nAverage flat armor reduction: %.1f per hit.",
                    avgArmor))
            end

            if UI.CombatStats.criticalDamage then
                UI.CombatStats.criticalDamage.value:setText(string.format("%.1f", avgArmor))
                UI.CombatStats.criticalDamage.value:setColor("#C0C0C0")
                UI.CombatStats.criticalDamage:setTooltip(string.format(
                    "Armor reduction from the combat formula.\nArmor value: %d\nAverage reduction: %.1f per hit.", armorVal, avgArmor))
            end

            if UI.CombatStats.lifeLeech then
                UI.CombatStats.lifeLeech.value:setText(string.format("%.1f", avgDefenseReduction))
                UI.CombatStats.lifeLeech.value:setColor("#C0C0C0")
                UI.CombatStats.lifeLeech:setTooltip(string.format(
                    "Defense roll reduction from the combat formula.\nDefense value: %d\nRoll range: %d to %d\nAverage reduction: %.1f when a defense check triggers.",
                    defenseVal, minDefenseReduction, maxDefenseReduction, avgDefenseReduction))
            end

            if UI.CombatStats.manaLeech then
                UI.CombatStats.manaLeech:setVisible(true)
                UI.CombatStats.manaLeech.value:setText(string.format("%.1f", avgTotalReduction))
                UI.CombatStats.manaLeech.value:setColor("#44AD25")
                UI.CombatStats.manaLeech:setTooltip(string.format(
                    "Combined average flat reduction from armor and defense formulas.\nArmor average: %.1f\nDefense average: %.1f\nTotal average: %.1f\nApplies when both checks are active.",
                    avgArmor, avgDefenseReduction, avgTotalReduction))
            end

            if UI.CombatStats.defenseWindow then
                UI.CombatStats.defenseWindow:setVisible(true)
                UI.CombatStats.defenseWindow.value:setText(string.format("%d - %d", minTotalReduction, maxTotalReduction))
                UI.CombatStats.defenseWindow.value:setColor("#C0C0C0")
                UI.CombatStats.defenseWindow:setTooltip(string.format(
                    "Theoretical total reduction interval from server formulas.\nArmor range: %d to %d\nDefense range: %d to %d\nCombined range: %d to %d\nThe defense component requires a defense check.",
                    minArmorReduction, maxArmorReduction, minDefenseReduction, maxDefenseReduction, minTotalReduction, maxTotalReduction))
            end
        end

    if data.weaponElementDamage > 0 then
        UI.CombatStats.converted.none:setVisible(false)
        UI.CombatStats.converted.value:setVisible(true)
        UI.CombatStats.converted.icon:setVisible(true)
        setElementIcon(UI.CombatStats.converted.icon, data.weaponElementType)
        UI.CombatStats.converted.value:setText(data.weaponElementDamage .. "%")
    else
        UI.CombatStats.converted.none:setVisible(true)
        UI.CombatStats.converted.value:setVisible(false)
        UI.CombatStats.converted.icon:setVisible(false)
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

    if UI.CombatStats.defence then
        UI.CombatStats.defence.value:setText(string.format("%.2f%%", critChance))
        UI.CombatStats.defence:setTooltip(
            "Chance that your attack becomes a critical hit.")
    end

    if UI.CombatStats.armor then
        UI.CombatStats.armor.value:setText(string.format("+%.2f%%", critExtra))
        UI.CombatStats.armor:setTooltip(
            "Extra damage added when a critical hit triggers.")
    end

    if UI.CombatStats.mitigation then
        UI.CombatStats.mitigation.value:setText(string.format("%.2f%%", critTotal))
        UI.CombatStats.mitigation:setTooltip(
            "Total critical hit multiplier.\nFormula: 100% base + critical extra damage.")
    end

    if UI.CombatStats.reductionNone then
        UI.CombatStats.reductionNone:destroyChildren()
        if UI.CombatStats.reduction then
            UI.CombatStats.reduction:setVisible(false)
        end

        local function decodeReductionPercent(encoded)
            if encoded < 32768 then
                return encoded / 100
            else
                return -(65535 - encoded) / 100
            end
        end

        -- Show all resistances, including element 0 (Physical).
        local elementEntries = {}
        if combatsArray then
            for _, entry in ipairs(combatsArray) do
                if entry[1] ~= nil then
                    table.insert(elementEntries, entry)
                end
            end
        end

        if #elementEntries > 0 then
            if UI.CombatStats.reduction then
                UI.CombatStats.reduction:setVisible(true)
            end
            UI.CombatStats.reductionNone:setVisible(true)

            for _, entry in ipairs(elementEntries) do
                local elementId = entry[1]
                local encodedPercent = entry[2]
                local pct = decodeReductionPercent(encodedPercent)
                -- Cap positive resistance at 50% (server enforces it, client mirrors the cap)
                local displayPct = (pct > 0) and math.min(50, pct) or pct

                local elementInfo = Cyclopedia.clientCombat and Cyclopedia.clientCombat[elementId]
                local elementName = elementInfo and elementInfo.id or ("Element " .. elementId)
                local elementPath = elementInfo and elementInfo.path or nil

                local row = g_ui.createWidget("CharacterSkillBase", UI.CombatStats.reductionNone)

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
                valueLabel:setText(string.format("%s%.0f%%", sign, displayPct))

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
            UI.CombatStats.reductionNone:setVisible(false)
        end
    end

    -- concoctions
    UI.CombatStats.concoctionPanel:destroyChildren()
    if concoctionsArray and next(concoctionsArray) ~= nil then
        for i = 1, #concoctionsArray do
            local widget = g_ui.createWidget("CharacterGridItem", UI.CombatStats.concoctionPanel)
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
        if UI.CombatStats[id] then
            UI.CombatStats[id]:destroy()
        end
    end

    local firstSpecial = true

    for i = 1, #forgeSkillsArray do
        local skillId = forgeSkillsArray[i][1]
        local percent = forgeSkillsArray[i][2]

        if percent > 0 then
            local widget = g_ui.createWidget("CharacterSkillBase", UI.CombatStats)
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
        UI.CharacterBase.InfoLabel:setText(string.format("Level: %d\n%s", player:getLevel(), currentVocationName))
    end
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
        { Vocation = getPlayerVocationName(player) },
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