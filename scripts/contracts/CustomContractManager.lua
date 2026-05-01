--
-- FS25 Contract and Invoices
--
-- @Author: Racc00n
-- @Version: 1.0.0.0
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
    setXMLString(xmlFile, key .. "#templateId", contract.templateId or CustomContract.TEMPLATE.FIELD_WORK)
    setXMLInt(xmlFile, key .. "#fillTypeIndex", contract.fillTypeIndex or -1)
    setXMLInt(xmlFile, key .. "#transportAmount", contract.transportAmount or -1)
    setXMLInt(xmlFile, key .. "#destinationId", contract.destinationId or -1)
    if contract.destinationX then setXMLFloat(xmlFile, key .. "#destinationX", contract.destinationX) end
    if contract.destinationZ then setXMLFloat(xmlFile, key .. "#destinationZ", contract.destinationZ) end
    setXMLFloat(xmlFile, key .. "#transportSoldPrice", contract.transportSoldPrice or 0)

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
    local templateId          = getXMLString(xmlFile, contractKey .. "#templateId")
    local fillTypeIndex       = getXMLInt(xmlFile, contractKey .. "#fillTypeIndex")
    local transportAmount     = getXMLInt(xmlFile, contractKey .. "#transportAmount")
    local destinationId       = getXMLInt(xmlFile, contractKey .. "#destinationId")
    local destinationX        = getXMLFloat(xmlFile, contractKey .. "#destinationX")
    local destinationZ        = getXMLFloat(xmlFile, contractKey .. "#destinationZ")
    local transportSoldPrice  = getXMLFloat(xmlFile, contractKey .. "#transportSoldPrice")

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
    contract.destinationId = destinationId
    if destinationX then contract.destinationX = destinationX end
    if destinationZ then contract.destinationZ = destinationZ end
    contract.transportSoldPrice = transportSoldPrice or 0

    self.contracts[id] = contract
    self.nextId        = math.max(self.nextId, id + 1)

    i                  = i + 1
  end

  self:_syncFarmAccess()
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

  self:_syncFarmAccess()
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
    if (contract.creatorFarmId == farmId or contract.contractorFarmId == farmId) and (contract.status == CustomContract.STATUS.COMPLETED or contract.status == CustomContract.STATUS.INVOICED or contract.status == CustomContract.STATUS.COMPLETED_AWAITING_INVOICE) then
      table.insert(completedForFarm, contract)
    end
  end

  return completedForFarm
end

