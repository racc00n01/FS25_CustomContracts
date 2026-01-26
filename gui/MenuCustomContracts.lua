MenuCustomContracts = {}

MenuCustomContracts.FILTER = {
  NEW    = 1, -- OPEN
  ACTIVE = 2, -- ACCEPTED (your active contract)
  YOURS  = 3  -- created by you
}

MenuCustomContracts.CATEGRORY_TEXTS = {
  "New",
  "Active",
  "Your Contracts"
}

MenuCustomContracts.NUM_CATEGORIES = #MenuCustomContracts.CATEGRORY_TEXTS

MenuCustomContracts._mt = Class(MenuCustomContracts, TabbedMenuFrameElement)

function MenuCustomContracts.new(i18n)
  local self = MenuCustomContracts:superClass().new(nil, MenuCustomContracts._mt)
  self.name = "menuCustomContracts"
  self.i18n = i18n

  self.newData = {}
  self.activeData = {}
  self.yourData = {}

  self.subCategoryPages = {}
  self.subCategoryTabs = {}
  self.currentFilter = MenuCustomContracts.FILTER.NEW

  --- Register custom bottom page buttons
  self.btnBack = { inputAction = InputAction.MENU_BACK }
  self.btnCreateContract = {
    inputAction = InputAction.MENU_ACCEPT,
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
    inputAction = InputAction.MENU_ACCEPT,
    callback = function()
      self:onDeleteContract()
    end
  }

  self.selectedIndex = -1

  -- Set menu buttons, the bar at the bottom where buttons are in all UI
  self:setMenuButtonInfo({
    self.btnBack,
    self.btnCreateContract,
    self.btnAccept,
    self.btnComplete,
    self.btnCancel
  })

  return self
end

function MenuCustomContracts:onGuiSetupFinished()
  MenuCustomContracts:superClass().onGuiSetupFinished(self)

  self:initialize()

  self.newContractsList:setDataSource(self)
  self.newContractsList:setDelegate(self)

  self.activeContractsList:setDataSource(self)
  self.activeContractsList:setDelegate(self)

  self.yourContractsList:setDataSource(self)
  self.yourContractsList:setDelegate(self)

  self.btnCreateContract.onClickCallback = self.onCreateContract
end

function MenuCustomContracts:onFrameOpen()
  MenuCustomContracts:superClass().onFrameOpen(self)

  print("[CustomContracts] Menu opened, subscribing to updates")

  self:onMoneyChange()
  g_messageCenter:subscribe(MessageType.MONEY_CHANGED, self.onMoneyChange, self)
  g_messageCenter:subscribe(MessageType.CUSTOM_CONTRACTS_UPDATED, self.updateContent, self)


  self:updateContent()
  self:updateSubCategoryPages(self.FILTER.NEW)
  self:updateMenuButtons()

  FocusManager:setFocus(self.subCategoryPages[self.FILTER.NEW]:getDescendantByName("layout"))
end

function MenuCustomContracts:updateContent()
  self.newData    = self:getContractsBasedOnFilter(MenuCustomContracts.FILTER.NEW)
  self.activeData = self:getContractsBasedOnFilter(MenuCustomContracts.FILTER.ACTIVE)
  self.yourData   = self:getContractsBasedOnFilter(MenuCustomContracts.FILTER.YOURS)

  self.newContractsList:reloadData()
  self.activeContractsList:reloadData()
  self.yourContractsList:reloadData()

  print(
    "[CustomContracts] updateContent called",
    "new:", #self.newData,
    "active:", #self.activeData,
    "yours:", #self.yourData
  )

  -- Redirect to "Yours" tab after creating a contract
  if self.redirectToYoursAfterCreate then
    self.redirectToYoursAfterCreate = false

    self:updateSubCategoryPages(MenuCustomContracts.FILTER.YOURS)
    FocusManager:setFocus(
      self.subCategoryPages[MenuCustomContracts.FILTER.YOURS]
      :getDescendantByName("layout")
    )
  end

  self:updateMenuButtons()
