-- Helper Spreader Refill Debug
-- Diagnostic-only tooling for tracing AI helper liquid manure and manure sources.

AIHelperRefillSourceDebug = {
    MOD_NAME = g_currentModName or "FS25_AIHelperRefillSourceFix",
    TAG = "[AIHelperRefillSourceDebug]",
    CONSOLE_COMMAND = "aiHelperRefillDebug",
    INITIAL_DUMP_DELAY_MS = 5000,
    SNAPSHOT_INTERVAL_MS = 1000,
    FIX_RECONCILE_INTERVAL_MS = 1000,
    ENABLE_EXPERIMENTAL_FIX = false,
    HUD_X = 0.985,
    HUD_Y = 0.875,
    HUD_TEXT_SIZE = 0.0115,
    HUD_LINE_HEIGHT = 0.014,
    HUD_MAX_LINES = 60
}

local AIHelperRefillSourceDebug_mt = Class(AIHelperRefillSourceDebug)
local collectSourceStorages
local storageIsRelevantToLocalFarm

AIHelperRefillDebugToggleEvent = {}
local AIHelperRefillDebugToggleEvent_mt = Class(AIHelperRefillDebugToggleEvent, Event)
InitEventClass(AIHelperRefillDebugToggleEvent, "AIHelperRefillDebugToggleEvent")

function AIHelperRefillDebugToggleEvent.emptyNew()
    return Event.new(AIHelperRefillDebugToggleEvent_mt)
end

function AIHelperRefillDebugToggleEvent.new(enabled)
    local self = AIHelperRefillDebugToggleEvent.emptyNew()
    self.enabled = enabled == true
    return self
end

function AIHelperRefillDebugToggleEvent:writeStream(streamId, connection)
    streamWriteBool(streamId, self.enabled == true)
end

function AIHelperRefillDebugToggleEvent:readStream(streamId, connection)
    self.enabled = streamReadBool(streamId)
    self:run(connection)
end

function AIHelperRefillDebugToggleEvent:run(connection)
    if g_currentMission ~= nil
        and g_currentMission.getIsServer ~= nil
        and g_currentMission:getIsServer()
        and g_aiHelperRefillSourceDebug ~= nil then
        g_aiHelperRefillSourceDebug:setEnabled(self.enabled, "server-event", true)
    end
end

function AIHelperRefillDebugToggleEvent.sendToServer(enabled)
    if g_server == nil and g_client ~= nil and g_client.getServerConnection ~= nil then
        g_client:getServerConnection():sendEvent(AIHelperRefillDebugToggleEvent.new(enabled))
    end
end
local function getFillTypeName(fillType)
    if fillType == nil then
        return "nil"
    end

    if FillType ~= nil and fillType == FillType.UNKNOWN then
        return "UNKNOWN"
    end

    if g_fillTypeManager ~= nil and g_fillTypeManager.getFillTypeNameByIndex ~= nil then
        return g_fillTypeManager:getFillTypeNameByIndex(fillType) or tostring(fillType)
    end

    return tostring(fillType)
end

local function safeCall(object, functionName, fallback)
    if object ~= nil and object[functionName] ~= nil then
        local ok, result = pcall(object[functionName], object)
        if ok and result ~= nil then
            return result
        end
    end

    return fallback
end

local function getNetworkId(object)
    if object == nil or NetworkUtil == nil or NetworkUtil.getObjectId == nil then
        return "n/a"
    end

    local ok, objectId = pcall(NetworkUtil.getObjectId, object)
    if ok and objectId ~= nil then
        return tostring(objectId)
    end

    return "n/a"
end

local function getPlaceableIdentity(placeable)
    if placeable == nil then
        return "no owning placeable"
    end

    local name = safeCall(placeable, "getName", "unnamed")
    local uniqueId = safeCall(placeable, "getUniqueId", placeable.uniqueId or "n/a")
    local configFile = placeable.configFileNameClean or placeable.configFileName or "n/a"

    return string.format("name='%s' uid='%s' config='%s' obj=%s netId=%s",
        tostring(name),
        tostring(uniqueId),
        tostring(configFile),
        tostring(placeable),
        getNetworkId(placeable))
end

local function getLocalFarmId()
    if g_currentMission ~= nil and g_currentMission.getFarmId ~= nil then
        return g_currentMission:getFarmId()
    end

    if g_localPlayer ~= nil then
        return g_localPlayer.farmId
    end

    return nil
end

local function belongsToLocalFarm(object)
    local localFarmId = getLocalFarmId()
    if object == nil or localFarmId == nil then
        return false
    end

    local ownerFarmId = object.ownerFarmId
    if object.getOwnerFarmId ~= nil then
        ownerFarmId = safeCall(object, "getOwnerFarmId", ownerFarmId)
    end

    return ownerFarmId == localFarmId
end

local function getOwnerFarmId(object)
    if object == nil then
        return nil
    end

    return safeCall(object, "getOwnerFarmId", object.ownerFarmId)
end

local function findStorageOwner(storage)
    if storage == nil then
        return nil
    end

    if storage.owningPlaceable ~= nil then
        return storage.owningPlaceable
    end

    local mission = g_currentMission
    local placeables = mission ~= nil
        and mission.placeableSystem ~= nil
        and mission.placeableSystem.placeables
        or nil

    for _, placeable in pairs(placeables or {}) do
        local husbandry = placeable.spec_husbandry
        if husbandry ~= nil and husbandry.storage == storage then
            return placeable
        end

        local silo = placeable.spec_silo
        if silo ~= nil then
            for _, siloStorage in ipairs(silo.storages or {}) do
                if siloStorage == storage then
                    return placeable
                end
            end
        end

        local siloExtension = placeable.spec_siloExtension
        if siloExtension ~= nil and siloExtension.storage == storage then
            return placeable
        end

        local manureHeap = placeable.spec_manureHeap
        if manureHeap ~= nil and manureHeap.manureHeap == storage then
            return placeable
        end
    end

    return storage.placeable
end

local function getStorageIdentity(storage)
    if storage == nil then
        return "nil storage"
    end

    local owner = findStorageOwner(storage)
    local ownerText = owner ~= nil and getPlaceableIdentity(owner) or "owner=unknown"

    return string.format("storageObj=%s netId=%s farmId=%s %s",
        tostring(storage),
        getNetworkId(storage),
        tostring(storage.ownerFarmId or "n/a"),
        ownerText)
end

local function storageBelongsToLocalFarm(storage)
    return belongsToLocalFarm(storage) or belongsToLocalFarm(findStorageOwner(storage))
end

local function stationIsRelevantToLocalFarm(station)
    if station == nil then
        return false
    end

    if belongsToLocalFarm(station) or belongsToLocalFarm(station.owningPlaceable) then
        return true
    end

    for _, entry in ipairs(collectSourceStorages(station)) do
        if storageBelongsToLocalFarm(entry.storage) then
            return true
        end
    end

    return false
end

local function getLoadingStationIdentity(station)
    if station == nil then
        return "nil loading station"
    end

    return string.format("stationObj=%s netId=%s farmId=%s stationName='%s' supportsExtension=%s %s",
        tostring(station),
        getNetworkId(station),
        tostring(station.ownerFarmId or "n/a"),
        tostring(station.stationName or "n/a"),
        tostring(station.supportsExtension),
        getPlaceableIdentity(station.owningPlaceable))
end

local function getLiquidManureLevel(storage)
    if storage == nil or FillType == nil or FillType.LIQUIDMANURE == nil then
        return 0, 0, false
    end

    local supported = storage.getIsFillTypeSupported ~= nil
        and storage:getIsFillTypeSupported(FillType.LIQUIDMANURE)
    local level = storage.getFillLevel ~= nil and storage:getFillLevel(FillType.LIQUIDMANURE) or 0
    local capacity = storage.getCapacity ~= nil and storage:getCapacity(FillType.LIQUIDMANURE) or 0

    return level or 0, capacity or 0, supported == true
end

