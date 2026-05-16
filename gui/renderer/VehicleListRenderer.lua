--
-- Multi-select vehicle list for CreateVehicleTransportContractDialog.
--

VehicleListRenderer = {}
local VehicleListRenderer_mt = Class(VehicleListRenderer)

function VehicleListRenderer.new()
  local self = setmetatable({}, VehicleListRenderer_mt)
  self.data = {}
  self.selectedUniqueIds = {}
  self.selectionChangedCallback = nil
  self.suppressSelectionHandler = false
  return self
end

function VehicleListRenderer:setData(data)
  self.data = data or {}
end

function VehicleListRenderer:clearSelection()
  self.selectedUniqueIds = {}
end

function VehicleListRenderer:getSelectedCount()
  local count = 0
  for _ in pairs(self.selectedUniqueIds) do
    count = count + 1
  end
  return count
end

function VehicleListRenderer:isSelected(uniqueId)
  return uniqueId ~= nil and self.selectedUniqueIds[uniqueId] == true
end

function VehicleListRenderer:toggleSelection(uniqueId)
  if uniqueId == nil then
    return
  end
  if self.selectedUniqueIds[uniqueId] then
    self.selectedUniqueIds[uniqueId] = nil
  else
    self.selectedUniqueIds[uniqueId] = true
  end
end

function VehicleListRenderer:getSelectedEntries()
  local out = {}
  for _, entry in ipairs(self.data) do
    if self:isSelected(entry.uniqueId) then
      table.insert(out, {
        uniqueId      = entry.uniqueId,
        title         = entry.title,
        imageFilename = entry.imageFilename
      })
    end
  end
  return out
end

function VehicleListRenderer:applyRowVisual(cell, index, entry)
  if cell == nil or entry == nil then
    return
  end

  local isChosen = self:isSelected(entry.uniqueId)

  if cell.applyProfile ~= nil then
    if isChosen then
      cell:applyProfile("CC_VehicleRowChosen", true)
    else
      cell:applyProfile("CC_VehicleRow", true)
    end
  end

  local icon = cell:getAttribute("icon")
  if icon ~= nil then
    if entry.imageFilename ~= nil and entry.imageFilename ~= "" then
      icon:setImageFilename(entry.imageFilename)
    end
    icon:setVisible(true)
  end

  local title = cell:getAttribute("title")
  if title ~= nil then
    title:setText(entry.title or "")
    title:setTextColor(1, 1, 1, 1)
  end
end

function VehicleListRenderer:getNumberOfSections()
  return 1
end

function VehicleListRenderer:getNumberOfItemsInSection(list, section)
  return #self.data
end

function VehicleListRenderer:getTitleForSectionHeader(list, section)
  return ""
end

function VehicleListRenderer:populateCellForItemInSection(list, section, index, cell)
  local entry = self.data[index]
  if entry == nil then
    return
  end
  self:applyRowVisual(cell, index, entry)
end

function VehicleListRenderer:refreshList(list)
  if list == nil then
    return
  end
  self.suppressSelectionHandler = true
  list:reloadData()
  self.suppressSelectionHandler = false
end

function VehicleListRenderer:onListSelectionChanged(list, section, index)
  -- Multi-select toggles via SmoothList onClick (CreateVehicleTransportContractDialog:onClickVehicleList).
end

function VehicleListRenderer:handleRowClick(list, section, index)
  if self.suppressSelectionHandler then
    return
  end

  local entry = self.data[index]
  if entry == nil then
    return
  end

  self:toggleSelection(entry.uniqueId)
  self:refreshList(list)

  if self.selectionChangedCallback ~= nil then
    self.selectionChangedCallback()
  end
end
