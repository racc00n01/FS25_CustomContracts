--
-- FS25 Contract and Invoices
--
-- @Author: Racc00n
-- @Version: 1.0.0.0
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
  self.contracts = contracts
  self.nextId = nextId

  return self
end

function SyncContractsEvent:writeStream(streamId, connection)
  streamWriteInt32(streamId, self.nextId)

  local count = table.size(self.contracts)
  streamWriteInt32(streamId, count)

  for _, contract in pairs(self.contracts) do
    streamWriteInt32(streamId, contract.id)
    streamWriteInt32(streamId, contract.creatorFarmId)
    streamWriteInt32(streamId, contract.contractorFarmId or -1)
    streamWriteInt32(streamId, contract.farmlandId)
    streamWriteInt32(streamId, contract.workAreaTypeIndex)
    streamWriteInt32(streamId, contract.reward)
    streamWriteString(streamId, contract.status)
    streamWriteString(streamId, contract.description or "")
    streamWriteInt32(streamId, contract.startPeriod)
    streamWriteInt32(streamId, contract.startDay)
    streamWriteInt32(streamId, contract.duePeriod)
    streamWriteInt32(streamId, contract.dueDay)
    streamWriteInt32(streamId, contract.invoiceId or -1)
    streamWriteString(streamId, contract.templateId or CustomContract.TEMPLATE.FIELD_WORK)
    streamWriteInt32(streamId, contract.fillTypeIndex or -1)
    streamWriteInt32(streamId, contract.transportAmount or -1)
    streamWriteInt32(streamId, contract.destinationId or -1)
    streamWriteFloat32(streamId, contract.destinationX or 0)
    streamWriteFloat32(streamId, contract.destinationZ or 0)
    streamWriteFloat32(streamId, contract.transportSoldPrice or 0)
    CustomContract.writeVehicleEntriesToStream(streamId, contract.transportVehicleEntries)
  end
end

function SyncContractsEvent:readStream(streamId, connection)
  self.nextId = streamReadInt32(streamId)
  local count = streamReadInt32(streamId)

  self.contracts = {}

  for i = 1, count do
    local id                  = streamReadInt32(streamId)
    local creatorFarmId       = streamReadInt32(streamId)
    local contractorFarmId    = streamReadInt32(streamId)
    local farmlandId          = streamReadInt32(streamId)
    local workAreaTypeIndex   = streamReadInt32(streamId)
    local reward              = streamReadInt32(streamId)
    local status              = streamReadString(streamId)
    local description         = streamReadString(streamId)
    local startPeriod         = streamReadInt32(streamId)
    local startDay            = streamReadInt32(streamId)
    local duePeriod           = streamReadInt32(streamId)
    local dueDay              = streamReadInt32(streamId)
    local invoiceId           = streamReadInt32(streamId)
    local templateId          = streamReadString(streamId)
    local fillTypeIndex       = streamReadInt32(streamId)
    local transportAmount     = streamReadInt32(streamId)
    local destinationId       = streamReadInt32(streamId)
    local destinationX        = streamReadFloat32(streamId)
    local destinationZ        = streamReadFloat32(streamId)
    local transportSoldPrice  = streamReadFloat32(streamId)
    local transportVehicleEntries = CustomContract.readVehicleEntriesFromStream(streamId)

    local contract            = CustomContract.new(
      id,
      creatorFarmId,
      farmlandId,
      workAreaTypeIndex,
      reward,
      description,
      startPeriod,
      startDay,
      duePeriod,
      dueDay,
      invoiceId,
      templateId or CustomContract.TEMPLATE.FIELD_WORK
    )

    contract.contractorFarmId = contractorFarmId ~= -1 and contractorFarmId or nil
    contract.status           = status
    if fillTypeIndex and fillTypeIndex >= 0 then contract.fillTypeIndex = fillTypeIndex end
    if transportAmount and transportAmount >= 0 then contract.transportAmount = transportAmount end
    if destinationId ~= nil then contract.destinationId = destinationId end
    if destinationX and destinationX ~= 0 then contract.destinationX = destinationX end
    if destinationZ and destinationZ ~= 0 then contract.destinationZ = destinationZ end
    contract.transportSoldPrice = transportSoldPrice or 0
    contract.transportVehicleEntries = transportVehicleEntries

    self.contracts[id] = contract
  end

  self:run(connection)
end

function SyncContractsEvent:run(connection)
  local contractManager = g_currentMission.CustomContracts.ContractManager
  if contractManager == nil then
    return
  end

  contractManager.contracts = self.contracts
  contractManager.nextId = self.nextId

  g_messageCenter:publish(MessageType.CUSTOM_CONTRACTS_UPDATED)
end
