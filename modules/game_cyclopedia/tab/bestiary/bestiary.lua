local UI = nil

local STAGES = {
    CREATURES = 2,
    SEARCH = 4,
    CATEGORY = 1,
    CREATURE = 3
}

local BESTIARY_UNLOCK_HINT = "Bestiary entries are unlocked by killing creatures. Only discovered creatures are shown."

local storedRaceIDs = {}
-- Move tracker data to global Cyclopedia namespace to persist across module reloads
Cyclopedia.storedTrackerData = Cyclopedia.storedTrackerData or nil
Cyclopedia.storedBosstiaryTrackerData = Cyclopedia.storedBosstiaryTrackerData or nil
Cyclopedia.storedTaskTrackerData = Cyclopedia.storedTaskTrackerData or nil
local animusMasteryPoints = 0
local bestiaryTrackerLiveRefreshEvent = nil
local BESTIARY_TRACKER_LIVE_REFRESH_MS = 1500

local function cancelBestiaryTrackerLiveRefresh()
    if bestiaryTrackerLiveRefreshEvent then
        removeEvent(bestiaryTrackerLiveRefreshEvent)
        bestiaryTrackerLiveRefreshEvent = nil
    end
end

local function scheduleBestiaryTrackerLiveRefresh()
    cancelBestiaryTrackerLiveRefresh()

    bestiaryTrackerLiveRefreshEvent = scheduleEvent(function()
        bestiaryTrackerLiveRefreshEvent = nil

        if not g_game.isOnline() then
            return
        end

        local bestiaryVisible = trackerMiniWindow and trackerMiniWindow:isVisible()
        local taskVisible = trackerMiniWindowTask and trackerMiniWindowTask:isVisible()
        if not bestiaryVisible and not taskVisible then
            return
        end

        if bestiaryVisible then
            if g_game.requestBestiaryTracker then
                g_game.requestBestiaryTracker()
            else
                g_game.requestBestiary()
            end
        end

        if taskVisible and g_game.requestTaskTracker then
            g_game.requestTaskTracker()
        end

        scheduleBestiaryTrackerLiveRefresh()
    end, BESTIARY_TRACKER_LIVE_REFRESH_MS)
end

local function getCreatureWidgetCreature(widget)
    if not widget or not widget.getCreature then
        return nil
    end

    local ok, creature = pcall(function()
        return widget:getCreature()
    end)

    if ok then
        return creature
    end

    return nil
end

local function safeSetCreatureStaticWalking(widget, interval)
    local creature = getCreatureWidgetCreature(widget)
    if creature and creature.setStaticWalking then
        creature:setStaticWalking(interval)
    end
end

local function safeSetCreatureShader(widget, shader)
    local creature = getCreatureWidgetCreature(widget)
    if creature and creature.setShader then
        creature:setShader(shader)
    end
end

