--
-- FS25 Contract and Invoices
--
-- @Author: Racc00n
-- @Version: 1.0.0.0
--

AddInvoiceLineDialog = {}
local AddInvoiceLineDialog_mt = Class(AddInvoiceLineDialog, MessageDialog)
local modDirectory = g_currentModDirectory

function AddInvoiceLineDialog.register()
  local dialog = AddInvoiceLineDialog.new()
  g_gui:loadGui(modDirectory .. "gui/dialog/invoices/AddInvoiceLineDialog.xml", "addInvoiceLineDialog", dialog)
  AddInvoiceLineDialog.INSTANCE = dialog
end

function AddInvoiceLineDialog.new(target, custom_mt)
  local dialog = MessageDialog.new(target, custom_mt or AddInvoiceLineDialog_mt)

  dialog.invoiceDraft = nil

  return dialog
end

function AddInvoiceLineDialog.show(invoiceDraft, onDone)
  if AddInvoiceLineDialog.INSTANCE == nil then AddInvoiceLineDialog.register() end

  local dialog = AddInvoiceLineDialog.INSTANCE

  dialog.invoiceDraft = invoiceDraft
  dialog.onDone = onDone

  g_gui:showDialog("addInvoiceLineDialog")
end

function AddInvoiceLineDialog:onCreate()
  AddInvoiceLineDialog:superClass().onCreate(self)
end

function AddInvoiceLineDialog:onOpen()
  AddInvoiceLineDialog:superClass().onOpen(self)

  if self.lineTextInput ~= nil then
    self.lineTextInput:setText(self.prefillText or "")
  end

  if self.linePriceInput ~= nil then
    self.linePriceInput:setText(self.prefillPrice or "")
  end
end

function AddInvoiceLineDialog:onClose()
  AddInvoiceLineDialog:superClass().onClose(self)
end

function AddInvoiceLineDialog:onCancel()
  self:close()
  g_gui:showDialog(self.parentDialogName)
end

local function parsePrice(text)
  if text == nil then return nil end
  text = tostring(text):gsub("%s+", ""):gsub(",", ".")
  return tonumber(text)
end

function AddInvoiceLineDialog:onOk()
  local title = self.lineTextInput:getText() or ""
  title = tostring(title):gsub("^%s+", ""):gsub("%s+$", "")

  local amountText = self.linePriceInput:getText() or ""
  local amount = parsePrice(amountText)

  if title == "" or amount == nil then
    InfoDialog.show(g_i18n:getText("cc_dialog_create_validation_fields"))
    return
  end

  if self.invoiceDraft.lines == nil then
    self.invoiceDraft.lines = {}
  end

  table.insert(self.invoiceDraft.lines, {
    title = title,
    amount = amount
  })

  self:close()

  if self.onDone ~= nil then
    self.onDone(self.invoiceDraft)
  end
end
