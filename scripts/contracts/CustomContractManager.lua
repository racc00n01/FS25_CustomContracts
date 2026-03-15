--
-- FS25 Contract and Invoices
--
-- @Author: Racc00n
-- @Version: 1.0.0.0
--

CustomContractManager                   = {}
CustomContractManager_mt                = Class(CustomContractManager)
CustomContractManager.dir               = g_currentModDirectory
CustomContractManager.modName           = g_currentModName

-- Default partition size for density-map progress (m² per partition).
CustomContractManager.SQM_PER_PARTITION = 2500

function CustomContractManager:new()
  local self = {}
  setmetatable(self, CustomContractManager_mt)
  self.contracts = {}
  self.accessByFarmland = {}
  self.nextId = 1
  self.completionCache = {}
  self.progressBars = {}

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
    setXMLFloat(xmlFile, key .. "#completionProgress", contract.completionProgress or 0)

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
    local completionProgress  = getXMLFloat(xmlFile, contractKey .. "#completionProgress")

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
    if completionProgress and completionProgress >= 0 then contract.completionProgress = completionProgress end

    self.contracts[id] = contract
    self.nextId        = math.max(self.nextId, id + 1)

    i                  = i + 1
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

  local farmId = g_currentMission:getFarmId()
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

  local farmId = g_currentMission:getFarmId()
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

  local farmId = g_currentMission:getFarmId()
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

  local farmId = g_currentMission:getFarmId()
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
    lines = {
      { title = lineTitle, amount = contract.reward }
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

  -- apply edits (only field-work fields for FIELD_WORK; transport keeps its own fields)
  if contract.templateId == CustomContract.TEMPLATE.FIELD_WORK then
    contract.farmlandId        = data.farmlandId
    contract.workAreaTypeIndex = data.workAreaTypeIndex
  end
  contract.reward      = data.reward
  contract.description = data.description
  contract.startPeriod = data.startPeriod
  contract.startDay    = data.startDay
  contract.duePeriod   = data.duePeriod
  contract.dueDay      = data.dueDay

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

--- Updates HUD side notification progress bars for the local player's accepted contracts (client-only).
--- Creates a bar when a contract is accepted, updates progress from contract.completionProgress, removes bar when done/cancelled.
function CustomContractManager:updateProgressBars()
  if not g_currentMission or not g_currentMission.hud or not g_localPlayer then
    return
  end

  local farmId = g_localPlayer.farmId
  if not farmId or farmId == FarmManager.SPECTATOR_FARM_ID then
    return
  end

  local hud = g_currentMission.hud
  local title = g_i18n:getText("contract_title") or "Contract"

  for id, contract in pairs(self.contracts) do
    if contract.status == CustomContract.STATUS.ACCEPTED and contract.contractorFarmId == farmId then
      local bar = self.progressBars[id]

      if bar == nil then
        bar = hud:addSideNotificationProgressBar(title,
          string.format(g_i18n:getText("cc_contract_notification_label"), contract:getWorkTypeAreaName(),
            contract.farmlandId),
          (contract.completionProgress or 0) / 100)
        if bar then
          self.progressBars[id] = bar
        end
      end

      if bar then
        bar.progress = (contract.completionProgress or 0) / 100
        hud:markSideNotificationProgressBarForDrawing(bar)
      end
    else
      local bar = self.progressBars[id]
      if bar then
        pcall(function()
          hud:removeSideNotificationProgressBar(bar)
        end)
        self.progressBars[id] = nil
      end
    end
  end
end

--- Creates density-map modifier and filter for contract progress (base-game mission style).
--- @param contract CustomContract
--- @param field table Field instance (from g_fieldManager:getFieldById(farmlandId))
--- @return DensityMapModifier|nil modifier
--- @return DensityMapFilter|nil filter
function CustomContractManager:createCompletionModifierForContract(contract, field)
  if not g_currentMission or not g_currentMission.fieldGroundSystem or not field then
    return nil, nil
  end
  local mission = g_currentMission
  local workType = contract.workAreaTypeIndex or 0
  local ok, modifier, filter = pcall(function()
    if workType == 1 then
      -- Cultivate: ground type between STUBBLE_TILLAGE and SEEDBED (same as CultivateMission)
      local mapId, firstChannel, numChannels = mission.fieldGroundSystem:getDensityMapData(FieldDensityMap.GROUND_TYPE)
      if not mapId then return nil, nil end
      modifier = DensityMapModifier.new(mapId, firstChannel, numChannels, g_terrainNode)
      filter = DensityMapFilter.new(modifier)
      local stubble = FieldGroundType.getValueByType(FieldGroundType.STUBBLE_TILLAGE)
      local seedbed = FieldGroundType.getValueByType(FieldGroundType.SEEDBED)
      filter:setValueCompareParams(DensityValueCompareType.BETWEEN, stubble, seedbed)
      return modifier, filter
    elseif workType == 2 then
      -- Plow: plow level >= 1
      local mapId, firstChannel, numChannels = mission.fieldGroundSystem:getDensityMapData(FieldDensityMap.PLOW_LEVEL)
      if not mapId then return nil, nil end
      modifier = DensityMapModifier.new(mapId, firstChannel, numChannels, g_terrainNode)
      filter = DensityMapFilter.new(modifier)
      filter:setValueCompareParams(DensityValueCompareType.GREATER, 0)
      return modifier, filter
    end
    return nil, nil
  end)
  if ok and modifier and filter then
    return modifier, filter
  end
  return nil, nil
end

--- Initializes partition list for field.
--- @param cache table cache entry (manager-owned, keyed by contract id)
--- @param field table Field with getDensityMapPolygon, getAreaHa
--- @param modifier DensityMapModifier
function CustomContractManager:initializeCompletionPartitions(cache, field, modifier)
  if not modifier or not field.getDensityMapPolygon or not field.getAreaHa then
    return
  end
  local polygon = field:getDensityMapPolygon()
  if not polygon or not polygon.applyToModifier then
    return
  end
  polygon:applyToModifier(modifier)
  local partitions = {}
  local minZ, maxZ = modifier:getPolygonMinMaxZ()
  if minZ ~= nil and maxZ ~= nil then
    local sizeSqm = MathUtil.haToSqm(field:getAreaHa())
    local numPartitions = math.max(1, math.ceil(sizeSqm / self.SQM_PER_PARTITION))
    local regionPerPartition = (maxZ - minZ) / numPartitions
    local currentMinZ = minZ
    for i = 1, numPartitions do
      local currentMaxZ = math.min(currentMinZ + regionPerPartition, maxZ)
      partitions[i] = { minZ = currentMinZ, maxZ = currentMaxZ, wasCalculated = false, sumPixels = 0, area = 0, totalArea = 0 }
      currentMinZ = currentMaxZ
    end
  else
    partitions[1] = { wasCalculated = false, sumPixels = 0, area = 0, totalArea = 0 }
  end
  cache.partitions = partitions
  cache.partitionIndex = 1
end

--- Gets field completion (0..1) using density maps, one partition per call. State is cached on the manager (keyed by contract id).
--- Returns nil if density-map path not available; then caller uses evaluateFieldWorkCompletion. Only contract.completionProgress is written by caller.
--- @param contract CustomContract
--- @return number|nil completion 0..1 or nil
function CustomContractManager:getFieldCompletionDensityMap(contract)
  if not g_currentMission or not g_fieldManager then
    return nil
  end

  local workType = contract.workAreaTypeIndex or 0
  if workType ~= 1 and workType ~= 2 then
    return nil
  end

  local field = g_fieldManager:getFieldById(contract.farmlandId)
  if not field then
    return nil
  end

  local cache = self.completionCache[contract.id]
  if not cache then
    cache = {}
    self.completionCache[contract.id] = cache
  end

  local modifier = cache.modifier
  local filter = cache.filter
  if not modifier or not filter then
    modifier, filter = self:createCompletionModifierForContract(contract, field)
    if not modifier or not filter then
      return nil
    end
    cache.modifier = modifier
    cache.filter = filter
    self:initializeCompletionPartitions(cache, field, modifier)
  end

  local partitions = cache.partitions
  if not partitions or #partitions == 0 then
    return nil
  end

  local idx = cache.partitionIndex or 1
  local partition = partitions[idx]
  if not partition then
    return nil
  end

  if partition.minZ ~= nil and partition.maxZ ~= nil and modifier.setPolygonClipRegion then
    modifier:setPolygonClipRegion(partition.minZ, partition.maxZ)
  end

  local sumPixels, area, totalArea = 0, 0, 0
  local ok, a, b, c = pcall(function()
    return modifier:executeGet(filter)
  end)

  if ok and a ~= nil then
    sumPixels = type(a) == "number" and a or 0
    if b ~= nil and type(b) == "number" then area = b end
    if c ~= nil and type(c) == "number" then totalArea = c end
    if totalArea == 0 and sumPixels then
      area = sumPixels
      totalArea = sumPixels
    end
  end

  partition.wasCalculated = true
  partition.area = area
  partition.totalArea = totalArea
  cache.partitionIndex = idx + 1

  if cache.partitionIndex > #partitions then
    cache.partitionIndex = 1
  end

  local areaDone = 0
  local areaTotal = 0
  for _, p in ipairs(partitions) do
    areaDone = areaDone + (p.area or 0)
    areaTotal = areaTotal + (p.totalArea or 0)
  end

  if areaTotal > 0 then
    cache.fieldPercentageDone = areaDone / areaTotal
  else
    cache.fieldPercentageDone = cache.fieldPercentageDone or 0
  end

  return cache.fieldPercentageDone
end

--- Evaluates field work completion from collected field data.
--- @param contract CustomContract
--- @param fieldData table[] array of field data from contractProgressFieldCollector
--- @return number completion 0-100
function CustomContractManager:evaluateFieldWorkCompletion(contract, fieldData)
  if not contract or not fieldData or #fieldData == 0 then
    return 0
  end

  local workType = contract.workAreaTypeIndex or 0
  local totalHectares = 0
  local doneHectares = 0
  local doneCount = 0

  for _, fData in ipairs(fieldData) do
    local ha = (fData.hectares or 0) + 0
    totalHectares = totalHectares + ha

    local done = false

    if workType == 1 then
      -- Cultivate: cultivated state (ground type sown or similar)
      local gType = fData.groundType or 0
      done = (gType == 2 or gType == 3 or gType == 4)
    elseif workType == 2 then
      -- Plow
      done = (fData.plowLevel or 0) >= 1
    elseif workType == 3 then
      -- Seed: crop present and growing
      done = (fData.fruitTypeIndex or 0) > 0 and (fData.growthState or 0) >= 1
    elseif workType == 4 then
      -- Fertilize
      done = (fData.fertilizationLevel or 0) >= 2
    elseif workType == 5 then
      -- Harvest: crop was harvest-ready and then removed (harvested); approximate by harvestReady or growth state reset
      done = (fData.harvestReady and (fData.growthState or 0) >= (fData.maxGrowthState or 1)) or
          ((fData.growthState or 0) == 0 and (fData.fruitTypeIndex or 0) > 0 and (fData.maxGrowthState or 0) > 0)
    elseif workType == 6 then
      -- Roll: no direct map; treat as done if field has crop (rolled before seed)
      done = (fData.fruitTypeIndex or 0) > 0
    elseif workType == 7 then
      -- Weed: low weed level
      done = (fData.weedLevel or 1) < 0.15
    elseif workType == 8 then
      -- Lime
      done = (fData.limeLevel or 0) >= 1
    elseif workType == 9 then
      -- Mulch: no simple map; use cultivation as proxy
      done = (fData.fruitTypeIndex or 0) > 0 and (fData.growthState or 0) >= 1
    elseif workType == 10 then
      -- Stone Pick: no simple field-state map; cannot auto-evaluate
      done = false
    elseif workType == 11 then
      -- Remove Foliage: no simple field-state map; cannot auto-evaluate
      done = false
    elseif workType == 12 then
      -- Mowing: grass in cut state (ground type GRASS_CUT)
      local gType = fData.groundType or 0
      local grassCutValue = FieldGroundType and FieldGroundType.GRASS_CUT or 16
      done = (gType == grassCutValue)
    elseif workType == 13 then
      -- Tedding: no simple field-state map (windrow state not in our field data); cannot auto-evaluate
      done = false
    elseif workType == 14 then
      -- Windrowing: no simple field-state map; cannot auto-evaluate
      done = false
    elseif workType == 15 then
      -- Baling: no simple field-state map; cannot auto-evaluate
      done = false
    elseif workType == 16 then
      -- Bale Wrapping: no simple field-state map; cannot auto-evaluate
      done = false
    elseif workType == 17 then
      -- Spraying: could be herbicide or fertilizer; cannot distinguish, so no auto-evaluate
      done = false
    else
      -- Other / unknown: cannot auto-evaluate
      done = false
    end

    if done then
      doneCount = doneCount + 1
      if ha > 0 then
        doneHectares = doneHectares + ha
      end
    end
  end

  local n = #fieldData
  if n == 0 then
    return 0
  end

  if totalHectares > 0 then
    return math.min(100, math.floor((doneHectares / totalHectares) * 100))
  end

  return math.min(100, math.floor((doneCount / n) * 100))
end

function CustomContractManager:contractProgressFieldCollector(contractId)
  if not g_currentMission:getIsServer() then return end

  local fieldData = {}
  if not g_currentMission then return fieldData end

  local isPF = false
  local pfEnv = g_currentMission.FS25_precisionFarming
  local pfInstance = nil

  if pfEnv and pfEnv.g_precisionFarming then
    isPF = true
    pfInstance = pfEnv.g_precisionFarming
  elseif g_currentMission.g_precisionFarming then
    isPF = true
    pfInstance = g_currentMission.g_precisionFarming
  end


  local contract = self:getContractById(contractId)
  if contract == nil then return fieldData end

  if contract.templateId == CustomContract.TEMPLATE.FIELD_WORK then
    local fields = g_fieldManager.getFields and g_fieldManager:getFields() or g_fieldManager.fields or {}
    for index, field in pairs(fields) do
      if not field or not field.farmland then
        break
      end
      local farmlandId = field.farmland.id
      if farmlandId == contract.farmlandId then
        local fieldId = field.id or field.fieldId or index
        if fieldId == nil then
          fieldId = 0
        end

        local fData = {
          id = fieldId,
          name = string.format("Field %d", tonumber(fieldId) or 0),
          hectares = field.areaHa or 0,
          fieldAreaInSqm = (field.areaHa or 0) * 10000,
          isOwned = true,
          ownerFarmId = field.farmland.ownerFarmId,
          farmlandId = farmlandId,
          posX = field.posX or 0,
          posZ = field.posZ or 0,
          fruitType = "unknown",
          fruitTypeIndex = 0,
          growthState = 0,
          maxGrowthState = 0,
          growthStatePercentage = 0,
          harvestReady = false,
          fertilizationLevel = field.fieldState and field.fieldState.fertilizationLevel or 0,
          limeLevel = field.fieldState and field.fieldState.limeLevel or 0,
          plowLevel = field.fieldState and field.fieldState.plowLevel or 0,
          weedLevel = field.fieldState and field.fieldState.weedLevel or 0,
          groundType = field.fieldState and field.fieldState.groundType or 0,
          isPrecisionFarming = isPF,
          nitrogenLevel = 0,
          targetNitrogen = 0,
          phValue = 0,
          targetPh = 0,
          isScanned = false,
          nitrogenText = "",
          limeText = "",
          suggestions = {}
        }

        local bestIndex = 0
        local gState = 0
        local bestState = 0
        local maxArea = 0

        if FSDensityMapUtil and FSDensityMapUtil.getFruitArea and g_fruitTypeManager and g_fruitTypeManager.fruitTypes then
          -- Create a 10x10 meter measuring box around the center coordinate
          local sX = fData.posX
          local sZ = fData.posZ
          local startX = sX - 5
          local startZ = sZ - 5
          local widthX = sX + 5
          local widthZ = sZ - 5
          local heightX = sX - 5
          local heightZ = sZ + 5

          for _, fruitType in pairs(g_fruitTypeManager.fruitTypes) do
            if fruitType.index and fruitType.index ~= 0 then
              local ok, area = pcall(FSDensityMapUtil.getFruitArea, fruitType.index, startX, startZ,
                widthX, widthZ,
                heightX, heightZ, true, true)
              local stateAreaMax = 0
              gState = 0
              -- Expanded to 15 to catch fully grown / withered states
              for state = 1, 15 do
                local okState, sArea = pcall(FSDensityMapUtil.getFruitAreaByState, fruitType.index,
                  startX, startZ,
                  widthX, widthZ, heightX, heightZ, state, state)
                if okState and type(sArea) == "number" and sArea > stateAreaMax then
                  stateAreaMax = sArea
                  gState = state
                end
              end
              if ok and type(area) == "number" and area > maxArea then
                maxArea = area
                bestIndex = fruitType.index
                bestState = gState
              end
            end
          end

          if bestIndex > 0 then
            fData.fruitTypeIndex = bestIndex

            if bestState > 0 then
              fData.growthState = bestState
            else
              fData.growthState = (field.fieldState and field.fieldState.growthState) or 0
            end
          else
            if field.fieldState then
              fData.fruitTypeIndex = field.fieldState.fruitTypeIndex or field.fieldState.currentFruitTypeIndex or 0
              fData.growthState = field.fieldState.growthState or 0
            end
          end

          if fData.fruitTypeIndex == 0 and field.plannedFruitTypeIndex and field.plannedFruitTypeIndex > 0 then
            fData.fruitTypeIndex = field.plannedFruitTypeIndex
          end

          local gType = field.fieldState and field.fieldState.groundType or 0
          if gType == 3 or gType == 4 then
            if fData.growthState == 0 or fData.growthState > 4 then fData.growthState = 1 end
            fData.harvestReady = false
            fData.needsPlowing = false
          elseif gType == 1 or gType == 2 then
            fData.growthState = 0
            fData.harvestReady = false
            fData.needsPlowing = false
          end

          if fData.fruitTypeIndex > 0 and g_fruitTypeManager then
            local fruitType = g_fruitTypeManager:getFruitTypeByIndex(fData.fruitTypeIndex)
            if fruitType then
              fData.fruitType = fruitType.name or "unknown"
              fData.maxGrowthState = fruitType.maxGrowthState or 0
            end

            if fData.maxGrowthState > 0 then
              fData.growthStatePercentage = math.floor((fData.growthState / fData.maxGrowthState) * 100)
              fData.harvestReady = fData.growthState >= fData.maxGrowthState
            end
          end

          table.sort(fData.suggestions, function(a, b) return (a.priority or 0) < (b.priority or 0) end)
        end
        table.insert(fieldData, fData)
      end
    end

    table.sort(fieldData, function(a, b) return (a.id or 0) < (b.id or 0) end)
    -- Prefer density-map progress (base-game style) for cultivate/plow; fall back to field-state evaluation
    local completionPct = nil
    local densityMapCompletion = self:getFieldCompletionDensityMap(contract)
    if densityMapCompletion ~= nil then
      completionPct = math.min(100, math.floor(densityMapCompletion * 100))
    end

    if completionPct == nil then
      completionPct = self:evaluateFieldWorkCompletion(contract, fieldData)
    end

    contract.completionProgress = completionPct

    if contract.status == CustomContract.STATUS.ACCEPTED and completionPct >= 100 then
      contract.status = CustomContract.STATUS.COMPLETED
      self.completionCache[contract.id] = nil
      g_messageCenter:publish(MessageType.CUSTOM_CONTRACTS_UPDATED)
    end
  end
end
