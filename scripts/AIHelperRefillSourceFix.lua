-- AI Helper Refill Source Fix
-- Keeps the AI helper refill menus synchronized with their underlying source lists.

print("[AI Helper Refill Source Fix] Loaded: syncing AI helper refill source menus.")
AIHelperRefillSourceFix = {}

local originalSetState
local applyVisibleSourceStateToElement

AIHelperRefillSourceSyncEvent = {}
local AIHelperRefillSourceSyncEvent_mt = Class(AIHelperRefillSourceSyncEvent, Event)
InitEventClass(AIHelperRefillSourceSyncEvent, "AIHelperRefillSourceSyncEvent")

AIHelperRefillSourceRequestEvent = {}
local AIHelperRefillSourceRequestEvent_mt = Class(AIHelperRefillSourceRequestEvent, Event)
InitEventClass(AIHelperRefillSourceRequestEvent, "AIHelperRefillSourceRequestEvent")

local function getLoadingStations(isManureSource)
    if g_currentMission == nil then
        return nil
    end

    if isManureSource then
        return g_currentMission.manureLoadingStations
    end

    return g_currentMission.liquidManureLoadingStations
end

local function getStationObjectId(isManureSource, sourceValue)
    if sourceValue == nil or sourceValue <= 2 or NetworkUtil == nil or NetworkUtil.getObjectId == nil then
        return 0
    end

    local stations = getLoadingStations(isManureSource)
    local station = stations ~= nil and stations[sourceValue - 2] or nil
    if station == nil then
        return 0
    end

    return NetworkUtil.getObjectId(station) or 0
end

local function findSourceValueForStationObjectId(isManureSource, stationObjectId, fallbackSourceValue)
    if stationObjectId == nil or stationObjectId == 0 then
        return fallbackSourceValue
    end

    local stations = getLoadingStations(isManureSource)
    if stations == nil then
        return fallbackSourceValue
    end

    local station = nil
    if NetworkUtil ~= nil and NetworkUtil.getObject ~= nil then
        station = NetworkUtil.getObject(stationObjectId)
    end

    if station ~= nil then
        for index, candidate in ipairs(stations) do
            if candidate == station then
                return index + 2
            end
        end
    end

    if NetworkUtil ~= nil and NetworkUtil.getObjectId ~= nil then
        for index, candidate in ipairs(stations) do
            if NetworkUtil.getObjectId(candidate) == stationObjectId then
                return index + 2
            end
        end
    end

    return fallbackSourceValue
end

function AIHelperRefillSourceSyncEvent.emptyNew()
    return Event.new(AIHelperRefillSourceSyncEvent_mt)
end

function AIHelperRefillSourceSyncEvent.new(isManureSource, sourceValue, stationObjectId)
    local self = AIHelperRefillSourceSyncEvent.emptyNew()
    self.isManureSource = isManureSource == true
    self.sourceValue = sourceValue or 1
    self.stationObjectId = stationObjectId or getStationObjectId(self.isManureSource, self.sourceValue)
    return self
end

function AIHelperRefillSourceSyncEvent:readStream(streamId, connection)
    self.isManureSource = streamReadBool(streamId)
    self.sourceValue = streamReadUInt16(streamId)
    self.stationObjectId = NetworkUtil.readNodeObjectId(streamId)
    self:run(connection)
end

function AIHelperRefillSourceSyncEvent:writeStream(streamId, connection)
    streamWriteBool(streamId, self.isManureSource == true)
    streamWriteUInt16(streamId, self.sourceValue or 1)
    NetworkUtil.writeNodeObjectId(streamId, self.stationObjectId or 0)
end

