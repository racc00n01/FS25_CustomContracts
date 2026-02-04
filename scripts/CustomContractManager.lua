--
-- FS25 CustomContracts
--
-- @Author: Racc00n
-- @Version: 0.0.1.1
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
    setXMLInt(xmlFile, key .. "#reward", contract.reward)
    setXMLString(xmlFile, key .. "#status", contract.status)
    setXMLString(xmlFile, key .. "#description", contract.description or '-')
    setXMLInt(xmlFile, key .. "#startPeriod", contract.startPeriod or -1)
    setXMLInt(xmlFile, key .. "#startDay", contract.startDay or -1)
    setXMLInt(xmlFile, key .. "#duePeriod", contract.duePeriod or -1)
    setXMLInt(xmlFile, key .. "#dueDay", contract.dueDay or -1)

    setXMLString(xmlFile, key .. "#templateId", contract.templateId)

    -- template payload
    if contract.templateId == CustomContract.TEMPLATE.FIELD_WORK then
      setXMLInt(xmlFile, key .. "#fieldId", contract.payload.fieldId or -1)
      setXMLString(xmlFile, key .. "#workType", contract.payload.workType or "")
    elseif contract.templateId == CustomContract.TEMPLATE.TRANSPORT then
      setXMLString(xmlFile, key .. "#transportType", contract.payload.transportType or "")
      setXMLString(xmlFile, key .. "#fillType", contract.payload.fillType or "")
      setXMLInt(xmlFile, key .. "#amount", contract.payload.amount or 0)
    elseif contract.templateId == CustomContract.TEMPLATE.FARM_JOB then
      setXMLString(xmlFile, key .. "#jobType", contract.payload.jobType or "")
      setXMLString(xmlFile, key .. "#targetType", contract.payload.targetType or "")
      setXMLInt(xmlFile, key .. "#targetId", contract.payload.targetId or 0)
      setXMLInt(xmlFile, key .. "#amount", contract.payload.amount or 0)
    elseif contract.templateId == CustomContract.TEMPLATE.CUSTOM then
      setXMLString(xmlFile, key .. "#title", contract.payload.title or "Custom job")
    end

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

    local id               = getXMLInt(xmlFile, contractKey .. "#id")
    local creatorFarmId    = getXMLInt(xmlFile, contractKey .. "#creatorFarmId")
    local contractorFarmId = getXMLInt(xmlFile, contractKey .. "#contractorFarmId")
    local reward           = getXMLInt(xmlFile, contractKey .. "#reward")
    local status           = getXMLString(xmlFile, contractKey .. "#status")
    local description      = getXMLString(xmlFile, contractKey .. "#description")
    local startPeriod      = getXMLInt(xmlFile, contractKey .. "#startPeriod")
    local startDay         = getXMLInt(xmlFile, contractKey .. "#startDay")
    local duePeriod        = getXMLInt(xmlFile, contractKey .. "#duePeriod")
    local dueDay           = getXMLInt(xmlFile, contractKey .. "#dueDay")

    local templateId       = getXMLString(xmlFile, contractKey .. "#templateId") or CustomContract.TEMPLATE.FIELD_WORK
    local payloadTable     = {}

    -- Backward compatibility: if old save has no templateId, treat it as FIELD_WORK
    if not hasXMLProperty(xmlFile, contractKey .. "#templateId") then
      templateId = CustomContract.TEMPLATE.FIELD_WORK
    end

    if templateId == CustomContract.TEMPLATE.FIELD_WORK then
      payloadTable.fieldId  = getXMLInt(xmlFile, contractKey .. "#fieldId")
      payloadTable.workType = getXMLString(xmlFile, contractKey .. "#workType") or ""
    elseif templateId == CustomContract.TEMPLATE.TRANSPORT then
      payloadTable.transportType = getXMLString(xmlFile, contractKey .. "#transportType") or ""
      payloadTable.fillType      = getXMLString(xmlFile, contractKey .. "#fillType") or ""
      payloadTable.amount        = getXMLInt(xmlFile, contractKey .. "#amount") or 0
    elseif templateId == CustomContract.TEMPLATE.FARM_JOB then
      payloadTable.jobType    = getXMLString(xmlFile, contractKey .. "#jobType") or ""
      payloadTable.targetType = getXMLString(xmlFile, contractKey .. "#targetType") or ""
      payloadTable.targetId   = getXMLInt(xmlFile, contractKey .. "#targetId") or 0
      payloadTable.amount     = getXMLInt(xmlFile, contractKey .. "#amount") or 0
    elseif templateId == CustomContract.TEMPLATE.CUSTOM then
      payloadTable.title = getXMLString(xmlFile, contractKey .. "#title") or "Custom job"
    end

    local contract            = CustomContract.new(
      id,
      creatorFarmId,
      templateId,
      payloadTable,
      reward,
      description,
      startPeriod,
      startDay,
      duePeriod,
      dueDay
    )

    contract.contractorFarmId = contractorFarmId ~= -1 and contractorFarmId or nil
    contract.status           = status

    self.contracts[id]        = contract
    self.nextId               = math.max(self.nextId, id + 1)

    i                         = i + 1
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

  local event = SyncContractsEvent.new(self.contracts, self.nextId)


  if connection ~= nil then
    connection:sendEvent(event)
  else
    g_server:broadcastEvent(event, true)
  end
