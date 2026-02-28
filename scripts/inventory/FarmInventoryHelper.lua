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
