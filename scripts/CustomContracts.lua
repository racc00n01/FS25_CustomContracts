--
-- FS25 CustomContracts
--
-- @Author: Racc00n
-- @Version: 0.0.1.1
--

CustomContracts = {}
CustomContracts.dir = g_currentModDirectory
CustomContracts.modName = g_currentModName
CustomContracts.SaveKey = "CustomContracts"

source(CustomContracts.dir .. "gui/MenuCustomContracts.lua")
source(CustomContracts.dir .. "gui/dialog/contracts/MenuCreateContract.lua")
source(CustomContracts.dir .. "gui/dialog/invoices/DetailInvoiceDialog.lua")
source(CustomContracts.dir .. "gui/dialog/invoices/AddInvoiceLineDialog.lua")
source(CustomContracts.dir .. "gui/dialog/invoices/CreateInvoiceDialog.lua")
source(CustomContracts.dir .. "gui/dialog/contracts/MenuEditContract.lua")
source(CustomContracts.dir .. "gui/renderer/ContractsRenderer.lua")
source(CustomContracts.dir .. "scripts/events/SyncContractsEvent.lua")
source(CustomContracts.dir .. "scripts/events/invoices/SyncInvoicesEvent.lua")
source(CustomContracts.dir .. "scripts/events/InitialClientStateEvent.lua")
source(CustomContracts.dir .. "scripts/util/CustomUtils.lua")

function CustomContracts:loadMap()
  g_currentMission.CustomContracts = self

  MessageType.CUSTOM_CONTRACTS_UPDATED = nextMessageTypeId()
  MessageType.INVOICES_UPDATED = nextMessageTypeId()
  MessageType.PLAYER_CONNECTED = nextMessageTypeId()

  g_gui:loadProfiles(CustomContracts.dir .. "gui/guiProfiles.xml")

  -- Register menu page
  local menuCustomContracts = MenuCustomContracts.new(g_i18n)
  g_gui:loadGui(CustomContracts.dir .. "gui/MenuCustomContracts.xml", "menuCustomContracts", menuCustomContracts, true)

  CustomContracts.addIngameMenuPage(menuCustomContracts, "menuCustomContracts", { 0, 0, 1024, 1024 },
    CustomContracts:makeIsCustomContractsCheckEnabledPredicate(), "pageSettings")

  -- Register Create contract dialog
  local createContractDialog = MenuCreateContract.new(g_i18n)
  g_gui:loadGui(CustomContracts.dir .. "gui/dialog/contracts/MenuCreateContract.xml", "menuCreateContract",
    createContractDialog)

  -- Register Edit contract dialog
  local editContractDialog = MenuEditContract.new(g_i18n)
  g_gui:loadGui(CustomContracts.dir .. "gui/dialog/contracts/MenuEditContract.xml", "menuEditContract",
    editContractDialog)

  -- Register Create invoice dialog
  local createInvoiceDialog = CreateInvoiceDialog.new(g_i18n)
  g_gui:loadGui(CustomContracts.dir .. "gui/dialog/invoices/CreateInvoiceDialog.xml", "createInvoiceDialog",
    createInvoiceDialog)

  -- Register Detail invoice dialog
  local detailInvoiceDialog = DetailInvoiceDialog.new(g_i18n)
  g_gui:loadGui(CustomContracts.dir .. "gui/dialog/invoices/DetailInvoiceDialog.xml", "detailInvoiceDialog",
    detailInvoiceDialog)

  -- Register Add invoice line invoice dialog
  local addInvoiceLineDialog = AddInvoiceLineDialog.new(g_i18n)
  g_gui:loadGui(CustomContracts.dir .. "gui/dialog/invoices/AddInvoiceLineDialog.xml", "addInvoiceLineDialog",
    addInvoiceLineDialog)

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

function CustomContracts:makeIsCustomContractsCheckEnabledPredicate()
  return function() return true end
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

