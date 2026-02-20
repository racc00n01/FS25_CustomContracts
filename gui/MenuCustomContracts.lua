--
-- FS25 CustomContracts
--
-- @Author: Racc00n
-- @Version: 0.0.1.1
--

MenuCustomContracts = {}
MenuCustomContracts._mt = Class(MenuCustomContracts, TabbedMenuFrameElement)

MenuCustomContracts.SUB_CATEGORY = {
  CONTRACTS = 1,
  INVOICES = 2,
}

MenuCustomContracts.CONTRACTS_LIST_TYPE = {
  NEW = 1,
  ACTIVE = 2,
  OWNED = 3,
  COMPLETED = 4
}
MenuCustomContracts.CONTRACTS_STATE_TEXTS = { "cc_new", "cc_active", "cc_owned", "cc_completed" }

MenuCustomContracts.HEADER_TITLES = {
  [MenuCustomContracts.SUB_CATEGORY.CONTRACTS] = "cc_header_contracts",
  [MenuCustomContracts.SUB_CATEGORY.INVOICES] = "cc_header_invoices",
}

CustomContract.STATUS = {
  OPEN                       = "OPEN",
  ACCEPTED                   = "ACCEPTED",
  COMPLETED                  = "COMPLETED",
  CANCELLED                  = "CANCELLED",
  EXPIRED                    = "EXPIRED",
  COMPLETED_AWAITING_INVOICE = "COMPLETED_AWAITING_INVOICE",
  INVOICED                   = "INVOICED"
}

function MenuCustomContracts.new(i18n, messageCenter)
  local self = MenuCustomContracts:superClass().new(nil, MenuCustomContracts._mt)
  self.name = "MenuCustomContracts"
  self.i18n = i18n
  self.messageCenter = messageCenter
  self.menuButtonInfo = {}

  -- Intialize renderers
  self.contractsRenderer = ContractsRenderer.new()
  self.invoicesInboxRenderer = InvoicesInboxRenderer.new()
  self.invoicesOutboxRenderer = InvoicesOutboxRenderer.new()

  return self
end

function MenuCustomContracts:displaySelectedContract()
  local index = self.contractsTable.selectedIndex

  if index ~= -1 then
    local selection = self.contractDisplaySwitcher:getState()
    local contract = self.contractsRenderer.data[selection][index]

    if contract ~= nil then
      local farmland = g_farmlandManager:getFarmlandById(contract.farmlandId)
      self.contractsInfoContainer:setVisible(true)
      self.noSelectedContractText:setVisible(false)

      --Contract info
      local farm = g_farmManager:getFarmById(contract.creatorFarmId)
      if farm ~= nil then
        self.contractId:setText(string.format(g_i18n:getText("cc_contract_id_label"), contract.id))
        self.contractFarmName:setText(string.format(g_i18n:getText("cc_contract_owner_label"), farm.name))
        self.contractWorkType:setText(contract:getWorkTypeAreaName(contract.workAreaTypeIndex))
      else
        self.contractFarmName:setText("-")
        self.contractWorkType:setText("-")
      end

      self.contractRewardValue:setText(
        g_i18n:formatMoney(contract.reward, 0, true, true)
      )

      local statusText
      local statusTextLabel

      if contract.contractorFarmId ~= nil then
        local contractorFarm = g_farmManager:getFarmById(contract.contractorFarmId)

        if contractorFarm ~= nil and contract.status ~= CustomContract.STATUS.EXPIRED and contract.status ~= CustomContract.STATUS.CANCELLED and contract.status ~= CustomContract.STATUS.COMPLETED and contract.status ~= CustomContract.STATUS.INVOICED and contract.status ~= CustomContract.STATUS.COMPLETED_AWAITING_INVOICE then
          statusTextLabel = g_i18n:getText("cc_contract_status_label")
          statusText = contractorFarm.name
        else
          statusTextLabel = g_i18n:getText("cc_contract_status_label_default")
          statusText = g_i18n:getText("cc_status_" .. string.lower(contract.status))
              or contract.status
        end
      else
        statusTextLabel = string.format(g_i18n:getText("cc_contract_status_label_default"))
        statusText = g_i18n:getText("cc_status_" .. string.lower(contract.status))
            or contract.status
      end

      self.contractStatusValue:setText(statusText)
      self.contractStatusLabel:setText(statusTextLabel)

      self.contractNotesValue:setText(
        contract.description or "-"
      )

      self.contractDescriptionValue:setText(
        string.format(g_i18n:getText("cc_contract_description"), contract:getWorkTypeAreaName(contract.workAreaTypeIndex),
          contract.farmlandId, farmland.areaInHa)
      )
      self.contractStartDateValue:setText(CustomUtils:formatPeriodDay(contract.startPeriod, contract.startDay))
      self.contractDueDateValue:setText(CustomUtils:formatPeriodDay(contract.duePeriod, contract.dueDay))
    else
      self.contractsInfoContainer:setVisible(false)
      self.noSelectedContractText:setVisible(true)
    end
  end
