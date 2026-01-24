CompleteContractEvent = {}
CompleteContractEvent_mt = Class(CompleteContractEvent, Event)

InitEventClass(CompleteContractEvent, "CompleteContractEvent")

function CompleteContractEvent.new(contractId)
  local self = Event.new(CompleteContractEvent_mt)
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
  g_customContractManager:completeContract(self.contractId)
end
