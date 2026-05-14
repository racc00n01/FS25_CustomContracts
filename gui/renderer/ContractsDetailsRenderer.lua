--
-- FS25 Contract and Invoices
--
-- Renders per-contract detail rows (Farmland, dates, status, accepted-by, …)
-- into the SmoothList `contractDetailsList` in ccDedicatedMenuContractsFrame.xml.
--

ContractsDetailsRenderer = {}
local ContractsDetailsRenderer_mt = Class(ContractsDetailsRenderer)

function ContractsDetailsRenderer.new()
  local self = {}
  setmetatable(self, ContractsDetailsRenderer_mt)
  self.rows = {}
  return self
end

function ContractsDetailsRenderer:setFromContract(contract)
  self.rows = {}

  if contract == nil then
    return
  end

  local i18n = g_i18n


  if contract.templateId == CustomContract.TEMPLATE.FIELD_WORK then
    table.insert(self.rows, {
      title = i18n:getText("cc_contract_detail_farmland") or i18n:getText("cc_contract_list_field_label"),
      info  = contract.farmlandId
    })
  end

  -- Start date
  table.insert(self.rows, {
    title = i18n:getText("cc_contract_start_date_label"),
    info  = CustomUtils:formatPeriodDay(contract.startPeriod, contract.startDay)
  })

  -- End date
  table.insert(self.rows, {
    title = i18n:getText("cc_contract_due_date_label"),
    info  = CustomUtils:formatPeriodDay(contract.duePeriod, contract.dueDay)
  })

  -- Status
  table.insert(self.rows, {
    title = i18n:getText("cc_contract_status_label_default"),
    info  = (i18n:getText("cc_status_" .. string.lower(contract.status or "")) or contract.status or "-")
  })

  if contract.contractorFarmId ~= nil then
    local contractorFarm = g_farmManager:getFarmById(contract.contractorFarmId)
    local contractorName = "-"
    if contractorFarm ~= nil and contractorFarm.name ~= nil and contractorFarm.name ~= "" then
      contractorName = contractorFarm.name
    end
    table.insert(self.rows, {
      title = i18n:getText("cc_contract_status_label"),
      info = contractorName,
    })
  end

  -- Farmland size
  if contract.templateId == CustomContract.TEMPLATE.FIELD_WORK then
    local farmland = g_farmlandManager:getFarmlandById(contract.farmlandId)
    if farmland ~= nil then
      table.insert(self.rows, {
        title = i18n:getText("cc_contract_detail_farmland_size_label"),
        info  = string.format(i18n:getText("cc_contract_detail_farmland_size"), farmland.areaInHa)
      })
    end
  end

  -- Transport details
  if contract.templateId == CustomContract.TEMPLATE.TRANSPORT then
    table.insert(self.rows, {
      title = i18n:getText("cc_contract_detail_transport_amount_label"),
      info  = string.format(i18n:getText("cc_contract_detail_transport_amount"), contract.transportAmount)
    })

    local fillType = g_fillTypeManager:getFillTypeByIndex(contract.fillTypeIndex)
    table.insert(self.rows, {
      title = i18n:getText("cc_contract_detail_transport_filltype_label"),
      info  = (fillType and (fillType.title or fillType.name)) or "-",
    })
  end
end

function ContractsDetailsRenderer:getNumberOfSections(list)
  return 1
end

function ContractsDetailsRenderer:getNumberOfItemsInSection(list, section)
  return #self.rows
end

function ContractsDetailsRenderer:getTitleForSectionHeader(list, section)
  return ""
end

function ContractsDetailsRenderer:populateCellForItemInSection(list, section, index, cell)
  local row = self.rows[index]
  if row == nil then
    return
  end

  cell:getAttribute("title"):setText(row.title or "")
  cell:getAttribute("info"):setText(row.info or "")
end
