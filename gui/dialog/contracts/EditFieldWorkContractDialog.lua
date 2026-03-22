--
-- Edit OPEN field-work contracts (creator only).
--

EditFieldWorkContractDialog = {}
local EditFieldWorkContractDialog_mt = Class(EditFieldWorkContractDialog, MessageDialog)
local modDirectory = g_currentModDirectory

function EditFieldWorkContractDialog.register()
  local dialog = EditFieldWorkContractDialog.new()
  g_gui:loadGui(modDirectory .. "gui/dialog/contracts/EditFieldWorkContractDialog.xml", "editFieldWorkContractDialog", dialog)
  EditFieldWorkContractDialog.INSTANCE = dialog
end

function EditFieldWorkContractDialog.new(target, custom_mt)
  local self = MessageDialog.new(target, custom_mt or EditFieldWorkContractDialog_mt)
  self.editContract = nil
  self.farmlandIds = nil
  self.selectedFarmlandIndex = 1
  self.selectedWorkTypeIndex = 1
  return self
end

function EditFieldWorkContractDialog.show(contract)
  if EditFieldWorkContractDialog.INSTANCE == nil then
    EditFieldWorkContractDialog.register()
  end
  EditFieldWorkContractDialog.INSTANCE.editContract = contract
  g_gui:showDialog("editFieldWorkContractDialog")
end

function EditFieldWorkContractDialog:onCreate()
  EditFieldWorkContractDialog:superClass().onCreate(self)
end

function EditFieldWorkContractDialog:onOpen()
  EditFieldWorkContractDialog:superClass().onOpen(self)

  local contract = self.editContract
  if contract == nil then
    self:close()
    return
  end

  local farmId = g_currentMission:getFarmId()
  if farmId == nil then
    self:close()
    return
  end

  self.rewardInput:setText(tostring(contract.reward or ""))
  self.selectedStartDateIndex = CustomUtils:setupMonthOptionOnDialog(self, self.startDateSelector, "startDateValues",
    contract.startPeriod, contract.startDay)
  self.selectedDueDateIndex = CustomUtils:setupMonthOptionOnDialog(self, self.dueDateSelector, "dueDateValues",
    contract.duePeriod, contract.dueDay)

  local farmlandIds = g_farmlandManager:getOwnedFarmlandIdsByFarmId(farmId)
  self.farmlandIds = farmlandIds

  local farmLandTexts = {}
  for _, farmLandId in ipairs(farmlandIds) do
    table.insert(farmLandTexts, string.format(g_i18n:getText("cc_contract_list_field_label"), farmLandId))
  end
  self.fieldSelector:setTexts(farmLandTexts)

  local workTypeTexts = {}
  for _, workType in ipairs(CustomContract.WORKAREATYPES) do
    table.insert(workTypeTexts, workType.name)
  end
  self.workTypeSelector:setTexts(workTypeTexts)

  self.selectedFarmlandIndex = CustomUtils:findIndex(self.farmlandIds, contract.farmlandId) or 1
  self.fieldSelector:setState(self.selectedFarmlandIndex, false)

  local wRow = CustomUtils:findWorkAreaTypeRowIndex(contract.workAreaTypeIndex)
  self.workTypeSelector:setState(wRow, false)
  self.selectedWorkTypeIndex = wRow

  self.descriptionInput:setText(contract.description or "-")
end

function EditFieldWorkContractDialog:onClose()
  self.editContract = nil
  EditFieldWorkContractDialog:superClass().onClose(self)
end

function EditFieldWorkContractDialog:onFarmlandSelectChange(state)
  self.selectedFarmlandIndex = state
end

function EditFieldWorkContractDialog:onWorkTypeSelectChange(state)
  self.selectedWorkTypeIndex = state
end

function EditFieldWorkContractDialog:onStartDateSelectChange(state)
  self.selectedStartDateIndex = state
end

function EditFieldWorkContractDialog:onDueDateSelectChange(state)
  self.selectedDueDateIndex = state
end

function EditFieldWorkContractDialog:onEnterPressed()
end

function EditFieldWorkContractDialog:onTextChanged()
end

function EditFieldWorkContractDialog:onConfirm(sender)
  if g_client == nil then
    return
  end

  local old = self.editContract
  if old == nil then
    return
  end

  local farmId = g_currentMission:getFarmId()
  local startIdx = self.selectedStartDateIndex or 1
  local dueIdx = self.selectedDueDateIndex or 1
  local startV = self.startDateValues[startIdx]
  local dueV = self.dueDateValues[dueIdx]

  if startV == nil or dueV == nil then
    InfoDialog.show(g_i18n:getText("cc_dialog_create_validation_fields_due_date"))
    return
  end

  if dueIdx < startIdx then
    InfoDialog.show(g_i18n:getText("cc_dialog_create_validation_fields_start_date"))
    return
  end

  local reward = tonumber(self.rewardInput:getText())
  if reward == nil or reward < 0 then
    InfoDialog.show(g_i18n:getText("cc_dialog_create_validation_fields"))
    return
  end

  local farmLandId = self.farmlandIds[self.selectedFarmlandIndex or 0]
  local description = self.descriptionInput:getText()
  local index = self.selectedWorkTypeIndex or 1
  local workAreaTypeIndex = CustomContract.WORKAREATYPES[index].index

  if farmLandId == nil or workAreaTypeIndex == nil then
    InfoDialog.show(g_i18n:getText("cc_dialog_create_validation_fields"))
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
    dueDay            = dueV.day,
    fillTypeIndex     = -1,
    transportAmount   = -1,
    destinationId     = -1,
    destinationX      = 0,
    destinationZ      = 0
  }

  g_client:getServerConnection():sendEvent(EditContractEvent.new(old.id, updated, farmId))
  self:close()
end

function EditFieldWorkContractDialog:onCancel(sender)
  self:close()
end
