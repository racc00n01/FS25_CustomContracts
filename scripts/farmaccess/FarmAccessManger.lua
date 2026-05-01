FarmAccessManager = {}
FarmAccessManager_mt = Class(FarmAccessManager)
FarmAccessManager.dir = g_currentModDirectory
FarmAccessManager.modName = g_currentModName

function FarmAccessManager:new()
  local self = setmetatable({}, FarmAccessManager_mt)
  self.access = {}
  self.nextId = 1

  if g_currentMission:getIsServer() then
    g_messageCenter:subscribe(
      MessageType.PLAYER_CONNECTED,
      self.onPlayerConnected,
      self
    )
  end

  return self
end

function FarmAccessManager:saveToXmlFile(xmlFile)
  if not g_currentMission:getIsServer() then return end
  local key = CustomContracts.SaveKey
  local count = 0

  for _, access in pairs(self.access) do
    local accessKey = string.format("%s.access(%d)", key, count)
    setXMLInt(xmlFile, accessKey .. "#id", access.id)
    setXMLInt(xmlFile, accessKey .. "#farmId", access.farmId)
    setXMLInt(xmlFile, accessKey .. "#contractorFor", access.contractorFor)
    setXMLInt(xmlFile, accessKey .. "#accessType", access.accessType)
    setXMLInt(xmlFile, accessKey .. "#scopeType", access.scopeType or FarmAccess.SCOPE_TYPES.FARM)
    setXMLInt(xmlFile, accessKey .. "#scopeId", access.scopeId or -1)
    setXMLInt(xmlFile, accessKey .. "#sourceId", access.sourceId or -1)
    count = count + 1
  end
end

function FarmAccessManager:loadFromXmlFile(xmlFile)
  if not g_currentMission:getIsServer() then return end
  self.access = {}
  self.nextId = 1
  local key = CustomContracts.SaveKey
  local i = 0
  while true do
    local accessKey = string.format("%s.access(%d)", key, i)
    if not hasXMLProperty(xmlFile, accessKey) then break end
    local id = getXMLInt(xmlFile, accessKey .. "#id")
    local farmId = getXMLInt(xmlFile, accessKey .. "#farmId")
    local contractorFor = getXMLInt(xmlFile, accessKey .. "#contractorFor")
    local accessType = getXMLInt(xmlFile, accessKey .. "#accessType")
    local scopeType = getXMLInt(xmlFile, accessKey .. "#scopeType") or FarmAccess.SCOPE_TYPES.FARM
    local scopeId = getXMLInt(xmlFile, accessKey .. "#scopeId") or -1
    local sourceId = getXMLInt(xmlFile, accessKey .. "#sourceId") or -1
    self.access[id] = FarmAccess.new(id, farmId, contractorFor, accessType, scopeType, scopeId, sourceId)
    self.nextId = math.max(self.nextId, id + 1)
    i = i + 1
  end
end

function FarmAccessManager:writeInitialClientState(streamId, connection)
  streamWriteInt32(streamId, self.nextId)

  local count = table.size(self.access)
  streamWriteInt32(streamId, count)

  for _, access in pairs(self.access) do
    access:writeStream(streamId)
  end
end

function FarmAccessManager:readInitialClientState(streamId, connection)
  self.access = {}

  self.nextId = streamReadInt32(streamId)
  local count = streamReadInt32(streamId)

  for i = 1, count do
    local access = FarmAccess.newFromStream(streamId)
    self.access[access.id] = access
  end

  g_messageCenter:publish(MessageType.FARM_ACCESS_UPDATED)
end

function FarmAccessManager:syncAccess(connection)
  if not g_currentMission:getIsServer() then return end

  local event = SyncFarmAccessEvent.new(self.access, self.nextId)

  if connection ~= nil then
    connection:sendEvent(event)
  else
    g_server:broadcastEvent(event, true)
  end
end

function FarmAccessManager:onPlayerConnected(connection)
  if not g_currentMission:getIsServer() then return end
  if connection == nil then return end
  self:syncAccess(connection)
end

function FarmAccessManager:addAccess(farmId, contractorFor, accessType, scopeType, scopeId, sourceId)
  local id = self.nextId
  self.nextId = self.nextId + 1

  local access = FarmAccess.new(
    id,
    farmId,
    contractorFor,
    accessType,
    scopeType or FarmAccess.SCOPE_TYPES.FARM,
    scopeId or -1,
    sourceId or -1
  )

  self.access[id] = access
  return access
end

function FarmAccessManager:getAccessById(id)
  return self.access[id]
end

function FarmAccessManager:removeAccessById(id)
  self.access[id] = nil
