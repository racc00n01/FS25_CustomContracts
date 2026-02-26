--
-- FS25 Contract and Invoices
--
-- @Author: Racc00n
-- @Version: 1.0.0.0
--

InvoiceLinesRenderer = {}
local InvoiceLinesRenderer_mt = Class(InvoiceLinesRenderer)

function InvoiceLinesRenderer.new()
  local self = {}
  setmetatable(self, InvoiceLinesRenderer_mt)

  self.data = {}

  return self
end

function InvoiceLinesRenderer:setData(data)
  self.data = data or {}
end

function InvoiceLinesRenderer:getNumberOfSections()
  return 1
end

function InvoiceLinesRenderer:getNumberOfItemsInSection(list, section)
  return #self.data
end

function InvoiceLinesRenderer:getTitleForSectionHeader(list, section)
  return ""
end

function InvoiceLinesRenderer:populateCellForItemInSection(list, section, index, cell)
  local line = self.data[index]

  cell:getAttribute("title"):setText(line.title)
  cell:getAttribute("amount"):setText(g_i18n:formatMoney(line.amount, 0, true, true))
end

function InvoiceLinesRenderer:onListSelectionChanged(list, section, index)
  -- optional
end
