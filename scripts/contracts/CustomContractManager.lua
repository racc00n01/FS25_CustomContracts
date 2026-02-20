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
  self.accessByFarmland = {}
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
    setXMLInt(xmlFile, key .. "#farmlandId", contract.farmlandId)
    setXMLInt(xmlFile, key .. "#workAreaTypeIndex", contract.workAreaTypeIndex)
    setXMLInt(xmlFile, key .. "#reward", contract.reward)
    setXMLString(xmlFile, key .. "#status", contract.status)
    setXMLString(xmlFile, key .. "#description", contract.description or '-')
    setXMLInt(xmlFile, key .. "#startPeriod", contract.startPeriod or -1)
    setXMLInt(xmlFile, key .. "#startDay", contract.startDay or -1)
    setXMLInt(xmlFile, key .. "#duePeriod", contract.duePeriod or -1)
    setXMLInt(xmlFile, key .. "#dueDay", contract.dueDay or -1)
    setXMLInt(xmlFile, key .. "#invoiceId", contract.invoiceId or -1)

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

    local id                  = getXMLInt(xmlFile, contractKey .. "#id")
    local creatorFarmId       = getXMLInt(xmlFile, contractKey .. "#creatorFarmId")
    local contractorFarmId    = getXMLInt(xmlFile, contractKey .. "#contractorFarmId")
    local farmlandId          = getXMLInt(xmlFile, contractKey .. "#farmlandId")
    local workAreaTypeIndex   = getXMLInt(xmlFile, contractKey .. "#workAreaTypeIndex")
    local reward              = getXMLInt(xmlFile, contractKey .. "#reward")
    local status              = getXMLString(xmlFile, contractKey .. "#status")
    local description         = getXMLString(xmlFile, contractKey .. "#description")
    local startPeriod         = getXMLInt(xmlFile, contractKey .. "#startPeriod")
    local startDay            = getXMLInt(xmlFile, contractKey .. "#startDay")
    local duePeriod           = getXMLInt(xmlFile, contractKey .. "#duePeriod")
    local dueDay              = getXMLInt(xmlFile, contractKey .. "#dueDay")
    local invoiceId           = getXMLInt(xmlFile, contractKey .. "#invoiceId")

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
      invoiceId
    )

    contract.contractorFarmId = contractorFarmId ~= -1 and contractorFarmId or nil
    contract.status           = status

    self.contracts[id]        = contract
    self.nextId               = math.max(self.nextId, id + 1)

    i                         = i + 1
  end

  self:_rebuildAccessCache()
  self:syncContracts()
end

function CustomContractManager:writeInitialClientState(streamId, connection)
  streamWriteInt32(streamId, self.nextId)

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

  self:_rebuildAccessCache()
  -- notify UI
  g_messageCenter:publish(MessageType.CUSTOM_CONTRACTS_UPDATED)
end

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

function CustomContractManager:getCompletedContractsForCurrentFarm()
  local completedForFarm = {}

  local farmId = g_currentMission:getFarmId();
  if farmId == nil or farmId == 0 then
    return completedForFarm
  end

  local contractManager = g_currentMission.CustomContracts.ContractManager

  for _, contract in pairs(contractManager.contracts) do
    -- Contracts completed
    if contract.creatorFarmId == farmId and (contract.status == CustomContract.STATUS.COMPLETED or contract.status == CustomContract.STATUS.INVOICED or contract.status == CustomContract.STATUS.COMPLETED_AWAITING_INVOICE) then
      table.insert(completedForFarm, contract)
    end
  end

  return completedForFarm
end