function AIHelperRefillSourceSyncEvent:run(connection)
    local missionInfo = g_currentMission ~= nil and g_currentMission.missionInfo or nil
    if missionInfo == nil then
        return
    end

    local sourceValue = findSourceValueForStationObjectId(
        self.isManureSource,
        self.stationObjectId,
        self.sourceValue)
    local stations = getLoadingStations(self.isManureSource)
    local maxSourceValue = #(stations or {}) + 2
    if sourceValue < 1 or sourceValue > maxSourceValue then
        return
    end

    if self.isManureSource then
        missionInfo.helperManureSource = sourceValue
    else
        missionInfo.helperSlurrySource = sourceValue
    end

    if g_server == nil and applyVisibleSourceStateToElement ~= nil then
        applyVisibleSourceStateToElement(self.isManureSource)
    end

    if g_server ~= nil and connection ~= nil then
        g_server:broadcastEvent(
            AIHelperRefillSourceSyncEvent.new(
                self.isManureSource,
                sourceValue,
                getStationObjectId(self.isManureSource, sourceValue)),
            nil,
            connection,
            nil)
    end
end

function AIHelperRefillSourceRequestEvent.emptyNew()
    return Event.new(AIHelperRefillSourceRequestEvent_mt)
end

function AIHelperRefillSourceRequestEvent.new(isManureSource)
    local self = AIHelperRefillSourceRequestEvent.emptyNew()
    self.isManureSource = isManureSource == true
    return self
end

function AIHelperRefillSourceRequestEvent:readStream(streamId, connection)
    self.isManureSource = streamReadBool(streamId)
    self:run(connection)
end

function AIHelperRefillSourceRequestEvent:writeStream(streamId, connection)
    streamWriteBool(streamId, self.isManureSource == true)
end

function AIHelperRefillSourceRequestEvent:run(connection)
    local missionInfo = g_currentMission ~= nil and g_currentMission.missionInfo or nil
    if g_server == nil or connection == nil or missionInfo == nil then
        return
    end

    local sourceValue
    if self.isManureSource then
        sourceValue = missionInfo.helperManureSource
    else
        sourceValue = missionInfo.helperSlurrySource
    end

    connection:sendEvent(
        AIHelperRefillSourceSyncEvent.new(
            self.isManureSource,
            sourceValue,
            getStationObjectId(self.isManureSource, sourceValue)))
end

local function sendHelperSourceToServer(isManureSource, sourceValue)
    if sourceValue == nil or g_server ~= nil or g_client == nil or g_client.getServerConnection == nil then
        return
    end

    g_client:getServerConnection():sendEvent(
        AIHelperRefillSourceSyncEvent.new(
            isManureSource,
            sourceValue,
            getStationObjectId(isManureSource, sourceValue)))
end

local function shouldRequestHelperSourceFromServer(isManureSource)
    if g_server ~= nil or g_client == nil or g_client.getServerConnection == nil then
        return false
    end

    local requestFlagName = isManureSource and "requestedInitialManureSource" or "requestedInitialSlurrySource"
    if not AIHelperRefillSourceFix[requestFlagName] then
        AIHelperRefillSourceFix[requestFlagName] = true
        return true
    end

    local missionInfo = g_currentMission ~= nil and g_currentMission.missionInfo or nil
    if missionInfo == nil then
        return false
    end

    local sourceValue = isManureSource and missionInfo.helperManureSource or missionInfo.helperSlurrySource
    local stations = getLoadingStations(isManureSource)
    local maxSourceValue = #(stations or {}) + 2

    return sourceValue == nil or sourceValue < 1 or sourceValue > maxSourceValue
end

local function requestHelperSourceFromServer(isManureSource)
    if not shouldRequestHelperSourceFromServer(isManureSource) then
        return
    end

    g_client:getServerConnection():sendEvent(AIHelperRefillSourceRequestEvent.new(isManureSource))
end

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

function applyVisibleSourceStateToElement(isManureSource)
    local missionInfo = g_currentMission ~= nil and g_currentMission.missionInfo or nil
    local element = isManureSource
        and AIHelperRefillSourceFix.manureOptionElement
        or AIHelperRefillSourceFix.slurryOptionElement

    if missionInfo == nil or element == nil or originalSetState == nil then
        return
    end

    local rawState = isManureSource and missionInfo.helperManureSource or missionInfo.helperSlurrySource
    local mappingName = isManureSource and "helperManureTextToStationIndexMapping" or "helperSlurryTextToStationIndexMapping"
    local fallbackState = isManureSource and 1 or rawState
    local visibleState = getVisibleState(element, mappingName, rawState, fallbackState)

    if visibleState ~= nil then
        originalSetState(element, visibleState, false)
    end
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
local function getFillLevelFromSourceStorage(station, storage, fillType, farmId)
    if storage == nil or fillType == nil then
        return 0
    end

    if storage.getIsFillTypeSupported ~= nil and not storage:getIsFillTypeSupported(fillType) then
        return 0
    end

    if station ~= nil
        and station.hasFarmAccessToStorage ~= nil
        and farmId ~= nil
        and not station:hasFarmAccessToStorage(farmId, storage) then
        return 0
    end

    if storage.getFillLevel ~= nil then
        return storage:getFillLevel(fillType) or 0
    end

    return 0
