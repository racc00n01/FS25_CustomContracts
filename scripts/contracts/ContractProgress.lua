--
-- FS25 Contract and Invoices
--
-- @Author: Racc00n
-- @Version: 1.0.0.0
--
-- Field work completion for accepted contracts.
--
-- Mirrors the base game (AbstractFieldMission): count the density map pixels
-- inside the field polygon that match a "done" filter and divide them by the
-- total pixels of that polygon. The field is split into partitions of
-- SQM_PER_PARTITION and only a few partitions are measured per tick, so large
-- fields never cost a full sweep in a single frame.
--
-- Server side only, clients receive the finished value through
-- ContractProgressEvent.
--

ContractProgress = {}
local ContractProgress_mt = Class(ContractProgress)

ContractProgress.SQM_PER_PARTITION = 2500
ContractProgress.SUCCESS_FACTOR = 0.98

-- The base game measures one partition per tick, which means the bar of a large
-- field only catches up after a minute. Spread a full sweep over this many ticks
-- instead, but never measure more than MAX_PARTS_PER_STEP partitions at once so
-- the cost per frame stays bounded.
ContractProgress.SWEEP_TICKS = 3
ContractProgress.MAX_PARTS_PER_STEP = 12

-- Completion of a contract that is not measured (yet).
ContractProgress.NOT_TRACKED = -1

--- Returns every field that belongs to the given farmland.
local function getFieldsForFarmland(farmlandId)
  local fields = {}
  if g_fieldManager == nil or farmlandId == nil then
    return fields
  end

  for _, field in pairs(g_fieldManager:getFields()) do
    local farmland = field.getFarmland ~= nil and field:getFarmland() or nil
    if farmland ~= nil and farmland:getId() == farmlandId then
      table.insert(fields, field)
    end
  end

  return fields
end

local function newFieldGroundModifier(densityMapType)
  local system = g_currentMission.fieldGroundSystem
  if system == nil then
    return nil
  end

  local mapId, firstChannel, numChannels = system:getDensityMapData(densityMapType)
  if mapId == nil then
    return nil
  end

  local modifier = DensityMapModifier.new(mapId, firstChannel, numChannels, g_terrainNode)
  return modifier, DensityMapFilter.new(modifier), system:getMaxValue(densityMapType)
end

local function newSystemModifier(system)
  if system == nil or system.getDensityMapData == nil then
    return nil
  end

  local mapId, firstChannel, numChannels = system:getDensityMapData()
  if mapId == nil then
    return nil
  end

  local modifier = DensityMapModifier.new(mapId, firstChannel, numChannels, g_terrainNode)
  return modifier, DensityMapFilter.new(modifier)
end

--- Ground work is done when the ground type sits between two types (see CultivateMission).
local function buildGroundType(fromType, toType)
  return function()
    local modifier, filter = newFieldGroundModifier(FieldDensityMap.GROUND_TYPE)
    if modifier == nil then
      return nil
    end

    filter:setValueCompareParams(
      DensityValueCompareType.BETWEEN,
      FieldGroundType.getValueByType(fromType),
      FieldGroundType.getValueByType(toType)
    )
    return modifier, filter
  end
end

--- Level maps (spray, lime, roller, stubble shred) are done one level above the
--- level the field had when the contract started, same as FertilizeMission.
local function buildLevelIncrease(densityMapType, fieldStateKey)
  return function(contract, field)
    local modifier, filter, maxValue = newFieldGroundModifier(densityMapType)
    if modifier == nil then
      return nil
    end

    maxValue = maxValue or 1

    if contract.progressTargetLevel == nil then
      local fieldState = field.getFieldState ~= nil and field:getFieldState() or nil
      local currentLevel = (fieldState ~= nil and fieldState[fieldStateKey]) or 0
      contract.progressTargetLevel = math.min(currentLevel + 1, maxValue)
    end

    filter:setValueCompareParams(DensityValueCompareType.BETWEEN, contract.progressTargetLevel, maxValue)
    return modifier, filter
  end
