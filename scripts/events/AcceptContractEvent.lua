AcceptContractEvent = {}
AcceptContractEvent_mt = Class(AcceptContractEvent, Event)

InitEventClass(AcceptContractEvent, "AcceptContractEvent")

function AcceptContractEvent.emptyNew()
    local self = Event.new(AcceptContractEvent_mt)

    return self
end

function AcceptContractEvent.new(contractId, farmId)
    local self = AcceptContractEvent.emptyNew()

    self.farmId = farmId
    self.contractId = contractId
    return self
end

function AcceptContractEvent:readStream(streamId, connection)
    self.farmId = streamReadInt32(streamId)
    self.contractId = streamReadInt32(streamId)
    self:run(connection)
end

function AcceptContractEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.farmId)
    streamWriteInt32(streamId, self.contractId)
end

function AcceptContractEvent:run(connection)
    -- Only the server may act
    if g_server == nil then
        return
    end

    -- 🚫 Ignore executions that are not from a player connection
    if connection == nil or connection:getIsServer() then
        return
    end

    -- Retrieve the contract
    local contract = g_customContractManager.contracts[self.contractId]

    print(
        "AcceptContractEvent server-side",
        "farmId:", self.farmId
    )

    if self.farmId == nil or self.farmId == FarmManager.SPECTATOR_FARM_ID then
        return
    end

    if g_customContractManager == nil then
        return
    end

    -- Validation if contract is open or not
    if contract == nil then InfoDialog.show("Contract was not found.") end
    if contract.status ~= CustomContract.STATUS.OPEN then InfoDialog.show("You cannot accept this contract.") end
    if contract.creatorFarmId == self.farmId then InfoDialog.show("You cannot accept your own contract.") end -- Cannot accept own contract

    g_customContractManager:acceptContract(self.contractId, self.farmId)
end
