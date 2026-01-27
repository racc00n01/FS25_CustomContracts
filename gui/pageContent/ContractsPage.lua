ContractsPage = {}
ContractsPage_mt = Class(ContractsPage)

function ContractsPage.new()
  local self = {}
  setmetatable(self, ContractsPage_mt)
  self.data = nil
  self.selectedRow = -1;
  self.indexChangedCallback = nil

  return self
end

function ContractsPage:setData(data)
  self.data = data
end

function ContractsPage:getNumberOfSections()
  return 1
end

function ContractsPage:getNumberOfItemsInSection(list, section)
  local menu = g_currentMission.customContracts.CustomContractsMenu
  local selection = menu.contractsFilterListSelector:getState()

  local count = self.data[selection] and #self.data[selection] or 0
  print("[CC] getNumberOfItems:", selection, count)

  local data = self.data[selection]
  return data ~= nil and #data or 0
end

function ContractsPage:getTitleForSectionHeader(list, section)
  return ""
end

function ContractsPage:populateCellForItemInSection(list, section, index, cell)
  print("[CC] populate row:", index)
  local menu = g_currentMission.customContracts.CustomContractsMenu
  local selection = menu.contractsFilterListSelector:getState()
  local contract = self.data[selection][index]

  if contract == nil then
    return
  end

  cell:getAttribute("field"):setText(contract.field)
  cell:getAttribute("reward"):setText(
    g_i18n:formatMoney(contract.reward, 0, true)
  )
end

function ContractsPage:onListSelectionChanged(list, section, index)
  self.selectedRow = index
  if self.indexChangedCallback ~= nil then
    self.indexChangedCallback(index)
  end
end
