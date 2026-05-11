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
makeSafeStub("requestTaskTracker")
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

local CYCLOPEDIA_EXT_OPCODE = 31
local CYCLOPEDIA_PROTOCOL_PREFIX = "cp"
local CYCLOPEDIA_PROTOCOL_VERSION = "1"
local CYCLOPEDIA_DEBUG = ClientLog and ClientLog.isEnabled and ClientLog.isEnabled("cyclopedia") or false

-- These remain intentionally disabled until the dedicated rollout phase.
local HARD_DISABLED_TABS = {
    items = true,
    houses = true,
    charms = true,
    bosstiary = true,
    bossSlot = true,
    magicalArchives = true
}

Cyclopedia.Capabilities = {
    items = false,
    bestiary = true,
    map = true,
    houses = false,
    character = true,
    charms = false,
    bosstiary = false,
    bossSlot = false,
    magicalArchives = false
}

Cyclopedia.TransportReady = false
Cyclopedia.PendingRequests = {}
Cyclopedia.PendingRequestSet = {}
Cyclopedia.CapabilitiesRequested = false

local encodeCyclopediaPayload
local decodeCyclopediaPayload

local function getPendingRequestKey(action, payload)
    return string.format("%s\31%s", tostring(action or ""), tostring(payload or ""))
end

local function queueCyclopediaPendingRequest(action, payload)
    local key = getPendingRequestKey(action, payload)
    if Cyclopedia.PendingRequestSet[key] then
        return false
    end

    if #Cyclopedia.PendingRequests >= 100 then
        return false
    end

    Cyclopedia.PendingRequestSet[key] = true
    table.insert(Cyclopedia.PendingRequests, { action = action, payload = payload })
    return true
end

