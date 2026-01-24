CompleteContractEvent = {}
local CompleteContractEvent_mt = Class(CompleteContractEvent, Event)

InitEventClass(CompleteContractEvent, "CompleteContractEvent")

-- REQUIRED
function CompleteContractEvent.emptyNew()
  local self = Event.new(CompleteContractEvent_mt)
  return self
end

-- Used by client UI
function CompleteContractEvent.new(contractId)
  local self = CompleteContractEvent.emptyNew()
  self.contractId = contractId
  return self
end

function CompleteContractEvent:writeStream(streamId, connection)
  streamWriteInt32(streamId, self.contractId)
end

function CompleteContractEvent:readStream(streamId, connection)
  self.contractId = streamReadInt32(streamId)
  self:run(connection)
end

function CompleteContractEvent:run(connection)
  -- 🔒 Server only
  if g_server == nil then
    return
  end

  -- 🔒 Ignore server-originated runs
  if connection == nil or connection:getIsServer() then
    return
  end

  if g_customContractManager == nil then
    return
  end

  local farmId = connection.farmId
  if farmId == nil or farmId == FarmManager.SPECTATOR_FARM_ID then
    return
  end

  g_customContractManager:handleCompleteRequest(farmId, self.contractId)
end
