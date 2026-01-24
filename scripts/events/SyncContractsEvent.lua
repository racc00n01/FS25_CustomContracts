SyncContractsEvent = {}
SyncContractsEvent_mt = Class(SyncContractsEvent, Event)

InitEventClass(SyncContractsEvent, "SyncContractsEvent")

function SyncContractsEvent.new(contracts, nextId)
  local self = Event.new(SyncContractsEvent_mt)
  self.contracts = contracts
  self.nextId = nextId
  return self
end

function SyncContractsEvent:writeStream(streamId, connection)
  streamWriteInt32(streamId, self.nextId)

  local count = table.size(self.contracts)
  streamWriteInt32(streamId, count)

  for _, contract in pairs(self.contracts) do
    contract:writeStream(streamId)
    -- streamWriteInt32(streamId, contract.id)
    -- streamWriteInt32(streamId, contract.creatorFarmId)
    -- streamWriteInt32(streamId, contract.contractorFarmId or -1)
    -- streamWriteInt32(streamId, contract.fieldId)
    -- streamWriteString(streamId, contract.workType)
    -- streamWriteInt32(streamId, contract.reward)
    -- streamWriteString(streamId, contract.status)
    -- streamWriteFloat(streamId, contract.progress)
  end
end

function SyncContractsEvent:readStream(streamId, connection)
  local nextId = streamReadInt32(streamId)
  local count = streamReadInt32(streamId)

  self.contracts = {}

  for i = 1, count do
    local contract = CustomContract.newFromStream(streamId)
    self.contracts[contract.id] = contract
  end

  self:run(connection)

  -- for i = 1, count do
  --   local id = streamReadInt32(streamId)
  --   local creatorFarmId = streamReadInt32(streamId)
  --   local contractorFarmId = streamReadInt32(streamId)
  --   local fieldId = streamReadInt32(streamId)
  --   local workType = streamReadString(streamId)
  --   local reward = streamReadInt32(streamId)
  --   local status = streamReadString(streamId)
  --   local progress = streamReadFloat(streamId)

  --   local contract = CustomContract.new(
  --     id,
  --     creatorFarmId,
  --     fieldId,
  --     workType,
  --     reward
  --   )

  --   contract.contractorFarmId = contractorFarmId ~= -1 and contractorFarmId or nil
  --   contract.status = status
  --   contract.progress = progress

  --   self.contracts[id] = contract
  -- end

  -- self:run(connection)
end

function SyncContractsEvent:run(connection)
  if g_customContractManager == nil then
    return
  end

  -- overwrite client copy
  g_customContractManager.contracts = self.contracts
  g_customContractManager.nextId = self.nextId

  -- 🔴 THIS triggers the menu update
  g_messageCenter:publish(MessageType.CUSTOM_CONTRACTS_UPDATED)
end