end

function MenuCustomContracts:onFrameClose()
  MenuCustomContracts:superClass().onFrameClose(self)
  g_messageCenter:unsubscribeAll(self)
end

function MenuCustomContracts:getNumberOfSections()
  return 1
end

function MenuCustomContracts:getNumberOfItemsInSection(list, section)
  if list == self.newContractsList then
    return #self.newData
  elseif list == self.activeContractsList then
    return #self.activeData
  elseif list == self.yourContractsList then
    return #self.yourData
  end
  return 0
end

function MenuCustomContracts:getTitleForSectionHeader()
  return ""
end

-- Handler for changes on the smoothlist selection.
function MenuCustomContracts:onListSelectionChanged(list, section, index)
  self.selectedIndex = index
  self.selectedList = list

  local contract = self:getSelectedContract()

  if list == self.yourContractsList then
    self:updateYourContractDetails(contract)
  else
    self:clearYourContractDetails()
  end

  self:updateMenuButtons()
  self:setMenuButtonInfoDirty()
end

function MenuCustomContracts:getSelectedContract()
  if self.selectedIndex == nil or self.selectedIndex < 1 then
    return nil
  end

  if self.selectedList == self.newContractsList then
    return self.newData[self.selectedIndex]
  elseif self.selectedList == self.activeContractsList then
    return self.activeData[self.selectedIndex]
  elseif self.selectedList == self.yourContractsList then
    return self.yourData[self.selectedIndex]
  end

  return nil
end

function MenuCustomContracts:updateYourContractDetails(contract)
  if contract == nil then
    self:clearYourContractDetails()
    return
  end

  local field = g_fieldManager:getFieldById(contract.fieldId)

  -- Field
  self.contractFieldValue:setText(
    string.format("Field %d", contract.fieldId)
  )
  self.contractFieldSizeValue:setText(
    string.format("%.2f ha", field.areaHa)
  )

  --Contract info
  local farm = g_farmManager:getFarmById(contract.creatorFarmId)
  if farm ~= nil then
    self.contractFarmName:setText(farm.name)
    self.contractWorkType:setText(contract.workType)
  else
    self.contractFarmName:setText("-")
    self.contractWorkType:setText("-")
  end

  local contractorFarm = g_farmManager:getFarmById(contract.contractorFarmId)
  if contractorFarm ~= nil then
    self.contractContractorValue:setText(contractorFarm.name)
  else
    self.contractContractorValue:setText("-")
  end

  self.contractWorkTypeValue:setText(contract.workType)

  self.contractRewardValue:setText(
    g_i18n:formatMoney(contract.reward, 0, true, true)
  )

  self.contractStatusValue:setText(
    g_i18n:getText("cc_status_" .. string.lower(contract.status))
    or contract.status
  )

  self.contractDescriptionValue:setText(
    contract.description or "-"
  )
end

function MenuCustomContracts:clearYourContractDetails()
  self.contractFieldValue:setText("-")
  self.contractFieldSizeValue:setText("-")
  self.contractFieldOwnerValue:setText("-")

  self.contractWorkTypeValue:setText("-")
  self.contractRewardValue:setText("-")
  self.contractStatusValue:setText("-")

  self.contractFarmName:setText("-")
  self.contractContractorValue:setText("-")

  self.contractDescriptionValue:setText("-")
end

function MenuCustomContracts:initialize()
  -- Tabs
  self.subCategoryTabs[self.FILTER.NEW]     = self.inGameMenuNew
  self.subCategoryTabs[self.FILTER.ACTIVE]  = self.inGameMenuActive
  self.subCategoryTabs[self.FILTER.YOURS]   = self.inGameMenuYours

  -- Pages
  self.subCategoryPages[self.FILTER.NEW]    = self.inGameMenuNewPage
  self.subCategoryPages[self.FILTER.ACTIVE] = self.inGameMenuActivePage
  self.subCategoryPages[self.FILTER.YOURS]  = self.inGameMenuYoursPage

  for key = 1, MenuCustomContracts.NUM_CATEGORIES do
    self.subCategoryPaging:addText(MenuCustomContracts.CATEGRORY_TEXTS[key])

    self.subCategoryTabs[key]:getDescendantByName("background")
        :setSize(self.subCategoryTabs[key].size[1], self.subCategoryTabs[key].size[2])

    self.subCategoryTabs[key].onClickCallback = function()
      self:updateSubCategoryPages(key)
    end
  end

  self.subCategoryPaging:setSize(
    self.subCategoryBox.maxFlowSize + 140 * g_pixelSizeScaledX
  )
