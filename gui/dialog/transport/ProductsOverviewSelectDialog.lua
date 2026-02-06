ProductsOverviewSelectDialog = {}
local ProductsOverviewSelectDialog_mt = Class(ProductsOverviewSelectDialog, MessageDialog)

function ProductsOverviewSelectDialog.new(target, custom_mt)
  local self = MessageDialog.new(target, custom_mt or ProductsOverviewSelectDialog_mt)
  self.selectedIndex = 1
  self.onSelectedCallback = nil
  self.selectedAmount = 0
  return self
end

function ProductsOverviewSelectDialog:onCreate()
  ProductsOverviewSelectDialog:superClass().onCreate(self)
end

function ProductsOverviewSelectDialog:onOpen()
  ProductsOverviewSelectDialog:superClass().onOpen(self)

  self.transportProducts = self:collectFarmSiloFillTypes()
  self.selectedIndex = 1

  self.transportProductSelector:setDataSource(self)
  self.transportProductSelector:setDelegate(self)
  self.transportProductSelector:reloadData()

  if #self.transportProducts > 0 then
    self.transportProductSelector:setSelectedIndex(1)
  end

  if #self.transportProducts > 0 then
    self.transportProductSelector:setSelectedIndex(1)
    self:updateAmountSlider() -- ✅ correct place
  end
end

function ProductsOverviewSelectDialog:onListSelectionChanged(list, section, index)
  self.selectedIndex = index or 1
  self:updateAmountSlider()
end

function ProductsOverviewSelectDialog:getNumberOfItemsInSection(list, section)
  if self.transportProducts == nil or #self.transportProducts == 0 then
    return 0
  end
  return #self.transportProducts
end

function ProductsOverviewSelectDialog:onClickAmount(state)
  local idx = state or (self.amountElement:getState() or 1)
  self.selectedAmountIndex = idx

  local v = 0
  if self.amountValues ~= nil then
    v = self.amountValues[idx] or 0
  end

  self.selectedAmount = v
  self.itemTextAmount:setText(tostring(v))
end

function ProductsOverviewSelectDialog:populateCellForItemInSection(list, section, index, cell)
  local product = self.transportProducts[index]
  if product == nil then return end

  cell:getAttribute("icon"):setImageFilename(product.hudOverlayFilename)
  cell:getAttribute("product"):setText(product.title)
  cell:getAttribute("amount"):setText(string.format("%d L", product.amount))
end

function ProductsOverviewSelectDialog:setCallback(cb)
  self.onSelectedCallback = cb
end

function ProductsOverviewSelectDialog:onConfirm()
  local idx = self.selectedIndex or 1
  local product = self.transportProducts and self.transportProducts[idx]

  g_currentMission.CustomContracts.selectedProducts = {
    index = idx,
    fillTypeIndex = product and product.fillTypeIndex,
    liters = self.selectedAmount or (product and product.amount) or 0
  }

  self:close()
  g_gui:showDialog("menuCreateContract")
end

function ProductsOverviewSelectDialog:onCancel()
  self:close()
end

function ProductsOverviewSelectDialog:buildAmountOptions(maxLiters)
  maxLiters = math.max(0, math.floor(maxLiters or 0))

  local step
  if maxLiters <= 10000 then
    step = 100
  elseif maxLiters <= 50000 then
    step = 500
  elseif maxLiters <= 200000 then
    step = 1000
  else
    step = 5000
  end

  local values = {}
  local texts  = {}

  table.insert(values, maxLiters)
  table.insert(texts, string.format("All (%d L)", maxLiters))

  local v = maxLiters - step
  while v > 0 do
    table.insert(values, v)
    table.insert(texts, string.format("%d L", v))
    v = v - step
  end

  return values, texts
end

function ProductsOverviewSelectDialog:updateAmountSlider()
  local p = self.transportProducts and self.transportProducts[self.selectedIndex]
  if p == nil then
    return
  end

  self.maxAmount = math.max(0, math.floor(p.amount or 0))
  if self.maxAmount <= 0 then
    self.amountValues   = { 0 }
    self.amountTexts    = { "0 L" }
    self.selectedAmount = 0
    self.amountElement:setTexts(self.amountTexts)
    self.amountElement:setState(1, true)
    self.itemTextAmount:setText("0")
    return
  end

  -- Build a list like: All, then 50k, 45k, 40k ... (whatever step fits)
  self.amountValues, self.amountTexts = self:buildAmountOptions(self.maxAmount)

  -- Default selection = ALL (index 1)
  self.selectedAmountIndex = 1
  self.selectedAmount = self.amountValues[self.selectedAmountIndex] or self.maxAmount

  self.amountElement:setTexts(self.amountTexts)
  self.amountElement:setState(self.selectedAmountIndex, true)

  -- Show numeric amount as well (optional)
  self.itemTextAmount:setText(tostring(self.selectedAmount))
end

function ProductsOverviewSelectDialog:collectFarmSiloFillTypes()
  local results = {}

  local farmId = g_currentMission:getFarmId()

  local totals = {}

  local placeableSystem = g_currentMission.placeableSystem
  local placeables = placeableSystem and placeableSystem.placeables

  if placeables == nil then
    return results
  end

  for v = 1, #g_currentMission.placeableSystem.placeables do
    local placeable = g_currentMission.placeableSystem.placeables[v]
    if placeable.spec_silo ~= nil then
      local owner = placeable.ownerFarmId
      if owner == farmId or owner == 0 then
        local siloSpec = placeable.spec_silo
        local loadingStation = siloSpec.loadingStation

        if loadingStation ~= nil and loadingStation.getAllFillLevels ~= nil then
          local fillLevels = loadingStation:getAllFillLevels(farmId) -- [fillTypeIndex] = liters
          if fillLevels ~= nil then
            for fillTypeIndex, liters in pairs(fillLevels) do
              if fillTypeIndex ~= nil and liters ~= nil and liters > 0 then
                totals[fillTypeIndex] = (totals[fillTypeIndex] or 0) + liters
              end
            end
          end
        end
      end
    end
  end

  for fillTypeIndex, liters in pairs(totals) do
    local ft = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
    print("index" .. fillTypeIndex)
    if ft ~= nil then
      table.insert(results, {
        fillTypeIndex = fillTypeIndex,
        hudOverlayFilename = ft.hudOverlayFilename,
        title = ft.title or ft.name or ("FillType " .. tostring(fillTypeIndex)),
        amount = math.floor(liters + 0.5)
      })
    end
  end

  table.sort(results, function(a, b) return a.title < b.title end)
  return results
end
