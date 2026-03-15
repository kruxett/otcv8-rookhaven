-- Fallback constants not present in otcv8-rookhaven's gamelib
if not ResourceTypes then
    ResourceTypes = {
        BANK_BALANCE = 0, GOLD_EQUIPPED = 1, CURRENCY_CUSTOM_EQUIPPED = 2,
        PREY_WILDCARDS = 10, DAILYREWARD_STREAK = 20, DAILYREWARD_JOKERS = 21,
        CHARM = 30, MINOR_CHARM = 31, MAX_CHARM = 32, MAX_MINOR_CHARM = 33,
        TASK_HUNTING = 50, FORGE_DUST = 70, FORGE_SLIVER = 71, FORGE_CORES = 72,
        LESSER_GEMS = 81, REGULAR_GEMS = 82, GREATER_GEMS = 83,
        LESSER_FRAGMENTS = 84, GREATER_FRAGMENTS = 85, WHEEL_OF_DESTINY = 86,
        COIN_NORMAL = 90, COIN_TRANSFERRABLE = 91, COIN_AUCTION = 92, COIN_TOURNAMENT = 93
    }
end

if not CyclopediaCharacterInfoTypes then
    CyclopediaCharacterInfoTypes = {
        BaseInformation = 0, GeneralStats = 1, CombatStats = 2, RecentDeaths = 3,
        RecentPVPKills = 4, Achievements = 5, ItemSummary = 6, OutfitsAndMounts = 7,
        StoreSummary = 8, Ispection = 9, Badges = 10, Titles = 11, Wheel = 12,
        Offencestats = 13, Defencestats = 14, Miscstats = 15
    }
end

-- Safe stubs for server-side g_game functions not yet implemented in otcv8
-- These will silently no-op until the server side is implemented
local function makeSafeStub(name)
    if not g_game[name] then
        g_game[name] = function(...)
            -- g_game[name] not yet implemented in this client build
        end
    end
end
makeSafeStub("requestBestiary")
makeSafeStub("requestBestiaryOverview")
makeSafeStub("requestBestiarySearch")
makeSafeStub("requestBosstiaryInfo")
makeSafeStub("requestCharacterInfo")
makeSafeStub("sendStatusTrackerBestiary")
makeSafeStub("sendBosstiarySlots")
makeSafeStub("sendBosstiarySlotAction")
makeSafeStub("sendUnlockBoss")
makeSafeStub("openCyclopediaMapHouse")
makeSafeStub("openCyclopediaItemDetail")
makeSafeStub("requestShowHouses")
makeSafeStub("requestBidHouse")
makeSafeStub("requestMoveOutHouse")
makeSafeStub("requestTransferHouse")
makeSafeStub("requestAcceptHouseTransfer")
makeSafeStub("requestRejectHouseTransfer")
makeSafeStub("requestCancelHouseTransfer")

-- Safe stub for Keybind (rookhaven uses a different keybind system)
if not Keybind then
    Keybind = {
        new = function(...) end,
        bind = function(...) end,
        delete = function(...) end,
    }
end

-- Global creature data cache populated from server bestiary responses
_CyclopediaCreatureDataCache = _CyclopediaCreatureDataCache or {}

-- Safe stubs for g_things functions not in rookhaven
if not g_things.getRaceData then
    g_things.getRaceData = function(raceId)
        if _CyclopediaCreatureDataCache[raceId] then
            return _CyclopediaCreatureDataCache[raceId]
        end
        return {
            name = "Unknown",
            outfit = { type = 0, head = 0, body = 0, legs = 0, feet = 0, addons = 0 },
            level = 0, experience = 0, speed = 0, points = 0, charm = 0,
            difficulty = 0, occurrence = 0, id = raceId or 0
        }
    end
end

if not g_things.getRacesByName then
    g_things.getRacesByName = function(text)
        local results = {}
        if not text or text == "" then return results end
        local lowerText = text:lower()
        for id, data in pairs(_CyclopediaCreatureDataCache) do
            if data.name and data.name:lower():find(lowerText, 1, true) then
                table.insert(results, { raceId = id, name = data.name })
            end
        end
        return results
    end
end

-- Safe wrappers for LocalPlayer methods not present in otcv8
local _origGetLocalPlayer = g_game.getLocalPlayer
g_game.getLocalPlayer = function()
    local p = _origGetLocalPlayer()
    if p then
        if not p.getTotalMoney then
            p.getTotalMoney = function(self) return 0 end
        end
        if not p.getResourceBalance then
            p.getResourceBalance = function(self, t) return 0 end
        end
    end
    return p
end

Cyclopedia = {}

local CYCLOPEDIA_EXT_OPCODE = 3
local CYCLOPEDIA_PROTOCOL_PREFIX = "cp"
local CYCLOPEDIA_PROTOCOL_VERSION = "1"

-- These remain intentionally disabled until the dedicated rollout phase.
local HARD_DISABLED_TABS = {
    charms = true,
    bosstiary = true,
    bossSlot = true,
    magicalArchives = true
}

Cyclopedia.Capabilities = {
    items = true,
    bestiary = true,
    map = true,
    houses = true,
    character = true,
    charms = false,
    bosstiary = false,
    bossSlot = false,
    magicalArchives = false
}

local function encodeCyclopediaPayload(kind, action, extra)
    local payload = table.concat({
        CYCLOPEDIA_PROTOCOL_PREFIX,
        CYCLOPEDIA_PROTOCOL_VERSION,
        kind,
        action
    }, "|")
    if extra and extra ~= "" then
        payload = payload .. "|" .. extra
    end
    return payload
end

