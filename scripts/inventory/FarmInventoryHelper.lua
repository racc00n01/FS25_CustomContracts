--
-- Stateless GUI helper: builds a snapshot of the farm's inventory (silos, pallets,
-- bales, production outputs, global transport pallets) for display and for
-- attaching to contract creation. Not saved; not a manager.
--

FarmInventoryHelper = {}

--[[
  Returns { byFillType = {...}, list = {...} } for the given farmId.
  - byFillType[fillTypeIndex] = { fillTypeIndex, title, amount, hudOverlayFilename }
  - list = sorted array of same entries (amount > 0) for GUI display.
]]

function FarmInventoryHelper.retrieveFarmInventory(farmId)
  if farmId == nil then
    return { byFillType = {}, list = {} }
  end
  local byFillType = {}
  FarmInventoryHelper.buildByFillType(FarmInventoryHelper.retrieveSiloFillTypes(farmId), byFillType)
  FarmInventoryHelper.buildByFillType(FarmInventoryHelper.retrievePallets(farmId), byFillType)
  FarmInventoryHelper.buildByFillType(FarmInventoryHelper.retrieveBales(farmId), byFillType)
  FarmInventoryHelper.buildByFillType(FarmInventoryHelper.retrieveProductionOutputs(farmId), byFillType)
  FarmInventoryHelper.buildByFillType(FarmInventoryHelper.retrieveGlobalTransportPallets(farmId), byFillType)
  local list = FarmInventoryHelper.buildInventoryList(byFillType)
  return { byFillType = byFillType, list = list }
end

--- Aggregates fill levels from all silos owned by (or shared with) the farm. Returns [fillTypeIndex] = liters.
function FarmInventoryHelper.retrieveSiloFillTypes(farmId)
  local totals = {}
  local placeableSystem = g_currentMission.placeableSystem
  local placeables = placeableSystem and placeableSystem.placeables
  if placeables == nil then return totals end

  for i = 1, #placeables do
    local placeable = placeables[i]
    if placeable.spec_silo ~= nil then
      local owner = placeable.ownerFarmId
      if owner == farmId then
        local siloSpec = placeable.spec_silo
        local loadingStation = siloSpec.loadingStation
        if loadingStation ~= nil and loadingStation.getAllFillLevels ~= nil then
          local fillLevels = loadingStation:getAllFillLevels(farmId)
          if fillLevels ~= nil then
            for fillTypeIndex, liters in pairs(fillLevels) do
              if fillTypeIndex ~= nil and liters ~= nil and liters > 0 then
                totals[fillTypeIndex] = (totals[fillTypeIndex] or 0) + liters
              end
            end
          end
        end
      end
    end
  end
  return totals
end

--- Pallets (loose pallets, shipping containers): returns [fillTypeIndex] = total liters.
function FarmInventoryHelper.retrievePallets(farmId)
  local totals = {}
  local vehicleSystem = g_currentMission.vehicleSystem
  local vehicles = vehicleSystem and vehicleSystem.vehicles
  if vehicles == nil then return totals end

  for _, vehicle in pairs(vehicles) do
    if vehicle.isPallet and (vehicle.ownerFarmId == farmId or vehicle.ownerFarmId == 0) then
      local fillTypeIndex, fillLevel
      if vehicle.spec_fillUnit ~= nil and vehicle.spec_fillUnit.fillUnits ~= nil and #vehicle.spec_fillUnit.fillUnits > 0 then
        local fu = vehicle.spec_fillUnit.fillUnits[1]
        fillTypeIndex = fu.fillType
        fillLevel = fu.fillLevel
      elseif vehicle.fillTypeIndex ~= nil and vehicle.amount ~= nil then
        fillTypeIndex = vehicle.fillTypeIndex
        fillLevel = vehicle.amount
      end
      if fillTypeIndex ~= nil and fillLevel ~= nil and fillLevel > 0 then
        totals[fillTypeIndex] = (totals[fillTypeIndex] or 0) + fillLevel
      end
    end
  end
  return totals
end

--- Bales (from itemSystem): returns [fillTypeIndex] = total liters.
function FarmInventoryHelper.retrieveBales(farmId)
  local totals = {}
  local mission = g_currentMission
  if mission == nil or mission.itemSystem == nil or mission.itemSystem.itemsToSave == nil then
    return totals
  end
  local Bale = Bale -- use global if available
  if Bale == nil then return totals end

  for _, item in pairs(mission.itemSystem.itemsToSave) do
    local bale = item and item.item
    local owner = bale.ownerFarmId
    if bale ~= nil and bale.isa ~= nil and bale:isa(Bale) and owner == farmId then
      local fillType = bale.fillType
      local fillLevel = bale.fillLevel or 0
      if fillType ~= nil and fillLevel > 0 then
        totals[fillType] = (totals[fillType] or 0) + fillLevel
      end
    end
  end
  return totals
