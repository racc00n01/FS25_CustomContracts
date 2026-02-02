--
-- FS25 CustomContracts
--
-- @Author: Racc00n
-- @Version: 0.0.1.1
--

CreateContractEvent = {}
local CreateContractEvent_mt = Class(CreateContractEvent, Event)

InitEventClass(CreateContractEvent, "CreateContractEvent")

-- Template IDs (keep centralized so server/client agree)
CreateContractEvent.TEMPLATE = {
  FIELD_WORK = "FIELD_WORK",
  TRANSPORT  = "TRANSPORT",
  FARM_JOB   = "FARM_JOB",
  CUSTOM     = "CUSTOM"
}

function CreateContractEvent.emptyNew()
  local self = Event.new(CreateContractEvent_mt)
  return self
end

--- payload structure (new):
-- {
--   templateId  = "FIELD_WORK" | "TRANSPORT" | "FARM_JOB" | "CUSTOM",
--   payload     = { ... template-specific ... },
--   reward      = number,
--   description = string,
--   startPeriod = int,
--   startDay    = int,
--   duePeriod   = int,
--   dueDay      = int
-- }
function CreateContractEvent.new(payload, farmId)
  local self = CreateContractEvent.emptyNew()
  self.payload = payload
  self.farmId = farmId
  return self
end

-- =========================
-- Stream helpers
-- =========================

local function writeNonEmptyString(streamId, s)
  if s == nil then s = "" end
  streamWriteString(streamId, s)
end

local function readStringSafe(streamId)
  local s = streamReadString(streamId)
  if s == nil then
    return ""
  end
  return s
end

-- =========================
-- Serialization
-- =========================

function CreateContractEvent:writeStream(streamId, connection)
  -- who created
  streamWriteInt32(streamId, self.farmId or FarmManager.SPECTATOR_FARM_ID)

  -- common header
  local templateId = (self.payload and self.payload.templateId) or CreateContractEvent.TEMPLATE.FIELD_WORK
  streamWriteString(streamId, templateId)

  -- common fields
  streamWriteInt32(streamId, self.payload.reward or 0)
  writeNonEmptyString(streamId, self.payload.description or "-")
  streamWriteInt32(streamId, self.payload.startPeriod or 0)
  streamWriteInt32(streamId, self.payload.startDay or 1)
  streamWriteInt32(streamId, self.payload.duePeriod or 0)
  streamWriteInt32(streamId, self.payload.dueDay or 1)

  -- template payload
  local p = self.payload.payload or {}

  if templateId == CreateContractEvent.TEMPLATE.FIELD_WORK then
    -- { fieldId=int, workType=stringId }
    streamWriteInt32(streamId, p.fieldId or 0)
    writeNonEmptyString(streamId, p.workType or "")
  elseif templateId == CreateContractEvent.TEMPLATE.TRANSPORT then
    -- Start minimal; expand later.
    -- { transportType=stringId, fillType=stringId?, amount=int?, from=?, to=? }
    writeNonEmptyString(streamId, p.transportType or "")
    writeNonEmptyString(streamId, p.fillType or "")
    streamWriteInt32(streamId, p.amount or 0)
  elseif templateId == CreateContractEvent.TEMPLATE.FARM_JOB then
    -- Start minimal; expand later.
    -- { jobType=stringId, targetType=stringId?, targetId=int?, amount=int? }
    writeNonEmptyString(streamId, p.jobType or "")
    writeNonEmptyString(streamId, p.targetType or "")
    streamWriteInt32(streamId, p.targetId or 0)
    streamWriteInt32(streamId, p.amount or 0)
  elseif templateId == CreateContractEvent.TEMPLATE.CUSTOM then
    -- { title=string }
    writeNonEmptyString(streamId, p.title or "Custom job")
  else
    -- Unknown template: write nothing extra to avoid desync.
    -- Better: write an int "0" version marker; but keep it simple for now.
  end
end

function CreateContractEvent:readStream(streamId, connection)
  self.farmId       = streamReadInt32(streamId)

  local templateId  = readStringSafe(streamId)
  local reward      = streamReadInt32(streamId)
  local description = readStringSafe(streamId)
  local startPeriod = streamReadInt32(streamId)
  local startDay    = streamReadInt32(streamId)
  local duePeriod   = streamReadInt32(streamId)
  local dueDay      = streamReadInt32(streamId)

  local payload     = {
    templateId  = templateId,
    reward      = reward,
    description = description,
    startPeriod = startPeriod,
    startDay    = startDay,
    duePeriod   = duePeriod,
    dueDay      = dueDay,
    payload     = {}
  }

  if templateId == CreateContractEvent.TEMPLATE.FIELD_WORK then
    payload.payload.fieldId  = streamReadInt32(streamId)
    payload.payload.workType = readStringSafe(streamId)
  elseif templateId == CreateContractEvent.TEMPLATE.TRANSPORT then
    payload.payload.transportType = readStringSafe(streamId)
    payload.payload.fillType      = readStringSafe(streamId)
    payload.payload.amount        = streamReadInt32(streamId)
  elseif templateId == CreateContractEvent.TEMPLATE.FARM_JOB then
    payload.payload.jobType    = readStringSafe(streamId)
    payload.payload.targetType = readStringSafe(streamId)
    payload.payload.targetId   = streamReadInt32(streamId)
    payload.payload.amount     = streamReadInt32(streamId)
  elseif templateId == CreateContractEvent.TEMPLATE.CUSTOM then
    payload.payload.title = readStringSafe(streamId)
  else
    -- Unknown template: nothing else to read.
  end

  self.payload = payload
  self:run(connection)
end

-- =========================
-- Run
-- =========================

function CreateContractEvent:run(connection)
  -- rebroadcast to all clients if server received it from a client
  if not connection:getIsServer() then
    g_server:broadcastEvent(CreateContractEvent.new(self.payload, self.farmId))
  end

  local farmId = self.farmId
  if farmId == nil or farmId == FarmManager.SPECTATOR_FARM_ID then
    return
  end

  local contractManager = g_currentMission.CustomContracts.ContractManager
  contractManager:handleCreateRequest(farmId, self.payload)
end
