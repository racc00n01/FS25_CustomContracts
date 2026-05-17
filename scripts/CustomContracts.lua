--
-- FS25 Contract and Invoices
--
-- @Author: Racc00n
-- @Version: 1.0.0.0
--

CustomContracts = {}
CustomContracts.dir = g_currentModDirectory
CustomContracts.modName = g_currentModName
CustomContracts.SaveKey = "CustomContracts"

function CustomContracts:loadMap()
  g_currentMission.CustomContracts = self

  MessageType.CUSTOM_CONTRACTS_UPDATED = nextMessageTypeId()
  MessageType.INVOICES_UPDATED = nextMessageTypeId()
  MessageType.NOTIFICATIONS_UPDATED = nextMessageTypeId()
  MessageType.FARM_ACCESS_UPDATED = nextMessageTypeId()
  MessageType.PLAYER_CONNECTED = nextMessageTypeId()

  g_gui:loadProfiles(CustomContracts.dir .. "gui/guiProfiles.xml")

  CreateContractDialog.register()
  CreateTransportContractDialog.register()
  CreateVehicleTransportContractDialog.register()
  PickDestinationMapDialog.register()
  EditFieldWorkContractDialog.register()
  EditTransportContractDialog.register()
  CreateInvoiceDialog.register()
  AddInvoiceLineDialog.register()
  DetailInvoiceDialog.register()
  EditInvoiceDialog.register()

  self.ContractManager = CustomContractManager:new()
  self.FarmAccessManager = FarmAccessManager:new()
  self.InvoiceManager = InvoiceManager:new()
  self.NotificationManager = NotificationManager:new()

  self.lastPeriod = g_currentMission.environment.currentPeriod - 1
  self.currentPeriod = g_currentMission.environment.currentPeriod
  self.currentDay = g_currentMission.environment.currentDay

  g_messageCenter:publish(MessageType.CUSTOM_CONTRACTS_UPDATED)
  g_messageCenter:publish(MessageType.INVOICES_UPDATED)
  g_messageCenter:publish(MessageType.NOTIFICATIONS_UPDATED)

  self:loadFromXmlFile()

  CCDedicatedMenu.setupGui()
end

function CustomContracts:loadFromXmlFile()
  if (not g_currentMission:getIsServer()) then return end

  local savegameFolderPath = g_currentMission.missionInfo.savegameDirectory;
  if savegameFolderPath == nil then
    savegameFolderPath = ('%ssavegame%d'):format(getUserProfileAppPath(), g_currentMission.missionInfo.savegameIndex)
  end
  savegameFolderPath = savegameFolderPath .. "/"

  if fileExists(savegameFolderPath .. CustomContracts.SaveKey .. ".xml") then
    local xmlFile = loadXMLFile(CustomContracts.SaveKey, savegameFolderPath .. CustomContracts.SaveKey .. ".xml");
    g_currentMission.CustomContracts.ContractManager:loadFromXmlFile(xmlFile)
    g_currentMission.CustomContracts.FarmAccessManager:loadFromXmlFile(xmlFile)
    g_currentMission.CustomContracts.InvoiceManager:loadFromXmlFile(xmlFile)
    g_currentMission.CustomContracts.NotificationManager:loadFromXmlFile(xmlFile)

    delete(xmlFile)
  end
end

function CustomContracts:saveToXmlFile()
  if (not g_currentMission:getIsServer()) then return end

  local savegameFolderPath = g_currentMission.missionInfo.savegameDirectory;
  if savegameFolderPath == nil then
    savegameFolderPath = ('%ssavegame%d'):format(getUserProfileAppPath(), g_currentMission.missionInfo.savegameIndex)
  end
  savegameFolderPath = savegameFolderPath .. "/"

  local xmlFile = createXMLFile(CustomContracts.SaveKey, savegameFolderPath .. CustomContracts.SaveKey .. ".xml",
    CustomContracts.SaveKey)

  g_currentMission.CustomContracts.ContractManager:saveToXmlFile(xmlFile)
  g_currentMission.CustomContracts.FarmAccessManager:saveToXmlFile(xmlFile)
  g_currentMission.CustomContracts.InvoiceManager:saveToXmlFile(xmlFile)
  g_currentMission.CustomContracts.NotificationManager:saveToXmlFile(xmlFile)

  saveXMLFile(xmlFile)
  delete(xmlFile)
end

function CustomContracts:sendInitialClientState(connection, user, farm)
  connection:sendEvent(InitialClientStateEvent:new())