local function getManureLevel(storage)
    if storage == nil or FillType == nil or FillType.MANURE == nil then
        return 0, 0, false
    end

    local supported = storage.getIsFillTypeSupported ~= nil
        and storage:getIsFillTypeSupported(FillType.MANURE)
    local level = storage.getFillLevel ~= nil and storage:getFillLevel(FillType.MANURE) or 0
    local capacity = storage.getCapacity ~= nil and storage:getCapacity(FillType.MANURE) or 0

    return level or 0, capacity or 0, supported == true
end

collectSourceStorages = function(station)
    local storages = {}
    if station ~= nil and station.sourceStorages ~= nil then
        for key, storage in pairs(station.sourceStorages) do
            table.insert(storages, {key=key, storage=storage})
        end
    end

    return storages
end

local function collectTargetStorages(station)
    local storages = {}
    if station ~= nil and station.targetStorages ~= nil then
        for key, storage in pairs(station.targetStorages) do
            table.insert(storages, {key=key, storage=storage})
        end
    end

    return storages
end

local function findStationIndex(stations, station)
    for index, candidate in ipairs(stations or {}) do
        if candidate == station then
            return index
        end
    end

    return nil
end

local function linkStorageToLoadingStation(storageSystem, storage, loadingStation)
    storageSystem:addStorageToLoadingStation(storage, loadingStation)
    if loadingStation.sourceStorages[storage] ~= nil then
        return "storageSystem"
    end

    -- StorageSystem rejects the first liquid-manure extension when the station
    -- currently only exposes STRAW. Establish the same bidirectional relation
    -- so the station can derive LIQUIDMANURE support from the extension.
    loadingStation.sourceStorages[storage] = storage
    storage:addLoadingStation(loadingStation)

    if g_messageCenter ~= nil
        and MessageType ~= nil
        and MessageType.STORAGE_ADDED_TO_LOADING_STATION ~= nil then
        g_messageCenter:publish(MessageType.STORAGE_ADDED_TO_LOADING_STATION, storage, loadingStation)
    end

    return "forced"
end

local function collectLiquidManureExtensionBugCandidates()
    local candidates = {}
    local mission = g_currentMission
    local placeables = mission ~= nil
        and mission.placeableSystem ~= nil
        and mission.placeableSystem.placeables
        or {}

    for _, placeable in pairs(placeables) do
        local husbandry = placeable.spec_husbandry
        local ownStorage = husbandry ~= nil and husbandry.storage or nil
        local loadingStation = husbandry ~= nil and husbandry.loadingStation or nil
        local unloadingStation = husbandry ~= nil and husbandry.unloadingStation or nil
        local ownLevel, ownCapacity, ownSupports = getLiquidManureLevel(ownStorage)
        local unloadingSupports = unloadingStation ~= nil
            and unloadingStation.getIsFillTypeSupported ~= nil
            and unloadingStation:getIsFillTypeSupported(FillType.LIQUIDMANURE)
        local loadingSupports = loadingStation ~= nil
            and loadingStation.getIsFillTypeSupported ~= nil
            and loadingStation:getIsFillTypeSupported(FillType.LIQUIDMANURE)

        if ownSupports
            and ownCapacity <= 0.0001
            and unloadingSupports
            and not loadingSupports
            and loadingStation ~= nil
            and loadingStation.supportsExtension == true then
            for _, targetEntry in ipairs(collectTargetStorages(unloadingStation)) do
                local storage = targetEntry.storage
                local owner = findStorageOwner(storage)
                local _, capacity, supports = getLiquidManureLevel(storage)
                local isSiloExtension = owner ~= nil and owner.spec_siloExtension ~= nil
                local sameFarm = getOwnerFarmId(placeable) == getOwnerFarmId(owner)

                if supports
                    and capacity > 0.0001
                    and isSiloExtension
                    and sameFarm
                    and loadingStation.sourceStorages[storage] == nil then
                    table.insert(candidates, {
                        placeable = placeable,
                        loadingStation = loadingStation,
                        unloadingStation = unloadingStation,
                        ownStorage = ownStorage,
                        ownLevel = ownLevel,
                        extensionStorage = storage
                    })
                end
            end
        end
    end

    return candidates
end

storageIsRelevantToLocalFarm = function(storage)
    if storageBelongsToLocalFarm(storage) then
        return true
    end

    local mission = g_currentMission
    for _, station in ipairs(mission ~= nil and mission.liquidManureLoadingStations or {}) do
        if belongsToLocalFarm(station) or belongsToLocalFarm(station.owningPlaceable) then
            for _, entry in ipairs(collectSourceStorages(station)) do
                if entry.storage == storage then
                    return true
                end
            end
        end
    end

    local placeables = mission ~= nil
        and mission.placeableSystem ~= nil
        and mission.placeableSystem.placeables
        or {}
    for _, placeable in pairs(placeables) do
        if belongsToLocalFarm(placeable) then
            local husbandry = placeable.spec_husbandry
            local station = husbandry ~= nil and husbandry.loadingStation or nil
            for _, entry in ipairs(collectSourceStorages(station)) do
                if entry.storage == storage then
                    return true
                end
            end
        end
    end

    return false
end

local function collectAllLiquidManureStorages(localFarmOnly)
    local result = {}
    local seen = {}
    local mission = g_currentMission

    local function add(storage, origin)
        if type(storage) ~= "table" or seen[storage] then
            return
        end

        local _, _, supported = getLiquidManureLevel(storage)
        if supported then
            seen[storage] = true
            table.insert(result, {storage=storage, origin=origin})
        end
    end

    if mission ~= nil then
        local storageSystem = mission.storageSystem
        if storageSystem ~= nil and storageSystem.storages ~= nil then
            for _, storage in pairs(storageSystem.storages) do
                add(storage, "storageSystem")
            end
        end

        for _, station in ipairs(mission.liquidManureLoadingStations or {}) do
            for _, entry in ipairs(collectSourceStorages(station)) do
                add(entry.storage, "sourceStorage")
            end
        end

        local placeables = mission.placeableSystem ~= nil and mission.placeableSystem.placeables or {}
        for _, placeable in pairs(placeables or {}) do
            local husbandry = placeable.spec_husbandry
            add(husbandry ~= nil and husbandry.storage or nil, "husbandry")

            local silo = placeable.spec_silo
            for _, storage in ipairs(silo ~= nil and silo.storages or {}) do
                add(storage, "silo")
            end

            local siloExtension = placeable.spec_siloExtension
            add(siloExtension ~= nil and siloExtension.storage or nil, "siloExtension")
        end
    end

    table.sort(result, function(a, b)
        return tostring(a.storage) < tostring(b.storage)
    end)

    if localFarmOnly then
        local filtered = {}
        for _, entry in ipairs(result) do
            if storageIsRelevantToLocalFarm(entry.storage) then
                table.insert(filtered, entry)
            end
        end
        return filtered
    end

    return result
end

local function collectAllManureStorages(localFarmOnly)
    local result = {}
    local seen = {}
    local mission = g_currentMission

    local function add(storage, origin)
        if type(storage) ~= "table" or seen[storage] then
            return
        end

        local _, _, supported = getManureLevel(storage)
        if supported then
            seen[storage] = true
            table.insert(result, {storage=storage, origin=origin})
        end
    end

    if mission ~= nil then
        local storageSystem = mission.storageSystem
        if storageSystem ~= nil and storageSystem.storages ~= nil then
            for _, storage in pairs(storageSystem.storages) do
                add(storage, "storageSystem")
            end
        end

        for _, station in ipairs(mission.manureLoadingStations or {}) do
            for _, entry in ipairs(collectSourceStorages(station)) do
                add(entry.storage, "sourceStorage")
            end
        end

        local placeables = mission.placeableSystem ~= nil and mission.placeableSystem.placeables or {}
        for _, placeable in pairs(placeables or {}) do
            local husbandry = placeable.spec_husbandry
            add(husbandry ~= nil and husbandry.storage or nil, "husbandry")

            local silo = placeable.spec_silo
            for _, storage in ipairs(silo ~= nil and silo.storages or {}) do
                add(storage, "silo")
            end

            local siloExtension = placeable.spec_siloExtension
            add(siloExtension ~= nil and siloExtension.storage or nil, "siloExtension")

            local manureHeap = placeable.spec_manureHeap
            add(manureHeap ~= nil and manureHeap.manureHeap or nil, "manureHeap")
        end
    end

    table.sort(result, function(a, b)
        return tostring(a.storage) < tostring(b.storage)
    end)

    if localFarmOnly then
        local filtered = {}
        for _, entry in ipairs(result) do
            if storageIsRelevantToLocalFarm(entry.storage) then
                table.insert(filtered, entry)
            end
        end
        return filtered
    end

    return result
