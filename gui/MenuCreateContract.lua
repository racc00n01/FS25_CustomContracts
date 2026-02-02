--
-- FS25 CustomContracts
--
-- @Author: Racc00n
-- @Version: 0.0.1.1
--

MenuCreateContract = {}
local MenuCreateContract_mt = Class(MenuCreateContract, MessageDialog)

CustomContractTemplates = {
  {
    id = "FIELD_WORK",
    text = "Field work",
    subtitle = "Cultivate, seed, harvest, mow…"
  },
  {
    id = "TRANSPORT",
    text = "Transport",
    subtitle = "Move goods from A to B"
  },
  {
    id = "FARM_JOB",
    text = "Farm job",
    subtitle = "Feed cows, remove slurry/manure…"
  },
  {
    id = "CUSTOM",
    text = "Custom",
    subtitle = "Free-form job"
  }
}

CustomContractWorkTypes = {
  { id = "CULTIVATE",     text = "Cultivate" },
  { id = "PLOW",          text = "Plow" },
  { id = "SEED",          text = "Seed" },
  { id = "FERTILIZE",     text = "Fertilize" },
  { id = "HARVEST",       text = "Harvest" },
  { id = "ROLL",          text = "Roll" },
  { id = "WEED",          text = "Weed" },
  { id = "LIME",          text = "Lime" },
  { id = "MULCH",         text = "Mulch" },
  { id = "STONEPICK",     text = "Stone Pick" },
  { id = "REMOVEFOLIAGE", text = "Remove Foliage" },
  { id = "MOW",           text = "Mowing" },
  { id = "TEDDING",       text = "Tedding" },
  { id = "WINDROWING",    text = "Windrowing" },
  { id = "BALING",        text = "Baling" },
  { id = "BALEWRAPPING",  text = "Bale Wrapping" },
  { id = "SPRAYING",      text = "Spraying" },
  { id = "OTHER",         text = "Other" }
}

function MenuCreateContract.new(target, custom_mt)
  local self = MessageDialog.new(target, custom_mt or MenuCreateContract_mt)
  return self
end

function MenuCreateContract:onCreate()
  MenuCreateContract:superClass().onCreate(self)
end

function MenuCreateContract:onGuiSetupFinished()
  MenuCreateContract:superClass().onGuiSetupFinished(self)
end

function MenuCreateContract:onOpen()
  MenuCreateContract:superClass().onOpen(self)

  local cc = g_currentMission.CustomContracts
  self.templateId = (cc and cc.selectedCreateTemplateId) or "FIELD_WORK"

  -- now apply + setup
  self:fillMonthMultiTextOption(self.startDateSelector, "startDateValues")
  self:fillMonthMultiTextOption(self.dueDateSelector, "dueDateValues")

  self:applyTemplate(self.templateId)

  if self.templateId == "FIELD_WORK" then
    self:setupFieldWork()
  elseif self.templateId == "TRANSPORT" then
    self:setupTransport()
  elseif self.templateId == "FARM_JOB" then
    self:setupFarmJobs()
  end

  self._pendingTemplateSetup = true
end

function MenuCreateContract:update(dt)
  MenuCreateContract:superClass().update(self, dt)

  if self._pendingTemplateSetup ~= true then
    return
  end

  -- Need a real farm (not spectator/0) and field manager ready
  local farmId = g_currentMission and g_currentMission:getFarmId()
  if farmId == nil or farmId == 0 or farmId == FarmManager.SPECTATOR_FARM_ID then
    return
  end

  if g_fieldManager == nil or g_fieldManager.getFields == nil then
    return
  end

  -- Now do the actual setup
  if self.templateId == "FIELD_WORK" then
    self:setupFieldWork()
  elseif self.templateId == "TRANSPORT" then
    self:setupTransport()
  elseif self.templateId == "FARM_JOB" then
    self:setupFarmJobs()
  elseif self.templateId == "CUSTOM" then
    -- nothing special
  end

  self._pendingTemplateSetup = false
end

function MenuCreateContract:onClose()
  MenuCreateContract:superClass().onClose(self)
  if g_currentMission and g_currentMission.CustomContracts then
    g_currentMission.CustomContracts.selectedCreateTemplateId = nil
  end
end

function MenuCreateContract:setTemplate(templateId)
  self.templateId = templateId
end

function MenuCreateContract:applyTemplate(templateId)
  templateId = templateId or "FIELD_WORK"


  print(string.format("[CC] applyTemplate=%s", tostring(templateId)))
  print("[CC] sections:",
    "field=", self.sectionFieldWork,
    "transport=", self.sectionTransport,
    "farmJob=", self.sectionFarmJob,
    "custom=", self.sectionCustom
  )


  if templateId == "FIELD_WORK" then
    self.sectionFieldWork:setVisible(true)
    self.sectionTransport:setVisible(false)
    self.sectionCustom:setVisible(false)
    self.sectionFarmJob:setVisible(false)
  end
  if templateId == "TRANSPORT" then
    self.sectionFieldWork:setVisible(false)
    self.sectionTransport:setVisible(true)
    self.sectionCustom:setVisible(false)
    self.sectionFarmJob:setVisible(false)
  end
  if templateId == "FARM_JOB" then
    self.sectionFieldWork:setVisible(false)
    self.sectionFarmJob:setVisible(true)
    self.sectionCustom:setVisible(false)
  end
  if templateId == "CUSTOM" then
    self.sectionFieldWork:setVisible(false)
    self.sectionTransport:setVisible(false)
    self.sectionCustom:setVisible(true)
    self.sectionFarmJob:setVisible(false)
  end
