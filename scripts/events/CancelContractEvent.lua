CancelContractEvent = {}
local CancelContractEvent_mt = Class(CancelContractEvent, Event)

InitEventClass(CancelContractEvent, "CancelContractEvent")

-- REQUIRED
function CancelContractEvent.emptyNew()
  local self = Event.new(CancelContractEvent_mt)
  return self
end

-- Used by client UI
function CancelContractEvent.new(contractId)
  local self = CancelContractEvent.emptyNew()
  self.contractId = contractId
  return self
end

function CancelContractEvent:writeStream(streamId, connection)
  streamWriteInt32(streamId, self.contractId)
end

function CancelContractEvent:readStream(streamId, connection)
  self.contractId = streamReadInt32(streamId)
  self:run(connection)
end

function CancelContractEvent:run(connection)
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

  contractManager:handleCancelRequest(farmId, self.contractId)
end
