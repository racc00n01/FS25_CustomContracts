--
-- Create contract dialog for Transport template: select product from inventory,
-- amount, destination, reward; then create.
-- Destination can be picked on the map (world X,Z) using the same picker as AI jobs.
--

CreateTransportContractDialog = {}
local CreateTransportContractDialog_mt = Class(CreateTransportContractDialog, MessageDialog)
local modDirectory = g_currentModDirectory

-- destinationId value meaning "use map coordinates (destinationX, destinationZ)"
CreateTransportContractDialog.DESTINATION_MAP_POSITION = -1

function CreateTransportContractDialog.register()
  local dialog = CreateTransportContractDialog.new()
  g_gui:loadGui(modDirectory .. "gui/dialog/contracts/CreateTransportContractDialog.xml", "createTransportContractDialog",
    dialog)
  CreateTransportContractDialog.INSTANCE = dialog
end

--- @param inventoryList table array of { fillTypeIndex, title, amount, hudOverlayFilename } from FarmInventoryHelper
--- @param options table|nil optional { savedState, destinationX, destinationZ } when reopening after map pick
function CreateTransportContractDialog.show(inventoryList, options)
  if CreateTransportContractDialog.INSTANCE == nil then
    CreateTransportContractDialog.register()
  end
  local dialog = CreateTransportContractDialog.INSTANCE
  dialog.pendingInventoryList = inventoryList or {}
  dialog.pendingOptions = options
  g_gui:showDialog("createTransportContractDialog")
end

function CreateTransportContractDialog.new(target, custom_mt)
  local self = MessageDialog.new(target, custom_mt or CreateTransportContractDialog_mt)
  self.pendingInventoryList = {}
  self.pendingOptions = nil
  self.inventoryData = {}
  self.inventoryListRenderer = InventoryListRenderer.new()
  self.selectedIndex = nil
  self.selectedItem = nil
  self.destinationOptions = {}
  self.pickedDestinationX = nil
  self.pickedDestinationZ = nil
  return self
end

function CreateTransportContractDialog:onCreate()
  CreateTransportContractDialog:superClass().onCreate(self)
end

function CreateTransportContractDialog:onOpen()
  CreateTransportContractDialog:superClass().onOpen(self)

  local options = self.pendingOptions
  self.pendingOptions = nil

  if options and options.savedState then
    local s = options.savedState
    self.inventoryData = s.inventoryData or self.pendingInventoryList
    self.selectedIndex = s.selectedIndex
    self.selectedItem = self.inventoryData[self.selectedIndex]
    self.pickedDestinationX = options.destinationX
    self.pickedDestinationZ = options.destinationZ
    self.amountInput:setText(s.amountText or "")
    self.rewardInput:setText(s.rewardText or "")
  else
    self.inventoryData = self.pendingInventoryList
    self.pendingInventoryList = {}
    self.selectedIndex = nil
    self.selectedItem = nil
    self.pickedDestinationX = options and options.destinationX
    self.pickedDestinationZ = options and options.destinationZ
    self.amountInput:setText("")
    self.rewardInput:setText("")
  end

  self.inventoryListRenderer:setData(self.inventoryData)
  self.inventoryList:setDataSource(self.inventoryListRenderer)
  self.inventoryList:setDelegate(self.inventoryListRenderer)
  self.inventoryList:reloadData()
  self.inventoryListRenderer.indexChangedCallback = function(index)
    self.selectedIndex = index
    self.selectedItem = self.inventoryData[index]
  end

  self:updateDestinationSelector()
end

function CreateTransportContractDialog:onClose()
  CreateTransportContractDialog:superClass().onClose(self)
end

--- Updates the destination button text to "Pick on map..." or "Destination: X, Z".
function CreateTransportContractDialog:updateDestinationSelector()
  local text
  if self.pickedDestinationX ~= nil and self.pickedDestinationZ ~= nil then
    text = string.format(g_i18n:getText("cc_dialog_transport_destination_picked"), self.pickedDestinationX,
      self.pickedDestinationZ)
  else
    text = g_i18n:getText("cc_dialog_transport_destination_pick_map")
  end
  self.destinationText:setText(text)
end

--- Open the map-in-dialog picker; callback updates destination and refreshes the button text.
function CreateTransportContractDialog:onDestinationClick()
  PickDestinationMapDialog.show(function(success, worldX, worldZ)
    if success and worldX ~= nil and worldZ ~= nil then
      self.pickedDestinationX = worldX
      self.pickedDestinationZ = worldZ
      self:updateDestinationSelector()
      g_inputBinding:setShowMouseCursor(true)
    end
  end)
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

  if self.pickedDestinationX == nil or self.pickedDestinationZ == nil then
    InfoDialog.show(g_i18n:getText("cc_dialog_transport_validation_destination"))
    return
  end

  local curPeriod, curDay, dpp = CustomUtils.getCurrentPeriodDay()
  local duePeriod = curPeriod
  local dueDay = math.min(curDay + 1, dpp)
  if dueDay <= curDay then
    duePeriod = curPeriod + 1
    dueDay = 1
  end

  local farmId = g_currentMission:getFarmId()
  local pickupDesc = FarmInventoryHelper.buildTransportPickupDescription(farmId, self.selectedItem.fillTypeIndex)

  local contract = {
    templateId        = CustomContract.TEMPLATE.TRANSPORT,
    farmlandId        = -1,
    workAreaTypeIndex = 0,
    fillTypeIndex     = self.selectedItem.fillTypeIndex,
    transportAmount   = amount,
    destinationId     = CreateTransportContractDialog.DESTINATION_MAP_POSITION,
    destinationX      = self.pickedDestinationX,
    destinationZ      = self.pickedDestinationZ,
    reward            = reward,
    description       = pickupDesc,
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
