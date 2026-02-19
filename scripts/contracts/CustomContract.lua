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

CustomContract.STATUS = {
  OPEN                       = "OPEN",
  ACCEPTED                   = "ACCEPTED",
  COMPLETED                  = "COMPLETED",
  CANCELLED                  = "CANCELLED",
  EXPIRED                    = "EXPIRED",
  COMPLETED_AWAITING_INVOICE = "COMPLETED_AWAITING_INVOICE",
  INVOICED                   = "INVOICED"
}

-- Intizialise function when creating a new CustomContract.
function CustomContract.new(id, creatorFarmId, farmlandId, workAreaTypeIndex, reward, description, startPeriod, startDay,
                            duePeriod,
                            dueDay, invoiceId)
  local self             = setmetatable({}, CustomContract_mt)

  self.id                = id
  self.creatorFarmId     = creatorFarmId
  self.contractorFarmId  = nil
  self.farmlandId        = farmlandId
  self.workAreaTypeIndex = workAreaTypeIndex
  self.reward            = reward
  self.status            = CustomContract.STATUS.OPEN
  self.description       = description or ""
  self.startPeriod       = startPeriod or -1
  self.startDay          = startDay or -1
  self.duePeriod         = duePeriod or -1
  self.dueDay            = dueDay or -1
  self.invoiceId         = invoiceId or -1

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
    invoiceId
  )

  contract.contractorFarmId = contractorFarmId ~= -1 and contractorFarmId or nil
  contract.status = status

  return contract
end

-- Function to retrieve WorkAreaType name from index
function CustomContract:getWorkTypeAreaName()
  return CustomContract.WORKAREATYPES[self.workAreaTypeIndex].name
end
