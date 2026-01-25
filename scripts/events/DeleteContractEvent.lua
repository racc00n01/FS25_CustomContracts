DeleteContractEvent = {}
local DeleteContractEvent_mt = Class(DeleteContractEvent, Event)

InitEventClass(DeleteContractEvent, "DeleteContractEvent")

-- REQUIRED
function DeleteContractEvent.emptyNew()
  local self = Event.new(DeleteContractEvent_mt)
  return self
end

-- Used by client UI
function DeleteContractEvent.new(contractId)
  local self = DeleteContractEvent.emptyNew()
  self.contractId = contractId
  return self
end

function DeleteContractEvent:writeStream(streamId, connection)
  streamWriteInt32(streamId, self.contractId)
end

function DeleteContractEvent:readStream(streamId, connection)
  self.contractId = streamReadInt32(streamId)
  self:run(connection)
end

function DeleteContractEvent:run(connection)
  -- 🔒 Server only
  if g_server == nil then
    return
  end

  -- 🔒 Ignore server-originated runs
  if connection == nil or connection:getIsServer() then
    return
  end

  local contractManager = g_currentMission.customContracts.ContractManager
  if contractManager == nil then
    return
  end

  local farmId = connection.farmId
  if farmId == nil or farmId == FarmManager.SPECTATOR_FARM_ID then
    return
  end

  contractManager:handleDeleteRequest(farmId, self.contractId)
end
