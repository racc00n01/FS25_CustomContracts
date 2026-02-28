--
-- List data source/delegate for inventory (product + amount) in CreateTransportContractDialog.
--

InventoryListRenderer = {}
local InventoryListRenderer_mt = Class(InventoryListRenderer)

function InventoryListRenderer.new()
  local self = setmetatable({}, InventoryListRenderer_mt)
  self.data = {}
  self.selectedRow = -1;
  return self
end

function InventoryListRenderer:setData(data)
  self.data = data or {}
end

function InventoryListRenderer:getNumberOfSections()
  return 1
end

function InventoryListRenderer:getNumberOfItemsInSection(list, section)
  return #self.data
end

function InventoryListRenderer:getTitleForSectionHeader(list, section)
  return ""
end

function InventoryListRenderer:populateCellForItemInSection(list, section, index, cell)
  local entry = self.data[index]
  if entry == nil then return end
  print("entry.hudOverlayFilename: " .. tostring(entry.hudOverlayFilename))
  cell:getAttribute("icon"):setImageFilename(entry.hudOverlayFilename)
  cell:getAttribute("title"):setText(entry.title or "")
  cell:getAttribute("amount"):setText(tostring(string.format("%d L", entry.amount or 0)))
end

function InventoryListRenderer:onListSelectionChanged(list, section, index)
  self.selectedRow = index;
  if self.indexChangedCallback ~= nil then
    self.indexChangedCallback(index)
  end
end
