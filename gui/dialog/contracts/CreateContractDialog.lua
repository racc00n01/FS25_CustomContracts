--
-- FS25 Contract and Invoices
--
-- @Author: Racc00n
-- @Version: 1.0.0.0
--

CreateContractDialog = {}
local CreateContractDialog_mt = Class(CreateContractDialog, MessageDialog)
local modDirectory = g_currentModDirectory

function CreateContractDialog.register()
  local dialog = CreateContractDialog.new()
  g_gui:loadGui(modDirectory .. "gui/dialog/contracts/CreateContractDialog.xml", "createContractDialog", dialog)
  CreateContractDialog.INSTANCE = dialog
end

function CreateContractDialog.show()
  if CreateContractDialog.INSTANCE == nil then CreateContractDialog.register() end

  local dialog = CreateContractDialog.INSTANCE
  g_gui:showDialog("createContractDialog")
end

function CreateContractDialog.new(target, custom_mt)
  local self = MessageDialog.new(target, custom_mt or CreateContractDialog_mt)

  self.farmId = g_currentMission:getFarmId()

  -- Contract paramaters
  self.workAreaTypeIndex = nil
  self.farmlandId = 0
  self.startDate = 0
  self.dueDate = 0
  self.reward = 0
  self.description = nil

  -- Data helpers
  self.farmlandIds = 0

  -- Indexes
  self.workTypeIndex = 1
  self.farmlandIndex = 1

  return self
end

function CreateContractDialog:onCreate()
  CreateContractDialog:superClass().onCreate(self)
end

function CreateContractDialog:onGuiSetupFinished()
  CreateContractDialog:superClass().onGuiSetupFinished(self)
end

function CreateContractDialog:onOpen()
  CreateContractDialog:superClass().onOpen(self)

  -- Initialize variables
  self.farmId = g_currentMission:getFarmId()
  self.farmlandIds = g_farmlandManager:getOwnedFarmlandIdsByFarmId(self.farmId)

  -- Populate workTypew MultiTextOption with available worktypes
  local workTypeTexts = {}

  for _, workType in ipairs(CustomContract.WORKAREATYPES) do
    table.insert(workTypeTexts, workType.name)
  end

  self.workTypeSelector:setTexts(workTypeTexts)
  self.workTypeSelector:setState(1, false)
  self.workTypeIndex = 1
  self.workAreaTypeIndex = CustomContract.WORKAREATYPES[self.workTypeIndex].index

  -- Populate field MultiTextOption with owned fields
  local farmlandTexts = {}
  for _, farmlandId in ipairs(self.farmlandIds) do
    table.insert(farmlandTexts, string.format(g_i18n:getText("cc_contract_list_field_label"), farmlandId))
  end

  self.fieldSelector:setTexts(farmlandTexts)
  self.fieldSelector:setState(1, false)
  self.fieldIndex = 1
  self.farmlandId = self.farmlandIds[self.fieldIndex]

  -- Populate startDate MultiTextOption with dates from now
  self:fillMonthMultiTextOption(self.startDateSelector, "startDateValues")
  self.selectedStartDateIndex = 1

  -- Populate dueDate MultiTextOption with dates from now till one year
  self:fillMonthMultiTextOption(self.dueDateSelector, "dueDateValues")
  self.selectedDueDateIndex = 1
end

function CreateContractDialog:onClose()
  CreateContractDialog:superClass().onClose(self)
end

function CreateContractDialog:onFarmlandSelectChange(state)
  self.farmlandIndex = state
  self.farmlandId = self.farmlandIds[self.farmlandIndex]
end

function CreateContractDialog:onGroupSelectChange(state)
  self.workTypeIndex = state
  self.workAreaTypeIndex = CustomContract.WORKAREATYPES[self.workTypeIndex].index
end

function CreateContractDialog:onStartDateSelectChange(state)
  self.selectedStartDateIndex = state
end

function CreateContractDialog:onDueDateSelectChange(state)
  self.selectedDueDateIndex = state
end

function CreateContractDialog:onClickVehicleList(list, section, index)
  self:toggleRentableVehicle(index)
  list:reloadData()
end

-- Submit create contract button
function CreateContractDialog:onConfirm(sender)
  if g_client == nil then return end

  self.reward = tonumber(self.rewardInput:getText())
  self.description = self.descriptionInput:getText()

  if self.farmlandId == nil or self.reward == nil or self.workAreaTypeIndex == nil then
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
    templateId        = CustomContract.TEMPLATE.FIELD_WORK,
    farmlandId        = self.farmlandId,
    workAreaTypeIndex = self.workAreaTypeIndex,
    reward            = self.reward,
    description       = self.description or "-",
    startPeriod       = startV.period,
    startDay          = startV.day,
    duePeriod         = dueV.period,
    dueDay            = dueV.day,
    invoiceId         = -1
  }

  g_client:getServerConnection():sendEvent(
    CreateContractEvent.new(contract, self.farmId)
  )

  self:close()
end

function CreateContractDialog:onCancel(sender)
  -- Cleanup form
  self.reward = nil
  self.description = nil
  self.farmlandId = nil
  self.workAreaTypeIndex = nil

  self:close()
end

function CreateContractDialog:fillMonthMultiTextOption(multiTextOption, valuesFieldName)
  local texts, values = CustomUtils:buildMonthOptionData()

  self[valuesFieldName] = values

  multiTextOption:setTexts(texts)
  multiTextOption:setState(1, true)
end