end

local function collectHusbandryLoadingStations(localFarmOnly)
    local result = {}
    local mission = g_currentMission
    local registered = {}

    for index, station in ipairs(mission ~= nil and mission.liquidManureLoadingStations or {}) do
        registered[station] = index
    end

    local placeables = mission ~= nil
        and mission.placeableSystem ~= nil
        and mission.placeableSystem.placeables
        or {}

    for _, placeable in pairs(placeables) do
        local husbandry = placeable.spec_husbandry
        if husbandry ~= nil and (not localFarmOnly or belongsToLocalFarm(placeable)) then
            local station = husbandry.loadingStation
            local unloadingStation = husbandry.unloadingStation
            local storage = husbandry.storage
            local stationSupports = station ~= nil
                and station.getIsFillTypeSupported ~= nil
                and station:getIsFillTypeSupported(FillType.LIQUIDMANURE)
                or false
            local storageLevel, storageCapacity, storageSupports = getLiquidManureLevel(storage)

            table.insert(result, {
                placeable = placeable,
                station = station,
                unloadingStation = unloadingStation,
                ownStorage = storage,
                registeredIndex = registered[station],
                stationSupports = stationSupports,
                storageSupports = storageSupports,
                storageLevel = storageLevel,
                storageCapacity = storageCapacity,
                sourceStorages = collectSourceStorages(station),
                targetStorages = collectTargetStorages(unloadingStation)
            })
        end
    end

    table.sort(result, function(a, b)
        return tostring(safeCall(a.placeable, "getName", "")) < tostring(safeCall(b.placeable, "getName", ""))
    end)

    return result
end

local function getVehicleIdentity(vehicle)
    if vehicle == nil then
        return "nil vehicle"
    end

    return string.format("name='%s' config='%s' obj=%s netId=%s",
        tostring(safeCall(vehicle, "getName", "unnamed")),
        tostring(vehicle.configFileNameClean or vehicle.configFileName or "n/a"),
        tostring(vehicle),
        getNetworkId(vehicle))
end

local function getSprayerFillDiagnostics(vehicle)
    if vehicle == nil or vehicle.spec_sprayer == nil then
        return "not a sprayer"
    end

    local fillUnitIndex = vehicle:getSprayerFillUnitIndex()
    local fillType = vehicle:getFillUnitFillType(fillUnitIndex)
    local lastValidFillType = vehicle:getFillUnitLastValidFillType(fillUnitIndex)
    local fillLevel = vehicle:getFillUnitFillLevel(fillUnitIndex)
    local capacity = vehicle:getFillUnitCapacity(fillUnitIndex)
    local spec = vehicle.spec_sprayer
    local rootVehicle = vehicle.rootVehicle
    local isTurnedOn = vehicle.getIsTurnedOn ~= nil and vehicle:getIsTurnedOn() or "n/a"
    local isFieldWorkActive = rootVehicle ~= nil
        and rootVehicle.getIsFieldWorkActive ~= nil
        and rootVehicle:getIsFieldWorkActive()
        or "n/a"
    local activeSprayType = vehicle:getActiveSprayType()

    return string.format(
        "fillUnit=%s level=%.3f capacity=%.3f fillType=%s lastValid=%s activeSprayType=%s turnedOn=%s fieldWorkActive=%s allows[LM=%s DIGESTATE=%s MANURE=%s LFERT=%s FERT=%s] flags[slurry=%s manure=%s fertilizer=%s]",
        tostring(fillUnitIndex),
        fillLevel or 0,
        capacity or 0,
        getFillTypeName(fillType),
        getFillTypeName(lastValidFillType),
        tostring(activeSprayType),
        tostring(isTurnedOn),
        tostring(isFieldWorkActive),
        tostring(vehicle:getFillUnitAllowsFillType(fillUnitIndex, FillType.LIQUIDMANURE)),
        tostring(vehicle:getFillUnitAllowsFillType(fillUnitIndex, FillType.DIGESTATE)),
        tostring(vehicle:getFillUnitAllowsFillType(fillUnitIndex, FillType.MANURE)),
        tostring(vehicle:getFillUnitAllowsFillType(fillUnitIndex, FillType.LIQUIDFERTILIZER)),
        tostring(vehicle:getFillUnitAllowsFillType(fillUnitIndex, FillType.FERTILIZER)),
        tostring(spec.isSlurryTanker),
        tostring(spec.isManureSpreader),
        tostring(spec.isFertilizerSprayer))
end

local function collectActiveAISprayers()
    local result = {}
    local mission = g_currentMission
    local vehicles = mission ~= nil
        and mission.vehicleSystem ~= nil
        and mission.vehicleSystem.vehicles
        or {}

    for _, vehicle in pairs(vehicles) do
        if vehicle.spec_sprayer ~= nil and vehicle.getIsAIActive ~= nil and vehicle:getIsAIActive() then
            table.insert(result, vehicle)
        end
    end

    table.sort(result, function(a, b)
        return tostring(safeCall(a, "getName", "")) < tostring(safeCall(b, "getName", ""))
    end)

    return result
end

function AIHelperRefillSourceDebug.new()
    local self = setmetatable({}, AIHelperRefillSourceDebug_mt)
    self.enabled = false
    self.missionElapsedMs = 0
    self.snapshotElapsedMs = 0
    self.fixElapsedMs = 0
    self.initialDumpDone = false
    self.lastSnapshotKey = nil
    self.hudLines = {}
    self.removalEvents = {}
    self.externalFillEvents = {}
    self.lastOutOfFillLogTime = {}
    self.fixedSourceLinks = setmetatable({}, {__mode="k"})
    self.fixedRegistrations = setmetatable({}, {__mode="k"})
    return self
end

function AIHelperRefillSourceDebug:loadMap()
    addConsoleCommand(
        self.CONSOLE_COMMAND,
        "Toggle AI helper refill source diagnostics",
        "consoleCommandToggle",
        self)
    self.missionElapsedMs = 0
    self.snapshotElapsedMs = 0
    self.fixElapsedMs = 0
    self.initialDumpDone = false
    self.lastSnapshotKey = nil
    self.hudLines = {}
    self.removalEvents = {}
    self.externalFillEvents = {}
    self.lastOutOfFillLogTime = {}
    self.fixedSourceLinks = setmetatable({}, {__mode="k"})
    self.fixedRegistrations = setmetatable({}, {__mode="k"})
end

function AIHelperRefillSourceDebug:deleteMap()
    removeConsoleCommand(self.CONSOLE_COMMAND)
    self.hudLines = {}
    self.removalEvents = {}
    self.externalFillEvents = {}
    self.lastOutOfFillLogTime = {}
    self.fixedSourceLinks = setmetatable({}, {__mode="k"})
    self.fixedRegistrations = setmetatable({}, {__mode="k"})
end

function AIHelperRefillSourceDebug:setEnabled(enabled, reason, skipServerRequest)
    self.enabled = enabled == true
    self.missionElapsedMs = 0
    self.snapshotElapsedMs = 0
    self.initialDumpDone = false
    self.lastSnapshotKey = nil
    self.hudLines = {}
    self.removalEvents = {}
    self.externalFillEvents = {}
    self.lastOutOfFillLogTime = {}

    if not skipServerRequest then
        AIHelperRefillDebugToggleEvent.sendToServer(self.enabled)
    end

    if self.enabled then
        self:log("Diagnostics enabled reason=%s", tostring(reason or "manual"))
        self:dumpState(reason or "enabled")
        self.initialDumpDone = true
        self.lastSnapshotKey = self:buildSnapshotKey()
        self.hudLines = self:buildHud()
        return "AI helper refill source diagnostics enabled"
    end

    self:log("Diagnostics disabled reason=%s", tostring(reason or "manual"))
    return "AI helper refill source diagnostics disabled"
