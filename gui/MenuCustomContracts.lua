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
      local field = g_fieldManager:getFieldById(contract.fieldId)
      self.contractsInfoContainer:setVisible(true)
      self.noSelectedContractText:setVisible(false)

      --Contract info
      local farm = g_farmManager:getFarmById(contract.creatorFarmId)
      if farm ~= nil then
        self.contractId:setText(string.format("Contract #%d", contract.id))
        self.contractFarmName:setText(string.format("Owned by: %s", farm.name))
        self.contractWorkType:setText(contract.workType)
      else
        self.contractFarmName:setText("-")
        self.contractWorkType:setText("-")
      end

      -- local contractorFarm = g_farmManager:getFarmById(contract.contractorFarmId)
      -- if contractorFarm ~= nil then
      --   self.contractContractorValue:setText(contractorFarm.name)
      -- else
      --   self.contractContractorValue:setText("-")
      -- end

      self.contractRewardValue:setText(
        g_i18n:formatMoney(contract.reward, 0, true, true)
      )

      local statusText

      if contract.contractorFarmId ~= nil then
        local contractorFarm = g_farmManager:getFarmById(contract.contractorFarmId)

        if contractorFarm ~= nil then
          statusText = string.format(
            "%s: %s",
            g_i18n:getText("cc_ownedBy"),
            contractorFarm.name
          )
        else
          statusText = contract.status
        end
      else
        statusText = g_i18n:getText("cc_status_" .. string.lower(contract.status))
            or contract.status
      end

      self.contractStatusValue:setText(statusText)

      self.contractNotesValue:setText(
        contract.description or "-"
      )

      self.contractDescriptionValue:setText(
        string.format("%s on Field %d (%.2f ha)", contract.workType, contract.fieldId, field.areaHa)
      )
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
    self.btnBack -- will be overridden dynamically
  }

  -- Any other subcategory → Back only
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
  -- FocusManager:setFocus(self.subCategoryPaging)
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
    local contractManager = g_currentMission.customContracts.ContractManager
    local newContracts = contractManager:getNewContractsForCurrentFarm()
    local activeContracts = contractManager:getActiveContractsForCurrentFarm()
    local ownedContracts = contractManager:getOwnedContractsForCurrentFarm()

    print("[CustomContracts] New contracts count: " .. #newContracts)
    print("[CustomContracts] Active contracts count: " .. #activeContracts)
    print("[CustomContracts] Owned contracts count: " .. #ownedContracts)

    local renderData = {
      [MenuCustomContracts.CONTRACTS_LIST_TYPE.NEW] = newContracts,
      [MenuCustomContracts.CONTRACTS_LIST_TYPE.ACTIVE] = activeContracts,
      [MenuCustomContracts.CONTRACTS_LIST_TYPE.OWNED] = ownedContracts
    }

    self.contractsRenderer:setData(renderData)
    self.contractsTable:reloadData()

    self.contractsContainer:setVisible(self.contractsTable:getItemCount() > 0)
    self.contractsInfoContainer:setVisible(self.contractsTable:getItemCount() > 0)
    self.noContractsContainer:setVisible(self.contractsTable:getItemCount() == 0)
  end

  self:updateMenuButtons()
end

function MenuCustomContracts:updateMenuButtons()
  local subCategory = self.subCategoryPaging:getState()

  -- Not on Contracts page → Back only
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

function MenuCustomContracts:onCreateContract()
  self.redirectToYoursAfterCreate = true
  local dialog = g_gui:showDialog("menuCreateContract")
end

function MenuCustomContracts:onCompleteContract()
  local index = self.contractsTable.selectedIndex
  local selection = self.contractDisplaySwitcher:getState()
  local contract = self.contractsRenderer.data[selection][index]

  YesNoDialog.show(
    function(_, yes)
      if yes then
        g_client:getServerConnection():sendEvent(
          CompleteContractEvent.new(contract.id, g_currentMission:getFarmId())
        )
      end
    end,
    self,
    string.format(
      "Complete contract for Field %d and receive €%s?",
      contract.fieldId,
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

  -- Use in game YesNoDialog to confirm accepting the contract
  YesNoDialog.show(
    function(_, yes)
      if yes then
        g_client:getServerConnection():sendEvent(
          AcceptContractEvent.new(contract.id, g_currentMission:getFarmId())
        )
      end
    end,
    self,
    string.format(
      "Accept contract for Field %d (%s) for €%s?",
      contract.fieldId,
      contract.workType,
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
      contract.fieldId
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
        g_client:getServerConnection():sendEvent(
          DeleteContractEvent.new(contract.id, g_currentMission:getFarmId())
        )
      end
    end,
    self,
    string.format(
      "Delete contract for Field %d?",
      contract.fieldId
    ),
    "Delete Contract"
  )
end
