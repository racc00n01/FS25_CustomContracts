--
-- FS25 Contract and Invoices
--
-- @Author: Racc00n
-- @Version: 1.0.0.0
--

DetailInvoiceDialog = {}
local DetailInvoiceDialog_mt = Class(DetailInvoiceDialog, MessageDialog)
local modDirectory = g_currentModDirectory

function DetailInvoiceDialog.register()
  local dialog = DetailInvoiceDialog.new()
  g_gui:loadGui(modDirectory .. "gui/dialog/invoices/DetailInvoiceDialog.xml", "detailInvoiceDialog", dialog)
  DetailInvoiceDialog.INSTANCE = dialog
end

function DetailInvoiceDialog.new(target, custom_mt)
  local self = MessageDialog.new(target, custom_mt or DetailInvoiceDialog_mt)
  self.linesRenderer = InvoiceLinesRenderer.new()

  self.invoice = nil
  self.farmId = nil

  return self
end

function DetailInvoiceDialog.show(invoice)
  if DetailInvoiceDialog.INSTANCE == nil then DetailInvoiceDialog.register() end

  local dialog = DetailInvoiceDialog.INSTANCE

  dialog.invoice = invoice

  g_gui:showDialog("detailInvoiceDialog")
end

function DetailInvoiceDialog:onCreate()
  DetailInvoiceDialog:superClass().onCreate(self)
end

function DetailInvoiceDialog:onGuiSetupFinished()
  DetailInvoiceDialog:superClass().onGuiSetupFinished(self)
end

function DetailInvoiceDialog:onOpen()
  DetailInvoiceDialog:superClass().onOpen(self)

  self.farmId = g_currentMission:getFarmId()
  self.invoiceNumber:setText(self.invoice.number)
  self.invoiceTitle:setText(self.invoice.title or "")
  self.invoiceStatusLabel:setText(g_i18n:getText("cc_invoice_status_label"))
  self.invoiceStatusValue:setText(self.invoice:getStatus(self.farmId))
  self.invoiceFromFarm:setText(self:getFarmName(self.invoice.creatorFarmId))
  self.invoiceReceiverFarm:setText(self:getFarmName(self.invoice.receiverFarmId))
  self.invoiceDescriptionValue:setText(self.invoice.description or "")
  self.invoiceTotalValue:setText(g_i18n:formatMoney(self.invoice.total, 0, true, false))

  self.invoiceLineTable:setDataSource(self.linesRenderer)
  self.invoiceLineTable:setDelegate(self.linesRenderer)

  if self.invoice.lines ~= nil then
    self.linesRenderer:setData(self.invoice.lines)
  end

  self.invoiceLineTable:reloadData()

  self:updateButtonVisibility()
end

function DetailInvoiceDialog:onClose()
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
  return string.format(g_i18n:getText("cc_farm"), tostring(farmId))
end

function DetailInvoiceDialog:updateButtonVisibility()
  if self.btnPay ~= nil then
    self.btnPay:setVisible(false)
  end
  if self.btnEditInvoice ~= nil then
    self.btnEditInvoice:setVisible(false)
  end
  if self.btnDeleteInvoice ~= nil then
    self.btnDeleteInvoice:setVisible(false)
  end
  if self.btnSent ~= nil then
    self.btnSent:setVisible(false)
  end

  if self.invoice.status == Invoice.STATUS.DRAFT then
    self.btnSent:setVisible(true)
    self.btnEditInvoice:setVisible(true)
  elseif (self.invoice.status == Invoice.STATUS.OPEN or self.invoice.status == Invoice.STATUS.SENT) and self.invoice.receiverFarmId == g_currentMission:getFarmId() then
    self.btnPay:setVisible(true)
  end
end

function DetailInvoiceDialog:onCancelInvoice()
  if self.invoice == nil then return end
  -- TODO: call your cancel event / manager function
end

function DetailInvoiceDialog:onPay()
  if self.invoice == nil then return end

  YesNoDialog.show(
    function(_, yes)
      if yes then
        g_client:getServerConnection():sendEvent(PayInvoiceEvent.new(self.invoice.id, self.farmId))
      end
    end,
    self,
    string.format(
      g_i18n:getText("cc_dialog_invoice_pay_yes_no"),
      self.invoice.number,
      g_i18n:formatMoney(self.invoice.total)
    ),
    g_i18n:getText("cc_dialog_invoice_pay_yes_no_btn")
  )
  self:close()
end

function DetailInvoiceDialog:onDelete()
  if self.invoice == nil then return end

  YesNoDialog.show(
    function(_, yes)
      if yes then
        g_client:getServerConnection():sendEvent(DeleteInvoiceEvent.new(self.invoice.id, self.farmId))
      end
    end,
    self,
    string.format(
      g_i18n:getText("cc_dialog_invoice_delete_yes_no"),
      self.invoice.number
    ),
    g_i18n:getText("cc_dialog_invoice_delete_yes_no_btn")
  )
  self:close()
end

function DetailInvoiceDialog:onSent()
  if self.invoice == nil then return end

  YesNoDialog.show(
    function(_, yes)
      if yes then
        g_client:getServerConnection():sendEvent(SendInvoiceEvent.new(self.invoice.id, self.farmId))
      end
    end,
    self,
    string.format(
      g_i18n:getText("cc_dialog_invoice_send_yes_no"),
      self.invoice.number,
      g_i18n:formatMoney(self.invoice.total)
    ),
    g_i18n:getText("cc_dialog_invoice_send_yes_no_btn")
  )
  self:close()
end

function DetailInvoiceDialog:onEdit()
  if self.invoice == nil then return end

  EditInvoiceDialog.show(self.invoice)
  self:close()
end
