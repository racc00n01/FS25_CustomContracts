--
-- Invoices tab of the dedicated Shift+I menu.
--

CCDedicatedMenuInvoicesFrame = {}
local CCDedicatedMenuInvoicesFrame_mt = Class(CCDedicatedMenuInvoicesFrame, TabbedMenuFrameElement)

local modDirectory = g_currentModDirectory

function CCDedicatedMenuInvoicesFrame.new()
  local self = CCDedicatedMenuInvoicesFrame:superClass().new(nil, CCDedicatedMenuInvoicesFrame_mt)
  self.name = "CCDedicatedMenuInvoicesFrame"
  self.hasCustomMenuButtons = true
  self.isFrameOpen = false

  self.invoicesInboxRenderer = InvoicesInboxRenderer.new()
  self.invoicesOutboxRenderer = InvoicesOutboxRenderer.new()

  self.activeInvoiceList = "INBOX"

  self.btnBack = { inputAction = InputAction.MENU_BACK }
  self.btnCreateInvoice = {
    inputAction = InputAction.MENU_EXTRA_1,
    text = g_i18n:getText("cc_btn_create_invoice"),
    callback = function()
      self:onCreateInvoice()
    end
  }
  self.btnPayInvoice = {
    inputAction = InputAction.MENU_ACCEPT,
    text = g_i18n:getText("cc_btn_pay_invoice"),
    callback = function()
      self:onPayInvoice()
    end
  }
  self.btnDetailInvoice = {
    inputAction = InputAction.MENU_ACTIVATE,
    text = g_i18n:getText("cc_btn_detail_invoice"),
    callback = function()
      self:onDetailInvoice()
    end
  }
  self.btnSentInvoice = {
    inputAction = InputAction.MENU_EXTRA_2,
    text = g_i18n:getText("cc_btn_send_invoice"),
    callback = function()
      self:onSentInvoice()
    end
  }
  self.btnDeleteInvoice = {
    inputAction = InputAction.MENU_CANCEL,
    text = g_i18n:getText("cc_btn_delete_invoice"),
    callback = function()
      self:onDeleteInvoice()
    end
  }

  self.menuButtonInfo = { self.btnBack }

  return self
end

function CCDedicatedMenuInvoicesFrame.setupGui()
  local frame = CCDedicatedMenuInvoicesFrame.new()
  g_gui:loadGui(
    Utils.getFilename("gui/ccmenu/ccDedicatedMenuInvoicesFrame.xml", modDirectory),
    "CCDedicatedMenuInvoicesFrame",
    frame,
    true
  )
end

function CCDedicatedMenuInvoicesFrame:onGuiSetupFinished()
  CCDedicatedMenuInvoicesFrame:superClass().onGuiSetupFinished(self)

  self.inboxInvoicesTable:setDataSource(self.invoicesInboxRenderer)
  self.inboxInvoicesTable:setDelegate(self.invoicesInboxRenderer)

  self.outboxInvoicesTable:setDataSource(self.invoicesOutboxRenderer)
  self.outboxInvoicesTable:setDelegate(self.invoicesOutboxRenderer)

  self.invoicesInboxRenderer.indexChangedCallback = function(index)
    if index ~= nil and index > 0 then
      self.activeInvoiceList = "INBOX"
      self.outboxInvoicesTable:setSelectedIndex(0)
    end
    self:updateMenuButtons()
    self:setMenuButtonInfoDirty()
  end

  self.invoicesOutboxRenderer.indexChangedCallback = function(index)
    if index ~= nil and index > 0 then
      self.activeInvoiceList = "OUTBOX"
      self.inboxInvoicesTable:setSelectedIndex(0)
    end
    self:updateMenuButtons()
    self:setMenuButtonInfoDirty()
  end
end

function CCDedicatedMenuInvoicesFrame:getMenuButtonInfo()
  return self.menuButtonInfo
end

function CCDedicatedMenuInvoicesFrame:onFrameOpen()
  CCDedicatedMenuInvoicesFrame:superClass().onFrameOpen(self)
  self.isFrameOpen = true

  self:onMoneyChange()
  g_messageCenter:subscribe(MessageType.MONEY_CHANGED, self.onMoneyChange, self)
  g_messageCenter:subscribe(MessageType.INVOICES_UPDATED, self.updateContent, self)

  FocusManager:setFocus(self.inboxInvoicesTable)
  self:updateContent()
  self:setMenuButtonInfoDirty()
end

function CCDedicatedMenuInvoicesFrame:onFrameClose()
  g_messageCenter:unsubscribeAll(self)
  CCDedicatedMenuInvoicesFrame:superClass().onFrameClose(self)
  self.isFrameOpen = false
end

function CCDedicatedMenuInvoicesFrame:onMoneyChange()
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

