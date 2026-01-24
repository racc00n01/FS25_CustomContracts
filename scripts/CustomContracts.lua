--
-- FS25 CustomContracts
--
-- @Author: Racc00n
-- @Date: -
-- @Version: 0.0.0.1
--

CustomContracts = {}
CustomContracts.dir = g_currentModDirectory
CustomContracts.modName = g_currentModName
CustomContracts.SaveKey = "CustomContracts"

source(CustomContracts.dir .. "gui/MenuCustomContracts.lua")
source(CustomContracts.dir .. "gui/MenuCreateContract.lua")
source(CustomContracts.dir .. "scripts/events/SyncContractsEvent.lua")

function CustomContracts:loadMap()
  g_currentMission.customContracts = self

  MessageType.CUSTOM_CONTRACTS_UPDATED = nextMessageTypeId()
  MessageType.PLAYER_CONNECTED = nextMessageTypeId()

  g_gui:loadProfiles(CustomContracts.dir .. "gui/guiProfiles.xml")

  if g_customContractManager == nil then
    g_customContractManager = CustomContractManager:new()
  end

  -- Register menu page
  local menuCustomContracts = MenuCustomContracts.new(g_i18n)
  g_gui:loadGui(CustomContracts.dir .. "gui/MenuCustomContracts.xml", "menuCustomContracts", menuCustomContracts, true)

  CustomContracts.addIngameMenuPage(menuCustomContracts, "menuCustomContracts", { 0, 0, 1024, 1024 },
    CustomContracts:makeIsTaskListCheckEnabledPredicate(), "pageSettings")


  -- Register Create contract dialog
  local createContractDialog = MenuCreateContract.new(g_i18n)
  g_gui:loadGui(CustomContracts.dir .. "gui/MenuCreateContract.xml", "menuCreateContract", createContractDialog)

  self:loadFromXmlFile()

  if g_currentMission:getIsServer() then
    g_customContractManager:syncContracts()
  end

  g_messageCenter:publish(MessageType.CUSTOM_CONTRACTS_UPDATED)
  g_messageCenter:publish(MessageType.PLAYER_CONNECTED)
end

function CustomContracts:makeIsTaskListCheckEnabledPredicate()
  return function() return true end
end

function CustomContracts:saveToXmlFile()
  if not g_currentMission:getIsServer() then
    return
  end

  local path = g_currentMission.missionInfo.savegameDirectory
  if path == nil then
    path = ('%ssavegame%d'):format(
      getUserProfileAppPath(),
      g_currentMission.missionInfo.savegameIndex
    )
  end
  path = path .. "/"

  local xmlFile = createXMLFile(
    CustomContracts.SaveKey,
    path .. CustomContracts.SaveKey .. ".xml",
    CustomContracts.SaveKey
  )

  g_customContractManager:saveToXmlFile(xmlFile)
  saveXMLFile(xmlFile)
  delete(xmlFile)
end

function CustomContracts:loadFromXmlFile()
  if not g_currentMission:getIsServer() then return end

  local savegameFolderPath = g_currentMission.missionInfo.savegameDirectory;
  if savegameFolderPath == nil then
    savegameFolderPath = ('%ssavegame%d'):format(getUserProfileAppPath(), g_currentMission.missionInfo.savegameIndex)
  end

  savegameFolderPath = savegameFolderPath .. "/"

  if fileExists(savegameFolderPath .. CustomContracts.SaveKey .. ".xml") then
    local xmlFile = loadXMLFile(CustomContracts.SaveKey, savegameFolderPath .. CustomContracts.SaveKey .. ".xml");
    g_customContractManager:loadFromXmlFile(xmlFile)

    delete(xmlFile)
  end
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

FSBaseMission.saveSavegame = Utils.appendedFunction(FSBaseMission.saveSavegame, CustomContracts.saveToXmlFile)

addModEventListener(CustomContracts)
