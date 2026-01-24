AcceptContractEvent = {}
AcceptContractEvent_mt = Class(AcceptContractEvent, Event)

InitEventClass(AcceptContractEvent, "AcceptContractEvent")

function AcceptContractEvent.new(contractId)
    local self = Event.new(AcceptContractEvent_mt)
    self.contractId = contractId
    return self
end

function AcceptContractEvent:readStream(streamId, connection)
    self.contractId = streamReadInt32(streamId)
    self:run(connection)
end

function AcceptContractEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.contractId)
end

function AcceptContractEvent:run(connection)
    -- Retrieve the contract
    local farmId = g_currentMission:getFarmId()
    local contract = g_customContractManager.contracts[self.contractId]

    -- Validation if contract is open or not
    if contract == nil then InfoDialog.show("Contract was not found.") end
    if contract.status ~= CustomContract.STATUS.OPEN then InfoDialog.show("You cannot accept this contract.") end
    if contract.creatorFarmId == farmId then InfoDialog.show("You cannot accept your own contract.") end -- Cannot accept own contract

    g_customContractManager:acceptContract(self.contractId, farmId)
end