end

function FarmAccessManager:removeAccessBySourceId(sourceId)
  if sourceId == nil or sourceId < 0 then
    return
  end

  for id, access in pairs(self.access) do
    if access.sourceId == sourceId then
      self.access[id] = nil
    end
  end
end

function FarmAccessManager:hasAccess(farmId, contractorFor, accessType, scopeType, scopeId)
  for _, access in pairs(self.access) do
    if access.farmId == farmId
        and access.contractorFor == contractorFor
        and access.accessType == accessType
        and access.scopeType == scopeType
        and access.scopeId == scopeId then
      return true
    end
  end

  return false
end

function FarmAccessManager:grantContractAccess(contract)
  if contract == nil then
    return
  end

  self:removeAccessBySourceId(contract.id)

  if contract.status ~= CustomContract.STATUS.ACCEPTED
      or contract.contractorFarmId == nil then
    return
  end

  if contract.templateId == CustomContract.TEMPLATE.FIELD_WORK and contract.farmlandId ~= nil and contract.farmlandId >= 0 then
    self:addAccess(
      contract.contractorFarmId,
      contract.creatorFarmId,
      FarmAccess.ACCESS_TYPES.FIELD_WORK,
      FarmAccess.SCOPE_TYPES.FARMLAND,
      contract.farmlandId,
      contract.id
    )
  end

  if contract.templateId == CustomContract.TEMPLATE.TRANSPORT
      and contract.fillTypeIndex ~= nil
      and contract.fillTypeIndex >= 0 then
    self:addAccess(
      contract.contractorFarmId,
      contract.creatorFarmId,
      FarmAccess.ACCESS_TYPES.TRANSPORT,
      FarmAccess.SCOPE_TYPES.SILO,
      contract.fillTypeIndex,
      contract.id
    )
  end
end

function FarmAccessManager:rebuildFromContracts(contracts)
  self.access = {}
  self.nextId = 1

  if contracts == nil then
    return
  end

  for _, contract in pairs(contracts) do
    self:grantContractAccess(contract)
  end
end

function FarmAccessManager:getFarmAccessFieldWorkByFarmId(farmId, landOwnerFarmId, x, z, workAreaType, workArea)
  if farmId == nil or landOwnerFarmId == nil then
    return false
  end

  local farmlandIdAtPos = g_farmlandManager:getFarmlandIdAtWorldPosition(x, z)
  if farmlandIdAtPos == nil then
    return false
  end

  for _, access in pairs(self.access) do
    if access.farmId == farmId
        and access.contractorFor == landOwnerFarmId
        and access.accessType == FarmAccess.ACCESS_TYPES.FIELD_WORK
        and access.scopeType == FarmAccess.SCOPE_TYPES.FARMLAND
        and access.scopeId == farmlandIdAtPos then
      return true
    end
  end

  return false
end

function FarmAccessManager:getGrantingFarmIdForFieldWork(farmId, x, z, workAreaType, workArea)
  if farmId == nil then
    return nil
  end

  local farmlandIdAtPos = g_farmlandManager:getFarmlandIdAtWorldPosition(x, z)
  if farmlandIdAtPos == nil then
    return nil
  end

  for _, access in pairs(self.access) do
    if access.farmId == farmId
        and access.accessType == FarmAccess.ACCESS_TYPES.FIELD_WORK
        and access.scopeType == FarmAccess.SCOPE_TYPES.FARMLAND
        and access.scopeId == farmlandIdAtPos then
      return access.contractorFor
    end
  end

  return nil
end

function FarmAccessManager:hasAcceptedContractWithOwner(contractorFarmId, ownerFarmId)
  if contractorFarmId == nil or ownerFarmId == nil then
    return false
  end

  for _, access in pairs(self.access) do
    if access.farmId == contractorFarmId
        and access.contractorFor == ownerFarmId
        and access.sourceId ~= nil
        and access.sourceId >= 0 then
      return true
    end
  end

  return false
end

function FarmAccessManager:hasTransportAccess(contractorFarmId, ownerFarmId, fillTypeIndex)
  if contractorFarmId == nil or ownerFarmId == nil then
    return false
  end

  for _, access in pairs(self.access) do
    if access.farmId == contractorFarmId
        and access.contractorFor == ownerFarmId
        and access.accessType == FarmAccess.ACCESS_TYPES.TRANSPORT
        and access.scopeType == FarmAccess.SCOPE_TYPES.SILO then
      if fillTypeIndex == nil or fillTypeIndex < 0 or access.scopeId == fillTypeIndex then
        return true
      end
    end
  end

  return false
end
