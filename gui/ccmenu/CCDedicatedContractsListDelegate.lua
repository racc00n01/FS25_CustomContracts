--
-- SmoothList data source for the dedicated Contracts & Invoices menu contracts tab.
-- Logic mirrors gui/renderer/ContractsRenderer.lua but uses the frame's
-- contractDisplaySwitcher instead of g_currentMission.CustomContracts.CustomContractsMenu.
--

CCDedicatedContractsListDelegate = {}
local CCDedicatedContractsListDelegate_mt = Class(CCDedicatedContractsListDelegate)

function CCDedicatedContractsListDelegate.new(menuFrame)
  local self = {}
  setmetatable(self, CCDedicatedContractsListDelegate_mt)
  self.menuFrame = menuFrame
  self.data = {}
  self.sectionContracts = {}
  self.selectedRow = -1
  self.selectedSection = nil
  self.indexChangedCallback = nil
  return self
end

function CCDedicatedContractsListDelegate:setData(data)
  self.data = data
  self.sectionContracts = {}
  for listType, flatList in pairs(data) do
    self.sectionContracts[listType] = self:buildSectionContracts(flatList or {})
  end
end

function CCDedicatedContractsListDelegate:buildSectionContracts(flatContracts)
  local sections = {}
  local lastTitle = nil

  table.sort(flatContracts, function(a, b)
    return (a:getWorkTypeAreaName() or "") < (b:getWorkTypeAreaName() or "")
  end)

  for _, contract in ipairs(flatContracts) do
    local title = contract:getWorkTypeAreaName()
    if lastTitle ~= title then
      table.insert(sections, { title = title, contracts = {} })
      lastTitle = title
    end
    table.insert(sections[#sections].contracts, contract)
  end

  return sections
end

function CCDedicatedContractsListDelegate:getSwitcherState()
  local mf = self.menuFrame
  if mf == nil or mf.contractDisplaySwitcher == nil then
    return 1
  end
  return mf.contractDisplaySwitcher:getState()
end

function CCDedicatedContractsListDelegate:getNumberOfSections()
  if self.sectionContracts == nil then
    return 0
  end
  local selection = self:getSwitcherState()
  local sections = self.sectionContracts[selection]
  return sections and #sections or 0
end

function CCDedicatedContractsListDelegate:getNumberOfItemsInSection(list, section)
  if self.sectionContracts == nil then
    return 0
  end
  local selection = self:getSwitcherState()
  local sections = self.sectionContracts[selection]
  if sections and sections[section] then
    return #sections[section].contracts
  end
  return 0
end

function CCDedicatedContractsListDelegate:getTitleForSectionHeader(list, section)
  if self.sectionContracts == nil then
    return ""
  end
  local selection = self:getSwitcherState()
  local sections = self.sectionContracts[selection]
  return (sections and sections[section] and sections[section].title or "")
end

function CCDedicatedContractsListDelegate:populateCellForItemInSection(list, section, index, cell)
  if self.sectionContracts == nil then
    return
  end
  local selection = self:getSwitcherState()
  local sec = self.sectionContracts[selection]
  if sec == nil or sec[section] == nil or sec[section].contracts[index] == nil then
    return
  end
  local contract = sec[section].contracts[index]

  local farm = g_farmManager:getFarmById(contract.creatorFarmId)
  if farm == nil then
    return
  end

  cell:getAttribute("farmIcon"):setImageSlice(nil, farm:getIconSliceId())
  cell:getAttribute("farmland"):setText(contract:getListLabel())

  if contract.status == CustomContract.STATUS.COMPLETED or contract.status == CustomContract.STATUS.COMPLETED_AWAITING_INVOICE or contract.status == CustomContract.STATUS.CANCELLED or contract.status == CustomContract.STATUS.EXPIRED or contract.status == CustomContract.STATUS.INVOICED then
    cell:getAttribute("reward"):setText(g_i18n:getText("cc_status_" .. string.lower(contract.status)))
  else
    cell:getAttribute("reward"):setText(g_i18n:formatMoney(contract.reward, 0, true, true))
  end
end

function CCDedicatedContractsListDelegate:getContractAtFlatIndex(selection, flatIndex)
  local sections = self.sectionContracts and self.sectionContracts[selection]
  if not sections or flatIndex < 1 then
    return nil
  end
  local count = 0
  for _, sec in ipairs(sections) do
    for i, c in ipairs(sec.contracts) do
      count = count + 1
      if count == flatIndex then
        return c
      end
    end
  end
  return nil
end

function CCDedicatedContractsListDelegate:onListSelectionChanged(list, section, index)
  self.selectedRow = index
  self.selectedSection = section
  if self.indexChangedCallback ~= nil then
    self.indexChangedCallback(section, index)
  end
end