local function decodeCyclopediaPayload(buffer)
    local parts = string.split(buffer or "", "|")
    if not parts or #parts < 4 then
        return nil
    end

    if parts[1] ~= CYCLOPEDIA_PROTOCOL_PREFIX or parts[2] ~= CYCLOPEDIA_PROTOCOL_VERSION then
        return nil
    end

    return {
        kind = parts[3],
        action = parts[4],
        status = parts[5],
        data = parts[6] or ""
    }
end

local function parseCapabilities(data)
    local capabilities = {}
    for _, pair in ipairs(string.split(data or "", ";")) do
        local kv = string.split(pair, "=")
        if kv and #kv == 2 then
            local key = kv[1]
            local value = kv[2]
            capabilities[key] = value == "1"
        end
    end
    return capabilities
end

local function safeUnregisterCyclopediaOpcode()
    pcall(function()
        ProtocolGame.unregisterExtendedOpcode(CYCLOPEDIA_EXT_OPCODE)
    end)
end

local function safeRegisterCyclopediaOpcode()
    safeUnregisterCyclopediaOpcode()
    local ok = pcall(function()
        ProtocolGame.registerExtendedOpcode(CYCLOPEDIA_EXT_OPCODE, Cyclopedia.onExtendedOpcode)
    end)

    if not ok then
        -- Retry once in case another module phase temporarily held the opcode.
        scheduleEvent(function()
            safeUnregisterCyclopediaOpcode()
            pcall(function()
                ProtocolGame.registerExtendedOpcode(CYCLOPEDIA_EXT_OPCODE, Cyclopedia.onExtendedOpcode)
            end)
        end, 50)
    end
end

local function enforceHardDisabledTabs()
    if not buttonSelection then
        return
    end

    for tabId, _ in pairs(HARD_DISABLED_TABS) do
        local button = buttonSelection:recursiveGetChildById(tabId)
        if button then
            button:setVisible(false)
        end
    end
end

function Cyclopedia.applyCapabilities(capabilities)
    if type(capabilities) ~= "table" then
        return
    end

    for key, value in pairs(capabilities) do
        Cyclopedia.Capabilities[key] = value and true or false
    end

    -- Keep rollout safety constraints in force regardless of server capability state.
    for tabId, _ in pairs(HARD_DISABLED_TABS) do
        Cyclopedia.Capabilities[tabId] = false
    end

    enforceHardDisabledTabs()
end

function Cyclopedia.requestCapabilities()
    Cyclopedia.sendCyclopediaRequest("capabilities", "")
end

function Cyclopedia.onExtendedOpcode(protocol, opcode, buffer)
    if opcode ~= CYCLOPEDIA_EXT_OPCODE then
        return
    end

    local payload = decodeCyclopediaPayload(buffer)
    if not payload or payload.kind ~= "res" then
        return
    end

    if payload.action == "capabilities" then
        if payload.status == "ok" then
            Cyclopedia.applyCapabilities(parseCapabilities(payload.data))
        end
        return
    end

    if payload.status ~= "ok" then
        return
    end

    local action = payload.action
    local data   = payload.data or ""

    if action == "character.recentDeaths" then
        Cyclopedia.parseAndLoadRecentDeaths(data)
    elseif action == "character.recentKills" then
        Cyclopedia.parseAndLoadRecentKills(data)
    elseif action == "character.itemSummary" then
        Cyclopedia.parseAndLoadItemSummary(data)
    elseif action == "character.appearances" then
        Cyclopedia.parseAndLoadAppearances(data)
    elseif action == "bestiary.categories" then
        Cyclopedia.parseAndLoadBestiaryCategories(data)
    elseif action == "bestiary.overview" then
        Cyclopedia.parseAndLoadBestiaryOverview(data)
    elseif action == "houses.list" then
        Cyclopedia.parseAndLoadHousesList(data)
    elseif action == "houses.towns" then
        Cyclopedia.parseAndLoadHouseTowns(data)
    end
end

-- =========================================================
--  Cyclopedia ext-opcode request helper
-- =========================================================

function Cyclopedia.sendCyclopediaRequest(action, payload)
    local protocol = g_game.getProtocolGame()
    if not protocol or not protocol.sendExtendedOpcode then
        return false
    end

    protocol:sendExtendedOpcode(CYCLOPEDIA_EXT_OPCODE,
        encodeCyclopediaPayload("req", action, payload))
    return true
end

function Cyclopedia.requestHouseTowns()
    Cyclopedia.sendCyclopediaRequest("houses.towns", "")
end

-- =========================================================
--  Local-player stat builders (no server round-trip needed)
-- =========================================================

function Cyclopedia.buildAndLoadGeneralStats()
    if not Cyclopedia.loadCharacterGeneralStats then return end
    local player = g_game.getLocalPlayer()
    if not player then return end

    local data = {
        level                  = player:getLevel(),
        levelPercent           = player:getLevelPercent(),
        baseExpGain            = 100,
        XpBoostPercent         = 0,
        XpBoostBonusRemainingTime = 0,
        staminaMinutes         = player:getStamina(),
        maxHealth              = player:getMaxHealth(),
        mana                   = player:getMaxMana(),
        soul                   = player:getSoul(),
        speed                  = player:getSpeed(),
        regenerationCondition  = player:getRegenerationTime(),
        offlineTrainingTime    = player:getOfflineTrainingTime(),
        magicLevel             = player:getMagicLevel(),
        magicLevelPercent      = player:getMagicLevelPercent() * 100,
        baseMagicLevel         = player:getBaseMagicLevel(),
    }

    -- skills[i+1] = {level, baseLevel, percent} for skill id i (Fist=0 ... Fishing=6)
    local skills = {}
    for i = 0, 6 do
        skills[i + 1] = {
            player:getSkillLevel(i),
            player:getSkillBaseLevel(i),
            player:getSkillLevelPercent(i),
        }
    end

    Cyclopedia.loadCharacterGeneralStats(data, skills)