end

function MenuCustomContracts:onGuiSetupFinished()
  MenuCustomContracts:superClass().onGuiSetupFinished(self)

  self.contractsTable:setDataSource(self.contractsRenderer)
  self.contractsTable:setDelegate(self.contractsRenderer)

  self.inboxInvoicesTable:setDataSource(self.invoicesInboxRenderer)
  self.inboxInvoicesTable:setDelegate(self.invoicesInboxRenderer)

  self.outboxInvoicesTable:setDataSource(self.invoicesOutboxRenderer)
  self.outboxInvoicesTable:setDelegate(self.invoicesOutboxRenderer)

  self.contractsRenderer.indexChangedCallback = function(index)
    self:displaySelectedContract()
    self:updateMenuButtons()
  end

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

function MenuCustomContracts:initialize()
  MenuCustomContracts:superClass().initialize(self)
  for i, tab in pairs(self.subCategoryTabs) do
    tab:getDescendantByName("background").getIsSelected = function()
      return i == self.subCategoryPaging:getState()
    end
    function tab.getIsSelected()
      return i == self.subCategoryPaging:getState()
    end
  end

  -- Set the filter switcher dots to follow the switcher state
  for i = 1, #self.contractsFilterDots.elements do
    self.contractsFilterDots.elements[i].getIsSelected = function()
      return self.contractDisplaySwitcher:getState() == i
    end
  end

  self.contractsFilterDots:invalidateLayout()

  -- Set the new/active/owned/completed contract switcher texts
  local contractSwitcherTexts = {}
  for k, v in pairs(MenuCustomContracts.CONTRACTS_STATE_TEXTS) do
    table.insert(contractSwitcherTexts, g_i18n:getText(v))
  end
  self.contractDisplaySwitcher:setTexts(contractSwitcherTexts)

  --- Register custom bottom page buttons
  self.btnBack = { inputAction = InputAction.MENU_BACK }

  -- Invoice related buttons
  self.btnCreateInvoice = {
    inputAction = InputAction.MENU_EXTRA_1,
    text = "Create invoice",
    callback = function()
      self
          :onCreateInvoice()
    end
  }
  self.btnPayInvoice = {
    inputAction = InputAction.MENU_ACCEPT,
    text = "Pay invoice",
    callback = function()
      self
          :onPayInvoice()
    end
  }
  self.btnDetailInvoice = {
    inputAction = InputAction.MENU_ACTIVATE,
    text = "View details",
    callback = function()
      self
          :onDetailInvoice()
    end
  }
  self.btnSentInvoice = {
    inputAction = InputAction.MENU_EXTRA_2,
    text = "Send invoice",
    callback = function()
      self
          :onSentInvoice()
    end
  }
  self.btnDeleteInvoice = {
    inputAction = InputAction.MENU_CANCEL,
    text = "Delete invoice",
    callback = function()
      self
          :onDeleteInvoice()
    end
  }

  -- Contract related buttons
  self.btnCreateContract = {
    inputAction = InputAction.MENU_EXTRA_1,
    text = g_i18n:getText("cc_btn_create_contract"),
    callback = function()
      self
          :onCreateContract()
    end
  }
  self.btnAccept = {
    text = g_i18n:getText("cc_btn_accept_contract"),
    inputAction = InputAction.MENU_ACCEPT,
    callback = function()
      self:onAcceptContract()
    end
  }

  self.btnComplete = {
    text = g_i18n:getText("cc_btn_complete_contract"),
    inputAction = InputAction.MENU_ACCEPT,
    callback = function()
      self:onCompleteContract()
    end
  }

  self.btnCancel = {
    text = g_i18n:getText("cc_btn_cancel_contract"),
    inputAction = InputAction.MENU_ACCEPT,
    callback = function()
      self:onCancelContract()
    end
  }

  self.btnDelete = {
    text = g_i18n:getText("cc_btn_delete_contract"),
    inputAction = InputAction.MENU_CANCEL,
    callback = function()
      self:onDeleteContract()
    end
  }

  self.btnReopen = {
    text = g_i18n:getText("cc_btn_reopen_contract"),
    inputAction = InputAction.MENU_ACCEPT,
    callback = function()
      self:onReopenContract()
    end
  }

  self.btnEdit = {
    text = g_i18n:getText("cc_btn_edit_contract"),
    inputAction = InputAction.MENU_ACCEPT,
    callback = function()
      self:onEditContract()
    end
  }

  self.contractButtonSets = {}

  -- NEW contracts
  self.contractButtonSets[MenuCustomContracts.CONTRACTS_LIST_TYPE.NEW] = {
    self.btnBack,
    self.btnAccept,
    self.btnCreateContract
  }

  -- ACTIVE contracts
  self.contractButtonSets[MenuCustomContracts.CONTRACTS_LIST_TYPE.ACTIVE] = {
    self.btnBack,
    self.btnComplete,
    self.btnCancel,
    self.btnCreateInvoice,
    self.btnCreateContract
  }

  -- OWNED contracts
  self.contractButtonSets[MenuCustomContracts.CONTRACTS_LIST_TYPE.OWNED] = {
    self.btnBack,
    self.btnDelete,
    self.btnCancel,
    self.btnReopen,
    self.btnEdit,
    self.btnCreateContract
  }

  -- COMPLETED contracts
  self.contractButtonSets[MenuCustomContracts.CONTRACTS_LIST_TYPE.COMPLETED] = {
    self.btnBack,
    self.btnDelete,
    self.btnCreateInvoice,
    self.btnCreateContract
  }

  self.menuButtonInfo[MenuCustomContracts.SUB_CATEGORY.CONTRACTS] = {
    self.btnBack
  }

  self.menuButtonInfo[MenuCustomContracts.SUB_CATEGORY.INVOICES] = {
    self.btnBack,
    self.btnPayInvoice,
    self.btnDetailInvoice,
    self.btnCreateInvoice,
  }

  self.currentContractsListType =
      self.contractDisplaySwitcher:getState()
      or MenuCustomContracts.CONTRACTS_LIST_TYPE.NEW

  self:updateMenuButtons()
