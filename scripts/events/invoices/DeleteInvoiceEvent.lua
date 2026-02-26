--
-- FS25 Contract and Invoices
--
-- @Author: Racc00n
-- @Version: 1.0.0.0
--

DeleteInvoiceEvent = {}
local DeleteInvoiceEvent_mt = Class(DeleteInvoiceEvent, Event)

InitEventClass(DeleteInvoiceEvent, "DeleteInvoiceEvent")

function DeleteInvoiceEvent.emptyNew()
  local self = Event.new(DeleteInvoiceEvent_mt)
  return self
end

function DeleteInvoiceEvent.new(invoiceId, farmId)
  local self = DeleteInvoiceEvent.emptyNew()
  self.farmId = farmId
  self.invoiceId = invoiceId
  return self
end

function DeleteInvoiceEvent:writeStream(streamId, connection)
  streamWriteInt32(streamId, self.farmId)
  streamWriteInt32(streamId, self.invoiceId)
end

function DeleteInvoiceEvent:readStream(streamId, connection)
  self.farmId = streamReadInt32(streamId)
  self.invoiceId = streamReadInt32(streamId)
  self:run(connection)
end

function DeleteInvoiceEvent:run(connection)
  if not connection:getIsServer() then
    g_server:broadcastEvent(DeleteInvoiceEvent.new(self.invoiceId, self.farmId))
  end

  g_currentMission.CustomContracts.InvoiceManager:handleDeleteRequest(self.invoiceId)
end
