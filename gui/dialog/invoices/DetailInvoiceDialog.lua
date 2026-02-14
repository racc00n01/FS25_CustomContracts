--
-- FS25 CustomContracts
-- @Author: Racc00n
-- @Version: 0.0.1.1
--

DetailInvoiceDialog = {}
local DetailInvoiceDialog_mt = Class(DetailInvoiceDialog, MessageDialog)

function DetailInvoiceDialog.new(target, custom_mt)
  local self = MessageDialog.new(target, custom_mt or DetailInvoiceDialog_mt)
  self.linesRenderer = InvoiceLinesRenderer.new()

  self.invoice = nil

  return self
end

function DetailInvoiceDialog:onCreate()
  DetailInvoiceDialog:superClass().onCreate(self)
end

function DetailInvoiceDialog:onGuiSetupFinished()
  DetailInvoiceDialog:superClass().onGuiSetupFinished(self)
end

function DetailInvoiceDialog:onOpen()
  DetailInvoiceDialog:superClass().onOpen(self)

  self.invoice = g_currentMission.CustomContracts.selectedInvoice

  self.invoiceLineTable:setDataSource(self.linesRenderer)
  self.invoiceLineTable:setDelegate(self.linesRenderer)

  if self.invoice.lines ~= nil then
    self.linesRenderer:setData(self.lines)
  end

  self.invoiceLineTable:reloadData()

  self:updateInvoiceUI(self.invoice)
end

function DetailInvoiceDialog:onClose()
  self.invoice = nil
  DetailInvoiceDialog:superClass().onClose(self)
end

function DetailInvoiceDialog:onCancel(sender)
  self:close()
end

function DetailInvoiceDialog:getFarmName(farmId)
  if farmId == nil then
    return "-"
  end
  local farm = g_farmManager and g_farmManager:getFarmById(farmId)
  if farm ~= nil and farm.name ~= nil and farm.name ~= "" then
    return farm.name
  end
  return string.format("Farm %s", tostring(farmId))
end

function DetailInvoiceDialog:getStatusText(status)
  if status == nil then
    return "-"
  end

  return tostring(status)
end

function DetailInvoiceDialog:formatMoney(amount)
  amount = tonumber(amount) or 0
  -- FS helper exists in basegame: g_i18n:formatMoney(value, 0, true, true)
  if g_i18n ~= nil and g_i18n.formatMoney ~= nil then
    return g_i18n:formatMoney(amount, 0, true, true)
  end
  return string.format("%.0f", amount)
end

function DetailInvoiceDialog:getInvoiceTitle(invoice)
  -- Customize this to your fields. Fallbacks are safe.
  if invoice.title ~= nil and invoice.title ~= "" then
    return invoice.title
  end
  if invoice.description ~= nil and invoice.description ~= "" then
    -- short title from description
    return invoice.description
  end
  return "Invoice"
end

function DetailInvoiceDialog:getInvoiceDescription(invoice)
  if invoice.description ~= nil and invoice.description ~= "" then
    return invoice.description
  end
  return "-"
end

function DetailInvoiceDialog:getInvoiceNumberText(invoice)
  -- Prefer invoice.number if you have it, else id
  if invoice.number ~= nil then
    return string.format("#%s", tostring(invoice.number))
  end
  if invoice.id ~= nil then
    return string.format("#%s", tostring(invoice.id))
  end
  return "#-"
end

function DetailInvoiceDialog:updateInvoiceUI(invoice)
  local myFarmId = g_currentMission:getFarmId()

  self.invoiceNumber:setText(self:getInvoiceNumberText(invoice))
  self.invoiceTitle:setText(self:getInvoiceTitle(invoice))
  self.invoiceStatusLabel:setText(g_i18n:getText("cc_invoice_status_label"))
  self.invoiceStatusValue:setText(self:getStatusText(invoice.status))
  self.invoiceFromFarm:setText(self:getFarmName(invoice.creatorFarmId))
  self.invoiceReceiverFarm:setText(self:getFarmName(invoice.receiverFarmId))
  self.invoiceDescriptionValue:setText(self:getInvoiceDescription(invoice))
  self.invoiceTotalValue:setText(self:formatMoney(invoice.total))

  self:updateButtonVisibility(invoice, myFarmId)
end

function DetailInvoiceDialog:updateButtonVisibility(invoice, myFarmId)
  local isCreator  = invoice.creatorFarmId == myFarmId
  local isReceiver = invoice.receiverFarmId == myFarmId

  local status     = invoice.status

  -- Default: hide everything except Back
  local function setVisible(elem, visible)
    if elem ~= nil then
      elem:setVisible(visible)
    end
  end

  if self.btnCancelInvoice ~= nil then setVisible(self.btnCancelInvoice, false) end
  if self.btnPay ~= nil then setVisible(self.btnPay, false) end
  if self.btnEdit ~= nil then setVisible(self.btnEdit, false) end

  if isCreator then
    if status == Invoice.STATUS.DRAFT then
      if self.btnEdit ~= nil then setVisible(self.btnEdit, true) end
      if self.btnCancelInvoice ~= nil then setVisible(self.btnCancelInvoice, true) end
    elseif status == Invoice.STATUS.SENT then
      -- optional: allow creator to cancel sent invoice
      if self.btnCancelInvoice ~= nil then setVisible(self.btnCancelInvoice, true) end
    end
  end

  if isReceiver then
    if status == Invoice.STATUS.SENT then
      if self.btnPay ~= nil then setVisible(self.btnPay, true) end
    end
  end
end

function DetailInvoiceDialog:onCancelInvoice()
  if self.invoice == nil then return end
  -- TODO: call your cancel event / manager function
  -- g_currentMission.CustomContracts.InvoiceManager:cancelInvoice(self.invoice.id)
end

function DetailInvoiceDialog:onPay()
  if self.invoice == nil then return end
  g_currentMission.CustomContracts.InvoiceManager:handlePayRequest(nil, self.invoice.id)
end

function DetailInvoiceDialog:onEdit()
  if self.invoice == nil then return end
  -- TODO: open edit dialog, set selected invoice, etc.
  -- g_currentMission.CustomContracts.selectedInvoice = self.invoice
  -- g_gui:showDialog("editInvoiceDialog")
end

function DetailInvoiceDialog:onSent()
  if self.invoice == nil then return end
  g_currentMission.CustomContracts.InvoiceManager:handleSendRequest(self.invoice.id)
  self:onClose()
end