end

function AIHelperRefillSourceDebug:consoleCommandToggle()
    return self:setEnabled(not self.enabled, "console-command", false)
end
function AIHelperRefillSourceDebug:log(message, ...)
    print(string.format("%s %s", self.TAG, string.format(message, ...)))
end

function AIHelperRefillSourceDebug:getSelectedSource()
    local mission = g_currentMission
    if mission == nil or mission.missionInfo == nil then
        return nil, nil, nil
    end

    local helperValue = mission.missionInfo.helperSlurrySource
    local stationIndex = helperValue ~= nil and helperValue - 2 or nil
    local station = stationIndex ~= nil
        and stationIndex > 0
        and mission.liquidManureLoadingStations ~= nil
        and mission.liquidManureLoadingStations[stationIndex]
        or nil

    return helperValue, stationIndex, station
end

function AIHelperRefillSourceDebug:getSelectedManureSource()
    local mission = g_currentMission
    if mission == nil or mission.missionInfo == nil then
        return nil, nil, nil
    end

    local helperValue = mission.missionInfo.helperManureSource
    local stationIndex = helperValue ~= nil and helperValue - 2 or nil
    local station = stationIndex ~= nil
        and stationIndex > 0
        and mission.manureLoadingStations ~= nil
        and mission.manureLoadingStations[stationIndex]
        or nil

    return helperValue, stationIndex, station
end

function AIHelperRefillSourceDebug:reconcileLiquidManureHusbandries()
    if not self.ENABLE_EXPERIMENTAL_FIX then
        return
    end

    local mission = g_currentMission
    local storageSystem = mission ~= nil and mission.storageSystem or nil
    local placeables = mission ~= nil
        and mission.placeableSystem ~= nil
        and mission.placeableSystem.placeables
        or nil

    if storageSystem == nil or placeables == nil or FillType == nil or FillType.LIQUIDMANURE == nil then
        return
    end

    for _, placeable in pairs(placeables) do
        local husbandry = placeable.spec_husbandry
        local loadingStation = husbandry ~= nil and husbandry.loadingStation or nil
        local unloadingStation = husbandry ~= nil and husbandry.unloadingStation or nil
        local ownStorage = husbandry ~= nil and husbandry.storage or nil
        local husbandrySupportsLiquidManure = unloadingStation ~= nil
            and unloadingStation.getIsFillTypeSupported ~= nil
            and unloadingStation:getIsFillTypeSupported(FillType.LIQUIDMANURE)
        local ownStorageSupportsLiquidManure = ownStorage ~= nil
            and ownStorage.getIsFillTypeSupported ~= nil
            and ownStorage:getIsFillTypeSupported(FillType.LIQUIDMANURE)

        if loadingStation ~= nil
            and loadingStation.supportsExtension == true
            and unloadingStation ~= nil
            and husbandrySupportsLiquidManure
            and ownStorageSupportsLiquidManure then
            for _, targetEntry in ipairs(collectTargetStorages(unloadingStation)) do
                local storage = targetEntry.storage
                local supportsLiquidManure = storage ~= nil
                    and storage.getIsFillTypeSupported ~= nil
                    and storage:getIsFillTypeSupported(FillType.LIQUIDMANURE)

                if supportsLiquidManure and loadingStation.sourceStorages[storage] == nil then
                    local linkMethod = linkStorageToLoadingStation(storageSystem, storage, loadingStation)
                    self.fixedSourceLinks[storage] = loadingStation
                    self:log("FIX_LINKED_LIQUID_MANURE_SOURCE method=%s placeable=%s loadingStation=%s storage=%s",
                        tostring(linkMethod),
                        getPlaceableIdentity(placeable),
                        getLoadingStationIdentity(loadingStation),
                        getStorageIdentity(storage))
                end
            end

            local stations = mission.liquidManureLoadingStations or {}
            local registeredIndex = findStationIndex(stations, loadingStation)
            if loadingStation:getIsFillTypeSupported(FillType.LIQUIDMANURE) and registeredIndex == nil then
                mission:addLiquidManureLoadingStation(loadingStation)
                self.fixedRegistrations[loadingStation] = true
                self:log("FIX_REGISTERED_LIQUID_MANURE_HELPER_SOURCE index=%s placeable=%s loadingStation=%s",
                    tostring(findStationIndex(mission.liquidManureLoadingStations, loadingStation)),
                    getPlaceableIdentity(placeable),
                    getLoadingStationIdentity(loadingStation))
            end
        end
    end
end