end

function MenuCreateContract:onFieldSelectChange(state)
  self.selectedFieldIndex = state
end

function MenuCreateContract:onGroupSelectChange(state)
  self.selectedWorkTypeIndex = state
end

function MenuCreateContract:onStartDateSelectChange(state)
  self.selectedStartDateIndex = state
end

function MenuCreateContract:onDueDateSelectChange(state)
  self.selectedDueDateIndex = state
end

-- XML onClick handlers
function MenuCreateContract:onConfirm(sender)
  if g_client == nil then return end

  local reward = tonumber(self.rewardInput:getText())
  local description = self.descriptionInput:getText()

  if reward == nil then
    InfoDialog.show("Please fill reward")
    return
  end

  local startIdx = self.selectedStartDateIndex or 1
  local dueIdx   = self.selectedDueDateIndex or 1
  local startV   = self.startDateValues[startIdx]
  local dueV     = self.dueDateValues[dueIdx]

  if startV == nil or dueV == nil then
    InfoDialog.show("Please select start and due date")
    return
  end
  if dueIdx < startIdx then
    InfoDialog.show("Due date cannot be before start date")
    return
  end

  local templateId = self.templateId or "FIELD_WORK"
  local payload = self:buildPayloadForTemplate(templateId)
  if payload == nil then
    -- buildPayload should have shown the error dialog
    return
  end

  local contract = {
    templateId  = templateId,
    payload     = payload,
    reward      = reward,
    description = (description ~= nil and description ~= "" and description) or "-",
    startPeriod = startV.period,
    startDay    = startV.day,
    duePeriod   = dueV.period,
    dueDay      = dueV.day
  }

  g_client:getServerConnection():sendEvent(
    CreateContractEvent.new(contract, g_currentMission:getFarmId())
  )

  self:close()
end

function MenuCreateContract:onCancel(sender)
  self:close()
end

function MenuCreateContract:retrieveFieldInfo(fieldId)
  local field = g_fieldManager:getFieldById(fieldId)

  if field == nil then
    return nil
  end
end

function MenuCreateContract:buildMonthOptionData()
  local env = g_currentMission.environment
  if env == nil then
    return {}, {}
  end

  local currentPeriod = env.currentPeriod

  local daysPerPeriod = env.daysPerPeriod or 1

  local texts = {}
  local values = {}

  for offset = 0, 11 do
    local period = DateUtil.wrapPeriod(currentPeriod + offset)
    local month = DateUtil.periodToMonth(period)

    if daysPerPeriod > 1 then
      for day = 1, daysPerPeriod do
        table.insert(texts,
          string.format("%s %d", DateUtil.getMonthName(month), day)
        )
        table.insert(values, {
          period = period,
          month  = month,
          day    = day
        })
      end
    else
      table.insert(texts, DateUtil.getMonthName(month))
      table.insert(values, {
        period = period,
        month  = month,
        day    = 1
      })
    end
  end

  return texts, values
end

function MenuCreateContract:fillMonthMultiTextOption(multiTextOption, valuesFieldName)
  local texts, values = self:buildMonthOptionData()

  self[valuesFieldName] = values

  multiTextOption:setTexts(texts)
  multiTextOption:setState(1, true)
end

function MenuCreateContract:setupFieldWork()
  local workTypeTexts = {}
  for _, workType in ipairs(CustomContractWorkTypes) do
    table.insert(workTypeTexts, workType.text)
  end
  self.workTypeSelector:setTexts(workTypeTexts)
  self.workTypeSelector:setState(1, false)
  self.selectedWorkTypeIndex = 1

  local fieldIds = {}
  local farmId = g_currentMission:getFarmId()
  if farmId == nil then return end

  for _, field in pairs(g_fieldManager:getFields()) do
    if field:getOwner() == farmId then
      table.insert(fieldIds, field:getId())
    end
  end

  table.sort(fieldIds)
  self.fieldIds = fieldIds

  local fieldTexts = {}
  for _, fieldId in ipairs(fieldIds) do
    table.insert(fieldTexts, string.format("Field %d", fieldId))
  end

  self:fillMonthMultiTextOption(self.startDateSelector, "startDateValues")
  self:fillMonthMultiTextOption(self.dueDateSelector, "dueDateValues")

  self.selectedStartDateIndex = 1
  self.selectedDueDateIndex   = 1

  self.fieldSelector:setTexts(fieldTexts)
  self.fieldSelector:setState(1, false)

  self.selectedFieldIndex = 1
end