end

function Cyclopedia.buildAndLoadCombatStats()
    if not Cyclopedia.loadCharacterCombatStats then return end
    local player = g_game.getLocalPlayer()
    if not player then return end

    -- Count active blessings from bitmask
    local blessingCount = 0
    local bitmask = player:getBlessings() or 0
    for i = 0, 7 do
        if bit.band(bitmask, bit.lshift(1, i)) ~= 0 then
            blessingCount = blessingCount + 1
        end
    end

    local data = {
        weaponElement      = 0,
        weaponMaxHitChance = 100,
        weaponElementDamage = 0,
        weaponElementType  = 0,
        defense            = 0,
        armor              = 0,
        haveBlessings      = blessingCount,
    }

    -- CriticalChance=7, CriticalDamage=8, LifeLeechAmount=10, ManaLeechAmount=12
    local additionalSkillsArray = {
        { 7,  player:getSkillLevel(7)  },
        { 8,  player:getSkillLevel(8)  },
        { 10, player:getSkillLevel(10) },
        { 12, player:getSkillLevel(12) },
    }

    Cyclopedia.loadCharacterCombatStats(data, 0.0, additionalSkillsArray, {}, {}, {}, {})
end

-- =========================================================
--  Override g_game stubs with ext-opcode backed versions
-- =========================================================

local _origRequestCharacterInfo = g_game.requestCharacterInfo
g_game.requestCharacterInfo = function(characterId, infoType, ...)
    local T = CyclopediaCharacterInfoTypes
    if infoType == T.GeneralStats then
        Cyclopedia.buildAndLoadGeneralStats()
    elseif infoType == T.Badges then
        if Cyclopedia.loadCharacterBadges then
            Cyclopedia.loadCharacterBadges(true, true, true, "", {})
        end
    elseif infoType == T.CombatStats
        or infoType == T.Offencestats
        or infoType == T.Defencestats
        or infoType == T.Miscstats then
        Cyclopedia.buildAndLoadCombatStats()
    elseif infoType == T.RecentDeaths then
        Cyclopedia.sendCyclopediaRequest("character.recentDeaths", "")
    elseif infoType == T.RecentPVPKills then
        Cyclopedia.sendCyclopediaRequest("character.recentKills", "")
    elseif infoType == T.ItemSummary then
        Cyclopedia.sendCyclopediaRequest("character.itemSummary", "")
    elseif infoType == T.OutfitsAndMounts then
        Cyclopedia.sendCyclopediaRequest("character.appearances", "")
    elseif infoType == T.StoreSummary then
        if Cyclopedia.onParseCyclopediaStoreSummary then
            Cyclopedia.onParseCyclopediaStoreSummary(0, 0, 0, 0, 0, {}, 0, {})
        end
    else
        _origRequestCharacterInfo(characterId, infoType, ...)
    end
end

local _origRequestBestiary = g_game.requestBestiary
g_game.requestBestiary = function(...)
    Cyclopedia.sendCyclopediaRequest("bestiary.categories", "")
end

local _origRequestBestiaryOverview = g_game.requestBestiaryOverview
g_game.requestBestiaryOverview = function(name, ...)
    Cyclopedia.sendCyclopediaRequest("bestiary.overview", tostring(name or ""))
end

local _origRequestBestiarySearch = g_game.requestBestiarySearch
g_game.requestBestiarySearch = function(raceId, ...)
    local selected = Cyclopedia.BestiaryCreatureCache and Cyclopedia.BestiaryCreatureCache[raceId] or nil
    if selected and Cyclopedia.loadBestiarySelectedCreature then
        Cyclopedia.loadBestiarySelectedCreature(selected)
        return
    end
    _origRequestBestiarySearch(raceId, ...)
end

local _origRequestShowHouses = g_game.requestShowHouses
g_game.requestShowHouses = function(townName, ...)
    Cyclopedia.sendCyclopediaRequest("houses.list", tostring(townName or ""))
end

-- =========================================================
--  Response parsers (called from onExtendedOpcode)
-- =========================================================

-- Format: timestamp,cause~timestamp,cause~...
function Cyclopedia.parseAndLoadRecentDeaths(data)
    if not Cyclopedia.loadCharacterRecentDeaths then return end
    local deaths = {}
    if data and data ~= "" then
        for _, record in ipairs(string.split(data, "~")) do
            local f = string.split(record, ",")
            if f and #f >= 2 then
                table.insert(deaths, {
                    timestamp = tonumber(f[1]) or 0,
                    cause     = f[2] or ""
                })
            end
        end
    end
    Cyclopedia.loadCharacterRecentDeaths(deaths)
end

-- Currently returns empty (no PvP kill tracking)
function Cyclopedia.parseAndLoadRecentKills(data)
    if not Cyclopedia.loadCharacterRecentKills then return end
    Cyclopedia.loadCharacterRecentKills({})
end

-- itemSummary is expensive server-side; return empty for now
function Cyclopedia.parseAndLoadItemSummary(data)
    if not Cyclopedia.loadCharacterItems then return end
    Cyclopedia.loadCharacterItems({
        inventory = {}, store = {}, stash = {}, depot = {}, inbox = {}
    })
end

-- appearances deferred; return empty
function Cyclopedia.parseAndLoadAppearances(data)
    if not Cyclopedia.loadCharacterAppearances then return end
    Cyclopedia.loadCharacterAppearances(
        { lookHead = 0, lookBody = 0, lookLegs = 0, lookFeet = 0 },
        {}, {}, {})
end

