--
-- FS25 CustomContracts
--
-- @Author: Racc00n
-- @Date: -
-- @Version: 0.0.0.1
--

CustomContractManager    = {}
CustomContractManager_mt = Class(CustomContractManager)
CustomContract.dir       = g_currentModDirectory
CustomContract.modName   = g_currentModName

function CustomContractManager:new()
  local self = {}
  setmetatable(self, CustomContractManager_mt)
  self.contracts = {}
  self.nextId = 1

  if g_currentMission:getIsServer() then
    g_messageCenter:subscribe(
      MessageType.PLAYER_CONNECTED,
      self.onPlayerConnected,
      self
    )
  end

  return self
end

function CustomContractManager:saveToXmlFile(xmlFile)
  if not g_currentMission:getIsServer() then return end

  local key = CustomContracts.SaveKey
  local count = 0

  for id, contract in pairs(self.contracts) do
    local key = string.format("%s.contract(%d)", key, count)

    setXMLInt(xmlFile, key .. "#id", contract.id)
    setXMLInt(xmlFile, key .. "#creatorFarmId", contract.creatorFarmId)
    setXMLInt(xmlFile, key .. "#contractorFarmId", contract.contractorFarmId or -1)
    setXMLInt(xmlFile, key .. "#fieldId", contract.fieldId)
    setXMLString(xmlFile, key .. "#workType", contract.workType)
    setXMLInt(xmlFile, key .. "#reward", contract.reward)
    setXMLString(xmlFile, key .. "#status", contract.status)
    setXMLString(xmlFile, key .. "#description", contract.description or '-')

    count = count + 1
  end
end

function CustomContractManager:loadFromXmlFile(xmlFile)
  if not g_currentMission:getIsServer() then return end

  self.contracts = {}
  self.nextId = 1

  local key = CustomContracts.SaveKey
  local i = 0

  while true do
    local contractKey = string.format("%s.contract(%d)", key, i)
    if not hasXMLProperty(xmlFile, contractKey) then
      break
    end

    local id = getXMLInt(xmlFile, contractKey .. "#id")
    local creatorFarmId = getXMLInt(xmlFile, contractKey .. "#creatorFarmId")
    local contractorFarmId = getXMLInt(xmlFile, contractKey .. "#contractorFarmId")
    local fieldId = getXMLInt(xmlFile, contractKey .. "#fieldId")
    local workType = getXMLString(xmlFile, contractKey .. "#workType")
    local reward = getXMLInt(xmlFile, contractKey .. "#reward")
    local status = getXMLString(xmlFile, contractKey .. "#status")
    local description = getXMLString(xmlFile, contractKey .. "#description")

    local contract = CustomContract.new(
      id,
      creatorFarmId,
      fieldId,
      workType,
      reward,
      description
    )

    contract.contractorFarmId = contractorFarmId ~= -1 and contractorFarmId or nil
    contract.status = status

    self.contracts[id] = contract
    self.nextId = math.max(self.nextId, id + 1)

    i = i + 1
  end

  self:syncContracts()
end

function CustomContractManager:writeInitialClientState(streamId, connection)
  -- nextId
  streamWriteInt32(streamId, self.nextId)

  -- contract count
  local count = table.size(self.contracts)
  streamWriteInt32(streamId, count)

  for _, contract in pairs(self.contracts) do
    contract:writeStream(streamId)
  end
end

function CustomContractManager:readInitialClientState(streamId, connection)
  self.contracts = {}

  self.nextId = streamReadInt32(streamId)
  local count = streamReadInt32(streamId)

  for i = 1, count do
    local contract = CustomContract.newFromStream(streamId)
    self.contracts[contract.id] = contract
  end

  -- notify UI
  g_messageCenter:publish(MessageType.CUSTOM_CONTRACTS_UPDATED)
end

-- Function to sync contracts to clients
function CustomContractManager:syncContracts(connection)
  if not g_currentMission:getIsServer() then return end

  print(
    "[CustomContracts][SERVER] syncContracts called",
    "contracts:", table.size(self.contracts),
    "nextId:", self.nextId
  )

  local event = SyncContractsEvent.new(self.contracts, self.nextId)


  if connection ~= nil then
    print("[CustomContracts][SERVER] sending SyncContractsEvent to a single client")
    connection:sendEvent(event)
  else
    print("[CustomContracts][SERVER] broadcasting SyncContractsEvent")
    g_server:broadcastEvent(event, true)
  end
