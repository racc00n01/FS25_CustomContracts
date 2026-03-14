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
  MessageType.PLAYER_CONNECTED = nextMessageTypeId()

  g_gui:loadProfiles(CustomContracts.dir .. "gui/guiProfiles.xml")

  -- Register menu page
  local menuCustomContracts = MenuCustomContracts.new(g_i18n)
  g_gui:loadGui(CustomContracts.dir .. "gui/MenuCustomContracts.xml", "menuCustomContracts", menuCustomContracts, true)

  CustomContracts.addIngameMenuPage(menuCustomContracts, "menuCustomContracts", { 0, 0, 1024, 1024 },
    CustomContracts:makeIsCustomContractsCheckEnabledPredicate(), 2)

  CreateContractDialog.register()
  CreateTransportContractDialog.register()
  PickDestinationMapDialog.register()
  EditContractDialog.register()
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
  self.progressUpdateAccum = 0
end

local PROGRESS_UPDATE_INTERVAL = 2

function CustomContracts:update(dt)
  if not g_currentMission or not g_currentMission.CustomContracts or not g_currentMission.CustomContracts.ContractManager then
    return
  end

  local mgr = g_currentMission.CustomContracts.ContractManager

  if g_client then
    mgr:updateProgressBars()
  end

  self.progressUpdateAccum = (self.progressUpdateAccum or 0) + dt
  if self.progressUpdateAccum < PROGRESS_UPDATE_INTERVAL then
    return
  end

  self.progressUpdateAccum = 0
  for _, contract in pairs(mgr.contracts) do
    if contract.status == CustomContract.STATUS.ACCEPTED and contract.templateId == CustomContract.TEMPLATE.FIELD_WORK then
      mgr:contractProgressFieldCollector(contract.id)
    end
  end
end

function CustomContracts:makeIsCustomContractsCheckEnabledPredicate()
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

function CustomContracts:loadFromXmlFile()
  if (not g_currentMission:getIsServer()) then return end

  local savegameFolderPath = g_currentMission.missionInfo.savegameDirectory
  if savegameFolderPath == nil then
    savegameFolderPath = ('%ssavegame%d'):format(getUserProfileAppPath(), g_currentMission.missionInfo.savegameIndex)
  end
  savegameFolderPath = savegameFolderPath .. "/"

  if fileExists(savegameFolderPath .. CustomContracts.SaveKey .. ".xml") then
    local xmlFile = loadXMLFile(CustomContracts.SaveKey, savegameFolderPath .. CustomContracts.SaveKey .. ".xml")
    g_currentMission.CustomContracts.ContractManager:loadFromXmlFile(xmlFile)
    g_currentMission.CustomContracts.InvoiceManager:loadFromXmlFile(xmlFile)

    delete(xmlFile)
  end
end

function CustomContracts:saveToXmlFile()
  if (not g_currentMission:getIsServer()) then return end

  local savegameFolderPath = g_currentMission.missionInfo.savegameDirectory
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

  if type(insertAfter) == "number" then
    targetPosition = math.max(1, insertAfter)
  else
    for i = 1, #g_inGameMenu.pagingElement.elements do
      local child = g_inGameMenu.pagingElement.elements[i]
      if child == g_inGameMenu[insertAfter] then
        targetPosition = i + 1
        break
      end
    end
  end

  if targetPosition < 1 then
    targetPosition = 1
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