end

--- Production point outputs (stored at factories): returns [fillTypeIndex] = total liters.
function FarmInventoryHelper.retrieveProductionOutputs(farmId)
  local totals = {}
  local mission = g_currentMission
  if mission == nil or mission.productionChainManager == nil or mission.productionChainManager.productionPoints == nil then
    return totals
  end

  for _, productionPoint in pairs(mission.productionChainManager.productionPoints) do
    local owner = productionPoint.ownerFarmId
    if owner == farmId then
      if productionPoint.storage ~= nil and productionPoint.outputFillTypeIdsArray ~= nil then
        for x = 1, #productionPoint.outputFillTypeIdsArray do
          local fillType = productionPoint.outputFillTypeIdsArray[x]
          local fillLevel = productionPoint.storage:getFillLevel(fillType)
          if fillType ~= nil and fillLevel > 0 then
            totals[fillType] = (totals[fillType] or 0) + MathUtil.round(fillLevel)
          end
        end
      end
    end
  end
  return totals
end

--- Global transport pallets (vehicle type): returns [fillTypeIndex] = total liters.
function FarmInventoryHelper.retrieveGlobalTransportPallets(farmId)
  local totals = {}
  local vehicleSystem = g_currentMission and g_currentMission.vehicleSystem
  local vehicles = vehicleSystem and vehicleSystem.vehicles
  if vehicles == nil then return totals end

  for _, vehicle in ipairs(vehicles) do
    if vehicle.ownerFarmId ~= farmId then
      -- skip
    elseif (vehicle.typeName == "GlobalTransportPallet" or vehicle.typeName == "GlobalTransportPalletLiquids")
        and vehicle.spec_fillUnit ~= nil and vehicle.spec_fillUnit.fillUnits ~= nil and #vehicle.spec_fillUnit.fillUnits > 0 then
      local fu = vehicle.spec_fillUnit.fillUnits[1]
      local fillType = fu.fillType
      local fillLevel = fu.fillLevel or 0
      if fillType ~= nil and fillLevel > 0 then
        totals[fillType] = (totals[fillType] or 0) + fillLevel
      end
    end
  end
  return totals
end

--- Builds byFillType from [fillTypeIndex] = liters. Merges with optional existing byFillType (adds amounts).
function FarmInventoryHelper.buildByFillType(fillTypeToLiters, existingByFillType)
  existingByFillType = existingByFillType or {}
  if fillTypeToLiters == nil then return existingByFillType end
  for fillTypeIndex, liters in pairs(fillTypeToLiters) do
    if fillTypeIndex ~= nil and liters ~= nil and liters > 0 then
      local ft = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
      if ft ~= nil then
        local entry = existingByFillType[fillTypeIndex]
        if entry == nil then
          existingByFillType[fillTypeIndex] = {
            fillTypeIndex = fillTypeIndex,
            title = ft.title or ft.name or ("FillType " .. tostring(fillTypeIndex)),
            amount = 0,
            hudOverlayFilename = ft.hudOverlayFilename
          }
          entry = existingByFillType[fillTypeIndex]
        end
        entry.amount = entry.amount + math.floor(liters + 0.5)
      end
    end
  end
  return existingByFillType
end

--- Returns sorted array of inventory entries for GUI: { fillTypeIndex, title, amount, hudOverlayFilename }.
function FarmInventoryHelper.buildInventoryList(byFillType)
  local list = {}
  if byFillType == nil then return list end
  for _, entry in pairs(byFillType) do
    if entry.amount > 0 then
      table.insert(list, {
        fillTypeIndex = entry.fillTypeIndex,
        title = entry.title,
        amount = entry.amount,
        hudOverlayFilename = entry.hudOverlayFilename
      })
    end
  end
  table.sort(list, function(a, b) return a.title < b.title end)
  return list
end

--- Localized display name for a placeable (silo, etc.), or nil.
function FarmInventoryHelper.getPlaceableDisplayName(placeable)
  if placeable == nil then
    return nil
  end
  if placeable.getName ~= nil then
    local n = placeable:getName()
    if n ~= nil and tostring(n) ~= "" then
      return tostring(n)
    end
  end
  if placeable.name ~= nil and tostring(placeable.name) ~= "" then
    return tostring(placeable.name)
  end
  return g_i18n:getText("cc_transport_pickup_unnamed_placeable")
