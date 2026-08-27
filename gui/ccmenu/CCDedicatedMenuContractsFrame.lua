--
-- Contracts tab of the dedicated Shift+I menu.
--

CCDedicatedMenuContractsFrame = {}
local CCDedicatedMenuContractsFrame_mt = Class(CCDedicatedMenuContractsFrame, TabbedMenuFrameElement)

local modDirectory = g_currentModDirectory

CCDedicatedMenuContractsFrame.CONTRACTS_LIST_TYPE = {
  NEW = 1,
  ACTIVE = 2,
  OWNED = 3,
  COMPLETED = 4
}

CCDedicatedMenuContractsFrame.CONTRACTS_STATE_TEXTS = { "cc_new", "cc_active", "cc_owned", "cc_completed" }

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

local function worldRadiusFromFarmlandHa(areaHa)
  if areaHa == nil or areaHa <= 0 then
    return 50
  end
  local areaSqm = areaHa * 10000
  local r = math.sqrt(areaSqm / math.pi)
  return math.max(25, math.min(r, 20))
end

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

function CCDedicatedMenuContractsFrame.new()
  local self = CCDedicatedMenuContractsFrame:superClass().new(nil, CCDedicatedMenuContractsFrame_mt)
  self.name = "CCDedicatedMenuContractsFrame"
  self.hasCustomMenuButtons = true
  self.isFrameOpen = false

  self.contractsListDelegate = CCDedicatedContractsListDelegate.new(self)
  self.contractDetailsRenderer = ContractsDetailsRenderer.new()
  self.contractVehicleElements = {}
  self.marqueeTime = 0

  self.fieldWorkFieldCircleHotspot = createAbstractFieldMissionCircleHotspot()
  self.transportPickupFieldCircleHotspot = createAbstractFieldMissionCircleHotspot()
  self.transportDropoffFieldCircleHotspot = createAbstractFieldMissionCircleHotspot()
  self.transportPickupMissionHotspot = createMissionMapHotspot()
  self.transportDropoffMissionHotspot = createMissionMapHotspot()

  self.cachedInventory = { byFillType = {}, list = {} }
  self.backButtonInfo = { inputAction = InputAction.MENU_BACK }

  self.btnCreateInvoice = {
    inputAction = InputAction.MENU_EXTRA_1,
    text = g_i18n:getText("cc_btn_create_invoice"),
    callback = function()
      self:onCreateInvoice()
    end
  }
  self.btnCreateContract = {
    inputAction = InputAction.MENU_EXTRA_1,
    text = g_i18n:getText("cc_btn_create_contract"),
    callback = function()
      self:onCreateContract()
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
  self.contractButtonSets[CCDedicatedMenuContractsFrame.CONTRACTS_LIST_TYPE.NEW] = {
    self.backButtonInfo,
    self.btnAccept,
    self.btnCreateContract
  }
  self.contractButtonSets[CCDedicatedMenuContractsFrame.CONTRACTS_LIST_TYPE.ACTIVE] = {
    self.backButtonInfo,
    self.btnComplete,
    self.btnCancel,
    self.btnCreateInvoice,
    self.btnCreateContract
  }
  self.contractButtonSets[CCDedicatedMenuContractsFrame.CONTRACTS_LIST_TYPE.OWNED] = {
    self.backButtonInfo,
    self.btnDelete,
    self.btnCancel,
    self.btnReopen,
    self.btnEdit,
    self.btnCreateContract
  }
  self.contractButtonSets[CCDedicatedMenuContractsFrame.CONTRACTS_LIST_TYPE.COMPLETED] = {
    self.backButtonInfo,
    self.btnDelete,
    self.btnCreateInvoice,
    self.btnCreateContract
  }

  self.menuButtonInfo = { self.backButtonInfo }
  self.pendingContractsListType = nil
  self.pendingFocusContractId = nil

  return self
end

function CCDedicatedMenuContractsFrame.setupGui()
  local frame = CCDedicatedMenuContractsFrame.new()
  g_gui:loadGui(
    Utils.getFilename("gui/ccmenu/ccDedicatedMenuContractsFrame.xml", modDirectory),
    "CCDedicatedMenuContractsFrame",
    frame,
    true
  )
end

-- The HUD IngameMap is shared: setIngameMap() immediately calls ingameMap:setCustomLayout() on it
-- (see IngameMapPreviewElement:setIngameMap). Linking during loadMap would hijack the world map
-- before the player opens this menu; only link in onFrameOpen and release in onFrameClose.
function CCDedicatedMenuContractsFrame:linkContractMapPreviewToHud()
  if self.contractMap == nil then
    return false
  end
  if g_currentMission ~= nil and g_currentMission.hud ~= nil then
    local hudMap = g_currentMission.hud:getIngameMap()
    if hudMap ~= nil then
      self.contractMap:setIngameMap(hudMap)
      self.contractMap.drawHotspots = true
      if self.mapBox ~= nil then
        self.mapBox:setVisible(true)
      end
      return true
    end
  end
  if self.mapBox ~= nil then
    self.mapBox:setVisible(false)
  end
  return false
end

function CCDedicatedMenuContractsFrame:onGuiSetupFinished()
  CCDedicatedMenuContractsFrame:superClass().onGuiSetupFinished(self)

  self.contractsTable:setDataSource(self.contractsListDelegate)
  self.contractsTable:setDelegate(self.contractsListDelegate)

  if self.contractDetailsList ~= nil then
    self.contractDetailsList:setDataSource(self.contractDetailsRenderer)
    self.contractDetailsList:setDelegate(self.contractDetailsRenderer)
  end

  self.contractsListDelegate.indexChangedCallback = function()
    self:displaySelectedContract()
    self:updateMenuButtons()
  end

  -- SmoothList queries the delegate before first updateContent(); empty tables avoid nil crashes.
  self.contractsListDelegate:setData({
    [CCDedicatedMenuContractsFrame.CONTRACTS_LIST_TYPE.NEW] = {},
    [CCDedicatedMenuContractsFrame.CONTRACTS_LIST_TYPE.ACTIVE] = {},
    [CCDedicatedMenuContractsFrame.CONTRACTS_LIST_TYPE.OWNED] = {},
    [CCDedicatedMenuContractsFrame.CONTRACTS_LIST_TYPE.COMPLETED] = {},
  })
end

function CCDedicatedMenuContractsFrame:initialize()
  CCDedicatedMenuContractsFrame:superClass().initialize(self)

  if self.contractsFilterDots ~= nil then
    for i = 1, #self.contractsFilterDots.elements do
      self.contractsFilterDots.elements[i].getIsSelected = function()
        return self.contractDisplaySwitcher:getState() == i
      end
    end
    self.contractsFilterDots:invalidateLayout()
  end

  if self.contractDisplaySwitcher ~= nil then
    local contractSwitcherTexts = {}
    for i = 1, #CCDedicatedMenuContractsFrame.CONTRACTS_STATE_TEXTS do
      table.insert(contractSwitcherTexts, g_i18n:getText(CCDedicatedMenuContractsFrame.CONTRACTS_STATE_TEXTS[i]))
    end
    self.contractDisplaySwitcher:setTexts(contractSwitcherTexts)
  end

  self.currentContractsListType = self.contractDisplaySwitcher:getState()
      or CCDedicatedMenuContractsFrame.CONTRACTS_LIST_TYPE.NEW

  if self.contractVehicleTemplate ~= nil then
    self.contractVehicleTemplate:unlinkElement()
  end

  self:updateMenuButtons()
end

function CCDedicatedMenuContractsFrame:update(dt)
  CCDedicatedMenuContractsFrame:superClass().update(self, dt)
  if self.isFrameOpen and self.contractEquipmentBox ~= nil and self.contractEquipmentBox:getIsVisible() then
    self:updateContractVehicleMarquee(dt)
  end
end

function CCDedicatedMenuContractsFrame:getMenuButtonInfo()
  return self.menuButtonInfo
end

--- Runs from fs25_menuContainer#onOpen before any child opens. Required when the menu is shown again:
--- PagingElement:onOpen only walks pageRoot:onOpen (no TabbedMenu:onPageChange), so onFrameOpen may
--- not run and IngameMapPreview:onOpen would otherwise see nil ingameMap.
function CCDedicatedMenuContractsFrame:onContractsPageRootOpen(element)
  self:linkContractMapPreviewToHud()
end

function CCDedicatedMenuContractsFrame:onFrameOpen()
  -- Bind HUD map before TabbedMenuFrameElement:onFrameOpen runs controller:onOpen (subtree).
  self:linkContractMapPreviewToHud()

  CCDedicatedMenuContractsFrame:superClass().onFrameOpen(self)
  self.isFrameOpen = true

  FocusManager:setFocus(self.contractsTable)
  self:refreshInventory()
  self:onMoneyChange()
  g_messageCenter:subscribe(MessageType.MONEY_CHANGED, self.onMoneyChange, self)
  g_messageCenter:subscribe(MessageType.CUSTOM_CONTRACTS_UPDATED, self.updateContent, self)
  g_messageCenter:subscribe(MessageType.CUSTOM_CONTRACT_PROGRESS_UPDATED, self.onContractProgressUpdated, self)
  self:updateContent()
  self:setMenuButtonInfoDirty()
end

function CCDedicatedMenuContractsFrame:onFrameClose()
  self:clearContractVehicleElements()
  self:clearContractMapPreviewHotspots()
  -- Must run super.onFrameClose first: IngameMapPreview:onClose clears HUD layout on ingameMap.
  -- Do NOT call contractMap:setIngameMap(nil) after this: TabbedMenu:onClose also runs
  -- PagingElement:onClose → pageRoot:onClose() a second time on the same tree; if preview.ingameMap
  -- was nilled, IngameMapPreview:onClose hits nil:setCustomLayout(nil) and crashes.
  CCDedicatedMenuContractsFrame:superClass().onFrameClose(self)
  if self.mapBox ~= nil then
    self.mapBox:setVisible(false)
  end
  g_messageCenter:unsubscribeAll(self)
  self.isFrameOpen = false
end

function CCDedicatedMenuContractsFrame:refreshInventory()
  local farmId = g_currentMission:getFarmId()
  self.cachedInventory = FarmInventoryHelper.retrieveFarmInventory(farmId)
end

function CCDedicatedMenuContractsFrame:clearContractMapPreviewHotspots()
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

function CCDedicatedMenuContractsFrame:clearContractMapPreviewClip()
  local hudMap = g_currentMission.hud and g_currentMission.hud:getIngameMap() or nil
  if hudMap ~= nil then
    hudMap.clipHotspots = false
    hudMap:setMapClipArea(nil, nil, nil, nil)
  end
end

function CCDedicatedMenuContractsFrame:clearContractVehicleElements()
  if self.contractVehicleElements == nil then
    self.contractVehicleElements = {}
  end
  for _, elem in pairs(self.contractVehicleElements) do
    elem:delete()
  end
  self.contractVehicleElements = {}
  self.marqueeTime = 0
  if self.contractVehiclesBox ~= nil then
    self.contractVehiclesBox:invalidateLayout()
    if self.contractVehiclesBox.setPivot ~= nil then
      self.contractVehiclesBox:setPivot(0.5, 0.5)
    end
    if self.contractVehiclesBox.setPosition ~= nil then
      self.contractVehiclesBox:setPosition(0)
    end
  end
end

function CCDedicatedMenuContractsFrame:populateContractVehicleElements(contract)
  self:clearContractVehicleElements()

  if contract == nil
      or self.contractVehicleTemplate == nil
      or self.contractVehiclesBox == nil then
    return
  end

  local entries = contract.transportVehicleEntries or {}
  local totalWidth = 0

  for _, entry in ipairs(entries) do
    local imageFilename = entry.imageFilename
    if imageFilename ~= nil and imageFilename ~= "" then
      local element = self.contractVehicleTemplate:clone(self.contractVehiclesBox)
      element:setImageFilename(imageFilename)
      element:setImageColor(nil, nil, nil, nil, 1)
      totalWidth = totalWidth + element.absSize[1] + element.margin[1] + element.margin[3]
      table.insert(self.contractVehicleElements, element)
    end
  end

  self.contractVehiclesBox:setSize(totalWidth)
  self.contractVehiclesBox:invalidateLayout()

  local parent = self.contractVehiclesBox.parent
  if parent ~= nil
      and parent.absSize ~= nil
      and parent.absSize[1] < self.contractVehiclesBox.maxFlowSize
      and self.contractVehiclesBox.pivot[1] ~= 0 then
    self.contractVehiclesBox:setPivot(0, 0.5)
    self.contractVehiclesBox:setPosition(0)
  end
end

function CCDedicatedMenuContractsFrame:updateContractVehicleMarquee(dt)
  if self.contractVehiclesBox == nil or self.contractVehiclesBox.parent == nil then
    return
  end

  local contentWidth = self.contractVehiclesBox.absSize[1]
  local visibleWidth = self.contractVehiclesBox.parent.absSize[1]
  local scrollAmount = contentWidth - visibleWidth
  local scrollLengthFactor = contentWidth / visibleWidth

  if scrollLengthFactor <= 1 then
    return
  end

  local scrollDuration = 5000 * scrollLengthFactor
  self.marqueeTime = self.marqueeTime + dt
  if scrollDuration <= self.marqueeTime then
    self.marqueeTime = -scrollDuration
  end

  local alpha = MathUtil.smoothstep(0.2, 0.8, math.abs(self.marqueeTime) / scrollDuration)
  local offset = scrollAmount * alpha
  self.contractVehiclesBox:setPosition(-offset)
end

function CCDedicatedMenuContractsFrame:applyContractDetailLayout(isVehicleTransport)
  if self.contractDetailsList ~= nil then
    if isVehicleTransport then
      self.contractDetailsList:applyProfile("CC_ContractDetailsListVehicleTransport", true)
    else
      self.contractDetailsList:applyProfile("CC_ContractDetailsList", true)
    end
  end
  if self.rewardTitle ~= nil then
    if isVehicleTransport then
      self.rewardTitle:applyProfile("CC_ContractRewardVehicleTransport", true)
    else
      self.rewardTitle:applyProfile("fs25_contractsContractReward", true)
    end
  end
  if self.contractRewardSeparator ~= nil then
    if isVehicleTransport then
      self.contractRewardSeparator:applyProfile("CC_ContractRewardSeparatorVehicleTransport", true)
    else
      self.contractRewardSeparator:applyProfile("fs25_contractsContractRewardSeparator", true)
    end
  end
  if self.contractRewardValue ~= nil then
    if isVehicleTransport then
      self.contractRewardValue:applyProfile("CC_ContractRewardValueVehicleTransport", true)
    else
      self.contractRewardValue:applyProfile("fs25_contractsContractRewardValue", true)
    end
  end
end

--- Copy of InGameMenuContractsFrame:updateProgressBar so the bar behaves
--- exactly like the base game one.
function CCDedicatedMenuContractsFrame:updateProgressBar(value)
  local fullWidth = self.contractProgressBarBg.size[1] - self.contractProgressBar.margin[1] * 2
  value = math.max(value, self.contractProgressBar.startSize[1] * 2 / fullWidth)
  self.contractProgressBar:setSize(fullWidth * math.min(value, 1), nil)
end

--- True when the server measures the field work of this contract.
function CCDedicatedMenuContractsFrame:getHasProgress(contract)
  return contract ~= nil
      and contract.status == CustomContract.STATUS.ACCEPTED
      and (contract.completion or ContractProgress.NOT_TRACKED) >= 0
end

--- Refreshes the percentage and the bar of the selected contract.
function CCDedicatedMenuContractsFrame:updateContractProgress(contract)
  if self.contractProgressBox == nil then
    return
  end

  local hasProgress = self:getHasProgress(contract)
  self.contractProgressBox:setVisible(hasProgress)

  if not hasProgress then
    return
  end

  self.contractProgressText:setText(string.format("%.0f%%", contract.completion * 100))
  self:updateProgressBar(contract.completion)
end

--- Progress updates arrive while the menu is open, only touch the box.
function CCDedicatedMenuContractsFrame:onContractProgressUpdated(contract)
  if not self.isFrameOpen then
    return
  end

  local selected = self:getSelectedContract()
  if selected ~= nil and contract ~= nil and selected.id == contract.id then
    self:updateContractProgress(selected)
  end
end

function CCDedicatedMenuContractsFrame:displaySelectedContract()
  local index = self.contractsTable.selectedIndex
  local selection = self.contractDisplaySwitcher:getState()

  if index ~= -1 and index ~= nil and index >= 1 then
    local contractByFlat = self.contractsListDelegate.data and self.contractsListDelegate.data[selection] and
        self.contractsListDelegate.data[selection][index]
    local contractBySection = nil
    local r = self.contractsListDelegate
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
      self.noContractsText:setVisible(false)

      self:clearContractMapPreviewHotspots()

      local hudMap = g_currentMission.hud and g_currentMission.hud:getIngameMap() or nil
      if hudMap ~= nil then
        self.contractMap:setIngameMap(hudMap)
        self.contractMap.drawHotspots = true

        if contract.templateId == CustomContract.TEMPLATE.TRANSPORT
            or contract.templateId == CustomContract.TEMPLATE.VEHICLE_TRANSPORT then
          local destX = contract.destinationX
          local destZ = contract.destinationZ
          local pickupX, pickupZ = nil, nil
          if contract.templateId == CustomContract.TEMPLATE.TRANSPORT then
            if FarmInventoryHelper ~= nil and contract.creatorFarmId ~= nil and contract.fillTypeIndex ~= nil then
              pickupX, pickupZ = FarmInventoryHelper.getPrimaryPickupWorldXZ(contract.creatorFarmId, contract
                .fillTypeIndex)
            end
          elseif contract.templateId == CustomContract.TEMPLATE.VEHICLE_TRANSPORT then
            pickupX, pickupZ = FarmVehicleHelper.getPrimaryPickupWorldXZ(
              contract.creatorFarmId,
              contract.transportVehicleEntries
            )
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

        if self.contractMap.ingameMap ~= nil then
          local posStartX = self.contractMap.absPosition[1]
          local posStartY = self.contractMap.absPosition[2]
          local posEndX = posStartX + self.contractMap.absSize[1]
          local posEndY = posStartY + self.contractMap.absSize[2]
          self.contractMap.ingameMap:setMapClipArea(posStartX, posStartY, posEndX, posEndY)
          self.contractMap.ingameMap.clipHotspots = true
        end
      end

      local farm = g_farmManager:getFarmById(contract.creatorFarmId)
      if farm ~= nil then
        self.contractFarmImage:setImageSlice(nil, farm:getIconSliceId())
        self.contractFarmName:setText(farm.name)
        if contract.templateId == CustomContract.TEMPLATE.FIELD_WORK then
          local workKey = "cc_workareatype_" .. string.lower(contract:getWorkTypeAreaName())
          self.contractWorkType:setText(g_i18n:getText(workKey) or contract:getWorkTypeAreaName())
        else
          self.contractWorkType:setText(contract:getWorkTypeAreaName())
        end
      else
        self.contractFarmName:setText("-")
        self.contractWorkType:setText("-")
      end

      self.contractRewardValue:setText(
        g_i18n:formatMoney(contract.reward, 0, true, true)
      )

      if self.contractDetailsRenderer ~= nil and self.contractDetailsList ~= nil then
        self.contractDetailsRenderer:setFromContract(contract)
        self.contractDetailsList:reloadData()
      end

      self:updateContractProgress(contract)

      local isVehicleTransport = contract.templateId == CustomContract.TEMPLATE.VEHICLE_TRANSPORT
      local hasVehicleEntries = contract.transportVehicleEntries ~= nil and #contract.transportVehicleEntries > 0
      -- Both boxes use the same slot, the base game shows the progress of a
      -- running contract there as well.
      local showEquipment = hasVehicleEntries and not self:getHasProgress(contract)
      if self.contractEquipmentBox ~= nil then
        self.contractEquipmentBox:setVisible(showEquipment)
      end
      if self.contractEquipmentDesc ~= nil then
        if isVehicleTransport then
          self.contractEquipmentDesc:setText(g_i18n:getText("cc_contract_vehicle_transport_equipment_desc"))
        elseif hasVehicleEntries then
          self.contractEquipmentDesc:setText(g_i18n:getText("cc_contract_lent_equipment_desc"))
        else
          self.contractEquipmentDesc:setText("")
        end
      end
      if showEquipment then
        self:populateContractVehicleElements(contract)
      else
        self:clearContractVehicleElements()
      end

      self:applyContractDetailLayout(isVehicleTransport)

      self.contractDescriptionValue:setText(contract:getDescriptionText())
    else
      self:clearContractMapPreviewHotspots()
      self:clearContractMapPreviewClip()
      if self.contractEquipmentBox ~= nil then
        self.contractEquipmentBox:setVisible(false)
      end
      if self.contractProgressBox ~= nil then
        self.contractProgressBox:setVisible(false)
      end
      self:clearContractVehicleElements()
      self:applyContractDetailLayout(false)
      self.contractsInfoContainer:setVisible(false)
      self.noContractsText:setVisible(true)
    end
  else
    self:clearContractMapPreviewHotspots()
    self:clearContractMapPreviewClip()
  end
end

function CCDedicatedMenuContractsFrame:onMoneyChange()
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

function CCDedicatedMenuContractsFrame:onSwitchContractDisplay()
  self.contractsTable:reloadData()
  self.currentContractsListType = self.contractDisplaySwitcher:getState()
  local hasItem = self.contractsTable:getItemCount() > 0
  self.contractsContainer:setVisible(hasItem)
  self.contractsInfoContainer:setVisible(hasItem)
  self.noContractsText:setVisible(not hasItem)
  if hasItem then
    self.contractsTable:setSelectedIndex(1)
  end
  self:displaySelectedContract()
  self:updateMenuButtons()
  self:setMenuButtonInfoDirty()
end

function CCDedicatedMenuContractsFrame:updateContent()
  local contractManager = g_currentMission.CustomContracts.ContractManager
  local newContracts = contractManager:getNewContractsForCurrentFarm()
  local activeContracts = contractManager:getActiveContractsForCurrentFarm()
  local ownedContracts = contractManager:getOwnedContractsForCurrentFarm()
  local completedContracts = contractManager:getCompletedContractsForCurrentFarm()

  local renderData = {
    [CCDedicatedMenuContractsFrame.CONTRACTS_LIST_TYPE.NEW] = newContracts,
    [CCDedicatedMenuContractsFrame.CONTRACTS_LIST_TYPE.ACTIVE] = activeContracts,
    [CCDedicatedMenuContractsFrame.CONTRACTS_LIST_TYPE.OWNED] = ownedContracts,
    [CCDedicatedMenuContractsFrame.CONTRACTS_LIST_TYPE.COMPLETED] = completedContracts
  }

  self.contractsListDelegate:setData(renderData)
  self.contractsTable:reloadData()

  self:applyPendingContractsView(renderData)

  if self.pendingContractsListType == nil then
    self.contractsContainer:setVisible(self.contractsTable:getItemCount() > 0)
    self.contractsInfoContainer:setVisible(self.contractsTable:getItemCount() > 0)
    self.noContractsText:setVisible(self.contractsTable:getItemCount() == 0)
  end

  self:updateMenuButtons()
end

function CCDedicatedMenuContractsFrame:queueContractsView(listType, focusContractId)
  self.pendingContractsListType = listType
  self.pendingFocusContractId = focusContractId
end

function CCDedicatedMenuContractsFrame:applyPendingContractsView(renderData)
  if self.pendingContractsListType == nil then
    return
  end

  local targetListType = self.pendingContractsListType
  local focusId = self.pendingFocusContractId

  self.pendingContractsListType = nil
  self.pendingFocusContractId = nil

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
  self.noContractsText:setVisible(not hasItem)

  if hasItem then
    self.contractsTable:setSelectedIndex(targetIndex)
  end

  self:displaySelectedContract()
end

function CCDedicatedMenuContractsFrame:getSelectedContract()
  local index = self.contractsTable.selectedIndex
  if index == nil or index < 1 then
    return nil
  end

  local selection = self.contractDisplaySwitcher:getState()
  local r = self.contractsListDelegate
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

function CCDedicatedMenuContractsFrame:updateMenuButtons()
  local currentMission = g_currentMission
  local myFarmId = currentMission and currentMission:getFarmId() or nil
  local isSpectator = (myFarmId == nil or myFarmId == FarmManager.SPECTATOR_FARM_ID)

  if isSpectator then
    self.menuButtonInfo = { self.backButtonInfo }
    self:setMenuButtonInfoDirty()
    return
  end

  self.menuButtonInfo = { self.backButtonInfo }

  local listType = self.currentContractsListType or CCDedicatedMenuContractsFrame.CONTRACTS_LIST_TYPE.NEW
  local baseButtons = self.contractButtonSets[listType] or { self.backButtonInfo, self.btnCreateContract }

  local contract = self:getSelectedContract()

  local filtered = {}
  for _, btn in ipairs(baseButtons) do
    if self:shouldShowButton(btn, listType, contract) then
      table.insert(filtered, btn)
    end
  end

  self.menuButtonInfo = filtered
  self:setMenuButtonInfoDirty()
end

function CCDedicatedMenuContractsFrame:shouldShowButton(button, listType, contract)
  local myFarmId = g_currentMission:getFarmId()

  if button == self.backButtonInfo then
    return true
  end

  if button == self.btnCreateContract then
    return true
  end

  if contract == nil then
    return false
  end

  local isOwner = (contract.creatorFarmId == myFarmId)
  local isContractor = (contract.contractorFarmId == myFarmId)

  local status = contract.status

  if listType == CCDedicatedMenuContractsFrame.CONTRACTS_LIST_TYPE.NEW then
    if button == self.btnAccept then
      return status == CustomContract.STATUS.OPEN and not isOwner
    end
    return false
  end

  if listType == CCDedicatedMenuContractsFrame.CONTRACTS_LIST_TYPE.ACTIVE then
    if button == self.btnComplete then
      return status == CustomContract.STATUS.ACCEPTED and isContractor
    end
    if button == self.btnCancel then
      return status == CustomContract.STATUS.ACCEPTED and isContractor
    end
    return false
  end

  if listType == CCDedicatedMenuContractsFrame.CONTRACTS_LIST_TYPE.OWNED then
    if not isOwner then
      return false
    end

    if button == self.btnEdit then
      return status == CustomContract.STATUS.OPEN or status == CustomContract.STATUS.CANCELLED or
          status == CustomContract.STATUS.EXPIRED
    end

    if button == self.btnCancel then
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

  if listType == CCDedicatedMenuContractsFrame.CONTRACTS_LIST_TYPE.COMPLETED then
    if button == self.btnCreateInvoice then
      return status == CustomContract.STATUS.COMPLETED_AWAITING_INVOICE and isContractor and contract.invoiceId < 0
    end
    return false
  end

  return false
end

function CCDedicatedMenuContractsFrame:onCreateInvoice()
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

function CCDedicatedMenuContractsFrame:onCreateContract()
  self:queueContractsView(CCDedicatedMenuContractsFrame.CONTRACTS_LIST_TYPE.OWNED, nil)

  local options = {
    g_i18n:getText("cc_dialog_template_field_work"),
    g_i18n:getText("cc_dialog_template_transport"),
    g_i18n:getText("cc_dialog_template_transport_vehicle"),
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
      local farmId = g_currentMission:getFarmId()
      local vehicles = FarmVehicleHelper.retrieveFarmVehicles(farmId)
      if vehicles ~= nil and #vehicles > 0 then
        CreateVehicleTransportContractDialog.show(vehicles)
      else
        InfoDialog.show(g_i18n:getText("cc_dialog_template_no_vehicles"))
      end
    elseif templateId == 4 then
      InfoDialog.show(g_i18n:getText("cc_dialog_template_coming_soon"))
    end
  end

  OptionDialog.show(callback, g_i18n:getText("cc_dialog_template_subtitle"),
    g_i18n:getText("cc_dialog_template_title"), options)
end

function CCDedicatedMenuContractsFrame.formatContractYesNoMessage(contract, textKey, withReward)
  if withReward then
    return string.format(
      g_i18n:getText(textKey),
      contract:getTypeDisplayName(),
      contract:getSubjectDisplayName(),
      g_i18n:formatMoney(contract.reward, 0, true, true)
    )
  end
  return string.format(
    g_i18n:getText(textKey),
    contract:getTypeDisplayName(),
    contract:getSubjectDisplayName()
  )
end

function CCDedicatedMenuContractsFrame:onCompleteContract()
  local index = self.contractsTable.selectedIndex
  local selection = self.contractDisplaySwitcher:getState()
  local contract = self.contractsListDelegate.data[selection][index]

  YesNoDialog.show(
    function(_, yes)
      if yes then
        self:queueContractsView(CCDedicatedMenuContractsFrame.CONTRACTS_LIST_TYPE.ACTIVE, nil)
        g_client:getServerConnection():sendEvent(
          CompleteContractEvent.new(contract.id, g_currentMission:getFarmId())
        )
      end
    end,
    self,
    CCDedicatedMenuContractsFrame.formatContractYesNoMessage(contract, "cc_dialog_complete_yes_no", true),
    g_i18n:getText("cc_dialog_complete_yes_no_btn")
  )
end

function CCDedicatedMenuContractsFrame:onAcceptContract()
  local index = self.contractsTable.selectedIndex
  local selection = self.contractDisplaySwitcher:getState()
  local contract = self.contractsListDelegate.data[selection][index]

  if contract == nil then
    InfoDialog.show("No contract found")
    return
  end

  YesNoDialog.show(
    function(_, yes)
      if yes then
        self:queueContractsView(CCDedicatedMenuContractsFrame.CONTRACTS_LIST_TYPE.ACTIVE, contract.id)
        g_client:getServerConnection():sendEvent(
          AcceptContractEvent.new(contract.id, g_currentMission:getFarmId())
        )
      end
    end,
    self,
    CCDedicatedMenuContractsFrame.formatContractYesNoMessage(contract, "cc_dialog_accept_yes_no", true),
    g_i18n:getText("cc_dialog_accept_yes_no_btn")
  )
end

function CCDedicatedMenuContractsFrame:onCancelContract()
  local index = self.contractsTable.selectedIndex
  local selection = self.contractDisplaySwitcher:getState()
  local contract = self.contractsListDelegate.data[selection][index]

  if contract == nil then
    return
  end

  YesNoDialog.show(
    function(_, yes)
      if yes then
        g_client:getServerConnection():sendEvent(
          CancelContractEvent.new(contract.id, g_currentMission:getFarmId())
        )
      end
    end,
    self,
    CCDedicatedMenuContractsFrame.formatContractYesNoMessage(contract, "cc_dialog_cancel_yes_no", false),
    g_i18n:getText("cc_dialog_cancel_yes_no_btn")
  )
end

function CCDedicatedMenuContractsFrame:onDeleteContract()
  local index = self.contractsTable.selectedIndex
  local selection = self.contractDisplaySwitcher:getState()
  local contract = self.contractsListDelegate.data[selection][index]

  if contract == nil then
    return
  end

  YesNoDialog.show(
    function(_, yes)
      if yes then
        self:queueContractsView(CCDedicatedMenuContractsFrame.CONTRACTS_LIST_TYPE.OWNED, nil)
        g_client:getServerConnection():sendEvent(
          DeleteContractEvent.new(contract.id, g_currentMission:getFarmId())
        )
      end
    end,
    self,
    CCDedicatedMenuContractsFrame.formatContractYesNoMessage(contract, "cc_dialog_delete_yes_no", false),
    g_i18n:getText("cc_dialog_delete_yes_no_btn")
  )
end

function CCDedicatedMenuContractsFrame:onReopenContract()
  local index = self.contractsTable.selectedIndex
  local selection = self.contractDisplaySwitcher:getState()
  local contract = self.contractsListDelegate.data[selection][index]

  if contract == nil then
    return
  end

  YesNoDialog.show(
    function(_, yes)
      if yes then
        self:queueContractsView(CCDedicatedMenuContractsFrame.CONTRACTS_LIST_TYPE.OWNED, nil)
        g_client:getServerConnection():sendEvent(
          ReopenContractEvent.new(contract.id, g_currentMission:getFarmId())
        )
      end
    end,
    self,
    CCDedicatedMenuContractsFrame.formatContractYesNoMessage(contract, "cc_dialog_reopen_yes_no", false),
    g_i18n:getText("cc_dialog_reopen_yes_no_btn")
  )
end

function CCDedicatedMenuContractsFrame:onEditContract()
  local index = self.contractsTable.selectedIndex
  local selection = self.contractDisplaySwitcher:getState()
  local contractByFlat = self.contractsListDelegate.data and self.contractsListDelegate.data[selection] and
      self.contractsListDelegate.data[selection][index]
  local contractBySection = nil
  local r = self.contractsListDelegate
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
  elseif contract.templateId == CustomContract.TEMPLATE.VEHICLE_TRANSPORT then
    InfoDialog.show(g_i18n:getText("cc_dialog_vehicle_transport_edit_not_supported"))
  else
    EditFieldWorkContractDialog.show(contract)
  end
end
