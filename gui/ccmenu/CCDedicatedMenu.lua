--
-- Standalone TabbedMenu for Contracts & Invoices (Shift+I). Mirrors RLMenu shell pattern.
--

CCDedicatedMenu = {}
local CCDedicatedMenu_mt = Class(CCDedicatedMenu, TabbedMenu)

local modDirectory = g_currentModDirectory

-- Mod tab icons: use filename + UVs (gui.* slice IDs do not resolve to mod textures on tab buttons).
local CC_MENU_ICON_UVS = GuiUtils.getUVs("0px 0px 512px 512px", { 512, 512 })

CCDedicatedMenu.ACTION_NAME = "CC_DEDICATED_MENU"

function CCDedicatedMenu.new(target, custom_mt)
  local self = TabbedMenu.new(target, custom_mt or CCDedicatedMenu_mt)
  self.isOpen = false
  return self
end

function CCDedicatedMenu.hasValidPlayerFarm()
  if g_currentMission == nil then
    return false
  end
  local farmId = g_currentMission:getFarmId()
  if farmId == nil or farmId == FarmManager.SPECTATOR_FARM_ID then
    return false
  end
  return true
end

local function makeFarmPredicate()
  return function()
    return CCDedicatedMenu.hasValidPlayerFarm()
  end
end

function CCDedicatedMenu.setupGui()
  CCDedicatedMenuContractsFrame.setupGui()
  CCDedicatedMenuInvoicesFrame.setupGui()
  CCDedicatedMenuNotificationsFrame.setupGui()

  g_ccDedicatedMenu = CCDedicatedMenu.new()
  g_gui:loadGui(
    Utils.getFilename("gui/ccmenu/ccDedicatedMenu.xml", modDirectory),
    "CCDedicatedMenu",
    g_ccDedicatedMenu,
    false
  )
end

function CCDedicatedMenu:onGuiSetupFinished()
  CCDedicatedMenu:superClass().onGuiSetupFinished(self)
  self:setupMenuPages()
end

function CCDedicatedMenu:setupMenuPages()
  local pred = makeFarmPredicate()

  self:registerPage(self.contractsFrame, 1, pred)
  self:addPageTab(self.contractsFrame, modDirectory .. "gui/icons/menuIconContract.dds", CC_MENU_ICON_UVS, nil)
  if self.contractsFrame ~= nil and self.contractsFrame.initialize ~= nil then
    self.contractsFrame:initialize()
  end

  self:registerPage(self.invoicesFrame, 2, pred)
  self:addPageTab(self.invoicesFrame, modDirectory .. "gui/icons/menuIconInvoice.dds", CC_MENU_ICON_UVS, nil)
  if self.invoicesFrame ~= nil and self.invoicesFrame.initialize ~= nil then
    self.invoicesFrame:initialize()
  end

  self:registerPage(self.notificationsFrame, 3, pred)
  self:addPageTab(self.notificationsFrame, modDirectory .. "gui/icons/menuIconNotifications.dds", CC_MENU_ICON_UVS, nil)
  if self.notificationsFrame ~= nil and self.notificationsFrame.initialize ~= nil then
    self.notificationsFrame:initialize()
  end

  self:rebuildTabList()
end

function CCDedicatedMenu:setupMenuButtonInfo()
  CCDedicatedMenu:superClass().setupMenuButtonInfo(self)
  self.clickBackCallback = self:makeSelfCallback(self.onButtonBack)
  self.backButtonInfo = {
    inputAction = InputAction.MENU_BACK,
    text = g_i18n:getText("button_back"),
    callback = self.clickBackCallback,
  }
  self.defaultMenuButtonInfo = { self.backButtonInfo }
  self.defaultMenuButtonInfoByActions[InputAction.MENU_BACK] = self.backButtonInfo
  self.defaultButtonActionCallbacks = {
    [InputAction.MENU_BACK] = self.clickBackCallback,
  }
end

function CCDedicatedMenu:onButtonBack()
  self:exitMenu()
end

function CCDedicatedMenu:onOpen()
  CCDedicatedMenu:superClass().onOpen(self)
  self.isOpen = true
end

function CCDedicatedMenu:onClose()
  CCDedicatedMenu:superClass().onClose(self)
  self.isOpen = false
end

function CCDedicatedMenu.open()
  if g_gui:getIsGuiVisible() then
    return
  end
  if not CCDedicatedMenu.hasValidPlayerFarm() then
    InfoDialog.show(g_i18n:getText("cc_menu_join_farm_first"))
    return
  end
  g_gui:showGui("CCDedicatedMenu")
end

function CCDedicatedMenu.addPlayerActionEvents(playerInputComponent, controlling)
  local triggerUp = false
  local triggerDown = true
  local triggerAlways = false
  local startActive = true
  local callbackState = nil
  local disableConflictingBindings = true

  local success, actionEventId = g_inputBinding:registerActionEvent(
    CCDedicatedMenu.ACTION_NAME,
    CCDedicatedMenu,
    CCDedicatedMenu.open,
    triggerUp, triggerDown, triggerAlways, startActive,
    callbackState, disableConflictingBindings
  )

  if success and actionEventId ~= nil then
    g_inputBinding:setActionEventTextVisibility(actionEventId, false)
  end
end

function CCDedicatedMenu.install()
  PlayerInputComponent.registerGlobalPlayerActionEvents = Utils.appendedFunction(
    PlayerInputComponent.registerGlobalPlayerActionEvents,
    CCDedicatedMenu.addPlayerActionEvents
  )
end

CCDedicatedMenu.install()