-- Called by CreateContractEvent, runs on server
function CustomContractManager:handleCreateRequest(farmId, payload)
  if not g_currentMission:getIsServer() then return end

  local id           = self.nextId
  self.nextId        = self.nextId + 1

  local contract     = CustomContract.new(
    id,
    farmId,
    payload.farmlandId,
    payload.workAreaTypeIndex,
    payload.reward,
    payload.description,
    payload.startPeriod,
    payload.startDay,
    payload.duePeriod,
    payload.dueDay,
    payload.invoiceId
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

  self:_rebuildAccessCache()
  self:syncContracts()
end

-- Function to completeContract, called by CompleteContractEvent
function CustomContractManager:handleCompleteRequest(farmId, contractId, connection)
  if not g_currentMission:getIsServer() then return end

  local contract = self.contracts[contractId]
  if contract == nil then return end
  if contract.status ~= CustomContract.STATUS.ACCEPTED then return end
  if contract.contractorFarmId ~= farmId then return end

  contract.status = CustomContract.STATUS.COMPLETED_AWAITING_INVOICE

  local draft = {
    receiverFarmId = contract.creatorFarmId,
    title = string.format(g_i18n:getText("cc_contract_id_label"), contract.id),
    description = contract.description or "",
    lines = {
      { title = string.format(g_i18n:getText("cc_dialog_invoice_create_auto_line_title"), contract.id), amount = contract.reward }
    },
    total = contract.reward,
    dueAt = contract.duePeriod,
    relatedContractId = contract.id,
    autoGenerated = true
  }

  self:_rebuildAccessCache()
  self:syncContracts()

  if connection ~= nil then
    connection:sendEvent(OpenCreateInvoiceDialogEvent.new(draft))
  end
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
  self:_rebuildAccessCache()
  self:syncContracts()
end

-- Function to deleteContract, called by DeleteContractEvent
function CustomContractManager:handleDeleteRequest(farmId, contractId)
  if not g_currentMission:getIsServer() then return end

  local contract = self.contracts[contractId]
  if contract == nil then return end
  if contract.creatorFarmId ~= farmId then return end

  self.contracts[contractId] = nil

  self:_rebuildAccessCache()
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


  self:_rebuildAccessCache()
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
  if contract.status == CustomContract.STATUS.ACCEPTED or contract.status == CustomContract.STATUS.COMPLETED then
    return
  end

  -- apply edits
  contract.farmlandId        = data.farmlandId
  contract.workAreaTypeIndex = data.workAreaTypeIndex
  contract.reward            = data.reward
  contract.description       = data.description
  contract.startPeriod       = data.startPeriod
  contract.startDay          = data.startDay
  contract.duePeriod         = data.duePeriod
  contract.dueDay            = data.dueDay

  self:syncContracts()
end

function CustomContractManager:_rebuildAccessCache()
  self.accessByFarmland = {}

  for _, c in pairs(self.contracts) do
    if c.status == CustomContract.STATUS.ACCEPTED and c.contractorFarmId ~= nil then
      local farmlandId = c.farmlandId
      if farmlandId ~= nil then
        self.accessByFarmland[farmlandId] = self.accessByFarmland[farmlandId] or {}
        self.accessByFarmland[farmlandId][c.contractorFarmId] = true
      end
    end
  end
end

function CustomContractManager:hasWorkAreaAccessByContract(farmId, landOwnerFarmId, x, z, workAreaType, workArea)
  local farmlandIdAtPos = g_farmlandManager:getFarmlandIdAtWorldPosition(x, z)
  if farmlandIdAtPos == nil then
    return false
  end

  for _, c in pairs(self.contracts) do
    if c.status == CustomContract.STATUS.ACCEPTED
        and c.contractorFarmId == farmId
        and c.creatorFarmId == landOwnerFarmId
        and c.farmlandId ~= nil then
      if c.farmlandId == farmlandIdAtPos then
        -- optional: restrict by workAreaType / c.workType here later
        return true
      end
    end
  end

  return false
end

function CustomContractManager:hasAcceptedContractWithOwner(contractorFarmId, ownerFarmId)
  if contractorFarmId == nil or ownerFarmId == nil then return false end

  for _, c in pairs(self.contracts) do
    if c.status == CustomContract.STATUS.ACCEPTED
        and c.contractorFarmId == contractorFarmId
        and c.creatorFarmId == ownerFarmId then
      return true
    end
  end

  return false
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
    if contract.status == CustomContract.STATUS.OPEN
        or contract.status == CustomContract.STATUS.ACCEPTED then
      if contract.duePeriod == g_currentMission.CustomContracts.lastPeriod then
        if CustomUtils.isPastDue(contract, curPeriod, curDay, daysPerPeriod) then
          contract.status = CustomContract.STATUS.EXPIRED
          changed = true
        end
      end
    end
  end

  if changed then
    self:syncContracts()
    g_messageCenter:publish(MessageType.CUSTOM_CONTRACTS_UPDATED)
  end

  return changed
end

function CustomContractManager:sendOpenCreateInvoiceDialog(contractorFarmId, draft)
  if g_server == nil then return end

  for _, connection in pairs(g_server.clientConnections) do
    if connection ~= nil and connection.farmId == contractorFarmId then
      connection:sendEvent(OpenCreateInvoiceDialogEvent.new(draft))
      return
    end
  end
end

function CustomContractManager:getContractById(id)
  return self.contracts[id]
end