end

function MenuCustomContracts:getMenuButtonInfo()
  return self.menuButtonInfo[self.subCategoryPaging:getState()]
end

function MenuCustomContracts:onFrameOpen()
  local texts = {}
  for k, tab in pairs(self.subCategoryTabs) do
    tab:setVisible(true)
    table.insert(texts, tostring(k))
  end
  self.subCategoryBox:invalidateLayout()
  self.subCategoryPaging:setTexts(texts)
  self.subCategoryPaging:setSize(self.subCategoryBox.maxFlowSize + 140 * g_pixelSizeScaledX)

  self:onMoneyChange()
  g_messageCenter:subscribe(MessageType.MONEY_CHANGED, self.onMoneyChange, self)
  g_messageCenter:subscribe(MessageType.CUSTOM_CONTRACTS_UPDATED, self.updateContent, self)
  g_messageCenter:subscribe(MessageType.INVOICES_UPDATED, self.updateContent, self)
  self:updateContent()
  self:setMenuButtonInfoDirty()
end

function MenuCustomContracts:onFrameClose()
  MenuCustomContracts:superClass().onFrameClose(self)
  g_messageCenter:unsubscribeAll(self)
end

function MenuCustomContracts:onClickContracts()
  self.subCategoryPaging:setState(MenuCustomContracts.SUB_CATEGORY.CONTRACTS, true)

  self:setMenuButtonInfoDirty()
