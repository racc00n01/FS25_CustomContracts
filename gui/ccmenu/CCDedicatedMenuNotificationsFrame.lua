--
-- Notifications tab of the dedicated Shift+I menu.
--

CCDedicatedMenuNotificationsFrame = {}
local CCDedicatedMenuNotificationsFrame_mt = Class(CCDedicatedMenuNotificationsFrame, TabbedMenuFrameElement)

local modDirectory = g_currentModDirectory

function CCDedicatedMenuNotificationsFrame.new()
  local self = CCDedicatedMenuNotificationsFrame:superClass().new(nil, CCDedicatedMenuNotificationsFrame_mt)
  self.name = "CCDedicatedMenuNotificationsFrame"
  self.hasCustomMenuButtons = true
  self.isFrameOpen = false

  self.notificationsRenderer = NotificationsRenderer.new()

  self.btnBack = { inputAction = InputAction.MENU_BACK }
  self.btnDeleteNotification = {
    text = g_i18n:getText("cc_btn_delete_notification"),
    inputAction = InputAction.MENU_CANCEL,
    callback = function()
      self:onDeleteNotification()
    end
  }

  self.menuButtonInfo = { self.btnDeleteNotification, self.btnBack }

  return self
end

function CCDedicatedMenuNotificationsFrame.setupGui()
  local frame = CCDedicatedMenuNotificationsFrame.new()
  g_gui:loadGui(
    Utils.getFilename("gui/ccmenu/ccDedicatedMenuNotificationsFrame.xml", modDirectory),
    "CCDedicatedMenuNotificationsFrame",
    frame,
    true
  )
end

function CCDedicatedMenuNotificationsFrame:onGuiSetupFinished()
  CCDedicatedMenuNotificationsFrame:superClass().onGuiSetupFinished(self)

  self.notificationsTable:setDataSource(self.notificationsRenderer)
  self.notificationsTable:setDelegate(self.notificationsRenderer)
end

function CCDedicatedMenuNotificationsFrame:getMenuButtonInfo()
  return self.menuButtonInfo
end

function CCDedicatedMenuNotificationsFrame:onFrameOpen()
  CCDedicatedMenuNotificationsFrame:superClass().onFrameOpen(self)
  self.isFrameOpen = true

  self:onMoneyChange()
  g_messageCenter:subscribe(MessageType.MONEY_CHANGED, self.onMoneyChange, self)
  g_messageCenter:subscribe(MessageType.NOTIFICATIONS_UPDATED, self.updateContent, self)

  FocusManager:setFocus(self.notificationsTable)
  self:updateContent()
  self:setMenuButtonInfoDirty()
end

function CCDedicatedMenuNotificationsFrame:onFrameClose()
  g_messageCenter:unsubscribeAll(self)
  CCDedicatedMenuNotificationsFrame:superClass().onFrameClose(self)
  self.isFrameOpen = false
end

function CCDedicatedMenuNotificationsFrame:onMoneyChange()
  if g_localPlayer ~= nil then
    local farm = g_farmManager:getFarmById(g_localPlayer.farmId)
    if farm.money <= -1 then
      self.currentBalanceText:applyProfile(ShopMenu.GUI_PROFILE.SHOP_MONEY_NEGATIVE, nil, true)
    else
      self.currentBalanceText:applyProfile(ShopMenu.GUI_PROFILE.SHOP_MONEY, nil, true)
    end
    local moneyText = g_i18n:formatMoney(farm.money, 0, true, false)
    self.currentBalanceText:setText(moneyText)
    if self.shopMoneyBox ~= nil then
      self.shopMoneyBox:invalidateLayout()
      self.shopMoneyBoxBg:setSize(self.shopMoneyBox.flowSizes[1] + 60 * g_pixelSizeScaledX)
    end
  end
end

function CCDedicatedMenuNotificationsFrame:updateContent()
  local notifications = g_currentMission.CustomContracts.NotificationManager:getNotificationsByCurrentFarm()
  self.notificationsRenderer:setData(notifications)
  self.notificationsTable:reloadData()

  self:updateMenuButtons()
end

function CCDedicatedMenuNotificationsFrame:getSelectedNotification()
  local index = self.notificationsTable.selectedIndex
  if index == nil or index < 1 then
    return nil
  end
  return self.notificationsRenderer.data and self.notificationsRenderer.data[index] or nil
end

function CCDedicatedMenuNotificationsFrame:updateMenuButtons()
  local currentMission = g_currentMission
  local myFarmId = currentMission and currentMission:getFarmId() or nil
  local isSpectator = (myFarmId == nil or myFarmId == FarmManager.SPECTATOR_FARM_ID)

  if isSpectator then
    self.menuButtonInfo = { self.btnBack }
    self:setMenuButtonInfoDirty()
    return
  end

  self.menuButtonInfo = { self.btnDeleteNotification, self.btnBack }
  self:setMenuButtonInfoDirty()
end

function CCDedicatedMenuNotificationsFrame:onDeleteNotification()
  local notification = self:getSelectedNotification()

  if notification == nil then
    return
  end

  g_client:getServerConnection():sendEvent(
    DeleteNotificationEvent.new(notification.id)
  )
end
