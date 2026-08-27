--
-- FS25 Contract and Invoices
--
-- @Author: Racc00n
-- @Version: 1.0.0.0
--
-- Server to client update of the completion of a single contract. Kept separate
-- from SyncContractsEvent because this fires while the contractor is working.
--

ContractProgressEvent = {}
local ContractProgressEvent_mt = Class(ContractProgressEvent, Event)

InitEventClass(ContractProgressEvent, "ContractProgressEvent")

function ContractProgressEvent.emptyNew()
  local self = Event.new(ContractProgressEvent_mt)
  return self
end

function ContractProgressEvent.new(contractId, completion)
  local self = ContractProgressEvent.emptyNew()
  self.contractId = contractId
  self.completion = completion
  return self
end

function ContractProgressEvent:writeStream(streamId, connection)
  streamWriteInt32(streamId, self.contractId)
  streamWriteFloat32(streamId, self.completion)
end

function ContractProgressEvent:readStream(streamId, connection)
  self.contractId = streamReadInt32(streamId)
  self.completion = streamReadFloat32(streamId)
  self:run(connection)
end

function ContractProgressEvent:run(connection)
  -- Progress is measured on the server only, clients never send this event.
  if connection ~= nil and not connection:getIsServer() then
    return
  end

  local contractManager = g_currentMission.CustomContracts.ContractManager
  if contractManager == nil then
    return
  end

  local contract = contractManager:getContractById(self.contractId)
  if contract == nil then
    return
  end

  contract.completion = self.completion

  g_messageCenter:publish(MessageType.CUSTOM_CONTRACT_PROGRESS_UPDATED, contract)
end