-- bestiary.categories response
-- Format: name,count,unlocked,animusBonus~...
function Cyclopedia.parseAndLoadBestiaryCategories(data)
    if not Cyclopedia.loadBestiaryCategories then return end
    local categories = {}
    if data and data ~= "" then
        for _, record in ipairs(string.split(data, "~")) do
            local f = string.split(record, ",")
            if f and #f >= 4 then
                table.insert(categories, {
                    bestClass         = f[1] or "Unknown",
                    count             = tonumber(f[2]) or 0,
                    unlockedCount     = tonumber(f[3]) or 0,
                    AnimusMasteryBonus = tonumber(f[4]) or 0,
                })
            end
        end
    end
    Cyclopedia.loadBestiaryCategories(categories)
end

-- bestiary.overview response
-- Format: categoryName~raceId,name,outfitType,kills,level,animusBonus~...
function Cyclopedia.parseAndLoadBestiaryOverview(data)
    if not Cyclopedia.loadBestiaryOverview then return end
    if not data or data == "" then
        Cyclopedia.loadBestiaryOverview("", {}, 0)
        return
    end
    local parts = string.split(data, "~")
    if not parts or #parts < 1 then
        Cyclopedia.loadBestiaryOverview("", {}, 0)
        return
    end
    local categoryName = parts[1]
    local creatures = {}
    Cyclopedia.BestiaryCreatureCache = Cyclopedia.BestiaryCreatureCache or {}
    for i = 2, #parts do
        local f = string.split(parts[i], ",")
        if f and #f >= 6 then
            local raceId     = tonumber(f[1]) or 0
            local name       = f[2] or "Unknown"
            local outfitType = tonumber(f[3]) or 0
            local kills      = tonumber(f[4]) or 0
            local level      = tonumber(f[5]) or 0
            local animus     = tonumber(f[6]) or 0
            local maxHealth  = tonumber(f[7]) or 100
            local experience = tonumber(f[8]) or 50
            local speed      = tonumber(f[9]) or 180
            local armor      = tonumber(f[10]) or 5
            local defense    = tonumber(f[11]) or 0
            -- Populate creature data cache so getRaceData works
            _CyclopediaCreatureDataCache[raceId] = {
                name   = name,
                outfit = { type = outfitType, head = 0, body = 0, legs = 0, feet = 0, addons = 0 },
                level = 0, experience = 0, speed = 0, points = kills, charm = 0,
                difficulty = 1, occurrence = 0, id = raceId
            }
            table.insert(creatures, {
                id                        = raceId,
                currentLevel              = level,
                creatureAnimusMasteryBonus = animus,
            })
            Cyclopedia.BestiaryCreatureCache[raceId] = {
                id = raceId,
                ocorrence = 1,
                difficulty = 1,
                killCounter = kills,
                thirdDifficulty = 25,
                secondUnlock = 100,
                lastProgressKillCount = 250,
                currentLevel = level,
                maxHealth = maxHealth,
                experience = experience,
                speed = speed,
                armor = armor,
                mitigation = defense,
                charmValue = 5,
                attackMode = 1,
                combat = {0, 0, 0, 0, 0, 0, 0, 0},
                loot = {},
                location = "Unknown",
                AnimusMasteryPoints = 0,
                AnimusMasteryBonus = 0,
            }
        end
    end
    Cyclopedia.loadBestiaryOverview(categoryName, creatures, 0)
end

-- houses.list response
-- Format: id,name,townName,rent,beds,sqm,ownerName,state,paidUntil~...
function Cyclopedia.parseAndLoadHousesList(data)
    local houses = {}
    local townsSet = {}
    local townsList = {}
    if data and data ~= "" then
        local playerName = (g_game.getLocalPlayer() and g_game.getLocalPlayer():getName()) or ""
        local lowerPlayerName = playerName:lower()
        for _, record in ipairs(string.split(data, "~")) do
            local f = string.split(record, ",")
            if f and #f >= 9 then
                local id         = tonumber(f[1]) or 0
                local name       = f[2] or "Unknown"
                local townName   = f[3] or ""
                local rent       = tonumber(f[4]) or 0
                local beds       = tonumber(f[5]) or 0
                local sqm        = tonumber(f[6]) or 0
                local ownerName  = f[7] or ""
                local state      = tonumber(f[8]) or 1
                local paidUntil  = tonumber(f[9]) or 0
                local isYours    = ownerName ~= "" and ownerName:lower() == lowerPlayerName

                if townName ~= "" and not townsSet[townName:lower()] then
                    townsSet[townName:lower()] = true
                    table.insert(townsList, townName)
                end

                table.insert(houses, {
                    id             = id,
                    name           = name,
                    description    = "",
                    rent           = rent,
                    beds           = beds,
                    sqm            = sqm,
                    gh             = false,
                    shop           = false,
                    visible        = true,
                    townName       = townName,
                    state          = state,
                    owner          = ownerName ~= "" and ownerName or "?",
                    rented         = state == 2 or state == 3,
                    paidUntil      = paidUntil > 0 and paidUntil or nil,
                    isYourOwner    = isYours,
                    inTransfer     = state == 3,
                    hasBid         = false,
                    isYourBid      = false,
                    bidEnd         = nil,
                    hightestBid    = nil,
                    bidName        = nil,
                    bidHolderLimit = nil,
                    canBid         = not (state == 2 or state == 3),
                    transferName   = nil,
                    transferTime   = 0,
                    transferValue  = 0,
                    isTransferOwner = false,
                    canAcceptTransfer = 0,
                })
            end
        end
    end
    -- Apply town filter from currently selected option (if house tab is open)
    Cyclopedia.House.DynamicCities = townsList
    if Cyclopedia.updateHouseCityOptions then
        Cyclopedia.updateHouseCityOptions(townsList)
    end
    Cyclopedia.House.CachedData = houses
    Cyclopedia.applyHousesTownFilter()
