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
source(CustomContracts.dir .. "gui/dialog/MenuCreateContract.lua")
source(CustomContracts.dir .. "gui/dialog/MenuEditContract.lua")
source(CustomContracts.dir .. "gui/ContractsRenderer.lua")
source(CustomContracts.dir .. "scripts/events/SyncContractsEvent.lua")
source(CustomContracts.dir .. "scripts/events/InitialClientStateEvent.lua")
source(CustomContracts.dir .. "scripts/util/CustomUtils.lua")

function CustomContracts:loadMap()
  g_currentMission.CustomContracts = self

  MessageType.CUSTOM_CONTRACTS_UPDATED = nextMessageTypeId()
  MessageType.PLAYER_CONNECTED = nextMessageTypeId()

  g_gui:loadProfiles(CustomContracts.dir .. "gui/guiProfiles.xml")

  -- Register menu page
  local menuCustomContracts = MenuCustomContracts.new(g_i18n)
  g_gui:loadGui(CustomContracts.dir .. "gui/MenuCustomContracts.xml", "menuCustomContracts", menuCustomContracts, true)

  CustomContracts.addIngameMenuPage(menuCustomContracts, "menuCustomContracts", { 0, 0, 1024, 1024 },
    CustomContracts:makeIsCustomContractsCheckEnabledPredicate(), "pageSettings")

  -- Register Create contract dialog
  local createContractDialog = MenuCreateContract.new(g_i18n)
  g_gui:loadGui(CustomContracts.dir .. "gui/dialog/MenuCreateContract.xml", "menuCreateContract", createContractDialog)

  -- Register Edit contract dialog
  local editContractDialog = MenuEditContract.new(g_i18n)
  g_gui:loadGui(CustomContracts.dir .. "gui/dialog/MenuEditContract.xml", "menuEditContract", editContractDialog)

  -- CustomContracts.show("Custom Contracts loaded!", 5000)
  -- local sn = g_currentMission.hud.sideNotification or g_currentMission.hud.sideNotifications
  -- sn:addNotification("Custom Contracts loaded!")

  g_currentMission.hud.sideNotifications:addNotification({
    title = "Custom Contracts",
    text = "Hello",
    duration = 4000
  })

  menuCustomContracts:initialize()

  self.ContractManager = CustomContractManager:new()
  self.CustomContractsMenu = menuCustomContracts
  self.lastPeriod = g_currentMission.environment.currentPeriod - 1
  self.currentPeriod = g_currentMission.environment.currentPeriod
  self.currentDay = g_currentMission.environment.currentDay

  g_messageCenter:publish(MessageType.CUSTOM_CONTRACTS_UPDATED)

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
end

-- Listening to game time, and triggers when hour is changed
function CustomContracts:hourChanged()
  -- Sync the contracts to retrieve the newest statuses
  g_currentMission.CustomContracts.ContractManager:syncContracts()

  -- Check if the period is changed or not
  local period = g_currentMission.environment.currentPeriod

  -- If the currentPeriod is not the same as the saved period triggered period changed
  if period ~= g_currentMission.CustomContracts.currentPeriod then
    g_currentMission.CustomContracts:onPeriodChanged()
    return
  end

  -- Check if the day is changed or not
  local day = g_currentMission.environment.currentDay

  -- If the currentDay is not the same as the saved day triggered day changed
  if day ~= g_currentMission.CustomContracts.currentDay then
    g_currentMission.CustomContracts:onDayChanged()
    return
  end
end

function CustomContracts:onPeriodChanged()
  -- Save the lastPeriod, so we can later use it to check if contracts need to be expired or not
  g_currentMission.CustomContracts.lastPeriod = g_currentMission.CustomContracts.currentPeriod

  -- Set the saved currentPeriod and currentDay with the new ones.
  g_currentMission.CustomContracts.currentPeriod = g_currentMission.environment.currentPeriod
  g_currentMission.CustomContracts.currentDay = g_currentMission.environment.currentDay

  -- Trigger the function to check if there are contracts that need to be expired, because of the period/day changed
  g_currentMission.CustomContracts.ContractManager:updateExpiredContracts()
end

function CustomContracts:onDayChanged()
  g_currentMission.CustomContracts.currentDay = g_currentMission.environment.currentDay

  g_currentMission.CustomContracts.ContractManager:updateExpiredContracts()
end

-- Override the basegame WorkArea allowance check.
function CustomContracts.getIsAccessibleAtWorldPosition(self, superFunc, farmId, x, z, workAreaType)
  -- Trigger basegame first
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

  g_gui:showDialog("menuCreateContract")
end

local function _getSideNotification()
  local hud = g_currentMission and g_currentMission.hud
  if hud == nil then return nil end
  return hud.sideNotification or hud.sideNotifications
end

-- Try several known method names / signatures.
function CustomContracts.show(text, durationMs)
  durationMs = durationMs or 4500

  local sn = _getSideNotification()
  if sn == nil then
    print(string.format("[CC] SideNotification not available. text=%s", tostring(text)))
    return false
  end

  -- Most likely candidates (we attempt them in a safe order)
  local candidates = {
    -- fn(sn, text, duration)
    function() if sn.addNotification ~= nil then return sn:addNotification(text, durationMs) end end,
    function() if sn.showNotification ~= nil then return sn:showNotification(text, durationMs) end end,

    -- Sometimes: fn(sn, text)
    function() if sn.addNotification ~= nil then return sn:addNotification(text) end end,
    function() if sn.showNotification ~= nil then return sn:showNotification(text) end end,

    -- Sometimes the HUD exposes it, not the element
    function()
      local hud = g_currentMission and g_currentMission.hud
      if hud ~= nil and hud.addSideNotification ~= nil then
        return hud:addSideNotification(text, durationMs)
      end
    end,
    function()
      local hud = g_currentMission and g_currentMission.hud
      if hud ~= nil and hud.showSideNotification ~= nil then
        return hud:showSideNotification(text, durationMs)
      end
    end
  }

  for _, fn in ipairs(candidates) do
    local ok, res = pcall(fn)
    if ok and res ~= false then
      return true
    end
  end

  print(string.format("[CC] Failed to call SideNotification method. text=%s", tostring(text)))
  return false
end

-- Debug: print available functions on the SideNotification instance
function CustomContracts.debugDump()
  local sn = _getSideNotification()
  if sn == nil then
    print("[CC] SideNotification is nil")
    return
  end

  print("[CC] SideNotification methods:")
  for k, v in pairs(sn) do
    if type(v) == "function" then
      print("  - " .. tostring(k))
    end
  end
end

WorkArea.getIsAccessibleAtWorldPosition =
    Utils.overwrittenFunction(WorkArea.getIsAccessibleAtWorldPosition, CustomContracts.getIsAccessibleAtWorldPosition)

FSBaseMission.sendInitialClientState = Utils.appendedFunction(FSBaseMission.sendInitialClientState,
  CustomContracts.sendInitialClientState)
FSBaseMission.saveSavegame = Utils.appendedFunction(FSBaseMission.saveSavegame, CustomContracts.saveToXmlFile)

g_messageCenter:subscribe(MessageType.HOUR_CHANGED, CustomContracts.hourChanged)
g_messageCenter:subscribe(MessageType.PLAYER_FARM_CHANGED, CustomContracts.playerFarmChanged)

addModEventListener(CustomContracts)
