--
-- Create contract dialog for vehicle/equipment transport.
--

CreateVehicleTransportContractDialog = {}
local CreateVehicleTransportContractDialog_mt = Class(CreateVehicleTransportContractDialog, MessageDialog)
local modDirectory = g_currentModDirectory

CreateVehicleTransportContractDialog.DESTINATION_MAP_POSITION = -1

function CreateVehicleTransportContractDialog.register()
  local dialog = CreateVehicleTransportContractDialog.new()
  g_gui:loadGui(
    modDirectory .. "gui/dialog/contracts/CreateVehicleTransportContractDialog.xml",
    "createVehicleTransportContractDialog",
    dialog
  )
  CreateVehicleTransportContractDialog.INSTANCE = dialog
end

function CreateVehicleTransportContractDialog.show(vehicleList, options)
  if CreateVehicleTransportContractDialog.INSTANCE == nil then
    CreateVehicleTransportContractDialog.register()
  end
  local dialog = CreateVehicleTransportContractDialog.INSTANCE
  dialog.pendingVehicleList = vehicleList or {}
  dialog.pendingOptions = options
  g_gui:showDialog("createVehicleTransportContractDialog")
end

function CreateVehicleTransportContractDialog.new(target, custom_mt)
  local self = MessageDialog.new(target, custom_mt or CreateVehicleTransportContractDialog_mt)
  self.pendingVehicleList = {}
  self.pendingOptions = nil
  self.vehicleData = {}
  self.vehicleListRenderer = VehicleListRenderer.new()
  self.pickedDestinationX = nil
  self.pickedDestinationZ = nil
  return self
end

function CreateVehicleTransportContractDialog:onCreate()
  CreateVehicleTransportContractDialog:superClass().onCreate(self)
end

function CreateVehicleTransportContractDialog:onOpen()
  CreateVehicleTransportContractDialog:superClass().onOpen(self)

  local options = self.pendingOptions
  self.pendingOptions = nil

  if options and options.savedState then
    local s = options.savedState
    self.vehicleData = s.vehicleData or self.pendingVehicleList
    self.vehicleListRenderer.selectedUniqueIds = s.selectedUniqueIds or {}
    self.pickedDestinationX = options.destinationX
    self.pickedDestinationZ = options.destinationZ
    self.rewardInput:setText(s.rewardText or "")
  else
    self.vehicleData = self.pendingVehicleList
    self.pendingVehicleList = {}
    self.vehicleListRenderer:clearSelection()
    self.pickedDestinationX = options and options.destinationX
    self.pickedDestinationZ = options and options.destinationZ
    self.rewardInput:setText("")
  end

  self.vehicleListRenderer:setData(self.vehicleData)
  self.vehicleList:setDataSource(self.vehicleListRenderer)
  self.vehicleList:setDelegate(self.vehicleListRenderer)
  self.vehicleListRenderer.selectionChangedCallback = function()
    self:updateVehicleSelectionCount()
  end

  self:updateDestinationSelector()
  self:updateVehicleSelectionCount()
  self.vehicleListRenderer:refreshList(self.vehicleList)
end

function CreateVehicleTransportContractDialog:updateVehicleSelectionCount()
  if self.vehicleSelectionCount == nil then
    return
  end
  local count = self.vehicleListRenderer:getSelectedCount()
  self.vehicleSelectionCount:setText(string.format(
    g_i18n:getText("cc_dialog_vehicle_transport_selection_count"),
    count
  ))
end

function CreateVehicleTransportContractDialog:onClose()
  CreateVehicleTransportContractDialog:superClass().onClose(self)
end

function CreateVehicleTransportContractDialog:updateDestinationSelector()
  local text
  if self.pickedDestinationX ~= nil and self.pickedDestinationZ ~= nil then
    text = string.format(
      g_i18n:getText("cc_dialog_transport_destination_picked"),
      self.pickedDestinationX,
      self.pickedDestinationZ
    )
  else
    text = g_i18n:getText("cc_dialog_transport_destination_pick_map")
  end
  self.destinationText:setText(text)
end

function CreateVehicleTransportContractDialog:onDestinationClick()
  PickDestinationMapDialog.show(function(success, worldX, worldZ)
    if success and worldX ~= nil and worldZ ~= nil then
      self.pickedDestinationX = worldX
      self.pickedDestinationZ = worldZ
      self:updateDestinationSelector()
      g_inputBinding:setShowMouseCursor(true)
    end
  end)
end

function CreateVehicleTransportContractDialog:onEnterPressed()
end

function CreateVehicleTransportContractDialog:onTextChanged()
end

function CreateVehicleTransportContractDialog:onConfirm()
  if g_client == nil then
    return
  end

  local selected = self.vehicleListRenderer:getSelectedEntries()
  if selected == nil or #selected == 0 then
    InfoDialog.show(g_i18n:getText("cc_dialog_vehicle_transport_validation_select"))
    return
  end

  local reward = tonumber(self.rewardInput:getText())
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

  local contract = {
    templateId              = CustomContract.TEMPLATE.VEHICLE_TRANSPORT,
    farmlandId              = -1,
    workAreaTypeIndex       = 0,
    destinationId           = CreateVehicleTransportContractDialog.DESTINATION_MAP_POSITION,
    destinationX            = self.pickedDestinationX,
    destinationZ            = self.pickedDestinationZ,
    reward                  = reward,
    description             = FarmVehicleHelper.buildVehicleDescription(selected),
    transportVehicleEntries = CustomContract.copyVehicleEntries(selected),
    startPeriod             = curPeriod,
    startDay                = curDay,
    duePeriod               = duePeriod,
    dueDay                  = dueDay,
    invoiceId               = -1
  }

  g_client:getServerConnection():sendEvent(CreateContractEvent.new(contract, g_currentMission:getFarmId()))
  self:close()
end

function CreateVehicleTransportContractDialog:onCancel()
  self.vehicleListRenderer:clearSelection()
  self:close()
end