-- Called by CreateContractEvent, runs on server
function CustomContractManager:handleCreateRequest(farmId, payload)
  if not g_currentMission:getIsServer() then return end

  local id                = self.nextId
  self.nextId             = self.nextId + 1

  local templateId        = payload.templateId or CustomContract.TEMPLATE.FIELD_WORK
  local farmlandId        = payload.farmlandId or -1
  local workAreaTypeIndex = payload.workAreaTypeIndex or 0
  if templateId == CustomContract.TEMPLATE.TRANSPORT then
    farmlandId = -1
    workAreaTypeIndex = 0
  end

  local contract = CustomContract.new(
    id,
    farmId,
    farmlandId,
    workAreaTypeIndex,
    payload.reward,
    payload.description,
    payload.startPeriod,
    payload.startDay,
    payload.duePeriod,
    payload.dueDay,
    payload.invoiceId or -1,
    templateId
  )

  if templateId == CustomContract.TEMPLATE.TRANSPORT then
    contract.fillTypeIndex   = payload.fillTypeIndex
    contract.transportAmount = payload.transportAmount
    contract.destinationId   = payload.destinationId or -1
    contract.transportSoldPrice = 0
    if payload.destinationX then contract.destinationX = payload.destinationX end
    if payload.destinationZ then contract.destinationZ = payload.destinationZ end
  end

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
  if contract.templateId == CustomContract.TEMPLATE.TRANSPORT then
    contract.transportSoldPrice = 0
  end

  -- Notify the creator of the contract
  local contractorFarm = g_farmManager:getFarmById(contract.creatorFarmId)
  local farmName = contractorFarm.name or "Unknown"

  g_currentMission.CustomContracts.NotificationManager:addNotification(
    string.format(g_i18n:getText("cc_contract_accepted_notification"), contract.id, farmName),
    Notification.TYPE.INFO,
    contract.creatorFarmId)

  -- Notify the contractor of the contract
  g_currentMission.CustomContracts.NotificationManager:addNotification(
    string.format(g_i18n:getText("cc_contract_accepted_notification"), contract.id, "You"), Notification.TYPE.INFO,
    contract.contractorFarmId)

  self:_syncFarmAccess()
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

  local lineTitle
  if contract.templateId == CustomContract.TEMPLATE.TRANSPORT then
    lineTitle = string.format(
      g_i18n:getText("cc_dialog_invoice_create_auto_line_title_transport") or "Transport contract #%d", contract.id)
  else
    lineTitle = string.format(g_i18n:getText("cc_dialog_invoice_create_auto_line_title"), contract.id)
  end
  local draft = {
    receiverFarmId = contract.creatorFarmId,
    title = string.format(g_i18n:getText("cc_contract_id_label"), contract.id),
    description = contract.description or "",
    lines = {},
    total = 0,
    dueAt = contract.duePeriod,
    relatedContractId = contract.id,
    autoGenerated = true
  }

  table.insert(draft.lines, { title = lineTitle, amount = contract.reward })

  if contract.templateId == CustomContract.TEMPLATE.TRANSPORT then
    local soldPrice = contract.transportSoldPrice or 0
    table.insert(draft.lines, {
      title = g_i18n:getText("cc_dialog_invoice_create_transport_sold_line_title") or "Sold produce value",
      amount = -soldPrice
    })
  end

  local total = 0
  for _, line in ipairs(draft.lines) do
    total = total + (tonumber(line.amount) or 0)
  end
  draft.total = total

  self:_syncFarmAccess()
  self:syncContracts()

  -- Notify the creator of the contract
  local contractorFarm = g_farmManager:getFarmById(contract.creatorFarmId)
  local farmName = contractorFarm.name or "Unknown"
  g_currentMission.CustomContracts.NotificationManager:addNotification(
    string.format(g_i18n:getText("cc_contract_completed_notification"), contract.id, farmName), Notification.TYPE.INFO,
    contract.creatorFarmId)

  -- Notify the contractor of the contract
  g_currentMission.CustomContracts.NotificationManager:addNotification(
    string.format(g_i18n:getText("cc_contract_completed_notification"), contract.id, "You"), Notification.TYPE.INFO,
    contract.contractorFarmId)

  -- CreateInvoiceDialog.show(draft)

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
  self:_syncFarmAccess()
  self:syncContracts()

  -- Notify the creator of the contract
  g_currentMission.CustomContracts.NotificationManager:addNotification(
    string.format(g_i18n:getText("cc_contract_cancelled_notification"), contract.id, "You"), Notification.TYPE.INFO,
    contract.creatorFarmId)

  -- Notify the contractor of the contract
  local creatorFarm = g_farmManager:getFarmById(contract.creatorFarmId)
  local farmName = creatorFarm.name or "Unknown"
  g_currentMission.CustomContracts.NotificationManager:addNotification(
    string.format(g_i18n:getText("cc_contract_cancelled_notification"), contract.id, farmName),
    Notification.TYPE.INFO,
    contract.contractorFarmId)
end

