CreateContractEvent = {}
CreateContractEvent_mt = Class(CreateContractEvent, Event)

InitEventClass(CreateContractEvent, "CreateContractEvent")

function CreateContractEvent.emptyNew()
  local self = Event.new(CreateContractEvent_mt)

  return self
end

function CreateContractEvent.new(farmId, contract)
  local self = Event.new(CreateContractEvent_mt)
  self.farmId = farmId
  self.contract = contract
  return self
end

function CreateContractEvent:writeStream(streamId, connection)
  streamWriteInt32(streamId, self.farmId)
  streamWriteInt32(streamId, self.contract.fieldId)
  streamWriteString(streamId, self.contract.workType)
  streamWriteInt32(streamId, self.contract.reward)
end

function CreateContractEvent:readStream(streamId, connection)
  self.farmId = streamReadInt32(streamId)
  self.contract = {
    fieldId  = streamReadInt32(streamId),
    workType = streamReadString(streamId),
    reward   = streamReadInt32(streamId)
  }
  self:run(connection)
end

function CreateContractEvent:run(connection)
  -- Only the server may act
  if g_server == nil then
    return
  end

  -- 🚫 Ignore executions that are not from a player connection
  if connection == nil or connection:getIsServer() then
    return
  end

  print(
    "CreateContractEvent server-side",
    "farmId:", self.farmId
  )

  if self.farmId == nil or self.farmId == FarmManager.SPECTATOR_FARM_ID then
    return
  end

  if g_customContractManager == nil then
    return
  end

  g_customContractManager:createContract(self.farmId, self.contract)
end