end

function MenuCustomContracts:updateSubCategoryPages(state)
  for i, _ in ipairs(self.subCategoryPages) do
    self.subCategoryPages[i]:setVisible(false)
    self.subCategoryTabs[i]:setSelected(false)
  end
  self.subCategoryPages[state]:setVisible(true)
  self.subCategoryTabs[state]:setSelected(true)
  self.subCategoryPaging.state = state
  self.newContractsList:reloadData()
  self.activeContractsList:reloadData()
  self.yourContractsList:reloadData()

  self.currentFilter = state
  self.selectedIndex = -1
  self:updateMenuButtons()
  self:setMenuButtonInfoDirty()
end

function MenuCustomContracts:getContractsBasedOnFilter(filter)
  local farmId = g_currentMission:getFarmId()
  local filteredContracts = {}

  local contractManager = g_currentMission.customContracts.ContractManager
  if contractManager == nil then
    return filteredContracts
  end

  for _, contract in pairs(contractManager.contracts) do
    if filter == MenuCustomContracts.FILTER.NEW then
      -- Open contracts NOT created by you
      if contract.status == CustomContract.STATUS.OPEN
          and contract.creatorFarmId ~= farmId then
        table.insert(filteredContracts, contract)
      end
    elseif filter == MenuCustomContracts.FILTER.ACTIVE then
      -- Contracts accepted by you
      if contract.status == CustomContract.STATUS.ACCEPTED
          and contract.contractorFarmId == farmId then
        table.insert(filteredContracts, contract)
      end
    elseif filter == MenuCustomContracts.FILTER.YOURS then
      -- Contracts you created (any status)
      if contract.creatorFarmId == farmId then
        table.insert(filteredContracts, contract)
      end
    end
  end

  return filteredContracts
end

function MenuCustomContracts:updateMenuButtons()
  local state    = self.subCategoryPaging.state
  local farmId   = g_currentMission:getFarmId()

  local buttons  = {
    self.btnBack,
    self.btnCreateContract
  }

  local contract = nil
  if self.selectedIndex ~= nil and self.selectedIndex > 0 then
    if state == MenuCustomContracts.FILTER.NEW then
      contract = self.newData[self.selectedIndex]
    elseif state == MenuCustomContracts.FILTER.ACTIVE then
      contract = self.activeData[self.selectedIndex]
    elseif state == MenuCustomContracts.FILTER.YOURS then
      contract = self.yourData[self.selectedIndex]
    end
  end

  -- NEW → Accept
  if state == MenuCustomContracts.FILTER.NEW then
    table.insert(buttons, self.btnAccept)

    self.btnAccept.disabled =
        contract == nil
        or contract.status ~= CustomContract.STATUS.OPEN
        or contract.creatorFarmId == farmId

    -- ACTIVE → Complete
  elseif state == MenuCustomContracts.FILTER.ACTIVE then
    table.insert(buttons, self.btnComplete)

    self.btnComplete.disabled =
        contract == nil
        or contract.status ~= CustomContract.STATUS.ACCEPTED
        or contract.contractorFarmId ~= farmId

    -- YOURS → Cancel
  elseif state == MenuCustomContracts.FILTER.YOURS then
    table.insert(buttons, self.btnCancel)
    table.insert(buttons, self.btnDelete)

    self.btnCancel.disabled =
        contract == nil
        or contract.creatorFarmId ~= farmId
        or contract.status ~= CustomContract.STATUS.OPEN

    self.btnDelete.disabled =
        contract == nil
        or contract.creatorFarmId ~= farmId
  end

  self:setMenuButtonInfo(buttons)