end

function CustomContracts:playerFarmChanged()
  g_messageCenter:publish(MessageType.CUSTOM_CONTRACTS_UPDATED)
  g_messageCenter:publish(MessageType.INVOICES_UPDATED)
  g_messageCenter:publish(MessageType.NOTIFICATIONS_UPDATED)
end

function CustomContracts:hourChanged()
  g_currentMission.CustomContracts.ContractManager:syncContracts()
  g_currentMission.CustomContracts.InvoiceManager:syncInvoices()
  g_currentMission.CustomContracts.NotificationManager:syncNotifications()

  local period = g_currentMission.environment.currentPeriod
  if period ~= g_currentMission.CustomContracts.currentPeriod then
    g_currentMission.CustomContracts:onPeriodChanged()
    return
  end

  local day = g_currentMission.environment.currentDay
  if day ~= g_currentMission.CustomContracts.currentDay then
    g_currentMission.CustomContracts:onDayChanged()
    return
  end
end

function CustomContracts:onPeriodChanged()
  g_currentMission.CustomContracts.lastPeriod = g_currentMission.CustomContracts.currentPeriod
  g_currentMission.CustomContracts.currentPeriod = g_currentMission.environment.currentPeriod
  g_currentMission.CustomContracts.currentDay = g_currentMission.environment.currentDay

  g_currentMission.CustomContracts.ContractManager:updateExpiredContracts()
end

function CustomContracts:onDayChanged()
  g_currentMission.CustomContracts.currentDay = g_currentMission.environment.currentDay

  g_currentMission.CustomContracts.ContractManager:updateExpiredContracts()
  -- TODO: Add function for expired invoices
end

function CustomContracts.getIsAccessibleAtWorldPosition(self, superFunc, farmId, x, z, workAreaType)
  -- base game first
  local isAccessible, landOwner, landValid = superFunc(self, farmId, x, z, workAreaType)
  if isAccessible then
    return true, landOwner, landValid
  end

  -- landOwner is the farmId owning that farmland at (x,z)
  if landOwner == nil or landOwner == FarmlandManager.NO_OWNER_FARM_ID then
    return false, landOwner, landValid
  end

  -- Use our farm access manager to provide dynamic access grants.
  local farmAccessManager = g_currentMission.CustomContracts.FarmAccessManager
  if farmAccessManager ~= nil then
    if farmAccessManager:getFarmAccessFieldWorkByFarmId(farmId, landOwner, x, z, workAreaType, self) then
      return true, landOwner, true
    end
  end

  return false, landOwner, landValid
end

-- From FieldRename mod
local orginalOnLoadMapFinished = InGameMenuMapFrame.onLoadMapFinished
InGameMenuMapFrame.onLoadMapFinished = function(self)
  orginalOnLoadMapFinished(self)

  CustomContracts.mapFrame = self

  table.insert(self.contextActions, {
    title = g_i18n:getText("cc_map_btn"),
    callback = function(frame)
      CustomContracts.onClickCreateContract(frame)
      return self
    end,
    isActive = false
  })
  RENAME_ACTION_INDEX = #self.contextActions
end

-- From FieldRename mod
local originalSetMapInputContext = InGameMenuMapFrame.setMapInputContext
InGameMenuMapFrame.setMapInputContext = function(self, canEnter, canReset, canSellVehicle, canVisit, canSetMarker,
                                                 removeMarker, canBuy, canSell, canManage)
  -- Call original
  originalSetMapInputContext(self, canEnter, canReset, canSellVehicle, canVisit, canSetMarker, removeMarker, canBuy,
    canSell, canManage)

  -- Enable rename when we can sell (i.e., player owns the farmland)
  -- canSell is true when the player owns the farmland and has farmManager permission
  if RENAME_ACTION_INDEX and self.contextActions and self.contextActions[RENAME_ACTION_INDEX] then
    self.contextActions[RENAME_ACTION_INDEX].isActive = canSell
  end
end