end

-- Format: townName~townName~...
function Cyclopedia.parseAndLoadHouseTowns(data)
    local towns = {}
    local seen = {}
    if data and data ~= "" then
        for _, townName in ipairs(string.split(data, "~")) do
            local clean = tostring(townName or "")
            if clean ~= "" and not seen[clean:lower()] then
                seen[clean:lower()] = true
                table.insert(towns, clean)
            end
        end
    end
    Cyclopedia.House.DynamicCities = towns
    if Cyclopedia.updateHouseCityOptions then
        Cyclopedia.updateHouseCityOptions(towns)
    end
end

-- Applies the current town filter from the house tab and reloads the list.
-- Safe to call even when the house tab is not open (Cyclopedia.reloadHouseList
-- guards against nil UI references inside house.lua).
function Cyclopedia.applyHousesTownFilter()
    if not Cyclopedia.House.CachedData then return end
    local townFilter = Cyclopedia.House.lastTown or nil
    local lowerFilter = townFilter and townFilter:lower() or nil
    local filtered = {}
    for _, h in ipairs(Cyclopedia.House.CachedData) do
        if not lowerFilter or lowerFilter == "" or (h.townName and h.townName:lower() == lowerFilter) then
            table.insert(filtered, h)
        end
    end
    Cyclopedia.House.Data = filtered
    if Cyclopedia.reloadHouseList then
        Cyclopedia.reloadHouseList()
    end
end

trackerButton = nil
trackerMiniWindow = nil
trackerButtonBosstiary = nil
trackerMiniWindowBosstiary = nil
contentContainer = nil

-- Track current character to detect character changes
local currentCharacter = nil

local buttonSelection = nil
local items = nil
local bestiary = nil
local charms = nil
local map = nil
local houses = nil
local character = nil
local CyclopediaButton = nil
local bosstiary = nil
local bossSlot = nil
local ButtonBossSlot = nil
local ButtonBestiary = nil
local tabStack = {}
local previousType = nil
local windowTypes = {}
local magicalArchives = nil
function toggle(defaultWindow)
    if not controllerCyclopedia.ui then
        return
    end
    if controllerCyclopedia.ui:isVisible() then
        return hide()
    end
    show(defaultWindow)
end

controllerCyclopedia = Controller:new()
controllerCyclopedia:setUI('game_cyclopedia')

function controllerCyclopedia:onInit()
end

