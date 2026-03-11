--
-- FS25 Contract and Invoices
--
-- @Author: Racc00n
-- @Version: 1.0.0.0
--

EditContractDialog = {}
local EditContractDialog_mt = Class(EditContractDialog, MessageDialog)
local modDirectory = g_currentModDirectory

function EditContractDialog.register()
  local dialog = EditContractDialog.new()
  g_gui:loadGui(modDirectory .. "gui/dialog/contracts/EditContractDialog.xml", "editContractDialog", dialog)
  EditContractDialog.INSTANCE = dialog
end

function EditContractDialog.new(target, custom_mt)
  local self = MessageDialog.new(target, custom_mt or EditContractDialog_mt)
  self.editContract = nil
  return self
end

function EditContractDialog.show(contract)
  if EditContractDialog.INSTANCE == nil then EditContractDialog.register() end

  local dialog = EditContractDialog.INSTANCE
  dialog.editContract = contract

  g_gui:showDialog("editContractDialog")
end

function EditContractDialog:onCreate()
  EditContractDialog:superClass().onCreate(self)
end

function EditContractDialog:onOpen()
  EditContractDialog:superClass().onOpen(self)

  -- must have a contract to edit
  local contract = self.editContract
  if contract == nil then
    self:close()
    return
  end

  -- Fill work types
  local workTypeTexts = {}
  for _, workType in ipairs(CustomContract.WORKAREATYPES) do
    table.insert(workTypeTexts, workType.name)
  end

  self.workTypeSelector:setTexts(workTypeTexts)

  -- Fill owned farmLandIds
  local farmId = g_currentMission:getFarmId()
  local farmlandIds = g_farmlandManager:getOwnedFarmlandIdsByFarmId(farmId)
  if farmId == nil then
    self:close()
    return
  end

  self.farmlandIds = farmlandIds

  local farmLandTexts = {}
  for _, farmLandId in ipairs(farmlandIds) do
    table.insert(farmLandTexts, string.format(g_i18n:getText("cc_contract_list_field_label"), farmLandId))
  end
  self.fieldSelector:setTexts(farmLandTexts)

  -- Fill date options
  self:fillMonthMultiTextOption(self.startDateSelector, "startDateValues")
  self:fillMonthMultiTextOption(self.dueDateSelector, "dueDateValues")

  self.selectedStartDateIndex = 1
  self.selectedDueDateIndex   = 1

  -- Prefill from contract
  self:prefillFromContract(contract)
end

function EditContractDialog:prefillFromContract(contract)
  -- Farmland -> index (for TRANSPORT, farmlandId is -1 so use 1)
  self.selectedFarmlandIndex = CustomUtils:findIndex(self.farmlandIds, contract.farmlandId) or 1
  self.fieldSelector:setState(self.selectedFarmlandIndex, false)

  -- Worktype (for TRANSPORT, workAreaTypeIndex is 0; use 1-based state)
  local workState = (contract.workAreaTypeIndex and contract.workAreaTypeIndex > 0) and contract.workAreaTypeIndex or 1
  self.workTypeSelector:setState(workState, false)

  -- Inputs
  self.rewardInput:setText(tostring(contract.reward or ""))
  self.descriptionInput:setText(contract.description or "-")
end

function EditContractDialog:onFarmlandSelectChange(state)
  self.selectedFarmlandIndex = state
end

function EditContractDialog:onWorkTypeSelectChange(state)
  self.selectedWorkTypeIndex = state
end

function EditContractDialog:onStartDateSelectChange(state)
  self.selectedStartDateIndex = state
end

function EditContractDialog:onDueDateSelectChange(state)
  self.selectedDueDateIndex = state
end

-- XML onClick handlers
function EditContractDialog:onConfirm(sender)
  if g_client == nil then return end

  local old = self.editContract
  if old == nil then return end

  local farmLandId = self.farmlandIds[self.selectedFarmlandIndex or 0]
  local reward = tonumber(self.rewardInput:getText())
  local description = self.descriptionInput:getText()

  local index = self.selectedWorkTypeIndex or 1
  local workAreaTypeIndex = CustomContract.WORKAREATYPES[index].index

  if farmLandId == nil or reward == nil or index == nil then
    InfoDialog.show(g_i18n:getText("cc_dialog_create_validation_fields"))
    return
  end

  local startIdx = self.selectedStartDateIndex or 1
  local dueIdx   = self.selectedDueDateIndex or 1

  local startV   = self.startDateValues[startIdx]
  local dueV     = self.dueDateValues[dueIdx]

  if startV == nil or dueV == nil then
    InfoDialog.show(g_i18n:getText("cc_dialog_create_validation_fields_due_date"))
    return
  end

  if dueIdx < startIdx then
    InfoDialog.show(g_i18n:getText("cc_dialog_create_validation_fields_start_date"))
    return
  end

  local updated = {
    farmlandId        = farmLandId,
    workAreaTypeIndex = workAreaTypeIndex,
    reward            = reward,
    description       = description or "-",
    startPeriod       = startV.period,
    startDay          = startV.day,
    duePeriod         = dueV.period,
    dueDay            = dueV.day
  }

  local farmId = g_currentMission:getFarmId()

  g_client:getServerConnection():sendEvent(
    EditContractEvent.new(self.editContract.id, updated, farmId)
  )

  self:close()
end

function EditContractDialog:onCancel(sender)
  self:close()
end

function EditContractDialog:fillMonthMultiTextOption(multiTextOption, valuesFieldName)
  local texts, values = CustomUtils:buildMonthOptionData()

  self[valuesFieldName] = values

  multiTextOption:setTexts(texts)
  multiTextOption:setState(1, true)
end
