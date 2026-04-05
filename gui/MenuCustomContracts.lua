--
-- FS25 Contract and Invoices
--
-- @Author: Racc00n
-- @Version: 1.0.0.0
--

MenuCustomContracts = {}
MenuCustomContracts._mt = Class(MenuCustomContracts, TabbedMenuFrameElement)

MenuCustomContracts.SUB_CATEGORY = {
  CONTRACTS = 1,
  INVOICES = 2,
  NOTIFICATIONS = 3,
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
  [MenuCustomContracts.SUB_CATEGORY.NOTIFICATIONS] = "cc_header_notifications",
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

--- Base-game field mission map circle (see AbstractFieldMissionHotspot: red overlay + IngameMap.alpha blink).
local function createAbstractFieldMissionCircleHotspot()
  if AbstractFieldMissionHotspot == nil then
    return nil
  end
  local ok, h = pcall(function()
    return AbstractFieldMissionHotspot.new()
  end)
  return ok and h or nil
end

local function createMissionMapHotspot()
  if MissionHotspot == nil then
    return nil
  end
  local ok, h = pcall(function()
    return MissionHotspot.new()
  end)
  return ok and h or nil
end

--- Rough world radius (meters) from farmland size; capped so the circle stays a hint, not the whole field.
local function worldRadiusFromFarmlandHa(areaHa)
  if areaHa == nil or areaHa <= 0 then
    return 50
  end
  local areaSqm = areaHa * 10000
  local r = math.sqrt(areaSqm / math.pi)
  return math.max(25, math.min(r, 20))
end

--- Field-work preview: prefer AbstractFieldMissionHotspot:setField(field) when the API exposes a field for this farmland.
local function setupFieldWorkCircleHotspot(hotspot, contract, farmland)
  if hotspot == nil or farmland == nil or contract == nil then
    return
  end
  g_currentMission:addMapHotspot(hotspot)
  local usedSetField = false
  if g_fieldManager ~= nil and contract.farmlandId ~= nil and hotspot.setField ~= nil then
    local field = nil
    if g_fieldManager.getFieldByFarmlandId ~= nil then
      field = g_fieldManager:getFieldByFarmlandId(contract.farmlandId)
    elseif g_fieldManager.getFieldByFarmland ~= nil then
      field = g_fieldManager:getFieldByFarmland(contract.farmlandId)
    end
    if field ~= nil then
      usedSetField = pcall(function()
        hotspot:setField(field)
      end)
    end
  end
  if not usedSetField then
    hotspot:setWorldPosition(farmland.xWorldPos, farmland.zWorldPos)
  end
  if hotspot.setWorldRadius ~= nil then
    hotspot:setWorldRadius(worldRadiusFromFarmlandHa(farmland.areaInHa))
  end
end

function MenuCustomContracts.new(i18n, messageCenter)
  local self = MenuCustomContracts:superClass().new(nil, MenuCustomContracts._mt)
  self.name = "MenuCustomContracts"
  self.i18n = i18n
  self.messageCenter = messageCenter
  self.menuButtonInfo = {}

  -- Intialize renderers
  self.contractsRenderer = ContractsRenderer.new()
  self.contractDetailsRenderer = ContractsDetailsRenderer.new()
  self.invoicesInboxRenderer = InvoicesInboxRenderer.new()
  self.invoicesOutboxRenderer = InvoicesOutboxRenderer.new()
  self.notificationsRenderer = NotificationsRenderer.new()

  -- Contract map: AbstractFieldMissionHotspot = blinking red circle (base field-mission style).
  -- PickDestinationMapDialog keeps AITargetHotspot for choosing a transport destination only.
  self.fieldWorkFieldCircleHotspot = createAbstractFieldMissionCircleHotspot()
  self.transportPickupFieldCircleHotspot = createAbstractFieldMissionCircleHotspot()
  self.transportDropoffFieldCircleHotspot = createAbstractFieldMissionCircleHotspot()
  -- Transport: base-game ! markers (TransportMission:createHotspot) in addition to red circles.
  self.transportPickupMissionHotspot = createMissionMapHotspot()
  self.transportDropoffMissionHotspot = createMissionMapHotspot()

  -- Cached farm inventory for GUI and contract creation (refreshed when menu opens).
  self.cachedInventory = { byFillType = {}, list = {} }

  return self
end

--- Map hotspots are global on the HUD ingame map; remove when switching contract, closing menu, or clearing preview.
function MenuCustomContracts:clearContractMapPreviewHotspots()
  if self.fieldWorkFieldCircleHotspot ~= nil then
    g_currentMission:removeMapHotspot(self.fieldWorkFieldCircleHotspot)
  end
  if self.transportPickupFieldCircleHotspot ~= nil then
    g_currentMission:removeMapHotspot(self.transportPickupFieldCircleHotspot)
  end
  if self.transportDropoffFieldCircleHotspot ~= nil then
    g_currentMission:removeMapHotspot(self.transportDropoffFieldCircleHotspot)
  end
  if self.transportPickupMissionHotspot ~= nil then
    g_currentMission:removeMapHotspot(self.transportPickupMissionHotspot)
  end
  if self.transportDropoffMissionHotspot ~= nil then
    g_currentMission:removeMapHotspot(self.transportDropoffMissionHotspot)
  end
end

function MenuCustomContracts:clearContractMapTransportHotspot()
  self:clearContractMapPreviewHotspots()
end

function MenuCustomContracts:clearContractMapPreviewClip()
  local hudMap = g_currentMission.hud and g_currentMission.hud:getIngameMap() or nil
  if hudMap ~= nil then
    hudMap.clipHotspots = false
    hudMap:setMapClipArea(nil, nil, nil, nil)
  end
end

function MenuCustomContracts:displaySelectedContract()
  local index = self.contractsTable.selectedIndex
  local selection = self.contractDisplaySwitcher:getState()

  if index ~= -1 then
    local contractByFlat = self.contractsRenderer.data and self.contractsRenderer.data[selection] and
        self.contractsRenderer.data[selection][index]
    local contractBySection = nil
    local r = self.contractsRenderer
    if r and r.sectionContracts and r.selectedSection and r.selectedRow then
      local secs = r.sectionContracts[selection]
      if secs and secs[r.selectedSection] then
        contractBySection = secs[r.selectedSection].contracts[r.selectedRow]
      end
    end
    local contractByFlatInSections = r and r:getContractAtFlatIndex(selection, index)
    local contract = contractBySection or contractByFlatInSections or contractByFlat

    if contract ~= nil then
      self.contractsInfoContainer:setVisible(true)
      self.noSelectedContractText:setVisible(false)

      self:clearContractMapPreviewHotspots()

      -- Ensure ingame map is set before using the preview
      local hudMap = g_currentMission.hud and g_currentMission.hud:getIngameMap() or nil
      if hudMap ~= nil then
        self.contractMap:setIngameMap(hudMap)
        self.contractMap.drawHotspots = true

        -- Center map depending on contract template
        if contract.templateId == CustomContract.TEMPLATE.TRANSPORT then
          local destX = contract.destinationX
          local destZ = contract.destinationZ
          local pickupX, pickupZ = nil, nil
          if FarmInventoryHelper ~= nil and contract.creatorFarmId ~= nil and contract.fillTypeIndex ~= nil then
            pickupX, pickupZ = FarmInventoryHelper.getPrimaryPickupWorldXZ(contract.creatorFarmId, contract
              .fillTypeIndex)
          end
          local transportCircleR = math.min(50, 85)
          if self.transportPickupFieldCircleHotspot ~= nil and pickupX ~= nil and pickupZ ~= nil then
            g_currentMission:addMapHotspot(self.transportPickupFieldCircleHotspot)
            self.transportPickupFieldCircleHotspot:setWorldPosition(pickupX, pickupZ)
            if self.transportPickupFieldCircleHotspot.setWorldRadius ~= nil then
              self.transportPickupFieldCircleHotspot:setWorldRadius(transportCircleR)
            end
          end
          if self.transportDropoffFieldCircleHotspot ~= nil and destX ~= nil and destZ ~= nil then
            g_currentMission:addMapHotspot(self.transportDropoffFieldCircleHotspot)
            self.transportDropoffFieldCircleHotspot:setWorldPosition(destX, destZ)
            if self.transportDropoffFieldCircleHotspot.setWorldRadius ~= nil then
              self.transportDropoffFieldCircleHotspot:setWorldRadius(transportCircleR)
            end
          end
          if self.transportPickupMissionHotspot ~= nil and pickupX ~= nil and pickupZ ~= nil then
            g_currentMission:addMapHotspot(self.transportPickupMissionHotspot)
            self.transportPickupMissionHotspot:setWorldPosition(pickupX, pickupZ)
          end
          if self.transportDropoffMissionHotspot ~= nil and destX ~= nil and destZ ~= nil then
            g_currentMission:addMapHotspot(self.transportDropoffMissionHotspot)
            self.transportDropoffMissionHotspot:setWorldPosition(destX, destZ)
          end
          local hasBoth = pickupX ~= nil and pickupZ ~= nil and destX ~= nil and destZ ~= nil
          if hasBoth and self.contractMap.fitToBoundary ~= nil then
            local minX = math.min(pickupX, destX)
            local maxX = math.max(pickupX, destX)
            local minZ = math.min(pickupZ, destZ)
            local maxZ = math.max(pickupZ, destZ)
            local pad = transportCircleR + 30
            minX, maxX = minX - pad, maxX + pad
            minZ, maxZ = minZ - pad, maxZ + pad
            if maxX - minX < 40 then
              local m = (minX + maxX) * 0.5
              minX, maxX = m - 20, m + 20
            end
            if maxZ - minZ < 40 then
              local m = (minZ + maxZ) * 0.5
              minZ, maxZ = m - 20, m + 20
            end
            local fitOk = pcall(function()
              self.contractMap:fitToBoundary(minX, maxX, minZ, maxZ, 0.12)
            end)
            if not fitOk then
              self.contractMap:setCenterToWorldPosition((minX + maxX) * 0.5, (minZ + maxZ) * 0.5)
            end
          else
            local centerX, centerZ = destX, destZ
            if hasBoth then
              centerX = (pickupX + destX) * 0.5
              centerZ = (pickupZ + destZ) * 0.5
            elseif pickupX ~= nil and pickupZ ~= nil and (destX == nil or destZ == nil) then
              centerX, centerZ = pickupX, pickupZ
            end
            if centerX ~= nil and centerZ ~= nil then
              self.contractMap:setCenterToWorldPosition(centerX, centerZ)
            end
          end
        else
          local farmland = g_farmlandManager:getFarmlandById(contract.farmlandId)
          if farmland ~= nil and farmland.xWorldPos ~= nil and farmland.zWorldPos ~= nil then
            if contract.templateId == CustomContract.TEMPLATE.FIELD_WORK then
              setupFieldWorkCircleHotspot(self.fieldWorkFieldCircleHotspot, contract, farmland)
            end
            self.contractMap:setCenterToWorldPosition(farmland.xWorldPos, farmland.zWorldPos)
          end
        end

        -- Clip the HUD ingame map to the preview rect
        if self.contractMap.ingameMap ~= nil then
          local posStartX = self.contractMap.absPosition[1]
          local posStartY = self.contractMap.absPosition[2]
          local posEndX = posStartX + self.contractMap.absSize[1]
          local posEndY = posStartY + self.contractMap.absSize[2]
          self.contractMap.ingameMap:setMapClipArea(posStartX, posStartY, posEndX, posEndY)
          self.contractMap.ingameMap.clipHotspots = true
        end
      end

      --Contract info
      local farm = g_farmManager:getFarmById(contract.creatorFarmId)
      if farm ~= nil then
        -- self.contractId:setText(string.format(g_i18n:getText("cc_contract_id_label"), contract.id))
        self.contractFarmImage:setImageSlice(nil, farm:getIconSliceId())
        self.contractFarmName:setText(farm.name)
        self.contractWorkType:setText(g_i18n:getText("cc_workareatype_" .. string.lower(contract:getWorkTypeAreaName())) or
          contract:getWorkTypeAreaName())
      else
        self.contractFarmName:setText("-")
        self.contractWorkType:setText("-")
      end

      self.contractRewardValue:setText(
        g_i18n:formatMoney(contract.reward, 0, true, true)
      )

      -- Populate contract details SmoothList
      if self.contractDetailsRenderer ~= nil and self.contractDetailsList ~= nil then
        self.contractDetailsRenderer:setFromContract(contract)
        self.contractDetailsList:reloadData()
      end

      -- local statusText
      -- local statusTextLabel

      -- if contract.contractorFarmId ~= nil then
      --   local contractorFarm = g_farmManager:getFarmById(contract.contractorFarmId)

      --   if contractorFarm ~= nil and contract.status ~= CustomContract.STATUS.EXPIRED and contract.status ~= CustomContract.STATUS.CANCELLED and contract.status ~= CustomContract.STATUS.COMPLETED and contract.status ~= CustomContract.STATUS.INVOICED and contract.status ~= CustomContract.STATUS.COMPLETED_AWAITING_INVOICE then
      --     statusTextLabel = g_i18n:getText("cc_contract_status_label")
      --     statusText = contractorFarm.name
      --   else
      --     statusTextLabel = g_i18n:getText("cc_contract_status_label_default")
      --     statusText = g_i18n:getText("cc_status_" .. string.lower(contract.status))
      --         or contract.status
      --   end
      -- else
      --   statusTextLabel = string.format(g_i18n:getText("cc_contract_status_label_default"))
      --   statusText = g_i18n:getText("cc_status_" .. string.lower(contract.status))
      --       or contract.status
      -- end

      -- self.contractStatusValue:setText(statusText)
      -- self.contractStatusLabel:setText(statusTextLabel)

      -- self.contractNotesValue:setText(
      --   contract.description or "-"
      -- )

      self.contractDescriptionValue:setText(contract:getDescriptionText())
    else
      self:clearContractMapPreviewHotspots()
      self:clearContractMapPreviewClip()
      self.contractsInfoContainer:setVisible(false)
      self.noSelectedContractText:setVisible(true)
    end
  else
    self:clearContractMapPreviewHotspots()
    self:clearContractMapPreviewClip()
  end
end

function MenuCustomContracts:onGuiSetupFinished()
  MenuCustomContracts:superClass().onGuiSetupFinished(self)

  -- Contracts list (left) uses ContractsRenderer
  self.contractsTable:setDataSource(self.contractsRenderer)
  self.contractsTable:setDelegate(self.contractsRenderer)

  -- Contract details SmoothList inside CC_ContractContractBox
  if self.contractDetailsList ~= nil then
    self.contractDetailsList:setDataSource(self.contractDetailsRenderer)
    self.contractDetailsList:setDelegate(self.contractDetailsRenderer)
  end

  -- Notifications table
  self.notificationsTable:setDataSource(self.notificationsRenderer)
  self.notificationsTable:setDelegate(self.notificationsRenderer)

  -- Invoice inbox/outbox tables
  self.inboxInvoicesTable:setDataSource(self.invoicesInboxRenderer)
  self.inboxInvoicesTable:setDelegate(self.invoicesInboxRenderer)

  self.outboxInvoicesTable:setDataSource(self.invoicesOutboxRenderer)
  self.outboxInvoicesTable:setDelegate(self.invoicesOutboxRenderer)

  self.contractsRenderer.indexChangedCallback = function(section, index)
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
    text = g_i18n:getText("cc_btn_create_invoice"),
    callback = function()
      self
          :onCreateInvoice()
    end
  }
  self.btnPayInvoice = {
    inputAction = InputAction.MENU_ACCEPT,
    text = g_i18n:getText("cc_btn_pay_invoice"),
    callback = function()
      self
          :onPayInvoice()
    end
  }
  self.btnDetailInvoice = {
    inputAction = InputAction.MENU_ACTIVATE,
    text = g_i18n:getText("cc_btn_detail_invoice"),
    callback = function()
      self
          :onDetailInvoice()
    end
  }
  self.btnSentInvoice = {
    inputAction = InputAction.MENU_EXTRA_2,
    text = g_i18n:getText("cc_btn_send_invoice"),
    callback = function()
      self
          :onSentInvoice()
    end
  }
  self.btnDeleteInvoice = {
    inputAction = InputAction.MENU_CANCEL,
    text = g_i18n:getText("cc_btn_delete_invoice"),
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

  self.menuButtonInfo[MenuCustomContracts.SUB_CATEGORY.NOTIFICATIONS] = {
    self.btnBack
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
  self.contractMap:setIngameMap(g_currentMission.hud:getIngameMap())
  self.contractMap.drawHotspots = true


  local texts = {}
  for k, tab in pairs(self.subCategoryTabs) do
    tab:setVisible(true)
    table.insert(texts, tostring(k))
  end
  self.subCategoryBox:invalidateLayout()
  self.subCategoryPaging:setTexts(texts)
  self.subCategoryPaging:setSize(self.subCategoryBox.maxFlowSize + 140 * g_pixelSizeScaledX)

  FocusManager:setFocus(self.contractsTable)
  self:refreshInventory()
  self:onMoneyChange()
  g_messageCenter:subscribe(MessageType.MONEY_CHANGED, self.onMoneyChange, self)
  g_messageCenter:subscribe(MessageType.CUSTOM_CONTRACTS_UPDATED, self.updateContent, self)
  g_messageCenter:subscribe(MessageType.INVOICES_UPDATED, self.updateContent, self)
  g_messageCenter:subscribe(MessageType.NOTIFICATIONS_UPDATED, self.updateContent, self)
  self:updateContent()
  self:setMenuButtonInfoDirty()
end

--- Refreshes the cached farm inventory snapshot (silos, etc.) for display and contract creation.
function MenuCustomContracts:refreshInventory()
  local farmId = g_currentMission:getFarmId()
  self.cachedInventory = FarmInventoryHelper.retrieveFarmInventory(farmId)
end

function MenuCustomContracts:onFrameClose()
  self:clearContractMapTransportHotspot()
  self:clearContractMapPreviewClip()
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

function MenuCustomContracts:onClickNotifications()
  self.subCategoryPaging:setState(MenuCustomContracts.SUB_CATEGORY.NOTIFICATIONS, true)
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

  -- Contracts page
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

  -- Invoices page
  if state == MenuCustomContracts.SUB_CATEGORY.INVOICES then
    local invoiceManager = g_currentMission.CustomContracts.InvoiceManager

    local invoices = invoiceManager:getInboundInvoicesByCurrentFarm()
    self.invoicesInboxRenderer:setData(invoices)
    self.inboxInvoicesTable:reloadData()

    local outboxInvoices = invoiceManager:getOutboundInvoicesByCurrentFarm()
    self.invoicesOutboxRenderer:setData(outboxInvoices)
    self.outboxInvoicesTable:reloadData()
  end

  -- Notifications page
  if state == MenuCustomContracts.SUB_CATEGORY.NOTIFICATIONS then
    local notifications = g_currentMission.CustomContracts.NotificationManager:getNotificationsByCurrentFarm()
    self.notificationsRenderer:setData(notifications)
    self.notificationsTable:reloadData()
  end

  self:updateMenuButtons()
end

function MenuCustomContracts:updateMenuButtons()
  local subCategory = self.subCategoryPaging:getState()

  -- If player is not in a farm (spectator), only allow backing out of the menu.
  local currentMission = g_currentMission
  local myFarmId = currentMission and currentMission:getFarmId() or nil
  local isSpectator = (myFarmId == nil or myFarmId == FarmManager.SPECTATOR_FARM_ID)

  if isSpectator then
    self.menuButtonInfo[subCategory] = { self.btnBack }
    self:setMenuButtonInfoDirty()
    return
  end

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

  if subCategory == MenuCustomContracts.SUB_CATEGORY.NOTIFICATIONS then
    self.menuButtonInfo[subCategory] = { self.btnBack }
    return
  end
end

function MenuCustomContracts:getSelectedContract()
  local index = self.contractsTable.selectedIndex
  if index == nil or index < 1 then
    return nil
  end

  local selection = self.contractDisplaySwitcher:getState()
  local r = self.contractsRenderer
  local contract = nil
  if r and r.selectedSection and r.selectedRow then
    local secs = r.sectionContracts and r.sectionContracts[selection]
    if secs and secs[r.selectedSection] then
      contract = secs[r.selectedSection].contracts[r.selectedRow]
    end
  end
  if not contract and r then
    contract = r:getContractAtFlatIndex(selection, index)
  end
  if not contract then
    local list = r and r.data and r.data[selection]
    contract = list and list[index]
  end
  return contract
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
  local myFarmId = g_currentMission:getFarmId()

  if button == self.btnBack then return true end

  if button == self.btnCreateContract then return true end

  -- No selected contract => only back + create
  if contract == nil then return false end

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

-- Function triggered when clicking on the "View details" button
function MenuCustomContracts:onDetailInvoice()
  local invoice = self:getSelectedInvoice()
  if invoice == nil then
    return
  end

  DetailInvoiceDialog.show(invoice)
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

  local options = {
    g_i18n:getText("cc_dialog_template_field_work"),
    g_i18n:getText("cc_dialog_template_transport"),
    -- g_i18n:getText("cc_dialog_template_farmjob"),
    -- g_i18n:getText("cc_dialog_template_custom"),
  }
  local callback = function(templateId)
    if templateId == 1 then
      if g_farmlandManager:getNumOwnedFarmlandIdsByFarmId(g_currentMission:getFarmId()) > 0 then
        CreateContractDialog.show()
      else
        InfoDialog.show(g_i18n:getText("cc_dialog_template_no_farmland"))
      end
    elseif templateId == 2 then
      self:refreshInventory()
      if self.cachedInventory.list ~= nil and #self.cachedInventory.list > 0 then
        CreateTransportContractDialog.show(self.cachedInventory.list)
      else
        InfoDialog.show(g_i18n:getText("cc_dialog_template_no_inventory"))
      end
    elseif templateId == 3 then
      InfoDialog.show(g_i18n:getText("cc_dialog_template_coming_soon"))
    elseif templateId == 4 then
      InfoDialog.show(g_i18n:getText("cc_dialog_template_coming_soon"))
    end
  end

  OptionDialog.show(callback, g_i18n:getText("cc_dialog_template_subtitle"),
    g_i18n:getText("cc_dialog_template_title"), options)
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
      g_i18n:getText("cc_workareatype_" ..
        string.lower(contract:getWorkTypeAreaName(contract.workAreaTypeIndex))),
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
  local contractByFlat = self.contractsRenderer.data and self.contractsRenderer.data[selection] and
      self.contractsRenderer.data[selection][index]
  local contractBySection = nil
  local r = self.contractsRenderer
  if r and r.sectionContracts and r.selectedSection and r.selectedRow then
    local secs = r.sectionContracts[selection]
    if secs and secs[r.selectedSection] then
      contractBySection = secs[r.selectedSection].contracts[r.selectedRow]
    end
  end
  local contractByFlatInSections = r and r:getContractAtFlatIndex(selection, index)
  local contract = contractBySection or contractByFlatInSections or contractByFlat

  if contract == nil then
    return
  end

  if contract.templateId == CustomContract.TEMPLATE.TRANSPORT then
    EditTransportContractDialog.show(contract)
  else
    EditFieldWorkContractDialog.show(contract)
  end
end