-- Function to prepare and open the CreateContractDialog
function CustomContracts.onClickCreateContract(frame)
  if frame == nil then
    return
  end

  local farmland = frame.selectedFarmland
  if farmland == nil then
    return
  end

  local fieldId = farmland.id

  -- Store the selected fieldId in the client session so we can retrieve it when opening the createContractDialog
  CustomContracts.uiState = CustomContracts.uiState or {}
  CustomContracts.uiState.prefilledFieldId = fieldId

  local farmId = g_currentMission:getFarmId()
  local cachedInventory = FarmInventoryHelper.retrieveFarmInventory(farmId)

  local options = {
    g_i18n:getText("cc_dialog_template_field_work"),
    g_i18n:getText("cc_dialog_template_transport"),
    g_i18n:getText("cc_dialog_template_transport_vehicle"),
  }
  local callback = function(templateId)
    if templateId == 1 then
      if g_farmlandManager:getNumOwnedFarmlandIdsByFarmId(g_currentMission:getFarmId()) > 0 then
        CreateContractDialog.show()
      else
        InfoDialog.show(g_i18n:getText("cc_dialog_template_no_farmland"))
      end
    elseif templateId == 2 then
      cachedInventory = FarmInventoryHelper.retrieveFarmInventory(farmId)
      if cachedInventory.list ~= nil and #cachedInventory.list > 0 then
        CreateTransportContractDialog.show(cachedInventory.list)
      else
        InfoDialog.show(g_i18n:getText("cc_dialog_template_no_inventory"))
      end
    elseif templateId == 3 then
      local vehicles = FarmVehicleHelper.retrieveFarmVehicles(farmId)
      if vehicles ~= nil and #vehicles > 0 then
        CreateVehicleTransportContractDialog.show(vehicles)
      else
        InfoDialog.show(g_i18n:getText("cc_dialog_template_no_vehicles"))
      end
    elseif templateId == 4 then
      InfoDialog.show(g_i18n:getText("cc_dialog_template_coming_soon"))
    end
  end

  OptionDialog.show(callback, g_i18n:getText("cc_dialog_template_title"),
    g_i18n:getText("cc_dialog_template_subtitle"), options)
end

function CustomContracts.canFarmAccess(self, superFunc, farmId, object, allowEqualAlways)
  if superFunc(self, farmId, object, allowEqualAlways) then
    return true
  end

  if object == nil or object.getOwnerFarmId == nil or farmId == nil then
    return false
  end

  local ownerFarmId = object:getOwnerFarmId()
  if ownerFarmId == nil
      or ownerFarmId == FarmlandManager.NO_OWNER_FARM_ID
      or ownerFarmId == farmId then
    return false
  end

  local farmAccessManager = g_currentMission.CustomContracts.FarmAccessManager
  if farmAccessManager == nil then
    return false
  end

  local uniqueId = FarmVehicleHelper.getVehicleUniqueId(object)
  if uniqueId == nil then
    return false
  end

  return farmAccessManager:hasVehicleTransportAccess(farmId, ownerFarmId, uniqueId)
end

function CustomContracts.canFarmAccessOtherId(self, superFunc, farmId, otherFarmId, ...)
  if superFunc(self, farmId, otherFarmId, ...) then
    return true
  end

  if farmId == nil or otherFarmId == nil then
    return false
  end
  if farmId == FarmlandManager.NO_OWNER_FARM_ID or otherFarmId == FarmlandManager.NO_OWNER_FARM_ID then
    return false
  end

  local farmAccessManager = g_currentMission.CustomContracts.FarmAccessManager
  if farmAccessManager == nil then
    return false
  end

  local fillTypeIndex = nil
  local args = { ... }
  for i = 1, #args do
    if type(args[i]) == "number" then
      fillTypeIndex = args[i]
      break
    end
  end

  return farmAccessManager:hasTransportAccess(farmId, otherFarmId, fillTypeIndex)
end

-- Function to resolve the fill type from the arguments
-- @param args The arguments
-- @param argCount The number of arguments
-- @return The fill type index
function CustomContracts.resolveFillTypeFromArgs(args, argCount)
  if g_fillTypeManager == nil then
    return nil
  end

  for i = 2, argCount do
    local value = args[i]
    if type(value) == "number" and value >= 0 and math.floor(value) == value then
      if g_fillTypeManager:getFillTypeByIndex(value) ~= nil then
        return value
      end
    end
  end

  return nil
end

-- Function to track the revenue from selling transport
function CustomContracts.trackTransportSoldRevenue(farmId, fillTypeIndex, soldPrice)
  if not g_currentMission:getIsServer() then
    return
  end
  if farmId == nil or fillTypeIndex == nil or soldPrice == nil or soldPrice <= 0 then
    return
  end

  local contractManager = g_currentMission.CustomContracts.ContractManager
  if contractManager == nil then
    return
  end

  contractManager:registerTransportSale(farmId, fillTypeIndex, soldPrice)
end

