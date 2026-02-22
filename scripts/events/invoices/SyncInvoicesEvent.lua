SyncInvoicesEvent = {}
local SyncInvoicesEvent_mt = Class(SyncInvoicesEvent, Event)

InitEventClass(SyncInvoicesEvent, "SyncInvoicesEvent")

function SyncInvoicesEvent.emptyNew()
  local self = Event.new(SyncInvoicesEvent_mt)
  return self
end

function SyncInvoicesEvent.new(invoices, nextId)
  local self = SyncInvoicesEvent.emptyNew()
  self.invoices = invoices
  self.nextId = nextId

  return self
end

function SyncInvoicesEvent:writeStream(streamId, connection)
  streamWriteInt32(streamId, self.nextId or 1)

  local count = table.size(self.invoices)
  streamWriteInt32(streamId, count)

  for _, invoice in pairs(self.invoices) do
    invoice:writeStream(streamId)
  end
end

function SyncInvoicesEvent:readStream(streamId, connection)
  self.nextId = streamReadInt32(streamId)
  local count = streamReadInt32(streamId)

  self.invoices = {}

  for i = 1, count do
    local invoice = Invoice.newFromStream(streamId)
    self.invoices[invoice.id] = invoice
  end

  self:run(connection)
end

function SyncInvoicesEvent:run(connection)
  local invoiceManager = g_currentMission.CustomContracts.InvoiceManager
  if invoiceManager == nil then
    return
  end

  invoiceManager.invoices = self.invoices
  invoiceManager.nextId = self.nextId

  g_messageCenter:publish(MessageType.INVOICES_UPDATED)
end
