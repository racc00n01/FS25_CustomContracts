--
-- Edit OPEN transport contracts (creator only).
--

EditTransportContractDialog = {}
local EditTransportContractDialog_mt = Class(EditTransportContractDialog, MessageDialog)
local modDirectory = g_currentModDirectory

function EditTransportContractDialog.register()
  local dialog = EditTransportContractDialog.new()
  g_gui:loadGui(modDirectory .. "gui/dialog/contracts/EditTransportContractDialog.xml", "editTransportContractDialog", dialog)
  EditTransportContractDialog.INSTANCE = dialog
end

function EditTransportContractDialog.new(target, custom_mt)
  local self = MessageDialog.new(target, custom_mt or EditTransportContractDialog_mt)
  self.editContract = nil
  self.inventoryListRenderer = InventoryListRenderer.new()
  self.inventoryData = {}
  self.selectedIndex = nil
  self.selectedItem = nil
  self.pickedDestinationX = nil
  self.pickedDestinationZ = nil
  return self
end

function EditTransportContractDialog.show(contract)
  if EditTransportContractDialog.INSTANCE == nil then
    EditTransportContractDialog.register()
  end
  EditTransportContractDialog.INSTANCE.editContract = contract
  g_gui:showDialog("editTransportContractDialog")
end

function EditTransportContractDialog:onCreate()
  EditTransportContractDialog:superClass().onCreate(self)
end

function EditTransportContractDialog:onOpen()
  EditTransportContractDialog:superClass().onOpen(self)

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

  local inv = FarmInventoryHelper.retrieveFarmInventory(farmId)
  self.inventoryData = inv.list or {}

  self.inventoryListRenderer:setData(self.inventoryData)
  self.inventoryList:setDataSource(self.inventoryListRenderer)
  self.inventoryList:setDelegate(self.inventoryListRenderer)
  self.inventoryListRenderer.indexChangedCallback = function(index)
    self.selectedIndex = index
    self.selectedItem = self.inventoryData[index]
  end

  local pickIdx = nil
  if contract.fillTypeIndex ~= nil then
    for i, entry in ipairs(self.inventoryData) do
      if entry.fillTypeIndex == contract.fillTypeIndex then
        pickIdx = i
        break
      end
    end
  end

  self.selectedIndex = pickIdx
  self.selectedItem = pickIdx ~= nil and self.inventoryData[pickIdx] or nil
  self.inventoryList:reloadData()
  if pickIdx ~= nil then
    self.inventoryList:setSelectedIndex(pickIdx)
  end

  self.transportAmountInput:setText(tostring(contract.transportAmount or ""))

  self.pickedDestinationX = contract.destinationX
  self.pickedDestinationZ = contract.destinationZ
  self:updateDestinationSelector()
end

function EditTransportContractDialog:onClose()
  self.editContract = nil
  self.inventoryData = {}
  self.selectedIndex = nil
  self.selectedItem = nil
  self.pickedDestinationX = nil
  self.pickedDestinationZ = nil
  EditTransportContractDialog:superClass().onClose(self)
end

function EditTransportContractDialog:updateDestinationSelector()
  local text
  if self.pickedDestinationX ~= nil and self.pickedDestinationZ ~= nil then
    text = string.format(g_i18n:getText("cc_dialog_transport_destination_picked"), self.pickedDestinationX,
      self.pickedDestinationZ)
  else
    text = g_i18n:getText("cc_dialog_transport_destination_pick_map")
  end
  self.destinationText:setText(text)
end

function EditTransportContractDialog:onDestinationClick()
  PickDestinationMapDialog.show(function(success, worldX, worldZ)
    if success and worldX ~= nil and worldZ ~= nil then
      self.pickedDestinationX = worldX
      self.pickedDestinationZ = worldZ
      self:updateDestinationSelector()
      g_inputBinding:setShowMouseCursor(true)
    end
  end)
end

function EditTransportContractDialog:onStartDateSelectChange(state)
  self.selectedStartDateIndex = state
end

function EditTransportContractDialog:onDueDateSelectChange(state)
  self.selectedDueDateIndex = state
end

function EditTransportContractDialog:onEnterPressed()
end

function EditTransportContractDialog:onTextChanged()
end

function EditTransportContractDialog:onConfirm(sender)
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

  self.selectedItem = self.inventoryData[self.selectedIndex]
  if self.selectedItem == nil then
    InfoDialog.show(g_i18n:getText("cc_dialog_transport_validation_select_product"))
    return
  end

  local amount = tonumber(self.transportAmountInput:getText())
  if amount == nil or amount <= 0 or amount > self.selectedItem.amount then
    InfoDialog.show(g_i18n:getText("cc_dialog_transport_validation_amount"))
    return
  end

  if self.pickedDestinationX == nil or self.pickedDestinationZ == nil then
    InfoDialog.show(g_i18n:getText("cc_dialog_transport_validation_destination"))
    return
  end

  local pickupDesc = FarmInventoryHelper.buildTransportPickupDescription(farmId, self.selectedItem.fillTypeIndex)

  local updated = {
    farmlandId        = -1,
    workAreaTypeIndex = 0,
    reward            = reward,
    description       = pickupDesc,
    startPeriod       = startV.period,
    startDay          = startV.day,
    duePeriod         = dueV.period,
    dueDay            = dueV.day,
    fillTypeIndex     = self.selectedItem.fillTypeIndex,
    transportAmount   = amount,
    destinationId     = CreateTransportContractDialog.DESTINATION_MAP_POSITION,
    destinationX      = self.pickedDestinationX,
    destinationZ      = self.pickedDestinationZ
  }

  g_client:getServerConnection():sendEvent(EditContractEvent.new(old.id, updated, farmId))
  self:close()
end

function EditTransportContractDialog:onCancel(sender)
  self:close()
end
