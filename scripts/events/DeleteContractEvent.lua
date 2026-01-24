DeleteContractEvent = {}
DeleteContractEvent_mt = Class(DeleteContractEvent, Event)

InitEventClass(DeleteContractEvent, "DeleteContractEvent")

function DeleteContractEvent.new(farmId, contractId)
  local self = Event.new(DeleteContractEvent_mt)
  self.farmId = farmId
  self.contractId = contractId
  return self
end

function DeleteContractEvent:readStream(streamId, connection)
  self.farmId = streamReadInt32(streamId)
  self.contractId = streamReadInt32(streamId)
  self:run(connection)
end

function DeleteContractEvent:writeStream(streamId, connection)
  streamWriteInt32(streamId, self.farmId)
  streamWriteInt32(streamId, self.contractId)
end

function DeleteContractEvent:run(connection)
  -- Retrieve the contract
  local contract = g_customContractManager.contracts[self.contractId]

  if self.farmId == nil or self.farmId == FarmManager.SPECTATOR_FARM_ID then
    return
  end


  -- Validation if contract is open or accepted
  if contract == nil then InfoDialog.show("Contract was not found.") end
  if contract.status ~= CustomContract.STATUS.CANCELLED then
    InfoDialog.show("Your first need to cancel this contract, before being able to delete it.")
  end

  g_customContractManager:deleteContract(self.contractId, self.farmId)
end