-- Function to deleteContract, called by DeleteContractEvent
function CustomContractManager:handleDeleteRequest(farmId, contractId)
  if not g_currentMission:getIsServer() then return end

  local contract = self.contracts[contractId]
  if contract == nil then return end
  if contract.creatorFarmId ~= farmId then return end

  self.contracts[contractId] = nil

  -- Notify the creator of the contract
  g_currentMission.CustomContracts.NotificationManager:addNotification(
    string.format(g_i18n:getText("cc_contract_deleted_notification"), contract.id, "You"), Notification.TYPE.INFO,
    contract.creatorFarmId)

  -- Notify the contractor of the contract
  local creatorFarm = g_farmManager:getFarmById(contract.creatorFarmId)
  local farmName = creatorFarm.name or "Unknown"
  g_currentMission.CustomContracts.NotificationManager:addNotification(
    string.format(g_i18n:getText("cc_contract_deleted_notification"), contract.id, farmName),
    Notification.TYPE.INFO,
    contract.contractorFarmId)

  self:_syncFarmAccess()
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
  self.contracts[contractId].transportSoldPrice = 0


  self:_syncFarmAccess()
  self:syncContracts()
end

function CustomContractManager:handleEditRequest(farmId, contractId, data)
  if not g_currentMission:getIsServer() then return end

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

  if contract.templateId == CustomContract.TEMPLATE.FIELD_WORK then
    contract.farmlandId        = data.farmlandId
    contract.workAreaTypeIndex = data.workAreaTypeIndex
  elseif contract.templateId == CustomContract.TEMPLATE.TRANSPORT then
    if data.fillTypeIndex ~= nil and data.fillTypeIndex >= 0 then
      contract.fillTypeIndex = data.fillTypeIndex
    end
    if data.transportAmount ~= nil and data.transportAmount > 0 then
      contract.transportAmount = data.transportAmount
    end
    if data.destinationId ~= nil then
      contract.destinationId = data.destinationId
    end
    if data.destinationX ~= nil then
      contract.destinationX = data.destinationX
    end
    if data.destinationZ ~= nil then
      contract.destinationZ = data.destinationZ
    end
  end

  contract.reward      = data.reward
  contract.description = data.description
  contract.startPeriod = data.startPeriod
  contract.startDay    = data.startDay
  contract.duePeriod   = data.duePeriod
  contract.dueDay      = data.dueDay

  self:syncContracts()
end

function CustomContractManager:_syncFarmAccess()
  local farmAccessManager = g_currentMission.CustomContracts.FarmAccessManager
  if farmAccessManager == nil then
    return
  end

  farmAccessManager:rebuildFromContracts(self.contracts)
  farmAccessManager:syncAccess()
end

function CustomContractManager:hasWorkAreaAccessByContract(farmId, landOwnerFarmId, x, z, workAreaType, workArea)
  local farmAccessManager = g_currentMission.CustomContracts.FarmAccessManager
  if farmAccessManager == nil then
    return false
  end

  return farmAccessManager:getFarmAccessFieldWorkByFarmId(farmId, landOwnerFarmId, x, z, workAreaType, workArea)
end

function CustomContractManager:hasAcceptedContractWithOwner(contractorFarmId, ownerFarmId)
  local farmAccessManager = g_currentMission.CustomContracts.FarmAccessManager
  if farmAccessManager == nil then
    return false
  end

  return farmAccessManager:hasAcceptedContractWithOwner(contractorFarmId, ownerFarmId)
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

function CustomContractManager:getActiveTransportContractForSale(contractorFarmId, fillTypeIndex)
  if contractorFarmId == nil or fillTypeIndex == nil then
    return nil
  end

  local match = nil
  for _, contract in pairs(self.contracts) do
    if contract.templateId == CustomContract.TEMPLATE.TRANSPORT
        and contract.status == CustomContract.STATUS.ACCEPTED
        and contract.contractorFarmId == contractorFarmId
        and contract.fillTypeIndex == fillTypeIndex then
      if match == nil or contract.id < match.id then
        match = contract
      end
    end
  end

  return match
end

function CustomContractManager:registerTransportSale(contractorFarmId, fillTypeIndex, soldPrice)
  if not g_currentMission:getIsServer() then
    return
  end
  if soldPrice == nil or soldPrice <= 0 then
    return
  end

  local contract = self:getActiveTransportContractForSale(contractorFarmId, fillTypeIndex)
  if contract == nil then
    return
  end

  contract.transportSoldPrice = (contract.transportSoldPrice or 0) + soldPrice
  self:syncContracts()
end
