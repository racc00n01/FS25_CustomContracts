CreateContractEvent = {}
local CreateContractEvent_mt = Class(CreateContractEvent, Event)

InitEventClass(CreateContractEvent, "CreateContractEvent")

-- REQUIRED by Giants networking
function CreateContractEvent.emptyNew()
  local self = Event.new(CreateContractEvent_mt)
  return self
end

-- Used by client UI
function CreateContractEvent.new(payload, farmId)
  local self = CreateContractEvent.emptyNew()
  self.payload = payload
  self.farmId = farmId
  return self
end

function CreateContractEvent:writeStream(streamId, connection)
  streamWriteInt32(streamId, self.farmId)
  streamWriteInt32(streamId, self.payload.fieldId)
  streamWriteString(streamId, self.payload.workType)
  streamWriteInt32(streamId, self.payload.reward)
end

function CreateContractEvent:readStream(streamId, connection)
  self.farmId = streamReadInt32(streamId)
  self.payload = {
    fieldId  = streamReadInt32(streamId),
    workType = streamReadString(streamId),
    reward   = streamReadInt32(streamId)
  }

  self:run(connection)
end

function CreateContractEvent:run(connection)
  if not connection:getIsServer() then
    g_server:broadcastEvent(CreateContractEvent.new(self.payload))
  end

  local farmId = self.farmId
  if farmId == nil or farmId == FarmManager.SPECTATOR_FARM_ID then
    print("[CustomContracts] Invalid farmId in CreateContractEvent: ", tostring(farmId))
    return
  end

  local contractManager = g_currentMission.customContracts.ContractManager
  contractManager:handleCreateRequest(farmId, self.payload)
end
