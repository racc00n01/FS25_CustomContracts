ContractsRenderer = {}
ContractsRenderer_mt = Class(ContractsRenderer)

function ContractsRenderer.new()
  local self = {}
  setmetatable(self, ContractsRenderer_mt)
  self.data = nil
  self.selectedRow = -1;
  self.indexChangedCallback = nil

  return self
end

function ContractsRenderer:setData(data)
  self.data = data
end

function ContractsRenderer:getNumberOfSections()
  return 1
end

function ContractsRenderer:getNumberOfItemsInSection(list, section)
  local menu = g_currentMission.customContracts.CustomContractsMenu
  local selection = menu.contractDisplaySwitcher:getState()
  return #self.data[selection]
end

function ContractsRenderer:getTitleForSectionHeader(list, section)
  return ""
end

function ContractsRenderer:populateCellForItemInSection(list, section, index, cell)
  local menu = g_currentMission.customContracts.CustomContractsMenu
  local selection = menu.contractDisplaySwitcher:getState()
  local contract = self.data[selection][index]

  cell:getAttribute("field"):setText(string.format("Field %d", contract.fieldId))
  cell:getAttribute("reward"):setText(g_i18n:formatMoney(contract.reward, 0, true, true))
end

function ContractsRenderer:onListSelectionChanged(list, section, index)
  self.selectedRow = index
  if self.indexChangedCallback ~= nil then
    self.indexChangedCallback(index)
  end
end
