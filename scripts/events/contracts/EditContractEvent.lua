--
-- FS25 CustomContracts
--
-- @Author: Racc00n
-- @Version: 0.0.1.1
--

EditContractEvent = {}
local EditContractEvent_mt = Class(EditContractEvent, Event)

InitEventClass(EditContractEvent, "EditContractEvent")

function EditContractEvent.emptyNew()
  local self = Event.new(EditContractEvent_mt)
  return self
end

function EditContractEvent.new(contractId, contractData, farmId)
  local self             = EditContractEvent.emptyNew()

  self.contractId        = contractId
  self.farmId            = farmId

  self.farmlandId        = contractData.farmlandId
  self.workAreaTypeIndex = contractData.workAreaTypeIndex
  self.reward            = contractData.reward
  self.description       = contractData.description
  self.startPeriod       = contractData.startPeriod
  self.startDay          = contractData.startDay
  self.duePeriod         = contractData.duePeriod
  self.dueDay            = contractData.dueDay

  return self
end

function EditContractEvent:writeStream(streamId, connection)
  streamWriteInt32(streamId, self.contractId)
  streamWriteInt32(streamId, self.farmId)

  streamWriteInt32(streamId, self.farmlandId)
  streamWriteInt32(streamId, self.workAreaTypeIndex)
  streamWriteInt32(streamId, self.reward)
  streamWriteString(streamId, self.description or "")

  streamWriteInt32(streamId, self.startPeriod)
  streamWriteInt32(streamId, self.startDay)
  streamWriteInt32(streamId, self.duePeriod)
  streamWriteInt32(streamId, self.dueDay)
end

function EditContractEvent:readStream(streamId, connection)
  self.contractId        = streamReadInt32(streamId)
  self.farmId            = streamReadInt32(streamId)

  self.farmlandId        = streamReadInt32(streamId)
  self.workAreaTypeIndex = streamReadInt32(streamId)
  self.reward            = streamReadInt32(streamId)
  self.description       = streamReadString(streamId)

  self.startPeriod       = streamReadInt32(streamId)
  self.startDay          = streamReadInt32(streamId)
  self.duePeriod         = streamReadInt32(streamId)
  self.dueDay            = streamReadInt32(streamId)

  self:run(connection)
end

function EditContractEvent:run(connection)
  if not connection:getIsServer() then
    g_server:broadcastEvent(
      EditContractEvent.new(
        self.contractId,
        {
          farmlandId        = self.farmlandId,
          workAreaTypeIndex = self.workAreaTypeIndex,
          reward            = self.reward,
          description       = self.description,
          startPeriod       = self.startPeriod,
          startDay          = self.startDay,
          duePeriod         = self.duePeriod,
          dueDay            = self.dueDay
        },
        self.farmId
      )
    )
  end

  local contractManager = g_currentMission.CustomContracts.ContractManager
  contractManager:handleEditRequest(self.farmId, self.contractId, {
    farmlandId        = self.farmlandId,
    workAreaTypeIndex = self.workAreaTypeIndex,
    reward            = self.reward,
    description       = self.description,
    startPeriod       = self.startPeriod,
    startDay          = self.startDay,
    duePeriod         = self.duePeriod,
    dueDay            = self.dueDay
  })
end
