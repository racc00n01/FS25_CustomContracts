--
-- Lists owned vehicles/equipment for vehicle transport contracts.
--

FarmVehicleHelper = {}

function FarmVehicleHelper.getVehicleOwnerFarmId(vehicle)
  if vehicle == nil then
    return nil
  end
  if vehicle.getOwnerFarmId ~= nil then
    local ok, farmId = pcall(function()
      return vehicle:getOwnerFarmId()
    end)
    if ok and farmId ~= nil then
      return farmId
    end
  end
  if vehicle.ownerFarmId ~= nil then
    return vehicle.ownerFarmId
  end
  if vehicle.propertyState ~= nil and vehicle.propertyState.ownerFarmId ~= nil then
    return vehicle.propertyState.ownerFarmId
  end
  return nil
end

function FarmVehicleHelper.getVehicleUniqueId(vehicle)
  if vehicle == nil then
    return nil
  end
  if vehicle.getUniqueId ~= nil then
    local ok, id = pcall(function()
      return vehicle:getUniqueId()
    end)
    if ok and id ~= nil and id ~= "" then
      return tostring(id)
    end
  end
  if vehicle.vehicleUniqueId ~= nil and vehicle.vehicleUniqueId ~= "" then
    return tostring(vehicle.vehicleUniqueId)
  end
  if vehicle.uniqueId ~= nil and vehicle.uniqueId ~= "" then
    return tostring(vehicle.uniqueId)
  end
  if vehicle.id ~= nil then
    return "vehicle_" .. tostring(vehicle.id)
  end
  if vehicle.rootNode ~= nil then
    return "node_" .. tostring(vehicle.rootNode)
  end
  return nil
end

function FarmVehicleHelper.getVehicleTitle(vehicle)
  if vehicle == nil then
    return "?"
  end
  if vehicle.getFullName ~= nil then
    local ok, name = pcall(function()
      return vehicle:getFullName()
    end)
    if ok and name ~= nil and name ~= "" then
      return name
    end
  end
  if vehicle.storeItem ~= nil and vehicle.storeItem.name ~= nil then
    return vehicle.storeItem.name
  end
  return g_i18n:getText("cc_vehicle_transport_unknown") or "Vehicle"
end

function FarmVehicleHelper.getVehicleImageFilename(vehicle)
  if vehicle == nil then
    return nil
  end
  if vehicle.storeItem ~= nil and vehicle.storeItem.imageFilename ~= nil then
    return vehicle.storeItem.imageFilename
  end
  if vehicle.getImageFilename ~= nil then
    local ok, filename = pcall(function()
      return vehicle:getImageFilename()
    end)
    if ok and filename ~= nil and filename ~= "" then
      return filename
    end
  end
  return nil
end

function FarmVehicleHelper.buildEntryFromVehicle(vehicle)
  local uniqueId = FarmVehicleHelper.getVehicleUniqueId(vehicle)
  if uniqueId == nil then
    return nil
  end

  local worldX, worldZ = nil, nil
  if vehicle.rootNode ~= nil then
    worldX, _, worldZ = getWorldTranslation(vehicle.rootNode)
  end

  return {
    uniqueId      = uniqueId,
    title         = FarmVehicleHelper.getVehicleTitle(vehicle),
    imageFilename = FarmVehicleHelper.getVehicleImageFilename(vehicle),
    worldX        = worldX,
    worldZ        = worldZ
  }
end

--- Returns sorted list of { uniqueId, title, imageFilename, worldX, worldZ } for the farm.
function FarmVehicleHelper.retrieveFarmVehicles(farmId)
  local list = {}
  if farmId == nil then
    return list
  end

  local vehicleSystem = g_currentMission.vehicleSystem
  local vehicles = vehicleSystem and vehicleSystem.vehicles
  if vehicles == nil then
    return list
  end

  local seenIds = {}
  local function tryAddVehicle(vehicle)
    if vehicle == nil or vehicle.isPallet then
      return
    end
    if FarmVehicleHelper.getVehicleOwnerFarmId(vehicle) ~= farmId then
      return
    end
    local entry = FarmVehicleHelper.buildEntryFromVehicle(vehicle)
    if entry ~= nil and seenIds[entry.uniqueId] == nil then
      seenIds[entry.uniqueId] = true
      table.insert(list, entry)
    end
  end

  if #vehicles > 0 then
    for i = 1, #vehicles do
      tryAddVehicle(vehicles[i])
    end
  else
    for _, vehicle in pairs(vehicles) do
      tryAddVehicle(vehicle)
    end
  end

  table.sort(list, function(a, b)
    return (a.title or ""):lower() < (b.title or ""):lower()
  end)

  return list
end

function FarmVehicleHelper.findVehicleByUniqueId(uniqueId)
  if uniqueId == nil or uniqueId == "" then
    return nil
  end
  local vehicleSystem = g_currentMission.vehicleSystem
  local vehicles = vehicleSystem and vehicleSystem.vehicles
  if vehicles == nil then
    return nil
  end
  for _, vehicle in pairs(vehicles) do
    if FarmVehicleHelper.getVehicleUniqueId(vehicle) == uniqueId then
      return vehicle
    end
  end
  return nil
end

function FarmVehicleHelper.getPrimaryPickupWorldXZ(farmId, entries)
  if entries ~= nil then
    for _, entry in ipairs(entries) do
      local vehicle = FarmVehicleHelper.findVehicleByUniqueId(entry.uniqueId)
      if vehicle ~= nil and vehicle.rootNode ~= nil then
        local x, _, z = getWorldTranslation(vehicle.rootNode)
        return x, z
      end
      if entry.worldX ~= nil and entry.worldZ ~= nil then
        return entry.worldX, entry.worldZ
      end
    end
  end
  return nil, nil
end

function FarmVehicleHelper.buildVehicleDescription(entries)
  if entries == nil or #entries == 0 then
    return ""
  end
  local names = {}
  for _, e in ipairs(entries) do
    table.insert(names, e.title or e.uniqueId or "?")
  end
  return table.concat(names, ", ")
end