end

function MenuCustomContracts:onClickInvoices()
  self.subCategoryPaging:setState(MenuCustomContracts.SUB_CATEGORY.INVOICES, true)
  self:updateMenuButtons()
  self:setMenuButtonInfoDirty()
end

function MenuCustomContracts:updateSubCategoryPages(subCategoryIndex)
  self:updateContent()
  self:setMenuButtonInfoDirty()
end

function MenuCustomContracts:onSwitchContractDisplay()
  self.contractsTable:reloadData()
  self.currentContractsListType = self.contractDisplaySwitcher:getState()
  local hasItem = self.contractsTable:getItemCount() > 0
  self.contractsContainer:setVisible(hasItem)
  self.contractsInfoContainer:setVisible(hasItem)
  self.noContractsContainer:setVisible(not hasItem)
  if hasItem then
    self.contractsTable:setSelectedIndex(1)
  end
  self:displaySelectedContract()

  self:updateMenuButtons()
  self:setMenuButtonInfoDirty()
end

function MenuCustomContracts:updateContent()
  local state = self.subCategoryPaging:getState()

  self.categoryHeaderText:setText(g_i18n:getText(MenuCustomContracts.HEADER_TITLES[state]))

  for k, v in pairs(self.subCategoryPages) do
    v:setVisible(k == state)
  end

  if state == MenuCustomContracts.SUB_CATEGORY.CONTRACTS then
    local contractManager = g_currentMission.CustomContracts.ContractManager
    local newContracts = contractManager:getNewContractsForCurrentFarm()
    local activeContracts = contractManager:getActiveContractsForCurrentFarm()
    local ownedContracts = contractManager:getOwnedContractsForCurrentFarm()
    local completedContracts = contractManager:getCompletedContractsForCurrentFarm()

    local renderData = {
      [MenuCustomContracts.CONTRACTS_LIST_TYPE.NEW] = newContracts,
      [MenuCustomContracts.CONTRACTS_LIST_TYPE.ACTIVE] = activeContracts,
      [MenuCustomContracts.CONTRACTS_LIST_TYPE.OWNED] = ownedContracts,
      [MenuCustomContracts.CONTRACTS_LIST_TYPE.COMPLETED] = completedContracts
    }

    self.contractsRenderer:setData(renderData)
    self.contractsTable:reloadData()

    self:applyPendingContractsView(renderData)

    -- If nothing queued, do your normal logic
    if self.pendingContractsListType == nil then
      self.contractsContainer:setVisible(self.contractsTable:getItemCount() > 0)
      self.contractsInfoContainer:setVisible(self.contractsTable:getItemCount() > 0)
      self.noContractsContainer:setVisible(self.contractsTable:getItemCount() == 0)
    end
  end

  -- INVOICES page
  if state == MenuCustomContracts.SUB_CATEGORY.INVOICES then
    local invoiceManager = g_currentMission.CustomContracts.InvoiceManager

    local invoices = invoiceManager:getInboundInvoicesByCurrentFarm()
    self.invoicesInboxRenderer:setData(invoices)
    self.inboxInvoicesTable:reloadData()

    local outboxInvoices = invoiceManager:getOutboundInvoicesByCurrentFarm()
    self.invoicesOutboxRenderer:setData(outboxInvoices)
    self.outboxInvoicesTable:reloadData()
  end

  self:updateMenuButtons()
end

