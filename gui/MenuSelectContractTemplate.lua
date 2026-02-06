MenuSelectContractTemplate = {}
local MenuSelectContractTemplate_mt = Class(MenuSelectContractTemplate, MessageDialog)

CustomContractTemplates = {
  {
    id = "FIELD_WORK",
    text = "Field work",
    subtitle = "Cultivate, seed, harvest, mow…"
  },
  {
    id = "TRANSPORT",
    text = "Transport",
    subtitle = "Move goods from A to B"
  },
  {
    id = "FARM_JOB",
    text = "Farm job",
    subtitle = "Feed cows, remove slurry/manure…"
  },
  {
    id = "CUSTOM",
    text = "Custom",
    subtitle = "Free-form job"
  }
}

function MenuSelectContractTemplate.new(target, custom_mt)
  local self = MessageDialog.new(target, custom_mt or MenuSelectContractTemplate_mt)
  self.selectedIndex = 1
  self.onSelectedCallback = nil
  return self
end

function MenuSelectContractTemplate:onCreate()
  MenuSelectContractTemplate:superClass().onCreate(self)
end

function MenuSelectContractTemplate:onOpen()
  MenuSelectContractTemplate:superClass().onOpen(self)

  local texts = {}
  for _, t in ipairs(CustomContractTemplates) do
    print(t.text)
    table.insert(texts, t.text)
  end

  self.templateSelector:setTexts(texts)
  self.templateSelector:setState(1, false)
  self.selectedIndex = 1
end

function MenuSelectContractTemplate:onTemplateChange(state)
  print('state ' .. state)
  self.selectedIndex = state
end

function MenuSelectContractTemplate:setCallback(cb)
  self.onSelectedCallback = cb
end

function MenuSelectContractTemplate:onConfirm()
  local idx = self.selectedIndex or 1
  local t = CustomContractTemplates[idx]
  if t == nil then
    self:close()
    return
  end

  -- Store selection somewhere global/stable
  g_currentMission.CustomContracts.selectedCreateTemplateId = t.id

  self:close()

  -- Now open the create dialog
  if g_currentMission.CustomContracts.selectedCreateTemplateId == "FIELD_WORK" then
    g_gui:showDialog("productsOverviewSelectDialog")
  elseif g_currentMission.CustomContracts.selectedCreateTemplateId == "TRANSPORT" then
    g_gui:showDialog("productsOverviewSelectDialog")
  end
end

function MenuSelectContractTemplate:onCancel()
  self:close()
end