end

--- Weeds and stones are done when the map is back to zero.
local function buildClearSystem(systemName)
  return function()
    local modifier, filter = newSystemModifier(g_currentMission[systemName])
    if modifier == nil then
      return nil
    end

    filter:setValueCompareParams(DensityValueCompareType.EQUAL, 0)
    return modifier, filter
  end
end

--- Harvesting and mowing are done when the fruit reached its cut state.
local function buildCutFruit(contract, field)
  local fruitTypeIndex = contract.progressFruitTypeIndex
  if fruitTypeIndex == nil or fruitTypeIndex < 0 then
    local fieldState = field.getFieldState ~= nil and field:getFieldState() or nil
    fruitTypeIndex = fieldState ~= nil and fieldState.fruitTypeIndex or nil
    if fruitTypeIndex == nil or fruitTypeIndex == FruitType.UNKNOWN then
      return nil
    end
    contract.progressFruitTypeIndex = fruitTypeIndex
  end

  local fruitDesc = g_fruitTypeManager:getFruitTypeByIndex(fruitTypeIndex)
  if fruitDesc == nil or fruitDesc.terrainDataPlaneId == nil then
    return nil
  end

  local modifier = DensityMapModifier.new(
    fruitDesc.terrainDataPlaneId,
    fruitDesc.startStateChannel,
    fruitDesc.numStateChannels,
    g_terrainNode
  )
  local filter = DensityMapFilter.new(modifier)
  filter:setValueCompareParams(DensityValueCompareType.EQUAL, fruitDesc.cutState)

  return modifier, filter
end

-- Work area types without a density map representation (baling, wrapping,
-- tedding, windrowing, foliage removal, other) are intentionally missing:
-- those contracts simply get no progress bar.
ContractProgress.BUILDERS = {
  [1] = buildGroundType(FieldGroundType.STUBBLE_TILLAGE, FieldGroundType.SEEDBED),    -- Cultivate
  [2] = buildGroundType(FieldGroundType.PLOWED, FieldGroundType.PLOWED),              -- Plow
  [3] = buildGroundType(FieldGroundType.SOWN, FieldGroundType.RIDGE_SOWN),            -- Seed
  [4] = buildLevelIncrease(FieldDensityMap.SPRAY_LEVEL, "sprayLevel"),                -- Fertilize
  [5] = buildCutFruit,                                                                -- Harvest
  [6] = buildLevelIncrease(FieldDensityMap.ROLLER_LEVEL, "rollerLevel"),              -- Roll
  [7] = buildClearSystem("weedSystem"),                                               -- Weed
  [8] = buildLevelIncrease(FieldDensityMap.LIME_LEVEL, "limeLevel"),                  -- Lime
  [9] = buildLevelIncrease(FieldDensityMap.STUBBLE_SHRED_LEVEL, "stubbleShredLevel"), -- Mulch
  [10] = buildClearSystem("stoneSystem"),                                             -- Stone Pick
  [12] = buildCutFruit,                                                               -- Mowing
  [17] = buildClearSystem("weedSystem")                                               -- Spraying
}

--- Returns true when this contract type can be measured at all.
function ContractProgress.isSupported(contract)
  if contract == nil or contract.templateId ~= CustomContract.TEMPLATE.FIELD_WORK then
    return false
  end
  return ContractProgress.BUILDERS[contract.workAreaTypeIndex] ~= nil
end