local function setBestiaryCategoryIcon(iconWidget, categoryName)
    if not iconWidget then
        return
    end

    local normalizedCategory = tostring(categoryName or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local iconNameByCategory = {
        -- Legacy support
        ["all"] = "all",
        ["other"] = "all",
        
        -- Humanoids category
        ["humanoid"] = "humanoid",
        ["humanoids"] = "humanoid",
        ["human"] = "humanoid",
        ["humans"] = "humanoid",
        ["cultist"] = "humanoid",
        ["cultists"] = "humanoid",
        ["knight"] = "humanoid",
        ["knights"] = "humanoid",
        ["warrior"] = "humanoid",
        ["warriors"] = "humanoid",
        ["mage"] = "humanoid",
        ["mages"] = "humanoid",
        ["wizard"] = "humanoid",
        ["wizards"] = "humanoid",
        ["priest"] = "humanoid",
        ["priests"] = "humanoid",
        
        -- Beasts category
        ["beast"] = "beast",
        ["mammals"] = "mammal",
        ["mammal"] = "mammal",
        ["beasts"] = "mammal",
        ["animal"] = "beast",
        ["animals"] = "beast",
        ["canine"] = "mammal",
        ["canines"] = "mammal",
        ["feline"] = "mammal",
        ["felines"] = "mammal",
        
        -- Undead category
        ["undead"] = "undead",
        ["skeleton"] = "undead",
        ["skeletons"] = "undead",
        ["zombie"] = "undead",
        ["zombies"] = "undead",
        ["wraith"] = "undead",
        ["wraiths"] = "undead",
        ["ghost"] = "undead",
        ["ghosts"] = "undead",
        ["vampire"] = "undead",
        ["vampires"] = "undead",
        ["lich"] = "undead",
        ["liches"] = "undead",
        
        -- Demons category
        ["demon"] = "demon",
        ["demons"] = "demon",
        ["devil"] = "demon",
        ["devils"] = "demon",
        ["fiend"] = "demon",
        ["fiends"] = "demon",
        ["infernal"] = "demon",
        
        -- Insects/Vermin category
        ["insectoid"] = "insectoid",
        ["insectoids"] = "insectoid",
        ["insects"] = "vermin",
        ["insect"] = "vermin",
        ["vermin"] = "vermin",
        ["spider"] = "vermin",
        ["spiders"] = "vermin",
        ["arachnid"] = "vermin",
        ["arachnids"] = "vermin",
        ["scorpion"] = "vermin",
        ["scorpions"] = "vermin",
        ["worm"] = "vermin",
        ["worms"] = "vermin",
        ["bug"] = "vermin",
        ["bugs"] = "vermin",
        
        -- Elementals category
        ["elemental"] = "elemental",
        ["elementals"] = "elemental",
        ["element"] = "elemental",
        ["fire elemental"] = "elemental",
        ["energy elemental"] = "elemental",
        ["earth elemental"] = "elemental",
        ["golem"] = "elemental",
        ["golems"] = "elemental",
        ["construct"] = "elemental",
        ["constructs"] = "elemental",
        ["amphibian"] = "reptile",
        ["amphibians"] = "reptile",
        ["plant"] = "magical",
        ["plants"] = "magical",
        ["extra dimensional"] = "magical",
        ["extra-dimensional"] = "magical",
        ["unknown"] = "all",
        
        -- Dragons category
        ["dragon"] = "mammal",
        ["dragons"] = "mammal",
        ["dragonborn"] = "mammal",
        ["drake"] = "mammal",
        ["drakes"] = "mammal",
        ["wyrm"] = "mammal",
        ["wyrms"] = "mammal",
        ["lindworm"] = "mammal",
        
        -- Reptiles category
        ["reptile"] = "reptile",
        ["reptiles"] = "reptile",
        ["reptilian"] = "reptile",
        ["serpent"] = "reptile",
        ["serpents"] = "reptile",
        ["lizard"] = "reptile",
        ["lizards"] = "reptile",
        ["scaled"] = "reptile",
        
        -- Magical creatures
        ["magical"] = "magical",
        ["magical creature"] = "magical",
        ["magical creatures"] = "magical",
        ["enchanted"] = "magical",
        ["mystical"] = "magical",
        ["spirit"] = "magical",
        ["spirits"] = "magical",
        ["wisp"] = "magical",
        ["wisps"] = "magical",
        
        -- Boss category (uses demon icon, but maps bosses)
        ["bosses"] = "demon",
        ["boss"] = "demon",
        ["raid boss"] = "demon",
        ["unique"] = "demon",
        ["legendary"] = "demon",
    }

    local iconName = iconNameByCategory[normalizedCategory] or normalizedCategory:gsub(" ", "_")
    local iconPath = "/game_cyclopedia/images/bestiary/creatures/" .. iconName
    local filePath = "/modules/game_cyclopedia/images/bestiary/creatures/" .. iconName .. ".png"

    if g_resources.fileExists(filePath) then
        iconWidget:setImageSource(iconPath)
        return
    end

    iconWidget:setImageSource("/game_cyclopedia/images/book")
end

local function formatBestiaryCreatureName(name)
    local text = tostring(name or "Unknown")
    return text:gsub("(%a)([%w']*)", function(first, rest)
        return first:upper() .. rest:lower()
    end)
end

function Cyclopedia.loadBestiaryOverview(name, creatures, animusPoints)
    if (name == "Result" or name == "") and #creatures > 0 then
        if #creatures == 1 then
            g_game.requestBestiarySearch(creatures[1].id)
            Cyclopedia.ShowBestiaryCreature()
        else
        Cyclopedia.loadBestiarySearchCreatures(creatures)
        end
    else
        Cyclopedia.loadBestiaryCreatures(creatures)
    end

    if animusPoints and animusPoints > 0 then
        animusMasteryPoints = animusPoints
    end
end

function showBestiary()
    UI = g_ui.loadUI("bestiary", contentContainer)
    UI:show()

    if UI.SearchEdit then
        UI.SearchEdit:setTooltip(BESTIARY_UNLOCK_HINT)
    end

    if UI.SearchButton then
        UI.SearchButton:setTooltip("Search discovered creatures")
    end

    UI.ListBase.CategoryList:setVisible(true)
    UI.ListBase.CreatureList:setVisible(false)
    UI.ListBase.CreatureInfo:setVisible(false)

    Cyclopedia.Bestiary.Stage = STAGES.CATEGORY
    Cyclopedia.Bestiary.Page = 1
    Cyclopedia.Bestiary.Categories = Cyclopedia.Bestiary.Categories or {}
    Cyclopedia.Bestiary.Creatures = Cyclopedia.Bestiary.Creatures or {}
    Cyclopedia.Bestiary.Search = Cyclopedia.Bestiary.Search or {}
    Cyclopedia.Bestiary.TotalCategoriesPages = Cyclopedia.Bestiary.TotalCategoriesPages or 1
    Cyclopedia.Bestiary.TotalCreaturesPages = Cyclopedia.Bestiary.TotalCreaturesPages or 1
    Cyclopedia.Bestiary.TotalSearchPages = Cyclopedia.Bestiary.TotalSearchPages or 1
    controllerCyclopedia.ui.CharmsBase:setVisible(false)
    controllerCyclopedia.ui.GoldBase:setVisible(true)
    controllerCyclopedia.ui.BestiaryTrackerButton:setVisible(true)
    if controllerCyclopedia.ui.TaskTrackerButton then
        controllerCyclopedia.ui.TaskTrackerButton:setVisible(true)
    end
    if g_game.getClientVersion() >= 1410 then
        controllerCyclopedia.ui.CharmsBase1410:hide()
    end

    local charmWidgetsToHide = {
        "CharmBase",
        "SelectButton",
        "CharmSelector",
        "BalanceBase",
        "CharmLabel",
        "BonusIcon",
        "BonusValue",
        "IconsSep",
        "LocationField",
        "LocationLabel",
    }

    for _, widgetId in ipairs(charmWidgetsToHide) do
        local widget = UI.ListBase and UI.ListBase.CreatureInfo and UI.ListBase.CreatureInfo[widgetId]
        if widget then
            widget:setVisible(false)
        end
    end
    
    -- Initialize tracker data and storedRaceIDs when bestiary is opened
    -- This ensures Track Kills status is properly loaded from cache
    Cyclopedia.initializeTrackerData()
    Cyclopedia.ensureStoredRaceIDsPopulated()

    -- Bind Enter key to search when SearchEdit is focused
    g_keyboard.bindKeyDown('Enter', function()
        if UI and UI:isVisible() and UI.SearchEdit:getText() ~= "" then
            Cyclopedia.BestiarySearch()
        end
    end, UI.SearchEdit)

    
    g_game.requestBestiary()

    -- Retry a few times in case first request happened before transport was ready.
    local retries = 0
    local function ensureBestiaryCategoriesLoaded()
        if not UI or not UI:isVisible() then
            return
        end

        local hasCategories = Cyclopedia.Bestiary and Cyclopedia.Bestiary.Categories and
            Cyclopedia.Bestiary.Categories[1] and #Cyclopedia.Bestiary.Categories[1] > 0
        if hasCategories then
            return
        end

        retries = retries + 1
        if retries <= 5 then
            g_game.requestBestiary()
            scheduleEvent(ensureBestiaryCategoriesLoaded, 400)
        end
    end

    Cyclopedia.onStageChange()
    scheduleEvent(ensureBestiaryCategoriesLoaded, 400)
end

Cyclopedia.Bestiary = {}
Cyclopedia.Bestiary.Stage = STAGES.CATEGORY
Cyclopedia.Bestiary.LastSearchText = ""
Cyclopedia.Bestiary.AllCreatures = Cyclopedia.Bestiary.AllCreatures or {}

local function normalizeBestiarySearchText(text)
    local searchText = tostring(text or ""):lower()
    searchText = searchText:gsub("^%s+", "")
    searchText = searchText:gsub("%s+$", "")
    return searchText
end

local function getBestiaryCreatureDisplayNameById(raceId)
    local raceData = g_things.getRaceData(raceId)
    return tostring((raceData and raceData.name) or "Unknown")
end

local function bestiaryCreatureIsKnown(creature)
    return (tonumber(creature and creature.killCounter) or 0) > 0
end

local function filterBestiaryCreatures(creatures, searchText)
    local filtered = {}
    local normalizedSearch = normalizeBestiarySearchText(searchText)

    for _, creature in ipairs(creatures or {}) do
        local known = bestiaryCreatureIsKnown(creature)
        if known then
            if normalizedSearch == "" then
                table.insert(filtered, creature)
            else
                local raceName = getBestiaryCreatureDisplayNameById(creature.id):lower()
                if raceName:find(normalizedSearch, 1, true) then
                    table.insert(filtered, creature)
                end
            end
        end
    end

    return filtered
end

function Cyclopedia.SetBestiaryProgress(fit, firstBar, secondBar, thirdBar, killCount, firstGoal, secondGoal, thirdGoal)
    local function calculateWidth(value, max)
        return math.min(math.floor((value / max) * fit), fit)
    end

    local function setBarVisibility(bar, isVisible, width, isCompleted)
        isVisible = isVisible and width > 0
        bar:setVisible(isVisible)
        if isVisible then
            -- Use fill image only when bestiary is completed, otherwise use orange progress bar
            if isCompleted then
                bar:setImageRect({
                    height = 12,
                    x = 0,
                    y = 0,
                    width = width
                })
                bar:setImageSource("/game_cyclopedia/images/bestiary/fill")
            else
                -- For orange progress bar, set the widget width and use image as background
                bar:setWidth(width)
                bar:setImageSource("/game_cyclopedia/images/bestiary/progressbar-orange-small")
                -- Clear any image rect to use the full image as background
                bar:setImageRect({})
            end
        end
    end

    -- Check if bestiary is completed (reached final goal)
    local isCompleted = killCount >= thirdGoal

    local firstWidth = calculateWidth(math.min(killCount, firstGoal), firstGoal)
    setBarVisibility(firstBar, killCount > 0, firstWidth, isCompleted)

    local secondWidth = 0
    if killCount > firstGoal then
        secondWidth = calculateWidth(math.min(killCount - firstGoal, secondGoal - firstGoal), secondGoal - firstGoal)
    end
    setBarVisibility(secondBar, killCount > firstGoal, secondWidth, isCompleted)

    local thirdWidth = 0
    if killCount > secondGoal then
        thirdWidth = calculateWidth(math.min(killCount - secondGoal, thirdGoal - secondGoal), thirdGoal - secondGoal)
    end
    setBarVisibility(thirdBar, killCount > secondGoal, thirdWidth, isCompleted)
end

function Cyclopedia.SetBestiaryStars(value)
    local safeValue = math.max(0, tonumber(value) or 0)
    UI.ListBase.CreatureInfo.StarFill:setWidth(safeValue * 9)
end

function Cyclopedia.SetBestiaryDiamonds(value)
    local safeValue = math.max(0, tonumber(value) or 0)
    UI.ListBase.CreatureInfo.DiamondFill:setWidth(safeValue * 9)
end

function Cyclopedia.CreateCreatureItems(data)
    UI.ListBase.CreatureInfo.ItemsBase.Itemlist:destroyChildren()

    for index, _ in pairs(data) do
        local widget = g_ui.createWidget("BestiaryItemGroup", UI.ListBase.CreatureInfo.ItemsBase.Itemlist)
        widget:setId(index)

        if index == 0 then
            widget.Title:setText(tr("Common") .. ":")
        elseif index == 1 then
            widget.Title:setText(tr("Uncommon") .. ":")
        elseif index == 2 then
            widget.Title:setText(tr("Semi-Rare") .. ":")
        elseif index == 3 then
            widget.Title:setText(tr("Rare") .. ":")
        else
            widget.Title:setText(tr("Very Rare") .. ":")
        end

        for i = 1, 15 do
            local item = g_ui.createWidget("BestiaryItem", widget.Items)
            item:setId(i)
        end

        for itemIndex, itemData in ipairs(data[index]) do
            local thing = g_things.getThingType(itemData.id, ThingCategoryItem)
            local itemWidget = UI.ListBase.CreatureInfo.ItemsBase.Itemlist[index].Items[itemIndex]
            itemWidget:setItemId(itemData.id)
            itemWidget.id = itemData.id
            itemWidget.classification = thing and thing.getClassification and thing:getClassification() or 0

            if itemData.id == 0 then
                itemWidget.undefinedItem:setVisible(true)
            end

            if itemData.id > 0 then
                if itemData.stackable then
                    itemWidget.Stackable:setText("1+")
                else
                    itemWidget.Stackable:setText("1")
                end
            end

            if ItemsDatabase and ItemsDatabase.setRarityItem then
                ItemsDatabase.setRarityItem(itemWidget, itemWidget:getItem())
            end

            itemWidget.onMouseRelease = onAddLootClick
        end
    end
end

function Cyclopedia.loadBestiarySelectedCreature(data)
    local raceData = g_things.getRaceData(data.id)
    local raceName = raceData and raceData.name or "Unknown"
    local formattedName = formatBestiaryCreatureName(raceName)

    UI.ListBase.CreatureInfo:setVisible(true)
    UI.ListBase.CreatureInfo:setText(formattedName)
    local occurrenceValue = math.max(1, math.min(4, tonumber(data.ocorrence) or 1))
    Cyclopedia.SetBestiaryDiamonds(occurrenceValue)
    Cyclopedia.SetBestiaryStars(data.difficulty)

    local difficultyValue = math.max(1, math.min(5, tonumber(data.difficulty) or 1))
    occurrenceValue = math.max(1, math.min(4, tonumber(data.ocorrence) or 1))
    local difficultyLevels = {
        [1] = "Very Easy",
        [2] = "Easy",
        [3] = "Medium",
        [4] = "Hard",
        [5] = "Very Hard",
    }
    local occurrenceLevels = {
        [1] = "Very Rare",
        [2] = "Rare",
        [3] = "Common",
        [4] = "Very Common",
    }

    local difficultyTooltip = string.format("Difficulty: %s (%d/5 stars).\nHigher stars indicate a more dangerous creature.",
        difficultyLevels[difficultyValue] or "Unknown", difficultyValue)
    local occurrenceTooltip = string.format("Occurrence: %s (%d/4 diamonds).\nHigher diamonds indicate the creature is encountered more often.",
        occurrenceLevels[occurrenceValue] or "Unknown", occurrenceValue)

    if UI.ListBase.CreatureInfo.StarBase then UI.ListBase.CreatureInfo.StarBase:setTooltip(difficultyTooltip) end
    if UI.ListBase.CreatureInfo.StarFill then UI.ListBase.CreatureInfo.StarFill:setTooltip(difficultyTooltip) end
    if UI.ListBase.CreatureInfo.DiamondBase then UI.ListBase.CreatureInfo.DiamondBase:setTooltip(occurrenceTooltip) end
    if UI.ListBase.CreatureInfo.DiamondFill then UI.ListBase.CreatureInfo.DiamondFill:setTooltip(occurrenceTooltip) end

    UI.ListBase.CreatureInfo.LeftBase.Sprite:setOutfit(raceData.outfit or { type = 0 })
    safeSetCreatureStaticWalking(UI.ListBase.CreatureInfo.LeftBase.Sprite, 1000)

    Cyclopedia.SetBestiaryProgress(60, UI.ListBase.CreatureInfo.ProgressBack, UI.ListBase.CreatureInfo.ProgressBack33,
        UI.ListBase.CreatureInfo.ProgressBack55, data.killCounter, data.thirdDifficulty, data.secondUnlock,
        data.lastProgressKillCount)

    UI.ListBase.CreatureInfo.ProgressValue:setText(data.killCounter)

    local fullText = ""
    if data.killCounter >= data.lastProgressKillCount then
        fullText = "(fully unlocked)"
    end

    UI.ListBase.CreatureInfo.ProgressBorder1:setTooltip(string.format(" %d / %d %s", data.killCounter,
        data.thirdDifficulty, fullText))
    UI.ListBase.CreatureInfo.ProgressBorder2:setTooltip(string.format(" %d / %d %s", data.killCounter,
        data.secondUnlock, fullText))
    UI.ListBase.CreatureInfo.ProgressBorder3:setTooltip(string.format(" %d / %d %s", data.killCounter,
        data.lastProgressKillCount, fullText))
    UI.ListBase.CreatureInfo.LeftBase.TrackCheck.raceId = data.id

    -- TODO investigate when it can be track-- idk when
    --[[     if data.currentLevel == 1 then
        UI.ListBase.CreatureInfo.LeftBase.TrackCheck:enable()
    else
        UI.ListBase.CreatureInfo.LeftBase.TrackCheck:disable()
    end ]]

    -- Ensure storedRaceIDs is populated from cached tracker data before checking
    Cyclopedia.ensureStoredRaceIDsPopulated()

    if table.find(storedRaceIDs, data.id) then
        UI.ListBase.CreatureInfo.LeftBase.TrackCheck:setChecked(true)
    else
        UI.ListBase.CreatureInfo.LeftBase.TrackCheck:setChecked(false)
    end

    if data.currentLevel > 1 then
        UI.ListBase.CreatureInfo.Value1:setText(data.maxHealth)
        UI.ListBase.CreatureInfo.Value2:setText(data.experience)
        UI.ListBase.CreatureInfo.Value3:setText(data.speed)
        UI.ListBase.CreatureInfo.Value4:setText(data.armor)
        UI.ListBase.CreatureInfo.Value5:setText(data.mitigation .. "%")
        UI.ListBase.CreatureInfo.BonusValue:setText(data.charmValue)
    else
        UI.ListBase.CreatureInfo.Value1:setText("?")
        UI.ListBase.CreatureInfo.Value2:setText("?")
        UI.ListBase.CreatureInfo.Value3:setText("?")
        UI.ListBase.CreatureInfo.Value4:setText("?")
        UI.ListBase.CreatureInfo.Value5:setText("?")
        UI.ListBase.CreatureInfo.BonusValue:setText("?")
    end

    local statsUnlocked = data.currentLevel > 1
    local statsLockHint = "Unlock more bestiary progress (kills) to reveal this value."

    local hpTooltip = statsUnlocked and string.format("Hit Points\nMaximum health: %s", tostring(data.maxHealth))
        or ("Hit Points\n" .. statsLockHint)
    local expTooltip = statsUnlocked and string.format("Experience\nXP granted on kill: %s", tostring(data.experience))
        or ("Experience\n" .. statsLockHint)
    local speedTooltip = statsUnlocked and string.format("Speed\nBase movement speed: %s", tostring(data.speed))
        or ("Speed\n" .. statsLockHint)
    local armorTooltip = statsUnlocked and string.format("Armor\nArmor value: %s", tostring(data.armor))
        or ("Armor\n" .. statsLockHint)
    local mitigationTooltip = statsUnlocked and string.format("Mitigation\nDamage reduction: %s%%", tostring(data.mitigation))
        or ("Mitigation\n" .. statsLockHint)
    local bonusTooltip = statsUnlocked and string.format("Charm Points\nPoints granted: %s", tostring(data.charmValue))
        or ("Charm Points\n" .. statsLockHint)

    if UI.ListBase.CreatureInfo.Icon1 then UI.ListBase.CreatureInfo.Icon1:setTooltip(hpTooltip) end
    if UI.ListBase.CreatureInfo.Value1 then UI.ListBase.CreatureInfo.Value1:setTooltip(hpTooltip) end
    if UI.ListBase.CreatureInfo.Icon2 then UI.ListBase.CreatureInfo.Icon2:setTooltip(expTooltip) end
    if UI.ListBase.CreatureInfo.Value2 then UI.ListBase.CreatureInfo.Value2:setTooltip(expTooltip) end
    if UI.ListBase.CreatureInfo.Icon3 then UI.ListBase.CreatureInfo.Icon3:setTooltip(speedTooltip) end
    if UI.ListBase.CreatureInfo.Value3 then UI.ListBase.CreatureInfo.Value3:setTooltip(speedTooltip) end
    if UI.ListBase.CreatureInfo.Icon4 then UI.ListBase.CreatureInfo.Icon4:setTooltip(armorTooltip) end
    if UI.ListBase.CreatureInfo.Value4 then UI.ListBase.CreatureInfo.Value4:setTooltip(armorTooltip) end
    if UI.ListBase.CreatureInfo.Icon5 then UI.ListBase.CreatureInfo.Icon5:setTooltip(mitigationTooltip) end
    if UI.ListBase.CreatureInfo.Value5 then UI.ListBase.CreatureInfo.Value5:setTooltip(mitigationTooltip) end
    if UI.ListBase.CreatureInfo.BonusIcon then UI.ListBase.CreatureInfo.BonusIcon:setTooltip(bonusTooltip) end
    if UI.ListBase.CreatureInfo.BonusValue then UI.ListBase.CreatureInfo.BonusValue:setTooltip(bonusTooltip) end

    if data.attackMode == 1 then
        local rect = {
            height = 9,
            x = 18,
            y = 0,
            width = 18
        }

        UI.ListBase.CreatureInfo.SubTextLabel:setImageSource("/images/icons/icons-skills")
        UI.ListBase.CreatureInfo.SubTextLabel:setImageClip(rect)
        UI.ListBase.CreatureInfo.SubTextLabel:setSize("18 9")
        UI.ListBase.CreatureInfo.SubTextLabel:setTooltip("Attack style: Ranged / Spellcaster\nThis creature can damage targets from distance.")
    else
        local rect = {
            height = 9,
            x = 0,
            y = 0,
            width = 18
        }
        UI.ListBase.CreatureInfo.SubTextLabel:setImageSource("/images/icons/icons-skills")
        UI.ListBase.CreatureInfo.SubTextLabel:setImageClip(rect)
        UI.ListBase.CreatureInfo.SubTextLabel:setSize("18 9")
        UI.ListBase.CreatureInfo.SubTextLabel:setTooltip("Attack style: Melee\nThis creature primarily fights in close combat.")
    end

    local resists = {"PhysicalProgress", "FireProgress", "EarthProgress", "EnergyProgress", "IceProgress",
                     "HolyProgress", "DeathProgress", "HealingProgress"}

    if not table.empty(data.combat) then
        for i = 1, 8 do
            local combat = Cyclopedia.calculateCombatValues(data.combat[i])
            UI.ListBase.CreatureInfo[resists[i]].Fill:setMarginRight(combat.margin)
            UI.ListBase.CreatureInfo[resists[i]].Fill:setBackgroundColor(combat.color)
            UI.ListBase.CreatureInfo[resists[i]]:setTooltip(string.format("Sensitive to %s : %s", string.gsub(
                resists[i], "Progress", ""):lower(), combat.tooltip))
        end
    else
        for i = 1, 8 do
            UI.ListBase.CreatureInfo[resists[i]].Fill:setMarginRight(65)
        end
    end

    local lootData = {}
    for _, value in ipairs(data.loot) do
        local loot = {
            name = value.name,
            id = value.itemId,
            type = value.type,
            difficulty = value.diffculty,
            stackable = value.stackable == 1 and true or false
        }

        if not lootData[value.diffculty] then
            lootData[value.diffculty] = {}
        end

        table.insert(lootData[value.diffculty], loot)
    end

    Cyclopedia.CreateCreatureItems(lootData)
    if UI.ListBase.CreatureInfo.LocationField and UI.ListBase.CreatureInfo.LocationField.Textlist and UI.ListBase.CreatureInfo.LocationField.Textlist.Text then
        UI.ListBase.CreatureInfo.LocationField.Textlist.Text:setText("")
    end

    if data.AnimusMasteryPoints and data.AnimusMasteryPoints > 1 then
        UI.ListBase.CreatureInfo.AnimusMastery:setTooltip("The Animus Mastery for this creature is unlocked.\nIt yields "..(data.AnimusMasteryBonus / 10).."% bonus experience points, plus an additional 0.1% for every 10 Animus Masteries unlocked, up to a maximum of 4%.\nYou currently benefit from "..(data.AnimusMasteryBonus / 10).."% bonus experience points due to having unlocked ".. data.AnimusMasteryPoints .." Animus Masteries.")
        UI.ListBase.CreatureInfo.AnimusMastery:setVisible(true)
    else
        UI.ListBase.CreatureInfo.AnimusMastery:removeTooltip()
        UI.ListBase.CreatureInfo.AnimusMastery:setVisible(false)
    end
end

function Cyclopedia.ShowBestiaryCreature()
    Cyclopedia.Bestiary.Stage = STAGES.CREATURE
    Cyclopedia.onStageChange()
end

function Cyclopedia.ShowBestiaryCreatures(Category)
    UI.ListBase.CreatureList:destroyChildren()
    UI.ListBase.CategoryList:setVisible(false)
    UI.ListBase.CreatureInfo:setVisible(false)
    UI.ListBase.CreatureList:setVisible(true)
    g_game.requestBestiaryOverview(Category, false, {})
end

function Cyclopedia.CreateBestiaryCategoryItem(Data)
    -- Keep back-button state controlled by stage transitions to avoid async desync.
    if Cyclopedia.Bestiary.Stage == STAGES.CATEGORY then
        UI.BackPageButton:setEnabled(false)
    end

    local widget = g_ui.createWidget("BestiaryCategory", UI.ListBase.CategoryList)
    widget:setText(Data.name)
    setBestiaryCategoryIcon(widget.ClassIcon, Data.name)
    widget.Category = Data.name
    widget:setColor("#C0C0C0")
    widget.TotalValue:setText(string.format("Total: %d", Data.amount))
    widget.KnownValue:setText(string.format("Known: %d", Data.know))
    widget.KnownValue:setTooltip("Known = creatures with at least 1 kill.")
    widget.TotalValue:setTooltip("Total creatures in this category.")
    widget:setTooltip(BESTIARY_UNLOCK_HINT)

    function widget.ClassBase:onClick()
        UI.BackPageButton:setEnabled(true)
        Cyclopedia.ShowBestiaryCreatures(self:getParent().Category)
        Cyclopedia.Bestiary.Stage = STAGES.CREATURES
        Cyclopedia.onStageChange()
    end
end

function Cyclopedia.loadBestiarySearchCreatures(data)
    UI.ListBase.CategoryList:setVisible(false)
    UI.ListBase.CreatureInfo:setVisible(false)
    UI.ListBase.CreatureList:setVisible(true)
    UI.BackPageButton:setEnabled(true)

    Cyclopedia.Bestiary.Stage = STAGES.SEARCH
    Cyclopedia.onStageChange()
    Cyclopedia.Bestiary.Search = {}
    Cyclopedia.Bestiary.Page = 1

    local sourceData = filterBestiaryCreatures(data, Cyclopedia.Bestiary.LastSearchText)

    local maxCategoriesPerPage = 15
    Cyclopedia.Bestiary.TotalSearchPages = math.ceil(#sourceData / maxCategoriesPerPage)
    if Cyclopedia.Bestiary.TotalSearchPages < 1 then
        Cyclopedia.Bestiary.TotalSearchPages = 1
    end

    UI.PageValue:setText(string.format("%d / %d", Cyclopedia.Bestiary.Page, Cyclopedia.Bestiary.TotalSearchPages))

    local page = 1
    Cyclopedia.Bestiary.Search[page] = {}

    for i = 1, #sourceData do
        if (i - 1) % maxCategoriesPerPage == 0 and i > 1 then
            page = page + 1
            Cyclopedia.Bestiary.Search[page] = {}
        end
        local creature = {
            id = sourceData[i].id,
            currentLevel = sourceData[i].currentLevel,
            AnimusMasteryBonus = sourceData[i].creatureAnimusMasteryBonus or 0,
            killCounter = sourceData[i].killCounter or 0,
        }

        table.insert(Cyclopedia.Bestiary.Search[page], creature)
    end

    if #sourceData == 0 then
        Cyclopedia.Bestiary.Search[1] = {}
    end

    Cyclopedia.Bestiary.Stage = STAGES.SEARCH
    Cyclopedia.loadBestiaryCreature(Cyclopedia.Bestiary.Page, true)
    Cyclopedia.verifyBestiaryButtons()
end

function Cyclopedia.loadBestiaryCreatures(data)
    Cyclopedia.Bestiary.AllCreatures = {}
    Cyclopedia.Bestiary.Creatures = {}
    Cyclopedia.Bestiary.Page = 1

    for i = 1, #data do
        table.insert(Cyclopedia.Bestiary.AllCreatures, {
            id = data[i].id,
            currentLevel = data[i].currentLevel,
            creatureAnimusMasteryBonus = data[i].creatureAnimusMasteryBonus,
            killCounter = data[i].killCounter or 0,
        })
    end

    local sourceData = filterBestiaryCreatures(Cyclopedia.Bestiary.AllCreatures, "")

    local maxCategoriesPerPage = 15
    Cyclopedia.Bestiary.TotalCreaturesPages = math.ceil(#sourceData / maxCategoriesPerPage)
    if Cyclopedia.Bestiary.TotalCreaturesPages < 1 then
        Cyclopedia.Bestiary.TotalCreaturesPages = 1
    end

    UI.PageValue:setText(string.format("%d / %d", Cyclopedia.Bestiary.Page, Cyclopedia.Bestiary.TotalCreaturesPages))

    local page = 1
    Cyclopedia.Bestiary.Creatures[page] = {}

    for i = 1, #sourceData do
        if (i - 1) % maxCategoriesPerPage == 0 and i > 1 then
            page = page + 1
            Cyclopedia.Bestiary.Creatures[page] = {}
        end

        local creature = {
            id = sourceData[i].id,
            currentLevel = sourceData[i].currentLevel,
            AnimusMasteryBonus = sourceData[i].creatureAnimusMasteryBonus,
            killCounter = sourceData[i].killCounter or 0,

        }

        table.insert(Cyclopedia.Bestiary.Creatures[page], creature)
    end

    if #sourceData == 0 then
        Cyclopedia.Bestiary.Creatures[1] = {}
    end

    Cyclopedia.loadBestiaryCreature(Cyclopedia.Bestiary.Page, false)
    Cyclopedia.verifyBestiaryButtons()
end

-- note: this one needs refactor
-- expected result:
-- when a string is entered
-- the list should generate client-side
-- the list of search results that match the search string
-- looks identical to category view
function Cyclopedia.BestiarySearch()
    local text = normalizeBestiarySearchText(UI.SearchEdit:getText())
    Cyclopedia.Bestiary.LastSearchText = text

    if not Cyclopedia.Bestiary.AllCreatures or #Cyclopedia.Bestiary.AllCreatures == 0 then
        g_game.requestBestiaryOverview("Creatures", false, {})
        return
    end

    if text == "" then
        Cyclopedia.Bestiary.Stage = STAGES.CREATURES
        Cyclopedia.onStageChange()
        Cyclopedia.loadBestiaryCreatures(Cyclopedia.Bestiary.AllCreatures or {})
        return
    end

    local results = filterBestiaryCreatures(Cyclopedia.Bestiary.AllCreatures or {}, text)
    Cyclopedia.loadBestiarySearchCreatures(results)
end

function Cyclopedia.BestiarySearchText(text)
    if text ~= "" then
        UI.SearchButton:enable(true)
    else
        UI.SearchButton:disable(false)
        Cyclopedia.Bestiary.LastSearchText = ""
        if Cyclopedia.Bestiary.Stage == STAGES.SEARCH then
            Cyclopedia.Bestiary.Stage = STAGES.CREATURES
            Cyclopedia.onStageChange()
            Cyclopedia.loadBestiaryCreatures(Cyclopedia.Bestiary.AllCreatures or {})
        end
    end
end

function Cyclopedia.CreateBestiaryCreaturesItem(data)
    local raceData = g_things.getRaceData(data.id)

    local function verify(name)
        if #name > 18 then
            return name:sub(1, 15) .. "..."
        else
            return name
        end
    end

    local widget = g_ui.createWidget("BestiaryCreature", UI.ListBase.CreatureList)
    widget:setId(data.id)

    local raceName = raceData and raceData.name or "Unknown"
    local formattedName = formatBestiaryCreatureName(raceName)

    widget.Name:setText(verify(formattedName))
    widget.Sprite:setOutfit(raceData.outfit or { type = 0 })
    safeSetCreatureStaticWalking(widget.Sprite, 1000)

    local discovered = (tonumber(data.killCounter) or 0) > 0

    if data.AnimusMasteryBonus > 0 then
        widget.AnimusMastery:setTooltip("The Animus Mastery for this creature is unlocked.\nIt yields ".. data.AnimusMasteryBonus.. "% bonus experience points, plus an additional 0.1% for every 10 Animus Masteries unlocked, up to a maximum of 4%.\nYou currently benefit from ".. data.AnimusMasteryBonus.. "% bonus experience points due to having unlocked ".. animusMasteryPoints.." Animus Masteries.")
        widget.AnimusMastery:setVisible(true)
    else
        widget.AnimusMastery:removeTooltip()
        widget.AnimusMastery:setVisible(false)
    end

    if not discovered then
        widget.KillsLabel:setText("?")
        safeSetCreatureShader(widget.Sprite, "Outfit - cyclopedia-black")
        widget.Name:setText("Unknown")
        widget.AnimusMastery:setVisible(false)
    elseif data.currentLevel >= 3 then
        widget.Finalized:setVisible(true)
        widget.KillsLabel:setVisible(false)
        safeSetCreatureShader(widget.Sprite, "")
        widget:setTooltip("Fully unlocked by kills.")
    else
        widget.KillsLabel:setText(string.format("%d / 3", math.max(tonumber(data.currentLevel) or 0, 0)))
        widget:setTooltip("Progress unlocks by kill thresholds.")

    end

    function widget.ClassBase:onClick()
        UI.BackPageButton:setEnabled(true)
        g_game.requestBestiarySearch(widget:getId())
        Cyclopedia.ShowBestiaryCreature()
    end
end

function Cyclopedia.loadBestiaryCreature(page, search)
    local state = "Creatures"
    if search then
        state = "Search"
    end

    if not Cyclopedia.Bestiary[state][page] then
        return
    end

    UI.ListBase.CreatureList:destroyChildren()

    for _, data in ipairs(Cyclopedia.Bestiary[state][page]) do
        Cyclopedia.CreateBestiaryCreaturesItem(data)
    end
end

function Cyclopedia.loadBestiaryCategories(data)
    Cyclopedia.Bestiary.Categories = {}
    Cyclopedia.Bestiary.Page = 1

    local maxCategoriesPerPage = 15
    Cyclopedia.Bestiary.TotalCategoriesPages = math.ceil(#data / maxCategoriesPerPage)

    if UI == nil or UI.PageValue == nil then -- I know, don't change it
        return
    end

    UI.PageValue:setText(string.format("%d / %d", Cyclopedia.Bestiary.Page, Cyclopedia.Bestiary.TotalCategoriesPages))

    local page = 1
    Cyclopedia.Bestiary.Categories[page] = {}

    for i = 1, #data do
        if (i - 1) % maxCategoriesPerPage == 0 and i > 1 then
            page = page + 1
            Cyclopedia.Bestiary.Categories[page] = {}
        end

        local category = {
            name = data[i].bestClass,
            amount = data[i].count,
            know = data[i].unlockedCount,
            AnimusMasteryBonus = data[i].AnimusMasteryBonus,
        }

        table.insert(Cyclopedia.Bestiary.Categories[page], category)
    end

    Cyclopedia.loadBestiaryCategory(Cyclopedia.Bestiary.Page)
    Cyclopedia.verifyBestiaryButtons()
end

function Cyclopedia.loadBestiaryCategory(page)
    if not Cyclopedia.Bestiary or not Cyclopedia.Bestiary.Categories then
        return
    end

    if not Cyclopedia.Bestiary.Categories[page] then
        return
    end

    UI.ListBase.CategoryList:destroyChildren()

    for _, data in ipairs(Cyclopedia.Bestiary.Categories[page]) do
        Cyclopedia.CreateBestiaryCategoryItem(data)
    end
end

function Cyclopedia.onStageChange()
    Cyclopedia.Bestiary.Page = 1

    if Cyclopedia.Bestiary.Stage == STAGES.CATEGORY then
        UI.BackPageButton:setEnabled(false)
        UI.ListBase.CategoryList:setVisible(true)
        UI.ListBase.CreatureList:setVisible(false)
        UI.ListBase.CreatureInfo:setVisible(false)
    end

    if Cyclopedia.Bestiary.Stage == STAGES.CREATURES then
        UI.BackPageButton:setEnabled(true)
        UI.ListBase.CategoryList:setVisible(false)
        UI.ListBase.CreatureList:setVisible(true)
        UI.ListBase.CreatureInfo:setVisible(false)
    end

    if Cyclopedia.Bestiary.Stage == STAGES.SEARCH then
        UI.BackPageButton:setEnabled(true)
        UI.ListBase.CategoryList:setVisible(false)
        UI.ListBase.CreatureList:setVisible(true)
        UI.ListBase.CreatureInfo:setVisible(false)
    end

    if Cyclopedia.Bestiary.Stage == STAGES.CREATURE then
        UI.BackPageButton:setEnabled(true)
        UI.ListBase.CategoryList:setVisible(false)
        UI.ListBase.CreatureList:setVisible(false)
        UI.ListBase.CreatureInfo:setVisible(false)
    end

    function UI.BackPageButton.onClick()
        local stage = Cyclopedia.Bestiary.Stage
        if stage == STAGES.CREATURE then
            Cyclopedia.Bestiary.Stage = STAGES.CREATURES
        elseif stage == STAGES.CREATURES or stage == STAGES.SEARCH then
            Cyclopedia.Bestiary.Stage = STAGES.CATEGORY
        else
            return
        end
        Cyclopedia.onStageChange()
    end

    Cyclopedia.verifyBestiaryButtons()
end

function Cyclopedia.changeBestiaryPage(prev, next)
    Cyclopedia.Bestiary.Page = tonumber(Cyclopedia.Bestiary.Page) or 1
    Cyclopedia.Bestiary.Stage = Cyclopedia.Bestiary.Stage or STAGES.CATEGORY

    if next then
        Cyclopedia.Bestiary.Page = Cyclopedia.Bestiary.Page + 1
    end

    if prev then
        Cyclopedia.Bestiary.Page = Cyclopedia.Bestiary.Page - 1
    end

    if Cyclopedia.Bestiary.Page < 1 then
        Cyclopedia.Bestiary.Page = 1
    end

    local stage = Cyclopedia.Bestiary.Stage
    if stage == STAGES.CATEGORY then
        Cyclopedia.loadBestiaryCategory(Cyclopedia.Bestiary.Page)
    elseif stage == STAGES.CREATURES then
        Cyclopedia.loadBestiaryCreature(Cyclopedia.Bestiary.Page, false)
    elseif stage == STAGES.SEARCH then
        Cyclopedia.loadBestiaryCreature(Cyclopedia.Bestiary.Page, true)
    end

    Cyclopedia.verifyBestiaryButtons()
end

function Cyclopedia.verifyBestiaryButtons()
    local function updateButtonState(button, condition)
        if condition then
            button:enable()
        else
            button:disable()
        end
    end

    local function updatePageValue(currentPage, totalPages)
        UI.PageValue:setText(string.format("%d / %d", currentPage, totalPages))
    end

    updateButtonState(UI.SearchButton, UI.SearchEdit:getText() ~= "")

    local stage = Cyclopedia.Bestiary.Stage
    local totalSearchPages = Cyclopedia.Bestiary.TotalSearchPages or 1
    local page = Cyclopedia.Bestiary.Page or 1
    if stage == STAGES.SEARCH and totalSearchPages then
        local totalPages = totalSearchPages
        updateButtonState(UI.PrevPageButton, page > 1)
        updateButtonState(UI.NextPageButton, page < totalPages)
        updatePageValue(page, totalPages)
        return
    end

    if stage == STAGES.CREATURE then
        UI.PrevPageButton:disable()
        UI.NextPageButton:disable()
        updatePageValue(1, 1)
        return
    end

    local totalCategoriesPages = Cyclopedia.Bestiary.TotalCategoriesPages or 1
    local totalCreaturesPages = Cyclopedia.Bestiary.TotalCreaturesPages or 1
    if stage == STAGES.CATEGORY and totalCategoriesPages or stage == STAGES.CREATURES and totalCreaturesPages then
        local totalPages = stage == STAGES.CATEGORY and totalCategoriesPages or totalCreaturesPages
        updateButtonState(UI.PrevPageButton, page > 1)
        updateButtonState(UI.NextPageButton, page < totalPages)
        updatePageValue(page, totalPages)
    end
end

--[[
===================================================
=                     Tracker                     =
===================================================
]]

function Cyclopedia.refreshBestiaryTracker()
    -- First check if we have a character
    local char = g_game.getCharacterName()
    if not char or #char == 0 then
        return
    end
    
    -- Ensure tracker data is initialized
    if not Cyclopedia.storedTrackerData then
        Cyclopedia.initializeTrackerData()
    end
    
    -- Always try to load cached data for immediate display
    local cachedData = Cyclopedia.loadTrackerData("bestiary")
    if cachedData and #cachedData > 0 then
        Cyclopedia.storedTrackerData = cachedData
        -- Immediately populate if we have tracker window
        if trackerMiniWindow then
            Cyclopedia.onParseCyclopediaTracker(0, Cyclopedia.storedTrackerData)
        end
    end
    
    -- Always request fresh data from server
    if g_game.requestBestiaryTracker then
        g_game.requestBestiaryTracker()
    else
        g_game.requestBestiary()
    end
end

function Cyclopedia.updateBestiaryTrackerLocal(raceId, enabled)
    local id = tonumber(raceId) or 0
    if id <= 0 then
        return
    end

    Cyclopedia.initializeTrackerData()
    Cyclopedia.storedTrackerData = Cyclopedia.storedTrackerData or {}

    local currentData = Cyclopedia.BestiaryCreatureCache and Cyclopedia.BestiaryCreatureCache[id] or {}
    local entryIndex = nil
    for i, entry in ipairs(Cyclopedia.storedTrackerData) do
        if tonumber(entry[1]) == id then
            entryIndex = i
            break
        end
    end

    if enabled then
        local trackerEntry = {
            id,
            tonumber(currentData.killCounter) or 0,
            tonumber(currentData.thirdDifficulty) or 25,
            tonumber(currentData.secondUnlock) or 100,
            tonumber(currentData.lastProgressKillCount) or 250,
        }

        if entryIndex then
            Cyclopedia.storedTrackerData[entryIndex] = trackerEntry
        else
            table.insert(Cyclopedia.storedTrackerData, trackerEntry)
        end
    elseif entryIndex then
        table.remove(Cyclopedia.storedTrackerData, entryIndex)
    end

    storedRaceIDs = {}
    for _, entry in ipairs(Cyclopedia.storedTrackerData) do
        table.insert(storedRaceIDs, tonumber(entry[1]) or 0)
    end

    Cyclopedia.saveTrackerData("bestiary", Cyclopedia.storedTrackerData)

    if trackerMiniWindow and trackerMiniWindow.contentsPanel then
        Cyclopedia.onParseCyclopediaTracker(0, Cyclopedia.storedTrackerData)
    end
end

function Cyclopedia.refreshBosstiaryTracker()
    -- First check if we have a character
    local char = g_game.getCharacterName()
    if not char or #char == 0 then
        return
    end
    
    -- Ensure tracker data is initialized
    if not Cyclopedia.storedBosstiaryTrackerData then
        Cyclopedia.initializeTrackerData()
    end
    
    -- Always try to load cached data for immediate display
    local cachedData = Cyclopedia.loadTrackerData("bosstiary")
    if cachedData and #cachedData > 0 then
        Cyclopedia.storedBosstiaryTrackerData = cachedData
        -- Immediately populate if we have tracker window
        if trackerMiniWindowBosstiary then
            Cyclopedia.onParseCyclopediaTracker(1, Cyclopedia.storedBosstiaryTrackerData)
        end
    end
    
    -- Always request fresh data from server
    g_game.requestBestiary()
end

function Cyclopedia.refreshAllVisibleTrackers()
    -- Refresh bestiary tracker if it's visible
    if trackerMiniWindow and trackerMiniWindow:isVisible() then
        Cyclopedia.refreshBestiaryTracker()
    end
    
    -- Refresh bosstiary tracker if it's visible
    if trackerMiniWindowBosstiary and trackerMiniWindowBosstiary:isVisible() then
        Cyclopedia.refreshBosstiaryTracker()
    end

    if trackerMiniWindowTask and trackerMiniWindowTask:isVisible() then
        Cyclopedia.refreshTaskTracker()
    end
end

function Cyclopedia.refreshTaskTracker()
    local char = g_game.getCharacterName()
    if not char or #char == 0 then
        return
    end

    Cyclopedia.initializeTrackerData()

    local cachedData = Cyclopedia.loadTrackerData("tasks")
    if cachedData and #cachedData > 0 then
        Cyclopedia.storedTaskTrackerData = cachedData
        if trackerMiniWindowTask then
            Cyclopedia.onParseTaskTracker(Cyclopedia.storedTaskTrackerData)
        end
    end

    if g_game.requestTaskTracker then
        g_game.requestTaskTracker()
    end
end

-- Force refresh function that can be called manually to reload data
function Cyclopedia.forceRefreshTrackers()
    local char = g_game.getCharacterName()
    if not char or #char == 0 then
        print("Debug: No character name available")
        return
    end
    
    print("Debug: Force refreshing trackers for character: " .. char)
    
    -- Clear stored data to force reload
    Cyclopedia.storedTrackerData = {}
    Cyclopedia.storedBosstiaryTrackerData = {}
    
    -- Initialize and load fresh data
    Cyclopedia.initializeTrackerData()
    
    -- Request fresh data from server
    g_game.requestBestiary()
    
    -- Refresh all visible trackers
    scheduleEvent(function()
        Cyclopedia.refreshAllVisibleTrackers()
    end, 100)
end

-- Debug function to check tracker state
function Cyclopedia.debugTrackerState()
    local char = g_game.getCharacterName()
    print("=== Tracker Debug Info ===")
    print("Character: " .. (char or "nil"))
    print("Bestiary data count: " .. (Cyclopedia.storedTrackerData and #Cyclopedia.storedTrackerData or "nil"))
    print("Bosstiary data count: " .. (Cyclopedia.storedBosstiaryTrackerData and #Cyclopedia.storedBosstiaryTrackerData or "nil"))
    print("Bestiary window visible: " .. tostring(trackerMiniWindow and trackerMiniWindow:isVisible()))
    print("Bosstiary window visible: " .. tostring(trackerMiniWindowBosstiary and trackerMiniWindowBosstiary:isVisible()))
    if trackerMiniWindow then
        print("Bestiary panel children: " .. trackerMiniWindow.contentsPanel:getChildCount())
    end
    if trackerMiniWindowBosstiary then
        print("Bosstiary panel children: " .. trackerMiniWindowBosstiary.contentsPanel:getChildCount())
    end
    print("========================")
end

function Cyclopedia.toggleBestiaryTracker()
    if not trackerMiniWindow then
        return
    end

    local buttonOn = trackerButton and trackerButton.isOn and trackerButton:isOn() or trackerMiniWindow:isVisible()
    if buttonOn then
        cancelBestiaryTrackerLiveRefresh()
        trackerMiniWindow:close()
        if trackerButton and trackerButton.setOn then
            trackerButton:setOn(false)
        end
        if ButtonBestiary and ButtonBestiary.setOn then
            ButtonBestiary:setOn(false)
        end
    else
        if not trackerMiniWindow:getParent() then
            local panel = modules.game_interface.findContentPanelAvailable(trackerMiniWindow,
            trackerMiniWindow:getMinimumHeight())
            if not panel then
                return
            end
            panel:addChild(trackerMiniWindow)
        end
        
        -- Ensure data is loaded before opening
        local char = g_game.getCharacterName()
        if char and #char > 0 then
            Cyclopedia.initializeTrackerData()
            -- Try to load immediately if we have cached data
            if Cyclopedia.storedTrackerData and #Cyclopedia.storedTrackerData > 0 then
                Cyclopedia.onParseCyclopediaTracker(0, Cyclopedia.storedTrackerData)
            end
        end
        
        trackerMiniWindow:open()
        scheduleBestiaryTrackerLiveRefresh()
        if ButtonBestiary and ButtonBestiary.setOn then
            ButtonBestiary:setOn(true)
        end
        
        -- Multiple fallback attempts
        scheduleEvent(function()
            if trackerMiniWindow:isVisible() then
                if trackerMiniWindow.contentsPanel:getChildCount() == 0 then
                    Cyclopedia.refreshBestiaryTracker()
                end
                
                -- Another fallback check
                scheduleEvent(function()
                    if trackerMiniWindow:isVisible() and trackerMiniWindow.contentsPanel:getChildCount() == 0 then
                        -- Force request fresh data if still empty
                        g_game.requestBestiary()
                        scheduleEvent(function()
                            Cyclopedia.refreshBestiaryTracker()
                        end, 1000)
                    end
                end, 500)
            end
        end, 100)
    end
end

function Cyclopedia.toggleBosstiaryTracker()
    if not trackerMiniWindowBosstiary then
        return
    end

    local buttonOn = trackerButtonBosstiary and trackerButtonBosstiary.isOn and trackerButtonBosstiary:isOn() or trackerMiniWindowBosstiary:isVisible()
    if buttonOn then
        trackerMiniWindowBosstiary:close()
        if trackerButtonBosstiary and trackerButtonBosstiary.setOn then
            trackerButtonBosstiary:setOn(false)
        end
    else
        if not trackerMiniWindowBosstiary:getParent() then
            local panel = modules.game_interface.findContentPanelAvailable(trackerMiniWindowBosstiary,
            trackerMiniWindowBosstiary:getMinimumHeight())
            if not panel then
                return
            end
            panel:addChild(trackerMiniWindowBosstiary)
        end
        
        -- Ensure data is loaded before opening
        local char = g_game.getCharacterName()
        if char and #char > 0 then
            Cyclopedia.initializeTrackerData()
            -- Try to load immediately if we have cached data
            if Cyclopedia.storedBosstiaryTrackerData and #Cyclopedia.storedBosstiaryTrackerData > 0 then
                Cyclopedia.onParseCyclopediaTracker(1, Cyclopedia.storedBosstiaryTrackerData)
            end
        end
        
        trackerMiniWindowBosstiary:open()
        
        -- Multiple fallback attempts
        scheduleEvent(function()
            if trackerMiniWindowBosstiary:isVisible() then
                if trackerMiniWindowBosstiary.contentsPanel:getChildCount() == 0 then
                    Cyclopedia.refreshBosstiaryTracker()
                end
                
                -- Another fallback check
                scheduleEvent(function()
                    if trackerMiniWindowBosstiary:isVisible() and trackerMiniWindowBosstiary.contentsPanel:getChildCount() == 0 then
                        -- Force request fresh data if still empty
                        g_game.requestBestiary()
                        scheduleEvent(function()
                            Cyclopedia.refreshBosstiaryTracker()
                        end, 1000)
                    end
                end, 500)
            end
        end, 100)
    end
end

function Cyclopedia.toggleTaskTracker()
    if not trackerMiniWindowTask then
        return
    end

    if trackerMiniWindowTask:isVisible() then
        trackerMiniWindowTask:close()
        return
    end

    if not trackerMiniWindowTask:getParent() then
        local panel = modules.game_interface.findContentPanelAvailable(trackerMiniWindowTask,
            trackerMiniWindowTask:getMinimumHeight())
        if not panel then
            return
        end
        panel:addChild(trackerMiniWindowTask)
    end

    local char = g_game.getCharacterName()
    if char and #char > 0 then
        Cyclopedia.initializeTrackerData()
        if Cyclopedia.storedTaskTrackerData and #Cyclopedia.storedTaskTrackerData > 0 then
            Cyclopedia.onParseTaskTracker(Cyclopedia.storedTaskTrackerData)
        end
    end

    trackerMiniWindowTask:open()
    scheduleBestiaryTrackerLiveRefresh()

    scheduleEvent(function()
        if trackerMiniWindowTask:isVisible() and trackerMiniWindowTask.contentsPanel:getChildCount() == 0 then
            Cyclopedia.refreshTaskTracker()
        end
    end, 100)
end

function Cyclopedia.onTrackerClose(temp)
    cancelBestiaryTrackerLiveRefresh()
    -- Button states are now handled by onClose callbacks
    -- This function can be removed or kept for backwards compatibility
end

function Cyclopedia.onBestiaryTrackerWindowOpened()
    scheduleBestiaryTrackerLiveRefresh()
end

function Cyclopedia.onBestiaryTrackerWindowClosed()
    cancelBestiaryTrackerLiveRefresh()
end

function Cyclopedia.setBarPercent(widget, percent)
    if percent > 92 then
        widget.killsBar:setBackgroundColor("#00BC00")
    elseif percent > 60 then
        widget.killsBar:setBackgroundColor("#50A150")
    elseif percent > 30 then
        widget.killsBar:setBackgroundColor("#A1A100")
    elseif percent > 8 then
        widget.killsBar:setBackgroundColor("#BF0A0A")
    elseif percent > 3 then
        widget.killsBar:setBackgroundColor("#910F0F")
    else
        widget.killsBar:setBackgroundColor("#850C0C")
    end

    widget.killsBar:setPercent(percent)
end

function Cyclopedia.onParseCyclopediaTracker(trackerType, data)
    if not data then
        return
    end

    local isBoss = trackerType == 1
    -- Store the original data for re-sorting
    if isBoss then
        Cyclopedia.storedBosstiaryTrackerData = data
        -- Save to persistent storage
        Cyclopedia.saveTrackerData("bosstiary", data)
    else
        Cyclopedia.storedTrackerData = data
        -- Save to persistent storage
        Cyclopedia.saveTrackerData("bestiary", data)
        
        -- Clear and repopulate storedRaceIDs only for bestiary tracker
        storedRaceIDs = {}
    end

    local window = isBoss and trackerMiniWindowBosstiary or trackerMiniWindow
    if not window or not window.contentsPanel then
        return
    end

    window.contentsPanel:destroyChildren()

    -- Sort the data for both trackers
    local trackerTypeStr = isBoss and "bosstiary" or "bestiary"
    data = Cyclopedia.sortTrackerData(data, trackerTypeStr)

    for _, entry in ipairs(data) do
        local raceId, kills, uno, dos, maxKills = unpack(entry)
        
        -- Only add to storedRaceIDs for bestiary tracker
        if not isBoss then
            table.insert(storedRaceIDs, raceId)
        end
        
        local raceData = g_things.getRaceData(raceId)
        local name = (raceData and raceData.name) or "Unknown"

        local widget = g_ui.createWidget("TrackerButton", window.contentsPanel)
        widget:setId(raceId)
        widget.creature:setOutfit((raceData and raceData.outfit) or { type = 0 })
        widget.label:setText(name:len() > 12 and name:sub(1, 9) .. "..." or name)
        widget.kills:setText(kills .. "/" .. maxKills)
        widget.onMouseRelease = onTrackerClick

        Cyclopedia.SetBestiaryProgress(54,widget.killsBar2, widget.ProgressBack33, widget.ProgressBack55, kills, uno, dos, maxKills)
    end
end

function Cyclopedia.onParseTaskTracker(data)
    if not data then
        return
    end

    Cyclopedia.storedTaskTrackerData = data
    Cyclopedia.saveTrackerData("tasks", data)

    if not trackerMiniWindowTask or not trackerMiniWindowTask.contentsPanel then
        return
    end

    trackerMiniWindowTask.contentsPanel:destroyChildren()
    local sorted = Cyclopedia.sortTrackerData(data, "tasks")

    local function buildTaskCreaturesTooltipLines(creatures, fallbackName)
        local lines = {}
        local normalized = {}

        for _, creature in ipairs(creatures or {}) do
            local text = tostring(creature or "")
            text = text:gsub("^%s+", ""):gsub("%s+$", "")
            if text ~= "" then
                table.insert(normalized, text)
            end
        end

        if #normalized == 0 then
            table.insert(normalized, fallbackName or "Unknown creature")
        end

        local maxVisible = 3
        local visibleCount = math.min(#normalized, maxVisible)
        for i = 1, visibleCount do
            table.insert(lines, "- " .. normalized[i])
        end

        if #normalized > maxVisible then
            table.insert(lines, "+" .. (#normalized - maxVisible) .. " more")
        end

        return table.concat(lines, "\n")
    end

    for _, entry in ipairs(sorted) do
        local taskId = tonumber(entry.taskId) or 0
        local raceId = tonumber(entry.raceId) or 0
        local progress = tonumber(entry.progress) or 0
        local firstGoal = tonumber(entry.firstGoal) or 1
        local secondGoal = tonumber(entry.secondGoal) or 2
        local required = tonumber(entry.required) or 3
        local taskName = tostring(entry.taskName or "Task")
        local creatureName = tostring(entry.creatureName or "Unknown creature")
        local outfitType = tonumber(entry.outfitType) or 0
        local creatures = entry.creatures or {}

        local raceData = raceId > 0 and g_things.getRaceData(raceId) or nil
        if (not raceData or not raceData.outfit or (tonumber(raceData.outfit.type) or 0) <= 0) and creatureName ~= "" and g_things.getRacesByName then
            local races = g_things.getRacesByName(creatureName)
            if races and races[1] then
                local lookupRaceId = races[1].id or races[1].raceId
                if lookupRaceId then
                    local lookedUp = g_things.getRaceData(lookupRaceId)
                    if lookedUp then
                        raceData = lookedUp
                    end
                end
            end
        end
        local widget = g_ui.createWidget("TrackerButton", trackerMiniWindowTask.contentsPanel)
        widget:setId(taskId)
        local raceOutfitType = raceData and raceData.outfit and tonumber(raceData.outfit.type) or 0
        if raceData and raceOutfitType and raceOutfitType > 0 then
            widget.creature:setOutfit(raceData.outfit)
            if raceData.name and raceData.name ~= "" and raceData.name ~= "Unknown" then
                creatureName = raceData.name
            end
        else
            widget.creature:setOutfit({
                type = outfitType,
                head = 0,
                body = 0,
                legs = 0,
                feet = 0,
                addons = 0,
            })
        end
        widget.label:setText(taskName:len() > 18 and taskName:sub(1, 15) .. "..." or taskName)
        widget.kills:setText(progress .. "/" .. required)

        local creaturesBlock = buildTaskCreaturesTooltipLines(creatures, creatureName)
        widget:setTooltip(string.format("%s\nCreatures:\n%s\nProgress: %d/%d", taskName, creaturesBlock, progress, required))

        Cyclopedia.SetBestiaryProgress(54, widget.killsBar2, widget.ProgressBack33, widget.ProgressBack55,
            progress, firstGoal, secondGoal, required)
    end
end

local BESTIATYTRACKER_FILTERS = {
    ["sortByName"] = false,
    ["ShortByPercentage"] = false,
    ["sortByKills"] = true,
    ["sortByAscending"] = true,
    ["sortByDescending"] = false
}

local BOSSTIARYTRACKER_FILTERS = {
    ["sortByName"] = false,
    ["ShortByPercentage"] = false,
    ["sortByKills"] = true,
    ["sortByAscending"] = true,
    ["sortByDescending"] = false
}

local TASKTRACKER_FILTERS = {
    ["sortByName"] = false,
    ["ShortByPercentage"] = false,
    ["sortByKills"] = true,
    ["sortByAscending"] = true,
    ["sortByDescending"] = false
}

function Cyclopedia.loadTrackerFilters(trackerType)
    local char = g_game.getCharacterName()
    if not char or #char == 0 then
        local defaultFilters = BESTIATYTRACKER_FILTERS
        if trackerType == "bosstiary" then
            defaultFilters = BOSSTIARYTRACKER_FILTERS
        elseif trackerType == "tasks" then
            defaultFilters = TASKTRACKER_FILTERS
        end
        return defaultFilters
    end
    
    local filterKey = "bestiaryTracker"
    if trackerType == "bosstiary" then
        filterKey = "bosstiaryTracker"
    elseif trackerType == "tasks" then
        filterKey = "taskTracker"
    end
    local charFilterKey = string.format("%s_%s", filterKey, char)
    local defaultFilters = BESTIATYTRACKER_FILTERS
    if trackerType == "bosstiary" then
        defaultFilters = BOSSTIARYTRACKER_FILTERS
    elseif trackerType == "tasks" then
        defaultFilters = TASKTRACKER_FILTERS
    end
    
    local settings = g_settings.getNode(charFilterKey)
    if not settings or not settings['filters'] then
        -- Save default filters for first time use
        g_settings.mergeNode(charFilterKey, {
            ['filters'] = defaultFilters,
            ['character'] = char
        })
        return defaultFilters
    end
    return settings['filters']
end

function Cyclopedia.saveTrackerFilters(trackerType)
    local char = g_game.getCharacterName()
    if not char or #char == 0 then
        return
    end
    
    local filterKey = "bestiaryTracker"
    if trackerType == "bosstiary" then
        filterKey = "bosstiaryTracker"
    elseif trackerType == "tasks" then
        filterKey = "taskTracker"
    end
    local charFilterKey = string.format("%s_%s", filterKey, char)
    
    g_settings.mergeNode(charFilterKey, {
        ['filters'] = Cyclopedia.loadTrackerFilters(trackerType),
        ['character'] = char
    })
end

-- New functions to save/load tracker data (character-specific)
function Cyclopedia.saveTrackerData(trackerType, data)
    local char = g_game.getCharacterName()
    if not char or #char == 0 then
        return
    end
    
    local dataKey = "bestiaryTrackerData"
    if trackerType == "bosstiary" then
        dataKey = "bosstiaryTrackerData"
    elseif trackerType == "tasks" then
        dataKey = "taskTrackerData"
    end
    local charDataKey = string.format("%s_%s", dataKey, char)
    
    g_settings.mergeNode(charDataKey, {
        ['data'] = data,
        ['timestamp'] = os.time(),
        ['character'] = char
    })
end

function Cyclopedia.loadTrackerData(trackerType)
    local char = g_game.getCharacterName()
    if not char or #char == 0 then
        return nil
    end
    
    local dataKey = "bestiaryTrackerData"
    if trackerType == "bosstiary" then
        dataKey = "bosstiaryTrackerData"
    elseif trackerType == "tasks" then
        dataKey = "taskTrackerData"
    end
    local charDataKey = string.format("%s_%s", dataKey, char)
    
    local settings = g_settings.getNode(charDataKey)
    if settings and settings['data'] and settings['character'] == char then
        -- Check if data is not too old (older than 1 hour = stale)
        local timestamp = settings['timestamp'] or 0
        local currentTime = os.time()
        if currentTime - timestamp < 3600 then -- 1 hour in seconds
            return settings['data']
        end
    end
    return nil
end

function Cyclopedia.initializeTrackerData()
    local char = g_game.getCharacterName()
    if not char or #char == 0 then
        -- Character name not available yet, skip initialization
        return
    end
    
    -- Only initialize if we don't already have data loaded for this character
    if not Cyclopedia.storedTrackerData then
        Cyclopedia.storedTrackerData = {}
    end
    if not Cyclopedia.storedBosstiaryTrackerData then
        Cyclopedia.storedBosstiaryTrackerData = {}
    end
    if not Cyclopedia.storedTaskTrackerData then
        Cyclopedia.storedTaskTrackerData = {}
    end
    
    -- Load cached bestiary tracker data for current character (only if not already loaded)
    if #Cyclopedia.storedTrackerData == 0 then
        local cachedBestiaryData = Cyclopedia.loadTrackerData("bestiary")
        if cachedBestiaryData and #cachedBestiaryData > 0 then
            Cyclopedia.storedTrackerData = cachedBestiaryData
        end
    end
    
    -- Load cached bosstiary tracker data for current character (only if not already loaded)
    if #Cyclopedia.storedBosstiaryTrackerData == 0 then
        local cachedBosstiaryData = Cyclopedia.loadTrackerData("bosstiary")
        if cachedBosstiaryData and #cachedBosstiaryData > 0 then
            Cyclopedia.storedBosstiaryTrackerData = cachedBosstiaryData
        end
    end

    if #Cyclopedia.storedTaskTrackerData == 0 then
        local cachedTaskData = Cyclopedia.loadTrackerData("tasks")
        if cachedTaskData and #cachedTaskData > 0 then
            Cyclopedia.storedTaskTrackerData = cachedTaskData
        end
    end
end

-- Function to ensure storedRaceIDs is populated from cached tracker data
function Cyclopedia.ensureStoredRaceIDsPopulated()
    -- If storedRaceIDs is already populated, don't need to do anything
    if storedRaceIDs and #storedRaceIDs > 0 then
        return
    end
    
    -- Initialize tracker data if not already done
    Cyclopedia.initializeTrackerData()
    
    -- Populate storedRaceIDs from cached bestiary tracker data
    if Cyclopedia.storedTrackerData and #Cyclopedia.storedTrackerData > 0 then
        storedRaceIDs = {}
        for _, entry in ipairs(Cyclopedia.storedTrackerData) do
            local raceId = entry[1] -- First element is the race ID
            table.insert(storedRaceIDs, raceId)
        end
    end
end

-- Function to clear tracker data when character changes
function Cyclopedia.clearTrackerDataForCharacterChange()
    -- Clear in-memory data
    Cyclopedia.storedTrackerData = {}
    Cyclopedia.storedBosstiaryTrackerData = {}
    Cyclopedia.storedTaskTrackerData = {}
    
    -- Clear visual tracker displays
    if trackerMiniWindow and trackerMiniWindow.contentsPanel then
        trackerMiniWindow.contentsPanel:destroyChildren()
    end
    if trackerMiniWindowBosstiary and trackerMiniWindowBosstiary.contentsPanel then
        trackerMiniWindowBosstiary.contentsPanel:destroyChildren()
    end
    if trackerMiniWindowTask and trackerMiniWindowTask.contentsPanel then
        trackerMiniWindowTask.contentsPanel:destroyChildren()
    end
    
    -- Clear stored race IDs
    storedRaceIDs = {}
end

-- Function to clean up old character data (optional maintenance function)
function Cyclopedia.cleanupOldTrackerData(daysOld)
    daysOld = daysOld or 30 -- Default: clean data older than 30 days
    local cutoffTime = os.time() - (daysOld * 24 * 60 * 60)
    
    -- Get all settings and find tracker-related keys
    local allSettings = g_settings.getSettings()
    for key, value in pairs(allSettings) do
        if string.match(key, "^bestiaryTrackerData_") or 
           string.match(key, "^bosstiaryTrackerData_") or
              string.match(key, "^taskTrackerData_") or
           string.match(key, "^bestiaryTracker_") or
              string.match(key, "^bosstiaryTracker_") or
              string.match(key, "^taskTracker_") then
            
            if value.timestamp and value.timestamp < cutoffTime then
                g_settings.remove(key)
            end
        end
    end
end

-- New function to populate visible trackers with cached data
function Cyclopedia.populateVisibleTrackersWithCachedData()
    -- Check if we have a valid character
    local char = g_game.getCharacterName()
    if not char or #char == 0 then
        return
    end
    
    -- Ensure tracker data is initialized for this character (but don't force reload if data exists)
    Cyclopedia.initializeTrackerData()
    
    -- Populate bestiary tracker if it's visible and has cached data
    if trackerMiniWindow and trackerMiniWindow:isVisible() then
        if Cyclopedia.storedTrackerData and #Cyclopedia.storedTrackerData > 0 then
            Cyclopedia.onParseCyclopediaTracker(0, Cyclopedia.storedTrackerData)
        else
            -- Try to load cached data and populate
            Cyclopedia.refreshBestiaryTracker()
        end
    end
    
    -- Populate bosstiary tracker if it's visible and has cached data
    if trackerMiniWindowBosstiary and trackerMiniWindowBosstiary:isVisible() then
        if Cyclopedia.storedBosstiaryTrackerData and #Cyclopedia.storedBosstiaryTrackerData > 0 then
            Cyclopedia.onParseCyclopediaTracker(1, Cyclopedia.storedBosstiaryTrackerData)
        else
            -- Try to load cached data and populate
            Cyclopedia.refreshBosstiaryTracker()
        end
    end

    if trackerMiniWindowTask and trackerMiniWindowTask:isVisible() then
        if Cyclopedia.storedTaskTrackerData and #Cyclopedia.storedTaskTrackerData > 0 then
            Cyclopedia.onParseTaskTracker(Cyclopedia.storedTaskTrackerData)
        else
            Cyclopedia.refreshTaskTracker()
        end
    end
end

function Cyclopedia.getTrackerFilter(trackerType, filter)
    return Cyclopedia.loadTrackerFilters(trackerType)[filter] or false
end

function Cyclopedia.setTrackerFilter(trackerType, filter, value)
    local char = g_game.getCharacterName()
    if not char or #char == 0 then
        return
    end
    
    local filterKey = trackerType == "bosstiary" and "bosstiaryTracker" or "bestiaryTracker"
    local charFilterKey = string.format("%s_%s", filterKey, char)
    local filters = Cyclopedia.loadTrackerFilters(trackerType)
    
    -- Handle mutual exclusion for sorting methods
    if filter == "sortByName" or filter == "ShortByPercentage" or filter == "sortByKills" then
        filters["sortByName"] = false
        filters["ShortByPercentage"] = false
        filters["sortByKills"] = false
        filters[filter] = true
    -- Handle mutual exclusion for sorting direction
    elseif filter == "sortByAscending" or filter == "sortByDescending" then
        filters["sortByAscending"] = false
        filters["sortByDescending"] = false
        filters[filter] = true
    else
        filters[filter] = value
    end
    
    g_settings.mergeNode(charFilterKey, {
        ['filters'] = filters,
        ['character'] = char
    })
    
    -- Refresh the tracker display
    Cyclopedia.refreshTracker(trackerType)
end

function Cyclopedia.refreshTracker(trackerType)
    if trackerType == "bosstiary" then
        if trackerMiniWindowBosstiary and Cyclopedia.storedBosstiaryTrackerData then
            Cyclopedia.onParseCyclopediaTracker(1, Cyclopedia.storedBosstiaryTrackerData)
        end
    elseif trackerType == "tasks" then
        if trackerMiniWindowTask and Cyclopedia.storedTaskTrackerData then
            Cyclopedia.onParseTaskTracker(Cyclopedia.storedTaskTrackerData)
        end
    else
        if trackerMiniWindow and Cyclopedia.storedTrackerData then
            Cyclopedia.onParseCyclopediaTracker(0, Cyclopedia.storedTrackerData)
        end
    end
end

function Cyclopedia.sortTrackerData(data, trackerType)
    local filters = Cyclopedia.loadTrackerFilters(trackerType)
    local isDescending = filters.sortByDescending
    
    -- Create a copy of the data to avoid modifying the original
    local sortedData = {}
    for i, v in ipairs(data) do
        sortedData[i] = v
    end
    
    if trackerType == "tasks" then
        if filters.sortByName then
            table.sort(sortedData, function(a, b)
                local nameA = tostring(a.taskName or "task"):lower()
                local nameB = tostring(b.taskName or "task"):lower()
                if isDescending then
                    return nameA > nameB
                else
                    return nameA < nameB
                end
            end)
        elseif filters.ShortByPercentage then
            table.sort(sortedData, function(a, b)
                local requiredA = tonumber(a.required) or 1
                local requiredB = tonumber(b.required) or 1
                local percentA = requiredA > 0 and ((tonumber(a.progress) or 0) / requiredA * 100) or 0
                local percentB = requiredB > 0 and ((tonumber(b.progress) or 0) / requiredB * 100) or 0
                if isDescending then
                    return percentA > percentB
                else
                    return percentA < percentB
                end
            end)
        elseif filters.sortByKills then
            table.sort(sortedData, function(a, b)
                local remainingA = (tonumber(a.required) or 0) - (tonumber(a.progress) or 0)
                local remainingB = (tonumber(b.required) or 0) - (tonumber(b.progress) or 0)
                if isDescending then
                    return remainingA > remainingB
                else
                    return remainingA < remainingB
                end
            end)
        end
        return sortedData
    end

    if filters.sortByName then
        table.sort(sortedData, function(a, b)
            local raceA = g_things.getRaceData(a[1])
            local raceB = g_things.getRaceData(b[1])
            local nameA = ((raceA and raceA.name) or "unknown"):lower()
            local nameB = ((raceB and raceB.name) or "unknown"):lower()
            if isDescending then
                return nameA > nameB
            else
                return nameA < nameB
            end
        end)
    elseif filters.ShortByPercentage then
        table.sort(sortedData, function(a, b)
            local raceIdA, killsA, _, _, maxKillsA = unpack(a)
            local raceIdB, killsB, _, _, maxKillsB = unpack(b)
            local percentA = maxKillsA > 0 and (killsA / maxKillsA * 100) or 0
            local percentB = maxKillsB > 0 and (killsB / maxKillsB * 100) or 0
            if isDescending then
                return percentA > percentB
            else
                return percentA < percentB
            end
        end)
    elseif filters.sortByKills then
        table.sort(sortedData, function(a, b)
            local remainingA = a[5] - a[2] -- maxKills - kills
            local remainingB = b[5] - b[2] -- maxKills - kills
            if isDescending then
                return remainingA > remainingB
            else
                return remainingA < remainingB
            end
        end)
    end
    
    return sortedData
end

-- Shared function to create tracker context menu
function Cyclopedia.createTrackerContextMenu(trackerType, mousePos)
    local menu = g_ui.createWidget('bestiaryTrackerMenu')
    menu:setGameMenu(true)
    local shortCreature = UIRadioGroup.create()
    local shortAlphabets = UIRadioGroup.create()

    for i, choice in ipairs(menu:getChildren()) do
        if i >= 1 and i <= 3 then
            shortCreature:addWidget(choice)
        elseif i == 5 or i == 6 then
            shortAlphabets:addWidget(choice)
        end
    end

    -- Set default selections
    local filters = Cyclopedia.loadTrackerFilters(trackerType)
    
    -- Set sorting method (default: sortByKills)
    if filters.sortByName then
        menu:getChildById('sortByName'):setChecked(true)
    elseif filters.ShortByPercentage then
        menu:getChildById('ShortByPercentage'):setChecked(true)
    elseif filters.sortByKills then
        menu:getChildById('sortByKills'):setChecked(true)
    else
        menu:getChildById('sortByKills'):setChecked(true)
    end
    
    -- Set sorting direction (default: ascending)
    if filters.sortByDescending then
        menu:getChildById('sortByDescending'):setChecked(true)
    else
        menu:getChildById('sortByAscending'):setChecked(true)
    end

    -- Add click handlers for menu options
    menu:getChildById('sortByName').onClick = function() Cyclopedia.setTrackerFilter(trackerType, 'sortByName', true); menu:destroy() end
    menu:getChildById('ShortByPercentage').onClick = function() Cyclopedia.setTrackerFilter(trackerType, 'ShortByPercentage', true); menu:destroy() end
    menu:getChildById('sortByKills').onClick = function() Cyclopedia.setTrackerFilter(trackerType, 'sortByKills', true); menu:destroy() end
    menu:getChildById('sortByAscending').onClick = function() Cyclopedia.setTrackerFilter(trackerType, 'sortByAscending', true); menu:destroy() end
    menu:getChildById('sortByDescending').onClick = function() Cyclopedia.setTrackerFilter(trackerType, 'sortByDescending', true); menu:destroy() end

    menu:display(mousePos)
    return true
end

-- Legacy functions for backwards compatibility
function Cyclopedia.loadBestiaryTrackerFilters()
    return Cyclopedia.loadTrackerFilters("bestiary")
end

function Cyclopedia.saveBestiaryTrackerFilters()
    return Cyclopedia.saveTrackerFilters("bestiary")
end

function Cyclopedia.getBestiaryTrackerFilter(filter)
    return Cyclopedia.getTrackerFilter("bestiary", filter)
end

function Cyclopedia.setBestiaryTrackerFilter(filter, value)
    return Cyclopedia.setTrackerFilter("bestiary", filter, value)
end

-- trackerMiniWindow.contentsPanel:moveChildToIndex(battleButton, index)
-- TODO Add sort by name, kills, percentage, ascending, descending
function test(index)
    trackerMiniWindow.contentsPanel:moveChildToIndex(trackerMiniWindow.contentsPanel:getLastChild(), index)
end

function onTrackerClick(widget, mousePosition, mouseButton)
    local taskId = tonumber(widget:getId())
    local menu = g_ui.createWidget("PopupMenu")

    menu:setGameMenu(true)
    menu:addOption("Stop Tracking " .. widget.label:getText(), function()
        g_game.sendStatusTrackerBestiary(taskId, false)
    end)
    menu:display(menuPosition)

    return true
end

function onAddLootClick(widget, mousePosition, mouseButton)
    local itemId = widget:getItemId()
    local quickLoot = modules.game_quickloot.QuickLoot
    local lootFilterValue = quickLoot.data.filter
    local menu = g_ui.createWidget("PopupMenu")

    menu:setGameMenu(true)

    if not quickLoot.lootExists(itemId, lootFilterValue) then
        menu:addOption("Add to Loot List",
        function()
            quickLoot.addLootList(itemId, lootFilterValue)
        end)
    else
        menu:addOption("Remove from Loot List", 
        function() 
            quickLoot.removeLootList(itemId, lootFilterValue)
        end)
    end

    menu:display(menuPosition)

    return true
end