end

function CustomContractManager:onPlayerConnected(connection)
  if not g_currentMission:getIsServer() then return end
  if connection == nil then return end

  print("[CustomContracts][SERVER] player connected → syncing contracts")

  self:syncContracts(connection)
end

-- Called by CreateContractEvent, runs on server
function CustomContractManager:handleCreateRequest(farmId, payload)
  if not g_currentMission:getIsServer() then return end
  print(
    "[CustomContracts] handleCreateRequest called",
    "farmId:", farmId,
    "payload:", payload
  )
  -- if farmId == FarmManager.SPECTATOR_FARM_ID then return end

  if payload.fieldId == nil or payload.workType == nil or payload.reward <= 0 then
    print("[CustomContracts] Invalid contract payload")
    return
  end

  local id = self.nextId
  self.nextId = self.nextId + 1

  local contract = CustomContract.new(
    id,
    farmId,
    payload.fieldId,
    payload.workType,
    payload.reward,
    payload.description
  )

  self.contracts[id] = contract
  print(
    "[CustomContracts] Created new contract:",
    "id:", self.contracts[id].id,
    "creatorFarmId:", self.contracts[id].creatorFarmId,
    "fieldId:", self.contracts[id].fieldId,
    "workType:", self.contracts[id].workType,
    "reward:", self.contracts[id].reward,
    "description:", self.contracts[id].description
  )

  self:syncContracts()
end

-- Function to acceptContract, called by AcceptContractEvent
function CustomContractManager:handleAcceptRequest(farmId, contractId)
  if not g_currentMission:getIsServer() then return end

  local contract = self.contracts[contractId]
  if contract == nil then return end
  if contract.status ~= CustomContract.STATUS.OPEN then return end
  if contract.creatorFarmId == farmId then return end

  if farmId == nil or farmId == FarmManager.SPECTATOR_FARM_ID then
    return
  end

  contract.contractorFarmId = farmId
  contract.status = CustomContract.STATUS.ACCEPTED

  self:syncContracts()

  -- TODO: grant field access
end

-- Function to completeContract, called by CompleteContractEvent
function CustomContractManager:handleCompleteRequest(farmId, contractId)
  if not g_currentMission:getIsServer() then return end

  local contract = self.contracts[contractId]
  if contract == nil then return end
  if contract.status ~= CustomContract.STATUS.ACCEPTED then return end
  if contract.contractorFarmId ~= farmId then return end

  if g_farmManager:getFarmById(contract.creatorFarmId).money < contract.reward then
    return
  end

  if g_currentMission:getIsServer() then
    -- Remove money from creator farm
    g_currentMission:addMoneyChange(
      -contract.reward,
      contract.creatorFarmId,
      MoneyType.MISSIONS,
      true
    )

    -- Pay the contractor
    g_currentMission:addMoneyChange(
      contract.reward,
      contract.contractorFarmId,
      MoneyType.MISSIONS,
      true
    )
  end

  g_farmManager:getFarmById(contract.creatorFarmId):changeBalance(-contract.reward, MoneyType.MISSIONS)
  g_farmManager:getFarmById(contract.contractorFarmId):changeBalance(contract.reward, MoneyType.MISSIONS)

  -- Change status of contract to be completed
  contract.status = CustomContract.STATUS.COMPLETED

  -- Update all clients
  self:syncContracts()
end

-- Function to cancelContract, called by CancelContractEvent
function CustomContractManager:handleCancelRequest(farmId, contractId)
  if not g_currentMission:getIsServer() then return end

  local contract = self.contracts[contractId]
  if contract == nil then return end
  if contract.contractorFarmId ~= farmId then return end
  if contract.status ~= CustomContract.STATUS.OPEN and contract.status ~= CustomContract.STATUS.ACCEPTED then
    return
  end

  contract.contractorFarmId = nil
  contract.status = CustomContract.STATUS.CANCELLED

  self:syncContracts()
end

-- Function to deleteContract, called by DeleteContractEvent
function CustomContractManager:handleDeleteRequest(farmId, contractId)
  if not g_currentMission:getIsServer() then return end

  local contract = self.contracts[contractId]
  if contract == nil then return end
  if contract.creatorFarmId ~= farmId then return end

  self.contracts[contractId] = nil

  self:syncContracts()
end
