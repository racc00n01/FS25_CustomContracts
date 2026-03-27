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

local function fixInGameMenu(frame, pageName, uvs, position, predicateFunc)
  local inGameMenu = g_gui.screenControllers[InGameMenu]
  position = position or #inGameMenu.pagingElement.pages + 1

  for k, v in pairs({ pageName }) do
    inGameMenu.controlIDs[v] = nil
  end

  for i = 1, #inGameMenu.pagingElement.elements do
    local child = inGameMenu.pagingElement.elements[i]
    if child == inGameMenu.pageAnimals then
      position = i
      break
    end
  end

  inGameMenu[pageName] = frame
  inGameMenu.pagingElement:addElement(inGameMenu[pageName])

  inGameMenu:exposeControlsAsFields(pageName)

  for i = 1, #inGameMenu.pagingElement.elements do
    local child = inGameMenu.pagingElement.elements[i]
    if child == inGameMenu[pageName] then
      table.remove(inGameMenu.pagingElement.elements, i)
      table.insert(inGameMenu.pagingElement.elements, position, child)
      break
    end
  end

  for i = 1, #inGameMenu.pagingElement.pages do
    local child = inGameMenu.pagingElement.pages[i]
    if child.element == inGameMenu[pageName] then
      table.remove(inGameMenu.pagingElement.pages, i)
      table.insert(inGameMenu.pagingElement.pages, position, child)
      break
    end
  end

  inGameMenu.pagingElement:updateAbsolutePosition()
  inGameMenu.pagingElement:updatePageMapping()

  inGameMenu:registerPage(inGameMenu[pageName], position, predicateFunc)
  inGameMenu:addPageTab(inGameMenu[pageName], CustomContracts.dir .. "images/menuIcon.dds", GuiUtils.getUVs(uvs))

  for i = 1, #inGameMenu.pageFrames do
    local child = inGameMenu.pageFrames[i]
    if child == inGameMenu[pageName] then
      table.remove(inGameMenu.pageFrames, i)
      table.insert(inGameMenu.pageFrames, position, child)
      break
    end
  end

  inGameMenu:rebuildTabList()
end

local function makeIsCustomContractsCheckEnabledPredicate()
  -- Only enable the Custom Contracts page for players that are actually in a farm.
  -- When in spectator mode (no farm or FarmManager.SPECTATOR_FARM_ID), the page
  -- tab will be hidden from the in‑game menu so it cannot appear half off‑screen.
  return function()
    if g_currentMission == nil then
      return false
    end

    local farmId = g_currentMission:getFarmId()
    if farmId == nil or farmId == FarmManager.SPECTATOR_FARM_ID then
      return false
    end

    return true
  end
end

function CustomContracts:loadMap()
  g_currentMission.CustomContracts = self

  MessageType.CUSTOM_CONTRACTS_UPDATED = nextMessageTypeId()
  MessageType.INVOICES_UPDATED = nextMessageTypeId()
  MessageType.PLAYER_CONNECTED = nextMessageTypeId()

  g_gui:loadProfiles(CustomContracts.dir .. "gui/guiProfiles.xml")

  local menuCustomContracts = MenuCustomContracts.new(g_i18n)
  g_gui:loadGui(CustomContracts.dir .. "gui/MenuCustomContracts.xml", "MenuCustomContracts", menuCustomContracts, true)

  fixInGameMenu(menuCustomContracts, "menuCustomContracts", { 0, 0, 1024, 1024 }, 4,
    makeIsCustomContractsCheckEnabledPredicate())

  CreateContractDialog.register()
  CreateTransportContractDialog.register()
  PickDestinationMapDialog.register()
  EditFieldWorkContractDialog.register()
  EditTransportContractDialog.register()
  CreateInvoiceDialog.register()
  AddInvoiceLineDialog.register()
  DetailInvoiceDialog.register()
  EditInvoiceDialog.register()

  menuCustomContracts:initialize()

  self.ContractManager = CustomContractManager:new()
  self.InvoiceManager = InvoiceManager:new()
  self.CustomContractsMenu = menuCustomContracts

  self.lastPeriod = g_currentMission.environment.currentPeriod - 1
  self.currentPeriod = g_currentMission.environment.currentPeriod
  self.currentDay = g_currentMission.environment.currentDay

  g_messageCenter:publish(MessageType.CUSTOM_CONTRACTS_UPDATED)
  g_messageCenter:publish(MessageType.INVOICES_UPDATED)

  self:loadFromXmlFile()
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
    g_currentMission.CustomContracts.InvoiceManager:loadFromXmlFile(xmlFile)

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
  g_currentMission.CustomContracts.InvoiceManager:saveToXmlFile(xmlFile)

  saveXMLFile(xmlFile)
  delete(xmlFile)
