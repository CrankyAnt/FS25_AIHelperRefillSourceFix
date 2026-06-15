-- AI Helper Refill Source Fix
-- Keeps the AI helper refill menus synchronized with their underlying source lists.

AIHelperRefillSourceFix = {}

local function getActiveFarmId()
    if g_currentMission ~= nil and g_currentMission.getFarmId ~= nil then
        return g_currentMission:getFarmId()
    end

    if g_localPlayer ~= nil then
        return g_localPlayer.farmId
    end

    return nil
end

local function getVisibleState(element, mappingName, rawState, fallbackState)
    if rawState == nil then
        return rawState
    end

    local mapping = element ~= nil
        and element.target ~= nil
        and element.target[mappingName]
        or nil

    for visibleState, mappedRawState in ipairs(mapping or {}) do
        if mappedRawState == rawState then
            return visibleState
        end
    end

    return mapping ~= nil and fallbackState or rawState
end

local function manureStationHasFarmAccess(station, farmId)
    if station == nil or farmId == nil or station.hasFarmAccessToStorage == nil then
        return false
    end

    for _, storage in pairs(station.sourceStorages or {}) do
        local supportsManure = storage ~= nil
            and storage.getIsFillTypeSupported ~= nil
            and storage:getIsFillTypeSupported(FillType.MANURE)

        if supportsManure and station:hasFarmAccessToStorage(farmId, storage) then
            return true
        end
    end

    return false
end

local function filterInaccessibleManureOptions(element)
    if element == nil
        or element.id ~= "multiHelperRefillManure"
        or element.target == nil
        or element.texts == nil
        or g_currentMission == nil then
        return nil
    end

    local farmId = getActiveFarmId()
    local oldMapping = element.target.helperManureTextToStationIndexMapping
    local filteredTexts = {}
    local filteredMapping = {}
    local removedOption = false

    for visibleState, text in ipairs(element.texts) do
        local rawState = oldMapping ~= nil and oldMapping[visibleState] or visibleState
        local keep = rawState <= 2

        if rawState > 2 then
            local station = g_currentMission.manureLoadingStations[rawState - 2]
            keep = manureStationHasFarmAccess(station, farmId)
        end

        if keep then
            table.insert(filteredTexts, text)
            table.insert(filteredMapping, rawState)
        else
            removedOption = true
        end
    end

    if not removedOption then
        return nil
    end

    element.target.helperManureTextToStationIndexMapping = filteredMapping
    return filteredTexts
end

local originalSetState = MultiTextOptionElement.setState
MultiTextOptionElement.setState = function(element, state, forceEvent)
    local visibleState = state
    local missionInfo = g_currentMission ~= nil and g_currentMission.missionInfo or nil

    if element.id == "multiHelperRefillSlurry"
        and missionInfo ~= nil
        and state == missionInfo.helperSlurrySource then
        visibleState = getVisibleState(element, "helperSlurryTextToStationIndexMapping", state, state)
    elseif element.id == "multiHelperRefillManure"
        and missionInfo ~= nil
        and state == missionInfo.helperManureSource then
        visibleState = getVisibleState(element, "helperManureTextToStationIndexMapping", state, 1)
    end

    originalSetState(element, visibleState, forceEvent)
end

local originalSetTexts = MultiTextOptionElement.setTexts
MultiTextOptionElement.setTexts = function(element, texts)
    originalSetTexts(element, texts)

    local filteredTexts = filterInaccessibleManureOptions(element)
    if filteredTexts ~= nil then
        originalSetTexts(element, filteredTexts)

        local missionInfo = g_currentMission ~= nil and g_currentMission.missionInfo or nil
        if missionInfo ~= nil then
            local visibleState = getVisibleState(
                element,
                "helperManureTextToStationIndexMapping",
                missionInfo.helperManureSource,
                1)
            originalSetState(element, visibleState, false)
        end
    end
end
