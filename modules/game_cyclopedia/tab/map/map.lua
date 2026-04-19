local UI = nil
local virtualFloor = 7

local mapFlagFilters = {}
local updateFilterCheckboxState

local function getMapWidget()
    if not UI or not UI.MapBase then
        return nil
    end
    return UI.MapBase.minimap
end

local function getMarkList()
    if not UI or not UI.InformationBase or not UI.InformationBase.InternalBase or
        not UI.InformationBase.InternalBase.DisplayBase then
        return nil
    end
    return UI.InformationBase.InternalBase.DisplayBase.MarkList
end

local function getShowAllBox()
    if not UI or not UI.InformationBase or not UI.InformationBase.InternalBase or
        not UI.InformationBase.InternalBase.DisplayBase then
        return nil
    end
    return UI.InformationBase.InternalBase.DisplayBase.ShowAllBox
end

local function getFilterState(iconId)
    local list = getMarkList()
    if not list then
        return true
    end

    local key = tostring(iconId)
    local widget = list:recursiveGetChildById(key)
    if not widget then
        return true
    end

    return widget:isChecked()
end

local function applyMapFlagFilters()
    local minimapWidget = getMapWidget()
    if not minimapWidget or not minimapWidget.flags then
        return
    end

    local showAllBox = getShowAllBox()
    local showAll = not showAllBox or showAllBox:isChecked()

    for _, flag in pairs(minimapWidget.flags) do
        local visible = true

        if not showAll then
            local iconId = tonumber(flag.icon)
            if iconId ~= nil then
                visible = getFilterState(iconId)
            end
        end

        flag:setVisible(visible)
    end
end

local function resetAndEnableMapFlagFilters()
    local list = getMarkList()
    if not list then
        return
    end

    mapFlagFilters = {}
    for _, child in ipairs(list:getChildren()) do
        local id = tonumber(child:getId())
        if id ~= nil and child.setChecked then
            child:setChecked(true)
            mapFlagFilters[id] = true
        end
    end

    local showAllBox = getShowAllBox()
    if showAllBox then
        showAllBox:setChecked(true)
    end
    
    -- Update visual state based on active marks
    updateFilterCheckboxState()
end

function showMap()
    UI = g_ui.loadUI("map", contentContainer)
    UI:show()
    controllerCyclopedia:registerEvents(LocalPlayer, {
        onPositionChange = Cyclopedia.onUpdateCameraPosition
    }):execute()

    Cyclopedia.prevFloor = 7
    Cyclopedia.loadMap()
    resetAndEnableMapFlagFilters()
    applyMapFlagFilters()

    controllerCyclopedia.ui.CharmsBase:setVisible(false)
    controllerCyclopedia.ui.GoldBase:setVisible(true)
    controllerCyclopedia.ui.BestiaryTrackerButton:setVisible(false)
    if controllerCyclopedia.ui.TaskTrackerButton then
        controllerCyclopedia.ui.TaskTrackerButton:setVisible(false)
    end
    if g_game.getClientVersion() >= 1410 then
        controllerCyclopedia.ui.CharmsBase1410:setVisible(false)
    end

    controllerCyclopedia:registerEvents(g_game, {
        onAddAutomapFlag = Cyclopedia.onAutomapFlagChanged,
        onRemoveAutomapFlag = Cyclopedia.onAutomapFlagChanged
    }):execute()
end

function Cyclopedia.loadMap()
    local minimapWidget = UI.MapBase.minimap
    minimapWidget:load()

    local player = g_game.getLocalPlayer()
    if player and player:getPosition() then
        minimapWidget:setCameraPosition(player:getPosition())
        minimapWidget:setCrossPosition(player:getPosition())
    end
end

function Cyclopedia.CreateMarkItem(Data)
    local MarkItem = g_ui.createWidget("MarkListItem", UI.InformationBase.InternalBase.DisplayBase.MarkList)
    MarkItem:setIcon("/images/game/minimap/flag" .. Data.flagId)
end

function Cyclopedia.toggleMapFlag(widget, checked)
    local iconId = tonumber(widget:getId())
    if iconId ~= nil then
        mapFlagFilters[iconId] = checked
    end

    local showAllBox = getShowAllBox()
    if showAllBox and showAllBox:isChecked() then
        return
    end

    applyMapFlagFilters()
end

function Cyclopedia.showAllFlags(checked)
    local list = getMarkList()
    if not list then
        return
    end

    for _, flag in ipairs(list:getChildren()) do
        if flag and flag.setChecked then
            flag:setChecked(checked)
            local iconId = tonumber(flag:getId())
            if iconId ~= nil then
                mapFlagFilters[iconId] = checked
            end
        end
    end

    applyMapFlagFilters()
end

local function buildActiveIconSet()
    local minimapWidget = getMapWidget()
    if not minimapWidget or not minimapWidget.flags then
        return {}
    end
    
    local activeIcons = {}
    for _, flag in pairs(minimapWidget.flags) do
        if flag and flag.icon then
            activeIcons[tonumber(flag.icon) or 0] = true
        end
    end
    return activeIcons
