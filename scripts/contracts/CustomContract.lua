--
-- FS25 Contract and Invoices
--
-- @Author: Racc00n
-- @Version: 1.0.0.0
--

CustomContract = {}
CustomContract.dir = g_currentModDirectory
CustomContract.modName = g_currentModName
CustomContract.__index = CustomContract
CustomContract_mt = Class(CustomContract)

CustomContract.WORKAREATYPES = {
  { index = 1,  name = "Cultivate" },
  { index = 2,  name = "Plow", },
  { index = 3,  name = "Seed" },
  { index = 4,  name = "Fertilize" },
  { index = 5,  name = "Harvest" },
  { index = 6,  name = "Roll" },
  { index = 7,  name = "Weed" },
  { index = 8,  name = "Lime" },
  { index = 9,  name = "Mulch" },
  { index = 10, name = "Stone Pick" },
  { index = 11, name = "Remove Foliage" },
  { index = 12, name = "Mowing" },
  { index = 13, name = "Tedding" },
  { index = 14, name = "Windrowing" },
  { index = 15, name = "Baling" },
  { index = 16, name = "Bale Wrapping" },
  { index = 17, name = "Spraying" },
  { index = 18, name = "Other" }
}

-- Contract creation template; determines which create flow/dialog is used.
CustomContract.TEMPLATE = {
  FIELD_WORK = "FIELD_WORK",
  TRANSPORT  = "TRANSPORT",
  FARM_JOB   = "FARM_JOB",
  CUSTOM     = "CUSTOM"
}

CustomContract.STATUS = {
  OPEN                       = "OPEN",
  ACCEPTED                   = "ACCEPTED",
  COMPLETED                  = "COMPLETED",
  CANCELLED                  = "CANCELLED",
  EXPIRED                    = "EXPIRED",
  COMPLETED_AWAITING_INVOICE = "COMPLETED_AWAITING_INVOICE",
  INVOICED                   = "INVOICED"
}

-- Initialize function when creating a new CustomContract.
function CustomContract.new(id, creatorFarmId, farmlandId, workAreaTypeIndex, reward, description, startPeriod, startDay,
                            duePeriod,
                            dueDay, invoiceId, templateId)
  local self              = setmetatable({}, CustomContract_mt)

  self.id                 = id
  self.creatorFarmId      = creatorFarmId
  self.contractorFarmId   = nil
  self.farmlandId         = farmlandId
  self.workAreaTypeIndex  = workAreaTypeIndex
  self.reward             = reward
  self.status             = CustomContract.STATUS.OPEN
  self.description        = description or ""
  self.startPeriod        = startPeriod or -1
  self.startDay           = startDay or -1
  self.duePeriod          = duePeriod or -1
  self.dueDay             = dueDay or -1
  self.invoiceId          = invoiceId or -1
  self.templateId         = templateId or CustomContract.TEMPLATE.FIELD_WORK

  -- Transport-specific (only used when templateId == TRANSPORT)
  self.fillTypeIndex      = nil
  self.transportAmount    = nil
  self.destinationId      = nil
  self.destinationX       = nil -- world X when destinationId == -1 (map position)
  self.destinationZ       = nil -- world Z when destinationId == -1 (map position)

  self.completionProgress = 0

  return self
end

function CustomContract:writeStream(streamId)
  streamWriteInt32(streamId, self.id)
  streamWriteInt32(streamId, self.creatorFarmId)
  streamWriteInt32(streamId, self.contractorFarmId or -1)
  streamWriteInt32(streamId, self.farmlandId)
  streamWriteInt32(streamId, self.workAreaTypeIndex)
  streamWriteInt32(streamId, self.reward)
  streamWriteString(streamId, self.status)
  streamWriteString(streamId, self.description)
  streamWriteInt32(streamId, self.startPeriod)
  streamWriteInt32(streamId, self.startDay)
  streamWriteInt32(streamId, self.duePeriod)
  streamWriteInt32(streamId, self.dueDay)
  streamWriteInt32(streamId, self.invoiceId)
  streamWriteString(streamId, self.templateId or CustomContract.TEMPLATE.FIELD_WORK)
  streamWriteInt32(streamId, self.fillTypeIndex or -1)
  streamWriteInt32(streamId, self.transportAmount or -1)
  streamWriteInt32(streamId, self.destinationId or -1)
  streamWriteFloat32(streamId, self.destinationX or 0)
  streamWriteFloat32(streamId, self.destinationZ or 0)
  streamWriteFloat32(streamId, self.completionProgress or 0)
