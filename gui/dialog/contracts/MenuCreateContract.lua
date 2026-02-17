--
-- FS25 CustomContracts
--
-- @Author: Racc00n
-- @Version: 0.0.1.1
--

MenuCreateContract = {}
local MenuCreateContract_mt = Class(MenuCreateContract, MessageDialog)

function MenuCreateContract.new(target, custom_mt)
  local self = MessageDialog.new(target, custom_mt or MenuCreateContract_mt)

  self.farmId = g_currentMission:getFarmId()

  -- Contract paramaters
  self.workAreaTypeIndex = nil
  self.fieldId = 0
  self.startDate = 0
  self.dueDate = 0
  self.reward = 0
  self.description = nil

  -- Data helpers
  self.fieldIds = 0

  -- Indexes
  self.workTypeIndex = 1
  self.fieldIndex = 1

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

  -- Initialize variables
  self.farmId = g_currentMission:getFarmId()
  self.fieldIds = self:getOwnedFieldsIds()

  -- Populate workTypew MultiTextOption with available worktypes
  local workTypeTexts = {}

  for _, workType in ipairs(CustomContract.WORKAREATYPES) do
    table.insert(workTypeTexts, workType.name)
  end

  self.workTypeSelector:setTexts(workTypeTexts)
  self.workTypeSelector:setState(1, false)
  self.workTypeIndex = 1

  -- Populate field MultiTextOption with owned fields
  local fieldTexts = {}
  for _, fieldId in ipairs(self.fieldIds) do
    table.insert(fieldTexts, string.format(g_i18n:getText("cc_contract_list_field_label"), fieldId))
  end

  self.fieldSelector:setTexts(fieldTexts)
  self.fieldSelector:setState(1, false)
  self.fieldIndex = 1

  -- Populate startDate MultiTextOption with dates from now
  self:fillMonthMultiTextOption(self.startDateSelector, "startDateValues")
  self.selectedStartDateIndex = 1

  -- Populate dueDate MultiTextOption with dates from now till one year
  self:fillMonthMultiTextOption(self.dueDateSelector, "dueDateValues")
  self.selectedDueDateIndex = 1
end

function MenuCreateContract:onClose()
  MenuCreateContract:superClass().onClose(self)
end

function MenuCreateContract:onFieldSelectChange(state)
  self.fieldIndex = state
  self.fieldId = self.fieldIds[self.fieldIndex]
end

function MenuCreateContract:onGroupSelectChange(state)
  self.workTypeIndex = state
  self.workAreaTypeIndex = CustomContract.WORKAREATYPES[self.workTypeIndex].index
end

function MenuCreateContract:onStartDateSelectChange(state)
  self.selectedStartDateIndex = state
end

function MenuCreateContract:onDueDateSelectChange(state)
  self.selectedDueDateIndex = state
end

function MenuCreateContract:onClickVehicleList(list, section, index)
  self:toggleRentableVehicle(index)
  list:reloadData()
end

-- Submit create contract button
function MenuCreateContract:onConfirm(sender)
  if g_client == nil then return end

  self.reward = tonumber(self.rewardInput:getText())
  self.description = self.descriptionInput:getText()

  if self.fieldId == nil or self.reward == nil or self.workAreaTypeIndex == nil then
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
    fieldId           = self.fieldId,
    workAreaTypeIndex = self.workAreaTypeIndex,
    reward            = self.reward,
    description       = self.description or "-",
    startPeriod       = startV.period,
    startDay          = startV.day,
    duePeriod         = dueV.period,
    dueDay            = dueV.day
  }

  g_client:getServerConnection():sendEvent(
    CreateContractEvent.new(contract, self.farmId)
  )

  self:close()
end

function MenuCreateContract:onCancel(sender)
  -- Cleanup form
  self.reward = nil
  self.description = nil
  self.fieldId = nil
  self.workType = nil

  self:close()
end

function MenuCreateContract:fillMonthMultiTextOption(multiTextOption, valuesFieldName)
  local texts, values = CustomUtils:buildMonthOptionData()

  self[valuesFieldName] = values

  multiTextOption:setTexts(texts)
  multiTextOption:setState(1, true)
end

-- Retrieve the field ids of the farm
function MenuCreateContract:getOwnedFieldsIds()
  local fieldIds = {}

  for _, field in pairs(g_fieldManager:getFields()) do
    if field:getOwner() == self.farmId then
      table.insert(fieldIds, field:getId())
    end
  end

  table.sort(fieldIds)

  return fieldIds
end
