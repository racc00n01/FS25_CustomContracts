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
  OWNED = 3
}
MenuCustomContracts.CONTRACTS_STATE_TEXTS = { "cc_new", "cc_active", "cc_owned" }

MenuCustomContracts.HEADER_TITLES = {
  [MenuCustomContracts.SUB_CATEGORY.CONTRACTS] = "cc_header_contracts",
  [MenuCustomContracts.SUB_CATEGORY.INVOICES] = "cc_header_invoices",
}

function MenuCustomContracts.new(i18n, messageCenter)
  local self = MenuCustomContracts:superClass().new(nil, MenuCustomContracts._mt)
  self.name = "MenuCustomContracts"
  self.i18n = i18n
  self.messageCenter = messageCenter
  self.menuButtonInfo = {}

  self.contractsRenderer = ContractsRenderer.new()

  return self
end

function MenuCustomContracts:displaySelectedContract()
  local index = self.contractsTable.selectedIndex

  if index ~= -1 then
    local selection = self.contractDisplaySwitcher:getState()
    local contract = self.contractsRenderer.data[selection][index]

    if contract ~= nil then
      local field = g_fieldManager:getFieldById(contract:getFieldId())
      self.contractsInfoContainer:setVisible(true)
      self.noSelectedContractText:setVisible(false)

      --Contract info
      local farm = g_farmManager:getFarmById(contract.creatorFarmId)
      if farm ~= nil then
        self.contractId:setText(string.format("Contract #%d", contract.id))
        self.contractFarmName:setText(string.format("Owned by: %s", farm.name))
        self.contractWorkType:setText(contract:getWorkType())
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

        if contractorFarm ~= nil then
          statusTextLabel = string.format(g_i18n:getText("cc_contract_status_label"))
          statusText = string.format(
            contractorFarm.name
          )
        else
          statusTextLabel = string.format(g_i18n:getText("cc_contract_status_label_default"))
          statusText = contract.status
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
        string.format("%s on Field %d (%.2f ha)", contract:getWorkType(), contract:getFieldId(), field.areaHa)
      )
      self.contractStartDateValue:setText(self:formatPeriodDay(contract.startPeriod, contract.startDay))
      self.contractDueDateValue:setText(self:formatPeriodDay(contract.duePeriod, contract.dueDay))
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

  self.contractsRenderer.indexChangedCallback = function(index)
    self:displaySelectedContract()
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


  -- Set the new/active/owned contract switcher texts
  local contractSwitcherTexts = {}
  for k, v in pairs(MenuCustomContracts.CONTRACTS_STATE_TEXTS) do
    table.insert(contractSwitcherTexts, g_i18n:getText(v))
  end
  self.contractDisplaySwitcher:setTexts(contractSwitcherTexts)

  --- Register custom bottom page buttons
  self.btnBack = { inputAction = InputAction.MENU_BACK }
  self.btnCreateContract = {
    inputAction = InputAction.MENU_EXTRA_1,
    text = "Create contract",
    callback = function()
      self
          :onCreateContract()
    end
  }
  self.btnAccept = {
    text = "Accept contract",
    inputAction = InputAction.MENU_ACCEPT,
    callback = function()
      self:onAcceptContract()
    end
  }

  self.btnComplete = {
    text = "Complete contract",
    inputAction = InputAction.MENU_ACCEPT,
    callback = function()
      self:onCompleteContract()
    end
  }

  self.btnCancel = {
    text = "Cancel contract",
    inputAction = InputAction.MENU_ACCEPT,
    callback = function()
      self:onCancelContract()
    end
  }

  self.btnDelete = {
    text = "Delete contract",
    inputAction = InputAction.MENU_EXTRA_2,
    callback = function()
      self:onDeleteContract()
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
    self.btnCreateContract
  }

  -- OWNED contracts
  self.contractButtonSets[MenuCustomContracts.CONTRACTS_LIST_TYPE.OWNED] = {
    self.btnBack,
    self.btnDelete,
    self.btnCancel,
    self.btnCreateContract
  }

  self.menuButtonInfo[MenuCustomContracts.SUB_CATEGORY.CONTRACTS] = {
    self.btnBack
  }

  for _, subCategory in pairs(MenuCustomContracts.SUB_CATEGORY) do
    if subCategory ~= MenuCustomContracts.SUB_CATEGORY.CONTRACTS then
      self.menuButtonInfo[subCategory] = {
        self.btnBack
      }
    end
  end

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

    local renderData = {
      [MenuCustomContracts.CONTRACTS_LIST_TYPE.NEW] = newContracts,
      [MenuCustomContracts.CONTRACTS_LIST_TYPE.ACTIVE] = activeContracts,
      [MenuCustomContracts.CONTRACTS_LIST_TYPE.OWNED] = ownedContracts
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

  self:updateMenuButtons()
end

function MenuCustomContracts:updateMenuButtons()
  local subCategory = self.subCategoryPaging:getState()

  if subCategory ~= MenuCustomContracts.SUB_CATEGORY.CONTRACTS then
    self.menuButtonInfo[subCategory] = { self.btnBack }
    self:setMenuButtonInfoDirty()
    return
  end

  -- Contracts page → based on NEW / ACTIVE / OWNED
  local buttons = self.contractButtonSets[self.currentContractsListType]
      or { self.btnBack }

  self.menuButtonInfo[MenuCustomContracts.SUB_CATEGORY.CONTRACTS] = buttons
  self:setMenuButtonInfoDirty()
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

function MenuCustomContracts:onCreateContract()
  -- self:queueContractsView(MenuCustomContracts.CONTRACTS_LIST_TYPE.OWNED, nil)
  local selector = g_gui:showDialog("menuSelectContractTemplate")
  print("Open dialog")

  if selector ~= nil then
    selector.target:setCallback(function(templateId)
      local dlg = g_gui:showDialog("menuCreateContract")
      if dlg ~= nil then
        dlg.target:setTemplate(templateId)
      end
    end)
  end
end

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
      "Complete contract for Field %d and receive €%s?",
      contract:getFieldId(),
      g_i18n:formatMoney(contract.reward)
    ),
    "Complete Contract"
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
      "Accept contract for Field %d (%s) for €%s?",
      contract:getFieldId(),
      contract:getWorkType(),
      g_i18n:formatMoney(contract.reward)
    ),
    "Accept Contract"
  )
end

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
      "Cancel contract for Field %d?",
      contract:getFieldId()
    ),
    "Cancel Contract"
  )
end

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
      "Delete contract for Field %d?",
      contract:getFieldId()
    ),
    "Delete Contract"
  )
end

function MenuCustomContracts:periodToMonth(period)
  return ((period + 1) % 12) + 1
end

function MenuCustomContracts:formatPeriodDay(period, day)
  if period == nil or period <= 0 then
    return "-"
  end

  local month = self:periodToMonth(period)

  local monthName = DateUtil.getMonthName(month) or tostring(month)

  local env = g_currentMission.environment
  local daysPerPeriod = (env and env.daysPerPeriod) or 1

  if daysPerPeriod > 1 then
    return string.format("%s %d", monthName, day or 1)
  end

  return monthName
end
