SellPointSelectDialog = {}
local SellPointSelectDialog_mt = Class(SellPointSelectDialog, MessageDialog)

function SellPointSelectDialog.new(target, custom_mt)
  local self = MessageDialog.new(target, custom_mt or SellPointSelectDialog_mt)
  self.selectedIndex = 1
  self.onSelectedCallback = nil

  -- input
  self.fillTypeIndex = nil
  self.liters = 0
  self.productTitle = nil

  -- data
  self.sellPoints = {}

  return self
end

function SellPointSelectDialog:onCreate()
  SellPointSelectDialog:superClass().onCreate(self)
end

--- Optional convenience: set required inputs before opening
function SellPointSelectDialog:setSelectionData(fillTypeIndex, liters, productTitle)
  self.fillTypeIndex = fillTypeIndex
  self.liters = liters or 0
  self.productTitle = productTitle
end

function SellPointSelectDialog:setCallback(cb)
  self.onSelectedCallback = cb
end

function SellPointSelectDialog:onOpen()
  SellPointSelectDialog:superClass().onOpen(self)

  -- If caller didn't pass inputs, try to read what the product dialog stored
  if self.fillTypeIndex == nil then
    local sel = g_currentMission.CustomContracts and g_currentMission.CustomContracts.selectedProducts
    if sel ~= nil then
      self.fillTypeIndex = sel.fillTypeIndex
      self.liters = sel.liters or 0
    end
  end

  self.sellPoints = self:collectSellPointsForFillType(self.fillTypeIndex)
  self.selectedIndex = 1

  -- Bind list
  self.sellPointSelector:setDataSource(self)
  self.sellPointSelector:setDelegate(self)
  self.sellPointSelector:reloadData()

  if #self.sellPoints > 0 then
    self.sellPointSelector:setSelectedIndex(1)
  end

  -- Update dialog text (optional)
  self:updateHeaderText()
end

function SellPointSelectDialog:updateHeaderText()
  if self.dialogTextElement == nil then
    -- MessageDialog typically uses setText() (mapped to dialogTextElement)
    -- But not all variants expose dialogTextElement directly.
  end

  local ftTitle = "—"
  if self.fillTypeIndex ~= nil then
    local ft = g_fillTypeManager:getFillTypeByIndex(self.fillTypeIndex)
    ftTitle = (ft and (ft.title or ft.name)) or tostring(self.fillTypeIndex)
  end

  local amountText = g_i18n:formatVolume(self.liters or 0, 0)
  local line = string.format("%s - %s", ftTitle, amountText)

  -- If you want “Select sell point” + subtitle, keep title in XML and use setText for subtitle
  self:setText(line)
end

function SellPointSelectDialog:onListSelectionChanged(list, section, index)
  self.selectedIndex = index or 1
end

function SellPointSelectDialog:getNumberOfItemsInSection(list, section)
  if self.sellPoints == nil or #self.sellPoints == 0 then
    return 0
  end
  return #self.sellPoints
end

function SellPointSelectDialog:populateCellForItemInSection(list, section, index, cell)
  local sp = self.sellPoints[index]
  if sp == nil then return end

  -- match your cell attributes naming style
  -- required:
  cell:getAttribute("sellPoint"):setText(sp.title)

  -- optional columns:
  local distanceEl = cell:getAttribute("distance")
  if distanceEl ~= nil then
    if sp.distance ~= nil then
      distanceEl:setText(string.format("%.0f m", sp.distance))
    else
      distanceEl:setText("")
    end
  end

  local priceEl = cell:getAttribute("price")
  if priceEl ~= nil then
    if sp.price ~= nil then
      -- keep it simple, you can format as currency later
      priceEl:setText(string.format("%.3f", sp.price))
    else
      priceEl:setText("")
    end
  end

  local iconEl = cell:getAttribute("icon")
  if iconEl ~= nil and sp.iconFilename ~= nil then
    iconEl:setImageFilename(sp.iconFilename)
  end
end

function SellPointSelectDialog:onConfirm()
  local idx = self.selectedIndex or 1
  local sp = self.sellPoints and self.sellPoints[idx]
  if sp == nil then
    self:close()
    return
  end

  g_currentMission.CustomContracts = g_currentMission.CustomContracts or {}
  g_currentMission.CustomContracts.selectedSellPoint = {
    index = idx,
    title = sp.title,
    -- runtime reference (good enough to pass to MenuCreateContract right away)
    station = sp.station,
    -- stable-ish ids if available
    placeableId = sp.placeableId
  }

  self:close()

  if self.onSelectedCallback ~= nil then
    self.onSelectedCallback(sp)
  else
    -- Continue to create dialog
    g_gui:showDialog("menuCreateContract")
  end
end

function SellPointSelectDialog:onCancel()
  self:close()
end

-- =========================================================
-- Data collection
-- =========================================================

function SellPointSelectDialog:collectSellPointsForFillType(fillTypeIndex)
  local results = {}

  if fillTypeIndex == nil or g_currentMission == nil or g_currentMission.storageSystem == nil then
    return results
  end

  local stations = g_currentMission.storageSystem:getUnloadingStations()
  if stations == nil then
    return results
  end

  local px, py, pz = nil, nil, nil
  if g_localPlayer ~= nil and g_localPlayer.getCurrentRootNode ~= nil then
    local node = g_localPlayer:getCurrentRootNode()
    if node ~= nil then
      px, py, pz = getWorldTranslation(node)
    end
  end

  for _, station in pairs(stations) do
    -- selling stations only
    if station ~= nil and station.isa ~= nil and station:isa(SellingStation) then
      -- accepts fill type?
      if station.acceptedFillTypes ~= nil and station.acceptedFillTypes[fillTypeIndex] == true then
        -- name
        local title = nil
        if station.getName ~= nil then
          title = station:getName()
        elseif station.owningPlaceable ~= nil and station.owningPlaceable.getName ~= nil then
          title = station.owningPlaceable:getName()
        end
        title = title or "Sell point"

        -- optional distance
        local dist = nil
        if px ~= nil and station.rootNode ~= nil then
          local sx, sy, sz = getWorldTranslation(station.rootNode)
          dist = MathUtil.vector3Length(px - sx, (py or sy) - sy, pz - sz)
        end

        -- optional price
        local price = nil
        if station.getEffectiveFillTypePrice ~= nil then
          price = station:getEffectiveFillTypePrice(fillTypeIndex)
        end

        -- optional owning placeable id
        local placeableId = nil
        if station.owningPlaceable ~= nil and station.owningPlaceable.id ~= nil then
          placeableId = station.owningPlaceable.id
        end

        table.insert(results, {
          station = station,
          title = title,
          distance = dist,
          price = price,
          placeableId = placeableId,
          iconFilename = nil
        })
      end
    end
  end

  -- sort: nearest first feels best for transport
  table.sort(results, function(a, b)
    local da = a.distance or math.huge
    local db = b.distance or math.huge
    if da == db then
      return (a.title or "") < (b.title or "")
    end
    return da < db
  end)

  return results
end