end

function CustomContractManager:onPlayerConnected(connection)
  if not g_currentMission:getIsServer() then return end
  if connection == nil then return end

  self:syncContracts(connection)
end

function CustomContractManager:getNewContractsForCurrentFarm()
  local newForFarm = {}

  local farmId = g_currentMission:getFarmId();
  if farmId == nil or farmId == 0 then
    return newForFarm
  end

  local contractManager = g_currentMission.CustomContracts.ContractManager

  for _, contract in pairs(contractManager.contracts) do
    -- Open contracts NOT created by you
    if contract.status == CustomContract.STATUS.OPEN
        and contract.creatorFarmId ~= farmId then
      table.insert(newForFarm, contract)
    end
  end

  return newForFarm
end

function CustomContractManager:getActiveContractsForCurrentFarm()
  local activeForFarm = {}

  local farmId = g_currentMission:getFarmId();
  if farmId == nil or farmId == 0 then
    return activeForFarm
  end

  local contractManager = g_currentMission.CustomContracts.ContractManager

  for _, contract in pairs(contractManager.contracts) do
    -- Contracts accepted by you or cancelled by you or the owner
    if (contract.status == CustomContract.STATUS.ACCEPTED or contract.status == CustomContract.STATUS.CANCELLED)
        and contract.contractorFarmId == farmId then
      table.insert(activeForFarm, contract)
    end
  end

  return activeForFarm
end

function CustomContractManager:getOwnedContractsForCurrentFarm()
  local ownedForFarm = {}

  local farmId = g_currentMission:getFarmId();
  if farmId == nil or farmId == 0 then
    return ownedForFarm
  end

  local contractManager = g_currentMission.CustomContracts.ContractManager

  for _, contract in pairs(contractManager.contracts) do
    -- Contracts you created (any status)
    if contract.creatorFarmId == farmId then
      table.insert(ownedForFarm, contract)
    end
  end

  return ownedForFarm
end

-- Called by CreateContractEvent, runs on server
function CustomContractManager:handleCreateRequest(farmId, payload)
  if not g_currentMission:getIsServer() then return end
  if payload == nil then return end

  local templateId = payload.templateId
  local p = payload.payload or {}

  -- common validation
  if templateId == nil or templateId == "" then return end
  if payload.reward == nil or payload.reward <= 0 then return end

  -- template-specific validation
  if templateId == CustomContract.TEMPLATE.FIELD_WORK then
    if p.fieldId == nil or p.fieldId <= 0 then return end
    if p.workType == nil or p.workType == "" then return end
  elseif templateId == CustomContract.TEMPLATE.TRANSPORT then
    if p.transportType == nil or p.transportType == "" then return end
    -- fillType/amount optional for now
  elseif templateId == CustomContract.TEMPLATE.FARM_JOB then
    if p.jobType == nil or p.jobType == "" then return end
    -- target optional for now
  elseif templateId == CustomContract.TEMPLATE.CUSTOM then
    -- title optional; we can default later
    if p.title == nil or p.title == "" then
      p.title = "Custom job"
    end
  else
    -- unknown template
    return
  end

  local id = self.nextId
  self.nextId = self.nextId + 1

  local contract = CustomContract.new(
    id,
    farmId,
    templateId,
    p,
    payload.reward,
    payload.description,
    payload.startPeriod,
    payload.startDay,
    payload.duePeriod,
    payload.dueDay
  )

  self.contracts[id] = contract
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

  -- Check who cancels the contract
  if farmId == contract.contractorFarmId then
    -- TODO: Add logic for a fine, if the start date is past
    contract.status = CustomContract.STATUS.CANCELLED
  else
    -- Owner cancels the contract
    -- TODO: Add fine, 10% of contract money will be transfered to contractor if the start date is past.
    contract.status = CustomContract.STATUS.CANCELLED
  end
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

