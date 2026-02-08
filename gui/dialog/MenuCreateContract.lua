--
-- FS25 CustomContracts
--
-- @Author: Racc00n
-- @Version: 0.0.1.1
--

MenuCreateContract = {}
local MenuCreateContract_mt = Class(MenuCreateContract, MessageDialog)

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

  self.prefilledFieldId = nil
  self.selectedRewardAmount = 0

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

  -- Set the prefilledFieldId as a variable inside this dialog, so it can be easier used.
  if g_currentMission.CustomContracts.uiState ~= nil then
    self.prefilledFieldId = g_currentMission.CustomContracts.uiState.prefilledFieldId
  end

  -- Logic the fill the multiselectoption for the work types
  local workTypeTexts = {}

  -- Map through the different types and add each one of them to the texts table.
  for _, workType in ipairs(CustomContractWorkTypes) do
    table.insert(workTypeTexts, workType.text)
  end

  -- Set the worktype multiselectoption with the correct options and index
  self.workTypeSelector:setTexts(workTypeTexts)
  self.workTypeSelector:setState(1, false)

  local fieldIds = {}

  local farmId = g_currentMission:getFarmId()
  if farmId == nil then
    return
  end

  for _, field in pairs(g_fieldManager:getFields()) do
    if field:getOwner() == farmId then
      table.insert(fieldIds, field:getId())
    end
  end

  table.sort(fieldIds)

  self.fieldIds = fieldIds

  local fieldTexts = {}
  for _, fieldId in ipairs(fieldIds) do
    local field = g_fieldManager:getFieldById(fieldId)
    if field ~= nil then
      table.insert(fieldTexts,
        string.format(g_i18n:getText("cc_dialog_create_input_field_value"), field:getId(), field.areaHa))
    end
  end

  self.fieldSelector:setTexts(fieldTexts)

  local selectedIndex = 1

  if self.prefilledFieldId ~= nil then
    for i, id in ipairs(fieldIds) do
      if id == self.prefilledFieldId then
        selectedIndex = i
        break
      end
    end
  end

  self.selectedFieldIndex = selectedIndex
  self.fieldSelector:setState(selectedIndex, false)

  self:fillMonthMultiTextOption(self.startDateSelector, "startDateValues")
  self:fillMonthMultiTextOption(self.dueDateSelector, "dueDateValues")

  self.selectedStartDateIndex = 1
  self.selectedDueDateIndex   = 1

  self:updateAmountSlider()
end

function MenuCreateContract:onClose()
  MenuCreateContract:superClass().onClose(self)

  -- Remove the prefilledFieldId from the session, so it doesnt intervene when opening the createContractDialog from a different route.
  if g_currentMission.CustomContracts.uiState ~= nil then
    g_currentMission.CustomContracts.uiState.prefilledFieldId = nil
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

function MenuCreateContract:onClickAmount(state)
  local idx = state or (self.rewardSelector:getState() or 1)
  self.selectedRewardAmountIndex = idx

  local v = 0
  if self.amountValues ~= nil then
    v = self.amountValues[idx] or 0
  end

  self.selectedRewardAmount = v
  self.itemTextAmount:setText(tostring(v))
end

-- XML onClick handlers
function MenuCreateContract:onConfirm(sender)
  if g_client == nil then
    return
  end

  local fieldId = self.fieldIds[self.selectedFieldIndex or 0]
  local reward = tonumber(self.rewardInput:getText())
  local description = self.descriptionInput:getText()

  local index = self.selectedWorkTypeIndex or 1
  local workType = CustomContractWorkTypes[index].text

  if fieldId == nil or reward == nil or workType == nil then
    InfoDialog.show(g_i18n:getText("cc_dialog_create_validation_fields"))
    return
  end

  local startIdx = self.selectedStartDateIndex or 1
  local dueIdx   = self.selectedDueDateIndex or 1

  local startV   = self.startDateValues[self.selectedStartDateIndex or 1]
  local dueV     = self.dueDateValues[self.selectedDueDateIndex or 1]

  if startV == nil or dueV == nil then
    InfoDialog.show(g_i18n:getText("cc_dialog_create_validation_fields_due_date"))
    return
  end

  if dueIdx < startIdx then
    InfoDialog.show(g_i18n:getText("cc_dialog_create_validation_fields_start_date"))
    return
  end

  local contract = {
    fieldId     = fieldId,
    workType    = workType,
    reward      = reward,
    description = description or "-",
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

function MenuCreateContract:fillMonthMultiTextOption(multiTextOption, valuesFieldName)
  local texts, values = CustomUtils:buildMonthOptionData()

  self[valuesFieldName] = values

  multiTextOption:setTexts(texts)
  multiTextOption:setState(1, true)
end

function MenuCreateContract:updateAmountSlider()
  local FIXED_MAX = 10000
  local STEP = 50

  self.maxAmount = FIXED_MAX

  -- Build ascending list: 0, 1000, 2000 ... 10000
  self.amountValues = {}
  self.amountTexts = {}

  for value = 0, self.maxAmount, STEP do
    table.insert(self.amountValues, value)
    table.insert(self.amountTexts, string.format("%d $", value))
  end

  -- Default selection = 0 (or change to last index if you prefer max default)
  self.selectedRewardAmountIndex = 1
  self.selectedRewardAmount = self.amountValues[self.selectedRewardAmountIndex]

  self.rewardSelector:setTexts(self.amountTexts)
  self.rewardSelector:setState(self.selectedRewardAmountIndex, true)

  self.itemTextAmount:setText(tostring(self.selectedRewardAmount))
end