end

function CustomContracts:sendInitialClientState(connection, user, farm)
  connection:sendEvent(InitialClientStateEvent:new())
end

function CustomContracts:registerMenu()
  local menu = g_gui.screenControllers[TabbedMenu]
  if menu == nil then
    return
  end

  local frame = MenuCustomContracts.new()
  g_gui:loadGui(
    CustomContracts.dir .. "gui/MenuCustomContracts.xml",
    "MenuCustomContracts",
    frame
  )

  menu:addFrame(frame)
end

function CustomContracts:playerFarmChanged()
  g_messageCenter:publish(MessageType.CUSTOM_CONTRACTS_UPDATED)
  g_messageCenter:publish(MessageType.INVOICES_UPDATED)
end

function CustomContracts:hourChanged()
  g_currentMission.CustomContracts.ContractManager:syncContracts()
  g_currentMission.CustomContracts.InvoiceManager:syncInvoices()

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
  -- TODO: Add function for expired invoices
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

  -- contract exception function
  if g_currentMission.CustomContracts.ContractManager:hasWorkAreaAccessByContract(farmId, landOwner, x, z, workAreaType, self) then
    return true, landOwner, true
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
    -- g_i18n:getText("cc_dialog_template_farmjob"),
    -- g_i18n:getText("cc_dialog_template_custom"),
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
      InfoDialog.show(g_i18n:getText("cc_dialog_template_coming_soon"))
    elseif templateId == 4 then
      InfoDialog.show(g_i18n:getText("cc_dialog_template_coming_soon"))
    end
  end

  OptionDialog.show(callback, g_i18n:getText("cc_dialog_template_title"),
    g_i18n:getText("cc_dialog_template_subtitle"), options)
end

-- function CustomContracts.canFarmAccessOtherId(self, superFunc, farmId, otherFarmId, ...)
--   -- base game first
--   if superFunc(self, farmId, otherFarmId, ...) then
--     return true
--   end

--   -- ignore nonsense ids
--   if farmId == nil or otherFarmId == nil then
--     return false
--   end
--   if farmId == FarmlandManager.NO_OWNER_FARM_ID or otherFarmId == FarmlandManager.NO_OWNER_FARM_ID then
--     return false
--   end

--   -- custom-contract exception
--   if g_currentMission.CustomContracts.ContractManager.hasAcceptedContractWithOwner ~= nil then
--     if g_currentMission.CustomContracts.ContractManager:hasAcceptedContractWithOwner(farmId, otherFarmId) then
--       return true
--     end
--   end

--   return false
-- end

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

-- AccessHandler.canFarmAccessOtherId =
--     Utils.overwrittenFunction(AccessHandler.canFarmAccessOtherId, CustomContracts.canFarmAccessOtherId)

WorkArea.getIsAccessibleAtWorldPosition =
    Utils.overwrittenFunction(WorkArea.getIsAccessibleAtWorldPosition, CustomContracts.getIsAccessibleAtWorldPosition)

FSBaseMission.sendInitialClientState = Utils.appendedFunction(FSBaseMission.sendInitialClientState,
  CustomContracts.sendInitialClientState)
FSBaseMission.saveSavegame = Utils.appendedFunction(FSBaseMission.saveSavegame, CustomContracts.saveToXmlFile)

g_messageCenter:subscribe(MessageType.HOUR_CHANGED, CustomContracts.hourChanged)
g_messageCenter:subscribe(MessageType.PLAYER_FARM_CHANGED, CustomContracts.playerFarmChanged)

addModEventListener(CustomContracts)
