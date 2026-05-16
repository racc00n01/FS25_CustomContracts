FarmAccess = {}
FarmAccess_mt = Class(FarmAccess)
FarmAccess.dir = g_currentModDirectory
FarmAccess.modName = g_currentModName

FarmAccess.ACCESS_TYPES = {
  FULL = 0,
  FIELD_WORK = 1,
  TRANSPORT = 2,
  FARM_JOB = 3,
  CUSTOM = 4,
  VEHICLE_TRANSPORT = 5
}

FarmAccess.SCOPE_TYPES = {
  FARM = 0,
  FARMLAND = 1,
  VEHICLE = 2,
  PLACEABLE = 3,
  PRODUCTION = 4,
  SILO = 5,
  CUSTOM = 6
}

function FarmAccess.new(id, farmId, contractorFor, accessType, scopeType, scopeId, sourceId, scopeStringId)
  local self = setmetatable({}, FarmAccess_mt)
  self.id = id
  self.farmId = farmId
  self.contractorFor = contractorFor
  self.accessType = accessType
  self.scopeType = scopeType or FarmAccess.SCOPE_TYPES.FARM
  self.scopeId = scopeId or -1
  self.sourceId = sourceId or -1
  self.scopeStringId = scopeStringId or ""
  return self
end

function FarmAccess:writeStream(streamId)
  streamWriteInt32(streamId, self.id)
  streamWriteInt32(streamId, self.farmId)
  streamWriteInt32(streamId, self.contractorFor)
  streamWriteInt32(streamId, self.accessType)
  streamWriteInt32(streamId, self.scopeType)
  streamWriteInt32(streamId, self.scopeId)
  streamWriteInt32(streamId, self.sourceId)
  streamWriteString(streamId, self.scopeStringId or "")
end

function FarmAccess.newFromStream(streamId)
  local id = streamReadInt32(streamId)
  local farmId = streamReadInt32(streamId)
  local contractorFor = streamReadInt32(streamId)
  local accessType = streamReadInt32(streamId)
  local scopeType = streamReadInt32(streamId)
  local scopeId = streamReadInt32(streamId)
  local sourceId = streamReadInt32(streamId)
  local scopeStringId = streamReadString(streamId)
  return FarmAccess.new(id, farmId, contractorFor, accessType, scopeType, scopeId, sourceId, scopeStringId)
end
