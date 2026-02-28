--
-- FS25 Contract and Invoices
--
-- @Author: Racc00n
-- @Version: 1.0.0.0
--

CreateContractEvent = {}
local CreateContractEvent_mt = Class(CreateContractEvent, Event)

InitEventClass(CreateContractEvent, "CreateContractEvent")

function CreateContractEvent.emptyNew()
  local self = Event.new(CreateContractEvent_mt)
  return self
end

function CreateContractEvent.new(payload, farmId)
  local self = CreateContractEvent.emptyNew()
  self.payload = payload
  self.farmId = farmId
  return self
end

function CreateContractEvent:writeStream(streamId, connection)
  streamWriteInt32(streamId, self.farmId)
  streamWriteString(streamId, self.payload.templateId or CustomContract.TEMPLATE.FIELD_WORK)
  streamWriteInt32(streamId, self.payload.farmlandId or -1)
  streamWriteInt32(streamId, self.payload.workAreaTypeIndex or 0)
  streamWriteInt32(streamId, self.payload.reward)
  streamWriteString(streamId, self.payload.description or "")
  streamWriteInt32(streamId, self.payload.startPeriod)
  streamWriteInt32(streamId, self.payload.startDay)
  streamWriteInt32(streamId, self.payload.duePeriod)
  streamWriteInt32(streamId, self.payload.dueDay)
  streamWriteInt32(streamId, self.payload.invoiceId or -1)
  streamWriteInt32(streamId, self.payload.fillTypeIndex or -1)
  streamWriteInt32(streamId, self.payload.transportAmount or -1)
  streamWriteInt32(streamId, self.payload.destinationId or -1)
end

function CreateContractEvent:readStream(streamId, connection)
  self.farmId = streamReadInt32(streamId)
  self.payload = {
    templateId        = streamReadString(streamId),
    farmlandId        = streamReadInt32(streamId),
    workAreaTypeIndex = streamReadInt32(streamId),
    reward            = streamReadInt32(streamId),
    description       = streamReadString(streamId),
    startPeriod       = streamReadInt32(streamId),
    startDay          = streamReadInt32(streamId),
    duePeriod         = streamReadInt32(streamId),
    dueDay            = streamReadInt32(streamId),
    invoiceId         = streamReadInt32(streamId),
    fillTypeIndex     = streamReadInt32(streamId),
    transportAmount   = streamReadInt32(streamId),
    destinationId     = streamReadInt32(streamId)
  }

  self:run(connection)
end

function CreateContractEvent:run(connection)
  if not connection:getIsServer() then
    g_server:broadcastEvent(CreateContractEvent.new(self.payload, self.farmId))
  end

  local farmId = self.farmId
  if farmId == nil or farmId == FarmManager.SPECTATOR_FARM_ID then
    return
  end

  local contractManager = g_currentMission.CustomContracts.ContractManager
  contractManager:handleCreateRequest(farmId, self.payload)
end