-- from Courseplay
function CustomContracts.addIngameMenuPage(frame, pageName, uvs, predicateFunc, insertAfter)
  local targetPosition = 0

  -- remove all to avoid warnings
  for k, v in pairs({ pageName }) do
    g_inGameMenu.controlIDs[v] = nil
  end

  for i = 1, #g_inGameMenu.pagingElement.elements do
    local child = g_inGameMenu.pagingElement.elements[i]
    if child == g_inGameMenu[insertAfter] then
      targetPosition = i + 1;
      break
    end
  end

  g_inGameMenu[pageName] = frame
  g_inGameMenu.pagingElement:addElement(g_inGameMenu[pageName])

  g_inGameMenu:exposeControlsAsFields(pageName)

  for i = 1, #g_inGameMenu.pagingElement.elements do
    local child = g_inGameMenu.pagingElement.elements[i]
    if child == g_inGameMenu[pageName] then
      table.remove(g_inGameMenu.pagingElement.elements, i)
      table.insert(g_inGameMenu.pagingElement.elements, targetPosition, child)
      break
    end
  end

  for i = 1, #g_inGameMenu.pagingElement.pages do
    local child = g_inGameMenu.pagingElement.pages[i]
    if child.element == g_inGameMenu[pageName] then
      table.remove(g_inGameMenu.pagingElement.pages, i)
      table.insert(g_inGameMenu.pagingElement.pages, targetPosition, child)
      break
    end
  end

  g_inGameMenu.pagingElement:updateAbsolutePosition()
  g_inGameMenu.pagingElement:updatePageMapping()

  g_inGameMenu:registerPage(g_inGameMenu[pageName], nil, predicateFunc)

  local iconFileName = Utils.getFilename('images/menuIcon.dds', CustomContracts.dir)
  g_inGameMenu:addPageTab(g_inGameMenu[pageName], iconFileName, GuiUtils.getUVs(uvs))

  for i = 1, #g_inGameMenu.pageFrames do
    local child = g_inGameMenu.pageFrames[i]
    if child == g_inGameMenu[pageName] then
      table.remove(g_inGameMenu.pageFrames, i)
      table.insert(g_inGameMenu.pageFrames, targetPosition, child)
      break
    end
  end

  g_inGameMenu:rebuildTabList()
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

function CustomContracts.canFarmAccessOtherId(self, superFunc, farmId, otherFarmId, ...)
  -- base game first
  if superFunc(self, farmId, otherFarmId, ...) then
    return true
  end

  -- ignore nonsense ids
  if farmId == nil or otherFarmId == nil then
    return false
  end
  if farmId == FarmlandManager.NO_OWNER_FARM_ID or otherFarmId == FarmlandManager.NO_OWNER_FARM_ID then
    return false
  end

  -- custom-contract exception
  if g_currentMission.CustomContracts.ContractManager.hasAcceptedContractWithOwner ~= nil then
    if g_currentMission.CustomContracts.ContractManager:hasAcceptedContractWithOwner(farmId, otherFarmId) then
      return true
    end
  end

  return false
end

function CustomContracts.placeableInfoTrigger_onDraw(self, superFunc)
  local spec = self.spec_infoTrigger
  if spec.showInfo then
    if spec.showAllPlayers then
      -- unchanged
    else
      local myFarmId = g_currentMission:getFarmId()
      local ownerFarmId = self:getOwnerFarmId()

      -- Allow owner OR accepted-contract contractor
      local allow = (ownerFarmId == myFarmId)
      if not allow then
        allow = g_currentMission.accessHandler:canFarmAccessOtherId(myFarmId, ownerFarmId)
      end

      if not allow then
        return
      end
    end
  end

  return superFunc(self)
end

function CustomContracts.canPlayerAccess(self, superFunc, object, ...)
  -- Base game first
  if superFunc(self, object, ...) then
    return true
  end

  if object == nil or object.getOwnerFarmId == nil then
    return false
  end

  local ownerFarmId = object:getOwnerFarmId()
  if ownerFarmId == nil then
    return false
  end

  local myFarmId = g_currentMission:getFarmId()

  if g_currentMission.CustomContracts.ContractManager.hasAcceptedContractWithOwner ~= nil then
    if g_currentMission.CustomContracts.ContractManager:hasAcceptedContractWithOwner(myFarmId, ownerFarmId) then
      return true
    end
  end

  return false
end

AccessHandler.canPlayerAccess =
    Utils.overwrittenFunction(
      AccessHandler.canPlayerAccess,
      CustomContracts.canPlayerAccess
    )

PlaceableInfoTrigger.onDraw =
    Utils.overwrittenFunction(PlaceableInfoTrigger.onDraw, CustomContracts.placeableInfoTrigger_onDraw)

AccessHandler.canFarmAccessOtherId =
    Utils.overwrittenFunction(AccessHandler.canFarmAccessOtherId, CustomContracts.canFarmAccessOtherId)

WorkArea.getIsAccessibleAtWorldPosition =
    Utils.overwrittenFunction(WorkArea.getIsAccessibleAtWorldPosition, CustomContracts.getIsAccessibleAtWorldPosition)

FSBaseMission.sendInitialClientState = Utils.appendedFunction(FSBaseMission.sendInitialClientState,
  CustomContracts.sendInitialClientState)
FSBaseMission.saveSavegame = Utils.appendedFunction(FSBaseMission.saveSavegame, CustomContracts.saveToXmlFile)

g_messageCenter:subscribe(MessageType.HOUR_CHANGED, CustomContracts.hourChanged)
g_messageCenter:subscribe(MessageType.PLAYER_FARM_CHANGED, CustomContracts.playerFarmChanged)

addModEventListener(CustomContracts)
