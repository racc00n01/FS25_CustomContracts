--
-- Create contract dialog for Transport template: select product from inventory,
-- amount, destination, reward; then create.
--

CreateTransportContractDialog = {}
local CreateTransportContractDialog_mt = Class(CreateTransportContractDialog, MessageDialog)
local modDirectory = g_currentModDirectory

function CreateTransportContractDialog.register()
  local dialog = CreateTransportContractDialog.new()
  g_gui:loadGui(modDirectory .. "gui/dialog/contracts/CreateTransportContractDialog.xml", "createTransportContractDialog",
    dialog)
  CreateTransportContractDialog.INSTANCE = dialog
end

--- @param inventoryList table array of { fillTypeIndex, title, amount, hudOverlayFilename } from FarmInventoryHelper
function CreateTransportContractDialog.show(inventoryList)
  if CreateTransportContractDialog.INSTANCE == nil then
    CreateTransportContractDialog.register()
  end
  local dialog = CreateTransportContractDialog.INSTANCE
  dialog.pendingInventoryList = inventoryList or {}
  g_gui:showDialog("createTransportContractDialog")
end

function CreateTransportContractDialog.new(target, custom_mt)
  local self = MessageDialog.new(target, custom_mt or CreateTransportContractDialog_mt)
  self.pendingInventoryList = {}
  self.inventoryData = {}
  self.inventoryListRenderer = InventoryListRenderer.new()
  self.selectedIndex = nil
  self.selectedItem = nil
  self.destinationOptions = {}
  return self
end

function CreateTransportContractDialog:onCreate()
  CreateTransportContractDialog:superClass().onCreate(self)
end

function CreateTransportContractDialog:onOpen()
  CreateTransportContractDialog:superClass().onOpen(self)
  self.inventoryData = self.pendingInventoryList
  self.pendingInventoryList = {}
  self.selectedIndex = nil
  self.selectedItem = nil

  self.inventoryListRenderer:setData(self.inventoryData)
  self.inventoryList:setDataSource(self.inventoryListRenderer)
  self.inventoryList:setDelegate(self.inventoryListRenderer)
  self.inventoryList:reloadData()
  self.inventoryListRenderer.indexChangedCallback = function(index)
    self.selectedIndex = index
    self.selectedItem = self.inventoryData[index]
  end

  -- Destination placeholder (e.g. sell points / select on map later)
  self.destinationOptions = { g_i18n:getText("cc_dialog_transport_destination_placeholder") }
  self.destinationSelector:setTexts(self.destinationOptions)
  self.destinationSelector:setState(1, false)

  self.amountInput:setText("")
  self.rewardInput:setText("")
end

function CreateTransportContractDialog:onClose()
  CreateTransportContractDialog:superClass().onClose(self)
end

function CreateTransportContractDialog:onDestinationChange(state)
  -- TODO: when destination picker is implemented (sell points / map), update selection
end

function CreateTransportContractDialog:onEnterPressed()
  -- no-op
end

function CreateTransportContractDialog:onTextChanged()
  -- no-op
end

function CreateTransportContractDialog:onConfirm()
  if g_client == nil then return end

  self.selectedItem = self.inventoryData[self.selectedIndex]

  if self.selectedItem == nil then
    InfoDialog.show(g_i18n:getText("cc_dialog_transport_validation_select_product"))
    return
  end

  local amount = tonumber(self.amountInput:getText())
  local reward = tonumber(self.rewardInput:getText())

  if amount == nil or amount <= 0 or amount > self.selectedItem.amount then
    InfoDialog.show(g_i18n:getText("cc_dialog_transport_validation_amount"))
    return
  end
  if reward == nil or reward < 0 then
    InfoDialog.show(g_i18n:getText("cc_dialog_create_validation_fields"))
    return
  end

  local curPeriod, curDay, dpp = CustomUtils.getCurrentPeriodDay()
  local duePeriod = curPeriod
  local dueDay = math.min(curDay + 1, dpp)
  if dueDay <= curDay then
    duePeriod = curPeriod + 1
    dueDay = 1
  end

  local contract = {
    templateId        = CustomContract.TEMPLATE.TRANSPORT,
    farmlandId        = -1,
    workAreaTypeIndex = 0,
    fillTypeIndex     = self.selectedItem.fillTypeIndex,
    transportAmount   = amount,
    destinationId     = 0,
    reward            = reward,
    description       = "-",
    startPeriod       = curPeriod,
    startDay          = curDay,
    duePeriod         = duePeriod,
    dueDay            = dueDay,
    invoiceId         = -1
  }

  g_client:getServerConnection():sendEvent(CreateContractEvent.new(contract, g_currentMission:getFarmId()))

  self:close()
end

function CreateTransportContractDialog:onCancel()
  self.selectedIndex = nil
  self.selectedItem = nil
  self:close()
end