function controllerCyclopedia:onGameStart()
    do
        safeRegisterCyclopediaOpcode()

        CyclopediaButton = modules.client_topmenu.addRightGameToggleButton('CyclopediaButton', tr('Cyclopedia'),
            '/images/topbuttons/cyclopedia', function() toggle("items") end, false, 7)
        CyclopediaButton:setOn(false)

        contentContainer = controllerCyclopedia.ui:recursiveGetChildById('contentContainer')
        buttonSelection = controllerCyclopedia.ui:recursiveGetChildById('buttonSelection')
        items = buttonSelection:recursiveGetChildById('items')
        bestiary = buttonSelection:recursiveGetChildById('bestiary')
        charms = buttonSelection:recursiveGetChildById('charms')
        map = buttonSelection:recursiveGetChildById('map')
        houses = buttonSelection:recursiveGetChildById('houses')
        character = buttonSelection:recursiveGetChildById('character')
        bosstiary = buttonSelection:recursiveGetChildById('bosstiary')
        bossSlot = buttonSelection:recursiveGetChildById('bossSlot')
        magicalArchives = buttonSelection:recursiveGetChildById('magicalArchives')

        windowTypes = {
            items = { obj = items, func = showItems },
            bestiary = { obj = bestiary, func = showBestiary },
            map = { obj = map, func = showMap },
            houses = { obj = houses, func = showHouse },
            character = { obj = character, func = showCharacter },
        }

        enforceHardDisabledTabs()

        g_ui.importStyle("cyclopedia_widgets")
        g_ui.importStyle("cyclopedia_pages")

        controllerCyclopedia:registerEvents(g_game, {
            onResourcesBalanceChange = Cyclopedia.onResourcesBalanceChange,
            -- bestiary
            onParseBestiaryRaces = Cyclopedia.loadBestiaryCategories,
            onParseBestiaryOverview = Cyclopedia.loadBestiaryOverview,
            onUpdateBestiaryMonsterData = Cyclopedia.loadBestiarySelectedCreature,
            -- bosstiary // bestiary
            onParseCyclopediaTracker = Cyclopedia.onParseCyclopediaTracker,
            -- bosstiary
            onParseSendBosstiary = Cyclopedia.LoadBosstiaryCreatures,
            -- boss_slot
            onParseBosstiarySlots = Cyclopedia.loadBossSlots,
            -- character
            onParseCyclopediaCharacterGeneralStats = Cyclopedia.loadCharacterGeneralStats,
            onParseCyclopediaCharacterCombatStats = Cyclopedia.loadCharacterCombatStats,
            onParseCyclopediaCharacterBadges = Cyclopedia.loadCharacterBadges,
            onCyclopediaCharacterRecentDeaths = Cyclopedia.loadCharacterRecentDeaths,
            onCyclopediaCharacterRecentKills = Cyclopedia.loadCharacterRecentKills,
            onUpdateCyclopediaCharacterItemSummary = Cyclopedia.loadCharacterItems,
            onParseCyclopediaCharacterAppearances = Cyclopedia.loadCharacterAppearances,
            onParseCyclopediaStoreSummary = Cyclopedia.onParseCyclopediaStoreSummary,
            -- character 14.10
            onCyclopediaCharacterOffenceStats = Cyclopedia.onCyclopediaCharacterOffenceStats,
            onCyclopediaCharacterDefenceStats = Cyclopedia.onCyclopediaCharacterDefenceStats,
            onCyclopediaCharacterMiscStats = Cyclopedia.onCyclopediaCharacterMiscStats,


            -- charms
            onUpdateBestiaryCharmsData = Cyclopedia.loadCharms,
            -- items
            onParseItemDetail = Cyclopedia.loadItemDetail
        })

        --[[===================================================
    =               Tracker Bestiary                      =
    =================================================== ]] --

        if trackerButton then trackerButton:setOn(false) end
        
        -- Only create if it doesn't exist
        if not trackerMiniWindow then
            trackerMiniWindow = g_ui.createWidget('BestiaryTracker', modules.game_interface.getRightPanel())

            -- Set the title with length limit like in containers
            local titleWidget = trackerMiniWindow:getChildById('miniwindowTitle')
            if titleWidget then
                local title = tr('Bestiary Tracker')
                if title:len() > 12 then
                    title = title:sub(1, 12) .. "..."
                end
                titleWidget:setText(title)
            end

            -- Set up contextMenuButton positioning and click handler
            local contextMenuButton = trackerMiniWindow:recursiveGetChildById('contextMenuButton')
            local newWindowButton = trackerMiniWindow:recursiveGetChildById('newWindowButton')
            local minimizeButton = trackerMiniWindow:recursiveGetChildById('minimizeButton')
            
            if contextMenuButton then
                contextMenuButton:setVisible(true)
                
                -- Position contextMenuButton like in ImbuementTracker
                if minimizeButton then
                    contextMenuButton:breakAnchors()
                    contextMenuButton:addAnchor(AnchorTop, minimizeButton:getId(), AnchorTop)
                    contextMenuButton:addAnchor(AnchorRight, minimizeButton:getId(), AnchorLeft)
                    contextMenuButton:setMarginRight(7)
                    contextMenuButton:setMarginTop(0)
                end
                
                contextMenuButton.onClick = function(widget, mousePos, mouseButton)
                    return Cyclopedia.createTrackerContextMenu("bestiary", mousePos)
                end
            end

            if newWindowButton then
                newWindowButton:setVisible(true)
                newWindowButton.onClick = function(widget, mousePos, mouseButton)
                    toggle("bestiary")
                    return true
                end
            end

            -- Hook into the onOpen event to ensure data is loaded when window is shown
            trackerMiniWindow.onOpen = function()
                if trackerButton then trackerButton:setOn(true) end
                -- Aggressive data loading when window becomes visible
                scheduleEvent(function()
                    local char = g_game.getCharacterName()
                    if char and #char > 0 then
                        -- Always ensure data is initialized
                        Cyclopedia.initializeTrackerData()
                        
                        -- Force refresh if no data is visible
                        if not Cyclopedia.storedTrackerData or #Cyclopedia.storedTrackerData == 0 then
                            -- Try to load from cache first
                            local cachedData = Cyclopedia.loadTrackerData("bestiary")
                            if cachedData and #cachedData > 0 then
                                Cyclopedia.storedTrackerData = cachedData
                                Cyclopedia.onParseCyclopediaTracker(0, Cyclopedia.storedTrackerData)
                            end
                        end
                        
                        -- Always try to refresh, regardless of cached data
                        Cyclopedia.refreshBestiaryTracker()
                        
                        -- Request fresh data from server
                        g_game.requestBestiary()
                        
                        -- Additional fallback check
                        scheduleEvent(function()
                            if trackerMiniWindow:isVisible() and trackerMiniWindow.contentsPanel:getChildCount() == 0 then
                                -- If still no data after all attempts, force another refresh
                                Cyclopedia.refreshBestiaryTracker()
                            end
                        end, 500)
                    end
                end, 50)
            end

            trackerMiniWindow.onClose = function()
                if trackerButton then trackerButton:setOn(false) end
            end

            trackerMiniWindow:setup()
            trackerMiniWindow:hide()
        end

        --[[===================================================
    =               Tracker Bosstiary                     =
    =================================================== ]] --

        if trackerButtonBosstiary then trackerButtonBosstiary:setOn(false) end
        
        -- Only create if it doesn't exist
        if not trackerMiniWindowBosstiary then
            trackerMiniWindowBosstiary = g_ui.createWidget('BestiaryTracker', modules.game_interface.getRightPanel())
            
            -- Set the title with length limit like in containers
            local titleWidgetBosstiary = trackerMiniWindowBosstiary:getChildById('miniwindowTitle')
            if titleWidgetBosstiary then
                local title = tr('Bosstiary Tracker')
                if title:len() > 12 then
                    title = title:sub(1, 12) .. "..."
                end
                titleWidgetBosstiary:setText(title)
            end

            -- Set the icon for Bosstiary Tracker when asset is available.
            local iconWidgetBosstiary = trackerMiniWindowBosstiary:getChildById('miniwindowIcon')
            if iconWidgetBosstiary and g_resources.fileExists('/images/icons/icon-bosstracker-widget.png') then
                iconWidgetBosstiary:setImageSource('/images/icons/icon-bosstracker-widget')
            end

            -- Set up contextMenuButton positioning and click handler for Bosstiary
            local contextMenuButtonBosstiary = trackerMiniWindowBosstiary:recursiveGetChildById('contextMenuButton')
            local newWindowButtonBosstiary = trackerMiniWindowBosstiary:recursiveGetChildById('newWindowButton')
            local minimizeButtonBosstiary = trackerMiniWindowBosstiary:recursiveGetChildById('minimizeButton')
            
            if contextMenuButtonBosstiary then
                contextMenuButtonBosstiary:setVisible(true)
                
                -- Position contextMenuButton like in ImbuementTracker
                if minimizeButtonBosstiary then
                    contextMenuButtonBosstiary:breakAnchors()
                    contextMenuButtonBosstiary:addAnchor(AnchorTop, minimizeButtonBosstiary:getId(), AnchorTop)
                    contextMenuButtonBosstiary:addAnchor(AnchorRight, minimizeButtonBosstiary:getId(), AnchorLeft)
                    contextMenuButtonBosstiary:setMarginRight(7)
                    contextMenuButtonBosstiary:setMarginTop(0)
                end
                
                contextMenuButtonBosstiary.onClick = function(widget, mousePos, mouseButton)
                    return Cyclopedia.createTrackerContextMenu("bosstiary", mousePos)
                end
            end

            if newWindowButtonBosstiary then
                newWindowButtonBosstiary:setVisible(true)
                newWindowButtonBosstiary.onClick = function(widget, mousePos, mouseButton)
                    toggle("bosstiary")
                    return true
                end
            end

            -- Hook into the onOpen event to ensure data is loaded when window is shown
            trackerMiniWindowBosstiary.onOpen = function()
                if trackerButtonBosstiary then trackerButtonBosstiary:setOn(true) end
                -- Aggressive data loading when window becomes visible
                scheduleEvent(function()
                    local char = g_game.getCharacterName()
                    if char and #char > 0 then
                        -- Always ensure data is initialized
                        Cyclopedia.initializeTrackerData()
                        
                        -- Force refresh if no data is visible
                        if not Cyclopedia.storedBosstiaryTrackerData or #Cyclopedia.storedBosstiaryTrackerData == 0 then
                            -- Try to load from cache first
                            local cachedData = Cyclopedia.loadTrackerData("bosstiary")
                            if cachedData and #cachedData > 0 then
                                Cyclopedia.storedBosstiaryTrackerData = cachedData
                                Cyclopedia.onParseCyclopediaTracker(1, Cyclopedia.storedBosstiaryTrackerData)
                            end
                        end
                        
                        -- Always try to refresh, regardless of cached data
                        Cyclopedia.refreshBosstiaryTracker()
                        
                        -- Request fresh data from server
                        g_game.requestBestiary()
                        
                        -- Additional fallback check
                        scheduleEvent(function()
                            if trackerMiniWindowBosstiary:isVisible() and trackerMiniWindowBosstiary.contentsPanel:getChildCount() == 0 then
                                -- If still no data after all attempts, force another refresh
                                Cyclopedia.refreshBosstiaryTracker()
                            end
                        end, 500)
                    end
                end, 50)
            end

            trackerMiniWindowBosstiary.onClose = function()
                if trackerButtonBosstiary then trackerButtonBosstiary:setOn(false) end
            end

            trackerMiniWindowBosstiary:setup()
            trackerMiniWindowBosstiary:hide()
        end
        if trackerMiniWindow and trackerMiniWindow.setupOnStart then
            trackerMiniWindow:setupOnStart()
        end
        if trackerMiniWindowBosstiary and trackerMiniWindowBosstiary.setupOnStart then
            trackerMiniWindowBosstiary:setupOnStart()
        end
        Cyclopedia.loadTrackerFilters("bestiary")
        Cyclopedia.loadTrackerFilters("bosstiary")
        
        -- Populate any visible trackers with cached data after windows are set up
        Cyclopedia.populateVisibleTrackersWithCachedData()
        
        -- Also set up proper tracker button states based on window visibility
        if trackerMiniWindow:isVisible() and trackerButton then
            trackerButton:setOn(true)
        end
        if trackerMiniWindowBosstiary:isVisible() and trackerButtonBosstiary then
            trackerButtonBosstiary:setOn(true)
        end
        
        Cyclopedia.BossSlots.UnlockBosses = {}
        Keybind.new("Windows", "Show/hide Bosstiary Tracker", "", "")

        Keybind.bind("Windows", "Show/hide Bosstiary Tracker", {{
            type = KEY_DOWN,
            callback = Cyclopedia.toggleBosstiaryTracker
        }})

        Keybind.new("Windows", "Show/hide Bestiary Tracker", "", "")
        Keybind.bind("Windows", "Show/hide Bestiary Tracker", {{
            type = KEY_DOWN,
            callback = Cyclopedia.toggleBestiaryTracker
        }})
        
        -- Initialize cached tracker data for immediate loading with delay to ensure character name is available
        scheduleEvent(function()
            local char = g_game.getCharacterName()
            if char and #char > 0 then
                -- Only clear data if character has changed
                if currentCharacter and currentCharacter ~= char then
                    if Cyclopedia.clearTrackerDataForCharacterChange then
                        Cyclopedia.clearTrackerDataForCharacterChange()
                    end
                end
                
                -- Update current character
                currentCharacter = char
                
                -- Initialize tracker data for current character
                Cyclopedia.initializeTrackerData()
                
                -- Populate any visible trackers with cached data
                Cyclopedia.populateVisibleTrackersWithCachedData()
                
                -- Request fresh bestiary data from server
                g_game.requestBestiary()
                
                -- Additional refresh after delays to ensure everything is loaded
                scheduleEvent(function()
                    Cyclopedia.populateVisibleTrackersWithCachedData()
                    Cyclopedia.refreshAllVisibleTrackers()
                end, 500)
                
                -- Final fallback check
                scheduleEvent(function()
                    Cyclopedia.refreshAllVisibleTrackers()
                end, 2000)
            end
        end, 500)

        scheduleEvent(function()
            Cyclopedia.requestCapabilities()
        end, 250)
    end
    if g_game.getClientVersion() >= 1410 then
        controllerCyclopedia.ui.CharmsBase.Icon:setImageSource("/game_cyclopedia/images/monster-icon-bonuspoints")
    end
