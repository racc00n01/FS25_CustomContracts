--
-- FS25 CustomContracts
--
-- @Author: Racc00n
-- @Version: 0.0.1.1
--

CompleteContractEvent = {}
local CompleteContractEvent_mt = Class(CompleteContractEvent, Event)

InitEventClass(CompleteContractEvent, "CompleteContractEvent")

function CompleteContractEvent.emptyNew()
  local self = Event.new(CompleteContractEvent_mt)
  return self
end

function CompleteContractEvent.new(contractId, farmId)
  local self = CompleteContractEvent.emptyNew()
  self.farmId = farmId
  self.contractId = contractId
  return self
end

function CompleteContractEvent:writeStream(streamId, connection)
  streamWriteInt32(streamId, self.farmId)
  streamWriteInt32(streamId, self.contractId)
end

function CompleteContractEvent:readStream(streamId, connection)
  self.farmId = streamReadInt32(streamId)
  self.contractId = streamReadInt32(streamId)
  self:run(connection)
end

function CompleteContractEvent:run(connection)
  if g_currentMission:getIsServer() then
    -- IMPORTANT: farmId should come from the event payload (what you already send),
    -- OR you can keep your existing validation logic with contractorFarmId == farmId.
    g_currentMission.CustomContracts.ContractManager:handleCompleteRequest(self.farmId, self.contractId, connection)
  end
end