function MenuCustomContracts:updateMenuButtons()
  local subCategory = self.subCategoryPaging:getState()

  if subCategory == MenuCustomContracts.SUB_CATEGORY.INVOICES then
    local invoice = self:getSelectedInvoice()
    local myFarmId = g_currentMission:getFarmId() or 0

    -- Default buttons
    local buttons = { self.btnBack, self.btnDetailInvoice, self.btnCreateInvoice }

    if invoice ~= nil then
      local isReceiver = invoice.receiverFarmId == myFarmId
      local isPayable = isReceiver and (invoice.status == Invoice.STATUS.SENT or invoice.status == Invoice.STATUS.OPEN)

      -- Add "Pay invoice" button for incoming invoices that are in SENT or OPEN status
      if isPayable then
        table.insert(buttons, self.btnPayInvoice)
      end

      -- Add "Send invoice" button for outgoing invoices that are in DRAFT status
      if invoice.status == Invoice.STATUS.DRAFT and invoice.creatorFarmId == myFarmId then
        table.insert(buttons, self.btnSentInvoice)
      end

      if invoice.creatorFarmId == myFarmId then
        table.insert(buttons, self.btnDeleteInvoice)
      end
    end

    self.menuButtonInfo[subCategory] = buttons
    self:setMenuButtonInfoDirty()
    return
  end

  if subCategory == MenuCustomContracts.SUB_CATEGORY.CONTRACTS then
    self.menuButtonInfo[subCategory] = { self.btnBack }

    local listType = self.currentContractsListType or MenuCustomContracts.CONTRACTS_LIST_TYPE.NEW
    local baseButtons = self.contractButtonSets[listType] or { self.btnBack, self.btnCreateContract }

    local contract = self:getSelectedContract()

    local filtered = {}
    for _, btn in ipairs(baseButtons) do
      if self:shouldShowButton(btn, listType, contract) then
        table.insert(filtered, btn)
      end
    end

    self.menuButtonInfo[MenuCustomContracts.SUB_CATEGORY.CONTRACTS] = filtered
    self:setMenuButtonInfoDirty()
    return
  end
end

function MenuCustomContracts:getSelectedContract()
  local index = self.contractsTable.selectedIndex
  if index == nil or index < 1 then
    return nil
  end

  local selection = self.contractDisplaySwitcher:getState()
  local list = self.contractsRenderer.data and self.contractsRenderer.data[selection]
  if list == nil then
    return nil
  end

  return list[index]
end

function MenuCustomContracts:getSelectedInvoice()
  local inboxIndex = self.inboxInvoicesTable.selectedIndex
  local outboxIndex = self.outboxInvoicesTable.selectedIndex

  if inboxIndex ~= nil and inboxIndex > 0 then
    return self.invoicesInboxRenderer.data and self.invoicesInboxRenderer.data[inboxIndex] or nil
  elseif outboxIndex ~= nil and outboxIndex > 0 then
    return self.invoicesOutboxRenderer.data and self.invoicesOutboxRenderer.data[outboxIndex] or nil
  end
end

function MenuCustomContracts:shouldShowButton(button, listType, contract)
  -- Always show these
  if button == self.btnBack or button == self.btnCreateContract then
    return true
  end

  -- No selected contract => only back + create
  if contract == nil then
    return false
  end

  local myFarmId = g_currentMission:getFarmId() or 0
  local isOwner = (contract.creatorFarmId == myFarmId)
  local isContractor = (contract.contractorFarmId == myFarmId)

  local status = contract.status

  -- NEW tab rules
  if listType == MenuCustomContracts.CONTRACTS_LIST_TYPE.NEW then
    if button == self.btnAccept then
      return status == CustomContract.STATUS.OPEN and not isOwner
    end
    return false
  end

  -- ACTIVE tab rules
  if listType == MenuCustomContracts.CONTRACTS_LIST_TYPE.ACTIVE then
    if button == self.btnComplete then
      return status == CustomContract.STATUS.ACCEPTED and isContractor
    end
    if button == self.btnCancel then
      return status == CustomContract.STATUS.ACCEPTED and isContractor
    end
    return false
  end

  -- OWNED tab rules
  if listType == MenuCustomContracts.CONTRACTS_LIST_TYPE.OWNED then
    if not isOwner then
      return false
    end

    if button == self.btnEdit then
      return status == CustomContract.STATUS.OPEN or status == CustomContract.STATUS.CANCELLED or
          status == CustomContract.STATUS.EXPIRED
    end

    if button == self.btnCancel then
      -- owner cancelling an accepted contract
      return status == CustomContract.STATUS.ACCEPTED or status == CustomContract.STATUS.OPEN
    end

    if button == self.btnReopen then
      return status == CustomContract.STATUS.CANCELLED or status == CustomContract.STATUS.EXPIRED
    end

    if button == self.btnDelete then
      return status == CustomContract.STATUS.OPEN
          or status == CustomContract.STATUS.CANCELLED
          or status == CustomContract.STATUS.EXPIRED
          or status == CustomContract.STATUS.COMPLETED
          or status == CustomContract.STATUS.INVOICED
          or status == CustomContract.STATUS.COMPLETED_AWAITING_INVOICE
    end

    return false
  end

  -- COMPLETED tab rules
  if listType == MenuCustomContracts.CONTRACTS_LIST_TYPE.COMPLETED then
    if button == self.btnCreateInvoice then
      return status == CustomContract.STATUS.COMPLETED_AWAITING_INVOICE and isContractor and contract.invoiceId < 0
    end
    return false
  end

  return false
