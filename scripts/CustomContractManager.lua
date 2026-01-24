--
-- FS25 CustomContracts
--
-- @Author: Racc00n
-- @Date: -
-- @Version: 0.0.0.1
--

CustomContractManager           = {}
CustomContractManager_mt        = Class(CustomContractManager)
CustomContract.dir              = g_currentModDirectory
CustomContract.modName          = g_currentModName

CustomContractManager.contracts = {}
CustomContractManager.nextId    = 1


function CustomContractManager:new()
  local self = {}
  setmetatable(self, CustomContractManager_mt)

  self.contracts = {}
  self.nextId = 1

  g_messageCenter:subscribe(
    MessageType.PLAYER_CONNECTED,
    self.onPlayerConnected,
    self
  )

  return self
end

function CustomContractManager:saveToXmlFile(xmlFile)
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

    count = count + 1
  end
end

function CustomContractManager:loadFromXmlFile(xmlFile)
  if not g_currentMission:getIsServer() then
    return
  end

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

    local contract = CustomContract.new(
      id,
      creatorFarmId,
      fieldId,
      workType,
      reward
    )

    contract.contractorFarmId = contractorFarmId ~= -1 and contractorFarmId or nil
    contract.status = status

    self.contracts[id] = contract
    self.nextId = math.max(self.nextId, id + 1)

    i = i + 1
  end

  self:syncContracts()
end

function CustomContractManager:onPlayerConnected(player)
  if not g_currentMission:getIsServer() then return end

  if player.connection ~= nil then
    self:syncContracts(player.connection)
  end
end

-- Called by CreateContractEvent, runs on server
function CustomContractManager:createContract(farmId, contract)
  if g_server == nil then
    return
  end

  print("Creating contract for farmId: " .. tostring(farmId))

  if farmId == nil or farmId == FarmManager.SPECTATOR_FARM_ID then
    return
  end

  local id = self.nextId
  self.nextId = self.nextId + 1

  local newContract = CustomContract.new(
    id,
    farmId,
    contract.fieldId,
    contract.workType,
    contract.reward
  )

  self.contracts[id] = newContract

  print(" Contract created with ID: " .. tostring(farmId))

  self:syncContracts()
  g_messageCenter:publish(MessageType.CUSTOM_CONTRACTS_UPDATED)
end

-- Function to acceptContract, called by AcceptContractEvent
function CustomContractManager:acceptContract(contractId, farmId)
  print("CustomContractManager:acceptContract called")
  if g_server == nil then
    return
  end

  if farmId == nil or farmId == FarmManager.SPECTATOR_FARM_ID then
    return
  end

  local contract = self.contracts[contractId]
  print(" Retrieved contract: " .. tostring(contract.id))
  if contract == nil then return end

  if contract.status ~= CustomContract.STATUS.OPEN then return end

  contract.contractorFarmId = farmId
  contract.status = CustomContract.STATUS.ACCEPTED

  print("Contract accepted: " .. tostring(contract.id))

  self:syncContracts()
  g_messageCenter:publish(MessageType.CUSTOM_CONTRACTS_UPDATED)

  -- TODO: grant field access
end

-- Function to completeContract, called by CompleteContractEvent
function CustomContractManager:completeContract(contractId)
  local contract = self.contracts[contractId]
  if contract == nil then return end

  if contract.status ~= CustomContract.STATUS.ACCEPTED then
    InfoDialog.show("You cannot complete this contract.")
    return
  end

  if contract.creatorFarmId == nil or contract.contractorFarmId == nil then
    InfoDialog.show("One of the farms involved in the contract does not exist.")
    return
  end

  if g_farmManager:getFarmById(contract.creatorFarmId).money < contract.reward then
    InfoDialog.show("Creator farm cannot afford reward.")
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

    g_farmManager:getFarmById(contract.creatorFarmId):changeBalance(-contract.reward, MoneyType.MISSIONS)

    -- Pay the contractor
    g_currentMission:addMoneyChange(
      contract.reward,
      contract.contractorFarmId,
      MoneyType.MISSIONS,
      true
    )

    g_farmManager:getFarmById(contract.contractorFarmId):changeBalance(contract.reward, MoneyType.MISSIONS)
  end

  -- Change status of contract to be completed
  contract.status = CustomContract.STATUS.COMPLETED

  -- Update all clients
  self:syncContracts()
  g_messageCenter:publish(MessageType.CUSTOM_CONTRACTS_UPDATED)
end

-- Function to cancelContract, called by CancelContractEvent
function CustomContractManager:cancelContract(contractId, farmId)
  if g_server == nil then
    return
  end

  local contract = self.contracts[contractId]
  if contract == nil then return end

  if contract.status ~= CustomContract.STATUS.OPEN and contract.status ~= CustomContract.STATUS.ACCEPTED then
    InfoDialog.show("You cannot cancel this contract.")
    return
  end

  contract.contractorFarmId = nil
  contract.status = CustomContract.STATUS.CANCELLED

  self:syncContracts()
  g_messageCenter:publish(MessageType.CUSTOM_CONTRACTS_UPDATED)
end

-- Function to deleteContract, called by DeleteContractEvent
function CustomContractManager:deleteContract(contractId, farmId)
  local contract = self.contracts[contractId]
  if contract == nil then return end

  if contract.status ~= CustomContract.STATUS.CANCELLED then
    InfoDialog.show("Your first need to cancel this contract, before being able to delete it.")
    return
  end

  self.contracts[contractId] = nil

  self:syncContracts()
  g_messageCenter:publish(MessageType.CUSTOM_CONTRACTS_UPDATED)
end

-- Function to sync contracts to clients
function CustomContractManager:syncContracts(connection)
  if not g_currentMission:getIsServer() then
    return
  end

  if connection ~= nil then
    connection:sendEvent(SyncContractsEvent.new(self.contracts, self.nextId))
  else
    g_server:broadcastEvent(
      SyncContractsEvent.new(self.contracts, self.nextId),
      false
    )
  end
end
