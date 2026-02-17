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
  self.farmId = nil

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
  self.farmId = g_currentMission:getFarmId()

  self.invoiceLineTable:setDataSource(self.linesRenderer)
  self.invoiceLineTable:setDelegate(self.linesRenderer)

  if self.invoice.lines ~= nil then
    self.linesRenderer:setData(self.invoice.lines)
  end

  self.invoiceLineTable:reloadData()

  self:updateInvoiceUI()
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

function DetailInvoiceDialog:updateInvoiceUI()
  self.invoiceNumber:setText(self.invoice)
  self.invoiceTitle:setText(self.invoice.title or "")
  self.invoiceStatusLabel:setText(g_i18n:getText("cc_invoice_status_label"))
  self.invoiceStatusValue:setText(self.status)
  self.invoiceFromFarm:setText(self:getFarmName(self.creatorFarmId))
  self.invoiceReceiverFarm:setText(self:getFarmName(self.receiverFarmId))
  self.invoiceDescriptionValue:setText(self.description or "")
  self.invoiceTotalValue:setText(g_i18n:formatMoney(self.money, 0, true, false))

  self:updateButtonVisibility()
end

function DetailInvoiceDialog:updateButtonVisibility()
  local isCreator  = self.creatorFarmId == self.farmId
  local isReceiver = self.receiverFarmId == self.farmId

  local status     = self.status

  if self.btnCancelInvoice ~= nil then
    self.btnCancelInvoice:setVisible(false)
  end
  if self.btnPay ~= nil then
    self.btnPay:setVisible(false)
  end
  if self.btnEdit ~= nil then
    self.btnEdit:setVisible(false)
  end
  if self.btnDeleteInvoice ~= nil then
    self.btnDeleteInvoice:setVisible(false)
  end

  if isCreator then
    self.btnDeleteInvoice:setVisible(true)

    if status == Invoice.STATUS.DRAFT then
      self.btnEdit:setVisible(true)
      self.btnCancelInvoice:setVisible(true)
    elseif status == Invoice.STATUS.SENT then
      self.btnCancelInvoice:setVisible(true)
    end
  end

  if isReceiver then
    if status == Invoice.STATUS.SENT then
      self.btnSent:setVisible(false)
      if self.btnPay ~= nil then
        self.btnPay:setVisible(true)
      end
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
  self:onClose()
  g_currentMission.CustomContracts.InvoiceManager:handlePayRequest(nil, self.invoice.id)
end

function DetailInvoiceDialog:onDelete()
  if self.invoice == nil then return end
  self:onClose()
  g_currentMission.CustomContracts.InvoiceManager:handleDeleteRequest(nil, self.invoice.id)
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