local function flushCyclopediaPendingRequests()
    if not Cyclopedia.TransportReady then
        return
    end

    local protocol = g_game.getProtocolGame()
    if not protocol or not protocol.sendExtendedOpcode then
        return
    end

    for _, req in ipairs(Cyclopedia.PendingRequests) do
        if CYCLOPEDIA_DEBUG then
            print(string.format("[Cyclopedia] flush request action=%s payloadLen=%d", req.action, #(req.payload or "")))
        end
        protocol:sendExtendedOpcode(CYCLOPEDIA_EXT_OPCODE,
            encodeCyclopediaPayload("req", req.action, req.payload))
    end

    Cyclopedia.PendingRequests = {}
    Cyclopedia.PendingRequestSet = {}
end

encodeCyclopediaPayload = function(kind, action, extra)
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

decodeCyclopediaPayload = function(buffer)
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

local function applyTabVisibilityFromCapabilities()
    if not buttonSelection then
        return
    end

    local orderedIds = { "items", "bestiary", "map", "houses", "character", "charms", "bosstiary", "bossSlot", "magicalArchives" }
    for _, id in ipairs(orderedIds) do
        local btn = buttonSelection:recursiveGetChildById(id)
        if btn then
            btn:setVisible(Cyclopedia.Capabilities[id] == true)
        end
    end

    -- Never allow rollout-disabled tabs to become visible.
    enforceHardDisabledTabs()

    if items then
        items:setVisible(false)
    end

    if houses then
        houses:setVisible(false)
    end
end

local function rebalanceTopTabs()
    if not buttonSelection then
        return
    end

    local orderedIds = { "items", "bestiary", "map", "houses", "character", "charms", "bosstiary", "bossSlot", "magicalArchives" }
    local visibleButtons = {}

    for _, id in ipairs(orderedIds) do
        local btn = buttonSelection:recursiveGetChildById(id)
        if btn and btn:isVisible() then
            table.insert(visibleButtons, btn)
        end
    end

    if #visibleButtons == 0 then
        return
    end

    local totalWidth = buttonSelection:getWidth()
    if totalWidth <= 0 then
        return
    end

    local buttonWidth = math.floor(totalWidth / #visibleButtons)
    for i, btn in ipairs(visibleButtons) do
        btn:breakAnchors()
        btn:addAnchor(AnchorTop, "parent", AnchorTop)
        if i == 1 then
            btn:addAnchor(AnchorLeft, "parent", AnchorLeft)
        else
            btn:addAnchor(AnchorLeft, "prev", AnchorRight)
        end
        btn:setWidth(buttonWidth)
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

    applyTabVisibilityFromCapabilities()
    rebalanceTopTabs()
end

function Cyclopedia.requestCapabilities()
    local protocol = g_game.getProtocolGame()
    if not protocol or not protocol.sendExtendedOpcode then
        return
    end

    if Cyclopedia.CapabilitiesRequested then
        return
    end

    Cyclopedia.CapabilitiesRequested = true

    protocol:sendExtendedOpcode(CYCLOPEDIA_EXT_OPCODE,
        encodeCyclopediaPayload("req", "capabilities", ""))
end

function Cyclopedia.onExtendedOpcode(protocol, opcode, buffer)
    if opcode ~= CYCLOPEDIA_EXT_OPCODE then
        return
    end

    if CYCLOPEDIA_DEBUG then
        print(string.format("[Cyclopedia] raw response opcode=%d len=%d buffer=%s", opcode, #(buffer or ""), tostring(buffer or "")))
    end

    local payload = decodeCyclopediaPayload(buffer)
    if not payload or payload.kind ~= "res" then
        if CYCLOPEDIA_DEBUG then
            print("[Cyclopedia] ignored malformed response")
        end
        return
    end

    if CYCLOPEDIA_DEBUG then
        print(string.format("[Cyclopedia] response action=%s status=%s dataLen=%d", payload.action or "?", payload.status or "?", #(payload.data or "")))
    end

    Cyclopedia.TransportReady = true
    flushCyclopediaPendingRequests()

    if payload.action == "capabilities" then
        Cyclopedia.CapabilitiesRequested = false
        -- Keep tab layout static in this client branch. Some servers send
        -- capability payloads that can destabilize tab visibility/anchors.
        return
    end

    if payload.status ~= "ok" then
        return
    end

    local action = payload.action
    local data   = payload.data or ""

    if action == "character.recentDeaths" then
        Cyclopedia.parseAndLoadRecentDeaths(data)
    elseif action == "character.combatStats" then
        Cyclopedia.parseAndLoadCombatStats(data)
    elseif action == "character.recentKills" then
        Cyclopedia.parseAndLoadRecentKills(data)
    elseif action == "character.itemSummary" then
        Cyclopedia.parseAndLoadItemSummary(data)
    elseif action == "character.appearances" then
        Cyclopedia.parseAndLoadAppearances(data)
    elseif action == "character.playtime" then
        Cyclopedia.parseAndLoadPlaytime(data)
    elseif action == "character.accountStatus" then
        local premium = tonumber(data) or 0
        if Cyclopedia.loadCharacterBadges then
            local player = g_game.getLocalPlayer()
            local online = (player and g_game.isOnline()) and 1 or 0
            Cyclopedia.loadCharacterBadges(true, online, premium, "", {})
        end
    elseif action == "character.profileStats" then
        Cyclopedia.parseAndLoadProfileStats(data)
    elseif action == "bestiary.categories" then
        Cyclopedia.parseAndLoadBestiaryCategories(data)
    elseif action == "bestiary.overview" then
        Cyclopedia.parseAndLoadBestiaryOverview(data)
    elseif action == "bestiary.creature" then
        Cyclopedia.parseAndLoadBestiaryCreature(data)
    elseif action == "bestiary.tracker" then
        Cyclopedia.parseAndLoadBestiaryTracker(data)
    elseif action == "tasks.active" then
        Cyclopedia.parseAndLoadTaskTracker(data)
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
        return false, false
    end

    payload = payload or ""

    local shouldSendNow = true
    if action ~= "capabilities" and not Cyclopedia.TransportReady then
        local queued = queueCyclopediaPendingRequest(action, payload)
        if not queued then
            Cyclopedia.requestCapabilities()
            return true, false
        end

        -- Avoid optimistic sends during login handshakes. Queue and flush when
        -- transport becomes ready to reduce bursty request spikes.
        shouldSendNow = false
        Cyclopedia.requestCapabilities()
    end

    if CYCLOPEDIA_DEBUG then
        print(string.format("[Cyclopedia] send request action=%s payloadLen=%d ready=%s", action, #payload, tostring(Cyclopedia.TransportReady)))
    end

    if shouldSendNow then
        protocol:sendExtendedOpcode(CYCLOPEDIA_EXT_OPCODE,
            encodeCyclopediaPayload("req", action, payload))
        return true, true
    end

    return true, false
end

function Cyclopedia.requestHouseTowns()
    local ok, sent = Cyclopedia.sendCyclopediaRequest("houses.towns", "")
    if ok and sent and CYCLOPEDIA_DEBUG then
        print("[Cyclopedia] request houses.towns")
    end
end

-- =========================================================
--  Local-player stat builders (no server round-trip needed)
-- =========================================================

function Cyclopedia.buildAndLoadGeneralStats()
    if not Cyclopedia.loadCharacterGeneralStats then return end
    local player = g_game.getLocalPlayer()
    if not player then return end

    local function safePlayerCall(methodName, default, ...)
        local method = player[methodName]
        if type(method) ~= 'function' then
            return default
        end

        local ok, value = pcall(method, player, ...)
        if not ok or value == nil then
            return default
        end

        return value
    end

    local data = {
        level                  = safePlayerCall('getLevel', 0),
        levelPercent           = safePlayerCall('getLevelPercent', 0),
        baseExpGain            = 100,
        XpBoostPercent         = 0,
        XpBoostBonusRemainingTime = 0,
        staminaMinutes         = safePlayerCall('getStamina', 0),
        maxHealth              = safePlayerCall('getMaxHealth', 0),
        mana                   = safePlayerCall('getMaxMana', 0),
        soul                   = safePlayerCall('getSoul', 0),
        speed                  = safePlayerCall('getSpeed', 0),
        regenerationCondition  = safePlayerCall('getRegenerationTime', 0),
        offlineTrainingTime    = safePlayerCall('getOfflineTrainingTime', 0),
        magicLevel             = safePlayerCall('getMagicLevel', 0),
        magicLevelPercent      = safePlayerCall('getMagicLevelPercent', 0),
        baseMagicLevel         = safePlayerCall('getBaseMagicLevel', 0),
    }

    -- skills[i+1] = {level, baseLevel, percent} for skill id i (Fist=0 ... Fishing=6)
    local skills = {}
    for i = 0, 6 do
        skills[i + 1] = {
            safePlayerCall('getSkillLevel', 0, i),
            safePlayerCall('getSkillBaseLevel', 0, i),
            safePlayerCall('getSkillLevelPercent', 0, i),
        }
    end

    Cyclopedia.loadCharacterGeneralStats(data, skills)
    Cyclopedia.sendCyclopediaRequest("character.playtime", "")
end

function Cyclopedia.buildAndLoadCombatStats()
    if not Cyclopedia.loadCharacterCombatStats then return end
    local player = g_game.getLocalPlayer()
    if not player then return end

    local function safePlayerCall(methodName, default, ...)
        local method = player[methodName]
        if type(method) ~= 'function' then
            return default
        end

        local ok, value = pcall(method, player, ...)
        if not ok or value == nil then
            return default
        end

        return value
    end

    -- Count active blessings from bitmask
    local blessingCount = 0
    local bitmask = safePlayerCall('getBlessings', 0) or 0
    for i = 0, 7 do
        if bit.band(bitmask, bit.lshift(1, i)) ~= 0 then
            blessingCount = blessingCount + 1
        end
    end

    local function getItemText(item)
        if not item then
            return ""
        end

        local parts = {}
        if item.getTooltip then
            local okTooltip, tooltip = pcall(item.getTooltip, item)
            if okTooltip and type(tooltip) == 'string' and tooltip ~= "" then
                table.insert(parts, tooltip)
            end
        end

        if item.getDescription then
            local okDescription, description = pcall(item.getDescription, item)
            if okDescription and type(description) == 'string' and description ~= "" then
                table.insert(parts, description)
            end
        end

        return table.concat(parts, "\n"):lower()
    end

    local function parseFirstNumberByAliases(text, aliases)
        for _, alias in ipairs(aliases) do
            local value = text:match(alias .. "%s*[:=]?%s*([%+%-]?%d+)")
            if value then
                return tonumber(value) or 0
            end
        end
        return 0
    end

    local function parseElementPercent(text, elementKey)
        local value = text:match(elementKey .. "[^%d%+%-]*([%+%-]?%d+)%%")
        if value then
            return tonumber(value) or 0
        end

        value = text:match(elementKey .. "[^%d%+%-]*([%+%-]?%d+)")
        if value then
            return tonumber(value) or 0
        end

        return 0
    end

    local elementByName = {
        fire = 1,
        earth = 2,
        energy = 3,
        ice = 4,
        holy = 5,
        death = 6,
        physical = 0
    }

    local function parseConvertedDamage(text)
        local amount, element = text:match("([%+%-]?%d+)%%?%s*(fire|earth|energy|ice|holy|death)%s*[dD]amage")
        if not amount or not element then
            amount, element = text:match("convert[^%d]*([%+%-]?%d+)%%?[^%a]*(fire|earth|energy|ice|holy|death)")
        end
        if not amount or not element then
            return 0, 0
        end
        return math.max(0, tonumber(amount) or 0), elementByName[element] or 0
    end

    local function encodeReductionPercent(percent)
        local p = tonumber(percent) or 0
        if p >= 0 then
            local encoded = math.floor(p * 100 + 0.5)
            return math.max(0, math.min(65535, encoded))
        end

        local encoded = 65535 - math.floor(math.abs(p) * 100 + 0.5)
        return math.max(0, math.min(65535, encoded))
    end

    local equipped = {}
    for slot = InventorySlotHead, InventorySlotAmmo do
        local item = player:getInventoryItem(slot)
        if item then
            table.insert(equipped, { slot = slot, item = item, text = getItemText(item) })
        end
    end

    local leftItem = player:getInventoryItem(InventorySlotLeft)
    local rightItem = player:getInventoryItem(InventorySlotRight)
    local leftText = getItemText(leftItem)
    local rightText = getItemText(rightItem)

    local attackLeft = parseFirstNumberByAliases(leftText, { "atk", "attack" })
    local attackRight = parseFirstNumberByAliases(rightText, { "atk", "attack" })
    local attackValue = math.max(attackLeft, attackRight)

    local defenseLeft = parseFirstNumberByAliases(leftText, { "def", "defense", "defence" })
    local defenseRight = parseFirstNumberByAliases(rightText, { "def", "defense", "defence" })

    local function isShield(item)
        if not item or not item.getMarketData then
            return false
        end

        local ok, marketData = pcall(function()
            return item:getMarketData()
        end)
        return ok and marketData and tonumber(marketData.category) == 13
    end

    local shieldDefenseValue = 0
    if isShield(leftItem) then
        shieldDefenseValue = math.max(shieldDefenseValue, defenseLeft)
    end
    if isShield(rightItem) then
        shieldDefenseValue = math.max(shieldDefenseValue, defenseRight)
    end

    local defenseItemValue = (shieldDefenseValue > 0) and shieldDefenseValue or math.max(defenseLeft, defenseRight)
    local shieldingLevel = safePlayerCall('getSkillLevel', 0, Skill.Shielding)
    local defenseSkillBonus = math.floor(shieldingLevel / 5)
    local defenseValue = defenseItemValue + defenseSkillBonus

    local armorValue = 0
    for _, info in ipairs(equipped) do
        armorValue = armorValue + math.max(0, parseFirstNumberByAliases(info.text, { "arm", "armor" }))
    end

    -- Formula-aligned armor mitigation estimate for UI (% against a 100-damage benchmark):
    -- Creature::blockHit uses:
    -- armor 1-3 => fixed reduction 1
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

    local averageArmorReduction = getAverageArmorReduction(armorValue)
    local mitigationPercent = math.max(0, math.min(95, averageArmorReduction))

    local convertedDamage, convertedElement = 0, 0
    do
        local c1, e1 = parseConvertedDamage(leftText)
        local c2, e2 = parseConvertedDamage(rightText)
        if c1 >= c2 then
            convertedDamage, convertedElement = c1, e1
        else
            convertedDamage, convertedElement = c2, e2
        end
    end

    local resistByElement = {
        [0] = 0,
        [1] = 0,
        [2] = 0,
        [3] = 0,
        [4] = 0,
        [5] = 0,
        [6] = 0
    }

    for _, info in ipairs(equipped) do
        local text = info.text
        resistByElement[1] = resistByElement[1] + parseElementPercent(text, "fire")
        resistByElement[2] = resistByElement[2] + parseElementPercent(text, "earth")
        resistByElement[3] = resistByElement[3] + parseElementPercent(text, "energy")
        resistByElement[4] = resistByElement[4] + parseElementPercent(text, "ice")
        resistByElement[5] = resistByElement[5] + parseElementPercent(text, "holy")
        resistByElement[6] = resistByElement[6] + parseElementPercent(text, "death")

        local allRes = parseElementPercent(text, "all")
        if allRes ~= 0 then
            for elementId = 1, 6 do
                resistByElement[elementId] = resistByElement[elementId] + allRes
            end
        end
    end

    local reductions = {}
    if mitigationPercent > 0 then
        table.insert(reductions, { 0, encodeReductionPercent(mitigationPercent) })
    end

    for elementId = 1, 6 do
        local value = resistByElement[elementId] or 0
        if value ~= 0 then
            table.insert(reductions, { elementId, encodeReductionPercent(value) })
        end
    end

    -- Infer weapon skill from highest melee skill as fallback heuristic
    local weaponSkillIdFallback = 0
    local bestMeleeLevel = safePlayerCall('getSkillLevel', 0, 0) or 0
    for _, sid in ipairs({1, 2, 3, 4}) do
        local lvl = safePlayerCall('getSkillLevel', 0, sid) or 0
        if lvl > bestMeleeLevel then
            bestMeleeLevel = lvl
            weaponSkillIdFallback = sid
        end
    end

    local data = {
        weaponElement      = 0,
        weaponMaxHitChance = attackValue,
        weaponElementDamage = convertedDamage,
        weaponElementType  = convertedElement,
        defense            = defenseValue,
        defenseItemValue   = defenseItemValue,
        shieldingSkillLevel = shieldingLevel,
        defenseSkillBonus  = defenseSkillBonus,
        armor              = armorValue,
        haveBlessings      = blessingCount,
        weaponSkillId      = weaponSkillIdFallback,
        attackSpeed        = 2000,
    }

    -- CriticalChance=7, CriticalDamage=8, LifeLeechAmount=10, ManaLeechAmount=12
    local additionalSkillsArray = {
        { 7,  safePlayerCall('getSkillLevel', 0, 7)  },
        { 8,  safePlayerCall('getSkillLevel', 0, 8)  },
        { 10, safePlayerCall('getSkillLevel', 0, 10) },
        { 12, safePlayerCall('getSkillLevel', 0, 12) },
    }

    Cyclopedia.loadCharacterCombatStats(data, mitigationPercent, additionalSkillsArray, {}, {}, reductions, {})
end

-- Format:
-- attack,weaponElement,convertedDamage,convertedType,armor,defense,blessings,mitigation,critChance,critDamage,lifeLeech,manaLeech,reductions,weaponSkillId,attackSpeed,shieldDefense,shieldingSkill,weaponSkillLevel
-- reductions format: elementId:percent;elementId:percent;...
function Cyclopedia.parseAndLoadCombatStats(data)
    if not Cyclopedia.loadCharacterCombatStats then
        return
    end

    if not data or data == "" then
        Cyclopedia.buildAndLoadCombatStats()
        return
    end

    local fields = string.split(data, ",")
    if not fields or #fields < 12 then
        Cyclopedia.buildAndLoadCombatStats()
        return
    end

    local function toNumber(value, default)
        local n = tonumber(value)
        if n == nil then
            return default
        end
        return n
    end

    local function encodeReductionPercent(percent)
        local p = toNumber(percent, 0)
        if p >= 0 then
            local encoded = math.floor(p * 100 + 0.5)
            return math.max(0, math.min(65535, encoded))
        end

        local encoded = 65535 - math.floor(math.abs(p) * 100 + 0.5)
        return math.max(0, math.min(65535, encoded))
    end

    local parsedData = {
        weaponMaxHitChance = toNumber(fields[1], 0),
        weaponElement = toNumber(fields[2], 0),
        weaponElementDamage = toNumber(fields[3], 0),
        weaponElementType = toNumber(fields[4], 0),
        armor = toNumber(fields[5], 0),
        defense = toNumber(fields[6], 0),
        defenseItemValue = toNumber(fields[16], 0),
        shieldingSkillLevel = toNumber(fields[17], 0),
        defenseSkillBonus = 0,
        haveBlessings = toNumber(fields[7], 0),
        weaponSkillId = toNumber(fields[14], 0),
        attackSpeed = toNumber(fields[15], 2000),
        weaponSkillLevel = toNumber(fields[18], 0),
    }

    local mitigation = toNumber(fields[8], 0)
    local additionalSkillsArray = {
        { Skill.CriticalChance, toNumber(fields[9], 0) },
        { Skill.CriticalDamage, toNumber(fields[10], 0) },
        { Skill.LifeLeechAmount, toNumber(fields[11], 0) },
        { Skill.ManaLeechAmount, toNumber(fields[12], 0) },
    }

    local reductions = {}
    local reductionRaw = fields[13] or ""
    if reductionRaw ~= "" then
        for _, entry in ipairs(string.split(reductionRaw, ";")) do
            local parts = string.split(entry, ":")
            if parts and #parts >= 2 then
                local elementId = toNumber(parts[1], nil)
                local percent = toNumber(parts[2], 0)
                if elementId ~= nil then
                    table.insert(reductions, { elementId, encodeReductionPercent(percent) })
                end
            end
        end
    end

    Cyclopedia.loadCharacterCombatStats(parsedData, mitigation, additionalSkillsArray, {}, {}, reductions, {})

    if Cyclopedia.onCyclopediaCharacterOffenceStats then
        Cyclopedia.onCyclopediaCharacterOffenceStats({
            weaponAttack = parsedData.weaponMaxHitChance,
            weaponElement = parsedData.weaponElement,
            weaponElementDamage = parsedData.weaponElementDamage,
            weaponSkillType = parsedData.weaponSkillId,
            weaponSkillLevel = parsedData.weaponSkillLevel,
            attackSpeed = parsedData.attackSpeed,
            critChanceTotal = toNumber(fields[9], 0),
            critDamageTotal = toNumber(fields[10], 100),
        })
    end

end

-- =========================================================
--  Override g_game stubs with ext-opcode backed versions
-- =========================================================

local _origRequestCharacterInfo = g_game.requestCharacterInfo
g_game.requestCharacterInfo = function(characterId, infoType, ...)
    local T = CyclopediaCharacterInfoTypes
    if infoType == T.GeneralStats then
        Cyclopedia.buildAndLoadGeneralStats()
        Cyclopedia.sendCyclopediaRequest("character.playtime", "")
        Cyclopedia.sendCyclopediaRequest("character.accountStatus", "")
        Cyclopedia.sendCyclopediaRequest("character.profileStats", "")
    elseif infoType == T.Badges then
        -- Account status is now fetched from server via character.accountStatus request
        Cyclopedia.sendCyclopediaRequest("character.accountStatus", "")
    elseif infoType == T.CombatStats
        or infoType == T.Offencestats
        or infoType == T.Defencestats
        or infoType == T.Miscstats then
        local ok, sent = Cyclopedia.sendCyclopediaRequest("character.combatStats", "")
        if not ok or not sent then
            Cyclopedia.buildAndLoadCombatStats()
        end
    elseif infoType == T.RecentDeaths then
        Cyclopedia.sendCyclopediaRequest("character.recentDeaths", "")
    elseif infoType == T.RecentPVPKills then
        Cyclopedia.sendCyclopediaRequest("character.recentKills", "")
    elseif infoType == T.ItemSummary then
        Cyclopedia.sendCyclopediaRequest("character.itemSummary", "")
    elseif infoType == T.OutfitsAndMounts then
        Cyclopedia.sendCyclopediaRequest("character.appearances", "")
        -- Equipment preview is built locally, no server round-trip needed
        if Cyclopedia.loadEquipmentPreview then
            Cyclopedia.loadEquipmentPreview()
        end
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

g_game.requestBestiarySearch = function(raceId, ...)
    Cyclopedia.sendCyclopediaRequest("bestiary.creature", tostring(raceId or 0))
end

g_game.sendStatusTrackerBestiary = function(raceId, enabled, ...)
    local tracked = enabled and 1 or 0
    if Cyclopedia.updateBestiaryTrackerLocal then
        Cyclopedia.updateBestiaryTrackerLocal(raceId, enabled)
    end
    Cyclopedia.sendCyclopediaRequest("bestiary.tracker", string.format("set,%d,%d", tonumber(raceId) or 0, tracked))
    scheduleEvent(function()
        if g_game.requestBestiaryTracker then
            g_game.requestBestiaryTracker()
        end
    end, 150)
end

g_game.requestBestiaryTracker = function(...)
    Cyclopedia.sendCyclopediaRequest("bestiary.tracker", "list")
end

g_game.requestTaskTracker = function(...)
    Cyclopedia.sendCyclopediaRequest("tasks.active", "")
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
    local kills = {}
    if data and data ~= "" then
        for _, record in ipairs(string.split(data, "~")) do
            local f = string.split(record, ",")
            if f and #f >= 3 then
                table.insert(kills, {
                    timestamp = tonumber(f[1]) or 0,
                    description = f[2] or "",
                    status = f[3] or ""
                })
            end
        end
    end
    Cyclopedia.loadCharacterRecentKills(kills)
end

-- itemSummary is expensive server-side; return empty for now
function Cyclopedia.parseAndLoadItemSummary(data)
    if not Cyclopedia.loadCharacterItems then return end
    local fallback = {
        inventory = {}, store = {}, stash = {}, depot = {}, inbox = {}
    }

    -- 8.60 fallback: at least expose currently equipped items.
    local player = g_game.getLocalPlayer()
    if player and player.getInventoryItem then
        local idx = 1
        for slot = InventorySlotFirst, InventorySlotPurse do
            local item = player:getInventoryItem(slot)
            if item then
                local itemId = item.getId and item:getId() or 0
                local amount = item.getCount and item:getCount() or 1
                if itemId and itemId > 0 then
                    fallback.inventory[idx] = {
                        itemId = itemId,
                        amount = amount and amount > 0 and amount or 1
                    }
                    idx = idx + 1
                end
            end
        end
    end

    Cyclopedia.loadCharacterItems(fallback)
end

-- appearances deferred; return empty
function Cyclopedia.parseAndLoadAppearances(data)
    if not Cyclopedia.loadCharacterAppearances then return end
    local color = { lookHead = 0, lookBody = 0, lookLegs = 0, lookFeet = 0 }
    local outfits = {}

    -- 8.60 fallback: expose current outfit as an appearance entry.
    local player = g_game.getLocalPlayer()
    if player and player.getOutfit then
        local outfit = player:getOutfit()
        if outfit then
            color.lookHead = outfit.head or 0
            color.lookBody = outfit.body or 0
            color.lookLegs = outfit.legs or 0
            color.lookFeet = outfit.feet or 0
            outfits[1] = {
                name = "Current Outfit",
                lookType = outfit.type or 0,
                addons = outfit.addon or 0
            }
        end
    end

    Cyclopedia.loadCharacterAppearances(color, outfits, {}, {})
end

function Cyclopedia.parseAndLoadPlaytime(data)
    if not Cyclopedia.loadCharacterPlaytime then return end
    local parts = string.split(data, ",")
    local seconds = tonumber(parts[1]) or 0
    local regenSecs = tonumber(parts[2]) or 0
    Cyclopedia.loadCharacterPlaytime(seconds)
    -- Feed server-provided food regen into the general stats display
    if Cyclopedia.updateFoodRegen then
        Cyclopedia.updateFoodRegen(regenSecs)
    end
end

function Cyclopedia.parseAndLoadProfileStats(data)
    if not Cyclopedia.updateProfileStats then return end
    local parts = string.split(data or "", ",")
    local totalKills  = tonumber(parts[1]) or 0
    local totalDeaths = tonumber(parts[2]) or 0
    Cyclopedia.updateProfileStats(totalKills, totalDeaths)
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
            local firstUnlock = tonumber(f[12]) or 25
            local secondUnlock = tonumber(f[13]) or 100
            local thirdUnlock = tonumber(f[14]) or 250

            if firstUnlock < 1 then firstUnlock = 1 end
            if secondUnlock <= firstUnlock then secondUnlock = firstUnlock + 1 end
            if thirdUnlock <= secondUnlock then thirdUnlock = secondUnlock + 1 end
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
                killCounter               = kills,
            })
            Cyclopedia.BestiaryCreatureCache[raceId] = {
                id = raceId,
                ocorrence = 1,
                difficulty = 1,
                killCounter = kills,
                thirdDifficulty = firstUnlock,
                secondUnlock = secondUnlock,
                lastProgressKillCount = thirdUnlock,
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

-- Format:
-- id,name,outfitType,currentLevel,killCounter,maxHealth,experience,speed,armor,mitigation,charmValue,location,firstUnlock,secondUnlock,thirdUnlock,loot,combat,difficulty,occurrence,attackMode
-- loot format: itemId:rarityTier:stackable;itemId:rarityTier:stackable;...
-- combat format: physical:fire:earth:energy:ice:holy:death:healing
function Cyclopedia.parseAndLoadBestiaryCreature(data)
    if not Cyclopedia.loadBestiarySelectedCreature then
        return
    end

    if not data or data == "" then
        return
    end

    local f = string.split(data, ",")
    if not f or #f < 12 then
        return
    end

    local raceId     = tonumber(f[1]) or 0
    local name       = f[2] or "Unknown"
    local outfitType = tonumber(f[3]) or 0

    if Cyclopedia._trackerPendingCreatureLookups then
        Cyclopedia._trackerPendingCreatureLookups[raceId] = nil
    end

    _CyclopediaCreatureDataCache[raceId] = {
        name   = name,
        outfit = { type = outfitType, head = 0, body = 0, legs = 0, feet = 0, addons = 0 },
        level = 0, experience = 0, speed = 0, points = tonumber(f[5]) or 0, charm = 0,
        difficulty = 1, occurrence = 0, id = raceId
    }

    local combatValues = {100, 100, 100, 100, 100, 100, 100, 100}
    local combatData = f[17] or ""
    if combatData ~= "" then
        local parts = string.split(combatData, ":")
        for i = 1, 8 do
            local value = tonumber(parts[i])
            if value then
                combatValues[i] = value
            end
        end
    end

    local payload = {
        id = raceId,
        ocorrence = tonumber(f[19]) or 1,
        difficulty = tonumber(f[18]) or 1,
        killCounter = tonumber(f[5]) or 0,
        thirdDifficulty = tonumber(f[13]) or 25,
        secondUnlock = tonumber(f[14]) or 100,
        lastProgressKillCount = tonumber(f[15]) or 250,
        currentLevel = tonumber(f[4]) or 1,
        maxHealth = tonumber(f[6]) or 100,
        experience = tonumber(f[7]) or 50,
        speed = tonumber(f[8]) or 180,
        armor = tonumber(f[9]) or 5,
        mitigation = tonumber(f[10]) or 0,
        charmValue = tonumber(f[11]) or 5,
        attackMode = tonumber(f[20]) or 0,
        combat = combatValues,
        loot = {},
        location = f[12] or "Unknown",
        AnimusMasteryPoints = 0,
        AnimusMasteryBonus = 0,
    }

    local lootData = f[16] or ""
    if lootData ~= "" and lootData ~= "-" then
        for _, entry in ipairs(string.split(lootData, ";")) do
            local parts = string.split(entry, ":")
            if parts and #parts >= 3 then
                local itemId = tonumber(parts[1]) or 0
                if itemId > 0 then
                    table.insert(payload.loot, {
                        name = "",
                        itemId = itemId,
                        type = 0,
                        diffculty = tonumber(parts[2]) or 0,
                        stackable = tonumber(parts[3]) or 0,
                    })
                end
            end
        end
    end

    if payload.thirdDifficulty < 1 then payload.thirdDifficulty = 1 end
    if payload.secondUnlock <= payload.thirdDifficulty then payload.secondUnlock = payload.thirdDifficulty + 1 end
    if payload.lastProgressKillCount <= payload.secondUnlock then payload.lastProgressKillCount = payload.secondUnlock + 1 end

    Cyclopedia.BestiaryCreatureCache = Cyclopedia.BestiaryCreatureCache or {}
    Cyclopedia.BestiaryCreatureCache[raceId] = payload
    Cyclopedia.loadBestiarySelectedCreature(payload)

    if Cyclopedia.storedTrackerData and Cyclopedia.refreshTracker then
        for _, entry in ipairs(Cyclopedia.storedTrackerData) do
            if tonumber(entry[1]) == raceId then
                Cyclopedia.refreshTracker("bestiary")
                break
            end
        end
    end
end

-- bestiary.tracker response
-- Format: raceId,kills,firstUnlock,secondUnlock,thirdUnlock,name,outfitType~...
function Cyclopedia.parseAndLoadBestiaryTracker(data)
    if not Cyclopedia.onParseCyclopediaTracker then
        return
    end

    local trackerEntries = {}
    if data and data ~= "" then
        for _, record in ipairs(string.split(data, "~")) do
            local f = string.split(record, ",")
            if f and #f >= 5 then
                table.insert(trackerEntries, {
                    tonumber(f[1]) or 0,
                    tonumber(f[2]) or 0,
                    tonumber(f[3]) or 25,
                    tonumber(f[4]) or 100,
                    tonumber(f[5]) or 250,
                    f[6] or "",
                    tonumber(f[7]) or 0,
                })
            end
        end
    end

    Cyclopedia.onParseCyclopediaTracker(0, trackerEntries)
end

-- tasks.active response
-- Format: taskId,raceId,progress,firstGoal,secondGoal,required,taskName,creatureName,outfitType,creatures(; separated),completed(0|1)~...
function Cyclopedia.parseAndLoadTaskTracker(data)
    if not Cyclopedia.onParseTaskTracker then
        return
    end

    local trackerEntries = {}
    if data and data ~= "" then
        for _, record in ipairs(string.split(data, "~")) do
            local f = string.split(record, ",")
            if f and #f >= 7 then
                local creatures = {}
                if f[10] and f[10] ~= "" then
                    for _, creature in ipairs(string.split(f[10], ";")) do
                        if creature and creature ~= "" then
                            table.insert(creatures, creature)
                        end
                    end
                elseif f[8] and f[8] ~= "" then
                    table.insert(creatures, f[8])
                end

                table.insert(trackerEntries, {
                    taskId = tonumber(f[1]) or 0,
                    raceId = tonumber(f[2]) or 0,
                    progress = tonumber(f[3]) or 0,
                    firstGoal = tonumber(f[4]) or 1,
                    secondGoal = tonumber(f[5]) or 2,
                    required = tonumber(f[6]) or 3,
                    taskName = f[7] or "Task",
                    creatureName = f[8] or "Unknown creature",
                    outfitType = tonumber(f[9]) or 0,
                    creatures = creatures,
                    completed = (tonumber(f[11]) or 0) == 1,
                })
            end
        end
    end

    Cyclopedia.onParseTaskTracker(trackerEntries)
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
    if CYCLOPEDIA_DEBUG then
        print(string.format("[Cyclopedia] parsed houses.list houses=%d towns=%d", #houses, #townsList))
    end
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
    if CYCLOPEDIA_DEBUG then
        print(string.format("[Cyclopedia] parsed houses.towns count=%d", #towns))
    end
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
trackerMiniWindowTask = nil
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
local ButtonTaskTracker = nil
local tabStack = {}
local previousType = nil
local windowTypes = {}
local magicalArchives = nil

local function purgeWidgetById(id)
    if not id then
        return
    end

    local root = g_ui.getRootWidget and g_ui.getRootWidget()
    if not root then
        return
    end

    -- Remove all stale instances in case the widget was reparented out of topmenu.
    for _ = 1, 20 do
        local widget = root:recursiveGetChildById(id)
        if not widget then
            break
        end
        widget:destroy()
    end
end

local function restoreMiniWindowState(window, defaultClosed)
    if not window then
        return
    end

    local miniWindows = g_settings.getNode('MiniWindows') or {}
    local state = miniWindows[window:getId()]

    if state and state.closed ~= nil then
        if state.closed then
            window:close(true)
        else
            window:open(true)
        end
        return
    end

    if defaultClosed then
        window:close(true)
    end
end

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
        if not controllerCyclopedia.ui then
            return
        end

        Cyclopedia.TransportReady = false
        Cyclopedia.PendingRequests = {}
        Cyclopedia.PendingRequestSet = {}
        Cyclopedia.CapabilitiesRequested = false

        -- Reset session XP tracker on each login
        if Cyclopedia.resetSessionXp then
            Cyclopedia.resetSessionXp()
        end

        safeRegisterCyclopediaOpcode()

        purgeWidgetById('CyclopediaButton')

        CyclopediaButton = modules.client_topmenu.addRightGameToggleButton('CyclopediaButton', tr('Cyclopedia'),
            '/images/topbuttons/cyclopedia', function() toggle("bestiary") end, false, 7)
        CyclopediaButton:setOn(false)

        purgeWidgetById('BestiaryTrackerTopButton')

        ButtonBestiary = modules.client_topmenu.addRightGameToggleButton('BestiaryTrackerTopButton', tr('Bestiary Tracker'),
            '/images/topbuttons/bestiaryTracker', function() Cyclopedia.toggleBestiaryTracker() end, false, 8)
        ButtonBestiary:setOn(false)

        purgeWidgetById('TaskTrackerTopButton')

        ButtonTaskTracker = modules.client_topmenu.addRightGameToggleButton('TaskTrackerTopButton', tr('Task Tracker'),
            '/images/topbuttons/bestiaryTracker', function() Cyclopedia.toggleTaskTracker() end, false, 8)
        ButtonTaskTracker:setOn(false)

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

        if items then
            items:setVisible(false)
        end

        if houses then
            houses:setVisible(false)
            houses:disable()
        end

        windowTypes = {
            bestiary = { obj = bestiary, func = showBestiary },
            map = { obj = map, func = showMap },
            character = { obj = character, func = showCharacter },
        }

        -- Keep a fixed, stable tab layout for this client branch.
        if bestiary then bestiary:setVisible(true) end
        if map then map:setVisible(true) end
        if character then character:setVisible(true) end
        if items then items:setVisible(false) end
        if houses then houses:setVisible(false) end
        if charms then charms:setVisible(false) end
        if bosstiary then bosstiary:setVisible(false) end
        if bossSlot then bossSlot:setVisible(false) end
        if magicalArchives then magicalArchives:setVisible(false) end

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
            trackerMiniWindow:setId('BestiaryTrackerWindow')
            trackerMiniWindow:setText(tr('Bestiary Tracker'))
            trackerMiniWindow:setIcon('/images/icons/icon-bestiarytracker-widget')

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
                if ButtonBestiary then ButtonBestiary:setOn(true) end
                if Cyclopedia.onBestiaryTrackerWindowOpened then
                    Cyclopedia.onBestiaryTrackerWindowOpened()
                end
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
                if ButtonBestiary then ButtonBestiary:setOn(false) end
                if Cyclopedia.onBestiaryTrackerWindowClosed then
                    Cyclopedia.onBestiaryTrackerWindowClosed()
                end
            end

            trackerMiniWindow:setup()
            restoreMiniWindowState(trackerMiniWindow, true)
        end

        --[[===================================================
    =               Tracker Tasks                         =
    =================================================== ]] --

        if not trackerMiniWindowTask then
            trackerMiniWindowTask = g_ui.createWidget('BestiaryTracker', modules.game_interface.getRightPanel())
            trackerMiniWindowTask:setId('TaskTrackerWindow')
            trackerMiniWindowTask:setText(tr('Task Tracker'))
            trackerMiniWindowTask:setIcon('/images/icons/icon-bestiarytracker-widget')

            local contextMenuButtonTask = trackerMiniWindowTask:recursiveGetChildById('contextMenuButton')
            local newWindowButtonTask = trackerMiniWindowTask:recursiveGetChildById('newWindowButton')
            local minimizeButtonTask = trackerMiniWindowTask:recursiveGetChildById('minimizeButton')

            if contextMenuButtonTask then
                contextMenuButtonTask:setVisible(true)
                if minimizeButtonTask then
                    contextMenuButtonTask:breakAnchors()
                    contextMenuButtonTask:addAnchor(AnchorTop, minimizeButtonTask:getId(), AnchorTop)
                    contextMenuButtonTask:addAnchor(AnchorRight, minimizeButtonTask:getId(), AnchorLeft)
                    contextMenuButtonTask:setMarginRight(7)
                    contextMenuButtonTask:setMarginTop(0)
                end

                contextMenuButtonTask.onClick = function(widget, mousePos, mouseButton)
                    return Cyclopedia.createTrackerContextMenu("tasks", mousePos)
                end
            end

            if newWindowButtonTask then
                newWindowButtonTask:setVisible(true)
                newWindowButtonTask.onClick = function(widget, mousePos, mouseButton)
                    toggle("bestiary")
                    return true
                end
            end

            trackerMiniWindowTask.onOpen = function()
                if ButtonTaskTracker then ButtonTaskTracker:setOn(true) end
                scheduleEvent(function()
                    if Cyclopedia.refreshTaskTracker then
                        Cyclopedia.refreshTaskTracker()
                    end
                end, 50)
            end

            trackerMiniWindowTask.onClose = function()
                if ButtonTaskTracker then ButtonTaskTracker:setOn(false) end
            end

            trackerMiniWindowTask:setup()
            restoreMiniWindowState(trackerMiniWindowTask, true)
        end

        --[[===================================================
    =               Tracker Bosstiary                     =
    =================================================== ]] --

        if trackerButtonBosstiary then trackerButtonBosstiary:setOn(false) end
        
        -- Only create if it doesn't exist
        if not trackerMiniWindowBosstiary then
            trackerMiniWindowBosstiary = g_ui.createWidget('BestiaryTracker', modules.game_interface.getRightPanel())
            trackerMiniWindowBosstiary:setId('BosstiaryTrackerWindow')
            trackerMiniWindowBosstiary:setText(tr('Bosstiary Tracker'))

            if g_resources.fileExists('/images/icons/icon-bosstracker-widget.png') then
                trackerMiniWindowBosstiary:setIcon('/images/icons/icon-bosstracker-widget')
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
            restoreMiniWindowState(trackerMiniWindowBosstiary, true)
        end
        if trackerMiniWindow and trackerMiniWindow.setupOnStart then
            trackerMiniWindow:setupOnStart()
        end
        if trackerMiniWindowBosstiary and trackerMiniWindowBosstiary.setupOnStart then
            trackerMiniWindowBosstiary:setupOnStart()
        end
        if trackerMiniWindowTask and trackerMiniWindowTask.setupOnStart then
            trackerMiniWindowTask:setupOnStart()
        end
        Cyclopedia.loadTrackerFilters("bestiary")
        Cyclopedia.loadTrackerFilters("bosstiary")
        Cyclopedia.loadTrackerFilters("tasks")
        
        -- Populate any visible trackers with cached data after windows are set up
        Cyclopedia.populateVisibleTrackersWithCachedData()
        
        -- Also set up proper tracker button states based on window visibility
        if trackerMiniWindow:isVisible() and trackerButton then
            trackerButton:setOn(true)
        end
        if trackerMiniWindow:isVisible() and ButtonBestiary then
            ButtonBestiary:setOn(true)
        end
        if trackerMiniWindowBosstiary:isVisible() and trackerButtonBosstiary then
            trackerButtonBosstiary:setOn(true)
        end
        if trackerMiniWindowTask:isVisible() and ButtonTaskTracker then
            ButtonTaskTracker:setOn(true)
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
                    -- Restart the live refresh polling loop for any tracker windows that
                    -- were open when the player logged out and are still visible now.
                    if Cyclopedia.scheduleTrackerLiveRefresh then
                        local bestiaryVisible = trackerMiniWindow and trackerMiniWindow:isVisible()
                        local taskVisible = trackerMiniWindowTask and trackerMiniWindowTask:isVisible()
                        if bestiaryVisible or taskVisible then
                            Cyclopedia.scheduleTrackerLiveRefresh()
                        end
                    end
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
    -- Stop the live refresh polling loop before tearing down state
    if Cyclopedia.cancelTrackerLiveRefresh then
        Cyclopedia.cancelTrackerLiveRefresh()
    end
    Cyclopedia.TransportReady = false
    Cyclopedia.PendingRequests = {}
    Cyclopedia.PendingRequestSet = {}
    Cyclopedia.CapabilitiesRequested = false

    if trackerMiniWindow then
        trackerMiniWindow.contentsPanel:destroyChildren()
    end
    if trackerMiniWindowBosstiary then
        trackerMiniWindowBosstiary.contentsPanel:destroyChildren()
    end
    if trackerMiniWindowTask then
        trackerMiniWindowTask.contentsPanel:destroyChildren()
    end

    if CyclopediaButton then
        CyclopediaButton:destroy()
        CyclopediaButton = nil
    end

    if ButtonBestiary then
        ButtonBestiary:destroy()
        ButtonBestiary = nil
    end

    if ButtonTaskTracker then
        ButtonTaskTracker:destroy()
        ButtonTaskTracker = nil
    end

    hide()
    
    -- Save tracker filters and data for current character
    if Cyclopedia.saveTrackerFilters then
        Cyclopedia.saveTrackerFilters("bestiary")
        Cyclopedia.saveTrackerFilters("bosstiary")
        Cyclopedia.saveTrackerFilters("tasks")
    end
    
    -- Save current tracker data for current character
    if Cyclopedia.saveTrackerData then
        if Cyclopedia.storedTrackerData then
            Cyclopedia.saveTrackerData("bestiary", Cyclopedia.storedTrackerData)
        end
        if Cyclopedia.storedBosstiaryTrackerData then
            Cyclopedia.saveTrackerData("bosstiary", Cyclopedia.storedBosstiaryTrackerData)
        end
        if Cyclopedia.storedTaskTrackerData then
            Cyclopedia.saveTrackerData("tasks", Cyclopedia.storedTaskTrackerData)
        end
    end
    
    -- Don't clear currentCharacter here - keep it for character change detection
    
    Keybind.delete("Windows", "Show/hide Bosstiary Tracker")
    Keybind.delete("Windows", "Show/hide Bestiary Tracker")
end

function controllerCyclopedia:onTerminate()
    safeUnregisterCyclopediaOpcode()
    Cyclopedia.TransportReady = false
    Cyclopedia.PendingRequests = {}
    Cyclopedia.PendingRequestSet = {}
    Cyclopedia.CapabilitiesRequested = false

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

    if trackerMiniWindowTask then
        trackerMiniWindowTask:destroy()
        trackerMiniWindowTask = nil
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
    if ButtonTaskTracker then
        ButtonTaskTracker:destroy()
        ButtonTaskTracker = nil
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
    if CyclopediaButton then
        CyclopediaButton:setOn(false)
    end
end

function resetCyclopediaTabs()
    tabStack = {}
    controllerCyclopedia.ui.BackButton:setEnabled(false)

    for _, window in pairs(windowTypes) do
        if window and window.obj then
            window.obj:enable()
            window.obj:setOn(false)
        end
    end

    previousType = nil
end

function show(defaultWindow)
    if not controllerCyclopedia.ui or not CyclopediaButton then
        return
    end

    applyTabVisibilityFromCapabilities()
    rebalanceTopTabs()

    controllerCyclopedia.ui:show()
    controllerCyclopedia.ui:raise()
    controllerCyclopedia.ui:focus()
    CyclopediaButton:setOn(true)
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
        type = "bestiary"
    end

    local currentType = previousType

    if previousType then
        if not isBackButtonPress and previousType ~= type then
            table.insert(tabStack, previousType)
            controllerCyclopedia.ui.BackButton:setEnabled(true)
        end
    end

    contentContainer:destroyChildren()

    for _, tabWindow in pairs(windowTypes) do
        if tabWindow and tabWindow.obj then
            tabWindow.obj:enable()
            tabWindow.obj:setOn(false)
        end
    end

    local window = windowTypes[type]
    if window and window.obj and window.obj:isVisible() then
        window.obj:setOn(true)
        window.obj:disable()
        previousType = type
        if window.func then
            window.func(contentContainer)
        end
    else
        previousType = currentType
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