end

local function getStationFillLevel(station, fillType, farmId)
    if station == nil or fillType == nil then
        return 0
    end

    local fillLevel = 0

    for _, storage in pairs(station.sourceStorages or {}) do
        fillLevel = fillLevel + getFillLevelFromSourceStorage(station, storage, fillType, farmId)
    end

    return fillLevel
end

local function stationCanSupplyFillType(station, fillType, farmId)
    return getStationFillLevel(station, fillType, farmId) > 0.000001
end

local function getSprayerLastValidFillType(sprayer, fillUnitIndex)
    if sprayer ~= nil and sprayer.getFillUnitLastValidFillType ~= nil and fillUnitIndex ~= nil then
        return sprayer:getFillUnitLastValidFillType(fillUnitIndex)
    end

    return FillType.UNKNOWN
end

local function getClientExternalSlurryFill(sprayer, inputFillType, dt)
    if g_currentMission == nil
        or g_currentMission.missionInfo == nil
        or g_currentMission.liquidManureLoadingStations == nil
        or g_currentMission.missionInfo.helperSlurrySource <= 2 then
        return FillType.UNKNOWN, 0
    end

    local fillUnitIndex = sprayer:getSprayerFillUnitIndex()
    local allowsLiquidManure = sprayer:getFillUnitAllowsFillType(fillUnitIndex, FillType.LIQUIDMANURE)
    local allowsDigestate = sprayer:getFillUnitAllowsFillType(fillUnitIndex, FillType.DIGESTATE)

    if not allowsLiquidManure and not allowsDigestate then
        return FillType.UNKNOWN, 0
    end

    local loadingStation = g_currentMission.liquidManureLoadingStations[g_currentMission.missionInfo.helperSlurrySource - 2]

    if loadingStation == nil then
        return FillType.UNKNOWN, 0
    end

    local farmId = sprayer:getActiveFarm() or sprayer:getOwnerFarmId()
    local lastValidFillType = getSprayerLastValidFillType(sprayer, fillUnitIndex)
    local preferDigestate = inputFillType == FillType.DIGESTATE or lastValidFillType == FillType.DIGESTATE

    if preferDigestate and allowsDigestate and stationCanSupplyFillType(loadingStation, FillType.DIGESTATE, farmId) then
        return FillType.DIGESTATE, sprayer:getSprayerUsage(FillType.DIGESTATE, dt)
    end

    if allowsLiquidManure and stationCanSupplyFillType(loadingStation, FillType.LIQUIDMANURE, farmId) then
        return FillType.LIQUIDMANURE, sprayer:getSprayerUsage(FillType.LIQUIDMANURE, dt)
    end

    if allowsDigestate and stationCanSupplyFillType(loadingStation, FillType.DIGESTATE, farmId) then
        return FillType.DIGESTATE, sprayer:getSprayerUsage(FillType.DIGESTATE, dt)
    end

    return FillType.UNKNOWN, 0
end