end

--- Localized display name for a production point.
function FarmInventoryHelper.getProductionPointDisplayName(productionPoint)
  if productionPoint == nil then
    return nil
  end
  if productionPoint.getName ~= nil then
    local n = productionPoint:getName()
    if n ~= nil and tostring(n) ~= "" then
      return tostring(n)
    end
  end
  if productionPoint.name ~= nil and tostring(productionPoint.name) ~= "" then
    return tostring(productionPoint.name)
  end
  return g_i18n:getText("cc_transport_pickup_factory")
end

--- Human-readable hint where the contractor can load this fill type on the farm (silos, production, pallets, …).
function FarmInventoryHelper.buildTransportPickupDescription(farmId, fillTypeIndex)
  if farmId == nil or fillTypeIndex == nil then
    return "-"
  end

  local parts = {}
  local seen = {}

  local function addPart(s)
    if s == nil or s == "" then
      return
    end
    if not seen[s] then
      seen[s] = true
      table.insert(parts, s)
    end
  end

  local placeableSystem = g_currentMission.placeableSystem
  local placeables = placeableSystem and placeableSystem.placeables
  if placeables ~= nil then
    for i = 1, #placeables do
      local placeable = placeables[i]
      if placeable.spec_silo ~= nil and placeable.ownerFarmId == farmId then
        local loadingStation = placeable.spec_silo.loadingStation
        if loadingStation ~= nil and loadingStation.getAllFillLevels ~= nil then
          local fillLevels = loadingStation:getAllFillLevels(farmId)
          if fillLevels ~= nil and fillLevels[fillTypeIndex] ~= nil and fillLevels[fillTypeIndex] > 0 then
            addPart(FarmInventoryHelper.getPlaceableDisplayName(placeable))
          end
        end
      end
    end
  end

  local mission = g_currentMission
  if mission ~= nil and mission.productionChainManager ~= nil and mission.productionChainManager.productionPoints ~= nil then
    for _, productionPoint in pairs(mission.productionChainManager.productionPoints) do
      if productionPoint.ownerFarmId == farmId and productionPoint.storage ~= nil then
        local fillLevel = productionPoint.storage:getFillLevel(fillTypeIndex)
        if fillLevel ~= nil and fillLevel > 0 then
          addPart(FarmInventoryHelper.getProductionPointDisplayName(productionPoint))
        end
      end
    end
  end

  local pallets = FarmInventoryHelper.retrievePallets(farmId)
  if pallets[fillTypeIndex] ~= nil and pallets[fillTypeIndex] > 0 then
    addPart(g_i18n:getText("cc_transport_pickup_loose_pallets"))
  end

  local bales = FarmInventoryHelper.retrieveBales(farmId)
  if bales[fillTypeIndex] ~= nil and bales[fillTypeIndex] > 0 then
    addPart(g_i18n:getText("cc_transport_pickup_bales"))
  end

  local gtp = FarmInventoryHelper.retrieveGlobalTransportPallets(farmId)
  if gtp[fillTypeIndex] ~= nil and gtp[fillTypeIndex] > 0 then
    addPart(g_i18n:getText("cc_transport_pickup_global_pallet"))
  end

  if #parts == 0 then
    return g_i18n:getText("cc_transport_pickup_unknown")
  end

  local s = table.concat(parts, ", ")
  if #s > 450 then
    s = string.sub(s, 1, 447) .. "..."
  end
  return s
end

--- World X/Z for a placeable (silo, etc.), or nil if unknown.
function FarmInventoryHelper.getWorldXZFromPlaceable(placeable)
  if placeable == nil then
    return nil, nil
  end
  local node = placeable.rootNode
  if node == nil and placeable.components ~= nil and placeable.components[1] ~= nil then
    node = placeable.components[1].node
  end
  if node ~= nil then
    local x, _, z = getWorldTranslation(node)
    return x, z
  end
  return nil, nil
end

--- World X/Z for a production point, or nil if unknown.
function FarmInventoryHelper.getWorldXZFromProductionPoint(productionPoint)
  if productionPoint == nil then
    return nil, nil
  end
  for _, key in ipairs({ "rootNode", "interactionRootNode", "markerNode" }) do
    local node = productionPoint[key]
    if node ~= nil then
      local x, _, z = getWorldTranslation(node)
      return x, z
    end
  end
  local own = productionPoint.owningPlaceable or productionPoint.placeable
  if own ~= nil then
    return FarmInventoryHelper.getWorldXZFromPlaceable(own)
  end
  if productionPoint.getOwner ~= nil then
    local o = productionPoint:getOwner()
    if o ~= nil then
      return FarmInventoryHelper.getWorldXZFromPlaceable(o)
    end
  end
  return nil, nil
