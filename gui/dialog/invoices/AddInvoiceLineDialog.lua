--
-- FS25 CustomContracts
--

AddInvoiceLineDialog = {}
local AddInvoiceLineDialog_mt = Class(AddInvoiceLineDialog, MessageDialog)

function AddInvoiceLineDialog.new(target, custom_mt)
  local self = MessageDialog.new(target, custom_mt or AddInvoiceLineDialog_mt)

  self.invoiceDraft = nil

  self.parentDialogName = "createInvoiceDialog"
  self.prefillText = ""
  self.prefillPrice = ""

  return self
end

function AddInvoiceLineDialog:onCreate()
  AddInvoiceLineDialog:superClass().onCreate(self)
end

function AddInvoiceLineDialog:setParentDialogName(name)
  self.parentDialogName = name or "createInvoiceDialog"
end

function AddInvoiceLineDialog:setPrefill(text, priceText)
  self.prefillText = text or ""
  self.prefillPrice = priceText or ""
end

function AddInvoiceLineDialog:onOpen()
  AddInvoiceLineDialog:superClass().onOpen(self)

  if g_currentMission.CustomContracts.invoiceDraft ~= nil then
    self.invoiceDraft = g_currentMission.CustomContracts.invoiceDraft
  end

  if self.lineErrorText ~= nil then
    self.lineErrorText:setText("")
  end

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

  if title == "" then
    if self.lineErrorText then
      self.lineErrorText:setText("Description is required")
    end
    return
  end

  if amount == nil then
    if self.lineErrorText then
      self.lineErrorText:setText("Price must be a number")
    end
    return
  end

  table.insert(self.invoiceDraft.lines, {
    title = title,
    amount = amount
  })

  self:close()
  g_gui:showDialog(self.parentDialogName)
end