end

-- Credits Red Tape
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

function MenuCustomContracts:populateCellForItemInSection(list, section, index, cell)
  local contract

  if list == self.newContractsList then
    contract = self.newData[index]
    self:populateNewOrActiveCell(contract, cell)
  elseif list == self.activeContractsList then
    contract = self.activeData[index]
    self:populateNewOrActiveCell(contract, cell)
  elseif list == self.yourContractsList then
    contract = self.yourData[index]
    self:populateYourContractsCell(contract, cell)
  end

  -- -- Creator farm (always exists)
  -- local creatorFarm = g_farmManager:getFarmById(contract.creatorFarmId)
  -- if creatorFarm ~= nil then
  --   cell:getAttribute("farm"):setText(creatorFarm.name)
  -- end

  -- -- Contractor farm (optional)
  -- local acceptCell = cell:getAttribute("accept")
  -- if acceptCell ~= nil then
  --   if contract.contractorFarmId ~= nil then
  --     local contractorFarm = g_farmManager:getFarmById(contract.contractorFarmId)
  --     if contractorFarm ~= nil then
  --       acceptCell:setText(contractorFarm.name)
  --     else
  --       acceptCell:setText("-")
  --     end
  --   else
  --     acceptCell:setText("-")
  --   end
  -- end

  -- cell:getAttribute("field"):setText("Field " .. contract.fieldId)
  -- cell:getAttribute("work"):setText(contract.workType)
  -- cell:getAttribute("reward"):setText(g_i18n:formatMoney(contract.reward))
  -- cell:getAttribute("status"):setText(string.lower(contract.status))
end

function MenuCustomContracts:populateNewOrActiveCell(contract, cell)
  if contract == nil then return end

  local farm = g_farmManager:getFarmById(contract.creatorFarmId)
  cell:getAttribute("farm"):setText(farm and farm.name or "-")
  cell:getAttribute("field"):setText("Field " .. contract.fieldId)
  cell:getAttribute("work"):setText(contract.workType)
  cell:getAttribute("reward"):setText(g_i18n:formatMoney(contract.reward))
  cell:getAttribute("status"):setText(string.lower(contract.status))

  local acceptCell = cell:getAttribute("accept")
  if acceptCell ~= nil then
    if contract.contractorFarmId then
      local contractor = g_farmManager:getFarmById(contract.contractorFarmId)
      acceptCell:setText(contractor and contractor.name or "-")
    else
      acceptCell:setText("-")
    end
  end
end

function MenuCustomContracts:populateYourContractsCell(contract, cell)
  if contract == nil then return end

  local farm = g_farmManager:getFarmById(contract.creatorFarmId)

  -- Contract details
  cell:getAttribute("field"):setText("Field " .. contract.fieldId)
  cell:getAttribute("reward"):setText(g_i18n:formatMoney(contract.reward))
end

function MenuCustomContracts:onCreateContract()
  self.redirectToYoursAfterCreate = true
  local dialog = g_gui:showDialog("menuCreateContract")
end

function MenuCustomContracts:onCompleteContract()
  if self.selectedIndex < 1 then return end

  local contract = self.activeData[self.selectedIndex]
  if contract == nil then return end

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
  if self.selectedIndex == nil or self.selectedIndex < 1 then
    InfoDialog.show("No contract selected")
    return
  end

  local contract
  if self.selectedList == self.newContractsList then
    contract = self.newData[self.selectedIndex]
  elseif self.selectedList == self.activeContractsList then
    contract = self.activeData[self.selectedIndex]
  elseif self.selectedList == self.yourContractsList then
    contract = self.yourData[self.selectedIndex]
  end
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
  if self.selectedIndex < 1 then return end

  local contract = self.yourData[self.selectedIndex]
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
  if self.selectedIndex < 1 then return end

  local contract = self.yourData[self.selectedIndex]
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