end

function CustomContract.newFromStream(streamId)
  local id = streamReadInt32(streamId)
  local creatorFarmId = streamReadInt32(streamId)
  local contractorFarmId = streamReadInt32(streamId)
  local farmlandId = streamReadInt32(streamId)
  local workAreaTypeIndex = streamReadInt32(streamId)
  local reward = streamReadInt32(streamId)
  local status = streamReadString(streamId)
  local description = streamReadString(streamId)
  local startPeriod = streamReadInt32(streamId)
  local startDay = streamReadInt32(streamId)
  local duePeriod = streamReadInt32(streamId)
  local dueDay = streamReadInt32(streamId)
  local invoiceId = streamReadInt32(streamId)
  local templateId = streamReadString(streamId)
  local fillTypeIndex = streamReadInt32(streamId)
  local transportAmount = streamReadInt32(streamId)
  local destinationId = streamReadInt32(streamId)
  local destinationX = streamReadFloat32(streamId)
  local destinationZ = streamReadFloat32(streamId)
  local completionProgress = streamReadFloat32(streamId)

  local contract = CustomContract.new(
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
    templateId
  )

  contract.contractorFarmId = contractorFarmId ~= -1 and contractorFarmId or nil
  contract.status = status
  contract.completionProgress = completionProgress

  if fillTypeIndex and fillTypeIndex >= 0 then contract.fillTypeIndex = fillTypeIndex end
  if transportAmount and transportAmount >= 0 then contract.transportAmount = transportAmount end
  if destinationId ~= nil then contract.destinationId = destinationId end
  if destinationX and destinationX ~= 0 then contract.destinationX = destinationX end
  if destinationZ and destinationZ ~= 0 then contract.destinationZ = destinationZ end

  return contract
end

-- Function to retrieve WorkAreaType name from index (or template display name for non-field-work).
function CustomContract:getWorkTypeAreaName()
  if self.templateId == CustomContract.TEMPLATE.TRANSPORT then
    return g_i18n:getText("cc_dialog_template_transport")
  end

  if self.templateId == CustomContract.TEMPLATE.FARM_JOB then
    return g_i18n:getText("cc_dialog_template_farm_job")
  end

  if self.templateId == CustomContract.TEMPLATE.CUSTOM then
    return g_i18n:getText("cc_dialog_template_custom")
  end

  local wt = self.workAreaTypeIndex and CustomContract.WORKAREATYPES[self.workAreaTypeIndex]

  return (wt and wt.name)
end

--- Returns a short label for list display (e.g. "Farmland 12" or "Transport").
function CustomContract:getListLabel()
  if self.templateId == CustomContract.TEMPLATE.TRANSPORT then
    return g_i18n:getText("cc_dialog_template_transport")
  end

  if self.templateId == CustomContract.TEMPLATE.FARM_JOB then
    return g_i18n:getText("cc_dialog_template_farm_job")
  end

  if self.templateId == CustomContract.TEMPLATE.CUSTOM then
    return g_i18n:getText("cc_dialog_template_custom")
  end

  return string.format(g_i18n:getText("cc_contract_list_field_label"), self.farmlandId)
end

--- Returns description text for contract details (field work vs transport).
function CustomContract:getDescriptionText()
  if self.templateId == CustomContract.TEMPLATE.TRANSPORT then
    local productName = "?"

    if self.fillTypeIndex and g_fillTypeManager then
      local ft = g_fillTypeManager:getFillTypeByIndex(self.fillTypeIndex)
      productName = (ft and (ft.title or ft.name)) or tostring(self.fillTypeIndex)
    end
    local line1 = string.format(g_i18n:getText("cc_contract_description_transport") or "Transport %d L %s",
      self.transportAmount or 0,
      productName)
    local d = self.description
    if d ~= nil and d ~= "" and d ~= "-" then
      return line1 .. "\n" .. string.format(g_i18n:getText("cc_contract_description_transport_pickup"), d)
    end
    return line1
  end

  local farmland = (g_farmlandManager and self.farmlandId) and g_farmlandManager:getFarmlandById(self.farmlandId)
  local areaHa = (farmland and farmland.areaInHa)
  local workKey = "cc_workareatype_" .. string.lower(self:getWorkTypeAreaName())
  return string.format(g_i18n:getText("cc_contract_description"), g_i18n:getText(workKey) or self:getWorkTypeAreaName(),
    self.farmlandId or 0, areaHa)
end
