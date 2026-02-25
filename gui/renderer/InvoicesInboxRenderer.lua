--
-- FS25 Contract and Invoices
--
-- @Author: Racc00n
-- @Version: 1.0.0.0
--

InvoicesInboxRenderer = {}
InvoicesInboxRenderer_mt = Class(InvoicesInboxRenderer)

function InvoicesInboxRenderer.new()
  local self = {}
  setmetatable(self, InvoicesInboxRenderer_mt)
  self.data = nil
  self.selectedRow = 0;
  self.indexChangedCallback = nil

  return self
end

function InvoicesInboxRenderer:setData(data)
  self.data = data
end

function InvoicesInboxRenderer:getNumberOfSections()
  return 1
end

function InvoicesInboxRenderer:getNumberOfItemsInSection(list, section)
  return #self.data
end

function InvoicesInboxRenderer:getTitleForSectionHeader(list, section)
  return ""
end

function InvoicesInboxRenderer:populateCellForItemInSection(list, section, index, cell)
  local invoice = self.data[index]

  local fromFarm = g_farmManager:getFarmById(invoice.creatorFarmId)
  local toFarm = g_farmManager:getFarmById(invoice.receiverFarmId)
  local farmId = g_currentMission:getFarmId()

  cell:getAttribute("id"):setText(invoice.number)
  cell:getAttribute("status"):setText(invoice:getStatus(farmId))
  cell:getAttribute("from"):setText(fromFarm.name)
  cell:getAttribute("amount"):setText(g_i18n:formatMoney(invoice.total, 0, true, true))
end

function InvoicesInboxRenderer:onListSelectionChanged(list, section, index)
  self.selectedRow = index

  if self.indexChangedCallback ~= nil then
    self.indexChangedCallback(index)
  end
end