end


function controllerCyclopedia:onGameEnd()
    safeUnregisterCyclopediaOpcode()

    if trackerMiniWindow then
        trackerMiniWindow.contentsPanel:destroyChildren()
    end
    if trackerMiniWindowBosstiary then
        trackerMiniWindowBosstiary.contentsPanel:destroyChildren()
    end
    hide()
    
    -- Save tracker filters and data for current character
    if Cyclopedia.saveTrackerFilters then
        Cyclopedia.saveTrackerFilters("bestiary")
        Cyclopedia.saveTrackerFilters("bosstiary")
    end
    
    -- Save current tracker data for current character
    if Cyclopedia.saveTrackerData then
        if Cyclopedia.storedTrackerData then
            Cyclopedia.saveTrackerData("bestiary", Cyclopedia.storedTrackerData)
        end
        if Cyclopedia.storedBosstiaryTrackerData then
            Cyclopedia.saveTrackerData("bosstiary", Cyclopedia.storedBosstiaryTrackerData)
        end
    end
    
    -- Don't clear currentCharacter here - keep it for character change detection
    
    Keybind.delete("Windows", "Show/hide Bosstiary Tracker")
    Keybind.delete("Windows", "Show/hide Bestiary Tracker")
end

function controllerCyclopedia:onTerminate()
    safeUnregisterCyclopediaOpcode()

    if trackerButton then
        trackerButton:destroy()
        trackerButton = nil
    end

    if trackerMiniWindow then
        trackerMiniWindow:destroy()
        trackerMiniWindow = nil
    end

    if trackerButtonBosstiary then
        trackerButtonBosstiary:destroy()
        trackerButtonBosstiary = nil
    end

    if trackerMiniWindowBosstiary then
        trackerMiniWindowBosstiary:destroy()
        trackerMiniWindowBosstiary = nil
    end

    if CyclopediaButton then
        CyclopediaButton:destroy()
        CyclopediaButton = nil
    end
    if ButtonBossSlot then
        ButtonBossSlot:destroy()
        ButtonBossSlot = nil
    end
    if ButtonBestiary then
        ButtonBestiary:destroy()
        ButtonBestiary = nil
    end
    
    -- Clear character tracking on module termination
    currentCharacter = nil
    
    -- Save items data if available
    if Cyclopedia and Cyclopedia.Items and Cyclopedia.Items.terminate then
        Cyclopedia.Items.terminate()
    end
    
    onTerminateCharm()