end

--- First resolved pickup location for transport (same priority as buildTransportPickupDescription).
--- Returns worldX, worldZ or nil, nil when no position can be determined.
function FarmInventoryHelper.getPrimaryPickupWorldXZ(farmId, fillTypeIndex)
  if farmId == nil or fillTypeIndex == nil then
    return nil, nil
  end

  local placeableSystem = g_currentMission.placeableSystem
  local placeables = placeableSystem and placeableSystem.placeables
  if placeables ~= nil then
    for i = 1, #placeables do
      local placeable = placeables[i]
      if placeable.spec_silo ~= nil and placeable.ownerFarmId == farmId then
        local loadingStation = placeable.spec_silo.loadingStation
        if loadingStation ~= nil and loadingStation.getAllFillLevels ~= nil then
          local fillLevels = loadingStation:getAllFillLevels(farmId)
          if fillLevels ~= nil and fillLevels[fillTypeIndex] ~= nil and fillLevels[fillTypeIndex] > 0 then
            local x, z = FarmInventoryHelper.getWorldXZFromPlaceable(placeable)
            if x ~= nil and z ~= nil then
              return x, z
            end
          end
        end
      end
    end
  end

  local mission = g_currentMission
  if mission ~= nil and mission.productionChainManager ~= nil and mission.productionChainManager.productionPoints ~= nil then
    for _, productionPoint in pairs(mission.productionChainManager.productionPoints) do
      if productionPoint.ownerFarmId == farmId and productionPoint.storage ~= nil then
        local fillLevel = productionPoint.storage:getFillLevel(fillTypeIndex)
        if fillLevel ~= nil and fillLevel > 0 then
          local x, z = FarmInventoryHelper.getWorldXZFromProductionPoint(productionPoint)
          if x ~= nil and z ~= nil then
            return x, z
          end
        end
      end
    end
  end

  local vehicleSystem = g_currentMission.vehicleSystem
  local vehicles = vehicleSystem and vehicleSystem.vehicles
  if vehicles ~= nil then
    for _, vehicle in pairs(vehicles) do
      if vehicle.isPallet and (vehicle.ownerFarmId == farmId or vehicle.ownerFarmId == 0) then
        local fti
        if vehicle.spec_fillUnit ~= nil and vehicle.spec_fillUnit.fillUnits ~= nil and #vehicle.spec_fillUnit.fillUnits > 0 then
          fti = vehicle.spec_fillUnit.fillUnits[1].fillType
        elseif vehicle.fillTypeIndex ~= nil then
          fti = vehicle.fillTypeIndex
        end
        if fti == fillTypeIndex and vehicle.rootNode ~= nil then
          local x, _, z = getWorldTranslation(vehicle.rootNode)
          return x, z
        end
      end
    end
  end

  if mission ~= nil and mission.itemSystem ~= nil and mission.itemSystem.itemsToSave ~= nil and Bale ~= nil then
    for _, item in pairs(mission.itemSystem.itemsToSave) do
      local bale = item and item.item
      if bale ~= nil and bale.isa ~= nil and bale:isa(Bale) and bale.ownerFarmId == farmId then
        if bale.fillType == fillTypeIndex and (bale.fillLevel or 0) > 0 then
          local node = bale.node or bale.rootNode
          if node ~= nil then
            local x, _, z = getWorldTranslation(node)
            return x, z
          end
        end
      end
    end
  end

  if vehicles ~= nil then
    for _, vehicle in ipairs(vehicles) do
      if vehicle.ownerFarmId == farmId
          and (vehicle.typeName == "GlobalTransportPallet" or vehicle.typeName == "GlobalTransportPalletLiquids")
          and vehicle.spec_fillUnit ~= nil and vehicle.spec_fillUnit.fillUnits ~= nil and #vehicle.spec_fillUnit.fillUnits > 0 then
        local fu = vehicle.spec_fillUnit.fillUnits[1]
        if fu.fillType == fillTypeIndex and (fu.fillLevel or 0) > 0 and vehicle.rootNode ~= nil then
          local x, _, z = getWorldTranslation(vehicle.rootNode)
          return x, z
        end
      end
    end
  end

  return nil, nil
end