function CCDedicatedMenuInvoicesFrame:updateContent()
  local invoiceManager = g_currentMission.CustomContracts.InvoiceManager

  local invoices = invoiceManager:getInboundInvoicesByCurrentFarm()
  self.invoicesInboxRenderer:setData(invoices)
  self.inboxInvoicesTable:reloadData()

  local outboxInvoices = invoiceManager:getOutboundInvoicesByCurrentFarm()
  self.invoicesOutboxRenderer:setData(outboxInvoices)
  self.outboxInvoicesTable:reloadData()

  self:updateMenuButtons()
end

function CCDedicatedMenuInvoicesFrame:getSelectedInvoice()
  local inboxIndex = self.inboxInvoicesTable.selectedIndex
  local outboxIndex = self.outboxInvoicesTable.selectedIndex

  if inboxIndex ~= nil and inboxIndex > 0 then
    return self.invoicesInboxRenderer.data and self.invoicesInboxRenderer.data[inboxIndex] or nil
  elseif outboxIndex ~= nil and outboxIndex > 0 then
    return self.invoicesOutboxRenderer.data and self.invoicesOutboxRenderer.data[outboxIndex] or nil
  end
end

function CCDedicatedMenuInvoicesFrame:updateMenuButtons()
  local currentMission = g_currentMission
  local myFarmId = currentMission and currentMission:getFarmId() or nil
  local isSpectator = (myFarmId == nil or myFarmId == FarmManager.SPECTATOR_FARM_ID)

  if isSpectator then
    self.menuButtonInfo = { self.btnBack }
    self:setMenuButtonInfoDirty()
    return
  end

  local invoice = self:getSelectedInvoice()
  local farmId = g_currentMission:getFarmId() or 0

  local buttons = { self.btnBack, self.btnDetailInvoice, self.btnCreateInvoice }

  if invoice ~= nil then
    local isReceiver = invoice.receiverFarmId == farmId
    local isPayable = isReceiver and (invoice.status == Invoice.STATUS.SENT or invoice.status == Invoice.STATUS.OPEN)

    if isPayable then
      table.insert(buttons, self.btnPayInvoice)
    end

    if invoice.status == Invoice.STATUS.DRAFT and invoice.creatorFarmId == farmId then
      table.insert(buttons, self.btnSentInvoice)
    end

    if invoice.creatorFarmId == farmId then
      table.insert(buttons, self.btnDeleteInvoice)
    end
  end

  self.menuButtonInfo = buttons
  self:setMenuButtonInfoDirty()
end

function CCDedicatedMenuInvoicesFrame:onCreateInvoice()
  local myFarmId = g_currentMission:getFarmId()
  local hasOtherFarm = false

  for _, farm in ipairs(g_farmManager.farms) do
    local farmId = farm.farmId
    if farmId ~= FarmManager.SPECTATOR_FARM_ID and farm.showInFarmScreen and farmId ~= myFarmId then
      hasOtherFarm = true
      break
    end
  end

  if not hasOtherFarm then
    InfoDialog.show(g_i18n:getText("cc_dialog_create_invoice_no_other_farms"))
    return
  end

  CreateInvoiceDialog.show()
end

function CCDedicatedMenuInvoicesFrame:onDetailInvoice()
  local invoice = self:getSelectedInvoice()
  if invoice == nil then
    return
  end

  DetailInvoiceDialog.show(invoice)
end

function CCDedicatedMenuInvoicesFrame:onPayInvoice()
  local invoice = self:getSelectedInvoice()

  if invoice == nil then
    return
  end

  YesNoDialog.show(
    function(_, yes)
      if yes then
        g_client:getServerConnection():sendEvent(
          PayInvoiceEvent.new(invoice.id, g_currentMission:getFarmId())
        )
      end
    end,
    self,
    string.format(
      g_i18n:getText("cc_dialog_invoice_pay_yes_no"),
      invoice.number,
      g_i18n:formatMoney(invoice.total)
    ),
    g_i18n:getText("cc_dialog_invoice_pay_yes_no_btn")
  )
end

function CCDedicatedMenuInvoicesFrame:onSentInvoice()
  local invoice = self:getSelectedInvoice()

  if invoice == nil then
    return
  end

  YesNoDialog.show(
    function(_, yes)
      if yes then
        g_client:getServerConnection():sendEvent(
          SendInvoiceEvent.new(invoice.id, g_currentMission:getFarmId())
        )
      end
    end,
    self,
    string.format(
      g_i18n:getText("cc_dialog_invoice_send_yes_no"),
      invoice.number,
      g_i18n:formatMoney(invoice.total)
    ),
    g_i18n:getText("cc_dialog_invoice_send_yes_no_btn")
  )
end

function CCDedicatedMenuInvoicesFrame:onDeleteInvoice()
  local invoice = self:getSelectedInvoice()

  if invoice == nil then
    return
  end

  YesNoDialog.show(
    function(_, yes)
      if yes then
        g_client:getServerConnection():sendEvent(
          DeleteInvoiceEvent.new(invoice.id, g_currentMission:getFarmId())
        )
      end
    end,
    self,
    string.format(
      g_i18n:getText("cc_dialog_invoice_delete_yes_no"),
      invoice.number
    ),
    g_i18n:getText("cc_dialog_invoice_delete_yes_no_btn")
  )
end