end

function hide()
    if not controllerCyclopedia.ui then
        return
    end
    resetCyclopediaTabs()
    controllerCyclopedia.ui:hide()
end

function resetCyclopediaTabs()
    tabStack = {}
    controllerCyclopedia.ui.BackButton:setEnabled(false)
    if previousType then
        local previousWindow = windowTypes[previousType]
        previousWindow.obj:enable()
        previousWindow.obj:setOn(false)
        previousType = nil;
    end
end

function show(defaultWindow)
    if not controllerCyclopedia.ui or not CyclopediaButton then
        return
    end

    controllerCyclopedia.ui:show()
    controllerCyclopedia.ui:raise()
    controllerCyclopedia.ui:focus()
    SelectWindow(defaultWindow, false)
    local player = g_game.getLocalPlayer()
    local totalMoney = player and player:getTotalMoney() or 0
    controllerCyclopedia.ui.GoldBase.Value:setText(Cyclopedia.formatGold(totalMoney))
end

function toggleBack()
    local previousTab = table.remove(tabStack, #tabStack)
    if #tabStack < 1 then
        controllerCyclopedia.ui.BackButton:setEnabled(false)
    end
    SelectWindow(previousTab, true)
end

function SelectWindow(type, isBackButtonPress)
    if not windowTypes[type] then
        type = "items"
    end

    if previousType then
        local previousWindow = windowTypes[previousType]
        if previousWindow and previousWindow.obj then
            previousWindow.obj:enable()
            previousWindow.obj:setOn(false)
        end
        if not isBackButtonPress then
            table.insert(tabStack, previousType)
            controllerCyclopedia.ui.BackButton:setEnabled(true)
        end
    end
    contentContainer:destroyChildren()

    local window = windowTypes[type]
    if window and window.obj and window.obj:isVisible() then
        window.obj:setOn(true)
        window.obj:disable()
        previousType = type
        if window.func then
            window.func(contentContainer)
        end
    end
end

function Cyclopedia.onResourcesBalanceChange()
    if not controllerCyclopedia.ui or not controllerCyclopedia.ui:isVisible() then
        return
    end

    local player = g_game.getLocalPlayer()
    if not player then
        return
    end

    controllerCyclopedia.ui.GoldBase.Value:setText(Cyclopedia.formatGold(player:getTotalMoney()))

    local formatResourceBalance = function(resourceType, maxResourceType)
        return string.format("%d/%d", player:getResourceBalance(resourceType),
            player:getResourceBalance(maxResourceType))
    end

    controllerCyclopedia.ui.CharmsBase.Value:setText(formatResourceBalance(ResourceTypes.CHARM,
        ResourceTypes.MAX_CHARM))

    if controllerCyclopedia.ui.CharmsBase1410:isVisible() then
        controllerCyclopedia.ui.CharmsBase1410.Value:setText(formatResourceBalance(
            ResourceTypes.MINOR_CHARM, ResourceTypes.MAX_MINOR_CHARM))
    end
end
