--
-- FS25 Contract and Invoices
--
-- @Author: Racc00n
-- @Version: 1.0.0.0
--

InvoicesOutboxRenderer = {}
InvoicesOutboxRenderer_mt = Class(InvoicesOutboxRenderer)

function InvoicesOutboxRenderer.new()
  local self = {}
  setmetatable(self, InvoicesOutboxRenderer_mt)
  self.data = nil
  self.selectedRow = 0;
  self.indexChangedCallback = nil

  return self
end

function InvoicesOutboxRenderer:setData(data)
  self.data = data
end

function InvoicesOutboxRenderer:getNumberOfSections()
  return 1
end

function InvoicesOutboxRenderer:getNumberOfItemsInSection(list, section)
  return #self.data
end

function InvoicesOutboxRenderer:getTitleForSectionHeader(list, section)
  return ""
end

function InvoicesOutboxRenderer:populateCellForItemInSection(list, section, index, cell)
  local invoice = self.data[index]

  local toFarm = g_farmManager:getFarmById(invoice.receiverFarmId)
  local farmId = g_currentMission:getFarmId()

  cell:getAttribute("outboxId"):setText(invoice.number)
  cell:getAttribute("outboxStatus"):setText(invoice:getStatus(farmId))
  cell:getAttribute("outboxTo"):setText(toFarm.name)
  cell:getAttribute("outboxAmount"):setText(g_i18n:formatMoney(invoice.total, 0, true, true))
end

function InvoicesOutboxRenderer:onListSelectionChanged(list, section, index)
  self.selectedRow = index

  if self.indexChangedCallback ~= nil then
    self.indexChangedCallback(index)
  end
end
