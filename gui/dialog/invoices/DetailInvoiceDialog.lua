--
-- FS25 CustomContracts
-- @Author: Racc00n
-- @Version: 0.0.1.1
--

DetailInvoiceDialog = {}
local DetailInvoiceDialog_mt = Class(DetailInvoiceDialog, MessageDialog)

function DetailInvoiceDialog.new(target, custom_mt)
  local self = MessageDialog.new(target, custom_mt or DetailInvoiceDialog_mt)

  self.invoice = nil

  return self
end

function DetailInvoiceDialog:onCreate()
  DetailInvoiceDialog:superClass().onCreate(self)
end

function DetailInvoiceDialog:onGuiSetupFinished()
  DetailInvoiceDialog:superClass().onGuiSetupFinished(self)
end

-- optional setter if you want to set directly instead of using g_currentMission.CustomContracts.selectedInvoice
function DetailInvoiceDialog:setInvoice(invoice)
  self.invoice = invoice
end

function DetailInvoiceDialog:onOpen()
  DetailInvoiceDialog:superClass().onOpen(self)

  -- 1) Resolve the invoice to show
  self.invoice = self.invoice or self:getInvoiceFromMission()
  if self.invoice == nil then
    -- nothing to show, just close safely
    self:close()
    return
  end

  -- 2) Populate UI
  self:updateInvoiceUI(self.invoice)
end

function DetailInvoiceDialog:onClose()
  self.invoice = nil
  DetailInvoiceDialog:superClass().onClose(self)
end

function DetailInvoiceDialog:onCancel(sender)
  self:close()
end

-- =========================
-- Invoice lookup helpers
-- =========================

function DetailInvoiceDialog:getInvoiceFromMission()
  local cc = g_currentMission and g_currentMission.CustomContracts
  if cc == nil then
    return nil
  end

  -- A) direct object
  if cc.selectedInvoice ~= nil then
    return cc.selectedInvoice
  end

  return nil
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
  -- If you already have i18n keys, map them here.
  -- Otherwise just show the raw status string.
  if status == nil then
    return "-"
  end

  -- Example mapping:
  -- if status == Invoice.STATUS.DRAFT then return g_i18n:getText("cc_invoice_status_draft") end
  -- ...
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

-- =========================
-- UI populate + button rules
-- =========================

function DetailInvoiceDialog:updateInvoiceUI(invoice)
  local myFarmId = g_currentMission:getFarmId()

  -- Text fields in XML:
  -- invoiceNumber, invoiceTitle, invoiceStatusLabel, invoiceStatusValue
  -- invoiceFromFarm, invoiceReceiverFarm, invoiceDescriptionValue, invoiceTotalValue

  if self.invoiceNumber ~= nil then
    self.invoiceNumber:setText(self:getInvoiceNumberText(invoice))
  end

  if self.invoiceTitle ~= nil then
    self.invoiceTitle:setText(self:getInvoiceTitle(invoice))
  end

  if self.invoiceStatusLabel ~= nil then
    -- You can set a static label or leave empty (your XML already has a label area)
    self.invoiceStatusLabel:setText(g_i18n:getText("cc_invoice_status_label") or "Status")
  end

  if self.invoiceStatusValue ~= nil then
    self.invoiceStatusValue:setText(self:getStatusText(invoice.status))
  end

  if self.invoiceFromFarm ~= nil then
    self.invoiceFromFarm:setText(self:getFarmName(invoice.creatorFarmId))
  end

  if self.invoiceReceiverFarm ~= nil then
    self.invoiceReceiverFarm:setText(self:getFarmName(invoice.receiverFarmId))
  end

  if self.invoiceDescriptionValue ~= nil then
    self.invoiceDescriptionValue:setText(self:getInvoiceDescription(invoice))
  end

  if self.invoiceTotalValue ~= nil then
    self.invoiceTotalValue:setText(self:formatMoney(invoice.amount or invoice.total or invoice.value or 0))
  end

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
  local function setDisabled(elem, disabled)
    if elem ~= nil and elem.setDisabled ~= nil then
      elem:setDisabled(disabled)
    end
  end

  -- If you didn’t give ids to buttons in XML, you *should*.
  -- Without ids, it’s hard to reference them here.
  -- So: add ids in XML like id="btnCancelInvoice" etc.
  --
  -- For now, I’ll assume you will add:
  -- <Button id="btnCancelInvoice" ... />
  -- <Button id="btnPay" ... />
  -- <Button id="btnEdit" ... />

  if self.btnCancelInvoice ~= nil then setVisible(self.btnCancelInvoice, false) end
  if self.btnPay ~= nil then setVisible(self.btnPay, false) end
  if self.btnEdit ~= nil then setVisible(self.btnEdit, false) end

  -- Rules (adjust to your design)
  -- - Creator can Edit/Cancel while DRAFT (and maybe while SENT)
  -- - Receiver can Pay when SENT
  -- - Nobody can edit paid invoices

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

-- =========================
-- Button callbacks
-- =========================

function DetailInvoiceDialog:onCancelInvoice()
  if self.invoice == nil then return end
  -- TODO: call your cancel event / manager function
  -- g_currentMission.CustomContracts.InvoiceManager:cancelInvoice(self.invoice.id)
end

function DetailInvoiceDialog:onPay()
  if self.invoice == nil then return end
  -- TODO: call your pay event / manager function
  g_currentMission.CustomContracts.InvoiceManager:handlePayRequest(nil, self.invoice.id)
end

function DetailInvoiceDialog:onEdit()
  if self.invoice == nil then return end
  -- TODO: open edit dialog, set selected invoice, etc.
  -- g_currentMission.CustomContracts.selectedInvoice = self.invoice
  -- g_gui:showDialog("editInvoiceDialog")
end
