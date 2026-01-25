AcceptContractEvent = {}
local AcceptContractEvent_mt = Class(AcceptContractEvent, Event)

InitEventClass(AcceptContractEvent, "AcceptContractEvent")

-- REQUIRED
function AcceptContractEvent.emptyNew()
    local self = Event.new(AcceptContractEvent_mt)
    return self
end

-- Used by client UI
function AcceptContractEvent.new(contractId)
    local self = AcceptContractEvent.emptyNew()
    self.contractId = contractId
    return self
end

function AcceptContractEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.contractId)
end

function AcceptContractEvent:readStream(streamId, connection)
    self.contractId = streamReadInt32(streamId)
    self:run(connection)
end

function AcceptContractEvent:run(connection)
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

    contractManager:handleAcceptRequest(farmId, self.contractId)
end