end

function MenuCustomContracts:onMoneyChange()
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

function MenuCustomContracts:queueContractsView(listType, focusContractId)
  self.pendingContractsListType = listType
  self.pendingFocusContractId = focusContractId -- can be nil
end

function MenuCustomContracts:applyPendingContractsView(renderData)
  if self.pendingContractsListType == nil then
    return
  end

  local targetListType = self.pendingContractsListType
  local focusId = self.pendingFocusContractId

  self.pendingContractsListType = nil
  self.pendingFocusContractId = nil

  -- Switch the switcher (NEW / ACTIVE / OWNED)
  self.contractDisplaySwitcher:setState(targetListType, true)
  self.currentContractsListType = targetListType

  self.contractsTable:reloadData()

  local items = renderData[targetListType] or {}
  local targetIndex = 0

  if focusId ~= nil then
    for i, c in ipairs(items) do
      if c.id == focusId then
        targetIndex = i
        break
      end
    end
  end

  if targetIndex == 0 and #items > 0 then
    targetIndex = 1
  end

  local hasItem = self.contractsTable:getItemCount() > 0
  self.contractsContainer:setVisible(hasItem)
  self.contractsInfoContainer:setVisible(hasItem)
  self.noContractsContainer:setVisible(not hasItem)

  if hasItem then
    self.contractsTable:setSelectedIndex(targetIndex)
  end

  self:displaySelectedContract()
end

-- Function triggered when clicking on the "Create invoice" button
function MenuCustomContracts:onCreateInvoice()
  local dialog = g_gui:showDialog("createInvoiceDialog")
end

-- Function triggered when clicking on the "View details" button
function MenuCustomContracts:onDetailInvoice()
  local invoice = self:getSelectedInvoice()
  if invoice == nil then
    return
  end

  g_currentMission.CustomContracts.selectedInvoice = invoice
  g_gui:showDialog("detailInvoiceDialog")
end

-- Function triggered when clicking on the "Pay invoice" button
function MenuCustomContracts:onPayInvoice()
  local invoice = self:getSelectedInvoice()

  if invoice == nil then return end

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

-- Function triggered when clicking on the "Send invoice" button
function MenuCustomContracts:onSentInvoice()
  local invoice = self:getSelectedInvoice()

  if invoice == nil then return end

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

-- Function triggered when clicking on the "Delete invoice" button
function MenuCustomContracts:onDeleteInvoice()
  local invoice = self:getSelectedInvoice()

  if invoice == nil then return end

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

-- Function triggered when clicking on the "Create contract" button
function MenuCustomContracts:onCreateContract()
  self:queueContractsView(MenuCustomContracts.CONTRACTS_LIST_TYPE.OWNED, nil)
  local dialog = g_gui:showDialog("menuCreateContract")
end

-- Function triggered when clicking on the "Complete contract" button
function MenuCustomContracts:onCompleteContract()
  local index = self.contractsTable.selectedIndex
  local selection = self.contractDisplaySwitcher:getState()
  local contract = self.contractsRenderer.data[selection][index]

  YesNoDialog.show(
    function(_, yes)
      if yes then
        self:queueContractsView(MenuCustomContracts.CONTRACTS_LIST_TYPE.ACTIVE, nil)
        g_client:getServerConnection():sendEvent(
          CompleteContractEvent.new(contract.id, g_currentMission:getFarmId())
        )
      end
    end,
    self,
    string.format(
      g_i18n:getText("cc_dialog_create_yes_no"),
      contract.farmlandId,
      g_i18n:formatMoney(contract.reward)
    ),
    g_i18n:getText("cc_dialog_create_yes_no_btn")
  )
