CancelContractEvent = {}
CancelContractEvent_mt = Class(CancelContractEvent, Event)

InitEventClass(CancelContractEvent, "CancelContractEvent")

function CancelContractEvent.new(farmId, contractId)
  local self = Event.new(CancelContractEvent_mt)
  self.farmId = farmId
  self.contractId = contractId
  return self
end

function CancelContractEvent:readStream(streamId, connection)
  self.farmId = streamReadInt32(streamId)
  self.contractId = streamReadInt32(streamId)
  self:run(connection)
end

function CancelContractEvent:writeStream(streamId, connection)
  streamWriteInt32(streamId, self.farmId)
  streamWriteInt32(streamId, self.contractId)
end

function CancelContractEvent:run(connection)
  -- Retrieve the contract
  local contract = g_customContractManager.contracts[self.contractId]

  if self.farmId == nil or self.farmId == FarmManager.SPECTATOR_FARM_ID then
    return
  end

  -- Validation if contract is open or accepted
  if contract == nil then InfoDialog.show("Contract was not found.") end
  if contract.status ~= CustomContract.STATUS.OPEN and contract.status ~= CustomContract.STATUS.ACCEPTED then
    InfoDialog.show("You cannot cancel this contract.")
  end

  g_customContractManager:cancelContract(self.contractId, self.farmId)
end
