--
-- FS25 CustomContracts
--
-- @Author: Racc00n
-- @Version: 0.0.1.1
--

CustomContract = {}
CustomContract.dir = g_currentModDirectory
CustomContract.modName = g_currentModName
CustomContract.__index = CustomContract
CustomContract_mt = Class(CustomContract)


CustomContract.STATUS = {
  OPEN      = "OPEN",
  ACCEPTED  = "ACCEPTED",
  COMPLETED = "COMPLETED",
  CANCELLED = "CANCELLED",
  EXPIRED   = "EXPIRED"
}

CustomContract.TEMPLATE = {
  FIELD_WORK = "FIELD_WORK",
  TRANSPORT  = "TRANSPORT",
  FARM_JOB   = "FARM_JOB",
  CUSTOM     = "CUSTOM"
}

-- Intizialise function when creating a new CustomContract.
function CustomContract.new(id, creatorFarmId, templateId, payload, reward, description, startPeriod, startDay, duePeriod,
                            dueDay)
  local self            = setmetatable({}, CustomContract_mt)

  self.id               = id
  self.creatorFarmId    = creatorFarmId
  self.contractorFarmId = nil

  self.templateId       = templateId or CustomContract.TEMPLATE.FIELD_WORK
  self.payload          = payload or {}

  self.reward           = reward or 0
  self.status           = CustomContract.STATUS.OPEN
  self.description      = description or ""
  self.startPeriod      = startPeriod or -1
  self.startDay         = startDay or -1
  self.duePeriod        = duePeriod or -1
  self.dueDay           = dueDay or -1

  return self
end

function CustomContract:getFieldId()
  if self.templateId == CustomContract.TEMPLATE.FIELD_WORK then
    return self.payload.fieldId
  end
  return nil
end

function CustomContract:getWorkType()
  if self.templateId == CustomContract.TEMPLATE.FIELD_WORK then
    return self.payload.workType -- should be ID like "HARVEST"
  end
  return nil
end

function CustomContract:getCustomTitle()
  if self.templateId == CustomContract.TEMPLATE.CUSTOM then
    return self.payload.title
  end
  return nil
end

local function writeNonEmptyString(streamId, s)
  streamWriteString(streamId, s or "")
end

local function readStringSafe(streamId)
  local s = streamReadString(streamId)
  return s or ""
end

function CustomContract:writeStream(streamId)
  streamWriteInt32(streamId, self.id)
  streamWriteInt32(streamId, self.creatorFarmId)
  streamWriteInt32(streamId, self.contractorFarmId or -1)

  -- new
  writeNonEmptyString(streamId, self.templateId)

  -- common
  streamWriteInt32(streamId, self.reward)
  writeNonEmptyString(streamId, self.status)
  writeNonEmptyString(streamId, self.description)
  streamWriteInt32(streamId, self.startPeriod)
  streamWriteInt32(streamId, self.startDay)
  streamWriteInt32(streamId, self.duePeriod)
  streamWriteInt32(streamId, self.dueDay)

  -- template payload (manual)
  local t = self.templateId
  local p = self.payload or {}

  if t == CustomContract.TEMPLATE.FIELD_WORK then
    streamWriteInt32(streamId, p.fieldId or 0)
    writeNonEmptyString(streamId, p.workType or "")
  elseif t == CustomContract.TEMPLATE.TRANSPORT then
    writeNonEmptyString(streamId, p.transportType or "")
    writeNonEmptyString(streamId, p.fillType or "")
    streamWriteInt32(streamId, p.amount or 0)
  elseif t == CustomContract.TEMPLATE.FARM_JOB then
    writeNonEmptyString(streamId, p.jobType or "")
    writeNonEmptyString(streamId, p.targetType or "")
    streamWriteInt32(streamId, p.targetId or 0)
    streamWriteInt32(streamId, p.amount or 0)
  elseif t == CustomContract.TEMPLATE.CUSTOM then
    writeNonEmptyString(streamId, p.title or "Custom job")
  else
    -- unknown: write nothing
  end
end

function CustomContract.newFromStream(streamId)
  local id = streamReadInt32(streamId)
  local creatorFarmId = streamReadInt32(streamId)
  local contractorFarmId = streamReadInt32(streamId)

  local templateId = readStringSafe(streamId)

  local reward = streamReadInt32(streamId)
  local status = readStringSafe(streamId)
  local description = readStringSafe(streamId)
  local startPeriod = streamReadInt32(streamId)
  local startDay = streamReadInt32(streamId)
  local duePeriod = streamReadInt32(streamId)
  local dueDay = streamReadInt32(streamId)

  local payload = {}

  if templateId == CustomContract.TEMPLATE.FIELD_WORK then
    payload.fieldId  = streamReadInt32(streamId)
    payload.workType = readStringSafe(streamId)
  elseif templateId == CustomContract.TEMPLATE.TRANSPORT then
    payload.transportType = readStringSafe(streamId)
    payload.fillType      = readStringSafe(streamId)
    payload.amount        = streamReadInt32(streamId)
  elseif templateId == CustomContract.TEMPLATE.FARM_JOB then
    payload.jobType    = readStringSafe(streamId)
    payload.targetType = readStringSafe(streamId)
    payload.targetId   = streamReadInt32(streamId)
    payload.amount     = streamReadInt32(streamId)
  elseif templateId == CustomContract.TEMPLATE.CUSTOM then
    payload.title = readStringSafe(streamId)
  else
    -- unknown: nothing
  end

  local contract = CustomContract.new(
    id,
    creatorFarmId,
    templateId,
    payload,
    reward,
    description,
    startPeriod,
    startDay,
    duePeriod,
    dueDay
  )

  contract.contractorFarmId = contractorFarmId ~= -1 and contractorFarmId or nil
  contract.status = status

  return contract
end
