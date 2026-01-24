CreateContractEvent = {}
local CreateContractEvent_mt = Class(CreateContractEvent, Event)

InitEventClass(CreateContractEvent, "CreateContractEvent")

-- REQUIRED by Giants networking
function CreateContractEvent.emptyNew()
  local self = Event.new(CreateContractEvent_mt)
  return self
end

-- Used by client UI
function CreateContractEvent.new(payload)
  local self = CreateContractEvent.emptyNew()
  self.payload = payload
  return self
end

function CreateContractEvent:writeStream(streamId, connection)
  streamWriteInt32(streamId, self.payload.fieldId)
  streamWriteString(streamId, self.payload.workType)
  streamWriteInt32(streamId, self.payload.reward)
end

function CreateContractEvent:readStream(streamId, connection)
  self.payload = {
    fieldId  = streamReadInt32(streamId),
    workType = streamReadString(streamId),
    reward   = streamReadInt32(streamId)
  }

  self:run(connection)
end

function CreateContractEvent:run(connection)
  -- 🔒 Server only
  if g_server == nil then
    return
  end

  -- 🔒 Ignore server-originated runs
  if connection == nil or connection:getIsServer() then
    return
  end

  if g_customContractManager == nil then
    return
  end

  local farmId = connection.farmId
  if farmId == nil or farmId == FarmManager.SPECTATOR_FARM_ID then
    return
  end

  g_customContractManager:handleCreateRequest(farmId, self.payload)
end