function AIHelperRefillSourceDebug:buildSnapshotKey()
    local mission = g_currentMission
    if mission == nil then
        return "noMission"
    end

    local helperValue = mission.missionInfo ~= nil and mission.missionInfo.helperSlurrySource or "nil"
    local manureHelperValue = mission.missionInfo ~= nil and mission.missionInfo.helperManureSource or "nil"
    local parts = {
        tostring(helperValue),
        tostring(#(mission.liquidManureLoadingStations or {})),
        tostring(manureHelperValue),
        tostring(#(mission.manureLoadingStations or {}))
    }

    for index, station in ipairs(mission.liquidManureLoadingStations or {}) do
        table.insert(parts, string.format("%d:%s:%d", index, tostring(station), #collectSourceStorages(station)))
    end

    for index, station in ipairs(mission.manureLoadingStations or {}) do
        table.insert(parts, string.format("M%d:%s:%d", index, tostring(station), #collectSourceStorages(station)))
    end

    return table.concat(parts, "|")
end

function AIHelperRefillSourceDebug:dumpState(reason)
    local mission = g_currentMission
    if mission == nil then
        return
    end

    local helperValue, stationIndex, selectedStation = self:getSelectedSource()
    local stations = mission.liquidManureLoadingStations or {}
    local allStorages = collectAllLiquidManureStorages()

    self:log("STATE DUMP reason='%s' isServer=%s isClient=%s helperSlurrySource=%s resolvedStationIndex=%s stationCount=%d selected=%s",
        tostring(reason),
        tostring(g_server ~= nil),
        tostring(g_client ~= nil),
        tostring(helperValue),
        tostring(stationIndex),
        #stations,
        getLoadingStationIdentity(selectedStation))

    for index, station in ipairs(stations) do
        local sourceStorages = collectSourceStorages(station)
        self:log("SOURCE index=%d helperValue=%d selected=%s sourceStorageCount=%d %s",
            index,
            index + 2,
            tostring(station == selectedStation),
            #sourceStorages,
            getLoadingStationIdentity(station))

        for sourceIndex, entry in ipairs(sourceStorages) do
            local level, capacity, supported = getLiquidManureLevel(entry.storage)
            self:log("SOURCE_STORAGE sourceIndex=%d key=%s liquidManureSupported=%s level=%.3f capacity=%.3f %s",
                sourceIndex,
                tostring(entry.key),
                tostring(supported),
                level,
                capacity,
                getStorageIdentity(entry.storage))
        end
    end

    for index, entry in ipairs(allStorages) do
        local level, capacity = getLiquidManureLevel(entry.storage)
        self:log("ALL_STORAGE index=%d origin=%s level=%.3f capacity=%.3f %s",
            index,
            tostring(entry.origin),
            level,
            capacity,
            getStorageIdentity(entry.storage))
    end

    for index, entry in ipairs(collectHusbandryLoadingStations()) do
        self:log("HUSBANDRY_STATION index=%d registeredIndex=%s stationSupportsLiquidManure=%s ownStorageSupportsLiquidManure=%s ownLevel=%.3f ownCapacity=%.3f sourceStorageCount=%d targetStorageCount=%d placeable=%s loadingStation=%s unloadingStation=%s",
            index,
            tostring(entry.registeredIndex),
            tostring(entry.stationSupports),
            tostring(entry.storageSupports),
            entry.storageLevel,
            entry.storageCapacity,
            #entry.sourceStorages,
            #entry.targetStorages,
            getPlaceableIdentity(entry.placeable),
            getLoadingStationIdentity(entry.station),
            getLoadingStationIdentity(entry.unloadingStation))

        for sourceIndex, sourceEntry in ipairs(entry.sourceStorages) do
            local level, capacity, supported = getLiquidManureLevel(sourceEntry.storage)
            self:log("HUSBANDRY_SOURCE_STORAGE husbandryIndex=%d sourceIndex=%d liquidManureSupported=%s level=%.3f capacity=%.3f %s",
                index,
                sourceIndex,
                tostring(supported),
                level,
                capacity,
                getStorageIdentity(sourceEntry.storage))
        end

        for targetIndex, targetEntry in ipairs(entry.targetStorages) do
            local level, capacity, supported = getLiquidManureLevel(targetEntry.storage)
            self:log("HUSBANDRY_TARGET_STORAGE husbandryIndex=%d targetIndex=%d liquidManureSupported=%s level=%.3f capacity=%.3f %s",
                index,
                targetIndex,
                tostring(supported),
                level,
                capacity,
                getStorageIdentity(targetEntry.storage))
        end
    end

    for index, candidate in ipairs(collectLiquidManureExtensionBugCandidates()) do
        self:log("LIQUID_MANURE_EXTENSION_BUG_CANDIDATE index=%d ownLevel=%.3f placeable=%s loadingStation=%s extension=%s",
            index,
            candidate.ownLevel,
            getPlaceableIdentity(candidate.placeable),
            getLoadingStationIdentity(candidate.loadingStation),
            getStorageIdentity(candidate.extensionStorage))
    end

    local manureHelperValue, manureStationIndex, selectedManureStation = self:getSelectedManureSource()
    local manureStations = mission.manureLoadingStations or {}
    self:log("MANURE STATE DUMP reason='%s' helperManureSource=%s resolvedStationIndex=%s stationCount=%d selected=%s",
        tostring(reason),
        tostring(manureHelperValue),
        tostring(manureStationIndex),
        #manureStations,
        getLoadingStationIdentity(selectedManureStation))

    for index, station in ipairs(manureStations) do
        local sourceStorages = collectSourceStorages(station)
        self:log("MANURE_SOURCE index=%d helperValue=%d selected=%s sourceStorageCount=%d %s",
            index,
            index + 2,
            tostring(station == selectedManureStation),
            #sourceStorages,
            getLoadingStationIdentity(station))

        for sourceIndex, entry in ipairs(sourceStorages) do
            local level, capacity, supported = getManureLevel(entry.storage)
            self:log("MANURE_SOURCE_STORAGE sourceIndex=%d key=%s manureSupported=%s level=%.3f capacity=%.3f %s",
                sourceIndex,
                tostring(entry.key),
                tostring(supported),
                level,
                capacity,
                getStorageIdentity(entry.storage))
        end
    end

    for index, entry in ipairs(collectAllManureStorages()) do
        local level, capacity = getManureLevel(entry.storage)
        self:log("ALL_MANURE_STORAGE index=%d origin=%s level=%.3f capacity=%.3f %s",
            index,
            tostring(entry.origin),
            level,
            capacity,
            getStorageIdentity(entry.storage))
    end
end

function AIHelperRefillSourceDebug:buildHud()
    local mission = g_currentMission
    local lines = {}
    if mission == nil then
        return lines
    end

    local helperValue, stationIndex, selectedStation = self:getSelectedSource()
    local stations = mission.liquidManureLoadingStations or {}

    table.insert(lines, "LIQUID MANURE HELPER DEBUG")
    table.insert(lines, string.format("helperSlurrySource=%s -> stationIndex=%s | registered sources=%d",
        tostring(helperValue), tostring(stationIndex), #stations))

    if helperValue == 1 then
        table.insert(lines, "Selected: OFF")
    elseif helperValue == 2 then
        table.insert(lines, "Selected: BUY")
    else
        table.insert(lines, string.format("Selected: %s", getPlaceableIdentity(selectedStation and selectedStation.owningPlaceable)))
    end

    table.insert(lines, "REGISTERED HELPER SOURCES")
    for index, station in ipairs(stations) do
        if stationIsRelevantToLocalFarm(station) then
            local marker = station == selectedStation and ">" or " "
            local owner = station.owningPlaceable
            local name = safeCall(owner, "getName", "unnamed")
            local uid = safeCall(owner, "getUniqueId", owner and owner.uniqueId or "n/a")
            local sourceStorages = collectSourceStorages(station)
            table.insert(lines, string.format("%s [%d/value=%d] %s | uid=%s | linked=%d",
                marker, index, index + 2, tostring(name), tostring(uid), #sourceStorages))

            for sourceIndex, entry in ipairs(sourceStorages) do
                if storageIsRelevantToLocalFarm(entry.storage) then
                    local level, capacity, supported = getLiquidManureLevel(entry.storage)
                    table.insert(lines, string.format("    S%d obj=%s LM=%s %.0f / %.0f farm=%s",
                        sourceIndex,
                        tostring(entry.storage),
                        supported and "yes" or "no",
                        level,
                        capacity,
                        tostring(entry.storage.ownerFarmId or "n/a")))
                end
            end
        end
    end

    table.insert(lines, "ALL LIQUID MANURE STORAGES")
    for index, entry in ipairs(collectAllLiquidManureStorages(true)) do
        local level, capacity = getLiquidManureLevel(entry.storage)
        local owner = findStorageOwner(entry.storage)
        local name = safeCall(owner, "getName", "owner unknown")
        local uid = safeCall(owner, "getUniqueId", owner and owner.uniqueId or "n/a")
        table.insert(lines, string.format("[%d] %s | %.0f / %.0f | uid=%s | obj=%s",
            index, tostring(name), level, capacity, tostring(uid), tostring(entry.storage)))
    end

    table.insert(lines, "HUSBANDRY LOADING STATIONS")
    for _, entry in ipairs(collectHusbandryLoadingStations(true)) do
        local name = safeCall(entry.placeable, "getName", "unnamed")
        table.insert(lines, string.format("%s | registered=%s stationLM=%s loadLinks=%d unloadLinks=%d ownLM=%.0f/%.0f",
            tostring(name),
            tostring(entry.registeredIndex),
            tostring(entry.stationSupports),
            #entry.sourceStorages,
            #entry.targetStorages,
            entry.storageLevel,
            entry.storageCapacity))
    end

    local manureHelperValue, manureStationIndex, selectedManureStation = self:getSelectedManureSource()
    local manureStations = mission.manureLoadingStations or {}
    table.insert(lines, "MANURE HELPER DEBUG")
    table.insert(lines, string.format("helperManureSource=%s -> stationIndex=%s | registered sources=%d",
        tostring(manureHelperValue), tostring(manureStationIndex), #manureStations))

    if manureHelperValue == 1 then
        table.insert(lines, "Selected manure: OFF")
    elseif manureHelperValue == 2 then
        table.insert(lines, "Selected manure: BUY")
    else
        table.insert(lines, string.format("Selected manure: %s",
            getPlaceableIdentity(selectedManureStation and selectedManureStation.owningPlaceable)))
    end

    table.insert(lines, "REGISTERED MANURE HELPER SOURCES")
    for index, station in ipairs(manureStations) do
        if stationIsRelevantToLocalFarm(station) then
            local marker = station == selectedManureStation and ">" or " "
            local owner = station.owningPlaceable
            local name = safeCall(owner, "getName", "unnamed")
            local uid = safeCall(owner, "getUniqueId", owner and owner.uniqueId or "n/a")
            local sourceStorages = collectSourceStorages(station)
            table.insert(lines, string.format("%s [%d/value=%d] %s | uid=%s | linked=%d",
                marker, index, index + 2, tostring(name), tostring(uid), #sourceStorages))

            for sourceIndex, entry in ipairs(sourceStorages) do
                if storageIsRelevantToLocalFarm(entry.storage) then
                    local level, capacity, supported = getManureLevel(entry.storage)
                    table.insert(lines, string.format("    S%d obj=%s M=%s %.0f / %.0f farm=%s",
                        sourceIndex,
                        tostring(entry.storage),
                        supported and "yes" or "no",
                        level,
                        capacity,
                        tostring(entry.storage.ownerFarmId or "n/a")))
                end
            end
        end
    end

    table.insert(lines, "ALL MANURE STORAGES")
    for index, entry in ipairs(collectAllManureStorages(true)) do
        local level, capacity = getManureLevel(entry.storage)
        local owner = findStorageOwner(entry.storage)
        local name = safeCall(owner, "getName", "owner unknown")
        local uid = safeCall(owner, "getUniqueId", owner and owner.uniqueId or "n/a")
        table.insert(lines, string.format("[%d] %s | %.0f / %.0f | uid=%s | obj=%s",
            index, tostring(name), level, capacity, tostring(uid), tostring(entry.storage)))
    end

    local activeAISprayers = collectActiveAISprayers()
    if #activeAISprayers > 0 then
        table.insert(lines, "ACTIVE AI SPRAYERS")
        for _, vehicle in ipairs(activeAISprayers) do
            local fillUnitIndex = vehicle:getSprayerFillUnitIndex()
            table.insert(lines, string.format("%s | external=%s | fill=%s %.0f/%.0f | last=%s",
                tostring(safeCall(vehicle, "getName", "unnamed")),
                tostring(vehicle:getIsSprayerExternallyFilled()),
                getFillTypeName(vehicle:getFillUnitFillType(fillUnitIndex)),
                vehicle:getFillUnitFillLevel(fillUnitIndex) or 0,
                vehicle:getFillUnitCapacity(fillUnitIndex) or 0,
                getFillTypeName(vehicle:getFillUnitLastValidFillType(fillUnitIndex))))
        end
    end

    return lines
end

function AIHelperRefillSourceDebug:recordExternalFill(vehicle, inputFillType, outputFillType, usage)
    local event = self.externalFillEvents[vehicle]
    if event == nil then
        event = {calls=0, successes=0, failures=0, usage=0}
        self.externalFillEvents[vehicle] = event
    end

    event.calls = event.calls + 1
    event.inputFillType = inputFillType
    event.outputFillType = outputFillType
    event.usage = event.usage + (usage or 0)
    if outputFillType == FillType.UNKNOWN then
        event.failures = event.failures + 1
    else
        event.successes = event.successes + 1
    end
end

function AIHelperRefillSourceDebug:recordOutOfFillCandidate(vehicle)
    local now = g_time or 0
    local lastTime = self.lastOutOfFillLogTime[vehicle] or -math.huge
    if now - lastTime < 1000 then
        return
    end

    self.lastOutOfFillLogTime[vehicle] = now
    local params = vehicle.spec_sprayer ~= nil and vehicle.spec_sprayer.workAreaParameters or {}
    self:log("OUT_OF_FILL_CANDIDATE vehicle=%s external=%s workAreaSprayFillType=%s workAreaSprayFillLevel=%s %s",
        getVehicleIdentity(vehicle),
        tostring(vehicle:getIsSprayerExternallyFilled()),
        getFillTypeName(params.sprayFillType),
        tostring(params.sprayFillLevel),
        getSprayerFillDiagnostics(vehicle))
end

function AIHelperRefillSourceDebug:recordRemoval(station, fillTypeIndex, fillDelta, remainingDelta, storageChanges, farmId)
    local event = self.removalEvents[station]
    if event == nil then
        event = {
            requested = 0,
            removed = 0,
            remaining = 0,
            farmId = farmId,
            fillTypeIndex = fillTypeIndex,
            helperValue = nil,
            isSelectedHelperSource = false,
            storageChanges = {}
        }
        self.removalEvents[station] = event
    end

    local helperValue, _, selectedStation
    if fillTypeIndex == FillType.MANURE then
        helperValue, _, selectedStation = self:getSelectedManureSource()
    else
        helperValue, _, selectedStation = self:getSelectedSource()
    end

    event.fillTypeIndex = fillTypeIndex
    event.helperValue = helperValue
    event.isSelectedHelperSource = station == selectedStation
    event.requested = event.requested + fillDelta
    event.removed = event.removed + (fillDelta - remainingDelta)
    event.remaining = event.remaining + remainingDelta

    for storage, change in pairs(storageChanges) do
        local aggregate = event.storageChanges[storage]
        if aggregate == nil then
            aggregate = {before=change.before, after=change.after, delta=0}
            event.storageChanges[storage] = aggregate
        end

        aggregate.after = change.after
        aggregate.delta = aggregate.delta + change.delta
    end
end

function AIHelperRefillSourceDebug:flushRemovalEvents()
    for station, event in pairs(self.removalEvents) do
        self:log("REMOVE_SUMMARY fillType=%s selectedHelperSource=%s helperSource=%s station=%s requested=%.6f removed=%.6f remaining=%.6f farmId=%s",
            getFillTypeName(event.fillTypeIndex),
            tostring(event.isSelectedHelperSource),
            tostring(event.helperValue),
            getLoadingStationIdentity(station),
            event.requested,
            event.removed,
            event.remaining,
            tostring(event.farmId))

        for storage, change in pairs(event.storageChanges) do
            self:log("REMOVE_STORAGE_SUMMARY delta=%.6f before=%.6f after=%.6f %s",
                change.delta,
                change.before,
                change.after,
                getStorageIdentity(storage))
        end
    end

    self.removalEvents = {}

    for vehicle, event in pairs(self.externalFillEvents) do
        self:log("EXTERNAL_FILL_SUMMARY vehicle=%s calls=%d successes=%d failures=%d input=%s output=%s usage=%.6f helperSlurrySource=%s helperManureSource=%s %s",
            getVehicleIdentity(vehicle),
            event.calls,
            event.successes,
            event.failures,
            getFillTypeName(event.inputFillType),
            getFillTypeName(event.outputFillType),
            event.usage,
            tostring(g_currentMission.missionInfo.helperSlurrySource),
            tostring(g_currentMission.missionInfo.helperManureSource),
            getSprayerFillDiagnostics(vehicle))
    end

    self.externalFillEvents = {}
end

function AIHelperRefillSourceDebug:update(dt)
    if not self.enabled or g_currentMission == nil then
        return
    end

    self.missionElapsedMs = self.missionElapsedMs + dt
    self.snapshotElapsedMs = self.snapshotElapsedMs + dt
    self.fixElapsedMs = self.fixElapsedMs + dt

    if self.fixElapsedMs >= self.FIX_RECONCILE_INTERVAL_MS then
        self.fixElapsedMs = 0
        self:reconcileLiquidManureHusbandries()
    end

    if not self.initialDumpDone and self.missionElapsedMs >= self.INITIAL_DUMP_DELAY_MS then
        self.initialDumpDone = true
        self.lastSnapshotKey = self:buildSnapshotKey()
        self:dumpState("initial")
    end

    if self.snapshotElapsedMs >= self.SNAPSHOT_INTERVAL_MS then
        self.snapshotElapsedMs = 0
        self:flushRemovalEvents()
        local snapshotKey = self:buildSnapshotKey()
        if self.initialDumpDone and snapshotKey ~= self.lastSnapshotKey then
            self:dumpState("selection-or-registration-changed")
        end
        self.lastSnapshotKey = snapshotKey
        self.hudLines = self:buildHud()
    end
end

function AIHelperRefillSourceDebug:draw()
    if not self.enabled or g_currentMission == nil or g_gui == nil or g_gui:getIsGuiVisible() then
        return
    end

    setTextAlignment(RenderText.ALIGN_RIGHT)
    setTextBold(false)

    local y = self.HUD_Y
    for index, line in ipairs(self.hudLines) do
        if index > self.HUD_MAX_LINES then
            renderText(self.HUD_X, y, self.HUD_TEXT_SIZE, "... HUD line limit reached; full details are in log.txt")
            break
        end

        if index == 1 then
            setTextBold(true)
            setTextColor(0.65, 0.85, 0.15, 1)
        elseif string.sub(line, 1, 1) == ">" then
            setTextBold(true)
            setTextColor(1, 0.8, 0.15, 1)
        else
            setTextBold(false)
            setTextColor(1, 1, 1, 1)
        end

        renderText(self.HUD_X, y, self.HUD_TEXT_SIZE, line)
        y = y - self.HUD_LINE_HEIGHT
    end

    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(false)
    setTextColor(1, 1, 1, 1)
end

local originalGetExternalFill = Sprayer.getExternalFill
Sprayer.getExternalFill = function(vehicle, fillType, dt)
    local outputFillType, usage = originalGetExternalFill(vehicle, fillType, dt)
    if g_aiHelperRefillSourceDebug ~= nil
        and g_aiHelperRefillSourceDebug.enabled
        and vehicle:getIsAIActive() then
        g_aiHelperRefillSourceDebug:recordExternalFill(vehicle, fillType, outputFillType, usage)
    end
    return outputFillType, usage
end

local originalProcessSprayerArea = Sprayer.processSprayerArea
Sprayer.processSprayerArea = function(vehicle, workArea, dt)
    local params = vehicle.spec_sprayer ~= nil and vehicle.spec_sprayer.workAreaParameters or nil
    if g_aiHelperRefillSourceDebug ~= nil
        and g_aiHelperRefillSourceDebug.enabled
        and vehicle:getIsAIActive()
        and params ~= nil
        and (params.sprayFillType == nil or params.sprayFillType == FillType.UNKNOWN) then
        g_aiHelperRefillSourceDebug:recordOutOfFillCandidate(vehicle)
    end

    return originalProcessSprayerArea(vehicle, workArea, dt)
end

local function isHelperSlurryOptionElement(element)
    if element == nil or element.texts == nil then
        return false
    end

    for _, text in ipairs(element.texts) do
        local value = string.lower(tostring(text))
        if string.find(value, "slurry extension", 1, true) ~= nil
            or string.find(value, "koeienstal", 1, true) ~= nil
            or string.find(value, "tank slurry", 1, true) ~= nil
            or string.find(value, "tank digestate", 1, true) ~= nil then
            return true
        end
    end

    return false
end

local function logHelperSlurryOptionState(element, reason, requestedState, forceEvent)
    if not isHelperSlurryOptionElement(element) then
        return
    end

    local texts = {}
    for index, text in ipairs(element.texts) do
        table.insert(texts, string.format("%d='%s'", index, tostring(text)))
    end

    print(string.format(
        "%s GUI_SLURRY_OPTION reason=%s id=%s name=%s requestedState=%s actualState=%s forceEvent=%s currentText='%s' onClickCallback=%s target=%s texts=[%s]",
        AIHelperRefillSourceDebug.TAG,
        tostring(reason),
        tostring(element.id),
        tostring(element.name),
        tostring(requestedState),
        tostring(element.state),
        tostring(forceEvent),
        tostring(element.texts[element.state]),
        tostring(element.onClickCallback),
        tostring(element.target),
        table.concat(texts, ", ")))
end

local function logHelperManureOptionState(element, reason, requestedState, forceEvent)
    if element == nil or element.id ~= "multiHelperRefillManure" or element.texts == nil then
        return
    end

    local texts = {}
    for index, text in ipairs(element.texts) do
        table.insert(texts, string.format("%d='%s'", index, tostring(text)))
    end

    local mappingEntries = {}
    local mapping = element.target ~= nil and element.target.helperManureTextToStationIndexMapping or nil
    for visibleState, rawState in ipairs(mapping or {}) do
        table.insert(mappingEntries, string.format("%d=%s", visibleState, tostring(rawState)))
    end

    print(string.format(
        "%s GUI_MANURE_OPTION reason=%s requestedState=%s actualState=%s forceEvent=%s currentText='%s' mapping=[%s] texts=[%s]",
        AIHelperRefillSourceDebug.TAG,
        tostring(reason),
        tostring(requestedState),
        tostring(element.state),
        tostring(forceEvent),
        tostring(element.texts[element.state]),
        table.concat(mappingEntries, ", "),
        table.concat(texts, ", ")))
end

local slurryGuiRuntimeDumped = false

local function describeGuiRuntimeValue(value)
    local valueType = type(value)
    if valueType == "string" then
        return string.format("string='%s'", value)
    elseif valueType == "number" or valueType == "boolean" or valueType == "nil" then
        return string.format("%s=%s", valueType, tostring(value))
    elseif valueType == "table" then
        return string.format("table=%s", tostring(value))
    elseif valueType == "function" then
        return string.format("function=%s", tostring(value))
    end

    return string.format("%s=%s", valueType, tostring(value))
end

local function tableContainsSlurryStation(value)
    if type(value) ~= "table" or g_currentMission == nil then
        return false
    end

    for _, station in ipairs(g_currentMission.liquidManureLoadingStations or {}) do
        for _, entry in pairs(value) do
            if entry == station then
                return true
            end
        end
    end

    return false
end

local function shouldInspectGuiRuntimeTable(key, value)
    if type(value) ~= "table" then
        return false
    end

    local keyText = string.lower(tostring(key))
    return tableContainsSlurryStation(value)
        or string.find(keyText, "slurry", 1, true) ~= nil
        or string.find(keyText, "manure", 1, true) ~= nil
        or string.find(keyText, "station", 1, true) ~= nil
        or string.find(keyText, "source", 1, true) ~= nil
        or string.find(keyText, "refill", 1, true) ~= nil
end

local function dumpGuiRuntimeTable(label, value)
    if type(value) ~= "table" then
        print(string.format("%s GUI_RUNTIME %s %s",
            AIHelperRefillSourceDebug.TAG, label, describeGuiRuntimeValue(value)))
        return
    end

    local entryCount = 0
    for _ in pairs(value) do
        entryCount = entryCount + 1
    end

    print(string.format("%s GUI_RUNTIME %s table=%s entries=%d",
        AIHelperRefillSourceDebug.TAG, label, tostring(value), entryCount))

    local logged = 0
    for key, entry in pairs(value) do
        logged = logged + 1
        if logged > 250 then
            print(string.format("%s GUI_RUNTIME %s entries-truncated-at=250",
                AIHelperRefillSourceDebug.TAG, label))
            break
        end

        print(string.format("%s GUI_RUNTIME %s[%s] %s",
            AIHelperRefillSourceDebug.TAG,
            label,
            tostring(key),
            describeGuiRuntimeValue(entry)))

        if type(entry) == "table"
            and (shouldInspectGuiRuntimeTable(key, entry)
                or string.find(string.lower(tostring(label)), "mapping", 1, true) ~= nil) then
            local nestedLogged = 0
            for nestedKey, nestedEntry in pairs(entry) do
                nestedLogged = nestedLogged + 1
                if nestedLogged > 100 then
                    print(string.format("%s GUI_RUNTIME %s[%s] entries-truncated-at=100",
                        AIHelperRefillSourceDebug.TAG, label, tostring(key)))
                    break
                end

                print(string.format("%s GUI_RUNTIME %s[%s][%s] %s",
                    AIHelperRefillSourceDebug.TAG,
                    label,
                    tostring(key),
                    tostring(nestedKey),
                    describeGuiRuntimeValue(nestedEntry)))
            end
        end
    end
end

local function dumpGuiCallback(label, callback)
    print(string.format("%s GUI_RUNTIME %s %s",
        AIHelperRefillSourceDebug.TAG, label, describeGuiRuntimeValue(callback)))

    if type(callback) ~= "function" or type(debug) ~= "table" then
        return
    end

    if debug.getinfo ~= nil then
        local ok, info = pcall(debug.getinfo, callback, "Snu")
        if ok and info ~= nil then
            print(string.format(
                "%s GUI_RUNTIME %s info source=%s line=%s lastLine=%s what=%s name=%s upvalues=%s params=%s",
                AIHelperRefillSourceDebug.TAG,
                label,
                tostring(info.short_src or info.source),
                tostring(info.linedefined),
                tostring(info.lastlinedefined),
                tostring(info.what),
                tostring(info.name),
                tostring(info.nups),
                tostring(info.nparams)))
        end
    end

    if debug.getupvalue ~= nil then
        for index = 1, 50 do
            local ok, name, value = pcall(debug.getupvalue, callback, index)
            if not ok or name == nil then
                break
            end

            print(string.format("%s GUI_RUNTIME %s upvalue[%d] name=%s %s",
                AIHelperRefillSourceDebug.TAG,
                label,
                index,
                tostring(name),
                describeGuiRuntimeValue(value)))

            if shouldInspectGuiRuntimeTable(name, value) then
                dumpGuiRuntimeTable(string.format("%s.upvalue[%d].%s", label, index, tostring(name)), value)
            end
        end
    end
end

local function dumpSlurryGuiRuntime(element, reason)
    if slurryGuiRuntimeDumped or element == nil or element.id ~= "multiHelperRefillSlurry" then
        return
    end

    slurryGuiRuntimeDumped = true
    if g_aiHelperRefillSourceDebug ~= nil then
        g_aiHelperRefillSourceDebug.slurryGuiProbe = {
            element = element,
            target = element.target,
            optionMapping = element.target ~= nil and element.target.optionMapping or nil,
            binaryOptionMapping = element.target ~= nil and element.target.binaryOptionMapping or nil,
            capacityTable = element.target ~= nil and element.target.capacityTable or nil,
            capacityNumberTable = element.target ~= nil and element.target.capacityNumberTable or nil,
            liquidManureLoadingStations = element.target ~= nil
                and element.target.liquidManureLoadingStations
                or nil,
            missionLiquidManureLoadingStations = g_currentMission ~= nil
                and g_currentMission.liquidManureLoadingStations
                or nil
        }
    end

    print(string.format("%s GUI_RUNTIME_DUMP reason=%s", AIHelperRefillSourceDebug.TAG, tostring(reason)))
    print(string.format(
        "%s GUI_RUNTIME element=%s target=%s targetName=%s state=%s texts=%s",
        AIHelperRefillSourceDebug.TAG,
        tostring(element),
        tostring(element.target),
        tostring(element.target ~= nil and element.target.name or nil),
        tostring(element.state),
        table.concat(element.texts or {}, " | ")))

    for key, value in pairs(element.target or {}) do
        if value == element.onClickCallback then
            print(string.format("%s GUI_RUNTIME callbackTargetKey=%s",
                AIHelperRefillSourceDebug.TAG, tostring(key)))
        end
    end

    dumpGuiRuntimeTable("target.optionMapping", element.target ~= nil and element.target.optionMapping or nil)
    dumpGuiRuntimeTable("target.binaryOptionMapping", element.target ~= nil and element.target.binaryOptionMapping or nil)
    dumpGuiRuntimeTable("target.capacityTable", element.target ~= nil and element.target.capacityTable or nil)
    dumpGuiRuntimeTable("target.capacityNumberTable", element.target ~= nil and element.target.capacityNumberTable or nil)
    dumpGuiRuntimeTable(
        "target.liquidManureLoadingStations",
        element.target ~= nil and element.target.liquidManureLoadingStations or nil)
    dumpGuiCallback("onClickCallback", element.onClickCallback)
end

local function logSlurryGuiClick(element, direction)
    if element == nil or element.id ~= "multiHelperRefillSlurry" or g_currentMission == nil then
        return
    end

    local rawState = g_currentMission.missionInfo ~= nil
        and g_currentMission.missionInfo.helperSlurrySource
        or nil
    local station = rawState ~= nil
        and rawState > 2
        and g_currentMission.liquidManureLoadingStations[rawState - 2]
        or nil

    print(string.format(
        "%s GUI_SLURRY_CLICK direction=%s visibleState=%s visibleText='%s' rawState=%s rawStation=%s",
        AIHelperRefillSourceDebug.TAG,
        tostring(direction),
        tostring(element.state),
        tostring(element.texts[element.state]),
        tostring(rawState),
        getLoadingStationIdentity(station)))
end

local function logManureGuiClick(element, direction)
    if element == nil or element.id ~= "multiHelperRefillManure" or g_currentMission == nil then
        return
    end

    local rawState = g_currentMission.missionInfo ~= nil
        and g_currentMission.missionInfo.helperManureSource
        or nil
    local station = rawState ~= nil
        and rawState > 2
        and g_currentMission.manureLoadingStations[rawState - 2]
        or nil

    print(string.format(
        "%s GUI_MANURE_CLICK direction=%s visibleState=%s visibleText='%s' rawState=%s rawStation=%s",
        AIHelperRefillSourceDebug.TAG,
        tostring(direction),
        tostring(element.state),
        tostring(element.texts[element.state]),
        tostring(rawState),
        getLoadingStationIdentity(station)))
end

local originalMultiTextOptionSetState = MultiTextOptionElement.setState
MultiTextOptionElement.setState = function(element, state, forceEvent)
    originalMultiTextOptionSetState(element, state, forceEvent)
    if g_aiHelperRefillSourceDebug ~= nil and g_aiHelperRefillSourceDebug.enabled then
        logHelperSlurryOptionState(element, "setState", state, forceEvent)
        logHelperManureOptionState(element, "setState", state, forceEvent)
    end
end

local originalMultiTextOptionSetTexts = MultiTextOptionElement.setTexts
MultiTextOptionElement.setTexts = function(element, texts)
    originalMultiTextOptionSetTexts(element, texts)
    if g_aiHelperRefillSourceDebug ~= nil and g_aiHelperRefillSourceDebug.enabled then
        logHelperSlurryOptionState(element, "setTexts", element.state, false)
        logHelperManureOptionState(element, "setTexts", element.state, false)
    end
end

local originalMultiTextOptionOnRightButtonClicked = MultiTextOptionElement.onRightButtonClicked
MultiTextOptionElement.onRightButtonClicked = function(element, steps, noFocus)
    originalMultiTextOptionOnRightButtonClicked(element, steps, noFocus)
    if g_aiHelperRefillSourceDebug ~= nil and g_aiHelperRefillSourceDebug.enabled then
        logSlurryGuiClick(element, "right")
        logManureGuiClick(element, "right")
    end
end

local originalMultiTextOptionOnLeftButtonClicked = MultiTextOptionElement.onLeftButtonClicked
MultiTextOptionElement.onLeftButtonClicked = function(element, steps, noFocus)
    originalMultiTextOptionOnLeftButtonClicked(element, steps, noFocus)
    if g_aiHelperRefillSourceDebug ~= nil and g_aiHelperRefillSourceDebug.enabled then
        logSlurryGuiClick(element, "left")
        logManureGuiClick(element, "left")
    end
end

local originalRemoveFillLevel = LoadingStation.removeFillLevel
LoadingStation.removeFillLevel = function(station, fillTypeIndex, fillDelta, farmId)
    if g_aiHelperRefillSourceDebug == nil
        or not g_aiHelperRefillSourceDebug.enabled
        or (fillTypeIndex ~= FillType.LIQUIDMANURE and fillTypeIndex ~= FillType.DIGESTATE and fillTypeIndex ~= FillType.MANURE) then
        return originalRemoveFillLevel(station, fillTypeIndex, fillDelta, farmId)
    end

    local before = {}
    for _, entry in ipairs(collectSourceStorages(station)) do
        before[entry.storage] = entry.storage:getFillLevel(fillTypeIndex)
    end

    local remainingDelta = originalRemoveFillLevel(station, fillTypeIndex, fillDelta, farmId)
    local storageChanges = {}
    for storage, oldLevel in pairs(before) do
        local newLevel = storage:getFillLevel(fillTypeIndex)
        if math.abs(oldLevel - newLevel) > 0.0001 then
            storageChanges[storage] = {
                before = oldLevel,
                after = newLevel,
                delta = newLevel - oldLevel
            }
        end
    end

    g_aiHelperRefillSourceDebug:recordRemoval(
        station,
        fillTypeIndex,
        fillDelta,
        remainingDelta,
        storageChanges,
        farmId)

    return remainingDelta
end

g_aiHelperRefillSourceDebug = AIHelperRefillSourceDebug.new()
addModEventListener(g_aiHelperRefillSourceDebug)

