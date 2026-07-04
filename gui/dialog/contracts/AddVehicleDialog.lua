--
-- Add Vehicle Dialog for lending your own equipment to a contract
-- This dialog is used to select vehicles from the player's own vehicles to add to a contract.
--

AddVehicleDialog = {}
local AddVehicleDialog_mt = Class(AddVehicleDialog, MessageDialog)
local modDirectory = g_currentModDirectory

function AddVehicleDialog.register()
  local dialog = AddVehicleDialog.new()
  g_gui:loadGui(
    modDirectory .. "gui/dialog/contracts/AddVehicleDialog.xml",
    "addVehicleDialog",
    dialog
  )
  AddVehicleDialog.INSTANCE = dialog
end

function AddVehicleDialog.show(vehicleList, callback)
  if AddVehicleDialog.INSTANCE == nil then
    AddVehicleDialog.register()
  end
  local dialog = AddVehicleDialog.INSTANCE
  dialog.pendingVehicleList = vehicleList or {}
  dialog.pendingCallback = callback
  g_gui:showDialog("addVehicleDialog")
end

function AddVehicleDialog.new(target, custom_mt)
  local self = MessageDialog.new(target, custom_mt or AddVehicleDialog_mt)
  self.pendingCallback = nil
  self.pendingVehicleList = {}
  self.vehicleData = {}
  self.vehicleListRenderer = VehicleListRenderer.new()
  return self
end

function AddVehicleDialog:onCreate()
  AddVehicleDialog:superClass().onCreate(self)
end

function AddVehicleDialog:onOpen()
  AddVehicleDialog:superClass().onOpen(self)

  self.vehicleData = self.pendingVehicleList
  self.pendingVehicleList = nil

  self.vehicleListRenderer:setData(self.vehicleData)
  self.vehicleList:setDataSource(self.vehicleListRenderer)
  self.vehicleList:setDelegate(self.vehicleListRenderer)
  self.vehicleListRenderer.selectionChangedCallback = function()
    self:updateVehicleSelectionCount()
  end

  self:updateVehicleSelectionCount()
  self.vehicleListRenderer:refreshList(self.vehicleList)
end

function AddVehicleDialog:updateVehicleSelectionCount()
  if self.vehicleSelectionCount == nil then
    return
  end
  local count = self.vehicleListRenderer:getSelectedCount()
  self.vehicleSelectionCount:setText(string.format(g_i18n:getText("cc_dialog_vehicle_transport_selection_count"), count))
end

function AddVehicleDialog:onClose()
  AddVehicleDialog:superClass().onClose(self)
end

function AddVehicleDialog:onConfirm()
  if g_client == nil then return end

  local selected = self.vehicleListRenderer:getSelectedEntries()
  if selected == nil or #selected == 0 then
    InfoDialog.show(g_i18n:getText("cc_dialog_vehicle_transport_validation_select"))
    return
  end

  if self.pendingCallback then
    self.pendingCallback(selected)
  end
  self:close()
end