--- Builds the modifiers and partitions for a contract, or nil when it cannot be tracked.
function ContractProgress.new(contract)
  if not ContractProgress.isSupported(contract) then
    return nil
  end

  local fields = getFieldsForFarmland(contract.farmlandId)
  if #fields == 0 then
    return nil
  end

  local self = setmetatable({}, ContractProgress_mt)
  self.contract = contract
  self.parts = {}
  self.partIndex = 1
  self.raw = 0

  local builder = ContractProgress.BUILDERS[contract.workAreaTypeIndex]
  for _, field in ipairs(fields) do
    local modifier, filter = builder(contract, field)
    if modifier ~= nil and filter ~= nil then
      self:addFieldPartitions(field, modifier, filter)
    end
  end

  if #self.parts == 0 then
    return nil
  end

  -- Measure everything once so the bar is correct from the first tick and so a
  -- freshly accepted contract knows the state the field started in.
  self:measureAll()

  if contract.progressBaseline == nil then
    contract.progressBaseline = self.raw
  end

  return self
end

--- Splits one field polygon into partitions of ContractProgress.SQM_PER_PARTITION.
function ContractProgress:addFieldPartitions(field, modifier, filter)
  local polygon = field:getDensityMapPolygon()
  if polygon == nil then
    return
  end

  polygon:applyToModifier(modifier)

  local minZ, maxZ = modifier:getPolygonMinMaxZ()
  if minZ == nil or maxZ == nil or maxZ <= minZ then
    table.insert(self.parts, { modifier = modifier, filter = filter, matched = 0, total = 0 })
    return
  end

  local sizeSqm = MathUtil.haToSqm(field:getAreaHa())
  local numPartitions = math.max(1, math.ceil(sizeSqm / ContractProgress.SQM_PER_PARTITION))
  local regionSize = (maxZ - minZ) / numPartitions
  local currentMinZ = minZ

  for _ = 1, numPartitions do
    local currentMaxZ = math.min(math.ceil(currentMinZ + regionSize), maxZ)
    table.insert(self.parts, {
      modifier = modifier,
      filter = filter,
      minZ = currentMinZ,
      maxZ = currentMaxZ,
      matched = 0,
      total = 0
    })

    currentMinZ = currentMaxZ
    if currentMaxZ >= maxZ then
      break
    end
  end
end

function ContractProgress:measurePart(part)
  if part.minZ ~= nil then
    part.modifier:setPolygonClipRegion(part.minZ, part.maxZ)
  end

  local _, matchedPixels, totalPixels = part.modifier:executeGet(part.filter)
  part.matched = matchedPixels or 0
  part.total = totalPixels or 0
end

function ContractProgress:updateRawCompletion()
  local matched, total = 0, 0
  for _, part in ipairs(self.parts) do
    matched = matched + part.matched
    total = total + part.total
  end

  if total > 0 then
    self.raw = matched / total
  else
    self.raw = 0
  end
end

--- Measures every partition at once, only used when the tracker is created.
function ContractProgress:measureAll()
  for _, part in ipairs(self.parts) do
    self:measurePart(part)
  end
  self:updateRawCompletion()
end

--- Number of partitions measured per tick, see SWEEP_TICKS.
function ContractProgress:getPartsPerStep()
  local perStep = math.ceil(#self.parts / ContractProgress.SWEEP_TICKS)
  return math.min(math.max(perStep, 1), ContractProgress.MAX_PARTS_PER_STEP)
end

--- Measures the next batch of partitions and returns the current completion [0, 1].
function ContractProgress:step()
  for _ = 1, self:getPartsPerStep() do
    local part = self.parts[self.partIndex]
    if part == nil then
      break
    end

    self:measurePart(part)

    self.partIndex = self.partIndex + 1
    if self.partIndex > #self.parts then
      self.partIndex = 1
    end
  end

  self:updateRawCompletion()

  return self:getCompletion()
end

--- Raw ratio normalized against the state the field had when the contract was
--- accepted, then scaled like the base game does with SUCCESS_FACTOR.
function ContractProgress:getCompletion()
  local baseline = self.contract.progressBaseline or 0
  local span = 1 - baseline
  local value

  if span > 0.01 then
    value = (self.raw - baseline) / span
  else
    -- The field was already in the target state when the contract started.
    value = 1
  end

  return math.min(math.max(value / ContractProgress.SUCCESS_FACTOR, 0), 1)
end
