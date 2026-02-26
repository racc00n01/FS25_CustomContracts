--
-- FS25 Contract and Invoices
--
-- @Author: Racc00n
-- @Version: 1.0.0.0
--

PayInvoiceEvent = {}
local PayInvoiceEvent_mt = Class(PayInvoiceEvent, Event)

InitEventClass(PayInvoiceEvent, "PayInvoiceEvent")

function PayInvoiceEvent.emptyNew()
  local self = Event.new(PayInvoiceEvent_mt)
  return self
end

function PayInvoiceEvent.new(invoiceId, farmId)
  local self = PayInvoiceEvent.emptyNew()
  self.farmId = farmId
  self.invoiceId = invoiceId
  return self
end

function PayInvoiceEvent:writeStream(streamId, connection)
  streamWriteInt32(streamId, self.farmId)
  streamWriteInt32(streamId, self.invoiceId)
end

function PayInvoiceEvent:readStream(streamId, connection)
  self.farmId = streamReadInt32(streamId)
  self.invoiceId = streamReadInt32(streamId)
  self:run(connection)
end

function PayInvoiceEvent:run(connection)
  if not connection:getIsServer() then
    g_server:broadcastEvent(PayInvoiceEvent.new(self.invoiceId, self.farmId))
  end

  local invoiceManager = g_currentMission.CustomContracts.InvoiceManager
  invoiceManager:handlePayRequest(self.farmId, self.invoiceId)
end
