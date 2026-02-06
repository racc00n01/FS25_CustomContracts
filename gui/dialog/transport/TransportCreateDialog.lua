--
-- FS25 CustomContracts
--
-- @Author: Racc00n
-- @Version: 0.0.1.1
--

TransportCreateDialog = {}
local TransportCreateDialog_mt = Class(TransportCreateDialog, MessageDialog)

function TransportCreateDialog.new(target, custom_mt)
  local self = MessageDialog.new(target, custom_mt or TransportCreateDialog_mt)
  return self
end

function TransportCreateDialog:onCreate()
  TransportCreateDialog:superClass().onCreate(self)
end

function TransportCreateDialog:onGuiSetupFinished()
  TransportCreateDialog:superClass().onGuiSetupFinished(self)
end

function TransportCreateDialog:onOpen()
  TransportCreateDialog:superClass().onOpen(self)

  local transport = g_currentMission.CustomContracts.newTransportContract

  -- Retrieve the filltype information
  local ftTitle = "—"
  if transport.fillTypeIndex ~= nil then
    local ft = g_fillTypeManager:getFillTypeByIndex(transport.fillTypeIndex)
    ftTitle = (ft and (ft.title or ft.name)) or tostring(transport.fillTypeIndex)
  end

  local amountText = g_i18n:formatVolume(transport.amount or 0, 0)

  local cc = g_currentMission.CustomContracts
  self.templateId = (cc and cc.selectedCreateTemplateId) or "FIELD_WORK"

  -- now apply + setup
  self:fillMonthMultiTextOption(self.startDateSelector, "startDateValues")
  self:fillMonthMultiTextOption(self.dueDateSelector, "dueDateValues")

  self.productName:setText(ftTitle)
  self.productAmount:setText(amountText)

  self.sellPointName:setText(transport.sellPointName)
end

function TransportCreateDialog:onClose()
  TransportCreateDialog:superClass().onClose(self)
end

function TransportCreateDialog:onStartDateSelectChange(state)
  self.selectedStartDateIndex = state
end

function TransportCreateDialog:onDueDateSelectChange(state)
  self.selectedDueDateIndex = state
end

-- XML onClick handlers
function TransportCreateDialog:onConfirm(sender)
  if g_client == nil then return end

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

function TransportCreateDialog:onCancel(sender)
  self:close()
end

function TransportCreateDialog:fillMonthMultiTextOption(multiTextOption, valuesFieldName)
  local texts, values = CustomUtils:buildMonthOptionData()

  self[valuesFieldName] = values

  multiTextOption:setTexts(texts)
  multiTextOption:setState(1, true)
end
