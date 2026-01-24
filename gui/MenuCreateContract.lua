MenuCreateContract = {}
local MenuCreateContract_mt = Class(MenuCreateContract, MessageDialog)

CustomContractWorkTypes = {
  {
    id = "CULTIVATE",
    text = "Cultivate"
  },
  {
    id = "PLOW",
    text = "Plow"
  },
  {
    id = "SEED",
    text = "Seed"
  },
  {
    id = "FERTILIZE",
    text = "Fertilize"
  },
  {
    id = "HARVEST",
    text = "Harvest"
  },
  {
    id = "ROLL",
    text = "Roll"
  },
  {
    id = "WEED",
    text = "Weed"
  },
  {
    id = "LIME",
    text = "Lime"
  },
  {
    id = "MULCH",
    text = "Mulch"
  },
  {
    id = "STONEPICK",
    text = "Stone Pick"
  },
  {
    id = "REMOVEFOLIAGE",
    text = "Remove Foliage"
  },
}

function MenuCreateContract.new(target, custom_mt)
  local self = MessageDialog.new(target, custom_mt or MenuCreateContract_mt)
  return self
end

function MenuCreateContract:onCreate()
  MenuCreateContract:superClass().onCreate(self)
end

function MenuCreateContract:onGuiSetupFinished()
  MenuCreateContract:superClass().onGuiSetupFinished(self)
end

function MenuCreateContract:onOpen()
  MenuCreateContract:superClass().onOpen(self)

  -- Intialize worktype list to the GUI
  local workTypeTexts = {}

  for _, workType in ipairs(CustomContractWorkTypes) do
    table.insert(workTypeTexts, workType.text)
  end

  self.workTypeSelector:setTexts(workTypeTexts)
  self.workTypeSelector:setState(1, false)

  -- Initialize field list to the GUI
  local fieldIds = {}

  local farmId = g_currentMission:getFarmId()
  if farmId == nil then
    return
  end

  for _, field in pairs(g_fieldManager:getFields()) do
    if field:getOwner() == farmId then
      table.insert(fieldIds, field:getId())
    end
  end

  table.sort(fieldIds)

  self.fieldIds = fieldIds

  local fieldTexts = {}
  for _, fieldId in ipairs(fieldIds) do
    table.insert(fieldTexts, string.format("Field %d", fieldId))
  end

  self.fieldSelector:setTexts(fieldTexts)
  self.fieldSelector:setState(1, false)

  self.selectedFieldIndex = 1
end

function MenuCreateContract:onClose()
  MenuCreateContract:superClass().onClose(self)
end

function MenuCreateContract:onGroupSelectChange(state)
  self.selectedWorkTypeIndex = state
end

function MenuCreateContract:onFieldSelectChange(state)
  self.selectedFieldIndex = state
end

-- XML onClick handlers
function MenuCreateContract:onConfirm(sender)
  if g_client == nil then
    print("CreateContract blocked: not running on client")
    return
  end

  local fieldId = self.fieldIds[self.selectedFieldIndex or 0]
  local reward = tonumber(self.rewardInput:getText())

  local index = self.selectedWorkTypeIndex or 1
  local workType = CustomContractWorkTypes[index].text

  if fieldId == nil or reward == nil or workType == nil then
    InfoDialog.show("Please fill all fields")
    return
  end

  local contract = {
    fieldId  = fieldId,
    workType = workType,
    reward   = reward
  }

  print(
    "Create button clicked",
    "g_server:", g_server ~= nil,
    "g_client:", g_client ~= nil,
    "localFarm:", g_currentMission:getFarmId()
  )

  g_client:getServerConnection():sendEvent(
    CreateContractEvent.new(contract)
  )

  self:close()
end

function MenuCreateContract:onCancel(sender)
  self:close()
end

function MenuCreateContract:retrieveFieldInfo(fieldId)
  local field = g_fieldManager:getFieldById(fieldId)

  if field == nil then
    return nil
  end
end