-- Function to reopen contracts, called by ReopenContractEvent
function CustomContractManager:handleReopenRequest(farmId, contractId)
  if not g_currentMission:getIsServer() then return end

  local contract = self.contracts[contractId]
  if contract == nil then return end
  if contract.creatorFarmId ~= farmId then return end

  self.contracts[contractId].contractorFarmId = nil
  self.contracts[contractId].status = CustomContract.STATUS.OPEN

  self:syncContracts()
end

function CustomContractManager:handleEditRequest(farmId, contractId, data)
  local contract = self.contracts[contractId]
  if contract == nil then
    return
  end

  -- permission check
  if contract.creatorFarmId ~= farmId then
    return
  end

  -- usually only allow editing OPEN contracts
  if contract.status ~= CustomContract.STATUS.OPEN then
    return
  end

  -- apply edits
  contract.fieldId     = data.fieldId
  contract.workType    = data.workType
  contract.reward      = data.reward
  contract.description = data.description
  contract.startPeriod = data.startPeriod
  contract.startDay    = data.startDay
  contract.duePeriod   = data.duePeriod
  contract.dueDay      = data.dueDay

  -- mark dirty / sync
  self:syncContracts()
end

local function toOrdinal(period, day, daysPerPeriod)
  return (period - 1) * daysPerPeriod + (day - 1)
end

function CustomContractManager:getCurrentPeriodDay()
  local env = g_currentMission.environment
  local period = (env and env.currentPeriod) or 1
  local dpp = (env and env.daysPerPeriod) or 1

  -- Try common names; fallback to 1
  local day = (env and (env.currentDayInPeriod or env.currentPeriodDay)) or 1
  day = math.max(1, math.min(day, dpp))

  return period, day, dpp
end

function CustomContractManager:isPastDue(contract, curPeriod, curDay, dpp)
  if contract.duePeriod == nil or contract.duePeriod == -1 then return false end
  if contract.dueDay == nil or contract.dueDay == -1 then return false end

  local curOrd = toOrdinal(curPeriod, curDay, dpp)
  local dueOrd = toOrdinal(contract.duePeriod, contract.dueDay, dpp)

  local yearLen = 12 * dpp
  if (contract.dueYearOffset or 0) > 0 then
    dueOrd = dueOrd + yearLen
    if curPeriod <= contract.duePeriod then
      curOrd = curOrd + yearLen
    end
  end

  return curOrd > dueOrd
end

function CustomContractManager:updateExpiredContracts()
  if not g_currentMission:getIsServer() then return end

  local curPeriod, curDay, daysPerPeriod = CustomUtils.getCurrentPeriodDay()
  local changed = false

  for _, contract in pairs(self.contracts) do
    -- Only check contracts that can expire
    if contract.status == CustomContract.STATUS.OPEN
        or contract.status == CustomContract.STATUS.ACCEPTED then
      if CustomUtils.isPastDue(contract, curPeriod, curDay, daysPerPeriod) then
        contract.status = CustomContract.STATUS.EXPIRED
        changed = true
      end
    end
  end

  -- Only sync if something actually changed
  if changed then
    self:syncContracts()
    g_messageCenter:publish(MessageType.CUSTOM_CONTRACTS_UPDATED)
  end

  return changed
end
