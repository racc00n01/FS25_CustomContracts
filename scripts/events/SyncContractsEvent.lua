--
-- FS25 CustomContracts
--
-- @Author: Racc00n
-- @Version: 0.0.1.1
--

SyncContractsEvent = {}
local SyncContractsEvent_mt = Class(SyncContractsEvent, Event)

InitEventClass(SyncContractsEvent, "SyncContractsEvent")

function SyncContractsEvent.emptyNew()
  local self = Event.new(SyncContractsEvent_mt)
  return self
end

function SyncContractsEvent.new(contracts, nextId)
  local self = SyncContractsEvent.emptyNew()
  self.contracts = contracts or {}
  self.nextId = nextId or 1
  return self
end

function SyncContractsEvent:writeStream(streamId, connection)
  -- nextId
  streamWriteInt32(streamId, self.nextId)

  -- contract count
  local count = table.size(self.contracts)
  streamWriteInt32(streamId, count)

  for _, contract in pairs(self.contracts) do
    -- IMPORTANT: delegate to contract serializer (template-aware)
    contract:writeStream(streamId)
  end
end

function SyncContractsEvent:readStream(streamId, connection)
  self.nextId = streamReadInt32(streamId)
  local count = streamReadInt32(streamId)

  self.contracts = {}

  for i = 1, count do
    -- IMPORTANT: delegate to contract deserializer (template-aware)
    local contract = CustomContract.newFromStream(streamId)
    if contract ~= nil then
      self.contracts[contract.id] = contract
    end
  end

  self:run(connection)
end

function SyncContractsEvent:run(connection)
  local contractManager = g_currentMission.CustomContracts.ContractManager
  if contractManager == nil then
    return
  end

  -- overwrite local (client) state
  contractManager.contracts = self.contracts
  contractManager.nextId = self.nextId

  -- notify UI
  g_messageCenter:publish(MessageType.CUSTOM_CONTRACTS_UPDATED)
end
