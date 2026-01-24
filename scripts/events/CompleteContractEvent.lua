CompleteContractEvent = {}
CompleteContractEvent_mt = Class(CompleteContractEvent, Event)

InitEventClass(CompleteContractEvent, "CompleteContractEvent")


function CompleteContractEvent.emptyNew()
  local self = Event.new(CompleteContractEvent_mt)
  return self
end

function CompleteContractEvent.new(contractId)
  local self = CompleteContractEvent.emptyNew()
  self.contractId = contractId
  return self
end

function CompleteContractEvent:readStream(streamId, connection)
  self.contractId = streamReadInt32(streamId)
  self:run(connection)
end

function CompleteContractEvent:writeStream(streamId, connection)
  streamWriteInt32(streamId, self.contractId)
end

function CompleteContractEvent:run(connection)
  if g_server == nil then
    return
  end
  if connection == nil or connection:getIsServer() then
    return
  end

  g_customContractManager:completeContract(self.contractId)
end
