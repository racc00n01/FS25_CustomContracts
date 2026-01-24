print("[CustomContracts] SyncContractsEvent file loaded")
SyncContractsEvent = {}
local SyncContractsEvent_mt = Class(SyncContractsEvent, Event)

InitEventClass(SyncContractsEvent, "SyncContractsEvent")

function SyncContractsEvent.emptyNew()
  local self = Event.new(SyncContractsEvent_mt)
  return self
end

function SyncContractsEvent.new(contracts, nextId)
  local self = SyncContractsEvent.emptyNew()
  self.contracts = contracts
  self.nextId = nextId
  return self
end

function SyncContractsEvent:writeStream(streamId, connection)
  -- nextId
  streamWriteInt32(streamId, self.nextId)

  -- contract count
  local count = table.size(self.contracts)
  streamWriteInt32(streamId, count)

  for _, contract in pairs(self.contracts) do
    streamWriteInt32(streamId, contract.id)
    streamWriteInt32(streamId, contract.creatorFarmId)
    streamWriteInt32(streamId, contract.contractorFarmId or -1)
    streamWriteInt32(streamId, contract.fieldId)
    streamWriteString(streamId, contract.workType)
    streamWriteInt32(streamId, contract.reward)
    streamWriteString(streamId, contract.status)
  end
end

function SyncContractsEvent:readStream(streamId, connection)
  self.nextId = streamReadInt32(streamId)
  local count = streamReadInt32(streamId)

  self.contracts = {}

  for i = 1, count do
    local id = streamReadInt32(streamId)
    local creatorFarmId = streamReadInt32(streamId)
    local contractorFarmId = streamReadInt32(streamId)
    local fieldId = streamReadInt32(streamId)
    local workType = streamReadString(streamId)
    local reward = streamReadInt32(streamId)
    local status = streamReadString(streamId)

    local contract = CustomContract.new(
      id,
      creatorFarmId,
      fieldId,
      workType,
      reward
    )

    contract.contractorFarmId =
        contractorFarmId ~= -1 and contractorFarmId or nil
    contract.status = status

    self.contracts[id] = contract
  end

  self:run(connection)
end

function SyncContractsEvent:run(connection)
  print("[CustomContracts] SyncContractsEvent received on client")
  if g_customContractManager == nil then
    return
  end

  print(
    "[CustomContracts] Publishing CUSTOM_CONTRACTS_UPDATED, contracts:",
    table.size(self.contracts)
  )

  print("[CustomContracts][CLIENT] SyncContractsEvent received")

  -- overwrite local (client) state
  g_customContractManager.contracts = self.contracts
  g_customContractManager.nextId = self.nextId

  -- notify UI
  g_messageCenter:publish(MessageType.CUSTOM_CONTRACTS_UPDATED)
end
