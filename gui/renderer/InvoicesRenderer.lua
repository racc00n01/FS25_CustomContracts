--
-- FS25 CustomContracts
--
-- @Author: Racc00n
-- @Version: 0.0.1.1
--

InvoicesRenderer = {}
InvoicesRenderer_mt = Class(InvoicesRenderer)

function InvoicesRenderer.new()
  local self = {}
  setmetatable(self, InvoicesRenderer_mt)
  self.data = nil
  self.selectedRow = 0;
  self.indexChangedCallback = nil

  return self
end

function InvoicesRenderer:setData(data)
  self.data = data
end

function InvoicesRenderer:getNumberOfSections()
  return 1
end

function InvoicesRenderer:getNumberOfItemsInSection(list, section)
  return #self.data
end

function InvoicesRenderer:getTitleForSectionHeader(list, section)
  return ""
end

function InvoicesRenderer:populateCellForItemInSection(list, section, index, cell)
  local invoice = self.data[index]

  local fromFarm = g_farmManager:getFarmById(invoice.creatorFarmId)
  local toFarm = g_farmManager:getFarmById(invoice.receiverFarmId)
  local farmId = g_currentMission:getFarmId()

  cell:getAttribute("id"):setText(invoice.number)
  cell:getAttribute("status"):setText(invoice:getStatus(farmId))
  cell:getAttribute("from"):setText(fromFarm.name)
  cell:getAttribute("to"):setText(toFarm.name)
  cell:getAttribute("amount"):setText(g_i18n:formatMoney(invoice.total, 0, true, true))
  cell:getAttribute("related"):setText(invoice.relatedContractId)
  cell:getAttribute("duedate"):setText(CustomUtils:formatPeriodDay(invoice.dueAt))
end

function InvoicesRenderer:onListSelectionChanged(list, section, index)
  self.selectedRow = index

  if self.indexChangedCallback ~= nil then
    self.indexChangedCallback(index)
  end
end