end

-- Function triggered when clicking on the "Accept contract" button
function MenuCustomContracts:onAcceptContract()
  local index = self.contractsTable.selectedIndex
  local selection = self.contractDisplaySwitcher:getState()
  local contract = self.contractsRenderer.data[selection][index]

  if contract == nil then
    InfoDialog.show("No contract found")
    return
  end

  YesNoDialog.show(
    function(_, yes)
      if yes then
        self:queueContractsView(MenuCustomContracts.CONTRACTS_LIST_TYPE.ACTIVE, contract.id)
        g_client:getServerConnection():sendEvent(
          AcceptContractEvent.new(contract.id, g_currentMission:getFarmId())
        )
      end
    end,
    self,
    string.format(
      g_i18n:getText("cc_dialog_accept_yes_no"),
      contract.farmlandId,
      contract:getWorkTypeAreaName(contract.workAreaTypeIndex),
      g_i18n:formatMoney(contract.reward)
    ),
    g_i18n:getText("cc_dialog_accept_yes_no_btn")
  )
end

-- Function triggered when clicking on the "Cancel contract" button
function MenuCustomContracts:onCancelContract()
  local index = self.contractsTable.selectedIndex
  local selection = self.contractDisplaySwitcher:getState()
  local contract = self.contractsRenderer.data[selection][index]

  if contract == nil then return end

  YesNoDialog.show(
    function(_, yes)
      if yes then
        g_client:getServerConnection():sendEvent(
          CancelContractEvent.new(contract.id, g_currentMission:getFarmId())
        )
      end
    end,
    self,
    string.format(
      g_i18n:getText("cc_dialog_cancel_yes_no"),
      contract.farmlandId
    ),
    g_i18n:getText("cc_dialog_cancel_yes_no_btn")
  )
end

-- Function triggered when clicking on the "Delete contract" button
function MenuCustomContracts:onDeleteContract()
  local index = self.contractsTable.selectedIndex
  local selection = self.contractDisplaySwitcher:getState()
  local contract = self.contractsRenderer.data[selection][index]

  if contract == nil then return end

  YesNoDialog.show(
    function(_, yes)
      if yes then
        self:queueContractsView(MenuCustomContracts.CONTRACTS_LIST_TYPE.OWNED, nil)
        g_client:getServerConnection():sendEvent(
          DeleteContractEvent.new(contract.id, g_currentMission:getFarmId())
        )
      end
    end,
    self,
    string.format(
      g_i18n:getText("cc_dialog_delete_yes_no"),
      contract.farmlandId
    ),
    g_i18n:getText("cc_dialog_delete_yes_no_btn")
  )
end

-- Function triggered when clicking on the "Reopen contract" button
function MenuCustomContracts:onReopenContract()
  local index = self.contractsTable.selectedIndex
  local selection = self.contractDisplaySwitcher:getState()
  local contract = self.contractsRenderer.data[selection][index]

  if contract == nil then return end

  YesNoDialog.show(
    function(_, yes)
      if yes then
        self:queueContractsView(MenuCustomContracts.CONTRACTS_LIST_TYPE.OWNED, nil)
        g_client:getServerConnection():sendEvent(
          ReopenContractEvent.new(contract.id, g_currentMission:getFarmId())
        )
      end
    end,
    self,
    string.format(
      g_i18n:getText("cc_dialog_reopen_yes_no"),
      contract.farmlandId
    ),
    g_i18n:getText("cc_dialog_reopen_yes_no_btn")
  )
end

-- Function triggered when clicking on the "Edit contract" button
function MenuCustomContracts:onEditContract()
  local index = self.contractsTable.selectedIndex
  local selection = self.contractDisplaySwitcher:getState()
  local contract = self.contractsRenderer.data[selection][index]

  if contract == nil then return end

  g_currentMission.CustomContracts.editContract = contract
  g_gui:showDialog("menuEditContract")
end