function CustomContracts.addFillLevelFromTool(self, superFunc, ...)
  local args = { ... }
  local argCount = select("#", ...)
  local farmId = args[1]
  local fillTypeIndex = CustomContracts.resolveFillTypeFromArgs(args, argCount)

  local beforeBalance = nil
  local farm = nil
  if g_currentMission:getIsServer() and type(farmId) == "number" then
    farm = g_farmManager:getFarmById(farmId)
    if farm ~= nil and farm.getBalance ~= nil then
      beforeBalance = farm:getBalance()
    end
  end

  local r1, r2, r3, r4, r5, r6 = superFunc(self, ...)

  if farm ~= nil and beforeBalance ~= nil and farm.getBalance ~= nil then
    local soldPrice = farm:getBalance() - beforeBalance
    if soldPrice > 0 then
      CustomContracts.trackTransportSoldRevenue(farmId, fillTypeIndex, soldPrice)
    end
  end

  return r1, r2, r3, r4, r5, r6
end

-- function CustomContracts.placeableInfoTrigger_onDraw(self, superFunc)
--   local spec = self.spec_infoTrigger
--   if spec.showInfo then
--     if spec.showAllPlayers then
--       -- unchanged
--     else
--       local myFarmId = g_currentMission:getFarmId()
--       local ownerFarmId = self:getOwnerFarmId()

--       -- Allow owner OR accepted-contract contractor
--       local allow = (ownerFarmId == myFarmId)
--       if not allow then
--         allow = g_currentMission.accessHandler:canFarmAccessOtherId(myFarmId, ownerFarmId)
--       end

--       if not allow then
--         return
--       end
--     end
--   end

--   return superFunc(self)
-- end

-- function CustomContracts.canPlayerAccess(self, superFunc, object, ...)
--   -- Base game first
--   if superFunc(self, object, ...) then
--     return true
--   end

--   if object == nil or object.getOwnerFarmId == nil then
--     return false
--   end

--   local ownerFarmId = object:getOwnerFarmId()
--   if ownerFarmId == nil then
--     return false
--   end

--   local myFarmId = g_currentMission:getFarmId()

--   if g_currentMission.CustomContracts.ContractManager.hasAcceptedContractWithOwner ~= nil then
--     if g_currentMission.CustomContracts.ContractManager:hasAcceptedContractWithOwner(myFarmId, ownerFarmId) then
--       return true
--     end
--   end

--   return false
-- end

-- AccessHandler.canPlayerAccess =
--     Utils.overwrittenFunction(
--       AccessHandler.canPlayerAccess,
--       CustomContracts.canPlayerAccess
--     )

-- PlaceableInfoTrigger.onDraw =
--     Utils.overwrittenFunction(PlaceableInfoTrigger.onDraw, CustomContracts.placeableInfoTrigger_onDraw)

AccessHandler.canFarmAccess =
    Utils.overwrittenFunction(AccessHandler.canFarmAccess, CustomContracts.canFarmAccess)

AccessHandler.canFarmAccessOtherId =
    Utils.overwrittenFunction(AccessHandler.canFarmAccessOtherId, CustomContracts.canFarmAccessOtherId)

if SellingStation ~= nil and SellingStation.addFillLevelFromTool ~= nil then
  SellingStation.addFillLevelFromTool =
      Utils.overwrittenFunction(SellingStation.addFillLevelFromTool, CustomContracts.addFillLevelFromTool)
end

if SellingStation ~= nil and SellingStation.addFillLevelFromVehicle ~= nil then
  SellingStation.addFillLevelFromVehicle =
      Utils.overwrittenFunction(SellingStation.addFillLevelFromVehicle,
        CustomContracts.addFillLevelFromTool)
end

WorkArea.getIsAccessibleAtWorldPosition =
    Utils.overwrittenFunction(WorkArea.getIsAccessibleAtWorldPosition, CustomContracts.getIsAccessibleAtWorldPosition)

FSBaseMission.sendInitialClientState = Utils.appendedFunction(FSBaseMission.sendInitialClientState,
  CustomContracts.sendInitialClientState)
FSBaseMission.saveSavegame = Utils.appendedFunction(FSBaseMission.saveSavegame, CustomContracts.saveToXmlFile)

g_messageCenter:subscribe(MessageType.HOUR_CHANGED, CustomContracts.hourChanged)
g_messageCenter:subscribe(MessageType.PLAYER_FARM_CHANGED, CustomContracts.playerFarmChanged)

addModEventListener(CustomContracts)