function MenuCreateContract:setupTransport()
  self.transportProducts = self:collectFarmSiloFillTypes()
  self.selectedTransportProductIndex = 1

  local texts = {}
  for _, p in ipairs(self.transportProducts) do
    table.insert(texts, string.format("%s (%d L)", p.title, p.amount))
  end

  if #texts == 0 then
    texts = { "No silo products found" }
  end

  self.transportProductSelector:setTexts(texts)
  self.transportProductSelector:setState(1, false)

  self.transportFromInput:setText("")
  self.transportToInput:setText("")
  self.transportAmountInput:setText("")

  -- self:updateTransportAmountHint()
end

function MenuCreateContract:setupFarmJobs()
  -- TODO later
end

function MenuCreateContract:buildPayloadForTemplate(templateId)
  if templateId == "FIELD_WORK" then
    local fieldId = self.fieldIds[self.selectedFieldIndex or 0]
    local wtIdx = self.selectedWorkTypeIndex or 1
    local workType = CustomContractWorkTypes[wtIdx] and CustomContractWorkTypes[wtIdx].id

    if fieldId == nil or workType == nil then
      InfoDialog.show("Please select field and work type")
      return nil
    end

    return { fieldId = fieldId, workType = workType }
  elseif templateId == "TRANSPORT" then
    local p = self.transportProducts and self.transportProducts[self.selectedTransportProductIndex or 1]
    if p == nil or p.fillTypeIndex == nil or p.amount == nil or p.amount <= 0 then
      InfoDialog.show("Select a silo product.")
      return nil
    end

    local fromText = self.transportFromInput:getText() or ""
    local toText   = self.transportToInput:getText() or ""
    local amount   = tonumber(self.transportAmountInput:getText() or "")

    if fromText == "" or toText == "" then
      InfoDialog.show("Please fill From and To.")
      return nil
    end

    if amount == nil then
      InfoDialog.show("Please fill Amount.")
      return nil
    end

    amount = math.floor(amount + 0.5)
    if amount < 1 then
      InfoDialog.show("Amount must be at least 1.")
      return nil
    end

    if amount > p.amount then
      InfoDialog.show(string.format("Amount exceeds available stock (max %,d L).", p.amount))
      return nil
    end

    return {
      fillTypeIndex = p.fillTypeIndex,
      amount = amount,
      fromText = fromText,
      toText = toText
    }
  elseif templateId == "FARM_JOB" then
    local idx = self.selectedFarmJobIndex or 1
    local j = self.farmJobs and self.farmJobs[idx]
    if j == nil then
      InfoDialog.show("Please select farm job")
      return nil
    end
    return { jobType = j.id }
  elseif templateId == "CUSTOM" then
    local title = self.titleInput and self.titleInput:getText() or ""
    title = title ~= "" and title or "Custom job"
    return { title = title }
  end

  InfoDialog.show("Unknown template")
  return nil
end

function MenuCreateContract:onTransportProductChange(state)
  self.selectedTransportProductIndex = state
  -- self:updateTransportAmountHint()
end

-- function MenuCreateContract:updateTransportAmountHint()
--   local p = self.transportProducts and self.transportProducts[self.selectedTransportProductIndex or 1]
--   if p == nil or p.amount == nil or p.amount <= 0 then
--     self.transportAmountHint:setText("Select a product with available stock.")
--     return
--   end

--   self.transportAmountHint:setText(string.format("Min 1 L • Max %,d L available", p.amount))
-- end

function MenuCreateContract:collectFarmSiloFillTypes()
  local results = {}

  local farmId = g_currentMission:getFarmId()

  local totals = {}

  local placeableSystem = g_currentMission.placeableSystem
  local placeables = placeableSystem and placeableSystem.placeables

  if placeables == nil then
    return results
  end

  for v = 1, #g_currentMission.placeableSystem.placeables do
    local placeable = g_currentMission.placeableSystem.placeables[v]
    if placeable.spec_silo ~= nil then
      local owner = placeable.ownerFarmId
      if owner == farmId or owner == 0 then
        local siloSpec = placeable.spec_silo
        local loadingStation = siloSpec.loadingStation

        if loadingStation ~= nil and loadingStation.getAllFillLevels ~= nil then
          local fillLevels = loadingStation:getAllFillLevels(farmId) -- [fillTypeIndex] = liters
          if fillLevels ~= nil then
            for fillTypeIndex, liters in pairs(fillLevels) do
              if fillTypeIndex ~= nil and liters ~= nil and liters > 0 then
                totals[fillTypeIndex] = (totals[fillTypeIndex] or 0) + liters
              end
            end
          end
        end
      end
    end
  end

  for fillTypeIndex, liters in pairs(totals) do
    local ft = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
    if ft ~= nil then
      table.insert(results, {
        fillTypeIndex = fillTypeIndex,
        title = ft.title or ft.name or ("FillType " .. tostring(fillTypeIndex)),
        amount = math.floor(liters + 0.5)
      })
    end
  end

  table.sort(results, function(a, b) return a.title < b.title end)
  return results
end