local function getClientExternalManureFill(sprayer, dt)
    if g_currentMission == nil
        or g_currentMission.missionInfo == nil
        or g_currentMission.manureLoadingStations == nil
        or g_currentMission.missionInfo.helperManureSource <= 2 then
        return FillType.UNKNOWN, 0
    end

    local fillUnitIndex = sprayer:getSprayerFillUnitIndex()

    if not sprayer:getFillUnitAllowsFillType(fillUnitIndex, FillType.MANURE) then
        return FillType.UNKNOWN, 0
    end

    local loadingStation = g_currentMission.manureLoadingStations[g_currentMission.missionInfo.helperManureSource - 2]

    if loadingStation == nil then
        return FillType.UNKNOWN, 0
    end

    local farmId = sprayer:getActiveFarm() or sprayer:getOwnerFarmId()

    if stationCanSupplyFillType(loadingStation, FillType.MANURE, farmId) then
        return FillType.MANURE, sprayer:getSprayerUsage(FillType.MANURE, dt)
    end

    return FillType.UNKNOWN, 0
end

Sprayer.getExternalFill = Utils.overwrittenFunction(Sprayer.getExternalFill, function(self, superFunc, fillType, dt)
    if fillType == FillType.DIGESTATE
        and self.isServer
        and g_currentMission ~= nil
        and g_currentMission.missionInfo ~= nil
        and g_currentMission.missionInfo.helperSlurrySource > 2 then
        local loadingStation = g_currentMission.liquidManureLoadingStations[g_currentMission.missionInfo.helperSlurrySource - 2]

        if loadingStation ~= nil then
            local usage = self:getSprayerUsage(FillType.DIGESTATE, dt)
            local farmId = self:getActiveFarm() or self:getOwnerFarmId()
            local remainingDelta = loadingStation:removeFillLevel(FillType.DIGESTATE, usage, farmId)

            if usage - remainingDelta > 0.000001 then
                return FillType.DIGESTATE, usage
            end
        end
    end

    local externalFillType, usage = superFunc(self, fillType, dt)

    if self.isServer or externalFillType ~= FillType.UNKNOWN then
        return externalFillType, usage
    end

    local fillUnitIndex = self:getSprayerFillUnitIndex()
    local supportsSlurryCategory = self:getFillUnitAllowsFillType(fillUnitIndex, FillType.LIQUIDMANURE)
        or self:getFillUnitAllowsFillType(fillUnitIndex, FillType.DIGESTATE)

    if fillType == FillType.LIQUIDMANURE
        or fillType == FillType.DIGESTATE
        or (fillType == FillType.UNKNOWN and supportsSlurryCategory) then
        externalFillType, usage = getClientExternalSlurryFill(self, fillType, dt)

        if externalFillType ~= FillType.UNKNOWN then
            return externalFillType, usage
        end
    end

    if fillType == FillType.MANURE
        or (fillType == FillType.UNKNOWN and self:getFillUnitAllowsFillType(fillUnitIndex, FillType.MANURE)) then
        externalFillType, usage = getClientExternalManureFill(self, dt)

        if externalFillType ~= FillType.UNKNOWN then
            return externalFillType, usage
        end
    end

    return externalFillType, usage
end)
originalSetState = MultiTextOptionElement.setState
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

    if element.id == "multiHelperRefillSlurry" then
        AIHelperRefillSourceFix.slurryOptionElement = element
        requestHelperSourceFromServer(false)
    elseif element.id == "multiHelperRefillManure" then
        AIHelperRefillSourceFix.manureOptionElement = element
        requestHelperSourceFromServer(true)
    end

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

local function syncHelperSourcesAfterClick(element)
    local missionInfo = g_currentMission ~= nil and g_currentMission.missionInfo or nil
    if element == nil or missionInfo == nil then
        return
    end

    if element.id == "multiHelperRefillSlurry" or element.id == "multiHelperRefillManure" then
        sendHelperSourceToServer(false, missionInfo.helperSlurrySource)
        sendHelperSourceToServer(true, missionInfo.helperManureSource)
    end
end

local originalOnRightButtonClicked = MultiTextOptionElement.onRightButtonClicked
MultiTextOptionElement.onRightButtonClicked = function(element, steps, noFocus)
    originalOnRightButtonClicked(element, steps, noFocus)
    syncHelperSourcesAfterClick(element)
end

local originalOnLeftButtonClicked = MultiTextOptionElement.onLeftButtonClicked
MultiTextOptionElement.onLeftButtonClicked = function(element, steps, noFocus)
    originalOnLeftButtonClicked(element, steps, noFocus)
    syncHelperSourcesAfterClick(element)
end