end

function updateFilterCheckboxState()
    local list = getMarkList()
    if not list then
        return
    end
    
    local activeIcons = buildActiveIconSet()
    local showAllBox = getShowAllBox()
    local showAll = not showAllBox or showAllBox:isChecked()
    
    -- Update each filter checkbox to show enabled state based on whether marks of that type exist
    for _, child in ipairs(list:getChildren()) do
        if child and child.setEnabled then
            local id = tonumber(child:getId())
            if id ~= nil then
                -- Enable checkbox if there are marks of this type, or always enable if showing all
                local hasMarks = activeIcons[id] ~= nil
                local enabled = hasMarks or showAll
                child:setEnabled(enabled)
                
                -- Add subtle visual indicator for active types
                if hasMarks and child:isEnabled() then
                    child:setOpacity(1.0)
                elseif not hasMarks then
                    child:setOpacity(0.6)
                end
            end
        end
    end
end

function Cyclopedia.onAutomapFlagChanged()
    if not UI then
        return
    end

    scheduleEvent(function()
        updateFilterCheckboxState()
        applyMapFlagFilters()
    end, 0)
end

function Cyclopedia.moveMap(widget)
    local distance = 5
    local direction = widget:getId()
    if direction == "n" then
        UI.MapBase.minimap:move(0, distance)
    elseif direction == "ne" then
        UI.MapBase.minimap:move(-distance, distance)
    elseif direction == "e" then
        UI.MapBase.minimap:move(-distance, 0)
    elseif direction == "se" then
        UI.MapBase.minimap:move(-distance, -distance)
    elseif direction == "s" then
        UI.MapBase.minimap:move(0, -distance)
    elseif direction == "sw" then
        UI.MapBase.minimap:move(distance, -distance)
    elseif direction == "w" then
        UI.MapBase.minimap:move(distance, 0)
    elseif direction == "nw" then
        UI.MapBase.minimap:move(distance, distance)
    end
end

function Cyclopedia.floorScrollBar(oldValue, value)
    if value < oldValue then
        UI.MapBase.minimap:floorUp()
    elseif oldValue < value then
        UI.MapBase.minimap:floorDown()
    end

    if value < 0 then
        value = 0
    elseif value > 15 then
        value = 15
    end
end

function ConvertLayer(Value)
    if Value == 150 then
        return 7
    elseif Value == 300 then
        return 15
    elseif Value >= 1 and Value <= 300 then
        return math.floor((Value - 1) / 20)
    else
        return 0
    end
end

function Cyclopedia.onUpdateCameraPosition()
    local player = g_game.getLocalPlayer()
    if not player then
        return
    end

    local pos = player:getPosition()
    if not pos then
        return
    end

    local minimapWidget = UI.MapBase.minimap
    if not minimapWidget:isDragging() then
        if not fullmapView then
            minimapWidget:setCameraPosition(player:getPosition())
        end

        minimapWidget:setCrossPosition(player:getPosition(), true)
    end

    virtualFloor = pos.z
end

function Cyclopedia.onClickRoseButton(dir)
    if dir == 'north' then
        UI.MapBase.minimap:move(0, 1)
    elseif dir == 'north-east' then
        UI.MapBase.minimap:move(-1, 1)
    elseif dir == 'east' then
        UI.MapBase.minimap:move(-1, 0)
    elseif dir == 'south-east' then
        UI.MapBase.minimap:move(-1, -1)
    elseif dir == 'south' then
        UI.MapBase.minimap:move(0, -1)
    elseif dir == 'south-west' then
        UI.MapBase.minimap:move(1, -1)
    elseif dir == 'west' then
        UI.MapBase.minimap:move(1, 0)
    elseif dir == 'north-west' then
        UI.MapBase.minimap:move(1, 1)
    end
end

function Cyclopedia.setZooom(zoom)
    if zoom then
        UI.MapBase.minimap:zoomIn()
    else
        UI.MapBase.minimap:zoomOut()
    end
end

local function refreshVirtualFloors()
    UI.InformationBase.InternalBase.NavigationBase.layersMark:setMarginTop(((virtualFloor + 1) * 4) - 3)
    UI.InformationBase.InternalBase.NavigationBase.automapLayers:setImageClip((virtualFloor * 14) .. ' 0 14 67')
end

function Cyclopedia.downLayer()
    if virtualFloor == 15 then
        return
    end

    UI.MapBase.minimap:floorDown(1)
    virtualFloor = virtualFloor + 1
    refreshVirtualFloors()
end

function Cyclopedia.upLayer()
    if virtualFloor == 0 then
        return
    end

    UI.MapBase.minimap:floorUp(1)
    virtualFloor = virtualFloor - 1
    refreshVirtualFloors()
end
